import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:medicare_ai/services/app_log_service.dart';
import 'package:medicare_ai/services/call_session_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({
    super.key,
    required this.roomName,
    required this.headerTitle,
    required this.callerUid,
    required this.calleeUid,
    required this.callerRole,
    required this.participantName,
    this.createSessionOnConnect = true,
    this.callId,
  });

  final String roomName;
  final String headerTitle;
  final String callerUid;
  final String calleeUid;
  final String callerRole;
  final String participantName;
  final bool createSessionOnConnect;
  final String? callId;

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  Room? _room;
  bool _connecting = true;
  bool _micEnabled = true;
  bool _micBusy = false;
  bool _ending = false;
  String _status = 'Connecting...';
  String? _callId;
  Timer? _callTimer;
  Duration _callElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    try {
      await LiveKitCallService.connectAudio(
        room: room,
        roomName: widget.roomName,
        identity: widget.callerUid,
        participantName: widget.participantName,
      );
      _callId = widget.callId;
      if (widget.createSessionOnConnect) {
        try {
          _callId = await CallSessionService.instance.createSession(
            callerUid: widget.callerUid,
            calleeUid: widget.calleeUid,
            callerRole: widget.callerRole,
            roomName: widget.roomName,
          );
        } catch (e) {
          AppLogService.instance.error('Call session create failed', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Call connected, but session log failed: $e'),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = 'Connected in-app call';
      });
      _startCallTimer();
    } catch (e) {
      AppLogService.instance.error('LiveKit connect failed', e);
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = _formatLiveKitConnectError(e);
      });
    }
  }

  String _formatLiveKitConnectError(Object e) {
    final text = e.toString();
    if (text.contains('invalid API key') || text.contains('Invalid API key')) {
      return 'LiveKit: invalid API key (connection refused).\n\n'
          'The "token test" only checks the HTTP API — it does not open a call. '
          'This error means the API key, secret, and WebSocket URL stored for '
          'the Cloud Function (LIVEKIT_API_KEY, LIVEKIT_API_SECRET, '
          'LIVEKIT_URL) are not a matching set for your LiveKit Cloud project. '
          'Copy all three from the same project in the LiveKit dashboard, '
          'set them as Firebase Function secrets, redeploy livekitToken, then try again.\n\n'
          'Details: $e';
    }
    return 'Unable to connect call room.\n$e';
  }

  Future<void> _toggleMic() async {
    if (_micBusy || _ending) {
      return;
    }
    final room = _room;
    if (room == null) return;
    final next = !_micEnabled;
    setState(() => _micBusy = true);
    try {
      await room.localParticipant?.setMicrophoneEnabled(next);
      if (!mounted) return;
      setState(() => _micEnabled = next);
    } catch (e) {
      AppLogService.instance.error('Toggle microphone failed', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not change microphone state. Try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _micBusy = false);
      }
    }
  }

  Future<void> _hangUp() async {
    if (_ending) {
      return;
    }
    _callTimer?.cancel();
    setState(() {
      _ending = true;
      _status = 'Ending call...';
    });
    // Close UI immediately so the user does not feel stuck waiting for
    // network/session cleanup.
    if (mounted) {
      Navigator.of(context).pop();
    }
    final room = _room;
    _room = null;
    final id = _callId;
    _callId = null;
    unawaited(_finalizeHangUp(room: room, callId: id));
  }

  Future<void> _finalizeHangUp({Room? room, String? callId}) async {
    try {
      await room?.disconnect().timeout(const Duration(seconds: 6));
    } catch (e) {
      AppLogService.instance.error('Room disconnect failed during hang-up', e);
    }
    if (callId != null) {
      try {
        await CallSessionService.instance
            .endSession(callId: callId)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        AppLogService.instance.error(
          'Call session end failed during hang-up',
          e,
        );
      }
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _room?.dispose();
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _callElapsed += const Duration(seconds: 1));
    });
  }

  String _formatElapsed(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    if (hh > 0) {
      return '${hh.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    final isConnected = !_connecting && _status == 'Connected in-app call';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _connecting
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: cs.onSurface,
              title: Text(widget.headerTitle),
            ),
      body: SafeArea(
        child: _connecting
            ? Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: cs.primary,
                    strokeWidth: 3,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 22),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.call_rounded, color: cs.primary, size: 36),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.participantName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFFE8F8EF)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isConnected ? 'Connected' : 'Unavailable',
                        style: TextStyle(
                          color: isConnected
                              ? const Color(0xFF1C7C45)
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isConnected ? _formatElapsed(_callElapsed) : _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure in-app call',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _toggleMic,
                            icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                            label: Text(
                              _micBusy
                                  ? 'Updating...'
                                  : (_micEnabled ? 'Mute mic' : 'Unmute mic'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _ending ? null : _hangUp,
                            icon: const Icon(Icons.call_end_rounded),
                            label: Text(_ending ? 'Ending...' : 'End call'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

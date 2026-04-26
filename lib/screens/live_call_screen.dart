import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:medicare_ai/screens/app_logs_screen.dart';
import 'package:medicare_ai/services/app_log_service.dart';
import 'package:medicare_ai/services/call_session_service.dart';
import 'package:medicare_ai/services/livekit_call_service.dart';

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
  String _status = 'Connecting...';
  String? _callId;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
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
                content: Text(
                  'Call connected, but session log failed: $e',
                ),
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
    final room = _room;
    if (room == null) return;
    final next = !_micEnabled;
    await room.localParticipant?.setMicrophoneEnabled(next);
    if (!mounted) return;
    setState(() => _micEnabled = next);
  }

  Future<void> _hangUp() async {
    await _room?.disconnect();
    final id = _callId;
    if (id != null) {
      await CallSessionService.instance.endSession(callId: id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.headerTitle),
        actions: [
          IconButton(
            tooltip: 'Open app logs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AppLogsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFF1D4ED8),
                child: Icon(Icons.call_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Room: ${widget.roomName}',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
              const Spacer(),
              if (_connecting) const CircularProgressIndicator(color: Colors.white),
              if (!_connecting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _toggleMic,
                      icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                      label: Text(_micEnabled ? 'Mute' : 'Unmute'),
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _hangUp,
                      icon: const Icon(Icons.call_end_rounded),
                      label: const Text('End'),
                    ),
                  ],
                ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
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
  });

  final String roomName;
  final String headerTitle;
  final String callerUid;
  final String calleeUid;
  final String callerRole;
  final String participantName;

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
    if (!LiveKitCallService.isConfigured) {
      setState(() {
        _connecting = false;
        _status = 'Missing LiveKit config. Add LIVEKIT_URL and LIVEKIT_TOKEN.';
      });
      return;
    }

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
      _callId = await CallSessionService.instance.createSession(
        callerUid: widget.callerUid,
        calleeUid: widget.calleeUid,
        callerRole: widget.callerRole,
        roomName: widget.roomName,
      );
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = 'Connected in-app call';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = 'Unable to connect call room.';
      });
    }
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

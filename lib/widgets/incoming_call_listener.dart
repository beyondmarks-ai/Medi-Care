import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/live_call_screen.dart';
import 'package:medicare_ai/services/call_session_service.dart';

class IncomingCallListener extends StatefulWidget {
  const IncomingCallListener({
    super.key,
    required this.child,
    required this.currentRole,
    required this.participantName,
  });

  final Widget child;
  final String currentRole;
  final String participantName;

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  final Set<String> _handledCallIds = <String>{};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;
    _subscription = CallSessionService.instance
        .incomingSessionStream(calleeUid: uid)
        .listen(_onIncomingSnapshot);
  }

  Future<void> _onIncomingSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (_dialogOpen) return;
    for (final doc in snapshot.docs) {
      if (_handledCallIds.contains(doc.id)) continue;
      _handledCallIds.add(doc.id);
      final data = doc.data();
      final roomName = (data['roomName'] as String?) ?? '';
      final callerUid = (data['callerUid'] as String?) ?? '';
      if (roomName.trim().isEmpty || callerUid.trim().isEmpty) {
        continue;
      }
      _dialogOpen = true;
      final accept = await _showIncomingCallDialog();
      _dialogOpen = false;
      if (!mounted) return;
      if (!accept) {
        await CallSessionService.instance.updateStatus(callId: doc.id, status: 'declined');
        continue;
      }
      await CallSessionService.instance.updateStatus(callId: doc.id, status: 'accepted');
      if (!mounted) return;
      final calleeUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveCallScreen(
            roomName: roomName,
            headerTitle: 'Incoming Call',
            callerUid: calleeUid,
            calleeUid: callerUid,
            callerRole: widget.currentRole,
            participantName: widget.participantName,
            createSessionOnConnect: false,
            callId: doc.id,
          ),
        ),
      );
    }
  }

  Future<bool> _showIncomingCallDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Incoming call'),
          content: const Text('Someone is calling you. Join now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

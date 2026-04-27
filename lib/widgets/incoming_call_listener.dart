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
      final callerRole = ((data['callerRole'] as String?) ?? '').trim();
      if (roomName.trim().isEmpty || callerUid.trim().isEmpty) {
        continue;
      }
      final callerName = await _resolveCallerName(callerUid);
      final titleName = _displayCallerName(
        callerName: callerName,
        callerRole: callerRole,
      );
      _dialogOpen = true;
      final accept = await _showIncomingCallDialog(
        callerName: titleName,
        callerRole: callerRole,
      );
      _dialogOpen = false;
      if (!mounted) return;
      if (!accept) {
        await CallSessionService.instance.updateStatus(
          callId: doc.id,
          status: 'declined',
        );
        continue;
      }
      await CallSessionService.instance.updateStatus(
        callId: doc.id,
        status: 'accepted',
      );
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

  Future<String?> _resolveCallerName(String callerUid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(callerUid)
          .get();
      final data = snap.data();
      final raw = (data?['name'] as String?)?.trim();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  String _displayCallerName({
    required String? callerName,
    required String callerRole,
  }) {
    final fallback = callerRole.toLowerCase() == 'doctor' ? 'Doctor' : 'Caller';
    final base = (callerName == null || callerName.isEmpty)
        ? fallback
        : callerName;
    if (callerRole.toLowerCase() == 'doctor' &&
        !base.toLowerCase().startsWith('dr')) {
      return 'Dr. $base';
    }
    return base;
  }

  Future<bool> _showIncomingCallDialog({
    required String callerName,
    required String callerRole,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        final title = callerRole.toLowerCase() == 'doctor'
            ? 'Dr Medicare'
            : 'Medicare call';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call_rounded, size: 34, color: cs.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  callerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Incoming call',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        icon: const Icon(Icons.call_end_rounded),
                        label: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Receive'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

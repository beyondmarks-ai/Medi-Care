import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_ai/services/doctor_pharmacy_send_service.dart';

/// Merges doctor-queued pharmacy lines into the patient cart when this user is signed in.
class PatientPharmacyInboxListener extends StatefulWidget {
  const PatientPharmacyInboxListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PatientPharmacyInboxListener> createState() =>
      _PatientPharmacyInboxListenerState();
}

class _PatientPharmacyInboxListenerState
    extends State<PatientPharmacyInboxListener> {
  StreamSubscription<User?>? _auth;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        DoctorPharmacySendService.instance.stopPatientInbox();
        return;
      }
      DoctorPharmacySendService.instance.startPatientInbox(
        patientUid: user.uid,
      );
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    DoctorPharmacySendService.instance.stopPatientInbox();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

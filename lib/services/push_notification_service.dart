import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // Placeholder foreground handler. Integrate local notifications UI if needed.
      final _ = message.notification;
    });

    await _saveToken();
    _messaging.onTokenRefresh.listen((_) => _saveToken());
  }

  Future<void> syncTokenForCurrentUser() => _saveToken();

  Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _db.collection('users').doc(uid).set(
      <String, dynamic>{
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

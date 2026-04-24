import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Replace these values with FlutterFire CLI generated options for production.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('Unsupported platform for Firebase.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:android:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
    iosBundleId: 'com.example.medicare_ai',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
    iosBundleId: 'com.example.medicare_ai',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
    authDomain: 'replace-me.firebaseapp.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
    authDomain: 'replace-me.firebaseapp.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-me',
    storageBucket: 'replace-me.appspot.com',
    authDomain: 'replace-me.firebaseapp.com',
  );
}

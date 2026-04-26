import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:medicare_ai/firebase_options.dart';
import 'package:medicare_ai/screens/splash_screen.dart';
import 'package:medicare_ai/services/app_log_service.dart';
import 'package:medicare_ai/services/push_notification_service.dart';
import 'package:medicare_ai/services/theme_mode_controller.dart';
import 'package:medicare_ai/theme/app_theme_data.dart';
import 'package:medicare_ai/widgets/theme_scope.dart';
import 'dart:async';

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogService.instance.error(
      'Flutter framework error',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    await PushNotificationService.instance.initialize();
    final theme = ThemeModeController();
    await theme.load();
    runApp(
      ThemeScope(
        controller: theme,
        child: const MedicareApp(),
      ),
    );
  }, (Object error, StackTrace stackTrace) {
    AppLogService.instance.error('Uncaught async error', error, stackTrace);
  });
}

class MedicareApp extends StatelessWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = ThemeScope.of(context).mode;
    return MaterialApp(
      title: 'Medicare AI',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.light(),
      darkTheme: AppThemeData.dark(),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 500),
      themeAnimationCurve: Curves.easeInOutCubic,
      home: const SplashScreen(),
    );
  }
}

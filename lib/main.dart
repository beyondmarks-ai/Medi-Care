import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:medicare_ai/firebase_options.dart';
import 'package:medicare_ai/screens/splash_screen.dart';
import 'package:medicare_ai/services/api_key_store.dart';
import 'package:medicare_ai/services/push_notification_service.dart';
import 'package:medicare_ai/services/theme_mode_controller.dart';
import 'package:medicare_ai/theme/app_theme_data.dart';
import 'package:medicare_ai/widgets/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiKeyStore.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.instance.initialize();
  final theme = ThemeModeController();
  await theme.load();
  runApp(
    ThemeScope(
      controller: theme,
      child: const MedicareApp(),
    ),
  );
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

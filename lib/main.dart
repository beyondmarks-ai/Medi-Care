import 'package:flutter/material.dart';
import 'package:medicare_ai/screens/splash_screen.dart';

void main() {
  runApp(const MedicareApp());
}

class MedicareApp extends StatelessWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medicare AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF916CF2)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

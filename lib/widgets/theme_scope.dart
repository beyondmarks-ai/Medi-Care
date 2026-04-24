import 'package:flutter/material.dart';
import 'package:medicare_ai/services/theme_mode_controller.dart';

class ThemeScope extends InheritedNotifier<ThemeModeController> {
  const ThemeScope({
    super.key,
    required ThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeModeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}

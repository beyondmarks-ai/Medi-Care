import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads API keys from bundled env.local.json (app-internal) with optional
/// --dart-define override.
class ApiKeyStore {
  ApiKeyStore._();

  static final Map<String, String> _assetKeys = <String, String>{};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final raw = await rootBundle.loadString('env.local.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is String && value.trim().isNotEmpty) {
            _assetKeys[entry.key] = value.trim();
          }
        }
      }
    } catch (_) {
      // If asset not found/invalid, we still allow dart-define based keys.
    }
  }

  static String read(String key) {
    final defineValue = String.fromEnvironment(key).trim();
    if (defineValue.isNotEmpty) return defineValue;
    return _assetKeys[key] ?? '';
  }
}


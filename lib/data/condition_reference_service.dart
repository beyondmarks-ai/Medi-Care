import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:medicare_ai/models/condition_reference_entry.dart';

/// Loads the bundled [ConditionReferenceBundle] (assets/data/condition_reference.json).
/// This is a static reference; your clinician sets real prescriptions in care workflows.
class ConditionReferenceService {
  ConditionReferenceService._();

  static ConditionReferenceBundle? _cache;

  static Future<ConditionReferenceBundle> load() async {
    if (_cache != null) {
      return _cache!;
    }
    final raw = await rootBundle.loadString('assets/data/condition_reference.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _cache = ConditionReferenceBundle.fromJson(map);
    return _cache!;
  }

  @visibleForTesting
  static void clearCacheForTest() {
    _cache = null;
  }
}

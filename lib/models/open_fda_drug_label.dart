import 'package:flutter/foundation.dart';

/// Parsed `drug/label` record from [OpenFdaService] (U.S. FDA openFDA, not medical advice).
@immutable
class OpenFdaDrugLabel {
  const OpenFdaDrugLabel({
    required this.brandNames,
    required this.genericNames,
    required this.manufacturerNames,
    this.indicationsAndUsage,
    this.purpose,
    this.contraindications,
    this.warnings,
    this.boxedWarning,
    this.adverseReactions,
    this.drugInteractions,
    this.dosageAndAdministration,
  });

  final List<String> brandNames;
  final List<String> genericNames;
  final List<String> manufacturerNames;
  final String? indicationsAndUsage;
  final String? purpose;
  final String? contraindications;
  final String? warnings;
  final String? boxedWarning;
  final String? adverseReactions;
  final String? drugInteractions;
  final String? dosageAndAdministration;
}

extension OpenFdaDrugLabelDisplay on OpenFdaDrugLabel {
  /// Best-effort display name for this SPL row (brand, else generic, else a fallback).
  String get displayTitle {
    if (brandNames.isNotEmpty) {
      return brandNames.first;
    }
    if (genericNames.isNotEmpty) {
      return genericNames.first;
    }
    return 'U.S. FDA product';
  }
}

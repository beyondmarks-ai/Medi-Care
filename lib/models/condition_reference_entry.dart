/// Educational reference for in-app "condition → general guidance" (not a prescription).
class ConditionReferenceBundle {
  ConditionReferenceBundle({
    required this.version,
    required this.disclaimer,
    required this.conditions,
  });

  final int version;
  final String disclaimer;
  final List<ConditionReferenceEntry> conditions;

  factory ConditionReferenceBundle.fromJson(Map<String, dynamic> json) {
    final list = json['conditions'] as List<dynamic>? ?? const [];
    return ConditionReferenceBundle(
      version: (json['version'] as num?)?.toInt() ?? 1,
      disclaimer: (json['disclaimer'] as String?)?.trim() ?? '',
      conditions: list
          .map((e) => ConditionReferenceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ConditionReferenceEntry {
  ConditionReferenceEntry({
    required this.id,
    required this.displayName,
    required this.keywords,
    required this.summary,
    required this.selfCare,
    required this.whenToSeeDoctor,
    required this.medicationNote,
    required this.medicationClasses,
  });

  final String id;
  final String displayName;
  final List<String> keywords;
  final String summary;
  final List<String> selfCare;
  final List<String> whenToSeeDoctor;
  final String medicationNote;
  final List<ReferenceMedicationClass> medicationClasses;

  factory ConditionReferenceEntry.fromJson(Map<String, dynamic> json) {
    return ConditionReferenceEntry(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => (e as String).toLowerCase())
              .toList() ??
          const [],
      summary: json['summary'] as String? ?? '',
      selfCare: (json['selfCare'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      whenToSeeDoctor: (json['whenToSeeDoctor'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      medicationNote: json['medicationNote'] as String? ?? '',
      medicationClasses: (json['medicationClasses'] as List<dynamic>?)
              ?.map(
                (e) => ReferenceMedicationClass.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
  }
}

class ReferenceMedicationClass {
  ReferenceMedicationClass({
    required this.name,
    required this.typicalUse,
  });

  final String name;
  final String typicalUse;

  factory ReferenceMedicationClass.fromJson(Map<String, dynamic> json) {
    return ReferenceMedicationClass(
      name: json['name'] as String? ?? '',
      typicalUse: json['typicalUse'] as String? ?? '',
    );
  }
}

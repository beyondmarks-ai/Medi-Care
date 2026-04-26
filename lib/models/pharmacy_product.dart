import 'package:flutter/foundation.dart';

/// One row from the pharmacy CSV (or Kaggle export). Catalog display only; not a prescription.
@immutable
class PharmacyProduct {
  const PharmacyProduct({
    required this.id,
    required this.name,
    this.category,
    this.subCategory,
    this.form,
    this.manufacturer,
    this.price,
    this.description,
    this.composition,
    this.packSize,
    this.imageAsset,
    this.extra = const {},
  });

  final String id;
  final String name;
  final String? category;
  final String? subCategory;
  final String? form;
  final String? manufacturer;
  final double? price;
  final String? description;
  final String? composition;
  final String? packSize;
  /// Path registered in pubspec, e.g. `assets/images/pharmacy_pills/abc.jpg`.
  final String? imageAsset;
  final Map<String, String> extra;

  String get displaySubtitle {
    final parts = <String>[
      if (category != null && category!.isNotEmpty) category!,
      if (form != null && form!.isNotEmpty) form!,
    ];
    return parts.isEmpty ? 'Pharmacy item' : parts.join(' · ');
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'subCategory': subCategory,
      'form': form,
      'manufacturer': manufacturer,
      'price': price,
      'description': description,
      'composition': composition,
      'packSize': packSize,
      'imageAsset': imageAsset,
      'extra': extra,
    };
  }

  static PharmacyProduct fromMap(Map<String, dynamic> m) {
    final extra = m['extra'];
    return PharmacyProduct(
      id: m['id'] as String? ?? 'unknown',
      name: m['name'] as String? ?? 'Unknown',
      category: m['category'] as String?,
      subCategory: m['subCategory'] as String?,
      form: m['form'] as String?,
      manufacturer: m['manufacturer'] as String?,
      price: (m['price'] as num?)?.toDouble(),
      description: m['description'] as String?,
      composition: m['composition'] as String?,
      packSize: m['packSize'] as String?,
      imageAsset: m['imageAsset'] as String?,
      extra: extra is Map
          ? extra.map(
              (k, v) => MapEntry(
                k.toString(),
                v == null ? '' : v.toString(),
              ),
            )
          : const {},
    );
  }
}

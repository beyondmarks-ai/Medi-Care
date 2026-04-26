import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:medicare_ai/models/pharmacy_product.dart';

/// Loads [PharmacyProduct] rows from [assetPath] (default: bundled Kaggle-style CSV).
///
/// **Expected:** UTF-8 CSV with a header row. This loader maps many common Kaggle
/// column names (e.g. `Medicine Name`, `sub_category`, `pharmacy_class_name`,
/// `image` / `image_asset` for rows produced by `scripts/build_pharmacy_from_kaggle_images.py`.
///
/// The file `TruMedicines-Pharmaceutical-images20k.dataset` in the repo is a
/// Microsoft `.NET` / Azure ML binary — it cannot be read here; use the
/// Kaggle **ZIP** of images (or the build script) instead.
class PharmacyCatalogLoader {
  PharmacyCatalogLoader._();

  static const defaultAsset = 'assets/data/pharmacy_catalog.csv';

  static List<PharmacyProduct>? _cache;

  static Future<List<PharmacyProduct>> load({String assetPath = defaultAsset}) async {
    if (_cache != null) {
      return _cache!;
    }
    final raw = await rootBundle.loadString(assetPath);
    _cache = _parseCsv(raw);
    return _cache!;
  }

  @visibleForTesting
  static void clearCacheForTest() {
    _cache = null;
  }

  @visibleForTesting
  static List<PharmacyProduct> parseForTest(String raw) => _parseCsv(raw);

  static String _normHeader(String h) {
    var s = h.trim();
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
      s = s.substring(1);
    }
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '');
  }

  static String? _firstNonEmpty(
    Map<String, String> row,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = row[k];
      if (v != null) {
        final t = v.trim();
        if (t.isNotEmpty) {
          return t;
        }
      }
    }
    return null;
  }

  static double? _parsePrice(String? s) {
    if (s == null || s.trim().isEmpty) {
      return null;
    }
    var t = s.trim().replaceAll(RegExp(r'[₹$€£\s,]'), '');
    t = t.replaceAll(RegExp(r'[^\d.-]'), '');
    if (t.isEmpty) {
      return null;
    }
    return double.tryParse(t);
  }

  static List<PharmacyProduct> _parseCsv(String raw) {
    final converter = CsvToListConverter(
      shouldParseNumbers: false,
    );
    final table = converter.convert(raw);
    if (table.isEmpty) {
      return const [];
    }
    final headerRow = table.first.map((c) => _normHeader('$c')).toList();
    final dataRows = table.skip(1).where((row) {
      if (row.isEmpty) {
        return false;
      }
      return row.any((c) => '$c'.trim().isNotEmpty);
    });

    final products = <PharmacyProduct>[];
    var seq = 0;
    for (final row in dataRows) {
      final map = <String, String>{};
      for (var i = 0; i < headerRow.length; i++) {
        final h = headerRow[i];
        if (h.isEmpty) {
          continue;
        }
        final v = i < row.length ? '${row[i]}'.trim() : '';
        if (v.isNotEmpty) {
          map[h] = v;
        }
      }
      final name = _firstNonEmpty(map, const [
        'name',
        'medicine_name',
        'medicinename',
        'drug_name',
        'product_name',
        'drug',
        'medicine',
        'item_name',
        'product',
        'pharmacy_product',
      ]);
      if (name == null) {
        continue;
      }
      final id = _firstNonEmpty(map, const [
        'id',
        'product_id',
        'medicine_id',
        'drug_id',
        'sku',
        'code',
      ]) ?? 'p${++seq}';

      final priceStr = _firstNonEmpty(map, const [
        'price',
        'mrp',
        'cost',
        'unit_price',
        'selling_price',
        'retail_price',
        'med_price',
        'pharmacy_price',
      ]);
      final category = _firstNonEmpty(map, const [
        'category',
        'therapeutic_class',
        'therapeuticclass',
        'class',
        'type',
        'pharmacy_class',
        'pharmacy_class_name',
        'drug_type',
        'therapeutic',
      ]);
      final subCategory = _firstNonEmpty(map, const [
        'sub_category',
        'subcategory',
        'subclass',
        'therapeutic_subclass',
      ]);
      final form = _firstNonEmpty(map, const [
        'form',
        'dosage_form',
        'doseform',
        'formulation',
        'typeform',
        'pharmacy_form',
        'form_type',
      ]);
      final manufacturer = _firstNonEmpty(map, const [
        'manufacturer',
        'company',
        'mfg',
        'brand_owner',
        'manufacturedby',
        'mfr',
      ]);
      final desc = _firstNonEmpty(map, const [
        'description',
        'desc',
        'uses',
        'indication',
        'indications',
        'details',
        'short_description',
      ]);
      final composition = _firstNonEmpty(map, const [
        'composition',
        'salt',
        'salts',
        'active_ingredients',
        'ingredients',
        'generic',
      ]);
      final pack = _firstNonEmpty(map, const [
        'pack',
        'pack_size',
        'packsize',
        'quantity',
        'package',
      ]);
      final imageAsset = _firstNonEmpty(map, const [
        'image',
        'image_asset',
        'image_path',
        'imagepath',
        'photo',
        'filename',
        'file',
        'path',
        'asset',
        'thumb',
        'thumbnail',
      ]);

      final usedKeys = {
        'name', 'medicine_name', 'medicinename', 'drug_name', 'product_name', 'drug', 'medicine', 'item_name', 'product', 'pharmacy_product',
        'id', 'product_id', 'medicine_id', 'drug_id', 'sku', 'code',
        'price', 'mrp', 'cost', 'unit_price', 'selling_price', 'retail_price', 'med_price', 'pharmacy_price',
        'category', 'therapeutic_class', 'therapeuticclass', 'class', 'type', 'pharmacy_class', 'pharmacy_class_name', 'drug_type', 'therapeutic',
        'sub_category', 'subcategory', 'subclass', 'therapeutic_subclass',
        'form', 'dosage_form', 'doseform', 'formulation', 'form_type', 'typeform', 'pharmacy_form',
        'manufacturer', 'company', 'mfg', 'brand_owner', 'mfr', 'manufacturedby',
        'description', 'desc', 'uses', 'indication', 'indications', 'details', 'short_description',
        'composition', 'salt', 'salts', 'active_ingredients', 'ingredients', 'generic',
        'pack', 'pack_size', 'packsize', 'package', 'quantity',
        'image', 'image_asset', 'image_path', 'imagepath', 'photo', 'filename', 'file', 'path', 'asset', 'thumb', 'thumbnail',
      };
      final extra = <String, String>{};
      for (final e in map.entries) {
        if (!usedKeys.contains(e.key)) {
          extra[e.key] = e.value;
        }
      }

      products.add(
        PharmacyProduct(
          id: id,
          name: name,
          category: category,
          subCategory: subCategory,
          form: form,
          manufacturer: manufacturer,
          price: _parsePrice(priceStr),
          description: desc,
          composition: composition,
          packSize: pack,
          imageAsset: imageAsset,
          extra: extra,
        ),
      );
    }
    return products;
  }
}

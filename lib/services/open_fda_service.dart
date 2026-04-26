import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:medicare_ai/models/open_fda_drug_label.dart';
import 'package:medicare_ai/services/api_key_store.dart';

class OpenFdaException implements Exception {
  OpenFdaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// U.S. FDA [openFDA drug labels](https://open.fda.gov/apis/drug/label/) - public data;
/// this app is not endorsed by the FDA. Use as reference only, not a substitute
/// for a prescriber or label on your product.
class OpenFdaService {
  OpenFdaService._();

  static Future<OpenFdaDrugLabel?> findLabelByName(String rawQuery) async {
    final list = await searchLabels(rawQuery, limit: 1);
    return list.isEmpty ? null : list.first;
  }

  /// Multiple labels — uses simple per-field queries first (avoids +OR+ encoding issues
  /// on some platforms that can trigger openFDA 500s).
  static Future<List<OpenFdaDrugLabel>> searchLabels(
    String rawQuery, {
    int limit = 8,
  }) async {
    await ApiKeyStore.initialize();
    final key = ApiKeyStore.read('OPENFDA_API_KEY').trim();
    final q = _sanitizeToken(rawQuery);
    if (q.length < 2) {
      return const [];
    }

    final need = limit.clamp(1, 25);
    final seen = <String>{};
    final out = <OpenFdaDrugLabel>[];

    void take(List<OpenFdaDrugLabel> batch) {
      for (final b in batch) {
        final dk = _dedupeKey(b);
        if (dk.isEmpty) {
          continue;
        }
        if (seen.add(dk)) {
          out.add(b);
        }
        if (out.length >= need) {
          return;
        }
      }
    }

    // 1) Single-field queries (most reliable; no OR in one string)
    for (final field in const ['openfda.brand_name', 'openfda.generic_name']) {
      if (out.length >= need) {
        break;
      }
      take(await _requestList(
        '$field:${_luceneTerm(q, quote: true)}',
        key: key,
        cap: need,
      ));
      if (out.length < need) {
        take(await _requestList(
          '$field:${_luceneTerm(q, quote: false)}',
          key: key,
          cap: need,
        ));
      }
    }

    // 2) OR query (one string) — only if we still need rows; may fail on some clients
    if (out.isEmpty) {
      take(await _requestList(
        'openfda.brand_name:${_luceneTerm(q, quote: true)}+OR+openfda.generic_name:${_luceneTerm(q, quote: true)}',
        key: key,
        cap: need,
      ));
    }
    if (out.length < need && out.isEmpty) {
      take(await _requestList(
        'openfda.brand_name:${_luceneTerm(q, quote: false)}+OR+openfda.generic_name:${_luceneTerm(q, quote: false)}',
        key: key,
        cap: need,
      ));
    }

    // 3) Prefix (short terms only) — can 500 on openFDA; skip if it keeps failing
    if (out.isEmpty && q.length >= 4) {
      final safe = q.replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');
      if (safe.length >= 3) {
        take(await _requestList(
          'openfda.brand_name:$safe*+OR+openfda.generic_name:$safe*',
          key: key,
          cap: need,
        ));
      }
    }

    if (out.length < need) {
      final first = q.split(RegExp(r'\s+')).firstWhere(
            (e) => e.length > 2,
            orElse: () => '',
          );
      if (first.isNotEmpty && first != q) {
        for (final field in const ['openfda.brand_name', 'openfda.generic_name']) {
          if (out.length >= need) {
            break;
          }
          take(await _requestList(
            '$field:${_luceneTerm(first, quote: true)}',
            key: key,
            cap: need,
          ));
        }
      }
    }

    return out.take(need).toList();
  }

  static String _dedupeKey(OpenFdaDrugLabel b) {
    if (b.brandNames.isNotEmpty) {
      return 'b:${b.brandNames.first}';
    }
    if (b.genericNames.isNotEmpty) {
      return 'g:${b.genericNames.first}';
    }
    if (b.manufacturerNames.isNotEmpty) {
      return 'm:${b.manufacturerNames.first}';
    }
    return '';
  }

  static String _sanitizeToken(String s) {
    return s
        .replaceAll('"', ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Safe fragment for field:value; quotes phrase when [quote] is true.
  static String _luceneTerm(String term, {required bool quote}) {
    final t = term.trim();
    if (t.isEmpty) {
      return '""';
    }
    if (quote) {
      return '"${t.replaceAll('"', ' ')}"';
    }
    return t;
  }

  static Future<List<OpenFdaDrugLabel>> _requestList(
    String search, {
    required String key,
    required int cap,
  }) async {
    if (cap <= 0) {
      return const [];
    }
    final uri = _buildRequestUri(
      search: search,
      limit: cap.clamp(1, 25),
      apiKey: key,
    );
    final res = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 404) {
      return const [];
    }
    if (res.statusCode == 429) {
      throw OpenFdaException('Rate limited. Try again in a moment.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // openFDA often returns JSON error body; 4xx/5xx should not take down the whole search
      if (res.statusCode >= 500) {
        return const [];
      }
      final errMsg = _parseErrorBody(res.body);
      if (res.statusCode == 400 && errMsg != null) {
        return const [];
      }
      if (res.statusCode >= 400) {
        return const [];
      }
      return const [];
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }
    if (decoded['error'] != null) {
      final err = decoded['error'];
      final msg = err is Map && err['message'] is String
          ? err['message'] as String
          : 'openFDA request failed';
      if (msg.toLowerCase().contains('not found') || msg.toLowerCase().contains('no matches')) {
        return const [];
      }
      return const [];
    }

    final results = decoded['results'];
    if (results is! List) {
      return const [];
    }
    return results
        .whereType<Map<String, dynamic>>()
        .map(_mapLabel)
        .toList();
  }

  static String? _parseErrorBody(String body) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['error'] is Map) {
        final m = d['error'] as Map;
        return m['message'] is String ? m['message'] as String : null;
      }
    } catch (_) {}
    return null;
  }

  /// Build URL so the `search` value is a single [encodeQueryComponent] — avoids
  /// `+` inside the value being read as a space on the server.
  static Uri _buildRequestUri({
    required String search,
    required int limit,
    required String apiKey,
  }) {
    final b = StringBuffer('https://api.fda.gov/drug/label.json?search=');
    b.write(Uri.encodeQueryComponent(search));
    b.write('&limit=');
    b.write(Uri.encodeQueryComponent('$limit'));
    if (apiKey.isNotEmpty) {
      b.write('&api_key=');
      b.write(Uri.encodeQueryComponent(apiKey));
    }
    return Uri.parse(b.toString());
  }

  static OpenFdaDrugLabel _mapLabel(Map<String, dynamic> result) {
    final open = (result['openfda'] is Map<String, dynamic>)
        ? result['openfda'] as Map<String, dynamic>
        : <String, dynamic>{};

    return OpenFdaDrugLabel(
      brandNames: _listFromOpenfda(open, 'brand_name'),
      genericNames: _listFromOpenfda(open, 'generic_name'),
      manufacturerNames: _listFromOpenfda(open, 'manufacturer_name'),
      indicationsAndUsage: _strField(result, 'indications_and_usage'),
      purpose: _strField(result, 'purpose'),
      contraindications: _strField(result, 'contraindications'),
      warnings: _strField(result, 'warnings'),
      boxedWarning: _strField(result, 'boxed_warning'),
      adverseReactions: _strField(result, 'adverse_reactions'),
      drugInteractions: _strField(result, 'drug_interactions'),
      dosageAndAdministration: _strField(result, 'dosage_and_administration'),
    );
  }

  static List<String> _listFromOpenfda(Map<String, dynamic> open, String key) {
    final v = open[key];
    if (v is List) {
      return v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    if (v is String && v.isNotEmpty) {
      return [v];
    }
    return const [];
  }

  static String? _strField(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) {
      return null;
    }
    if (v is String) {
      return v.isEmpty ? null : v;
    }
    if (v is List) {
      final parts = v.map((e) => '$e').where((e) => e.isNotEmpty).toList();
      if (parts.isEmpty) {
        return null;
      }
      return parts.join('\n\n');
    }
    return '$v';
  }
}

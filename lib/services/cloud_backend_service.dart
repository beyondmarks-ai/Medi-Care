import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CloudBackendService {
  CloudBackendService._();

  static const String _defaultBaseUrl =
      'https://us-central1-medicare-ai-74f87.cloudfunctions.net';

  static String get baseUrl {
    final defined = String.fromEnvironment('CLOUD_API_BASE_URL').trim();
    if (defined.isNotEmpty) return defined;
    return _defaultBaseUrl;
  }

  static Future<Map<String, dynamic>> postJson({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    return _postJsonInternal(path: path, body: body);
  }

  static Future<Map<String, dynamic>> postJsonWithFallback({
    required List<String> paths,
    required Map<String, dynamic> body,
  }) async {
    if (paths.isEmpty) {
      throw Exception('No backend paths configured.');
    }
    Object? lastError;
    for (final rawPath in paths) {
      final path = rawPath.trim();
      if (path.isEmpty) continue;
      try {
        return await _postJsonInternal(path: path, body: body);
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('All backend endpoints failed: $lastError');
  }

  static Future<Map<String, dynamic>> _postJsonInternal({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to use this feature.');
    }
    final idToken = await user.getIdToken(true);
    final response = await http.post(
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path'),
      headers: <String, String>{
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloud request failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid cloud response.');
    }
    return decoded;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:medicare_ai/services/api_key_store.dart';
import 'package:path_provider/path_provider.dart';

class SarvamTtsService {
  static const String _endpoint = 'https://api.sarvam.ai/text-to-speech';
  static const String _model = 'bulbul:v3';
  static const String _speaker = 'shubh';

  final http.Client _client;

  SarvamTtsService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> synthesizeToFile({
    required String text,
    required String language,
  }) async {
    final apiKey = ApiKeyStore.read('SARVAM_API_KEY');
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'Missing SARVAM_API_KEY. Run with --dart-define-from-file including SARVAM_API_KEY.',
      );
    }

    final langCode = _languageToSarvamCode(language);
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'api-subscription-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model': _model,
        'speaker': _speaker,
        'target_language_code': langCode,
        'speech_sample_rate': 24000,
        'pace': 1.0,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sarvam TTS failed (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final audios = body['audios'] as List<dynamic>? ?? const [];
    if (audios.isEmpty) {
      throw Exception('Sarvam TTS returned no audio.');
    }
    final base64Audio = audios.first;
    if (base64Audio is! String || base64Audio.trim().isEmpty) {
      throw Exception('Sarvam TTS returned invalid audio payload.');
    }

    final bytes = base64Decode(base64Audio);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/sarvam_tts_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _languageToSarvamCode(String language) {
    switch (language) {
      case 'Hindi':
        return 'hi-IN';
      case 'Bengali':
        return 'bn-IN';
      case 'Telugu':
        return 'te-IN';
      case 'Marathi':
        return 'mr-IN';
      case 'Tamil':
        return 'ta-IN';
      case 'Urdu':
        return 'ur-IN';
      case 'Gujarati':
        return 'gu-IN';
      case 'Kannada':
        return 'kn-IN';
      case 'Odia':
        return 'od-IN';
      case 'Malayalam':
        return 'ml-IN';
      case 'Punjabi':
        return 'pa-IN';
      case 'Assamese':
        return 'as-IN';
      case 'Maithili':
        return 'mai-IN';
      case 'Santali':
        return 'sat-IN';
      case 'Kashmiri':
        return 'ks-IN';
      case 'Nepali':
        return 'ne-IN';
      case 'Konkani':
        return 'kok-IN';
      case 'Sindhi':
        return 'sd-IN';
      case 'Dogri':
        return 'doi-IN';
      case 'Manipuri':
        return 'mni-IN';
      case 'Bodo':
        return 'brx-IN';
      case 'Sanskrit':
        return 'sa-IN';
      case 'English':
      default:
        return 'en-IN';
    }
  }
}


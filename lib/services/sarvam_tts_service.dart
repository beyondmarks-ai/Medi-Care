import 'dart:convert';
import 'dart:io';

import 'package:medicare_ai/services/cloud_backend_service.dart';
import 'package:path_provider/path_provider.dart';

class SarvamTtsService {
  SarvamTtsService();

  Future<String> synthesizeToFile({
    required String text,
    required String language,
  }) async {
    final response = await CloudBackendService.postJson(
      path: '/sarvamTts',
      body: <String, dynamic>{
        'text': text,
        'language': language,
      },
    );
    final base64Audio = response['audioBase64'];
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
}


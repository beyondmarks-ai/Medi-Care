import 'package:medicare_ai/services/cloud_backend_service.dart';

class OpenRouterMedicalAiService {
  OpenRouterMedicalAiService();

  Future<String> ask({
    required List<MedicalChatMessage> history,
    required String outputLanguage,
  }) async {
    final response = await CloudBackendService.postJson(
      path: '/openrouterChat',
      body: <String, dynamic>{
        'history': history
            .map((m) => <String, String>{'role': m.role, 'content': m.content})
            .toList(growable: false),
        'outputLanguage': outputLanguage,
      },
    );
    final text = (response['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      throw Exception('OpenRouter returned an empty assistant message.');
    }
    return text;
  }
}

class MedicalChatMessage {
  const MedicalChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}


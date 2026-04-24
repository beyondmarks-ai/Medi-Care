import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:medicare_ai/services/api_key_store.dart';

class OpenRouterMedicalAiService {
  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openai/gpt-4.1-mini';

  static const String _systemPrompt = '''
You are a professional medical assistant inside a healthcare app.

Strict rules:
- Answer ONLY medical and health-related queries.
- If a user asks anything non-medical (coding, finance, travel, jokes, etc.), politely refuse and ask them to ask a medical question.
- Never claim to be a doctor.
- Do not provide emergency diagnosis certainty.
- For emergencies (chest pain, breathing trouble, stroke signs, severe bleeding, suicidal intent, unconsciousness, seizures, severe allergic reactions), tell the user to contact local emergency services immediately.
- Keep answers concise, practical, and safe.
- If unsure, clearly say uncertainty and suggest consulting a licensed clinician.

Response style requirements:
- Sound professional and clinically clear, like a careful doctor.
- Use very simple words so non-medical users can understand.
- Keep responses short and concise (usually 4-8 bullets maximum).
- Always format in Markdown with clear sections:
  **Quick Answer**
  **Possible Causes**
  **What You Can Do Now**
  **When to Seek Urgent Care**
- Use bullet points for each section.
- Highlight critical warnings with **bold** text.
''';

  final http.Client _client;

  OpenRouterMedicalAiService({http.Client? client})
      : _client = client ?? http.Client();

  Future<String> ask({
    required List<MedicalChatMessage> history,
    required String outputLanguage,
  }) async {
    final apiKey = ApiKeyStore.read('OPENROUTER_API_KEY');
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'Missing OPENROUTER_API_KEY. Run with --dart-define=OPENROUTER_API_KEY=your_key',
      );
    }

    final languageDirective = _languageDirective(outputLanguage);

    final messages = <Map<String, String>>[
      const {'role': 'system', 'content': _systemPrompt},
      {
        'role': 'system',
        'content': '''
The user may ask in any language.
You MUST answer ONLY in: $languageDirective.
Never answer in English unless the selected output language is English.
Keep medical meaning accurate while translating.
''',
      },
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://medicare-ai.local',
        'X-Title': 'Medicare AI',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'OpenRouter request failed (${response.statusCode}): ${response.body}',
      );
    }

    final assistantText = _extractContent(response.body);

    // Hard fallback: when non-English is selected but output remains largely English,
    // force a translation-only pass to selected language.
    if (outputLanguage != 'English' && _looksMostlyEnglish(assistantText)) {
      final translated = await _translateToSelectedLanguage(
        sourceText: assistantText,
        outputLanguage: outputLanguage,
      );
      if (translated.trim().isNotEmpty) {
        return translated.trim();
      }
    }

    return assistantText;
  }

  Future<String> _translateToSelectedLanguage({
    required String sourceText,
    required String outputLanguage,
  }) async {
    final apiKey = ApiKeyStore.read('OPENROUTER_API_KEY');
    final directive = _languageDirective(outputLanguage);
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://medicare-ai.local',
        'X-Title': 'Medicare AI',
      },
      body: jsonEncode({
        'model': _model,
        'temperature': 0,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a strict medical translator. Translate faithfully and return only translated medical guidance with bullets preserved.',
          },
          {
            'role': 'user',
            'content':
                'Translate the following medical response to $directive. Do not use English.\n\n$sourceText',
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return sourceText;
    }
    return _extractContent(response.body);
  }

  static String _extractContent(String rawBody) {
    final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('OpenRouter returned no choices.');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>? ?? const {};
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    throw Exception('OpenRouter returned an empty assistant message.');
  }

  static bool _looksMostlyEnglish(String text) {
    if (text.trim().isEmpty) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
    final nonWhitespace = text.replaceAll(RegExp(r'\s'), '').length;
    if (nonWhitespace == 0) return false;
    final ratio = letters / nonWhitespace;
    return ratio > 0.45;
  }

  static String _languageDirective(String language) {
    switch (language) {
      case 'Hindi':
        return 'Hindi (Devanagari script)';
      case 'Bengali':
        return 'Bengali (Bangla script)';
      case 'Telugu':
        return 'Telugu (Telugu script)';
      case 'Marathi':
        return 'Marathi (Devanagari script)';
      case 'Tamil':
        return 'Tamil (Tamil script)';
      case 'Urdu':
        return 'Urdu (Perso-Arabic script)';
      case 'Gujarati':
        return 'Gujarati (Gujarati script)';
      case 'Kannada':
        return 'Kannada (Kannada script)';
      case 'Odia':
        return 'Odia (Odia script)';
      case 'Malayalam':
        return 'Malayalam (Malayalam script)';
      case 'Punjabi':
        return 'Punjabi (Gurmukhi script)';
      case 'Assamese':
        return 'Assamese (Assamese/Bengali script)';
      case 'Maithili':
        return 'Maithili (Devanagari script)';
      case 'Santali':
        return 'Santali (Ol Chiki script preferred)';
      case 'Kashmiri':
        return 'Kashmiri (Perso-Arabic script)';
      case 'Nepali':
        return 'Nepali (Devanagari script)';
      case 'Konkani':
        return 'Konkani (Devanagari script)';
      case 'Sindhi':
        return 'Sindhi (Perso-Arabic script)';
      case 'Dogri':
        return 'Dogri (Devanagari script)';
      case 'Manipuri':
        return 'Manipuri/Meitei (Meitei Mayek preferred)';
      case 'Bodo':
        return 'Bodo (Devanagari script)';
      case 'Sanskrit':
        return 'Sanskrit (Devanagari script)';
      case 'English':
      default:
        return 'English';
    }
  }
}

class MedicalChatMessage {
  const MedicalChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}


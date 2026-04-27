import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:medicare_ai/services/openrouter_medical_ai_service.dart';

class MedicineImageAnalysis {
  const MedicineImageAnalysis({
    required this.extractedText,
    required this.answer,
  });

  final String extractedText;
  final String answer;
}

class MedicineImageAiService {
  MedicineImageAiService({OpenRouterMedicalAiService? aiService})
    : _aiService = aiService ?? OpenRouterMedicalAiService();

  final OpenRouterMedicalAiService _aiService;

  Future<MedicineImageAnalysis> analyzeImage({
    required String imagePath,
    String outputLanguage = 'English',
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      final extracted = recognized.text.trim();
      if (extracted.length < 3) {
        throw const MedicineImageAiException(
          'I could not read enough text from this image. Retake the photo with the medicine name, strength, and strip/box label clearly visible.',
        );
      }

      final answer = await _aiService.ask(
        outputLanguage: outputLanguage,
        history: [
          MedicalChatMessage(role: 'user', content: _buildPrompt(extracted)),
        ],
      );
      return MedicineImageAnalysis(extractedText: extracted, answer: answer);
    } finally {
      await recognizer.close();
    }
  }

  String _buildPrompt(String extractedText) {
    return '''
You are Medi AI, a careful medicine-label assistant for patients.

The user photographed a medicine strip/box. OCR extracted this visible text:

"""
$extractedText
"""

Give a professional, patient-friendly explanation in Markdown.

Rules:
- Do not claim certainty if the label text is incomplete or ambiguous.
- Identify the most likely medicine name, strength, and active ingredient if visible.
- Explain common use in simple terms.
- Explain general timing guidance only: e.g. "often after food", "as prescribed", "do not double dose". Do not invent a prescription schedule.
- Include who should avoid it or ask a doctor/pharmacist first.
- Include urgent warning signs.
- Tell the patient to follow their doctor/pharmacist and the original label.

Use exactly these bold section headings:
**Likely medicine**
**What it is used for**
**When to take**
**Who should not take it / caution**
**Important warnings**
**Next step**
''';
  }
}

class MedicineImageAiException implements Exception {
  const MedicineImageAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicare_ai/services/medicine_image_ai_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

class MedicineScannerScreen extends StatefulWidget {
  const MedicineScannerScreen({super.key});

  @override
  State<MedicineScannerScreen> createState() => _MedicineScannerScreenState();
}

class _MedicineScannerScreenState extends State<MedicineScannerScreen> {
  final _picker = ImagePicker();
  final _service = MedicineImageAiService();

  XFile? _image;
  MedicineImageAnalysis? _analysis;
  bool _loading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_loading) {
      return;
    }
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _image = picked;
      _analysis = null;
      _error = null;
      _loading = true;
    });

    try {
      final result = await _service.analyzeImage(imagePath: picked.path);
      if (!mounted) {
        return;
      }
      setState(() {
        _analysis = result;
        _loading = false;
      });
    } on MedicineImageAiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Unable to analyze this medicine image right now. $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan medicine')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _HeroInstructionCard(colorScheme: cs),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Open camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_image != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(_image!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              'Reading the label and asking Medi AI…',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _StatusCard(
              icon: Icons.error_outline_rounded,
              title: 'Could not analyze image',
              body: _error!,
              color: cs.error,
            ),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 16),
            _AnalysisCard(analysis: _analysis!),
          ],
        ],
      ),
    );
  }
}

class _HeroInstructionCard extends StatelessWidget {
  const _HeroInstructionCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.portalX.ctaStart, context.portalX.ctaEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.document_scanner_rounded, color: Colors.white, size: 30),
            SizedBox(height: 12),
            Text(
              'Scan a medicine label',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Take a clear photo of the strip or box. Medi AI reads visible text and explains likely use, timing, and safety cautions.',
              style: TextStyle(color: Colors.white, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});

  final MedicineImageAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medi AI explanation',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                MarkdownBody(
                  data: analysis.answer,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: const TextStyle(height: 1.45, fontSize: 14),
                        strong: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: const Text('Text read from image'),
          subtitle: const Text(
            'Use this to verify the label was read correctly.',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                analysis.extractedText,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'This is not a prescription. Always follow your doctor, pharmacist, and the medicine label.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:medicare_ai/models/open_fda_drug_label.dart';
import 'package:medicare_ai/services/open_fda_service.dart';

/// Search U.S. FDA drug product labels via openFDA (reference only).
class OpenFdaDrugLabelScreen extends StatefulWidget {
  const OpenFdaDrugLabelScreen({
    super.key,
    this.initialQuery = '',
    this.initialLabel,
  });

  final String initialQuery;
  final OpenFdaDrugLabel? initialLabel;

  @override
  State<OpenFdaDrugLabelScreen> createState() => _OpenFdaDrugLabelScreenState();
}

class _OpenFdaDrugLabelScreenState extends State<OpenFdaDrugLabelScreen> {
  late final TextEditingController _controller;
  bool _loading = false;
  OpenFdaDrugLabel? _label;
  String? _error;
  String? _notFound;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialLabel != null) {
      _label = widget.initialLabel;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _error = 'Enter a brand or generic name (e.g. Advil, ibuprofen).';
        _label = null;
        _notFound = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notFound = null;
      _label = null;
    });
    try {
      final result = await OpenFdaService.findLabelByName(q);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        if (result == null) {
          _notFound = 'No label matched that search. openFDA may not list every product; try a simpler name.';
          _label = null;
        } else {
          _label = result;
        }
      });
    } on OpenFdaException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('openFDA label search'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _FdaDisclaimerBanner(colorScheme: cs),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Brand or generic name',
              hintText: 'e.g. Advil, metformin',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _search,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Search openFDA'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: cs.error),
            ),
          ],
          if (_notFound != null) ...[
            const SizedBox(height: 12),
            Text(_notFound!),
          ],
          if (_label != null) ...[
            const SizedBox(height: 20),
            _LabelDetails(label: _label!),
          ],
        ],
      ),
    );
  }
}

class _FdaDisclaimerBanner extends StatelessWidget {
  const _FdaDisclaimerBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gavel_rounded, size: 22, color: colorScheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'U.S. FDA public data (openFDA). This app is not operated or endorsed by the U.S. Food and Drug Administration. Content is for reference only, may be incomplete, and is not a substitute for your own medicine label or a licensed clinician. Always follow your prescriber and the official labeling for your product.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelDetails extends StatelessWidget {
  const _LabelDetails({required this.label});

  final OpenFdaDrugLabel label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.brandNames.isNotEmpty) _Section('Brand name (openFDA)', label.brandNames.join(', ')),
        if (label.genericNames.isNotEmpty) _Section('Generic name (openFDA)', label.genericNames.join(', ')),
        if (label.manufacturerNames.isNotEmpty)
          _Section('Manufacturer (openFDA)', label.manufacturerNames.join(', ')),
        if (label.purpose != null) _Section('Purpose (OTC, if present)', label.purpose!),
        if (label.indicationsAndUsage != null)
          _Section('Indications and usage', label.indicationsAndUsage!),
        if (label.contraindications != null) _Section('Contraindications', label.contraindications!),
        if (label.warnings != null) _Section('Warnings', label.warnings!),
        if (label.boxedWarning != null) _Section('Boxed warning', label.boxedWarning!),
        if (label.drugInteractions != null) _Section('Drug interactions', label.drugInteractions!),
        if (label.adverseReactions != null) _Section('Adverse reactions', label.adverseReactions!),
        if (label.dosageAndAdministration != null)
          _Section('Dosage and administration', label.dosageAndAdministration!),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: const TextStyle(height: 1.4, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

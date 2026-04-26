import 'package:flutter/material.dart';
import 'package:medicare_ai/data/condition_reference_service.dart';
import 'package:medicare_ai/models/condition_reference_entry.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

/// Educational condition library: pick a name (e.g. blood sugar) and read general guidance.
/// Not a substitute for a prescription or your doctor's plan.
class ConditionReferenceScreen extends StatefulWidget {
  const ConditionReferenceScreen({super.key});

  @override
  State<ConditionReferenceScreen> createState() => _ConditionReferenceScreenState();
}

class _ConditionReferenceScreenState extends State<ConditionReferenceScreen> {
  late Future<ConditionReferenceBundle> _future;
  ConditionReferenceEntry? _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = ConditionReferenceService.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<ConditionReferenceBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Health reference')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load reference data: ${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Health reference')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final bundle = snapshot.data!;
        final list = _filtered(bundle.conditions);
        if (_selected == null && list.isNotEmpty) {
          _selected = list.first;
        } else if (_selected != null && !list.contains(_selected)) {
          _selected = list.isNotEmpty ? list.first : null;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Health reference'),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _search = '';
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                tooltip: 'Clear search',
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _DisclaimerBanner(text: bundle.disclaimer),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search (e.g. sugar, diabetes, BP…)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ConditionDropdown(
                  items: list,
                  value: _selected,
                  onChanged: (c) => setState(() => _selected = c),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _selected == null
                    ? Center(
                        child: Text(
                          list.isEmpty ? 'No matches. Try another search term.' : 'Pick a condition.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        child: _EntryBody(entry: _selected!),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ConditionReferenceEntry> _filtered(List<ConditionReferenceEntry> all) {
    if (_search.isEmpty) {
      return all;
    }
    return all
        .where(
          (e) =>
              e.displayName.toLowerCase().contains(_search) ||
              e.id.contains(_search) ||
              e.keywords.any((k) => k.contains(_search)) ||
              e.summary.toLowerCase().contains(_search),
        )
        .toList();
  }
}

class _ConditionDropdown extends StatelessWidget {
  const _ConditionDropdown({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<ConditionReferenceEntry> items;
  final ConditionReferenceEntry? value;
  final ValueChanged<ConditionReferenceEntry?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Condition',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ConditionReferenceEntry>(
          isExpanded: true,
          value: v != null && items.contains(v) ? v : items.first,
          items: [
            for (final e in items)
              DropdownMenuItem(
                value: e,
                child: Text(
                  e.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (e) => onChanged(e),
        ),
      ),
    );
  }
}

class _EntryBody extends StatelessWidget {
  const _EntryBody({required this.entry});

  final ConditionReferenceEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.displayName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _Section(
          title: 'Overview',
          child: Text(entry.summary, style: TextStyle(height: 1.45, color: cs.onSurface)),
        ),
        if (entry.selfCare.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Self-care & lifestyle',
            child: _BulletList(lines: entry.selfCare),
          ),
        ],
        if (entry.medicationNote.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'About medicines (general)',
            child: Text(
              entry.medicationNote,
              style: TextStyle(height: 1.45, color: cs.onSurface),
            ),
          ),
        ],
        if (entry.medicationClasses.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...entry.medicationClasses.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MedicationClassCard(name: c.name, typicalUse: c.typicalUse),
            ),
          ),
        ],
        if (entry.whenToSeeDoctor.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Section(
            title: 'When to see a doctor',
            child: _BulletList(lines: entry.whenToSeeDoctor),
          ),
        ],
      ],
    );
  }
}

class _MedicationClassCard extends StatelessWidget {
  const _MedicationClassCard({
    required this.name,
    required this.typicalUse,
  });

  final String name;
  final String typicalUse;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text(typicalUse, style: TextStyle(height: 1.4, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.medicareColorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('· ', style: TextStyle(color: c, fontWeight: FontWeight.w800)),
                Expanded(
                  child: Text(line, style: TextStyle(height: 1.45, color: c)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

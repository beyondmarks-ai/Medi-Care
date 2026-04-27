import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medicare_ai/data/pharmacy_catalog_loader.dart';
import 'package:medicare_ai/models/open_fda_drug_label.dart';
import 'package:medicare_ai/models/pharmacy_product.dart';
import 'package:medicare_ai/screens/open_fda_drug_label_screen.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/doctor_pharmacy_send_service.dart';
import 'package:medicare_ai/services/open_fda_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

/// Send a line item to a patient's in-app pharmacy cart: from the bundled
/// catalog **or** from a U.S. FDA product label (openFDA), with key label
/// excerpts for the doctor before sending.
class DoctorSendPharmacyScreen extends StatefulWidget {
  const DoctorSendPharmacyScreen({super.key, this.preSelectedPatient});

  final PatientProfile? preSelectedPatient;

  @override
  State<DoctorSendPharmacyScreen> createState() =>
      _DoctorSendPharmacyScreenState();
}

class _DoctorSendPharmacyScreenState extends State<DoctorSendPharmacyScreen> {
  late Future<List<PharmacyProduct>> _catalog;
  String _qCatalog = '';
  String _qFda = '';
  Timer? _fdaDebounce;
  List<OpenFdaDrugLabel> _fdaLabels = const [];
  bool _fdaLoading = false;
  String? _fdaError;
  int _fdaSeq = 0;

  /// 0 = app catalog, 1 = U.S. FDA (openFDA).
  int _source = 0;

  PatientProfile? _patient;
  final Set<String> _selectedCatalogIds = <String>{};
  final List<OpenFdaDrugLabel> _selectedFdaList = <OpenFdaDrugLabel>[];
  final Map<String, int> _lineQtyByKey = <String, int>{};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _catalog = PharmacyCatalogLoader.load();
    _patient = widget.preSelectedPatient;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_patient != null) {
        return;
      }
      final doc = CareAssignmentService.instance.activeDoctor;
      if (doc == null) {
        return;
      }
      final list = CareAssignmentService.instance.patientsForDoctor(doc.id);
      if (list.isNotEmpty) {
        setState(() => _patient = list.first);
      }
    });
  }

  @override
  void dispose() {
    _fdaDebounce?.cancel();
    super.dispose();
  }

  void _onFdaQueryChanged(String v) {
    setState(() => _qFda = v);
    _fdaDebounce?.cancel();
    final t = v.trim();
    if (t.length < 2) {
      setState(() {
        _fdaLabels = const [];
        _fdaError = null;
        _fdaLoading = false;
      });
      return;
    }
    setState(() {
      _fdaLoading = true;
      _fdaError = null;
    });
    _fdaDebounce = Timer(const Duration(milliseconds: 500), () async {
      final id = ++_fdaSeq;
      if (!mounted) {
        return;
      }
      try {
        final list = await OpenFdaService.searchLabels(t, limit: 10);
        if (!mounted || id != _fdaSeq) {
          return;
        }
        setState(() {
          _fdaLoading = false;
          _fdaLabels = list;
        });
      } on OpenFdaException catch (e) {
        if (!mounted || id != _fdaSeq) {
          return;
        }
        setState(() {
          _fdaLoading = false;
          _fdaError = e.message;
          _fdaLabels = const [];
        });
      } catch (e) {
        if (!mounted || id != _fdaSeq) {
          return;
        }
        setState(() {
          _fdaLoading = false;
          _fdaError = e.toString();
          _fdaLabels = const [];
        });
      }
    });
  }

  static bool _sameFdaLabel(OpenFdaDrugLabel a, OpenFdaDrugLabel b) {
    return _fdaKey(a) == _fdaKey(b);
  }

  static String _catalogSelectionKey(PharmacyProduct p) {
    return [
      p.id,
      p.name,
      p.composition ?? '',
      p.manufacturer ?? '',
      p.packSize ?? '',
      p.form ?? '',
      p.price?.toStringAsFixed(2) ?? '',
    ].join('|').toLowerCase();
  }

  static String _fdaKey(OpenFdaDrugLabel l) {
    return [
      l.displayTitle,
      l.genericNames.join(','),
      l.manufacturerNames.join(','),
      l.indicationsAndUsage ?? '',
      l.contraindications ?? '',
    ].join('|').toLowerCase();
  }

  List<PharmacyProduct> _filterCatalog(List<PharmacyProduct> all) {
    final s = _qCatalog.trim().toLowerCase();
    if (s.isEmpty) {
      return all;
    }
    return all
        .where(
          (p) =>
              p.name.toLowerCase().contains(s) ||
              (p.composition != null &&
                  p.composition!.toLowerCase().contains(s)),
        )
        .toList();
  }

  PharmacyProduct _pharmacyProductFromFda(OpenFdaDrugLabel l) {
    return PharmacyProduct(
      id: _stableFdaLineId(l),
      name: l.displayTitle,
      category: 'U.S. FDA label (openFDA)',
      manufacturer: l.manufacturerNames.isNotEmpty
          ? l.manufacturerNames.first
          : null,
      description: _ellipSize(l.indicationsAndUsage ?? l.purpose, 400),
      extra: {
        'source': 'openFDA U.S. drug label (reference only)',
        if (l.genericNames.isNotEmpty)
          'generic': l.genericNames.take(4).join(', '),
      },
    );
  }

  String _stableFdaLineId(OpenFdaDrugLabel l) {
    final s = _fdaKey(l).trim();
    if (s.isEmpty) {
      return 'openfda_${l.hashCode & 0x7fffffff}';
    }
    return 'openfda_${s.hashCode & 0x7fffffff}';
  }

  String? _ellipSize(String? s, int max) {
    if (s == null) {
      return null;
    }
    final t = s.trim();
    if (t.isEmpty) {
      return null;
    }
    if (t.length <= max) {
      return t;
    }
    return '${t.substring(0, max)}…';
  }

  String _sectionOrPlaceholder(String? body) {
    final t = body?.trim();
    if (t == null || t.isEmpty) {
      return 'Not present in this label excerpt. Open the full U.S. FDA label to review.';
    }
    return t;
  }

  void _toggleCatalogId(String id) {
    setState(() {
      if (_selectedCatalogIds.contains(id)) {
        _selectedCatalogIds.remove(id);
        _lineQtyByKey.remove(id);
      } else {
        _selectedCatalogIds.add(id);
        _lineQtyByKey[id] = _lineQtyByKey[id] ?? 1;
      }
    });
  }

  void _toggleFda(OpenFdaDrugLabel l) {
    setState(() {
      final i = _selectedFdaList.indexWhere((s) => _sameFdaLabel(s, l));
      final key = _fdaKey(l);
      if (i >= 0) {
        _selectedFdaList.removeAt(i);
        _lineQtyByKey.remove(key);
      } else {
        _selectedFdaList.add(l);
        _lineQtyByKey[key] = _lineQtyByKey[key] ?? 1;
      }
    });
  }

  bool _isFdaSelected(OpenFdaDrugLabel l) =>
      _selectedFdaList.any((s) => _sameFdaLabel(s, l));

  int get _selectedCount =>
      _source == 0 ? _selectedCatalogIds.length : _selectedFdaList.length;

  int _qtyFor(String key) => _lineQtyByKey[key] ?? 1;

  void _changeQty(String key, int delta) {
    setState(() {
      final next = (_lineQtyByKey[key] ?? 1) + delta;
      _lineQtyByKey[key] = next < 1 ? 1 : next;
    });
  }

  List<PharmacyProduct> _selectedCatalogProducts(List<PharmacyProduct> all) {
    return [
      for (final p in all)
        if (_selectedCatalogIds.contains(_catalogSelectionKey(p))) p,
    ];
  }

  Future<void> _send() async {
    List<DoctorMedicineSendLine> lines;
    if (_source == 0) {
      final all = await _catalog;
      if (!mounted) {
        return;
      }
      lines = [
        for (final p in _selectedCatalogProducts(all))
          DoctorMedicineSendLine(
            product: p,
            quantity: _qtyFor(_catalogSelectionKey(p)),
          ),
      ];
    } else {
      lines = [
        for (final l in _selectedFdaList)
          DoctorMedicineSendLine(
            product: _pharmacyProductFromFda(l),
            quantity: _qtyFor(_fdaKey(l)),
          ),
      ];
    }
    if (!mounted) {
      return;
    }
    if (_patient == null || lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _source == 0
                ? 'Choose a patient and at least one item from the app catalog (use the checkboxes).'
                : 'Choose a patient and at least one U.S. FDA label (use the checkboxes), or search again.',
          ),
        ),
      );
      return;
    }
    final uid = CareAssignmentService.instance.patientUidById(_patient!.id);
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patient is not linked to a login yet. They must use the app once after signup.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await DoctorPharmacySendService.sendMedicineLinesToPatient(
        patientUid: uid,
        patientId: _patient!.id,
        lines: lines,
      );
      if (!mounted) {
        return;
      }
      final sample = lines.length == 1
          ? '${lines.first.product.name} (×${lines.first.quantity})'
          : '${lines.length} items';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent $sample to ${_patient!.name}’s pharmacy cart.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().toLowerCase().contains('permission-denied')
                ? 'Could not write to the server. Ask your admin to deploy the latest Firestore rules for “doctor_pharmacy_sends” and sign in again.'
                : '$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    final doc = CareAssignmentService.instance.activeDoctor;
    final patients = doc == null
        ? <PatientProfile>[]
        : CareAssignmentService.instance.patientsForDoctor(doc.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create prescription'),
        actions: [
          IconButton(
            tooltip: 'Open full U.S. FDA label search',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OpenFdaDrugLabelScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: patients.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No assigned patients. Assign a patient in signup flow first.',
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final effectivePatient =
                    _patient != null &&
                        patients.any((e) => e.id == _patient!.id)
                    ? _patient!
                    : patients.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<PatientProfile>(
                            // ignore: deprecated_member_use
                            value: effectivePatient,
                            decoration: const InputDecoration(
                              labelText: 'Patient',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final p in patients)
                                DropdownMenuItem<PatientProfile>(
                                  value: p,
                                  child: Text('${p.name} (${p.id})'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _patient = v),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(
                                value: 0,
                                label: Text('Medicine catalog'),
                                icon: Icon(
                                  Icons.medication_liquid_outlined,
                                  size: 18,
                                ),
                              ),
                              ButtonSegment(
                                value: 1,
                                label: Text('FDA reference'),
                                icon: Icon(Icons.gavel_outlined, size: 18),
                              ),
                            ],
                            selected: {_source},
                            onSelectionChanged: (s) {
                              setState(() {
                                _source = s.first;
                                if (_source == 0) {
                                  for (final l in _selectedFdaList) {
                                    _lineQtyByKey.remove(_fdaKey(l));
                                  }
                                  _selectedFdaList.clear();
                                } else {
                                  for (final key in _selectedCatalogIds) {
                                    _lineQtyByKey.remove(key);
                                  }
                                  _selectedCatalogIds.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _source == 0
                          ? FutureBuilder<List<PharmacyProduct>>(
                              future: _catalog,
                              builder: (context, snap) {
                                if (snap.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        'Could not load catalog: ${snap.error}',
                                      ),
                                    ),
                                  );
                                }
                                if (!snap.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final list = _filterCatalog(snap.data!)
                                  ..sort((a, b) => a.name.compareTo(b.name));
                                final draftProducts = _selectedCatalogProducts(
                                  snap.data!,
                                );
                                return ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    8,
                                  ),
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'Search medicine catalog',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                        hintText: 'Name or composition',
                                      ),
                                      onChanged: (v) =>
                                          setState(() => _qCatalog = v),
                                    ),
                                    if (draftProducts.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _PrescriptionDraftCard(
                                        title: 'Prescription draft',
                                        subtitle:
                                            'Set quantity per medicine, then send all at once.',
                                        rows: [
                                          for (final p in draftProducts)
                                            _DraftLineRow(
                                              keyId: _catalogSelectionKey(p),
                                              title: p.name,
                                              subtitle: p.displaySubtitle,
                                              quantity: _qtyFor(
                                                _catalogSelectionKey(p),
                                              ),
                                              onMinus: () => _changeQty(
                                                _catalogSelectionKey(p),
                                                -1,
                                              ),
                                              onPlus: () => _changeQty(
                                                _catalogSelectionKey(p),
                                                1,
                                              ),
                                              onRemove: () => _toggleCatalogId(
                                                _catalogSelectionKey(p),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Catalog matches (${list.length}) · ${_selectedCatalogIds.length} selected',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: list.isEmpty
                                              ? null
                                              : () => setState(() {
                                                  for (final p in list) {
                                                    final key =
                                                        _catalogSelectionKey(p);
                                                    _selectedCatalogIds.add(
                                                      key,
                                                    );
                                                    _lineQtyByKey[key] =
                                                        _lineQtyByKey[key] ?? 1;
                                                  }
                                                }),
                                          child: const Text('Select all'),
                                        ),
                                        TextButton(
                                          onPressed: _selectedCatalogIds.isEmpty
                                              ? null
                                              : () => setState(() {
                                                  for (final key
                                                      in _selectedCatalogIds) {
                                                    _lineQtyByKey.remove(key);
                                                  }
                                                  _selectedCatalogIds.clear();
                                                }),
                                          child: const Text('Clear'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    for (final p in list)
                                      CheckboxListTile(
                                        value: _selectedCatalogIds.contains(
                                          _catalogSelectionKey(p),
                                        ),
                                        onChanged: (_) => _toggleCatalogId(
                                          _catalogSelectionKey(p),
                                        ),
                                        title: Text(
                                          p.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          p.displaySubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                  ],
                                );
                              },
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                              children: [
                                TextField(
                                  onChanged: _onFdaQueryChanged,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Search U.S. FDA labels (openFDA)',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                    hintText:
                                        'e.g. metformin, ibuprofen, atorvastatin (min. 2 letters)',
                                  ),
                                ),
                                if (_qFda.trim().length >= 2 &&
                                    _fdaLoading) ...[
                                  const SizedBox(height: 12),
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Querying openFDA…',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (_fdaError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _fdaError!,
                                    style: TextStyle(
                                      color: cs.error,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (_qFda.trim().length < 2) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Search FDA label text for reference. Check medicines to add them to the prescription draft.',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (_selectedFdaList.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _PrescriptionDraftCard(
                                    title: 'Prescription draft',
                                    subtitle:
                                        'Set quantity per FDA label, then send all at once.',
                                    rows: [
                                      for (final l in _selectedFdaList)
                                        _DraftLineRow(
                                          keyId: _fdaKey(l),
                                          title: l.displayTitle,
                                          subtitle: l.genericNames.isNotEmpty
                                              ? 'Generic: ${l.genericNames.take(2).join(', ')}'
                                              : 'U.S. FDA label',
                                          quantity: _qtyFor(_fdaKey(l)),
                                          onMinus: () =>
                                              _changeQty(_fdaKey(l), -1),
                                          onPlus: () =>
                                              _changeQty(_fdaKey(l), 1),
                                          onRemove: () => _toggleFda(l),
                                        ),
                                    ],
                                  ),
                                ],
                                if (_fdaLabels.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'openFDA results (${_fdaLabels.length}) · ${_selectedFdaList.length} selected',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _fdaLabels.isEmpty
                                            ? null
                                            : () => setState(() {
                                                for (final l in _fdaLabels) {
                                                  if (!_isFdaSelected(l)) {
                                                    _selectedFdaList.add(l);
                                                    _lineQtyByKey[_fdaKey(l)] =
                                                        _lineQtyByKey[_fdaKey(
                                                          l,
                                                        )] ??
                                                        1;
                                                  }
                                                }
                                              }),
                                        child: const Text('Select all'),
                                      ),
                                      TextButton(
                                        onPressed: _selectedFdaList.isEmpty
                                            ? null
                                            : () => setState(() {
                                                for (final l
                                                    in _selectedFdaList) {
                                                  _lineQtyByKey.remove(
                                                    _fdaKey(l),
                                                  );
                                                }
                                                _selectedFdaList.clear();
                                              }),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                for (final l in _fdaLabels)
                                  CheckboxListTile(
                                    value: _isFdaSelected(l),
                                    onChanged: (_) => _toggleFda(l),
                                    title: Text(
                                      l.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      l.genericNames.isNotEmpty
                                          ? 'Generic: ${l.genericNames.take(2).join(', ')}'
                                          : _ellipSize(
                                                  l.indicationsAndUsage,
                                                  80,
                                                ) ??
                                                'Check to add; details below',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                if (_qFda.trim().length >= 2 &&
                                    !_fdaLoading &&
                                    _fdaError == null &&
                                    _fdaLabels.isEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'No openFDA match. Try a U.S. brand or generic; check spelling, or use App catalog for items in the bundled list.',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (_selectedFdaList.length == 1) ...[
                                  const SizedBox(height: 16),
                                  _FdaSelectionPreview(
                                    label: _selectedFdaList.first,
                                    colorScheme: cs,
                                    onOpenFull: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              OpenFdaDrugLabelScreen(
                                                initialLabel:
                                                    _selectedFdaList.first,
                                                initialQuery: _selectedFdaList
                                                    .first
                                                    .displayTitle,
                                              ),
                                        ),
                                      );
                                    },
                                    sectionText: _sectionOrPlaceholder,
                                    ellipSize: _ellipSize,
                                  ),
                                ] else if (_selectedFdaList.length > 1) ...[
                                  const SizedBox(height: 16),
                                  _FdaMultiSelectionSummary(
                                    labels: _selectedFdaList,
                                    colorScheme: cs,
                                    onOpenOne: (label) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              OpenFdaDrugLabelScreen(
                                                initialLabel: label,
                                                initialQuery:
                                                    label.displayTitle,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: FilledButton(
                          onPressed: _sending ? null : _send,
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _selectedCount == 0
                                      ? 'Send to patient cart'
                                      : 'Send $_selectedCount medicine(s) to cart',
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PrescriptionDraftCard extends StatelessWidget {
  const _PrescriptionDraftCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_DraftLineRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _DraftLineRow extends StatelessWidget {
  const _DraftLineRow({
    required this.keyId,
    required this.title,
    required this.subtitle,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final String keyId;
  final String title;
  final String subtitle;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey(keyId),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: quantity > 1 ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _FdaMultiSelectionSummary extends StatelessWidget {
  const _FdaMultiSelectionSummary({
    required this.labels,
    required this.colorScheme,
    required this.onOpenOne,
  });

  final List<OpenFdaDrugLabel> labels;
  final ColorScheme colorScheme;
  final void Function(OpenFdaDrugLabel) onOpenOne;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${labels.length} U.S. FDA labels selected',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Each will be queued to the patient’s cart as its own line. Set quantities in the draft above; for full “uses / do not use” text, open a label from the list.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final l in labels) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: l.genericNames.isNotEmpty
                    ? Text('Generic: ${l.genericNames.take(2).join(', ')}')
                    : null,
                trailing: TextButton(
                  onPressed: () => onOpenOne(l),
                  child: const Text('Full label'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FdaSelectionPreview extends StatelessWidget {
  const _FdaSelectionPreview({
    required this.label,
    required this.colorScheme,
    required this.onOpenFull,
    required this.sectionText,
    required this.ellipSize,
  });

  final OpenFdaDrugLabel label;
  final ColorScheme colorScheme;
  final VoidCallback onOpenFull;
  final String Function(String? body) sectionText;
  final String? Function(String? s, int max) ellipSize;

  @override
  Widget build(BuildContext context) {
    final uses = label.indicationsAndUsage ?? label.purpose;
    final notFor = label.contraindications;
    final warn = [
      if (label.boxedWarning != null && label.boxedWarning!.trim().isNotEmpty)
        label.boxedWarning!,
      if (label.warnings != null && label.warnings!.trim().isNotEmpty)
        label.warnings!,
    ].join('\n\n');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Label excerpts — ${label.displayTitle}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'What it is used for',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              sectionText(ellipSize(uses, 1200)),
              style: const TextStyle(height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Who should not use it / contraindications (when in label)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.tertiary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              sectionText(ellipSize(notFor, 1200)),
              style: const TextStyle(height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'Boxed / general warnings (may also describe risks)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              sectionText(ellipSize(warn.isEmpty ? null : warn, 2000)),
              style: const TextStyle(height: 1.35, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenFull,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open full U.S. FDA label in app'),
            ),
          ],
        ),
      ),
    );
  }
}

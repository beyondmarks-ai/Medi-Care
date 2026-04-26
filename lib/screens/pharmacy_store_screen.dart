import 'dart:async';

import 'package:flutter/material.dart';
import 'package:medicare_ai/data/pharmacy_catalog_loader.dart';
import 'package:medicare_ai/models/open_fda_drug_label.dart';
import 'package:medicare_ai/models/pharmacy_product.dart';
import 'package:medicare_ai/screens/open_fda_drug_label_screen.dart';
import 'package:medicare_ai/services/open_fda_service.dart';
import 'package:medicare_ai/services/pharmacy_cart_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

/// Browse products from the bundled CSV (replace with your Kaggle export in assets).
class PharmacyStoreScreen extends StatefulWidget {
  const PharmacyStoreScreen({super.key});

  @override
  State<PharmacyStoreScreen> createState() => _PharmacyStoreScreenState();
}

class _PharmacyStoreScreenState extends State<PharmacyStoreScreen> {
  late Future<List<PharmacyProduct>> _future;
  String _search = '';
  String? _category; // null = all
  final _cart = PharmacyCartService.instance;
  Timer? _fdaDebounce;
  List<OpenFdaDrugLabel> _fdaLabels = const [];
  bool _fdaLoading = false;
  String? _fdaError;
  int _fdaSeq = 0;

  @override
  void initState() {
    super.initState();
    _future = PharmacyCatalogLoader.load();
    _cart.addListener(_onCart);
  }

  @override
  void dispose() {
    _fdaDebounce?.cancel();
    _cart.removeListener(_onCart);
    super.dispose();
  }

  void _onSearchTextChanged(String v) {
    setState(() => _search = v);
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
    _fdaDebounce = Timer(const Duration(milliseconds: 500), () async {
      final id = ++_fdaSeq;
      if (!mounted) {
        return;
      }
      setState(() {
        _fdaLoading = true;
        _fdaError = null;
      });
      try {
        final list = await OpenFdaService.searchLabels(t, limit: 6);
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

  void _onCart() {
    if (mounted) {
      setState(() {});
    }
  }

  List<PharmacyProduct> _filter(List<PharmacyProduct> all) {
    final q = _search.toLowerCase();
    return all.where((p) {
      if (_category != null) {
        final c = p.category;
        if (c == null || c != _category) {
          return false;
        }
      }
      if (q.isEmpty) {
        return true;
      }
      final buf = StringBuffer()
        ..write(p.name)
        ..write(' ')
        ..write(p.displaySubtitle)
        ..write(' ')
        ..write(p.manufacturer ?? '')
        ..write(' ')
        ..write(p.description ?? '')
        ..write(' ')
        ..write(p.composition ?? '');
      for (final e in p.extra.values) {
        buf.write(' ');
        buf.write(e);
      }
      return buf.toString().toLowerCase().contains(q);
    }).toList();
  }

  Set<String> _categories(List<PharmacyProduct> all) {
    final s = <String>{};
    for (final p in all) {
      final c = p.category;
      if (c != null && c.isNotEmpty) {
        s.add(c);
      }
    }
    final list = s.toList()..sort();
    return list.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        return FutureBuilder<List<PharmacyProduct>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Pharmacy')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Could not load catalog: ${snap.error}'),
                  ),
                ),
              );
            }
            if (!snap.hasData) {
              return Scaffold(
                appBar: AppBar(title: const Text('Pharmacy')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final all = snap.data!;
            final list = _filter(all)..sort((a, b) => a.name.compareTo(b.name));
            final cats = _categories(all).toList()..sort();

            return Scaffold(
              appBar: AppBar(
                title: const Text('Pharmacy store'),
                actions: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const OpenFdaDrugLabelScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.health_and_safety_outlined),
                    tooltip: 'openFDA drug label search',
                  ),
                  IconButton(
                    onPressed: () => _openCart(context),
                    icon: Badge(
                      isLabelVisible: _cart.itemCount > 0,
                      label: Text('${_cart.itemCount}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                    tooltip: 'Cart',
                  ),
                ],
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: _InfoBanner(
                      text:
                          'The box below filters this app’s catalog and (with 2+ characters) also searches U.S. FDA product labels on openFDA. Not a prescription service. Verify with a pharmacist.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search catalog + FDA (e.g. ibuprofen, Advil) — min 2 letters for FDA',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      onChanged: _onSearchTextChanged,
                    ),
                  ),
                  if (cats.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: _category == null,
                              onSelected: (_) => setState(() => _category = null),
                            ),
                          ),
                          ...cats.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(c),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c == _category ? null : c),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: _PharmacySearchBody(
                      list: list,
                      searchTrimmed: _search.trim(),
                      selectedCategory: _category,
                      fdaLoading: _fdaLoading,
                      fdaError: _fdaError,
                      fdaLabels: _fdaLabels,
                      onProductTap: (p) => _showProductSheet(context, p),
                      onProductAdd: (p) {
                        _cart.add(p);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added: ${p.name}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scroll) {
            return ListenableBuilder(
              listenable: _cart,
              builder: (context, _) {
                if (_cart.lines.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Cart is empty. Add items from the list.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                final sub = _cart.subtotal;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Your cart',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: _cart.lines.length,
                        itemBuilder: (context, i) {
                          final line = _cart.lines[i];
                          return ListTile(
                            title: Text(
                              line.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (line.fromDoctor != null &&
                                    line.fromDoctor!.trim().isNotEmpty)
                                  Text(
                                    'Suggested by ${line.fromDoctor}',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  line.product.price != null
                                      ? '₹${line.product.price!.toStringAsFixed(2)} · ×${line.quantity}'
                                      : '×${line.quantity}',
                                ),
                              ],
                            ),
                            isThreeLine: line.fromDoctor != null &&
                                line.fromDoctor!.trim().isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    _cart.setQuantity(
                                      line.product,
                                      line.quantity - 1,
                                    );
                                  },
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _cart.setQuantity(
                                      line.product,
                                      line.quantity + 1,
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _cart.remove(line.product);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFFF4949),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Subtotal: ₹${sub.toStringAsFixed(2)} (illustration only)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Demo: orders are not processed. In production, this would go to your pharmacy or payment flow.',
                              ),
                            ),
                          );
                          _cart.clear();
                        },
                        child: const Text('Checkout (demo)'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showProductSheet(BuildContext context, PharmacyProduct p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 8,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (p.imageAsset != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      p.imageAsset!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(
                        height: 100,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  p.displaySubtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (p.manufacturer != null) ...[
                  const SizedBox(height: 8),
                  Text('Manufacturer: ${p.manufacturer!}'),
                ],
                if (p.packSize != null) ...[
                  const SizedBox(height: 4),
                  Text('Pack: ${p.packSize!}'),
                ],
                if (p.composition != null) ...[
                  const SizedBox(height: 8),
                  Text('Composition: ${p.composition!}'),
                ],
                if (p.description != null) ...[
                  const SizedBox(height: 8),
                  Text(p.description!),
                ],
                if (p.price != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '₹${p.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (p.extra.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Additional fields', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...p.extra.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value}'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => OpenFdaDrugLabelScreen(
                          initialQuery: p.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.health_and_safety_outlined, size: 20),
                  label: const Text('openFDA label (U.S. FDA data)'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    _cart.add(p);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added: ${p.name}')),
                    );
                  },
                  child: const Text('Add to cart'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _displayFdaName(OpenFdaDrugLabel b) {
  if (b.brandNames.isNotEmpty) {
    return b.brandNames.first;
  }
  if (b.genericNames.isNotEmpty) {
    return b.genericNames.first;
  }
  return '';
}

class _PharmacySearchBody extends StatelessWidget {
  const _PharmacySearchBody({
    required this.list,
    required this.searchTrimmed,
    required this.selectedCategory,
    required this.fdaLoading,
    required this.fdaError,
    required this.fdaLabels,
    required this.onProductTap,
    required this.onProductAdd,
  });

  final List<PharmacyProduct> list;
  final String searchTrimmed;
  final String? selectedCategory;
  final bool fdaLoading;
  final String? fdaError;
  final List<OpenFdaDrugLabel> fdaLabels;
  final void Function(PharmacyProduct) onProductTap;
  final void Function(PharmacyProduct) onProductAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      children: [
        if (list.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'In-app catalog',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProductTile(
              product: p,
              onTap: () => onProductTap(p),
              onAdd: () => onProductAdd(p),
            ),
          ),
        if (fdaLoading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                children: [
                  Text('Loading openFDA…'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ],
        if (fdaError != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(fdaError!, style: TextStyle(color: cs.error)),
          ),
        ],
        if (fdaLabels.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'U.S. FDA product labels (openFDA)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Regulatory text from the FDA; tap a row to read. Not a substitute for your package insert.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final label in fdaLabels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FdaResultTile(
                label: label,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => OpenFdaDrugLabelScreen(
                        initialLabel: label,
                        initialQuery: _displayFdaName(label),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
        if (list.isEmpty && !fdaLoading && fdaError == null) ...[
          if (selectedCategory != null && searchTrimmed.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No products in the "$selectedCategory" group in this app catalog. Clear the category or search below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ] else if (searchTrimmed.isNotEmpty && searchTrimmed.length < 2) ...[
            const SizedBox(height: 12),
            Text(
              'Type at least 2 characters to also query U.S. FDA openFDA. The in-app list still filters as you type.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ] else if (searchTrimmed.length >= 2 && fdaLabels.isEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'No in-app products and no openFDA match for that text. Try a U.S. brand or generic name (e.g. ibuprofen, Tylenol, metformin). Check spelling. openFDA does not list every product worldwide, and the sample catalog may be small.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ],
      ],
    );
  }
}

class _FdaResultTile extends StatelessWidget {
  const _FdaResultTile({required this.label, required this.onTap});

  final OpenFdaDrugLabel label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    final title = _displayFdaName(label).isEmpty ? 'FDA label' : _displayFdaName(label);
    String sub;
    if (label.genericNames.isNotEmpty) {
      sub = 'Generic: ${label.genericNames.take(2).join(', ')}';
    } else {
      final u = label.indicationsAndUsage;
      if (u != null && u.isNotEmpty) {
        sub = u.length > 120 ? '${u.substring(0, 120)}…' : u;
      } else {
        sub = 'Tap for full label text';
      }
    }
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_pharmacy_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({
    required this.product,
    required this.colorScheme,
  });

  final PharmacyProduct product;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final a = product.imageAsset;
    if (a == null) {
      return CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        a,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          return CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final PharmacyProduct product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = context.medicareColorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              _ProductThumb(product: product, colorScheme: cs),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (product.manufacturer != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.manufacturer!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (product.price != null)
                Text(
                  '₹${product.price!.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              IconButton.filledTonal(
                onPressed: onAdd,
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                tooltip: 'Add to cart',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

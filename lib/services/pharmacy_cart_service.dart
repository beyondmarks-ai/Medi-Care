import 'package:flutter/foundation.dart';

import 'package:medicare_ai/models/pharmacy_product.dart';

class CartLine {
  CartLine({
    required this.product,
    this.quantity = 1,
    this.fromDoctor,
  });

  final PharmacyProduct product;
  int quantity;
  /// Set when a clinician added this line via the doctor dashboard.
  String? fromDoctor;
}

/// In-memory cart for the demo pharmacy. Does not process payments.
class PharmacyCartService extends ChangeNotifier {
  PharmacyCartService._();
  static final PharmacyCartService instance = PharmacyCartService._();

  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);

  int get itemCount => _lines.fold(0, (a, b) => a + b.quantity);

  double? get subtotal {
    if (_lines.isEmpty) {
      return 0;
    }
    var hasPrice = false;
    double s = 0;
    for (final l in _lines) {
      final p = l.product.price;
      if (p != null) {
        hasPrice = true;
        s += p * l.quantity;
      }
    }
    if (!hasPrice) {
      return null;
    }
    return s;
  }

  void add(
    PharmacyProduct product, {
    int quantity = 1,
    String? fromDoctor,
  }) {
    for (final line in _lines) {
      if (line.product.id == product.id) {
        line.quantity += quantity;
        if (fromDoctor != null && fromDoctor.isNotEmpty) {
          line.fromDoctor = line.fromDoctor != null
              ? '${line.fromDoctor!} · $fromDoctor'
              : fromDoctor;
        }
        notifyListeners();
        return;
      }
    }
    _lines.add(
      CartLine(
        product: product,
        quantity: quantity,
        fromDoctor: fromDoctor,
      ),
    );
    notifyListeners();
  }

  void setQuantity(PharmacyProduct product, int quantity) {
    final line = _lines.where((e) => e.product.id == product.id).firstOrNull;
    if (line == null) {
      return;
    }
    if (quantity <= 0) {
      _lines.remove(line);
    } else {
      line.quantity = quantity;
    }
    notifyListeners();
  }

  void remove(PharmacyProduct product) {
    _lines.removeWhere((e) => e.product.id == product.id);
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final i = iterator;
    if (i.moveNext()) {
      return i.current;
    }
    return null;
  }
}

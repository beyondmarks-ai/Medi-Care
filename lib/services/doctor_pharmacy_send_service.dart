import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:medicare_ai/models/pharmacy_product.dart';
import 'package:medicare_ai/services/care_assignment_service.dart';
import 'package:medicare_ai/services/pharmacy_cart_service.dart';
import 'package:medicare_ai/services/app_log_service.dart';

/// Cloud queue: doctor → patient pharmacy cart. Collection [doctor_pharmacy_sends].
class DoctorPharmacySendService {
  DoctorPharmacySendService._();
  static final DoctorPharmacySendService instance =
      DoctorPharmacySendService._();

  static const _col = 'doctor_pharmacy_sends';

  final _db = FirebaseFirestore.instance;
  bool _inboxActive = false;
  String? _inboxUid;
  void Function(String message)? _onError;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;

  /// Doctor sends one catalog item to a patient's cart (arrives via [startPatientInbox]).
  static Future<void> sendMedicineToPatient({
    required String patientUid,
    required String patientId,
    required PharmacyProduct product,
    int quantity = 1,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw StateError('Not signed in');
    }
    final doctor = CareAssignmentService.instance.activeDoctor;
    if (doctor == null) {
      throw StateError('Doctor profile not loaded');
    }
    if (!CareAssignmentService.instance.canDoctorCallPatient(
      doctorId: doctor.id,
      patientId: patientId,
    )) {
      throw StateError('This patient is not assigned to you.');
    }
    if (patientUid.isEmpty) {
      throw StateError(
        'Patient account not linked. Ask them to open the app once.',
      );
    }
    if (quantity < 1) {
      quantity = 1;
    }

    await FirebaseFirestore.instance.collection(_col).add(<String, dynamic>{
      'patientUid': patientUid,
      'patientId': patientId,
      'product': product.toMap(),
      'quantity': quantity,
      'doctorId': doctor.id,
      'doctorName': doctor.name,
      'doctorAuthUid': u.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Queue several catalog / FDA line items to the same patient in one go.
  static Future<void> sendMedicinesToPatient({
    required String patientUid,
    required String patientId,
    required List<PharmacyProduct> products,
    int quantityPerLine = 1,
  }) async {
    await sendMedicineLinesToPatient(
      patientUid: patientUid,
      patientId: patientId,
      lines: [
        for (final p in products)
          DoctorMedicineSendLine(product: p, quantity: quantityPerLine),
      ],
    );
  }

  /// Queue several prescription lines to the same patient, preserving each
  /// line's quantity.
  static Future<void> sendMedicineLinesToPatient({
    required String patientUid,
    required String patientId,
    required List<DoctorMedicineSendLine> lines,
  }) async {
    final batchId = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final p = _asPrescriptionLine(line.product, batchId: batchId, index: i);
      await sendMedicineToPatient(
        patientUid: patientUid,
        patientId: patientId,
        product: p,
        quantity: line.quantity,
      );
    }
  }

  /// A doctor's prescription can contain several rows that are similar or even
  /// share a catalog/FDA id. Give each sent row its own cart id so it remains a
  /// separate prescription line instead of being merged by PharmacyCartService.
  static PharmacyProduct _asPrescriptionLine(
    PharmacyProduct p, {
    required int batchId,
    required int index,
  }) {
    return PharmacyProduct(
      id: 'doctor_send_${batchId}_${index}_${p.id}',
      name: p.name,
      category: p.category,
      subCategory: p.subCategory,
      form: p.form,
      manufacturer: p.manufacturer,
      price: p.price,
      description: p.description,
      composition: p.composition,
      packSize: p.packSize,
      imageAsset: p.imageAsset,
      extra: <String, String>{
        ...p.extra,
        'originalProductId': p.id,
        'doctorSendBatchId': '$batchId',
      },
    );
  }

  /// Call when a patient is logged in so pending doctor sends merge into [PharmacyCartService].
  void startPatientInbox({
    required String patientUid,
    void Function(String message)? onError,
  }) {
    stopPatientInbox();
    _inboxActive = true;
    _inboxUid = patientUid;
    _onError = onError;
    _inboxSub = _db
        .collection(_col)
        .where('patientUid', isEqualTo: patientUid)
        .snapshots()
        .listen(
          (snap) {
            for (final doc in snap.docs) {
              final st = doc.data()['status'] as String?;
              if (st == 'pending') {
                // ignore: unawaited_futures
                _claimAndMerge(doc);
              }
            }
          },
          onError: (Object e, StackTrace st) {
            AppLogService.instance.error('Patient pharmacy inbox', e, st);
            _onError?.call(e.toString());
          },
        );
  }

  /// Single-flight claim so the same line is not added to the cart twice.
  Future<void> _claimAndMerge(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data0 = doc.data();
    if (data0 == null) {
      return;
    }
    if ((data0['status'] as String?) != 'pending') {
      return;
    }
    final map = data0['product'];
    if (map is! Map<String, dynamic>) {
      return;
    }
    final q = (data0['quantity'] as num?)?.toInt() ?? 1;
    final who = (data0['doctorName'] as String?)?.trim() ?? 'Your doctor';
    try {
      var didMerge = false;
      await _db.runTransaction((transaction) async {
        final fresh = await transaction.get(doc.reference);
        if (!fresh.exists) {
          return;
        }
        final d = fresh.data()!;
        if (d['status'] != 'pending') {
          return;
        }
        transaction.update(doc.reference, <String, dynamic>{
          'status': 'merged',
          'mergedAt': FieldValue.serverTimestamp(),
        });
        didMerge = true;
      });
      if (!didMerge) {
        return;
      }
      final product = PharmacyProduct.fromMap(map);
      PharmacyCartService.instance.add(
        product,
        quantity: q < 1 ? 1 : q,
        fromDoctor: who,
      );
    } catch (e, st) {
      AppLogService.instance.error('Merge doctor pharmacy line', e, st);
    }
  }

  void stopPatientInbox() {
    _inboxSub?.cancel();
    _inboxSub = null;
    _inboxActive = false;
    _inboxUid = null;
    _onError = null;
  }

  bool get isInboxActive => _inboxActive;
  String? get inboxPatientUid => _inboxUid;
}

class DoctorMedicineSendLine {
  const DoctorMedicineSendLine({required this.product, required this.quantity});

  final PharmacyProduct product;
  final int quantity;
}

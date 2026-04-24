import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DocumentStorageService {
  DocumentStorageService._();

  static final DocumentStorageService instance = DocumentStorageService._();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> uploadDocument({
    required String ownerUid,
    required String role,
    required String localPath,
    required String uploadType,
  }) async {
    final file = File(localPath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final ref = _storage.ref('documents/$ownerUid/$uploadType/$fileName');
    await ref.putFile(file);
    final downloadUrl = await ref.getDownloadURL();
    await _db.collection('documents').add(<String, dynamic>{
      'ownerUid': ownerUid,
      'role': role,
      'uploadType': uploadType,
      'storagePath': ref.fullPath,
      'downloadUrl': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return downloadUrl;
  }
}

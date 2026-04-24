import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicare_ai/models/chat_message.dart';

class ChatHistoryService {
  ChatHistoryService._();

  static final ChatHistoryService instance = ChatHistoryService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messages(String uid) =>
      _db.collection('chats').doc(uid).collection('messages');

  Future<List<ChatMessageModel>> loadMessages(String uid) async {
    final query = await _messages(uid).orderBy('createdAt', descending: false).get();
    return query.docs.map(ChatMessageModel.fromDoc).toList(growable: false);
  }

  Future<void> appendMessage({
    required String uid,
    required String role,
    required String content,
    required String language,
  }) async {
    final data = ChatMessageModel(
      id: '',
      role: role,
      content: content,
      language: language,
      createdAt: DateTime.now(),
    ).toMap();
    await _messages(uid).add(data);
  }
}

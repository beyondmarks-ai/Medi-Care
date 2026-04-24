import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.language,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final String language;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'role': role,
      'content': content,
      'language': language,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static ChatMessageModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];
    final createdAt = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
    return ChatMessageModel(
      id: doc.id,
      role: (data['role'] as String?) ?? 'assistant',
      content: (data['content'] as String?) ?? '',
      language: (data['language'] as String?) ?? 'English',
      createdAt: createdAt,
    );
  }
}

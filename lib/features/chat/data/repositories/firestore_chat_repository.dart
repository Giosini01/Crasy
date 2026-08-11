import 'package:app_incontri/features/chat/domain/entities/chat_message.dart';
import 'package:app_incontri/features/chat/domain/repositories/chat_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _firestore.collection('chats').doc(chatId).collection('messages');

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _messages(chatId)
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatMessage(
                  id: doc.id,
                  senderId: doc.data()['senderId'] as String? ?? '',
                  text: doc.data()['text'] as String? ?? '',
                  sentAt: (doc.data()['sentAt'] as Timestamp?)?.toDate(),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> send({
    required String chatId,
    required String senderId,
    required String text,
  }) {
    return _messages(chatId).add({
      'senderId': senderId,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }
}

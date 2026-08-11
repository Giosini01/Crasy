import 'package:app_incontri/features/chat/domain/entities/chat_message.dart';

abstract class ChatRepository {
  /// I messaggi della conversazione, dal piu' vecchio al piu' recente.
  Stream<List<ChatMessage>> watchMessages(String chatId);

  /// Invia un messaggio. Non si modifica e non si cancella: come per il cuore
  /// e lo scarto, quello che si e' detto resta detto.
  Future<void> send({
    required String chatId,
    required String senderId,
    required String text,
  });
}

import 'package:app_incontri/core/services/firebase/firebase_providers.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/chat/data/repositories/firestore_chat_repository.dart';
import 'package:app_incontri/features/chat/domain/entities/chat_message.dart';
import 'package:app_incontri/features/chat/domain/repositories/chat_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => FirestoreChatRepository(ref.watch(firebaseFirestoreProvider)),
);

/// L'identificativo di chi sta guardando, vuoto se la sessione e' caduta.
final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState is AuthenticatedAuthState ? authState.user.id : '';
});

/// La conversazione con una persona, indicizzata sul suo identificativo.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, otherUserId) {
      final me = ref.watch(currentUserIdProvider);

      if (me.isEmpty) {
        return Stream.value(const <ChatMessage>[]);
      }

      return ref
          .watch(chatRepositoryProvider)
          .watchMessages(ChatMessage.chatIdOf(me, otherUserId));
    });

/// Invia, senza tenere stato: il campo si svuota e il messaggio compare
/// quando torna dal server, come in qualunque conversazione.
final sendMessageProvider = Provider<Future<void> Function(String, String)>((
  ref,
) {
  return (String otherUserId, String text) async {
    final me = ref.read(currentUserIdProvider);
    final trimmed = text.trim();

    if (me.isEmpty || trimmed.isEmpty) {
      return;
    }

    await ref
        .read(chatRepositoryProvider)
        .send(
          chatId: ChatMessage.chatIdOf(me, otherUserId),
          senderId: me,
          text: trimmed,
        );
  };
});

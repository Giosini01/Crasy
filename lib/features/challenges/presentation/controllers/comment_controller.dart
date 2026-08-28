import 'dart:async';

import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/data/repositories/firestore_notifications_repository.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final commentSenderProvider = Provider<CommentSender>(CommentSender.new);

/// Manda un commento, e avvisa chi e' stato nominato.
///
/// Le due cose stanno insieme e in quest'ordine: **prima il commento, poi le
/// notifiche**, e le seconde non possono far fallire il primo. Una campanella
/// che non squilla e' un peccato; un commento che sparisce perche' la
/// campanella non ha funzionato e' un bug che nessuno riesce a spiegarsi.
class CommentSender {
  const CommentSender(this._ref);

  final Ref _ref;

  /// Manda il commento. Torna `null` se e' andata, altrimenti il motivo scritto
  /// per essere letto da chi l'ha scritto.
  Future<String?> send({
    required String challengeId,
    required String entryId,
    required String text,
    List<EntryMention> mentions = const [],
    String challengeTitle = '',
  }) async {
    final scritto = text.trim();

    if (scritto.isEmpty) {
      return null;
    }

    if (scritto.length > EntryComment.maxLength) {
      return 'Al massimo ${EntryComment.maxLength} caratteri.';
    }

    // Lo stesso controllo delle consegne e delle didascalie. Un commento e'
    // testo scritto da una persona e letto da tutte le altre: non c'e' ragione
    // per cui qui debba valere una regola piu' larga.
    final rifiuto = ContentPolicy.validate(scritto);

    if (rifiuto != null) {
      return rifiuto;
    }

    final authState = _ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      return 'Sessione non valida.';
    }

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final autore = profile?.username ?? 'anonimo';

    // Solo i nominati che compaiono davvero nel testo. Fra il tocco sul
    // suggerimento e l'invio si puo' cancellare mezzo commento, e chi e' stato
    // tolto dalla riga non deve ricevere una chiamata.
    final nominati = [
      for (final mention in mentions)
        if (scritto.contains('@${mention.username}') &&
            mention.userId != authState.user.id)
          mention,
    ];

    try {
      await _ref
          .read(challengeRepositoryProvider)
          .addComment(
            challengeId: challengeId,
            entryId: entryId,
            userId: authState.user.id,
            authorName: autore,
            text: scritto,
            mentions: nominati,
          );
    } on Object catch (_) {
      return 'Commento non mandato. Riprova.';
    }

    unawaited(
      _avvisaNominati(
        nominati,
        actorId: authState.user.id,
        actorUsername: autore,
        challengeId: challengeId,
        challengeTitle: challengeTitle,
      ),
    );

    return null;
  }

  Future<void> _avvisaNominati(
    List<EntryMention> nominati, {
    required String actorId,
    required String actorUsername,
    required String challengeId,
    required String challengeTitle,
  }) async {
    if (nominati.isEmpty) {
      return;
    }

    final notifications = _ref.read(notificationsRepositoryProvider);

    if (notifications == null) {
      return;
    }

    // **Una chiamata sola per gara, per persona, da parte della stessa
    // persona.** Il nome del documento non porta dentro quale commento, ed e'
    // voluto: le regole accettano una notifica sola per quel nome, quindi chi
    // nomina qualcuno dieci volte nella stessa gara — cosa che in una
    // discussione capita da sola — gli fa squillare la campanella una volta.
    //
    // Si perde qualcosa: la seconda chiamata, dentro la stessa gara, non
    // arriva. Vale il prezzo. Una campanella che suona dieci volte per la
    // stessa conversazione si spegne dalle impostazioni del telefono, e da li'
    // non suona piu' nemmeno quando qualcuno vince.
    //
    // Dentro lo stesso commento vale lo stesso: nominare qualcuno tre volte
    // nella stessa riga e' una chiamata sola.
    final visti = <String>{};

    for (final mention in nominati) {
      if (!visti.add(mention.userId)) {
        continue;
      }

      await notifications.push(
        toUserId: mention.userId,
        id: FirestoreNotificationsRepository.mentionId(
          challengeId: challengeId,
          actorId: actorId,
          toUserId: mention.userId,
        ),
        kind: NotificationKind.mention,
        actorId: actorId,
        actorUsername: actorUsername,
        challengeId: challengeId,
        challengeTitle: challengeTitle,
      );
    }
  }
}

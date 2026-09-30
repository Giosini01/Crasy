import 'dart:async';

import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/challenges/domain/entities/entry_comment.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
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
    final scritti = _nomiNelTesto(scritto);
    final nominati = [
      for (final mention in mentions)
        if (scritti.contains(mention.username.toLowerCase()) &&
            mention.userId != authState.user.id)
          mention,
    ];

    // **E anche quelli scritti a mano.** Chi scrive `@mario` per intero senza
    // toccare il suggerimento lo ha nominato lo stesso, e si aspetta che a
    // Mario arrivi la notizia: prima non arrivava niente, e il nome restava
    // testo nero. Si cerca il nome esatto, uno per uno.
    nominati.addAll(
      await _risolviAMano(scritti, gia: nominati, io: authState.user.id),
    );

    final String commentId;

    try {
      final commento = await _ref
          .read(challengeRepositoryProvider)
          .addComment(
            challengeId: challengeId,
            entryId: entryId,
            userId: authState.user.id,
            authorName: autore,
            text: scritto,
            mentions: nominati,
          );
      commentId = commento.id;
    } on Object catch (_) {
      return 'Commento non mandato. Riprova.';
    }

    unawaited(
      _avvisaNominati(
        nominati,
        actorId: authState.user.id,
        actorUsername: autore,
        challengeId: challengeId,
        entryId: entryId,
        commentId: commentId,
        challengeTitle: challengeTitle,
      ),
    );

    // **E chi la foto l'ha mandata.** Un commento sotto la roba di qualcuno che
    // non se ne accorge non e' una conversazione, e' un messaggio lasciato su
    // un muro. Il nome della partecipazione **e'** l'identificativo di chi
    // l'ha mandata — e' la regola "una foto a testa" scritta nella forma dei
    // dati — quindi qui non serve leggere niente per sapere a chi scrivere.
    //
    // Se e' anche fra i nominati gli arriva gia' quella: due squilli per la
    // stessa riga sono uno di troppo.
    if (!nominati.any((mention) => mention.userId == entryId)) {
      unawaited(
        _avvisaAutore(
          entryId,
          commentId: commentId,
          actorId: authState.user.id,
          actorUsername: autore,
          challengeId: challengeId,
          challengeTitle: challengeTitle,
        ),
      );
    }

    return null;
  }

  /// I nomi scritti con la chiocciola, in minuscolo.
  static Set<String> _nomiNelTesto(String testo) => {
    for (final trovato in RegExp(r'@([A-Za-z0-9_.]+)').allMatches(testo))
      trovato.group(1)!.toLowerCase(),
  };

  /// Le persone nominate a mano: `@nome` scritto per intero, senza passare dai
  /// suggerimenti.
  ///
  /// Una ricerca per nome, e solo per quelli che non si conoscono gia'. Al
  /// massimo cinque: un commento con dieci chiocciole non e' una conversazione.
  /// Non lancia: un nome che non si trova resta testo, e il commento parte lo
  /// stesso.
  Future<List<EntryMention>> _risolviAMano(
    Set<String> scritti, {
    required List<EntryMention> gia,
    required String io,
  }) async {
    final noti = {for (final mention in gia) mention.username.toLowerCase()};
    final daCercare = scritti.difference(noti).take(5).toList();

    if (daCercare.isEmpty) {
      return const [];
    }

    final repository = _ref.read(friendsRepositoryProvider);

    if (repository == null) {
      return const [];
    }

    final trovati = <EntryMention>[];

    for (final nome in daCercare) {
      try {
        final profili = await repository.searchProfiles(nome, limit: 3);

        for (final profilo in profili) {
          if (profilo.username.toLowerCase() == nome && profilo.id != io) {
            trovati.add(
              EntryMention(userId: profilo.id, username: profilo.username),
            );

            break;
          }
        }
      } on Object catch (_) {
        // Vedi sopra: resta testo.
      }
    }

    return trovati;
  }

  Future<void> _avvisaAutore(
    String entryId, {
    required String commentId,
    required String actorId,
    required String actorUsername,
    required String challengeId,
    required String challengeTitle,
  }) async {
    final notifications = _ref.read(notificationsRepositoryProvider);

    // Commentare sotto la propria foto non fa squillare niente: sarebbe
    // l'unica notifica dell'app che si manda da soli.
    if (notifications == null || entryId == actorId) {
      return;
    }

    await notifications.push(
      toUserId: entryId,
      id: FirestoreNotificationsRepository.commentId(
        challengeId: challengeId,
        entryId: entryId,
        commentId: commentId,
      ),
      kind: NotificationKind.comment,
      actorId: actorId,
      actorUsername: actorUsername,
      challengeId: challengeId,
      entryId: entryId,
      challengeTitle: challengeTitle,
    );
  }

  Future<void> _avvisaNominati(
    List<EntryMention> nominati, {
    required String actorId,
    required String actorUsername,
    required String challengeId,
    required String entryId,
    required String commentId,
    required String challengeTitle,
  }) async {
    if (nominati.isEmpty) {
      return;
    }

    final notifications = _ref.read(notificationsRepositoryProvider);

    if (notifications == null) {
      return;
    }

    // **Una chiamata per commento.** Prima era una sola per gara, per
    // persona: dal secondo tag nella stessa gara la notifica veniva scartata
    // in silenzio, e chi taggava qualcuno per rispondergli non lo raggiungeva
    // piu'. Chi viene nominato vuole saperlo ogni volta.
    //
    // Dentro lo stesso commento invece resta una: nominare qualcuno tre volte
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
          commentId: commentId,
          toUserId: mention.userId,
        ),
        kind: NotificationKind.mention,
        actorId: actorId,
        actorUsername: actorUsername,
        challengeId: challengeId,
        entryId: entryId,
        challengeTitle: challengeTitle,
      );
    }
  }
}

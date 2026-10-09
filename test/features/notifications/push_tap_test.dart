import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Dove porta il tocco su una notifica.**
///
/// E' la parte che si rompe in silenzio: nessuno se ne accorge finche' non
/// tocca quella notifica proprio in quel caso, e quando succede la segnalazione
/// che arriva e' "non mi porta dove dovrebbe" — senza dire quale notifica.
///
/// Il difetto che queste prove tengono chiuso: la fiamma, che e' la notifica
/// piu' numerosa di tutte, non aveva un caso suo e finiva nell'elenco delle
/// notifiche. Si leggeva "una fiamma nuova sulla tua foto", si toccava, e si
/// arrivava a un elenco con dentro scritta la stessa frase.
void main() {
  PushTap tocco(Map<String, String> dati, {String? io = 'io'}) =>
      pushTapOf(dati, daFermo: false, io: io);

  group('la fiamma porta alla foto', () {
    test('apre la foto di chi riceve, nella gara giusta', () {
      final dove = tocco({
        'kind': 'fire',
        'challengeId': 'gara-1',
        'notificationId': 'n1',
      });

      // **La foto si sa senza che il server la mandi.** Una partecipazione ha
      // come identificativo l'uid di chi l'ha mandata, quindi la foto che ha
      // preso la fiamma e' quella di chi legge la notizia.
      expect(dove.apri, AppRoutes.entryCommentsOf('gara-1', 'io'));
      expect(dove.scheda, AppRoutes.challenges);
    });

    test('se il server manda la foto, vince quella', () {
      final dove = tocco({
        'kind': 'fire',
        'challengeId': 'gara-1',
        'entryId': 'foto-vera',
      });

      expect(dove.apri, AppRoutes.entryCommentsOf('gara-1', 'foto-vera'));
    });

    test(
      'senza gara si torna in campanella invece di non andare da nessuna parte',
      () {
        final dove = tocco({'kind': 'fire', 'notificationId': 'n1'});

        expect(dove.apri, AppRoutes.notifications);
      },
    );
  });

  group('le altre notifiche', () {
    test('una sfida porta alla sfida, non in campanella', () {
      for (final kind in [
        'duel',
        'duelAccepted',
        'duelDeclined',
        'duelCompleted',
        'duelApproved',
        'duelRejected',
      ]) {
        final dove = tocco({'kind': kind, 'challengeId': 'gara-2'});

        expect(dove.apri, AppRoutes.challengeDetailOf('gara-2'), reason: kind);
      }
    });

    test('una richiesta di amicizia porta dove si risponde', () {
      final dove = tocco({'kind': 'friendRequest'});

      expect(dove.apri, AppRoutes.friends);
      expect(dove.scheda, AppRoutes.profile);
    });

    test('un commento apre la foto commentata', () {
      final dove = tocco({
        'kind': 'comment',
        'challengeId': 'gara-3',
        'entryId': 'foto-3',
      });

      expect(dove.apri, AppRoutes.entryCommentsOf('gara-3', 'foto-3'));
    });

    test('chi prova a batterti porta alla sua foto', () {
      final dove = tocco({
        'kind': 'rival',
        'challengeId': 'gara-4',
        'entryId': 'foto-4',
      });

      expect(dove.apri, AppRoutes.entryCommentsOf('gara-4', 'foto-4'));
    });

    test('senza la foto, chi prova a batterti porta in campanella', () {
      // Le notizie scritte prima che il server portasse dentro la foto: la
      // gara intera non dice quale sia quella nuova, e in campanella la riga
      // accesa la trova da sola.
      final dove = tocco({'kind': 'rival', 'challengeId': 'gara-4'});

      expect(dove.apri, AppRoutes.notifications);
    });

    test('una gara nuova non apre niente sopra la scheda', () {
      final dove = tocco({'kind': 'newChallenge'});

      expect(dove.apri, isNull);
      expect(dove.scheda, AppRoutes.challenges);
    });
  });
}

import 'package:crasy/core/constants/app_routes.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Dove porta il tocco su una notifica.**
///
/// E' la parte che si rompe in silenzio: nessuno se ne accorge finche' non
/// tocca quella notifica proprio in quel caso, e quando succede la segnalazione
/// che arriva e' "non mi porta dove dovrebbe" — senza dire quale notifica.
///
/// La regola adesso e' una sola: **tutto in campanella, sulla sezione giusta**.
/// Le scorciatoie verso la foto o il commento si rompevano appena mancava un
/// pezzo; la campanella c'e' sempre.
void main() {
  PushTap tocco(Map<String, String> dati) => pushTapOf(dati, daFermo: false);

  String campanella(String sezione) =>
      '${AppRoutes.notifications}?sezione=$sezione';

  test('ogni notizia porta in campanella, nella sua sezione', () {
    const attese = {
      'fire': 'fires',
      'comment': 'comments',
      'mention': 'comments',
      'participation': 'participations',
      'rival': 'participations',
      'duel': 'duels',
      'duelApproved': 'duels',
      'partyMission': 'duels',
      'win': 'wins',
      'ended': 'wins',
      'friendRequest': 'requests',
    };

    for (final MapEntry(key: kind, value: sezione) in attese.entries) {
      final dove = tocco({
        'kind': kind,
        'challengeId': 'gara-1',
        'entryId': 'foto-1',
        'notificationId': 'n1',
      });

      expect(dove.apri, campanella(sezione), reason: kind);
      expect(dove.evidenzia, 'n1', reason: kind);
      expect(dove.scheda, AppRoutes.challenges, reason: kind);
    }
  });

  test('una gara nuova non apre niente sopra la scheda', () {
    final dove = tocco({'kind': 'newChallenge'});

    expect(dove.apri, isNull);
    expect(dove.scheda, AppRoutes.challenges);
  });
}

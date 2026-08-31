import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:crasy/features/challenges/domain/entities/entry_moderation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chi vede cosa, dopo una segnalazione o un blocco.
///
/// **La soglia e' la parte delicata.** Con dei soldi in palio, far sparire la
/// foto che sta vincendo e' un attacco che conviene: qui si verifica che una
/// segnalazione sola non basti, e che allo stesso tempo chi segnala non sia
/// costretto a continuare a guardare quello che ha segnalato.
void main() {
  ChallengeEntry entry({
    String userId = 'autore',
    List<String> reporters = const [],
    EntryModeration moderation = EntryModeration.approved,
  }) {
    return ChallengeEntry(
      id: userId,
      challengeId: 'gara',
      userId: userId,
      authorName: userId,
      mediaUrl: 'https://esempio/foto.jpg',
      reporters: reporters,
      moderation: moderation,
    );
  }

  test('una foto normale la vedono tutti', () {
    expect(entry().isVisibleTo('chiunque'), isTrue);
  });

  test('chi la segnala non la vede piu, da solo', () {
    final foto = entry(reporters: const ['io']);

    expect(foto.isVisibleTo('io'), isFalse);
    // Ma gli altri si': una segnalazione sola non e' un verdetto.
    expect(foto.isVisibleTo('un-altro'), isTrue);
  });

  test('sotto la soglia la foto resta in gara', () {
    expect(
      entry(reporters: const ['uno', 'due']).isVisibleTo('un-altro'),
      isTrue,
    );
  });

  test('alla soglia sparisce per tutti', () {
    final foto = entry(reporters: const ['uno', 'due', 'tre']);

    expect(foto.isVisibleTo('un-altro'), isFalse);
    // Anche per chi l'ha mandata: se restasse visibile solo a lui, penserebbe
    // di essere ancora in gara.
    expect(foto.isVisibleTo('autore'), isFalse);
  });

  test('la soglia e tre', () {
    expect(ChallengeEntry.reportsToHide, 3);
  });

  test('chi hai bloccato sparisce senza soglie', () {
    final foto = entry();

    expect(foto.isVisibleTo('io', blocked: const {'autore'}), isFalse);
    expect(foto.isVisibleTo('io', blocked: const {'un-altro'}), isTrue);
  });

  test('il blocco vince anche su una foto in attesa di controllo', () {
    final foto = entry(moderation: EntryModeration.pending);

    // In attesa la vedrebbe solo chi l'ha mandata; bloccandolo non la vede piu'
    // nemmeno chi ha bloccato.
    expect(foto.isVisibleTo('autore'), isTrue);
    expect(foto.isVisibleTo('autore', blocked: const {'autore'}), isFalse);
  });
}

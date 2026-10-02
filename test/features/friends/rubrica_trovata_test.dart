import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La rubrica divisa in due: chi c'e' gia' e chi va invitato.**
///
/// La divisione si regge su una cosa sola — il numero con cui una persona e'
/// stata trovata torna indietro dal server — e se quel numero mancasse non si
/// romperebbe niente in modo visibile: chi e' gia' su CRASY comparirebbe
/// **anche** fra quelli da invitare, e si manderebbe un invito a chi l'app ce
/// l'ha gia'. Una figuraccia silenziosa, di quelle che nessuno segnala.
void main() {
  SuggestedFriend suCrasy(String numero) =>
      SuggestedFriend(userId: 'u$numero', username: 'tizio', numero: numero);

  test('chi e\' stato trovato non finisce fra quelli da invitare', () {
    final rubrica = RubricaTrovata(
      suCrasy: [suCrasy('+393331111111')],
      daInvitare: const [Contatto(nome: 'Marco', numero: '+393332222222')],
    );

    expect(rubrica.suCrasy.single.numero, '+393331111111');
    expect(rubrica.daInvitare.single.numero, '+393332222222');
    expect(
      rubrica.daInvitare.map((c) => c.numero),
      isNot(contains('+393331111111')),
    );
  });

  test('una rubrica senza niente dentro si riconosce', () {
    expect(const RubricaTrovata().vuota, isTrue);
  });

  test('con qualcuno da invitare non e\' vuota', () {
    // Il caso normale all'inizio: nessuno dei tuoi contatti ha ancora CRASY,
    // ma la schermata ha comunque tutto da fare. Trattarla come vuota vorrebbe
    // dire mostrare "non c'e' nessuno" sopra un elenco di duecento persone da
    // invitare.
    const rubrica = RubricaTrovata(
      daInvitare: [Contatto(nome: 'Marco', numero: '+393332222222')],
    );

    expect(rubrica.vuota, isFalse);
  });

  test('con qualcuno gia\' dentro non e\' vuota', () {
    expect(RubricaTrovata(suCrasy: [suCrasy('+39333')]).vuota, isFalse);
  });
}

import 'package:crasy/core/moderation/email_policy.dart';
import 'package:crasy/features/auth/presentation/utils/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le caselle usa-e-getta, e perche' qui contano.
///
/// Le fiamme decidono chi si prende i soldi, e vale una per persona: chi si fa
/// cinque caselle in due minuti si fa cinque account, e si vota cinque volte da
/// solo. Questo elenco e' la prima porta contro quella cosa.
void main() {
  group('i domini usa-e-getta non passano', () {
    test('i piu'
        ' diffusi', () {
      for (final email in [
        'tizio@mailinator.com',
        'tizio@yopmail.com',
        'tizio@10minutemail.com',
        'tizio@guerrillamail.com',
        'tizio@sharklasers.com',
        'tizio@temp-mail.org',
        'tizio@grr.la',
      ]) {
        expect(EmailPolicy.isDisposable(email), isTrue, reason: email);
      }
    });

    test('anche i loro sottodomini', () {
      // Quei siti ne offrono a manciate proprio per aggirare gli elenchi
      // fatti sul nome esatto.
      expect(EmailPolicy.isDisposable('tizio@qualcosa.mailinator.com'), isTrue);
      expect(EmailPolicy.isDisposable('tizio@a.b.yopmail.com'), isTrue);
    });

    test('le maiuscole e gli spazi non aiutano', () {
      expect(EmailPolicy.isDisposable('  Tizio@MailInator.COM  '), isTrue);
    });

    test('gli alias infiniti valgono come usa-e-getta', () {
      // Servizi seri, usati da gente seria, che pero' regalano un indirizzo
      // nuovo a ogni registrazione: con dei premi in denaro il problema e'
      // identico.
      expect(EmailPolicy.isDisposable('tizio@simplelogin.io'), isTrue);
      expect(EmailPolicy.isDisposable('tizio@duck.com'), isTrue);
    });
  });

  group('gli indirizzi veri passano', () {
    test('i fornitori normali', () {
      for (final email in [
        'daniele@gmail.com',
        'daniele@icloud.com',
        'daniele@libero.it',
        'daniele@outlook.com',
        'daniele.carrella@unazienda.it',
      ]) {
        expect(EmailPolicy.isDisposable(email), isFalse, reason: email);
      }
    });

    test('i relay di Apple si accettano di proposito', () {
      // Sono indirizzi veri di persone vere, e il giorno in cui ci sara'
      // l'accesso con Apple — che Apple impone di accettare — bloccarli
      // chiuderebbe la porta a chi entra dalla strada che ci obbligano a
      // offrire.
      expect(
        EmailPolicy.isDisposable('abc123@privaterelay.appleid.com'),
        isFalse,
      );
    });

    test('una stringa che non e'
        ' un indirizzo non fa danni', () {
      expect(EmailPolicy.isDisposable('non e un indirizzo'), isFalse);
      expect(EmailPolicy.isDisposable(''), isFalse);
      expect(EmailPolicy.isDisposable(null), isFalse);
    });
  });

  group('vale a chi si registra, non a chi entra', () {
    test('registrandosi viene rifiutata', () {
      expect(
        AuthValidators.validateNewEmail('tizio@mailinator.com'),
        isNotNull,
      );
    });

    test('entrando viene accettata', () {
      // **Chi e' gia' dentro resta dentro.** Chiudere fuori qualcuno che si e'
      // registrato ieri, magari con delle foto in gara, per una regola scritta
      // oggi, e' una punizione retroattiva.
      expect(AuthValidators.validateEmail('tizio@mailinator.com'), isNull);
    });

    test('un indirizzo normale passa in tutti e due i casi', () {
      expect(AuthValidators.validateNewEmail('daniele@gmail.com'), isNull);
      expect(AuthValidators.validateEmail('daniele@gmail.com'), isNull);
    });
  });
}

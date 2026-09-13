import 'package:crasy/core/moderation/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il corpo chiesto per nome, e le parolacce.**
///
/// Era il buco piu' largo del filtro: "foto al tuo pisello" e "foto alla tua
/// fessa" passavano lisce, e la categoria delle volgarita' esisteva — con il
/// suo messaggio gia' scritto — senza una sola parola dentro. Su un'app che
/// **paga la gente per fare cose**, una missione del genere non e' un
/// contenuto discutibile: e' una richiesta di materiale sessuale con dei soldi
/// in mezzo.
///
/// La seconda meta' di questo file conta quanto la prima. Un filtro che boccia
/// chi non ha fatto niente perde la fiducia di tutti e finisce disattivato:
/// "foto a un uccello sul balcone" e "che sfiga" devono passare, o la prima
/// volta che succede qualcuno spegne l'intero controllo.
void main() {
  String? categoria(String testo) => ContentPolicy.check(testo)?.category;

  group('il corpo chiesto per nome non passa', () {
    const richieste = [
      'Foto al tuo pisello',
      'Foto alla tua fessa',
      'Mostrami la tua figa',
      'Foto della tua topa',
      'Fatti una foto in mutande',
      'Una foto in reggiseno',
      'Fai vedere le tette',
      'Foto al tuo uccello',
      'Foto alla tua patata',
      'Mostra le parti intime',
    ];

    for (final testo in richieste) {
      test('"$testo"', () {
        expect(categoria(testo), 'sesso', reason: testo);
      });
    }
  });

  group('la parolaccia da sola passa, la richiesta no', () {
    // **Una decisione gia' presa, e la lascio stare.** Le parolacce senza
    // bersaglio passano — sta scritto in `content_policy_test.dart`, ed e'
    // giusto: "che cazzo hai fatto" e' stupore, non una richiesta, e un filtro
    // che la ferma boccia meta' di quello che la gente scrive davvero.
    //
    // Cambia tutto quando c'e' il possessivo: li' non e' piu' un'esclamazione,
    // e' una richiesta di materiale sessuale — con dei soldi in mezzo.
    test('l\'esclamazione resta permessa', () {
      expect(ContentPolicy.check('che cazzo hai fatto'), isNull);
      expect(ContentPolicy.check('vaffanculo'), isNull);
    });

    test('la richiesta no', () {
      expect(categoria('Fammi vedere il tuo cazzo'), 'sesso');
      expect(categoria('Foto al cazzo'), 'sesso');
    });
  });

  group('i travestimenti non aiutano', () {
    test('le lettere spaziate si rileggono attaccate', () {
      expect(categoria('foto al tuo p i s e l l o'), 'sesso');
    });

    test('i numeri al posto delle lettere', () {
      expect(categoria('foto al tuo p1sello'), 'sesso');
    });

    test('le lettere ripetute si schiacciano', () {
      expect(categoria('foto al tuo pisellooooo'), 'sesso');
    });
  });

  group('e quello che non c\'entra passa', () {
    // **Questa meta' vale quanto l'altra.** Ognuna di queste frasi contiene
    // una parola dell'elenco dentro un'altra parola: bocciarle vorrebbe dire
    // un filtro che si arrabbia con chi non ha fatto niente, e quello dura
    // tre giorni prima che qualcuno lo spenga.
    const innocue = [
      'Foto a un uccello sul balcone',
      'Foto di una patata gigante',
      'Che sfiga, ho perso il treno',
      'Confessa la tua paura piu\' grande',
      'La professa di matematica',
      'Foto ai piselli a cena',
      'Trova una topaia e fotografala',
      'Tagliati i capelli davanti a tutti',
      'Balla in mezzo alla piazza',
      'Fai una foto con un porcospino',
    ];

    for (final testo in innocue) {
      test('"$testo"', () {
        expect(ContentPolicy.check(testo), isNull, reason: testo);
      });
    }
  });
}

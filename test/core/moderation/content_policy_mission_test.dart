import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il controllo sul testo di una **missione**: titolo e consegna.
///
/// Una missione e' un incarico con dei soldi in mezzo, e un elenco di parole non
/// vede chi gira intorno: "tuffati dalla scogliera" passa anche quando "salta dal
/// ponte" no. Qui si controlla quello che il modulo dice subito; l'ultima parola e'
/// del server, e i suoi giri di parole sono provati in
/// `functions/test/parole.test.js`.
void main() {
  group('quello che in una missione si ferma', () {
    test('una parolaccia passa in un commento ma non in una missione', () {
      // Una decisione gia' presa: "che cazzo hai fatto" e' stupore. Dentro una
      // missione, che e' un incarico pagato, il database la ferma da sempre.
      expect(ContentPolicy.check('che cazzo hai fatto'), isNull);
      expect(
        ContentPolicy.checkMission('che cazzo hai fatto'),
        ContentPolicy.profanity,
      );
    });

    test('i validatori della missione usano il controllo giusto', () {
      expect(
        ChallengeDraftValidators.validateTitle('Che cazzo di sfida'),
        ContentPolicy.profanity.message,
      );
      expect(
        ChallengeDraftValidators.validateBrief('Foto con il reggiseno rosso'),
        ContentPolicy.sexual.message,
      );
    });

    test('validateMission torna il messaggio, o niente', () {
      expect(
        ContentPolicy.validateMission('Tuffati dalla scogliera'),
        ContentPolicy.danger.message,
      );
      expect(ContentPolicy.validateMission('Fai una foto.'), isNull);
      expect(ContentPolicy.validateMission(null), isNull);
      expect(ContentPolicy.validateMission('   '), isNull);
    });
  });

  group('i giri di parole', () {
    // Nessuna di queste contiene una parola dell'elenco di `check`: ognuna e'
    // pericolosa per **l'azione e il posto messi insieme**.
    const vietate = <String, ContentViolation>{
      'Sdraiati sulla carreggiata e fatti una foto': ContentPolicy.danger,
      'Stenditi sui binari per 10 secondi': ContentPolicy.danger,
      'Tuffati dalla scogliera piu\' alta che trovi': ContentPolicy.danger,
      'Salta giu dal balcone e riprendi tutto': ContentPolicy.danger,
      'Bevi mezza bottiglia di vodka tutta d\'un fiato': ContentPolicy.danger,
      'Scola un litro di grappa e riprendilo': ContentPolicy.danger,
      'Brucia i peli del braccio con l\'accendino': ContentPolicy.danger,
      'Attraversa l\'autostrada a occhi chiusi': ContentPolicy.danger,
      'Fermati in mezzo alla tangenziale': ContentPolicy.danger,
      'Ingerisci un po\' di candeggina e mostra la faccia':
          ContentPolicy.selfHarm,
      'Mescola dei sonniferi nella birra e bevila': ContentPolicy.selfHarm,
      'Taglia il tuo braccio e fotografa': ContentPolicy.selfHarm,
      'Incidi la coscia con un coltello': ContentPolicy.selfHarm,
      'Pedina una ragazza fino a casa': ContentPolicy.crime,
      'Insegui uno sconosciuto per dieci minuti': ContentPolicy.crime,
      'Foto di tuo figlio mentre fa il bagno': ContentPolicy.sexual,
    };

    for (final entry in vietate.entries) {
      test('"${entry.key}" viene rifiutata', () {
        expect(ContentPolicy.checkMission(entry.key), entry.value);
      });
    }

    test('i travestimenti piu\' banali non salvano nemmeno qui', () {
      expect(ContentPolicy.checkMission('SALTAAAA dal tetto'), isNotNull);
      expect(ContentPolicy.checkMission('S4lta dal b4lcone'), isNotNull);
    });
  });

  group('e una missione normale continua a passare', () {
    // **Questa meta' vale quanto l'altra.** Ogni coppia di `_combos` costa una
    // challenge innocua rifiutata per sbaglio, e un filtro che si arrabbia con
    // chi non ha fatto niente viene spento. Qui ci sono le frasi vicine a quelle
    // vietate: stesse parole, senza la richiesta.
    const innocue = [
      'Fatti una foto mentre salti',
      'Fai un salto di gioia davanti al ponte vecchio',
      'salto mortale sul divano',
      'Fai un tuffo in piscina',
      'Fotografa un ponte illuminato di notte',
      'Fotografa un tetto rosso',
      'Fatti una foto sul balcone di casa',
      'Il palazzo piu\' alto che vedi dal tuo balcone',
      'Fermati al semaforo e saluta il vicino',
      'Dormi con il tuo cane e fotografalo',
      'Fotografa la stazione ferroviaria',
      'Bevi un caffe\' e mostra la tazza',
      'Bevi un bicchiere d\'acqua tutto d\'un fiato',
      'Bevi una birra con gli amici e brindate',
      'Taglia la torta e mostra il braccio del tuo amico',
      'tagliati i capelli davanti allo specchio',
      'Cuoci le tagliatelle e mostra il piatto',
      'Segui le indicazioni e chiedi a uno sconosciuto una foto',
      'Fai una foto in spiaggia con la spia accesa',
      'Mostra il tuo bambino che ride',
      'Fai il bagno al mare con un amico',
      'Il tuo bagno piu\' strano',
      'Foto a un uccello sul balcone',
      'Fai una foto con un porcospino',
      'Balla in mezzo alla piazza',
    ];

    for (final testo in innocue) {
      test('"$testo"', () {
        expect(ContentPolicy.checkMission(testo), isNull, reason: testo);
      });
    }
  });
}

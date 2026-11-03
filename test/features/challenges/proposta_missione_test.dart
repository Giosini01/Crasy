import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/core/errors/error_message_mapper.dart';
import 'package:crasy/core/moderation/content_policy.dart';
import 'package:crasy/features/challenges/data/repositories/firestore_challenge_repository.dart';
import 'package:crasy/features/challenges/domain/entities/challenge.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_scope.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_source.dart';
import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:crasy/features/challenges/domain/entities/proposta_missione.dart';
import 'package:crasy/features/challenges/presentation/controllers/create_challenge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un rifiuto di una funzione del server, com'e' fatto quando arriva al telefono.
class _RifiutoDelServer extends FirebaseFunctionsException {
  _RifiutoDelServer(String code, String message)
    : super(code: code, message: message);
}

Challenge _missione({
  String targetUserId = '',
  String duelMessage = '',
  bool anonimo = false,
}) {
  final inizio = DateTime(2026, 11, 3, 12);

  return Challenge(
    id: '',
    title: 'Foto fuori al balcone',
    brief: 'Una foto, adesso.',
    prizeCents: 500,
    scope: ChallengeScope.friends,
    maxParticipants: 10,
    mediaKind: MediaKind.video,
    source: ChallengeSource.archive,
    anonimo: anonimo,
    audience: const ['chi-lancia', 'un-amico'],
    createdByUserId: 'chi-lancia',
    createdByUsername: 'mario',
    targetUserId: targetUserId,
    targetUsername: 'nome-scritto-dal-telefono',
    duelMessage: duelMessage,
    startsAt: inizio,
    endsAt: inizio.add(const Duration(hours: 3)),
  );
}

/// **Una missione si propone, e il server decide.**
///
/// Il percorso vero si prova con le prove del server
/// (`functions/test/integrazione.emu.js`). Qui si prova la meta' che sta sul
/// telefono: cosa parte, e come si legge cosa torna.
void main() {
  group('cosa parte', () {
    test('solo quello che ha scelto chi lancia', () {
      expect(FirestoreChallengeRepository.corpoDellaProposta(_missione()), {
        'title': 'Foto fuori al balcone',
        'brief': 'Una foto, adesso.',
        'prizeCents': 500,
        'scope': 'friends',
        'maxParticipants': 10,
        'mediaKind': 'video',
        'source': 'archive',
        'minutes': 180,
        'anonimo': false,
      });
    });

    test('chi la vede e come si chiama lo decide il server', () {
      final corpo = FirestoreChallengeRepository.corpoDellaProposta(
        _missione(targetUserId: 'bersaglio', duelMessage: 'Dai'),
      );

      for (final campo in [
        'audience',
        'createdByUserId',
        'createdByUsername',
        'targetUsername',
        'startsAt',
        'endsAt',
        'prizeStatus',
      ]) {
        expect(corpo.containsKey(campo), isFalse, reason: campo);
      }
    });

    test('una sfida porta il bersaglio e la riga per lui', () {
      final corpo = FirestoreChallengeRepository.corpoDellaProposta(
        _missione(targetUserId: 'bersaglio', duelMessage: 'Dai', anonimo: true),
      );

      expect(corpo['targetUserId'], 'bersaglio');
      expect(corpo['duelMessage'], 'Dai');
      expect(corpo['anonimo'], isTrue);
    });
  });

  group('cosa torna', () {
    test('in gara: l\'identificativo', () {
      expect(
        FirestoreChallengeRepository.idDellaGara({
          'stato': 'inGara',
          'challengeId': 'gara-1',
        }),
        'gara-1',
      );
    });

    test('in controllo: non e\' una gara', () {
      expect(
        () => FirestoreChallengeRepository.idDellaGara({
          'stato': 'inControllo',
          'propostaId': 'p1',
        }),
        throwsA(
          isA<MissioneInControllo>().having(
            (e) => e.propostaId,
            'propostaId',
            'p1',
          ),
        ),
      );
    });

    test('gia\' approvata: si va a pagare', () {
      expect(
        () => FirestoreChallengeRepository.idDellaGara({
          'stato': 'daPagare',
          'propostaId': 'p2',
        }),
        throwsA(
          isA<MissioneDaPagare>().having(
            (e) => e.propostaId,
            'propostaId',
            'p2',
          ),
        ),
      );
    });

    test('bloccata: la frase del server arriva a schermo', () {
      const frase = 'Non si può chiedere a nessuno di farsi del male.';

      expect(
        () => FirestoreChallengeRepository.idDellaGara({
          'stato': 'bloccata',
          'messaggio': frase,
        }),
        throwsA(
          isA<MissioneBloccata>().having(
            ErrorMessageMapper.map,
            'a schermo',
            frase,
          ),
        ),
      );
    });

    test('bloccata senza frase: si dice qualcosa lo stesso', () {
      expect(
        () => FirestoreChallengeRepository.idDellaGara({'stato': 'bloccata'}),
        throwsA(
          isA<MissioneBloccata>().having(
            (e) => e.messaggio,
            'messaggio',
            isNotEmpty,
          ),
        ),
      );
    });

    test('una risposta che non si sa leggere non e\' una gara', () {
      for (final risposta in <Map<Object?, Object?>>[
        {},
        {'stato': 'inGara'},
        {'stato': 'inGara', 'challengeId': ''},
        {'stato': 'un-esito-che-ancora-non-esiste'},
      ]) {
        expect(
          () => FirestoreChallengeRepository.idDellaGara(risposta),
          throwsStateError,
          reason: '$risposta',
        );
      }
    });
  });

  group('i rifiuti del server a schermo', () {
    test('quelli scritti apposta si leggono com\'erano', () {
      const frasi = {
        'resource-exhausted':
            'Hai proposto troppe missioni per oggi. Riprova domani.',
        'permission-denied': 'Non puoi sfidare questa persona.',
        'invalid-argument': 'Il premio minimo è 1 euro.',
        'failed-precondition':
            'Per lanciarla in anonimo serve almeno un amico.',
        'not-found': 'Questa missione non c’è più.',
      };

      frasi.forEach((codice, frase) {
        expect(
          ErrorMessageMapper.map(_RifiutoDelServer(codice, frase)),
          frase,
          reason: codice,
        );
      });
    });

    test('un rifiuto del server non dice piu\' che il tempo e\' scaduto', () {
      expect(
        ErrorMessageMapper.map(
          _RifiutoDelServer('permission-denied', 'Non puoi sfidarla.'),
        ),
        isNot(contains('tempo')),
      );
    });

    test('un guasto non mostra il messaggio di chissa\' cosa', () {
      expect(
        ErrorMessageMapper.map(_RifiutoDelServer('internal', 'INTERNAL')),
        isNot(contains('INTERNAL')),
      );
      expect(
        ErrorMessageMapper.map(_RifiutoDelServer('unavailable', 'upstream')),
        isNot(contains('upstream')),
      );
    });

    test('un rifiuto senza frase non lascia una riga vuota', () {
      expect(
        ErrorMessageMapper.map(_RifiutoDelServer('permission-denied', ' ')),
        isNotEmpty,
      );
    });

    test('in controllo non e\' un guasto, anche se arrivasse fin qui', () {
      expect(
        ErrorMessageMapper.map(const MissioneInControllo('p')),
        contains('Non paghi niente'),
      );
      expect(
        ErrorMessageMapper.map(const MissioneDaPagare('p')),
        contains('manca solo il pagamento'),
      );
    });
  });

  group('la proposta, come la racconta il server', () {
    test('si legge tutta', () {
      final proposta = PropostaMissione.fromMap({
        'propostaId': 'p1',
        'stato': 'approvata',
        'title': 'Foto',
        'brief': 'Una foto',
        'prizeCents': 500,
        'challengeId': null,
        'motivo': '',
      });

      expect(proposta.id, 'p1');
      expect(proposta.approvata, isTrue);
      expect(proposta.inCoda, isFalse);
      expect(proposta.prizeCents, 500);
      expect(proposta.challengeId, isNull);
    });

    test('gli stati si riconoscono', () {
      PropostaMissione di(String stato) =>
          PropostaMissione.fromMap({'stato': stato});

      expect(di('rifiutata').rifiutata, isTrue);
      expect(di('bloccata').bloccata, isTrue);
      expect(di('daControllare').inCoda, isTrue);
      expect(di('daConfermare').inCoda, isTrue);
      // Le due che si sono fermate non aspettano piu' nessuno.
      expect(di('rifiutata').inCoda, isFalse);
      expect(di('bloccata').inCoda, isFalse);
    });

    test('un identificativo vuoto vuol dire che la gara non c\'e\'', () {
      expect(PropostaMissione.fromMap({'challengeId': ''}).challengeId, isNull);
      expect(PropostaMissione.fromMap({'challengeId': 'g'}).challengeId, 'g');
    });
  });

  group('la riga per l\'amico', () {
    test('e\' facoltativa', () {
      expect(ChallengeDraftValidators.validateDuelMessage(null), isNull);
      expect(ChallengeDraftValidators.validateDuelMessage('  '), isNull);
      expect(
        ChallengeDraftValidators.validateDuelMessage('Vediamo se ce la fai.'),
        isNull,
      );
    });

    test('non passa piu\' senza che la guardi nessuno', () {
      for (final riga in ['ammazzati', '4MM4ZZ4T1', 'foto nudo']) {
        expect(
          ChallengeDraftValidators.validateDuelMessage(riga),
          ContentPolicy.validate(riga),
          reason: riga,
        );
        expect(
          ChallengeDraftValidators.validateDuelMessage(riga),
          isNotNull,
          reason: riga,
        );
      }
    });

    test('ha un limite, lo stesso del server', () {
      expect(ChallengeDraftValidators.validateDuelMessage('a' * 140), isNull);
      expect(
        ChallengeDraftValidators.validateDuelMessage('a' * 141),
        isNotNull,
      );
    });
  });

  group('il filtro nell\'app', () {
    test('un negroni e\' un cocktail', () {
      expect(ContentPolicy.check('Un negroni al bar'), isNull);
      expect(ContentPolicy.check('Foto con un negroni'), isNull);
    });

    test('le parole di odio si fermano lo stesso', () {
      for (final parola in ['negro', 'negri', 'negra', 'negre', 'n3gr0']) {
        expect(ContentPolicy.check(parola), ContentPolicy.hate, reason: parola);
      }
    });
  });
}

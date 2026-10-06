import 'package:crasy/core/widgets/filter_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Cercare dentro un elenco che si ha gia' in mano.**
///
/// Il difetto da cui nasce: con trecento amici, sfidarne uno voleva dire
/// scorrere una fila di facce per decine di trascinamenti. E lo scorrimento
/// orizzontale su quella pagina se lo prendeva il gesto per tornare indietro,
/// quindi dal nono amico in poi gli altri erano **irraggiungibili**.
void main() {
  group('quando il campo si fa vedere', () {
    test('non sotto le righe che stanno a schermo', () {
      expect(FilterField.quandoServe(0), isFalse);
      expect(FilterField.quandoServe(8), isFalse);
      expect(FilterField.quandoServe(9), isTrue);
      expect(FilterField.quandoServe(300), isTrue);
    });
  });

  group('cosa combacia', () {
    test('le maiuscole non contano', () {
      expect(combacia('Marco', 'marco'), isTrue);
      expect(combacia('marco', 'MARCO'), isTrue);
    });

    test('si trova anche per cognome, non solo per inizio', () {
      // I nomi utente sono spesso nome e cognome attaccati: un filtro che
      // guarda solo l'inizio non trova mai niente per cognome, ed e' il modo in
      // cui si cerca una persona quando di nomi ce ne sono tre uguali.
      expect(combacia('marco.rossi', 'rossi'), isTrue);
      expect(combacia('marco.rossi', 'ross'), isTrue);
    });

    test('uno spazio incollato non fa sparire la riga', () {
      expect(combacia('marco', ' marco '), isTrue);
    });

    test('senza niente da cercare, combacia tutto', () {
      // E' quello che tiene l'elenco intero quando il campo e' vuoto: senza
      // questo, aprendo la pagina non si vedrebbe nessuno.
      expect(combacia('chiunque', ''), isTrue);
      expect(combacia('chiunque', '   '), isTrue);
      expect(combacia('', ''), isTrue);
    });

    test('quello che non c entra resta fuori', () {
      expect(combacia('marco', 'luca'), isFalse);
      expect(combacia('', 'luca'), isFalse);
    });
  });
}

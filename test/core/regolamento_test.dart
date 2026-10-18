import 'package:crasy/core/legal/legal_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Il regolamento delle missioni dice le cose che Apple controlla.**
///
/// Apple vuole le regole ufficiali delle gare con premi dentro l'app, e vuole
/// che dicano che Apple non è sponsor (linea guida 5.3.2). Se una riga così
/// sparisce in una modifica, la revisione la rifiuta: questa prova se ne
/// accorge prima.
void main() {
  final testo = LegalTexts.regolamento.body;

  test('Apple e Google non sono sponsor, ed è scritto', () {
    expect(testo, contains('Apple Inc. e Google LLC non sono sponsor'));
    expect(testo, contains('non sono coinvolte in'));
  });

  test('si partecipa gratis, e chi lancia non partecipa', () {
    expect(testo, contains('Partecipare e\' gratuito'));
    expect(testo, contains('Chi lancia una missione non puo\''));
  });

  test('come si vince, senza sorte', () {
    expect(testo, contains('vince la'));
    expect(testo, contains('nessun elemento di sorte'));
  });

  test('non chiede un consenso in più', () {
    // Il regolamento si legge e basta: non è fra i documenti da accettare,
    // quindi cambiarlo non deve far ripassare tutti dal consenso.
    expect(
      LegalConsent.values.map((consenso) => consenso.document),
      isNot(contains(LegalTexts.regolamento)),
    );
  });
}

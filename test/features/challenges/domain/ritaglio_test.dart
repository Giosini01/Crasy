import 'package:crasy/features/challenges/domain/entities/ritaglio.dart';
import 'package:flutter_test/flutter_test.dart';

/// **La cornice delle anteprime, letta dal database.**
///
/// La foto sale intera; la cornice dice solo quale parte mostrare nei
/// riquadri. Una cornice rotta non deve rompere niente: si ignora, e la foto
/// si mostra tagliata al centro come prima.
void main() {
  test('va e torna dal database uguale', () {
    const cornice = Ritaglio(x: 0.1, y: 0.2, larghezza: 0.8, altezza: 0.5);

    expect(Ritaglio.fromMap(cornice.toMap()), cornice);
  });

  test('senza cornice, o con una cornice rotta, non se ne usa nessuna', () {
    expect(Ritaglio.fromMap(null), isNull);
    expect(Ritaglio.fromMap({'x': 0, 'y': 0}), isNull);
    expect(Ritaglio.fromMap({'x': 0, 'y': 0, 'w': 0, 'h': 1}), isNull);
    expect(Ritaglio.fromMap({'x': 0, 'y': 0, 'w': 2, 'h': 1}), isNull);
  });
}

import 'package:crasy/features/moderation/domain/report_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gli stati di una segnalazione, letti da come stanno scritti sul database.
///
/// La cosa che questo file difende e' una sola e vale piu' delle altre: **le
/// segnalazioni gia' in archivio non devono sparire** il giorno in cui la
/// dashboard esiste. Portano scritto `open`, un valore che non si scrive piu',
/// e vogliono dire esattamente "arrivata, nessuno l'ha guardata".
void main() {
  test('i quattro stati si leggono per come sono scritti', () {
    expect(ReportStatus.fromWire('new'), ReportStatus.fresh);
    expect(ReportStatus.fromWire('reviewing'), ReportStatus.reviewing);
    expect(ReportStatus.fromWire('fake'), ReportStatus.fake);
    expect(ReportStatus.fromWire('removed'), ReportStatus.removed);
  });

  test('le segnalazioni vecchie, scritte open, restano nuove', () {
    expect(ReportStatus.fromWire('open'), ReportStatus.fresh);
  });

  test('senza stato, o con uno inventato, si legge nuova', () {
    expect(ReportStatus.fromWire(null), ReportStatus.fresh);
    expect(ReportStatus.fromWire(''), ReportStatus.fresh);
    expect(ReportStatus.fromWire('qualcosa'), ReportStatus.fresh);
  });

  test('aperta vuol dire che c\'e\' ancora una decisione da prendere', () {
    expect(ReportStatus.fresh.isOpen, isTrue);
    expect(ReportStatus.reviewing.isOpen, isTrue);
    expect(ReportStatus.fake.isOpen, isFalse);
    expect(ReportStatus.removed.isOpen, isFalse);
  });

  test('la segnalazione nasce nuova, non gia\' decisa', () {
    expect(ReportStatus.fresh.wire, 'new');
  });
}

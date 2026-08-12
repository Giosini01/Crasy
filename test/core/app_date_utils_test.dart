import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quanto manca', () {
    test('oltre il giorno si contano giorni e ore', () {
      expect(
        AppDateUtils.formatTimeLeft(const Duration(days: 3, hours: 4)),
        '3g 4h',
      );
    });

    test('oltre l\'ora si contano ore e minuti', () {
      expect(
        AppDateUtils.formatTimeLeft(const Duration(hours: 4, minutes: 32)),
        '4h 32m',
      );
    });

    test('sotto l\'ora compaiono i secondi, a due cifre', () {
      expect(
        AppDateUtils.formatTimeLeft(const Duration(minutes: 32, seconds: 9)),
        '32m 09s',
      );
    });

    test('a tempo scaduto si dice che e\' chiusa', () {
      expect(AppDateUtils.formatTimeLeft(Duration.zero), 'chiusa');
      expect(
        AppDateUtils.formatTimeLeft(const Duration(seconds: -5)),
        'chiusa',
      );
    });
  });

  group('quanto tempo fa', () {
    final now = DateTime(2026, 8, 12, 12);

    test('sotto il minuto si dice solo "ora"', () {
      expect(
        AppDateUtils.shortTimeAgo(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        'ora',
      );
    });

    test('la scala sale da minuti a giorni', () {
      expect(
        AppDateUtils.shortTimeAgo(
          now.subtract(const Duration(minutes: 35)),
          now: now,
        ),
        '35m',
      );
      expect(
        AppDateUtils.shortTimeAgo(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        '2h',
      );
      expect(
        AppDateUtils.shortTimeAgo(
          now.subtract(const Duration(days: 3)),
          now: now,
        ),
        '3g',
      );
    });
  });

  test('la chiave di giornata ha sempre due cifre', () {
    expect(AppDateUtils.dateKey(DateTime(2026, 8, 9)), '2026-08-09');
    expect(AppDateUtils.dateKey(DateTime(2026, 12, 25)), '2026-12-25');
  });
}

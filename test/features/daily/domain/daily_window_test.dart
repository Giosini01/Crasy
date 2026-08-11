import 'package:app_incontri/features/daily/domain/entities/daily_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Le fasce di riferimento sono 12:00, 15:00 e 21:00, ognuna lunga un'ora.
  group('DailyWindow.openSlotAt', () {
    test('is closed before the first slot', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 11, 59)), isNull);
    });

    test('opens exactly on the hour', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 12)), 0);
    });

    test('stays open until the last minute of the slot', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 12, 59)), 0);
    });

    test('closes when the hour is over', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 13)), isNull);
    });

    test('recognises the afternoon and evening slots', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 15, 30)), 1);
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 21, 30)), 2);
    });

    test('is closed between two slots', () {
      expect(DailyWindow.openSlotAt(DateTime(2026, 8, 9, 17)), isNull);
    });
  });

  group('DailyWindow.nextOpening', () {
    test('points at the first slot early in the morning', () {
      expect(
        DailyWindow.nextOpening(DateTime(2026, 8, 9, 8)),
        DateTime(2026, 8, 9, 12),
      );
    });

    test('points at the next slot while one is open', () {
      expect(
        DailyWindow.nextOpening(DateTime(2026, 8, 9, 12, 30)),
        DateTime(2026, 8, 9, 15),
      );
    });

    test('points at tomorrow once the last slot has passed', () {
      expect(
        DailyWindow.nextOpening(DateTime(2026, 8, 9, 23)),
        DateTime(2026, 8, 10, 12),
      );
    });

    test('rolls over the end of the month', () {
      expect(
        DailyWindow.nextOpening(DateTime(2026, 8, 31, 23)),
        DateTime(2026, 9, 1, 12),
      );
    });

    test('rolls over the end of the year', () {
      expect(
        DailyWindow.nextOpening(DateTime(2026, 12, 31, 23)),
        DateTime(2027, 1, 1, 12),
      );
    });
  });

  test('endOf closes a slot one hour after it opened', () {
    expect(
      DailyWindow.endOf(1, DateTime(2026, 8, 9, 15, 20)),
      DateTime(2026, 8, 9, 16),
    );
  });

  test('one shot a day, whatever the number of slots', () {
    // Le fasce dicono **quando**, non **quante volte**: sono tre occasioni per
    // un solo scatto. E' la regola su cui poggia tutta l'app, e non deve
    // seguire per sbaglio il numero delle fasce.
    expect(DailyWindow.maxPerDay, 1);
    expect(DailyWindow.slotHours.length, greaterThan(1));
  });

  test('labels are padded to the clock format', () {
    expect(DailyWindow.labelOf(0), '12:00');
    expect(DailyWindow.labelOf(2), '21:00');
  });
}

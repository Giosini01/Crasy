import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_access.dart';
import 'package:app_incontri/features/daily/domain/entities/daily_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fasce di riferimento: 12:00, 15:00, 21:00.
  final noonSlot = DateTime(2026, 8, 9, 12, 30);
  final betweenSlots = DateTime(2026, 8, 9, 17);

  Daily daily({DailyStatus status = DailyStatus.active, int? slot = 0}) {
    return Daily(
      id: 'daily-$slot-${status.name}',
      userId: 'user-1',
      storagePath: 'dailies/user-1/2026-08-09/daily.jpg',
      dateKey: '2026-08-09',
      slot: slot,
      status: status,
    );
  }

  test('an open slot with nothing published allows capture', () {
    final access = DailyAccess.resolve(now: noonSlot, todayDailies: const []);

    expect(access.windowOpen, isTrue);
    expect(access.openSlot, 0);
    expect(access.canCapture, isTrue);
    expect(access.discoverUnlocked, isFalse);
    expect(access.remaining, DailyWindow.maxPerDay);
    expect(access.boundary, DateTime(2026, 8, 9, 13));
  });

  test('the slot of the moment can be used only once', () {
    final access = DailyAccess.resolve(
      now: noonSlot,
      todayDailies: [daily()],
    );

    expect(access.usedCurrentSlot, isTrue);
    expect(access.canCapture, isFalse);
    // Restano le altre due fasce della giornata.
    expect(access.remaining, DailyWindow.maxPerDay - 1);
    expect(access.discoverUnlocked, isTrue);
  });

  test('one photo closes the whole day, whatever slot it was taken in', () {
    final access = DailyAccess.resolve(
      now: noonSlot,
      todayDailies: [daily(slot: 2)],
    );

    // La fascia di adesso e' libera, ma la giornata no: se ne fa **una sola**,
    // e non esiste modo di rifarla.
    expect(access.usedCurrentSlot, isFalse);
    expect(access.limitReached, isTrue);
    expect(access.canCapture, isFalse);
  });

  test('between two slots nothing can be captured', () {
    final access = DailyAccess.resolve(
      now: betweenSlots,
      todayDailies: const [],
    );

    expect(access.windowOpen, isFalse);
    expect(access.canCapture, isFalse);
    // Il countdown punta all'apertura successiva.
    expect(access.boundary, DateTime(2026, 8, 9, 21));
  });

  test('discover stays open between slots once something is published', () {
    final access = DailyAccess.resolve(
      now: betweenSlots,
      todayDailies: [daily()],
    );

    expect(access.windowOpen, isFalse);
    expect(access.canCapture, isFalse);
    expect(access.discoverUnlocked, isTrue);
  });

  test('using every slot exhausts the day', () {
    final access = DailyAccess.resolve(
      now: noonSlot,
      todayDailies: [daily(), daily(slot: 1), daily(slot: 2)],
    );

    expect(access.limitReached, isTrue);
    expect(access.remaining, 0);
    expect(access.usedSlots, {0, 1, 2});
  });

  test('a photo awaiting verification does not unlock discover', () {
    final access = DailyAccess.resolve(
      now: noonSlot,
      todayDailies: [daily(status: DailyStatus.draft)],
    );

    expect(access.discoverUnlocked, isFalse);
    expect(access.verifying, isTrue);
    expect(access.usedCurrentSlot, isTrue);
  });

  test('a rejected photo frees its slot again', () {
    final access = DailyAccess.resolve(
      now: noonSlot,
      todayDailies: [daily(status: DailyStatus.rejected)],
    );

    expect(access.usedToday, 0);
    expect(access.usedCurrentSlot, isFalse);
    expect(access.canCapture, isTrue);
    expect(access.justRejected, isTrue);
    expect(access.discoverUnlocked, isFalse);
  });

  test('timeToBoundary clamps to zero once the boundary has passed', () {
    final access = DailyAccess.resolve(now: noonSlot, todayDailies: const []);

    expect(
      access.timeToBoundary(DateTime(2026, 8, 9, 12, 45)),
      const Duration(minutes: 15),
    );
    expect(access.timeToBoundary(DateTime(2026, 8, 9, 14)), Duration.zero);
  });
}

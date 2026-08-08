import 'package:app_incontri/features/daily/domain/entities/daily.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily exposes active state from enum status', () {
    const daily = Daily(
      id: 'daily-1',
      userId: 'user-1',
      storagePath: 'dailies/user-1/daily-1.jpg',
      dateKey: '2026-08-08',
      status: DailyStatus.active,
    );

    expect(daily.isActive, isTrue);
  });
}

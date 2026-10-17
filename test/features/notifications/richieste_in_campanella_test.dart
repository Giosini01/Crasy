import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/friends/domain/entities/friendship.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/notifications/domain/entities/app_notification.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Chi ha iniziato a seguirti sta in RICHIESTE.**
///
/// La sezione c'era, con il suo numero e il tocco che porta a "Ti seguono", ma
/// nessuno ci metteva le righe: la push "Qualcuno ha iniziato a seguirti"
/// atterrava su "Niente in RICHIESTE".
void main() {
  test('chi ti segue compare in campanella, con il nome della push', () async {
    final container = ProviderContainer(
      overrides: [
        storedNotificationsProvider.overrideWith(
          (ref) => Stream.value(const <AppNotification>[]),
        ),
        incomingRequestsProvider.overrideWith(
          (ref) => Stream.value([
            FriendRequest(
              fromUserId: 'id-di-mario',
              fromUsername: 'mario',
              createdAt: DateTime(2026, 10, 17, 18),
            ),
          ]),
        ),
        myEntriesProvider.overrideWith((ref) => Stream.value(const [])),
        endedChallengesProvider.overrideWith((ref) => Stream.value(const [])),
        revealsSeenProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Gli elenchi arrivano da degli stream: si aspetta che ci siano.
    container.listen(notificationsProvider, (_, _) {});
    await container.read(incomingRequestsProvider.future);
    await container.read(storedNotificationsProvider.future);

    final riga = container.read(notificationsProvider).single;

    // Lo stesso nome che porta la push: toccandola, la riga si accende.
    expect(riga.id, 'amicizia_id-di-mario');
    expect(riga.group, NotificationGroup.requests);
    expect(riga.message, '@mario ti ha seguito');
  });
}

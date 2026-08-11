import 'package:app_incontri/features/chat/domain/entities/chat_message.dart';
import 'package:app_incontri/features/matches/domain/entities/match_person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchPerson person({
    DateTime? capturedAt,
    String photoUrl = 'https://example.com/oggi.jpg',
    String profilePhotoUrl = 'https://example.com/profilo.jpg',
    List<String> interests = const [],
  }) {
    return MatchPerson(
      userId: 'u2',
      name: 'Anna',
      age: 28,
      photoUrl: photoUrl,
      icebreaker: '',
      vibe: 'relax',
      interests: interests,
      distanceKm: 0.4,
      message: '',
      myMessage: '',
      photoCapturedAt: capturedAt,
      profilePhotoUrl: profilePhotoUrl,
      matchedAt: DateTime(2026, 8, 10, 12),
    );
  }

  final now = DateTime(2026, 8, 10, 20);

  test('an Istantanea from a few hours ago is still the match photo', () {
    final anna = person(capturedAt: now.subtract(const Duration(hours: 7)));

    expect(anna.expiredAt(now), isFalse);
    expect(anna.photoAt(now), 'https://example.com/oggi.jpg');
    expect(
      anna.photoExpiresAt,
      now.subtract(const Duration(hours: 7)).add(const Duration(hours: 24)),
    );
  });

  test('past twenty-four hours the photo falls back to the profile one', () {
    final anna = person(capturedAt: now.subtract(const Duration(hours: 25)));

    // Il match **non** muore con la foto: resta la persona, cambia solo cosa
    // si vede.
    expect(anna.expiredAt(now), isTrue);
    expect(anna.photoAt(now), 'https://example.com/profilo.jpg');
  });

  test('a match with no photo at all is treated as expired', () {
    final anna = person(capturedAt: null, photoUrl: '');

    expect(anna.expiredAt(now), isTrue);
    expect(anna.photoAt(now), 'https://example.com/profilo.jpg');
  });

  test('shared interests are counted, never scored', () {
    final anna = person(interests: const ['libri', 'musica', 'mare']);

    expect(anna.sharedLabelWith(const ['musica']), '1 interesse in comune');
    expect(
      anna.sharedLabelWith(const ['musica', 'mare', 'sport']),
      '2 interessi in comune',
    );
    expect(anna.sharedLabelWith(const ['sport']), isEmpty);
    expect(anna.sharedLabelWith(const []), isEmpty);
  });

  test('the chat address is the same computed from either side', () {
    // Le due parti lo calcolano da sole e devono ottenere la stessa stringa:
    // e' su questo che si appoggia anche il permesso di scrittura.
    expect(ChatMessage.chatIdOf('zeta', 'alfa'), 'alfa_zeta');
    expect(
      ChatMessage.chatIdOf('alfa', 'zeta'),
      ChatMessage.chatIdOf('zeta', 'alfa'),
    );
  });
}

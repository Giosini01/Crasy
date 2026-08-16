import 'package:crasy/features/profile/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = UserProfile(
    id: 'user-1',
    username: 'martina',
    birthDate: DateTime(2000, 1, 1),
    bio: 'Faccio cose assurde.',
    city: 'Napoli',
    createdAt: null,
    updatedAt: null,
    onboardingCompleted: true,
  );

  test('le iniziali sono le prime due lettere, in maiuscolo', () {
    expect(profile.initials, 'MA');
    expect(profile.copyWith(username: 'a').initials, 'A');
    expect(profile.copyWith(username: '').initials, '?');
  });

  test('la foto conta solo se c\'e\' davvero un indirizzo', () {
    expect(profile.hasPhoto, isFalse);
    expect(profile.copyWith(photoUrl: '').hasPhoto, isFalse);
    expect(profile.copyWith(photoUrl: 'https://x/y.jpg').hasPhoto, isTrue);
  });

  test('una bio di soli spazi vale come assente', () {
    expect(profile.hasBio, isTrue);
    expect(profile.copyWith(bio: '   ').hasBio, isFalse);
  });

  test('copyWith cambia un campo e lascia stare gli altri', () {
    final updated = profile.copyWith(city: 'Milano');

    expect(updated.city, 'Milano');
    expect(updated.username, profile.username);
    expect(updated.bio, profile.bio);
  });

  test('due profili con gli stessi campi sono uguali', () {
    expect(profile.copyWith(), profile);
    expect(profile.copyWith().hashCode, profile.hashCode);
    expect(profile.copyWith(username: 'altra'), isNot(profile));
  });
}

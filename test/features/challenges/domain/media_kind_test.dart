import 'package:crasy/features/challenges/domain/entities/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('il nome scritto sul database torna il vincolo giusto', () {
    expect(MediaKind.fromName('photo'), MediaKind.photo);
    expect(MediaKind.fromName('video'), MediaKind.video);
  });

  test('senza vincolo scritto la challenge chiede una foto', () {
    // Le challenge lanciate prima che il vincolo esistesse chiedevano tutte una
    // foto: leggerle come "video" cambierebbe le regole a gara in corso, a
    // gente che ha gia' mandato la sua.
    expect(MediaKind.fromName(null), MediaKind.photo);
    expect(MediaKind.fromName(''), MediaKind.photo);
    expect(MediaKind.fromName('gif'), MediaKind.photo);
  });

  test('un video dura al massimo mezzo minuto', () {
    expect(MediaKind.maxVideoDuration, const Duration(seconds: 30));
    expect(MediaKind.video.isVideo, isTrue);
    expect(MediaKind.photo.isVideo, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:sinifcepte/features/student_photos/data/foto_alici.dart';

/// Seçicinin geçici kopyası silinir; ASIL dosya asla (Windows'ta seçici
/// asıl dosyanın yolunu veriyor).
void main() {
  final gecici = p.join(p.current, 'onbellek');

  test('uygulamanın geçici dizinindeki kopya silinebilir', () {
    expect(geciciKopyaMi(p.join(gecici, 'image_picker123.jpg'), gecici), isTrue);
    expect(geciciKopyaMi(p.join(gecici, 'alt', 'x.jpg'), gecici), isTrue);
  });

  test('KRITIK: geçici dizin dışındaki (asıl) dosya ASLA silinmez', () {
    expect(geciciKopyaMi(p.join(p.current, 'Resimler', 'ogrenci.jpg'), gecici), isFalse);
    expect(geciciKopyaMi(p.join(gecici, '..', 'Resimler', 'ogrenci.jpg'), gecici), isFalse,
        reason: '.. ile dışarı çıkan yol');
    expect(geciciKopyaMi('${gecici}_baska${p.separator}x.jpg', gecici), isFalse,
        reason: 'aynı önekle başlayan başka dizin');
    expect(geciciKopyaMi(gecici, gecici), isFalse, reason: 'dizinin kendisi');
  });
}

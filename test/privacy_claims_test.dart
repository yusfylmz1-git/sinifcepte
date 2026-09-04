import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gizlilik metnindeki iddialar KODLA uyusuyor mu?
///
/// ## Neden bu test var
/// Ayni hataya UC KEZ dusuldu:
///   1. "ogrenci verisi buluta aktarilmaz" -> studentName buluta gidiyordu
///   2. "ogrenci numaralari cihazda kalir"  -> studentNumber buluta gidiyordu
///   3. (bu testin engelledigi bir sonraki)
///
/// Metin elle yazildigi icin kod degisince yalan haline geliyor.
/// Bu test, "cihazda kalir" denen bir alanin buluta yazilmadigini
/// KAYNAK KODDAN dogrular.
///
/// Yanlis beyan hukuki risktir; bir insanin gozden kacirmasina
/// birakilmamali.
void main() {
  /// Bulut deposu dosyalari — buraya yazilan her sey SUNUCUYA gider.
  const bulutDosyalari = [
    'lib/features/parent_portal/data/repositories/cloud_token_repository.dart',
    'lib/features/parent_portal/data/repositories/cloud_communication_repository.dart',
  ];

  String bulutKodu() {
    final b = StringBuffer();
    for (final yol in bulutDosyalari) {
      final f = File(yol);
      if (f.existsSync()) b.write(f.readAsStringSync());
    }
    return b.toString();
  }

  String gizlilikMetni() =>
      File('lib/features/profile/screens/legal_document_screen.dart')
          .readAsStringSync();

  /// [alan] bulut deposuna YAZILIYOR mu?
  ///
  /// Yalnizca yazma aranir: `'alan': deger` kalibi. Okuma
  /// (`data['alan']`) sayilmaz, cunku okuma veriyi buluta gondermez.
  bool bulutaYaziliyor(String alan) {
    final kod = bulutKodu();
    return kod.contains("'$alan':");
  }

  group('Cihazda kaldigi soylenen veriler GERCEKTEN cihazda mi', () {
    test('KRITIK: veli telefonu buluta yazilmiyor', () {
      expect(gizlilikMetni(), contains('Veli telefon numaraları'),
          reason: 'metin bu iddiayi tasiyor olmali');
      expect(bulutaYaziliyor('parentPhone'), isFalse,
          reason: 'metin "cihazda kalir" diyor; kod aksini yapiyorsa '
              'bu YANLIS BEYANDIR');
    });

    test('KRITIK: sinav notlari buluta yazilmiyor', () {
      expect(bulutaYaziliyor('score'), isFalse);
      expect(bulutaYaziliyor('grade'), isFalse);
      expect(bulutaYaziliyor('examScore'), isFalse);
    });

    test('KRITIK: katilim ve devamsizlik buluta yazilmiyor', () {
      expect(bulutaYaziliyor('starsCount'), isFalse);
      expect(bulutaYaziliyor('attendance'), isFalse);
      expect(bulutaYaziliyor('homeworkStatus'), isFalse);
    });

    test('KRITIK: ders programi buluta yazilmiyor', () {
      expect(bulutaYaziliyor('lessonName'), isFalse);
      expect(bulutaYaziliyor('lessonHourIndex'), isFalse);
    });
  });

  group('Buluta gittigi soylenen veriler metinde YAZIYOR mu', () {
    test('KRITIK: ogrenci adi hem kodda hem metinde', () {
      expect(bulutaYaziliyor('studentName'), isTrue,
          reason: 'bu alan gercekten buluta gidiyor');
      expect(gizlilikMetni(), contains('adı, soyadı'),
          reason: 'metin bunu ACIKCA soylemeli');
    });

    test('KRITIK: ogrenci NUMARASI hem kodda hem metinde', () {
      // Bu, denetimde yakalanan ikinci yalandi: metin "ogrenci
      // numaralari cihazda kalir" diyordu ama studentNumber
      // parent_tokens ve parent_links icinde buluta gidiyor.
      expect(bulutaYaziliyor('studentNumber'), isTrue);
      expect(gizlilikMetni(), contains('okul numarası'),
          reason: 'numaranin buluta gittigi yazilmali');
    });

    test('veli adi metinde geciyor', () {
      expect(bulutaYaziliyor('parentName'), isTrue);
      expect(gizlilikMetni(), contains('Velinin adı'));
    });
  });

  group('Yanlis beyanlar geri gelmemeli', () {
    test('KRITIK: "buluta aktarilmaz" iddiasi yok', () {
      // Yalnizca KULLANICIYA GOSTERILEN metin denetlenir. Aciklama
      // satirlari eski hatayi anlatmak icin bu ifadeyi tasiyabilir.
      final gorunenSatirlar = gizlilikMetni()
          .split('\n')
          .where((l) {
            final k = l.trimLeft();
            return !k.startsWith('//') && !k.startsWith('///');
          })
          .join('\n');

      expect(gorunenSatirlar.contains('buluta aktarılmaz'), isFalse,
          reason: 'ogrenci adi buluta gidiyor; bu ifade yanlis beyandir');
    });

    test('KRITIK: ogrenci numarasi "cihazda kalir" listesinde degil', () {
      final metin = gizlilikMetni();
      final i = metin.indexOf('Yalnızca cihazda kalan veriler');
      final j = metin.indexOf('Buluta gönderilen veriler');
      if (i == -1 || j == -1 || j <= i) return;

      final cihazBolumu = metin.substring(i, j);
      expect(cihazBolumu.contains('Öğrenci numaraları'), isFalse,
          reason: 'studentNumber buluta gidiyor; cihaz listesinde olamaz');
    });
  });

  group('Veli telefonu artik SORULMUYOR', () {
    test('KRITIK: baglanma ekraninda telefon alani yok', () {
      // Alan vardi ama hicbir yerde kullanilmiyordu: veli girdigi
      // numara bag kaydinda kaliyor, ogretmen hicbir ekranda
      // goremiyordu. Toplanan ama kullanilmayan kisisel veri KVKK
      // acisindan savunulamaz.
      final kod = File(
        'lib/features/parent_portal/presentation/screens/'
        'parent_student_connect_screen.dart',
      ).readAsStringSync();

      expect(kod.contains('_parentPhoneController'), isFalse,
          reason: 'telefon alani kaldirilmali');
      expect(kod.contains('İletişim Telefon Numarası'), isFalse);
    });

    test('KRITIK: bag kaydina null geciriliyor', () {
      final kod = File(
        'lib/features/parent_portal/presentation/screens/'
        'parent_student_connect_screen.dart',
      ).readAsStringSync();
      expect(kod, contains('parentPhone: null'));
    });

    test('ogretmen kendi girdigi numaralari kullanmaya devam ediyor', () {
      // Veli Rehberi ogretmenin girdigi numaralarla calisir; bu
      // ozellik KALDIRILMADI.
      final kod = File(
        'lib/features/classes/screens/parent_contacts_screen.dart',
      ).readAsStringSync();
      expect(kod, contains('parentPhone'));
    });
  });
}

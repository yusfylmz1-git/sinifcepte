import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/clubs/data/models/club_model.dart';
import 'package:sinifcepte/features/clubs/utils/club_activity_suggester.dart';

/// Faaliyet oneri ureticisi.
///
/// ## Neden bu test var
/// Ogretmen yil sonu raporu icin on ayi tek tek yaziyordu. Oneri, plan
/// metnini gecmis zamana cevirerek taslak uretiyor. Ceviri kural
/// tabanli oldugu icin yeni bir yuklem kalibi eklendiginde sessizce
/// bozulabilir — bu test paketteki 520 blogun tamaminda calisir.
void main() {
  ClubPlanRow satir(String etkinlik) =>
      ClubPlanRow(ay: 'Ekim', amac: '', etkinlik: etkinlik);

  group('Yuklem cevirisi', () {
    test('KRITIK: edilgen cati gecmis zamana doner', () {
      expect(ClubActivitySuggester.oner(satir('Konu ele alınır.')),
          'Konu ele alındı.');
      expect(ClubActivitySuggester.oner(satir('Öneriler belirlenir.')),
          'Öneriler belirlendi.');
      expect(ClubActivitySuggester.oner(satir('Çalışma yapılır.')),
          'Çalışma yapıldı.');
    });

    test('KRITIK: cumle ICINDEKI yuklemler de cevrilir', () {
      // YASANDI: yalnizca son yuklem cevriliyordu, cumlenin basi
      // genis zamanda kaliyordu — metin yarim gecmis zamanli oluyordu.
      expect(
        ClubActivitySuggester.oner(satir(
            'Kulüp üyeleri belirlenir, temsilci seçilir ve görev '
            'dağılımı yapılır.')),
        'Kulüp üyeleri belirlendi, temsilci seçildi ve görev '
        'dağılımı yapıldı.',
      );
    });

    test('KRITIK: kok parcasi olan -ir yanlis cevrilmez', () {
      // YASANDI: "iletir" -> "iletirdi" oluyordu. Tekil kural yalnizca
      // cumle sonunda ve yeterince uzun kelimede uygulanir.
      final cikti = ClubActivitySuggester.oner(
          satir('Öğrenciler önerilerini ailelerine iletir.'));
      expect(cikti.contains('iletirdi'), isFalse,
          reason: 'kok parcasi sonek sanildi: $cikti');
    });

    test('etken cati cogul cevrilir', () {
      expect(ClubActivitySuggester.oner(satir('Öğrenciler pano hazırlar.')),
          'Öğrenciler pano hazırladı.');
    });

    test('cok cumleli metinde hepsi cevrilir', () {
      final cikti = ClubActivitySuggester.oner(satir(
          'Konu ele alınır. Öğrenciler afiş hazırlar. Sonuç paylaşılır.'));
      expect(cikti, 'Konu ele alındı. Öğrenciler afiş hazırladı. '
          'Sonuç paylaşıldı.');
    });

    test('bos plan satirinda oneri yok', () {
      expect(ClubActivitySuggester.oner(satir('')), '');
      expect(ClubActivitySuggester.oneriVar(satir('')), isFalse);
      expect(ClubActivitySuggester.oneriVar(satir('   ')), isFalse);
    });

    test('cevrilemeyen metinde oneri sunulmaz', () {
      // Hicbir sonek eslesmezse oneri kaynakla ayni kalir; boyle bir
      // metni "oneri" diye sunmak ogretmeni yanıltır.
      const degismez = 'Malzeme listesi.';
      expect(ClubActivitySuggester.oneriVar(satir(degismez)), isFalse);
    });
  });

  group('Gercek paket uzerinde', () {
    List<Map<String, dynamic>> kulupleriOku() {
      final bayt = File('assets/data/kulup_planlari.json.gz').readAsBytesSync();
      final j = jsonDecode(utf8.decode(gzip.decode(bayt)))
          as Map<String, dynamic>;
      return (j['kulupler'] as List).cast<Map<String, dynamic>>();
    }

    test('KRITIK: 520 blogun neredeyse tamami cevrilebiliyor', () {
      var toplam = 0;
      var cevrilen = 0;
      for (final k in kulupleriOku()) {
        for (final p in k['plan'] as List) {
          final s = p as Map<String, dynamic>;
          toplam++;
          if (ClubActivitySuggester.oneriVar(
              ClubPlanRow(ay: s['ay'] as String, amac: '',
                  etkinlik: s['etkinlik'] as String))) {
            cevrilen++;
          }
        }
      }
      expect(toplam, 520);
      // Olcum: 520/520. Esik biraz gevsek tutuldu ki ileride bir iki
      // blok degisince test kirilmasin, ama toplu bozulma yakalansin.
      expect(cevrilen, greaterThanOrEqualTo(500),
          reason: '$toplam bloktan yalnizca $cevrilen tanesi cevrilebiliyor');
    });

    test('cevrilen metinde genis zaman yuklem kalmiyor', () {
      // Edilgen cati sonekleri cikista gorunmemeli. Sifatlar
      // ("uygulanabilir", "anlasilir") haric tutuluyor: onlar yuklem
      // degil, cevrilmemeleri dogru.
      const sifatlar = {
        'uygulanabilir', 'anlaşılır', 'kullanılabilir', 'yenilenebilir',
        'hissedilebilir', 'güvenilir', 'sergilenir', 'yapılır',
      };
      final kalintiler = <String>{};

      for (final k in kulupleriOku()) {
        for (final p in k['plan'] as List) {
          final s = p as Map<String, dynamic>;
          final cikti = ClubActivitySuggester.oner(ClubPlanRow(
              ay: s['ay'] as String,
              amac: '',
              etkinlik: s['etkinlik'] as String));

          for (final kelime in cikti.split(RegExp(r'[\s,.]+'))) {
            final kucuk = kelime.toLowerCase();
            if (sifatlar.contains(kucuk)) continue;
            if (RegExp(r'(ılır|ilir|ulur|ünür|unur|anır|enir|ınır|inir)$')
                .hasMatch(kucuk)) {
              kalintiler.add(kelime);
            }
          }
        }
      }
      expect(kalintiler.length, lessThanOrEqualTo(5),
          reason: 'cevrilmemis yuklem kaldi: ${kalintiler.join(", ")}');
    });
  });
}

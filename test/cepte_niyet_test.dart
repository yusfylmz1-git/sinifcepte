import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/assistant/data/cepte_niyet.dart';

/// Cepte niyet cozumleyici.
///
/// ## Neden kural, model degil
/// Cihazda calisan kucuk bir dil modeli Turkce egitim jargonunda kazanim
/// UYDURABILIR. Bu uygulamanin ciktisi teftise gidiyor; en buyuk risk
/// yanlis resmi evrak basmak. Kural tabanli esleme ya dogru anlar ya
/// "anlamadim" der — arada bir sey yoktur.
///
/// Bu dosya, cozumleyicinin YANLIS ANLAMADIGINI kilitler.
void main() {
  CepteNiyet coz(String s) => CepteCozumleyici.coz(s);

  group('Belge uretimi', () {
    test('KRITIK: sinif + ders + tur birlikte cikarilir', () {
      final n = coz('5. sınıf türkçe yıllık plan');
      expect(n.tur, CepteNiyetTuru.yillikPlan);
      expect(n.sinif, 5);
      expect(n.dersKodu, 'TURKCE');
      expect(n.hazir, isTrue);
    });

    test('Gunluk plan ayri tanınır', () {
      final n = coz('6. sınıf matematik günlük plan');
      expect(n.tur, CepteNiyetTuru.gunlukPlan);
      expect(n.sinif, 6);
      expect(n.dersKodu, 'MAT');
    });

    test('Hafta bilgisi tasinir', () {
      final n = coz('5. sınıf türkçe 3. hafta günlük plan');
      expect(n.hafta, 3);
      expect(n.tur, CepteNiyetTuru.gunlukPlan);
    });

    test('Turkce karakter yazilmadan da anlar', () {
      // Ogretmen telefonda hizlica ASCII yaziyor.
      final n = coz('5 sinif turkce yillik plan');
      expect(n.sinif, 5);
      expect(n.dersKodu, 'TURKCE');
      expect(n.tur, CepteNiyetTuru.yillikPlan);
    });

    test('Sube adiyla sinif cikarilir', () {
      expect(coz('5-A türkçe yıllık plan').sinif, 5);
      expect(coz('7/B matematik günlük plan').sinif, 7);
    });
  });

  group('Eksik bilgi: TAHMIN YOK', () {
    test('KRITIK: ders yoksa uretime gecilmez', () {
      final n = coz('yıllık plan hazırla');
      expect(n.tur, CepteNiyetTuru.yillikPlan);
      expect(n.hazir, isFalse, reason: 'eksik bilgiyle belge basilmamali');
      expect(n.eksikler, containsAll(['sinif', 'ders']));
    });

    test('Sinif yoksa sorulur', () {
      final n = coz('türkçe yıllık plan');
      expect(n.dersKodu, 'TURKCE');
      expect(n.eksikler, contains('sinif'));
      expect(n.hazir, isFalse);
    });

    test('Bos cumle belirsizdir', () {
      expect(coz('').tur, CepteNiyetTuru.belirsiz);
      expect(coz('   ').tur, CepteNiyetTuru.belirsiz);
    });

    test('KRITIK: anlasilmayan cumlede is uydurulmaz', () {
      final n = coz('bugün hava çok güzel');
      expect(n.tur, CepteNiyetTuru.belirsiz);
      expect(n.hazir, isFalse);
    });
  });

  group('Kelime siniri tuzagi', () {
    test('KRITIK: "din" kelimesi "aydin" icinde eslesmez', () {
      final n = coz('aydın öğretmenin yıllık planı');
      expect(n.dersKodu, isNot('DIN'));
    });

    test('KRITIK: "fen" kelimesi "telefon" icinde eslesmez', () {
      final n = coz('telefon numarası');
      expect(n.dersKodu, isNull);
    });

    test('Gercek ders adi yakalanir', () {
      expect(coz('4. sınıf fen bilimleri yıllık plan').dersKodu, 'FEN');
      expect(coz('8. sınıf din kültürü günlük plan').dersKodu, 'DIN');
    });
  });

  group('En uzun eslesme kazanir', () {
    test('KRITIK: "beden egitimi ve oyun" BEDEN_OYUN olur', () {
      expect(coz('2. sınıf beden eğitimi ve oyun yıllık plan').dersKodu,
          'BEDEN_OYUN');
    });

    test('Sade "beden egitimi" BEDEN olur', () {
      expect(coz('6. sınıf beden eğitimi yıllık plan').dersKodu, 'BEDEN');
    });

    test('"turk dili ve edebiyati" EDEBIYAT olur', () {
      expect(coz('9. sınıf türk dili ve edebiyatı yıllık plan').dersKodu,
          'EDEBIYAT');
    });
  });

  group('Ekran acma', () {
    test('KRITIK: uretim gerektirmeyen is ekrana goturur', () {
      final n = coz('sınıfıma öğretmen ekle');
      expect(n.tur, CepteNiyetTuru.ekranAc);
      expect(n.ekran, CepteEkran.ogretmenKadrosu);
    });

    test('Kurul tutanagi ekrani', () {
      // Toplanti tarihi ve kararlar ogretmenden gelir; Cepte UYDURMAZ.
      final n = coz('zümre tutanağı');
      expect(n.tur, CepteNiyetTuru.ekranAc);
      expect(n.ekran, CepteEkran.kurulTutanaklari);
    });

    test('Devamsizlik ekrani', () {
      expect(coz('devamsızlık takibi').ekran, CepteEkran.devamsizlik);
    });

    test('Ders programi ekrani', () {
      expect(coz('ders programım').ekran, CepteEkran.dersProgrami);
    });

    test('Oturma plani ekrani', () {
      expect(coz('oturma planı').ekran, CepteEkran.oturmaPlani);
    });
  });

  group('Kazanim sorusu', () {
    test('KRITIK: hafta sorusu kazanim niyeti uretir', () {
      final n = coz('5. sınıf türkçe 3. hafta ne işleyeceğim');
      expect(n.tur, CepteNiyetTuru.kazanimSor);
      expect(n.sinif, 5);
      expect(n.dersKodu, 'TURKCE');
      expect(n.hafta, 3);
    });

    test('Plan istegi kazanim sorusunun onune gecer', () {
      // "yillik plan" acikca belge istiyor; kazanim sorusu degil.
      final n = coz('5. sınıf türkçe yıllık plan kazanımları');
      expect(n.tur, CepteNiyetTuru.yillikPlan);
    });
  });
}

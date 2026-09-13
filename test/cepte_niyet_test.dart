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

  group('Belirli gun ve haftalar', () {
    test('KRITIK: ogretmen TARIHI yaziyor, adi degil', () {
      // "23 nisan" diyor; verideki ad "Ulusal Egemenlik ve Cocuk
      // Bayrami". Ikisi de ayni ekrana gitmeli.
      expect(coz('23 nisan').ekran, CepteEkran.belirliGunler);
      expect(coz('29 ekim').ekran, CepteEkran.belirliGunler);
      expect(coz('19 mayıs').ekran, CepteEkran.belirliGunler);
    });

    test('Gun adiyla da bulunur', () {
      expect(coz('cumhuriyet bayramı panosu').ekran, CepteEkran.belirliGunler);
      expect(coz('öğretmenler günü').ekran, CepteEkran.belirliGunler);
      expect(coz('atatürk haftası').ekran, CepteEkran.belirliGunler);
    });

    test('Hafta adlari da taniniyor', () {
      expect(coz('orman haftası').ekran, CepteEkran.belirliGunler);
      expect(coz('kızılay haftası').ekran, CepteEkran.belirliGunler);
      expect(coz('engelliler haftası').ekran, CepteEkran.belirliGunler);
    });
  });

  group('Bitisik yazim', () {
    test('KRITIK: "23nisan" da taniniyor', () {
      // Cihazda olculdu: ogretmen telefonda bitisik yaziyor ve
      // "23nisan" hic taninmiyordu. Bosluk yazim tercihidir.
      expect(coz('23nisan').ekran, CepteEkran.belirliGunler);
      expect(coz('29ekim').ekran, CepteEkran.belirliGunler);
      expect(coz('19mayis').ekran, CepteEkran.belirliGunler);
    });

    test('Ekran adlari da bitisik yazilabilir', () {
      expect(coz('dersprogramim').ekran, CepteEkran.dersProgrami);
      expect(coz('oturmaplani').ekran, CepteEkran.oturmaPlani);
    });

    test('KRITIK: bosluk toleransi kelime siniri kuralini BOZMAZ', () {
      // "aydin" icinde "din" hala eslesmemeli; bosluk silme kisa
      // kodlara uygulanmaz.
      expect(coz('aydın öğretmenin planı').dersKodu, isNot('DIN'));
      expect(coz('telefon numarası').dersKodu, isNull);
    });
  });

  group('Sosyal kulupler', () {
    test('Kulup adiyla bulunur', () {
      expect(coz('satranç kulübü').ekran, CepteEkran.sosyalKulupler);
      expect(coz('tiyatro kulübü').ekran, CepteEkran.sosyalKulupler);
      expect(coz('çevre kulübü').ekran, CepteEkran.sosyalKulupler);
    });

    test('KRITIK: "kizilay haftasi" ile "kizilay kulubu" ayrilir', () {
      // Ayni kelime iki ayri ekrana ait: hafta belirli gunlerde,
      // kulup EK-4 cizelgesinde. Karistirilirsa ogretmen yanlis
      // belgeye goturulur.
      expect(coz('kızılay haftası').ekran, CepteEkran.belirliGunler);
      expect(coz('kızılay kulübü').ekran, CepteEkran.sosyalKulupler);
    });

    test('KRITIK: cevre ve yesilay da ayrilir', () {
      expect(coz('çevre koruma haftası').ekran, CepteEkran.belirliGunler);
      expect(coz('çevre kulübü').ekran, CepteEkran.sosyalKulupler);
      expect(coz('yeşilay haftası').ekran, CepteEkran.belirliGunler);
      expect(coz('yeşilay kulübü').ekran, CepteEkran.sosyalKulupler);
    });

    test('Sade "kulup" da ekrana goturur', () {
      expect(coz('kulüp işlemleri').ekran, CepteEkran.sosyalKulupler);
      expect(coz('ek-4 çizelgesi').ekran, CepteEkran.sosyalKulupler);
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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/documents/data/special_days_repository.dart';

/// MEB Belirli Gün ve Haftalar çizelgesi.
///
/// ## Neden bu testler var
/// Veri MEB'in resmî PDF'inden ayrıştırılıyor
/// (`tool/build_belirli_gun_dataset.py`). Çizelgede üç ayrı tarih
/// anlatımı var ve üçü farklı ele alınmalı:
///   * "23 Nisan"                -> sabit
///   * "10-16 Kasım"             -> aralık
///   * "Eylül ayının 3. haftası" -> kural (hesaplanamaz)
///
/// En büyük risk, kural tipini hesaplanmış gibi göstermek: öğretmene
/// YANLIŞ TARİH vermek, tarih vermemekten kötüdür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SpecialDaysRepository repo;

  setUpAll(() {
    final bytes =
        File('assets/data/belirli_gun_hafta.json.gz').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      if (ad == 'assets/data/belirli_gun_hafta.json.gz') {
        return Uint8List.fromList(bytes).buffer.asByteData();
      }
      if (ad == 'assets/data/pano_icerikleri.json.gz') {
        return Uint8List.fromList(
                File('assets/data/pano_icerikleri.json.gz').readAsBytesSync())
            .buffer
            .asByteData();
      }
      return null;
    });
  });

  setUp(() {
    SpecialDaysRepository.resetCache();
    repo = SpecialDaysRepository();
  });

  group('Veri paketi', () {
    test('KRITIK: cizelge dolu', () async {
      final hepsi = await repo.all();
      expect(hepsi.length, greaterThanOrEqualTo(50),
          reason: 'MEB cizelgesinde 60 civari madde var');
    });

    test('KRITIK: resmi bayramlar dogru tarihte', () async {
      // Bunlar sabit ve herkesin bildigi tarihler; ayristirma
      // bozulursa ilk burada gorunur.
      final hepsi = await repo.all();
      final beklenen = {
        'Cumhuriyet Bayramı': (10, 29),
        'Ulusal Egemenlik ve Çocuk Bayramı': (4, 23),
        'Öğretmenler Günü': (11, 24),
        'Dünya Kadınlar Günü': (3, 8),
        'Şehitler Günü': (3, 18),
      };
      for (final e in beklenen.entries) {
        final m = hepsi.where((x) => x.ad == e.key).firstOrNull;
        expect(m, isNotNull, reason: '"${e.key}" cizelgede yok');
        expect(m!.ay, e.value.$1, reason: '${e.key} ayi yanlis');
        expect(m.baslangicGun, e.value.$2, reason: '${e.key} gunu yanlis');
      }
    });

    test('KRITIK: hafta araliklari cozulmus', () async {
      final hepsi = await repo.all();
      final ataturk =
          hepsi.where((x) => x.ad == 'Atatürk Haftası').firstOrNull;
      expect(ataturk, isNotNull);
      expect(ataturk!.tur, 'aralik');
      expect(ataturk.ay, 11);
      expect(ataturk.baslangicGun, 10);
      expect(ataturk.bitisGun, 16);
    });

    test('KRITIK: ay atlayan hafta iki ayi da kapsar', () async {
      // "Kızılay Haftası (29 Ekim-4 Kasım)" — tek ay varsayilirsa
      // Kasim gunleri kapsam disi kalir.
      final k = (await repo.all())
          .where((x) => x.ad == 'Kızılay Haftası')
          .firstOrNull;
      expect(k, isNotNull);
      expect(k!.kapsar(DateTime(2026, 10, 30)), isTrue,
          reason: 'Ekim tarafi');
      expect(k.kapsar(DateTime(2026, 11, 3)), isTrue,
          reason: 'Kasim tarafi');
      expect(k.kapsar(DateTime(2026, 11, 8)), isFalse,
          reason: 'hafta bitti');
    });

    test('KRITIK: degisken tarihli maddeler HESAPLANMIS gibi durmuyor',
        () async {
      // "Eylül ayının 3. haftası" takvim yilina gore degisir.
      // Uydurulmus bir tarih vermektense metin gosterilir.
      final hepsi = await repo.all();
      final kural = hepsi.where((x) => x.tur == 'kural').toList();
      expect(kural, isNotEmpty);
      for (final m in kural) {
        expect(m.kesinTarihli, isFalse,
            reason: '"${m.ad}" kesin tarihli sayilmamali');
        expect(m.kapsar(DateTime(2026, 9, 15)), isFalse,
            reason: '"${m.ad}" gune eslesmemeli');
        expect(m.tarihMetni.trim(), isNotEmpty,
            reason: 'tarih metni gosterilecek, bos olamaz');
      }
    });

    test('her maddenin adi ve tarih metni var', () async {
      for (final m in await repo.all()) {
        expect(m.ad.trim(), isNotEmpty);
        expect(m.tarihMetni.trim(), isNotEmpty);
      }
    });

    test('cizelge ogretim yili sirasinda (Eylul once)', () async {
      final hepsi = await repo.all();
      final ilkAy = hepsi.firstWhere((x) => x.ay != null).ay;
      expect(ilkAy, 9, reason: 'ogretim yili Eylul`de baslar');
    });
  });

  group('Gune gore sorgu', () {
    test('KRITIK: 23 Nisan o gune denk gelir', () async {
      final gun = await repo.forDay(DateTime(2027, 4, 23));
      expect(gun.map((e) => e.ad),
          contains('Ulusal Egemenlik ve Çocuk Bayramı'));
    });

    test('sabit gun BIR GUN oncesine denk gelmez', () async {
      final gun = await repo.forDay(DateTime(2027, 4, 22));
      expect(gun.map((e) => e.ad),
          isNot(contains('Ulusal Egemenlik ve Çocuk Bayramı')));
    });

    test('hafta araliginin ORTASI da kapsanir', () async {
      final gun = await repo.forDay(DateTime(2026, 11, 13));
      expect(gun.map((e) => e.ad), contains('Atatürk Haftası'));
    });
  });

  group('Yaklasanlar', () {
    test('KRITIK: ayni hafta listede TEK kez cikar', () async {
      // Hafta yedi gune yayilir; her gunu ayri kayit sayilirsa liste
      // ayni adla dolar.
      final y = await repo.upcoming(
        bugun: DateTime(2026, 11, 9),
        gunSayisi: 20,
      );
      final adlar = y.map((e) => e.madde.ad).toList();
      expect(adlar.length, adlar.toSet().length,
          reason: 'tekrar eden madde var: $adlar');
    });

    test('KRITIK: yaklasanlar yalnizca KESIN tarihli maddeler', () async {
      final y = await repo.upcoming(
        bugun: DateTime(2026, 9, 1),
        gunSayisi: 60,
      );
      for (final e in y) {
        expect(e.madde.kesinTarihli, isTrue,
            reason: '"${e.madde.ad}" tarihi hesaplanamaz, listede olmamali');
      }
    });

    test('bos donem bos liste dondurur', () async {
      // Temmuz ortasi: okul tatili, cizelgede madde yok.
      final y = await repo.upcoming(
        bugun: DateTime(2027, 7, 10),
        gunSayisi: 5,
      );
      expect(y, isEmpty);
    });
  });

  /// Pano/toren calismasi yapilan gunler.
  ///
  /// ## Neden ayri liste
  /// Cizelgedeki 61 maddenin hepsi icin pano hazirlanmaz; "Dunya
  /// Fikri Mulkiyet Gunu" anilir ama sinif calisma yapmaz. Ogretmenin
  /// fiilen hazirlik yaptigi gunler isaretlidir.
  group('Pano calismalari', () {
    test('KRITIK: milli bayramlarin hepsi etkinlikli', () async {
      final e = (await repo.withActivities()).map((x) => x.ad).toSet();
      const olmasiGereken = [
        'Cumhuriyet Bayramı',
        'Ulusal Egemenlik ve Çocuk Bayramı',
        "Atatürk'ü Anma ve Gençlik ve Spor Bayramı",
        'Zafer Bayramı',
        'Şehitler Günü',
        '15 Temmuz Demokrasi ve Millî Birlik Günü',
        "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü",
      ];
      for (final ad in olmasiGereken) {
        expect(e, contains(ad), reason: '"$ad" pano listesinde yok');
      }
    });

    test('KRITIK: pano listesi cizelgenin TAMAMI degil', () async {
      // Hepsi isaretlenirse ayri sekmenin anlami kalmaz.
      final hepsi = await repo.all();
      final e = await repo.withActivities();
      expect(e.length, lessThan(hepsi.length),
          reason: 'secim yapilmamis');
      expect(e.length, greaterThan(15),
          reason: 'onemli gunler eksik kalmis');
    });

    test('etkinlik gerektirmeyen gunler listede YOK', () async {
      final e = (await repo.withActivities()).map((x) => x.ad).toSet();
      // Bunlar cizelgede var ama sinif pano hazirlamaz.
      for (final ad in [
        '26 Nisan Dünya Fikrî Mülkiyet Günü',
        'Kişisel Verileri Koruma Günü',
        'Vergi Haftası',
      ]) {
        expect(e, isNot(contains(ad)),
            reason: '"$ad" pano listesine girmemeli');
      }
    });

    test('KRITIK: 15 Temmuz cizelgede var', () async {
      // Kaynak PDF'te PARANTEZSIZ ve yildizli geciyor; parantez
      // arayan ayristiriciya takilmiyordu.
      final hepsi = await repo.all();
      final t = hepsi
          .where((x) => x.ad.contains('15 Temmuz'))
          .firstOrNull;
      expect(t, isNotNull, reason: '15 Temmuz eksik');
      expect(t!.etkinlikli, isTrue);
    });
  });

  /// Pano ve etkinlik icerikleri.
  ///
  /// ## En buyuk risk: ad uyusmazligi
  /// Icerik `ad` alaniyla cizelgeye baglaniyor. Tek harf farki
  /// (apostrof, buyuk-kucuk) baglantiyi sessizce kopariyor: ogretmen
  /// karta basiyor, "icerik yok" goruyor ve icerik yazilmis olmasina
  /// ragmen ulasamiyor.
  group('Pano icerikleri', () {
    late PanoContentRepository pano;

    setUp(() {
      PanoContentRepository.resetCache();
      pano = PanoContentRepository();
    });

    test('KRITIK: her icerigin adi CIZELGEDE var', () async {
      final cizelge = (await repo.all()).map((e) => e.ad).toSet();
      final icerikler = await pano.availableDays();
      for (final ad in icerikler) {
        expect(cizelge, contains(ad),
            reason: '"$ad" cizelgede yok; karta baglanamaz');
      }
    });

    test('KRITIK: icerikli gunler ETKINLIKLI olarak isaretli', () async {
      // Icerik pano sekmesinde gosteriliyor; gun etkinlikli degilse
      // o sekmede hic gorunmez.
      final etkinlikli = (await repo.withActivities()).map((e) => e.ad).toSet();
      for (final ad in await pano.availableDays()) {
        expect(etkinlikli, contains(ad),
            reason: '"$ad" pano sekmesinde gorunmez');
      }
    });

    test('KRITIK: milli bayramlarin icerigi var', () async {
      final v = await pano.availableDays();
      for (final ad in [
        'Ulusal Egemenlik ve Çocuk Bayramı',
        'Cumhuriyet Bayramı',
        'Atatürk Haftası',
        "Atatürk'ü Anma ve Gençlik ve Spor Bayramı",
        'Şehitler Günü',
        '15 Temmuz Demokrasi ve Millî Birlik Günü',
      ]) {
        expect(v, contains(ad), reason: '"$ad" icerigi eksik');
      }
    });

    test('KRITIK: 15 Temmuz toren taslagi var', () async {
      final i = await pano.forDay('15 Temmuz Demokrasi ve Millî Birlik Günü');
      expect(i, isNotNull);
      expect(i!.torenVar, isTrue);
      expect(i.program, isNotEmpty);
      expect(i.mudurKonusmasi.trim().length, greaterThan(250));
      expect(i.konusmalar, isNotEmpty);
      expect(i.konusmalar.first.metin.trim().length, greaterThan(200));
      expect(i.siirler, isNotEmpty);
      expect(i.panoKartlar.length, greaterThanOrEqualTo(4));
      expect(i.etkinlikler.length, greaterThanOrEqualTo(3));
    });

    test('KRITIK: Ilkogretim Haftasi toren taslagi var', () async {
      final i = await pano.forDay('İlköğretim Haftası');
      expect(i, isNotNull);
      expect(i!.torenVar, isTrue);
      expect(i.program, isNotEmpty);
      expect(i.mudurKonusmasi.trim().length, greaterThan(250));
      expect(i.konusmalar, isNotEmpty);
      expect(i.konusmalar.first.metin.trim().length, greaterThan(200));
      expect(i.siirler, isNotEmpty);
      expect(i.panoKartlar.length, greaterThanOrEqualTo(4));
      expect(i.etkinlikler.length, greaterThanOrEqualTo(3));
      expect(i.sloganlar.length, greaterThanOrEqualTo(4));
    });

    test('KRITIK: Ataturk Haftasi toren taslagi var', () async {
      final i = await pano.forDay('Atatürk Haftası');
      expect(i, isNotNull);
      expect(i!.torenVar, isTrue);
      expect(i.program, isNotEmpty);
      expect(i.mudurKonusmasi.trim().length, greaterThan(250));
      expect(i.konusmalar, isNotEmpty);
      expect(i.konusmalar.first.metin.trim().length, greaterThan(200));
      expect(i.siirler, isNotEmpty);
      expect(i.panoKartlar.length, greaterThanOrEqualTo(4));
    });

    test('iceriksiz gunler pano listesinde yok', () async {
      // Pano sekmesi yalnizca icerigi hazir gunleri gosterir.
      final e = (await repo.withActivities()).map((x) => x.ad).toSet();
      for (final ad in [
        'Anneler Günü',
        'Babalar Günü',
        'Kütüphaneler Haftası',
        'İnsan Hakları ve Demokrasi Haftası',
        'Müzeler Haftası',
        'Yaşlılar Haftası',
        'Dünya Otizm Farkındalık Günü',
        'Ağız ve Diş Sağlığı Haftası',
        'Sivil Savunma Günü',
      ]) {
        expect(e, isNot(contains(ad)),
            reason: '"$ad" iceriksizken pano listesinde');
      }
    });

    test('KRITIK: her icerikte ozet ve en az bir etkinlik var', () async {
      for (final ad in await pano.availableDays()) {
        final i = await pano.forDay(ad);
        expect(i, isNotNull);
        expect(i!.ozet.trim().length, greaterThan(40),
            reason: '"$ad" ozeti cok kisa');
        expect(i.etkinlikler, isNotEmpty,
            reason: '"$ad" etkinliksiz');
        for (final e in i.etkinlikler) {
          expect(e.ad.trim(), isNotEmpty);
          expect(e.adimlar, isNotEmpty,
              reason: '"${e.ad}" adimsiz');
        }
      }
    });

    test('KRITIK: kaynak ayrimi acik', () async {
      // Uydurulmus icerigi "MEB kaynakli" gostermek, ogretmeni resmi
      // evrakta yanlis bilgiye surukler.
      for (final ad in await pano.availableDays()) {
        final i = await pano.forDay(ad);
        expect(['meb', 'genel'], contains(i!.kaynak),
            reason: '"$ad" kaynagi tanimsiz: ${i.kaynak}');
      }
    });

    test('23 Nisan icerigi MEB rehberinden', () async {
      final i = await pano.forDay('Ulusal Egemenlik ve Çocuk Bayramı');
      expect(i!.mebKaynakli, isTrue);
      expect(i.etkinlikler.length, greaterThanOrEqualTo(3));
    });

    test('KRITIK: 23 Nisan pano paketi vecize ve dilek karti tasir', () async {
      final i = await pano.forDay('Ulusal Egemenlik ve Çocuk Bayramı');
      expect(i!.zenginPano, isTrue);
      expect(i.vecize.trim().length, greaterThan(40));
      expect(i.panoParagraflar.length, 3);
      expect(i.kronoloji.length, greaterThanOrEqualTo(3));
      expect(i.ogrenciGoreviBaslik, contains('Dileğim'));
      expect(i.panoDortlukler.length, 4);
      expect(i.biliyorMuydunuz.length, 3);
    });

    test('KRITIK: 23 Nisan toreninde oyun ve birden cok siir var', () async {
      final i = await pano.forDay('Ulusal Egemenlik ve Çocuk Bayramı');
      expect(i!.siirler.length, greaterThanOrEqualTo(3));
      expect(i.oyunlar.length, greaterThanOrEqualTo(4));
      final program = i.program.join(' ').toLowerCase();
      expect(program, contains('sandalye'));
      expect(program, contains('çuval'));
      expect(program, contains('yumurta'));
      expect(program, contains('müzik'));
    });

    test('KRITIK: milli gunlerde toren taslagi var', () async {
      final i = await pano.forDay('Ulusal Egemenlik ve Çocuk Bayramı');
      expect(i!.torenVar, isTrue);
      expect(i.program, isNotEmpty);
      expect(i.mudurKonusmasi.trim().length, greaterThan(250));
      expect(i.konusmalar.single.metin.trim().length, greaterThan(200));
      expect(i.panoKartlar.length, greaterThanOrEqualTo(4));
    });

    test('icerigi olmayan gun null doner', () async {
      final i = await pano.forDay('Vergi Haftası');
      expect(i, isNull);
    });
  });
}

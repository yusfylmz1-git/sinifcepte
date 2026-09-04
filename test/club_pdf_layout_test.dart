import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/clubs/data/models/club_model.dart';
import 'package:sinifcepte/features/clubs/utils/club_activity_suggester.dart';
import 'package:sinifcepte/features/clubs/utils/club_bundle_exporter.dart';
import 'package:sinifcepte/features/clubs/utils/club_pdf_generator.dart';

/// 52 kulubun UC belgesi de gercekten uretilip taraniyor.
///
/// ## Neden bu test var
/// Cihazda goruldu: uzun planlarda imza blogu ve OLUR ikinci sayfaya
/// kayiyordu — tablo birinci sayfayi doldurunca imza tek basina bos
/// sayfada kaliyor. Resmi evrakta bu kabul edilemez; mudur imzalayacagi
/// sayfada belgeyi de gormeli.
///
/// Pano isinde ayni yontem kullanildi (220 PDF tarandi). Goz denetimi
/// 52 kulup x 3 belge = 156 PDF icin gercekci degil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Varlik okuyucusu: PdfTrFonts gomulu fontlari buradan alir.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final ad = utf8.decode(message!.buffer.asUint8List());
      final f = File(ad);
      if (f.existsSync()) {
        return Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData();
      }
      return null;
    });
  });

  const profil = TeacherProfileModel(
    id: 't1',
    firstName: 'Ayşe',
    lastName: 'Yılmaz',
    branch: 'Sınıf Öğretmenliği',
    schoolName: 'Şehit Öğretmen Ortaokulu',
    schoolPrincipalName: 'Mehmet Demir',
    email: 'ogretmen@example.com',
  );

  /// Paketteki kuluplerin plan satirlarini okur.
  List<({String ad, String kod, String tema, List<ClubPlanRow> plan})>
      kulupleriOku() {
    final bayt = File('assets/data/kulup_planlari.json.gz').readAsBytesSync();
    final j = jsonDecode(utf8.decode(gzip.decode(bayt)))
        as Map<String, dynamic>;
    return [
      for (final k in (j['kulupler'] as List).cast<Map<String, dynamic>>())
        (
          ad: k['ad'] as String,
          kod: k['kod'] as String,
          tema: k['tema'] as String,
          plan: [
            for (final p in (k['plan'] as List).cast<Map<String, dynamic>>())
              ClubPlanRow(
                ay: p['ay'] as String,
                amac: p['amac'] as String,
                etkinlik: p['etkinlik'] as String,
              ),
          ],
        ),
    ];
  }

  ClubModel kulupModeli(String ad, String kod, String tema) => ClubModel(
        id: 1,
        catalogCode: kod,
        ad: ad,
        tema: tema,
        ogretimYili: '2025-2026',
        olusturmaTarihi: DateTime(2025, 9, 15),
      );

  /// PDF metnini aranabilir hale getirir.
  ///
  /// Syncfusion her kelimeyi AYRI SATIRA koyuyor: tablo basligi
  /// metinde "ADI", "VE", "SOYADI" olarak ayri ayri duruyor.
  /// Satir sonlari bosluga cevrilmezse cok kelimeli hicbir ifade
  /// bulunamaz — testin kendisi yanlis alarm verir.
  String duz(String ham) => ham.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Son sayfada tablodan bagimsiz, YALNIZ imza blogu mu var?
  ///
  /// Imza metinleri var ama ay adi yoksa, o sayfaya tablo hic
  /// ulasmamis demektir — imza tek basina kalmis.
  bool imzaYalnizKalmis(List<int> bayt) {
    final doc = PdfDocument(inputBytes: bayt);
    try {
      if (doc.pages.count < 2) return false;
      final sonSayfa = duz(PdfTextExtractor(doc).extractText(
        startPageIndex: doc.pages.count - 1,
      ));
      final imzaVar = sonSayfa.contains('Danışman Öğretmen');
      if (!imzaVar) return false;

      // Tablo icerigi var mi? Ay adlarindan biri geciyorsa var.
      const aylar = [
        'Eylül', 'Ekim', 'Kasım', 'Aralık', 'Ocak',
        'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      ];
      return !aylar.any(sonSayfa.contains);
    } finally {
      doc.dispose();
    }
  }

  group('Yillik plan PDF yerlesimi', () {
    test('KRITIK: imza blogu bos sayfaya kaymiyor', () async {
      final bozuk = <String>[];

      for (final k in kulupleriOku()) {
        final bayt = await ClubPdfGenerator.yillikPlanBytes(
          kulup: kulupModeli(k.ad, k.kod, k.tema),
          plan: k.plan,
          teacherProfile: profil,
        );
        if (imzaYalnizKalmis(bayt)) bozuk.add(k.ad);
      }

      expect(bozuk, isEmpty,
          reason: 'imza blogu tablodan kopup bos sayfaya dustu: '
              '${bozuk.join(", ")}');
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('KRITIK: her kulubun plani uretiliyor ve on ay basiliyor', () async {
      // Ornekleme: hepsini uretmek yavas, ilk uc + en uzun adli kulup.
      final hepsi = kulupleriOku();
      final ornek = [
        ...hepsi.take(3),
        hepsi.reduce((a, b) => a.ad.length >= b.ad.length ? a : b),
      ];

      for (final k in ornek) {
        final bayt = await ClubPdfGenerator.yillikPlanBytes(
          kulup: kulupModeli(k.ad, k.kod, k.tema),
          plan: k.plan,
          teacherProfile: profil,
        );
        final doc = PdfDocument(inputBytes: bayt);
        final metin = duz(PdfTextExtractor(doc).extractText());
        doc.dispose();

        for (final ay in ['Eylül', 'Ocak', 'Haziran']) {
          expect(metin.contains(ay), isTrue,
              reason: '${k.ad}: $ay ayi PDF de yok');
        }
        expect(metin.contains('Danışman Öğretmen'), isTrue,
            reason: '${k.ad}: imza blogu yok');
        expect(metin.contains('OLUR'), isTrue,
            reason: '${k.ad}: mudur OLUR blogu yok');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Faaliyet raporu PDF yerlesimi', () {
    test('KRITIK: imza blogu bos sayfaya kaymiyor', () async {
      final bozuk = <String>[];

      for (final k in kulupleriOku()) {
        // Kurulumda tohumlanan hal: her ay plandan uretilmis taslak.
        final faaliyetler = [
          for (final p in k.plan)
            ClubActivityLog(
              clubId: 1,
              ay: p.ay,
              yapilanCalisma: ClubActivitySuggester.oner(p),
              katilanSayisi: 18,
            ),
        ];

        final bayt = await ClubPdfGenerator.faaliyetRaporuBytes(
          kulup: kulupModeli(k.ad, k.kod, k.tema),
          plan: k.plan,
          faaliyetler: faaliyetler,
          uyeSayisi: 18,
          teacherProfile: profil,
        );
        if (imzaYalnizKalmis(bayt)) bozuk.add(k.ad);
      }

      expect(bozuk, isEmpty,
          reason: 'imza blogu tablodan kopup bos sayfaya dustu: '
              '${bozuk.join(", ")}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('Birlesik belge', () {
    test('KRITIK: uc belge tek PDF de birlesiyor', () async {
      final k = kulupleriOku().first;
      final faaliyetler = [
        for (final p in k.plan)
          ClubActivityLog(
            clubId: 1,
            ay: p.ay,
            yapilanCalisma: ClubActivitySuggester.oner(p),
          ),
      ];

      final bayt = await ClubBundleExporter.birlesikBytes(
        kulup: kulupModeli(k.ad, k.kod, k.tema),
        plan: k.plan,
        uyeler: const [],
        faaliyetler: faaliyetler,
        teacherProfile: profil,
      );

      final doc = PdfDocument(inputBytes: bayt);
      final metin = duz(PdfTextExtractor(doc).extractText());
      final sayfa = doc.pages.count;
      doc.dispose();

      // Uc belgenin de basligi bulunmali.
      expect(metin.contains('YILLIK ÇALIŞMA PLANI'), isTrue,
          reason: 'birlesik belgede yillik plan yok');
      expect(metin.contains('ÜYE LİSTESİ'), isTrue,
          reason: 'birlesik belgede uye listesi yok');
      expect(metin.contains('FAALİYET RAPORU'), isTrue,
          reason: 'birlesik belgede faaliyet raporu yok');

      // Her belge ayri sayfada baslamali: en az uc sayfa.
      expect(sayfa, greaterThanOrEqualTo(3),
          reason: 'belgeler ayri sayfada baslamiyor ($sayfa sayfa)');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Uye listesi PDF', () {
    test('KRITIK: uye yokken elle doldurulacak sablon basiliyor', () async {
      final bayt = await ClubPdfGenerator.uyeListesiBytes(
        kulup: kulupModeli('Satranç Kulübü', 'satranc', 'spor'),
        uyeler: const [],
        teacherProfile: profil,
      );
      final doc = PdfDocument(inputBytes: bayt);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();

      expect(metin.contains('ADI VE SOYADI'), isTrue,
          reason: 'bos listede tablo basligi yok');
      expect(metin.contains('üye eklenmemiş'), isFalse,
          reason: 'kullanilamaz uyari metni hala basiliyor');
      // Sira numaralari basili gelmeli ki ogretmen elle doldursun.
      expect(metin.contains('25'), isTrue,
          reason: 'bos sablonda sira numaralari yok');
    });

    test('uye varken liste ve toplam basiliyor', () async {
      final bayt = await ClubPdfGenerator.uyeListesiBytes(
        kulup: kulupModeli('Satranç Kulübü', 'satranc', 'spor'),
        uyeler: const [
          ClubMember(
            clubId: 1,
            adSoyad: 'Zeynep Kaya',
            okulNo: 142,
            sinifAdi: '6-B',
            gorev: 'Kulüp Temsilcisi',
          ),
          ClubMember(
            clubId: 1,
            adSoyad: 'Ali Vural',
            okulNo: 88,
            sinifAdi: '7-A',
          ),
        ],
        teacherProfile: profil,
      );
      final doc = PdfDocument(inputBytes: bayt);
      final metin = duz(PdfTextExtractor(doc).extractText());
      doc.dispose();

      expect(metin.contains('ZEYNEP KAYA'), isTrue);
      expect(metin.contains('Kulüp Temsilcisi'), isTrue);
      expect(metin.contains('Toplam üye sayısı: 2'), isTrue);
    });
  });
}

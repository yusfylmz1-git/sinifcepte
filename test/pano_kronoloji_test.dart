import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/features/documents/data/special_days_repository.dart';
import 'package:sinifcepte/features/documents/utils/special_day_pdf_generator.dart';

/// Derinleştirilen resmî gün içeriklerinin PDF'e sığması.
///
/// ## Neden bu test var
/// Cihazda görüldü: 15 Temmuz panosunda tarih şeridi beş satırdı ve
/// o gecenin kendisini anlatmıyordu (köprü, TBMM, salalar hiç yoktu).
/// Kronoloji altı satıra, bilgi kartları güne özgü olgulara çıkarıldı.
///
/// İçerik uzayınca kartlar sayfaya sığmayabilir. Kulüp PDF'inde imza
/// bloğunun boş sayfaya kaymasıyla aynı risk — orada ölçerek
/// yakalanmıştı, burada da ölçülüyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
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

  /// PDF metnini aranabilir hâle getirir.
  ///
  /// Syncfusion her kelimeyi ayrı satıra koyuyor; satır sonları
  /// boşluğa çevrilmezse çok kelimeli hiçbir ifade bulunamaz.
  String duz(String ham) => ham.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> panoMetni(String gunAdi) async {
    SpecialDaysRepository.resetCache();
    PanoContentRepository.resetCache();

    final gun =
        (await SpecialDaysRepository().all()).firstWhere((e) => e.ad == gunAdi);
    final icerik = await PanoContentRepository().forDay(gunAdi);

    final bayt = await SpecialDayPdfGenerator.panoCalismasi(
      gun: gun,
      icerik: icerik,
      schoolName: 'Şehit Öğretmen Ortaokulu',
      className: '6-B',
      teacherName: 'Ayşe DEMİR',
      academicYear: '2026-2027',
    );

    final doc = PdfDocument(inputBytes: bayt);
    final metin = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return metin;
  }

  group('Derinlestirilen kronolojiler PDF de', () {
    test('KRITIK: 15 Temmuz o gecenin olaylarini tasiyor', () async {
      final metin = await panoMetni('15 Temmuz Demokrasi ve Millî Birlik Günü');

      // Önceki hâlde bunların hiçbiri yoktu; kronoloji genel demokrasi
      // tarihiydi (1946 seçimi, TBMM'nin açılışı).
      expect(metin.contains('Meclis'), isTrue,
          reason: 'TBMM olayı panoda yok');
      expect(metin.contains('sala') || metin.contains('Sala'), isTrue,
          reason: 'salalar panoda yok');
      expect(metin.contains('yirmi bir saat'), isTrue,
          reason: 'girişimin süresi panoda yok');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: dogrulanmamis sehit sayisi YAZILMIYOR', () async {
      // Kaynaklarda 251, 253 ve "300'e yakın" geçiyor; tek bir resmî
      // rakam teyit edilemedi. İçerik kuralı: emin değilsen yazma.
      final metin = await panoMetni('15 Temmuz Demokrasi ve Millî Birlik Günü');

      expect(metin.contains('251'), isFalse,
          reason: 'doğrulanmamış rakam resmî evrakta');
      expect(metin.contains('253'), isFalse,
          reason: 'doğrulanmamış rakam resmî evrakta');
      expect(metin.contains('iki yüzü aşkın'), isTrue,
          reason: 'kayıp hiç anılmamış');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: Sehitler Gunu zaferin NASIL kazanildigini anlatiyor',
        () async {
      final metin = await panoMetni('Şehitler Günü');

      // Önceki hâli "Çanakkale Deniz Zaferi kazanıldı" demekle
      // yetiniyordu.
      expect(metin.contains('Nusret'), isTrue,
          reason: 'mayın gemisi panoda yok');
      expect(metin.contains('yirmi altı'), isTrue,
          reason: 'mayın sayısı panoda yok');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: 23 Nisan Meclisin acilisini baglama oturtuyor', () async {
      final metin = await panoMetni('Ulusal Egemenlik ve Çocuk Bayramı');

      // Önceki kronolojide üç satırdan ikisi tarih bile taşımıyordu.
      expect(metin.contains('işgal'), isTrue,
          reason: 'Meclis neden Ankara’da açıldı anlatılmıyor');
      expect(metin.contains('1929'), isTrue,
          reason: 'çocuk bayramı olma tarihi yok');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Sayfa yerlesimi', () {
    test('KRITIK: uzayan kronoloji metni kesmiyor', () async {
      // Kartlar sayfalanıyor (sayfada 5); altıncı satır ikinci sayfaya
      // düşmeli, kaybolmamalı.
      final metin = await panoMetni('Şehitler Günü');

      // Kronolojinin ilk ve SON satırı da basılmış olmalı.
      expect(metin.contains('Şubat 1915'), isTrue,
          reason: 'kronolojinin ilk satırı yok');
      expect(metin.contains('Şehitleri Anma Günü'), isTrue,
          reason: 'kronolojinin son satırı kesilmiş');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

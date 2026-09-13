import 'dart:typed_data';

import '../../../core/utils/turkish_text.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../../documents/utils/plan_week_builder.dart';
import 'cepte_niyet.dart';

/// Belge hazırlama denemesinin sonucu.
///
/// Üç durum vardır ve üçü de öğretmene farklı şey söyler:
/// hazır belge, sorulacak bir soru, ya da yapılamama gerekçesi.
class CepteBelgeSonucu {
  const CepteBelgeSonucu._({
    required this.durum,
    this.planlar = const [],
    this.dersAdi,
    this.dersKodu,
    this.publisher,
    this.sinif,
    this.mesaj,
    this.secenekler = const [],
  });

  factory CepteBelgeSonucu.hazir({
    required List<Map<String, dynamic>> planlar,
    required String dersAdi,
    required String dersKodu,
    required String publisher,
    required int sinif,
  }) =>
      CepteBelgeSonucu._(
        durum: CepteBelgeDurumu.hazir,
        planlar: planlar,
        dersAdi: dersAdi,
        dersKodu: dersKodu,
        publisher: publisher,
        sinif: sinif,
      );

  factory CepteBelgeSonucu.secimGerekli({
    required String mesaj,
    required List<String> secenekler,
  }) =>
      CepteBelgeSonucu._(
        durum: CepteBelgeDurumu.secimGerekli,
        mesaj: mesaj,
        secenekler: secenekler,
      );

  factory CepteBelgeSonucu.yapilamaz(String mesaj) =>
      CepteBelgeSonucu._(durum: CepteBelgeDurumu.yapilamaz, mesaj: mesaj);

  final CepteBelgeDurumu durum;
  final List<Map<String, dynamic>> planlar;
  final String? dersAdi;
  final String? dersKodu;
  final String? publisher;
  final int? sinif;
  final String? mesaj;
  final List<String> secenekler;

  bool get basarili => durum == CepteBelgeDurumu.hazir;
}

enum CepteBelgeDurumu { hazir, secimGerekli, yapilamaz }

/// Sohbetten belge üretir — EKRAN AÇMADAN.
///
/// ## Neden ayrı katman
/// Plan haritasını kuran mantık daha önce ekran durumuna bağlıydı
/// (`_seciliSinif`, `_seciliDersKodu`); `PlanWeekBuilder` ile koparıldı.
/// Bu servis o koparmanın karşılığı: niyeti alıp veriyi toplar ve PDF
/// üreticisine verilecek plan listesini kurar.
///
/// Veritabanı çağrıları DIŞARIDAN verilir. Böylece test sahte veriyle
/// çalışır, `sqflite` kurmaya gerek kalmaz; aynı kalıp
/// `PlanWeekBuilder.takvimdenTarih` içinde de kullanılıyor.
class CepteBelgeServisi {
  const CepteBelgeServisi({
    required this.dersleriGetir,
    required this.kazanimlariGetir,
    required this.takvimdenTarih,
  });

  /// `(sinif) -> ders satirlari` (subject_code, subject_name, publisher)
  final Future<List<Map<String, dynamic>>> Function(int sinif) dersleriGetir;

  /// `(sinif, dersKodu, publisher) -> kazanim satirlari`
  final Future<List<Map<String, dynamic>>> Function({
    required int gradeLevel,
    required String subjectCode,
    required String publisher,
  }) kazanimlariGetir;

  final String Function(int hafta) takvimdenTarih;

  /// Niyetten plan listesi kurar.
  ///
  /// [ayrintili] günlük plan içindir (öğretme-öğrenme süreci dolu gelir).
  Future<CepteBelgeSonucu> planHazirla(
    CepteNiyet niyet, {
    required bool ayrintili,
  }) async {
    final sinif = niyet.sinif;
    final kod = niyet.dersKodu;

    // EKSİK BİLGİYLE ÜRETİM YOK.
    //
    // Çözümleyici zaten eksikleri işaretliyor; burada da kontrol
    // edilir çünkü servis doğrudan da çağrılabilir. Yanlış belge
    // basmaktansa soru sormak iyidir: bu çıktı teftişe gidiyor.
    if (sinif == null || kod == null) {
      final eksik = <String>[];
      if (sinif == null) eksik.add('hangi sınıf');
      if (kod == null) eksik.add('hangi ders');
      return CepteBelgeSonucu.secimGerekli(
        mesaj: 'Belgeyi hazırlayabilmem için ${eksik.join(' ve ')} '
            'bilgisine ihtiyacım var.',
        secenekler: const [],
      );
    }

    final dersler = await dersleriGetir(sinif);
    final eslesenler = dersler
        .where((d) => trFold('${d['subject_code']}') == trFold(kod))
        .toList();

    if (eslesenler.isEmpty) {
      return CepteBelgeSonucu.yapilamaz(
        '$sinif. sınıfta bu ders müfredat paketinde bulunmuyor.',
      );
    }

    // LİSEDE AYNI DERS ÜÇ OKUL TÜRÜYLE GELİR.
    //
    // Anadolu / Fen / Sosyal Bilimler Lisesi planları farklıdır ve
    // hangisinin isteneceğini Cepte BİLEMEZ. Tahmin etmek yanlış
    // evrak basmak demek; öğretmene sorulur.
    if (eslesenler.length > 1) {
      final secenekler = eslesenler
          .map((d) => '${d['publisher']}'.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (secenekler.length > 1) {
        return CepteBelgeSonucu.secimGerekli(
          mesaj: 'Bu ders için birden fazla plan var. Hangisini '
              'hazırlayayım?',
          secenekler: secenekler,
        );
      }
    }

    final ders = eslesenler.first;
    final dersAdi = '${ders['subject_name'] ?? ''}'.trim();
    final publisher = '${ders['publisher'] ?? ''}'.trim();

    final satirlar = await kazanimlariGetir(
      gradeLevel: sinif,
      subjectCode: '${ders['subject_code']}',
      publisher: publisher,
    );

    final dersHaftalari = PlanWeekBuilder.dersHaftalari(satirlar);
    if (!PlanWeekBuilder.planUretilebilir(dersHaftalari)) {
      return CepteBelgeSonucu.yapilamaz(
        PlanWeekBuilder.planYokGerekcesi(
          dersAdi.isEmpty ? kod : dersAdi,
          sinif,
        ),
      );
    }

    final planlar = <Map<String, dynamic>>[];
    for (final satir in dersHaftalari) {
      planlar.add(PlanWeekBuilder.haftaPlani(
        satir: satir,
        haftaNo: PlanWeekBuilder.dersHaftaNo(satir),
        sinif: sinif,
        dersKodu: '${ders['subject_code']}',
        dersAdi: dersAdi.isEmpty ? null : dersAdi,
        takvimdenTarih: takvimdenTarih,
        ayrintili: ayrintili,
      ));
    }

    // Son ders haftası 35 ise yıl sonu değerlendirme haftası eklenir.
    final sonHafta = PlanWeekBuilder.dersHaftaNo(dersHaftalari.last);
    if (sonHafta == 35) {
      planlar.add(PlanWeekBuilder.yilSonuHaftasi(
        haftaNo: 36,
        sinif: sinif,
        dersKodu: '${ders['subject_code']}',
        dersAdi: dersAdi.isEmpty ? kod : dersAdi,
        takvimdenTarih: takvimdenTarih,
        ayrintili: ayrintili,
      ));
    }

    return CepteBelgeSonucu.hazir(
      planlar: planlar,
      dersAdi: dersAdi.isEmpty ? kod : dersAdi,
      dersKodu: '${ders['subject_code']}',
      publisher: publisher,
      sinif: sinif,
    );
  }
}

/// PDF üreticisine verilecek çağrı bilgisi.
///
/// Servis baytları kendisi üretmez: PDF üretimi ekran tarafında
/// `PdfPreviewScreen` üzerinden yapılır (o ekranın 45 sn zaman aşımı,
/// görünür hata ekranı ve tanı logu var — doğrudan `sharePdf` çağrısı
/// bunların hiçbirini kullanmıyordu ve sessiz donmaya yol açmıştı).
typedef CepteBelgeUretici = Future<Uint8List> Function({
  required List<Map<String, dynamic>> planlar,
  required TeacherProfileModel teacher,
  required String ders,
  required String sinif,
});

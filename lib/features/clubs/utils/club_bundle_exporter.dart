import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' show BuildContext;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../shared/screens/pdf_preview_screen.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../data/models/club_model.dart';
import 'club_pdf_generator.dart';

/// Kulübün üç belgesini tek işlemde verir.
///
/// ## Neden gerekli
/// Üç evrak birlikte isteniyor — kulüp dosyasına hepsi konuyor. Öğretmen
/// üç ayrı önizleme açıp üç kez paylaşmak zorunda kalmamalı.
///
/// İki yol sunuluyor çünkü okullar farklı istiyor:
/// * **Tek PDF** — yazdırıp dosyaya koymak, tek seferde imzalatmak için
/// * **Üç ayrı dosya** — idareye ayrı ayrı teslim, arşivde ayrı durması
class ClubBundleExporter {
  ClubBundleExporter._();

  /// Üç belgeyi tek PDF'te birleştirir.
  ///
  /// ## Neden yeniden üretiliyor
  /// Hazır PDF'leri birleştirmek için sayfa kopyalama gerekir; `pdf`
  /// paketi bunu desteklemiyor. Bunun yerine aynı belge üreticileri
  /// tek `pw.Document` üzerinde arka arkaya çağrılıyor — her belge
  /// kendi künyesi, sayfalaması ve imza bloğuyla ayrı sayfada başlıyor.
  static Future<Uint8List> birlesikBytes({
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubMember> uyeler,
    required List<ClubActivityLog> faaliyetler,
    required TeacherProfileModel teacherProfile,
  }) async {
    final pdf = await PdfTrFonts.document();

    ClubPdfGenerator.yillikPlanSayfasi(
      pdf: pdf,
      kulup: kulup,
      plan: plan,
      teacherProfile: teacherProfile,
    );
    ClubPdfGenerator.uyeListesiSayfasi(
      pdf: pdf,
      kulup: kulup,
      uyeler: uyeler,
      teacherProfile: teacherProfile,
    );
    ClubPdfGenerator.faaliyetRaporuSayfasi(
      pdf: pdf,
      kulup: kulup,
      plan: plan,
      faaliyetler: faaliyetler,
      uyeSayisi: uyeler.length,
      teacherProfile: teacherProfile,
    );

    return PdfTrFonts.kaydet(pdf);
  }

  /// Birleşik belgeyi önizlemede açar.
  static Future<void> birlesikAc(
    BuildContext context, {
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubMember> uyeler,
    required List<ClubActivityLog> faaliyetler,
    required TeacherProfileModel teacherProfile,
  }) =>
      PdfPreviewScreen.open(
        context,
        title: 'Kulüp Belgeleri',
        subtitle: '${kulup.ad} · 3 belge',
        fileName: 'Kulup_Belgeleri_${_dosyaAdi(kulup.ad)}.pdf',
        documentBuilder: (format) => birlesikBytes(
          kulup: kulup,
          plan: plan,
          uyeler: uyeler,
          faaliyetler: faaliyetler,
          teacherProfile: teacherProfile,
        ),
      );

  /// Üç belgeyi ayrı dosya olarak paylaşır.
  ///
  /// Dosyalar geçici dizine yazılır; işletim sistemi paylaşımdan sonra
  /// temizler. Kalıcı kayıt gerekmiyor — öğretmen paylaştığı yerde
  /// saklıyor.
  static Future<void> ucDosyaPaylas({
    required ClubModel kulup,
    required List<ClubPlanRow> plan,
    required List<ClubMember> uyeler,
    required List<ClubActivityLog> faaliyetler,
    required TeacherProfileModel teacherProfile,
  }) async {
    final ad = _dosyaAdi(kulup.ad);

    final belgeler = <(String, Uint8List)>[
      (
        'Kulup_Yillik_Plan_$ad.pdf',
        await ClubPdfGenerator.yillikPlanBytes(
          kulup: kulup,
          plan: plan,
          teacherProfile: teacherProfile,
        )
      ),
      (
        'Kulup_Uye_Listesi_$ad.pdf',
        await ClubPdfGenerator.uyeListesiBytes(
          kulup: kulup,
          uyeler: uyeler,
          teacherProfile: teacherProfile,
        )
      ),
      (
        'Kulup_Faaliyet_Raporu_$ad.pdf',
        await ClubPdfGenerator.faaliyetRaporuBytes(
          kulup: kulup,
          plan: plan,
          faaliyetler: faaliyetler,
          uyeSayisi: uyeler.length,
          teacherProfile: teacherProfile,
        )
      ),
    ];

    final dizin = await getTemporaryDirectory();
    final dosyalar = <XFile>[];
    for (final (dosyaAdi, bayt) in belgeler) {
      final f = File('${dizin.path}/$dosyaAdi');
      await f.writeAsBytes(bayt);
      dosyalar.add(XFile(f.path, mimeType: 'application/pdf'));
    }

    await SharePlus.instance.share(
      ShareParams(
        files: dosyalar,
        subject: '${kulup.ad} — Kulüp Belgeleri',
      ),
    );
  }

  static String _dosyaAdi(String ad) => ad
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
}

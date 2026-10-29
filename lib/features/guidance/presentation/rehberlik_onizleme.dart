import 'package:flutter/material.dart';

import '../../../data/models/class_model.dart';
import '../../../shared/screens/pdf_preview_screen.dart';
import '../../auth_profile/data/models/teacher_profile_model.dart';
import '../data/models/guidance_plan_model.dart';
import '../data/repositories/guidance_plan_repository.dart';
import '../utils/guidance_plan_pdf_generator.dart';
import '../utils/rehberlik_etkinlik_pdf.dart';

/// Rehberlik planı belgelerinin önizlemesi.
///
/// Haftalık takip sayfası ve Rehberlik Dosyası aynı belgeleri açar; iki
/// yerde ayrı yazılınca biri güncellenip öteki eskide kalıyordu.
class RehberlikOnizleme {
  RehberlikOnizleme._();

  /// Yıllık takip çizelgesi: haftaların uygulandı/uygulanmadı durumu.
  static Future<void> planCizelgesi(
    BuildContext context, {
    required ClassModel classModel,
    required TeacherProfileModel teacher,
    required List<GuidancePlanItem> plan,
    required Map<int, GuidanceLogEntry> kayitlar,
    required int grade,
    required String yil,
  }) {
    return PdfPreviewScreen.open(
      context,
      title: 'Rehberlik planı',
      subtitle: '${classModel.name} · $yil',
      fileName: 'Rehberlik_Plani_${classModel.name}.pdf',
      documentBuilder: (_) => GuidancePlanPdfGenerator.build(
        plan: plan,
        kayitlar: kayitlar,
        gradeLevel: grade,
        className: classModel.name,
        schoolName: teacher.schoolName,
        teacherName: teacher.fullName,
        academicYear: yil,
      ),
    );
  }

  /// Haftaların uygulama kaydı (her hafta bir sayfa).
  ///
  /// Kullanıcı (29 Ekim 2026): "Her hafta çıktı alınabilir olmalı; bizde
  /// yalnız yapıldı/yapılmadı raporu var, yapılan etkinliğin çıktısı yok."
  static Future<void> uygulamaKayitlari(
    BuildContext context, {
    required ClassModel classModel,
    required TeacherProfileModel teacher,
    required GuidancePlanRepository repo,
    required List<GuidancePlanItem> maddeler,
    required Map<int, GuidanceLogEntry> kayitlar,
    required int grade,
    required String yil,
    required String baslik,
  }) async {
    final haftalar = <RehberlikHaftasi>[
      for (final m in maddeler)
        (
          madde: m,
          etkinlik: await repo.activityFor(gradeLevel: grade, hafta: m.hafta ?? 0),
          kayit: kayitlar[m.siraNo],
        ),
    ];
    if (!context.mounted) return;
    await PdfPreviewScreen.open(
      context,
      title: 'Rehberlik etkinliği uygulama kaydı',
      subtitle: '${classModel.name} · $baslik',
      fileName: 'Rehberlik_Etkinlik_${classModel.name}_${baslik.replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_')}.pdf',
      documentBuilder: (_) => RehberlikEtkinlikPdf.olustur(
        haftalar: haftalar,
        schoolName: teacher.schoolName,
        className: classModel.name,
        teacherName: teacher.fullName,
        academicYear: yil,
      ),
    );
  }
}

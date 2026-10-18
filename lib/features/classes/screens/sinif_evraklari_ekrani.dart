import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../../../shared/screens/pdf_preview_screen.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../attendance/presentation/widgets/participation_cumulative_reports_modal.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../presentation/widgets/classroom_rules_editor_modal.dart';
import '../presentation/widgets/duty_schedule_editor_modal.dart';
import '../presentation/widgets/parent_invitation_editor_modal.dart';
import '../presentation/widgets/parent_meeting_editor_modal.dart';
import '../providers/absence_followup_provider.dart';
import '../providers/student_provider.dart';
import '../utils/classroom_documents_pdf_generator.dart';

/// Sınıf evrakları (sınıf sayfasındaki "Evrak" düğmesi).
///
/// Eskiden yalnız rehberlik sınıfının "Sınıfım" merkezinin altındaydı; o
/// merkez kalkınca (18 Ekim 2026) her sınıfın kendi evrak sayfası oldu.
/// Ders sınıfında yalnız o derse ait belgeler çıkar. Şube evrakları
/// (nöbetçi listesi, veli toplantısı, devamsızlık çizelgesi, acil durum
/// listesi, kulüp dağılımı, sınıf kuralları) rehberlik sınıfına özgüdür.
class SinifEvraklariEkrani extends ConsumerWidget {
  final ClassModel classModel;

  const SinifEvraklariEkrani({super.key, required this.classModel});

  static Future<void> ac(BuildContext context, ClassModel classModel) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SinifEvraklariEkrani(classModel: classModel)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = ref.watch(studentListProvider(classModel.id!)).valueOrNull ?? const <StudentModel>[];
    final profile = ref.watch(teacherProfileProvider);
    final rehberlik = classModel.isHomeroom;

    final dersBelgeleri = <_Belge>[
      _Belge(
        'Ders İçi Katılım & Ödev Raporları',
        'Dönem sonu raporu, veli toplantısı kılavuzu',
        Icons.assessment_rounded,
        () => ParticipationCumulativeReportsModal.show(context, initialClassId: classModel.id),
      ),
      _Belge(
        'Sınıf Öğrenci Listesi Formu',
        'Resmî imzalı standart A4 sınıf listesi',
        Icons.format_list_numbered_rounded,
        () => ClassroomDocumentsPdfGenerator.generateStudentListPdf(
          context: context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Ders İçi Değerlendirme Not Çizelgesi',
        'A4 yatay 10 etkinlikli değerlendirme formu',
        Icons.fact_check_outlined,
        () => PdfPreviewScreen.open(
          context,
          title: 'Ders İçi Değerlendirme Çizelgesi',
          subtitle: '${classModel.name} - ${classModel.subject}',
          fileName: 'Degerlendirme_Cizelgesi_${classModel.name}.pdf',
          documentBuilder: (format) => ClassroomDocumentsPdfGenerator.generateEvaluationSheetPdfBytes(
            classModel: classModel,
            students: students,
            teacherProfile: profile,
          ),
        ),
      ),
    ];

    final subeBelgeleri = <_Belge>[
      _Belge(
        'Nöbetçi Listesi',
        'Haftalık nöbetçi öğrenci çizelgesi',
        Icons.shield_outlined,
        () => DutyScheduleEditorModal.show(
          context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Devamsız Öğrenci Takip Çizelgesi',
        'Veli iletişimli, imzalı devamsızlık takip formu',
        Icons.event_busy_outlined,
        () => ClassroomDocumentsPdfGenerator.generateAbsenceFollowupPdf(
          context: context,
          classModel: classModel,
          entries: ref.read(absenceFollowupProvider(classModel.id!)).valueOrNull ?? const [],
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Acil Durum & Veli İletişim Listesi',
        'Veli telefonları ve acil durum rehberlik belgesi',
        Icons.contact_phone_outlined,
        () => ClassroomDocumentsPdfGenerator.generateEmergencyContactListPdf(
          context: context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Sosyal Kulüp Öğrenci Dağılımı',
        'Kulüp tercihleri ve öğrenci eşleştirme tablosu',
        Icons.palette_outlined,
        () => ClassroomDocumentsPdfGenerator.generateClubDistributionPdf(
          context: context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Veli Davetiye Mektubu',
        'Tek A4\'te 8 adet kesilebilir davetiye',
        Icons.mail_outline_rounded,
        () => ParentInvitationEditorModal.show(context, classModel: classModel, teacherProfile: profile),
      ),
      _Belge(
        'Veli Toplantı Tutanağı & İmza Sirküsü',
        'Gündem maddeleri, kararlar ve veli imza çizelgesi',
        Icons.how_to_reg_outlined,
        () => ParentMeetingEditorModal.show(
          context,
          classModel: classModel,
          students: students,
          teacherProfile: profile,
        ),
      ),
      _Belge(
        'Sınıf Kuralları Afişi',
        'Hazır 10 MEB kuralı veya düzenlenebilir A4 afiş',
        Icons.format_paint_outlined,
        () => ClassroomRulesEditorModal.show(context, classModel: classModel, teacherProfile: profile),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(title: '${classModel.name} Evrakları', subtitle: 'Sınıfa ait belgeler'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            _baslik(isDark, 'Ders belgeleri'),
            for (final b in dersBelgeleri) _kart(context, isDark, b, students.isEmpty),
            _baslik(isDark, 'Şube evrakları'),
            if (rehberlik)
              for (final b in subeBelgeleri) _kart(context, isDark, b, students.isEmpty)
            else
              Text(
                'Nöbetçi listesi, veli toplantısı, devamsızlık çizelgesi gibi şube '
                'evrakları rehberlik sınıfınızın sayfasında çıkar.',
                style: AppFonts.outfit(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bölüm başlığı. toUpperCase() YOK: Dart 'i'yi 'I' yapar.
  Widget _baslik(bool isDark, String metin) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );

  Widget _kart(BuildContext context, bool isDark, _Belge b, bool ogrenciYok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: ogrenciYok
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Evrak oluşturmak için önce sınıfa öğrenci ekleyin.')),
                  )
              : b.ac,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(b.ikon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.ad,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        b.aciklama,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.picture_as_pdf_rounded, size: 17, color: Color(0xFFFF512F)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Belge {
  final String ad;
  final String aciklama;
  final IconData ikon;
  final VoidCallback ac;

  const _Belge(this.ad, this.aciklama, this.ikon, this.ac);
}

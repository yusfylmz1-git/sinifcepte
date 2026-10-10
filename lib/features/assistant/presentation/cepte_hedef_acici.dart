import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/geri_yukleme_akisi.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/class_model.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../academic_calendar/screens/academic_calendar_screen.dart';
import '../../analytics/presentation/views/analytics_dashboard_view.dart';
import '../../analytics/presentation/widgets/class_report_card_comments_modal.dart';
import '../../attendance/data/models/classroom_participation_model.dart';
import '../../attendance/presentation/views/arti_eksi_listesi_view.dart';
import '../../attendance/presentation/views/class_lesson_history_view.dart';
import '../../attendance/presentation/views/classroom_participation_view.dart';
import '../../attendance/presentation/widgets/participation_cumulative_reports_modal.dart';
import '../../auth_profile/presentation/views/teacher_profile_setup_view.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../board_config/presentation/tahta_kilidi_screen.dart';
import '../../classes/providers/class_provider.dart';
import '../../classes/screens/absence_followup_screen.dart';
import '../../classes/screens/my_class_hub_screen.dart';
import '../../classes/screens/parent_contacts_screen.dart';
import '../../classes/screens/seating_plan_screen.dart';
import '../../classes/screens/student_list_screen.dart';
import '../../clubs/data/repositories/club_repository.dart';
import '../../clubs/presentation/screens/clubs_hub_screen.dart';
import '../../clubs/presentation/views/club_detail_view.dart';
import '../../documents/data/special_days_repository.dart';
import '../../documents/presentation/views/annual_plans_view.dart';
import '../../documents/presentation/views/daily_plans_view.dart';
import '../../documents/data/council_minutes.dart';
import '../../documents/presentation/views/council_minutes_view.dart';
import '../../documents/presentation/views/documents_hub_view.dart';
import '../../documents/presentation/views/other_documents_view.dart';
import '../../documents/presentation/views/special_days_view.dart';
import '../../documents/presentation/views/teacher_file_view.dart';
import '../../documents/presentation/widgets/pano_content_sheet.dart';
import '../../exam_operations/presentation/views/exam_operations_menu_view.dart';
import '../../exam_operations/presentation/views/exam_tracking_view.dart';
import '../../exam_operations/presentation/views/project_tracking_view.dart';
import '../../exam_operations/presentation/views/quiz_list_view.dart';
import '../../guidance/presentation/screens/guidance_hub_screen.dart';
import '../../guidance/presentation/views/special_education_view.dart';
import '../../navigation/providers/navigation_provider.dart';
import '../../outcomes/providers/outcomes_provider.dart';
import '../../parent_portal/presentation/screens/bulk_announcement_screen.dart';
import '../../parent_portal/presentation/screens/teacher_parent_panel_screen.dart';
import '../../schedule/screens/schedule_table_preview_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../student_photos/presentation/eokul_foto_merkezi_ekrani.dart';
import '../../student_photos/presentation/sinif_foto_ekrani.dart';
import '../data/cepte_arama.dart';
import '../data/cepte_niyet.dart';

/// Alt menü sekmeleri (MainNavigationScreen sırası).
const int _sekmeSiniflar = 1;
const int _sekmeKazanimlar = 2;
const int _sekmeProgram = 3;
const int _sekmeProfil = 4;

/// Aramadaki bir sonucu açar. Plan hazırlama ([PlanEylemi]) burada değil,
/// Cepte ekranında soru-cevapla yürür.
Future<void> cepteHedefiAc(BuildContext context, WidgetRef ref, CepteHedef h) async {
  switch (h.eylem) {
    case EkranEylemi(:final ekran):
      await _ekranAc(context, ref, ekran);
    case SinifEkraniEylemi(:final ekran, :final classId):
      await _sinifEkraniAc(context, ekran, classId);
    case OgrenciEylemi(:final classId):
      final c = await ClassRepository().getClassById(classId);
      if (c == null || !context.mounted) return;
      await _git(context, StudentListScreen(classModel: c));
    case BelirliGunEylemi(:final ad, :final etkinlikli):
      await _belirliGunAc(context, ref, ad, etkinlikli: etkinlikli);
    case KulupEylemi(:final kulupId):
      final kulup = kulupId == null ? null : await ClubRepository().kulup(kulupId);
      if (!context.mounted) return;
      await _git(context, kulup == null ? const ClubsHubScreen() : ClubDetailView(kulup: kulup));
    case KazanimEylemi(:final sinif, :final dersKodu, :final dersAdi, :final yayinci):
      // Ana sayfadaki "Günün dersleri" ile aynı yol: gerçek kod ve yayınevi
      // (bkz. kazanim_ders_eslestirici; ad gönderilince 40. hafta açılıyordu).
      final sinifN = ref.read(selectedGradeProvider.notifier);
      final dersN = ref.read(selectedSubjectProvider.notifier);
      final favoriN = ref.read(isFavoritesModeProvider.notifier);
      sinifN.state = sinif;
      dersN.state = {'subject_code': dersKodu, 'subject_name': dersAdi, 'publisher': yayinci};
      favoriN.state = false;
      _sekmeyeGec(context, ref, _sekmeKazanimlar);
    case PlanEylemi():
      // Cepte ekranı yürütür (sınıf/ders/okul türü sorulabilir).
      break;
  }
}

Future<void> _git(BuildContext context, Widget hedef) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => hedef));

/// Alt menüdeki ekranlar sayfa olarak değil sekme olarak açılır; Cepte
/// kapanır ve sekmeye geçilir.
void _sekmeyeGec(BuildContext context, WidgetRef ref, int sekme) {
  final nav = ref.read(navigationIndexProvider.notifier);
  Navigator.of(context).popUntil((r) => r.isFirst);
  nav.state = sekme;
}

Future<void> _ekranAc(BuildContext context, WidgetRef ref, CepteEkran ekran) async {
  switch (ekran) {
    case CepteEkran.kazanimlar:
      return _sekmeyeGec(context, ref, _sekmeKazanimlar);
    case CepteEkran.dersProgrami:
      return _sekmeyeGec(context, ref, _sekmeProgram);
    case CepteEkran.siniflarim:
      return _sekmeyeGec(context, ref, _sekmeSiniflar);
    case CepteEkran.profil:
      return _sekmeyeGec(context, ref, _sekmeProfil);
    case CepteEkran.donemSonuRaporlari:
      return ParticipationCumulativeReportsModal.show(context);
    case CepteEkran.karneGorusleri:
      return ClassReportCardCommentsModal.show(context);
    case CepteEkran.veriYedekleme:
      AppDrawer.showBackupDialog(context);
      return;
    default:
      break;
  }
  final Widget hedef = switch (ekran) {
    CepteEkran.dersSaatleri => const ScheduleTablePreviewScreen(),
    CepteEkran.dersIciKatilim => const ClassroomParticipationView(),
    CepteEkran.yillikPlanlar => const AnnualPlansView(),
    CepteEkran.gunlukPlanlar => const DailyPlansView(),
    CepteEkran.belirliGunler => const SpecialDaysView(),
    CepteEkran.sosyalKulupler => const ClubsHubScreen(),
    CepteEkran.kurulTutanaklari => const DocumentsHubView(),
    CepteEkran.ogretmenDosyasi => const TeacherFileView(),
    CepteEkran.digerEvraklar => const OtherDocumentsView(),
    CepteEkran.sinavIslemleri => const ExamOperationsMenuView(),
    CepteEkran.sinavTakvimi => const ExamTrackingView(),
    CepteEkran.projeOdev => const ProjectTrackingView(),
    CepteEkran.quizSozlu => const QuizListView(),
    CepteEkran.sinavAnalizleri => const AnalyticsDashboardView(),
    CepteEkran.rehberlik => const GuidanceHubScreen(),
    CepteEkran.ozelEgitim => const SpecialEducationView(),
    CepteEkran.calismaTakvimi => const AcademicCalendarScreen(),
    CepteEkran.eokulFoto => const EokulFotoMerkeziEkrani(),
    CepteEkran.tahtaKilidi => const TahtaKilidiScreen(),
    CepteEkran.topluDuyuru => const BulkAnnouncementScreen(),
    CepteEkran.zumreTutanagi => const CouncilMinutesView(kind: CouncilKind.zumre),
    CepteEkran.sokTutanagi => const CouncilMinutesView(kind: CouncilKind.sok),
    CepteEkran.geriYukleme => const GeriYuklemeEkrani(),
    CepteEkran.ayarlar => const SettingsScreen(),
    CepteEkran.profilBilgileri => const TeacherProfileSetupView(),
    // Sınıfa bağlı eski niyetler: sınıf Sınıfım'da seçilir.
    CepteEkran.sinifim ||
    CepteEkran.veliPaneli ||
    CepteEkran.devamsizlik ||
    CepteEkran.oturmaPlani ||
    CepteEkran.nobetciListesi ||
    CepteEkran.ogrenciListesi ||
    CepteEkran.ogretmenKadrosu =>
      const MyClassHubScreen(),
    // Yukarıda sekme/pencere olarak açıldılar.
    CepteEkran.kazanimlar ||
    CepteEkran.dersProgrami ||
    CepteEkran.siniflarim ||
    CepteEkran.profil ||
    CepteEkran.donemSonuRaporlari ||
    CepteEkran.karneGorusleri ||
    CepteEkran.veriYedekleme =>
      const SizedBox.shrink(),
  };
  if (!context.mounted) return;
  await _git(context, hedef);
}

Future<void> _sinifEkraniAc(BuildContext context, CepteSinifEkrani ekran, int classId) async {
  final ClassModel? c = await ClassRepository().getClassById(classId);
  if (c == null || !context.mounted) return;
  switch (ekran) {
    case CepteSinifEkrani.islenenDersler:
      await ClassLessonHistoryView.open(context, classId: classId, className: c.name);
      return;
    case CepteSinifEkrani.artiEksi:
      final ogrenciler = await StudentRepository().getStudentsByClassId(classId);
      if (!context.mounted) return;
      final bugun = DateTime.now();
      await _git(
        context,
        ArtiEksiListesiView(
          classId: classId,
          baslik: c.subject.isEmpty ? c.name : '${c.name} · ${c.subject}',
          tarih: '${bugun.year}-${bugun.month.toString().padLeft(2, '0')}-'
              '${bugun.day.toString().padLeft(2, '0')}',
          ogrenciler: [
            for (final o in ogrenciler)
              if (o.id != null)
                StudentParticipationEvaluation(
                  studentId: o.id!,
                  studentName: '${o.firstName} ${o.lastName}'.trim(),
                  studentNumber: o.schoolNumber,
                ),
          ],
        ),
      );
      return;
    default:
      break;
  }
  final Widget hedef = switch (ekran) {
    CepteSinifEkrani.sinifim => MyClassHubScreen(initialClass: c),
    CepteSinifEkrani.ogrenciListesi => StudentListScreen(classModel: c),
    CepteSinifEkrani.oturmaPlani => SeatingPlanScreen(classModel: c),
    CepteSinifEkrani.devamsizlik => AbsenceFollowupScreen(classModel: c),
    CepteSinifEkrani.veliIletisim => ParentContactsScreen(classModel: c),
    CepteSinifEkrani.veliPaneli => TeacherParentPanelScreen(classModel: c),
    CepteSinifEkrani.eokulFoto => SinifFotoEkrani(sinif: c),
    CepteSinifEkrani.islenenDersler || CepteSinifEkrani.artiEksi => const SizedBox.shrink(),
  };
  if (!context.mounted) return;
  await _git(context, hedef);
}

/// Etkinlikli günde doğrudan o günün panosu (pano, konuşma, şiir); belirli
/// gün ekranındaki dokunuşla aynı pencere.
Future<void> _belirliGunAc(
  BuildContext context,
  WidgetRef ref,
  String ad, {
  required bool etkinlikli,
}) async {
  if (!etkinlikli) return _git(context, const SpecialDaysView());
  final gunler = await SpecialDaysRepository().all();
  final gun = gunler.where((g) => g.ad == ad).firstOrNull;
  final icerik = await PanoContentRepository().forDay(ad);
  if (!context.mounted) return;
  if (gun == null) return _git(context, const SpecialDaysView());
  final profil = ref.read(teacherProfileProvider);
  final sinif = ref.read(homeroomClassProvider);
  await PanoContentSheet.show(
    context,
    gun: gun,
    icerik: icerik,
    schoolName: profil.schoolName,
    className: sinif?.name ?? '',
    teacherName: profil.fullName,
    academicYear: AppDateFormatter.academicYearLabel(),
  );
}

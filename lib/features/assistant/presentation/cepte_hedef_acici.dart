import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/geri_yukleme_akisi.dart';
import '../../../core/backup/yedek_penceresi.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/class_model.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../academic_calendar/screens/academic_calendar_screen.dart';
import '../../analytics/presentation/views/exam_analysis_list_view.dart';
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
import '../../classes/screens/class_list_screen.dart';
import '../../classes/screens/absence_followup_screen.dart';
import '../../classes/screens/parent_contacts_screen.dart';
import '../../classes/screens/seating_plan_screen.dart';
import '../../classes/screens/sinif_evraklari_ekrani.dart';
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
import '../../documents/presentation/views/evraklar_sekmesi.dart';
import '../../documents/presentation/views/special_days_view.dart';
import '../../documents/presentation/views/teacher_file_view.dart';
import '../../documents/presentation/widgets/pano_content_sheet.dart';
import '../../exam_operations/presentation/views/exam_operations_menu_view.dart';
import '../../exam_operations/presentation/views/exam_tracking_view.dart';
import '../../exam_operations/presentation/views/project_tracking_view.dart';
import '../../exam_operations/presentation/views/quiz_list_view.dart';
import '../../guidance/presentation/screens/guidance_hub_screen.dart';
import '../../navigation/providers/navigation_provider.dart';
import '../../outcomes/presentation/views/weekly_outcomes_view.dart';
import '../../outcomes/providers/outcomes_provider.dart';
import '../../parent_portal/presentation/screens/sinif_velileri_ekrani.dart';
import '../../schedule/screens/schedule_table_preview_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../student_photos/presentation/eokul_foto_merkezi_ekrani.dart';
import '../../student_photos/presentation/sinif_foto_ekrani.dart';
import '../data/cepte_arama.dart';
import '../data/cepte_niyet.dart';

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
      await _git(context, const WeeklyOutcomesView());
    case PlanEylemi():
      // Cepte ekranı yürütür (sınıf/ders/okul türü sorulabilir).
      break;
  }
}

Future<void> _git(BuildContext context, Widget hedef) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => hedef));

/// Alt çubuktaki ekranlar (Ders Programı, Sınıfım, Profil) sayfa olarak
/// değil sekme olarak açılır; Cepte kapanır ve sekmeye geçilir.
void _sekmeyeGec(BuildContext context, WidgetRef ref, int sekme) {
  final nav = ref.read(navigationIndexProvider.notifier);
  Navigator.of(context).popUntil((r) => r.isFirst);
  nav.state = sekme;
}

Future<void> _ekranAc(BuildContext context, WidgetRef ref, CepteEkran ekran) async {
  switch (ekran) {
    case CepteEkran.dersProgrami:
      return _sekmeyeGec(context, ref, AnaSekme.dersProgrami);
    case CepteEkran.profil:
      return _sekmeyeGec(context, ref, AnaSekme.profil);
    case CepteEkran.donemSonuRaporlari:
      return ParticipationCumulativeReportsModal.show(context);
    case CepteEkran.karneGorusleri:
      return ClassReportCardCommentsModal.show(context);
    case CepteEkran.veriYedekleme:
      yedekPenceresiniAc(context);
      return;
    case CepteEkran.sinifim ||
          CepteEkran.ogrenciListesi ||
          CepteEkran.veliPaneli ||
          CepteEkran.ogretmenKadrosu ||
          CepteEkran.topluDuyuru ||
          CepteEkran.devamsizlik ||
          CepteEkran.oturmaPlani ||
          CepteEkran.nobetciListesi:
      return _rehberlikSinifindaAc(context, ref, ekran);
    default:
      break;
  }
  final Widget hedef = switch (ekran) {
    // Özet'teki düğmelerin sayfaları (26 Ekim 2026).
    CepteEkran.kazanimlar => const WeeklyOutcomesView(),
    CepteEkran.siniflarim => const ClassListScreen(),
    CepteEkran.digerEvraklar => const EvraklarSekmesi(),
    CepteEkran.dersSaatleri => const ScheduleTablePreviewScreen(),
    CepteEkran.dersIciKatilim => const ClassroomParticipationView(),
    CepteEkran.yillikPlanlar => const AnnualPlansView(),
    CepteEkran.gunlukPlanlar => const DailyPlansView(),
    CepteEkran.belirliGunler => const SpecialDaysView(),
    CepteEkran.sosyalKulupler => const ClubsHubScreen(),
    CepteEkran.kurulTutanaklari => const DocumentsHubView(),
    CepteEkran.ogretmenDosyasi => const TeacherFileView(),
    CepteEkran.sinavIslemleri => const ExamOperationsMenuView(),
    CepteEkran.sinavTakvimi => const ExamTrackingView(),
    CepteEkran.projeOdev => const ProjectTrackingView(),
    CepteEkran.quizSozlu => const QuizListView(),
    CepteEkran.sinavAnalizleri => const ExamAnalysisListView(),
    CepteEkran.rehberlik => const GuidanceHubScreen(),
    // Rehberlik ekranının sekmeleri: Özel eğitim görünümü tek başına
    // açılınca sayfa iskeleti yoktu (siyah zemin, başlık ve geri düğmesi
    // yok, durum çubuğunun altında; 26 Ekim 2026).
    CepteEkran.bep => const GuidanceHubScreen(baslangicSekmesi: GuidanceHubScreen.bepSekmesi),
    CepteEkran.ozelEgitim =>
      const GuidanceHubScreen(baslangicSekmesi: GuidanceHubScreen.ozelEgitimSekmesi),
    CepteEkran.calismaTakvimi => const AcademicCalendarScreen(),
    CepteEkran.eokulFoto => const EokulFotoMerkeziEkrani(),
    CepteEkran.tahtaKilidi => const TahtaKilidiScreen(),
    CepteEkran.zumreTutanagi => const CouncilMinutesView(kind: CouncilKind.zumre),
    CepteEkran.sokTutanagi => const CouncilMinutesView(kind: CouncilKind.sok),
    CepteEkran.geriYukleme => const GeriYuklemeEkrani(),
    CepteEkran.ayarlar => const SettingsScreen(),
    CepteEkran.profilBilgileri => const TeacherProfileSetupView(),
    // Yukarıda sekme/pencere ya da rehberlik sınıfında açıldılar.
    CepteEkran.sinifim ||
    CepteEkran.veliPaneli ||
    CepteEkran.devamsizlik ||
    CepteEkran.oturmaPlani ||
    CepteEkran.nobetciListesi ||
    CepteEkran.ogrenciListesi ||
    CepteEkran.ogretmenKadrosu ||
    CepteEkran.topluDuyuru ||
    CepteEkran.dersProgrami ||
    CepteEkran.profil ||
    CepteEkran.donemSonuRaporlari ||
    CepteEkran.karneGorusleri ||
    CepteEkran.veriYedekleme =>
      const SizedBox.shrink(),
  };
  if (!context.mounted) return;
  await _git(context, hedef);
}

/// Sınıf adı verilmeden sorulan sınıf işleri ("veliler", "nöbet",
/// "devamsızlık"...) rehberlik sınıfında açılır.
///
/// Eskiden hepsi "Sınıfım" merkezini açıyordu; o merkez kalktı (18 Ekim
/// 2026). Sınıfın kendisi (öğrenci listesi) alt çubuktaki "Sınıfım"
/// sekmesidir (26 Ekim 2026). Rehberlik sınıfı seçilmemişse sınıf listesi
/// açılır ve nasıl seçileceği söylenir.
Future<void> _rehberlikSinifindaAc(BuildContext context, WidgetRef ref, CepteEkran ekran) async {
  final siniflar = await ClassRepository().getAllClasses();
  final sinif = siniflar.where((c) => c.isHomeroom).firstOrNull;
  if (!context.mounted) return;
  if (sinif == null) {
    final messenger = ScaffoldMessenger.of(context);
    await _git(context, const ClassListScreen());
    messenger.showSnackBar(const SnackBar(
      content: Text('Önce rehberlik sınıfınızı seçin: sınıf kartındaki ⋮ › Rehberlik Sınıfı Yap.'),
      duration: Duration(seconds: 5),
    ));
    return;
  }
  final Widget? hedef = switch (ekran) {
    CepteEkran.veliPaneli ||
    CepteEkran.ogretmenKadrosu ||
    CepteEkran.topluDuyuru =>
      SinifVelileriEkrani(classModel: sinif),
    CepteEkran.devamsizlik => AbsenceFollowupScreen(classModel: sinif),
    CepteEkran.oturmaPlani => SeatingPlanScreen(classModel: sinif),
    CepteEkran.nobetciListesi => SinifEvraklariEkrani(classModel: sinif),
    _ => null,
  };
  if (hedef == null) {
    // Sınıfın kendisi: alt çubuktaki "Sınıfım" sekmesi.
    _sekmeyeGec(context, ref, AnaSekme.sinifim);
    return;
  }
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
    CepteSinifEkrani.sinifim => StudentListScreen(classModel: c),
    CepteSinifEkrani.ogrenciListesi => StudentListScreen(classModel: c),
    CepteSinifEkrani.oturmaPlani => SeatingPlanScreen(classModel: c),
    CepteSinifEkrani.devamsizlik => AbsenceFollowupScreen(classModel: c),
    CepteSinifEkrani.veliIletisim => ParentContactsScreen(classModel: c),
    // Veli bağlantıları rehberlik sınıfında; ders sınıfında sınıf
    // sayfası açılır, şeritteki pasif "Veliler" nedenini söyler.
    CepteSinifEkrani.veliPaneli =>
      c.isHomeroom ? SinifVelileriEkrani(classModel: c) : StudentListScreen(classModel: c),
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

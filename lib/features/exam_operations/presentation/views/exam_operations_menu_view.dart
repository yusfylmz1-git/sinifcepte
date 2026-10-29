import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/gruplu_liste.dart';
import '../../../analytics/presentation/views/exam_analysis_list_view.dart';
import '../../../analytics/presentation/widgets/class_report_card_comments_modal.dart';
import '../../../analytics/providers/exam_analysis_provider.dart';
import '../../data/models/exam_model.dart';
import '../../providers/exam_tracking_provider.dart';
import 'exam_tracking_view.dart';
import 'project_tracking_view.dart';
import 'quiz_list_view.dart';

/// Sınav İşlemleri: not çizelgeleri, sınavlar, dönem sonu.
///
/// ## Neden bu düzen (DEG-10, 29 Ekim 2026)
/// Kullanıcı: "Sınav işlemleri görünüm olarak çok karmaşık; en üstteki
/// öğrenci değerlendirme takip yazısı düğme gibi görünüyor; alttaki iki
/// sarı düğme yakışmadı." Üstteki açıklama kutusu kalktı; beş iş, Rehberlik
/// Dosyası'nın onaylanan gruplu listesinde ne zaman yapıldığına göre
/// dizildi. Rozetler ("Dinamik Çizelge", "Geri Sayım") bilgi taşımıyordu,
/// yerlerini durum satırı aldı: sıradaki sınav, girilen sınav sayısı.
class ExamOperationsMenuView extends ConsumerWidget {
  const ExamOperationsMenuView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final yaklasan = ref.watch(examTrackingProvider).upcomingExams;
    final analizSayisi = ref.watch(examAnalysisListProvider).valueOrNull?.length;

    void ac(Widget sayfa) => Navigator.push(context, MaterialPageRoute(builder: (_) => sayfa));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Sınav İşlemleri',
        showBackButton: true,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const GrupBasligi('NOT ÇİZELGELERİ'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('sinav_islemleri_quiz'),
                ikon: Icons.table_chart_outlined,
                ad: 'Quiz ve Sözlü Notlar',
                alt: 'Her quiz bir sütun, ortalama kendiliğinden',
                onTap: () => ac(const QuizListView()),
              ),
              GrupSatiri(
                key: const ValueKey('sinav_islemleri_proje'),
                ikon: Icons.assignment_turned_in_outlined,
                ad: 'Proje ve Ödev Değerlendirme',
                alt: 'Konu, teslim ve 100 puanlık ölçekle puanlama',
                onTap: () => ac(const ProjectTrackingView()),
              ),
            ]),
            const SizedBox(height: 18),
            const GrupBasligi('SINAVLAR'),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('sinav_islemleri_takvim'),
                ikon: Icons.event_outlined,
                ad: 'Sınav Takvimi',
                alt: siradakiSinav(yaklasan),
                onTap: () => ac(const ExamTrackingView()),
              ),
              GrupSatiri(
                key: const ValueKey('sinav_islemleri_analiz'),
                ikon: Icons.insights_outlined,
                ad: 'Sınav Analizleri',
                alt: analizSayisi == null || analizSayisi == 0
                    ? 'Soru bazlı başarı ve MEB analiz raporu'
                    : '$analizSayisi sınav · soru bazlı başarı, MEB raporu',
                onTap: () => ac(const ExamAnalysisListView()),
              ),
            ]),
            const SizedBox(height: 18),
            GrupBasligi('DÖNEM SONU', etiket: zamanEtiketi(const [1, 6], DateTime.now())),
            const SizedBox(height: 7),
            GrupKutusu(satirlar: [
              GrupSatiri(
                key: const ValueKey('sinav_islemleri_karne'),
                ikon: Icons.rate_review_outlined,
                ad: 'e-Okul Karne Görüşü',
                alt: 'Ders içi katılımdan görüş ve katılım puanı',
                onTap: () => ClassReportCardCommentsModal.show(context),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Sınav Takvimi satırının durumu: en yakın sınav ve kalan gün.
String siradakiSinav(List<ExamModel> yaklasan) {
  if (yaklasan.isEmpty) return 'Yaklaşan sınav yok · okulun yazılı tarihlerini ekleyin';
  final s = yaklasan.first;
  final gun = s.daysRemaining;
  final kalan = gun == 0
      ? 'bugün'
      : gun == 1
          ? 'yarın'
          : '$gun gün kaldı';
  return 'Sıradaki: ${s.title} · $kalan';
}

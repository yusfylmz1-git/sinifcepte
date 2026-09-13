import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/screens/my_class_hub_screen.dart';
import '../../../clubs/presentation/screens/clubs_hub_screen.dart';
import '../../../documents/presentation/views/documents_hub_view.dart';
import '../../../documents/presentation/views/other_documents_view.dart';
import '../../../documents/presentation/views/special_days_view.dart';
import '../../../documents/presentation/views/teacher_file_view.dart';
import '../../../documents/utils/annual_plan_pdf_generator.dart';
import '../../../documents/utils/daily_plan_pdf_generator.dart';
import '../../../exam_operations/presentation/views/exam_operations_menu_view.dart';
import '../../../guidance/presentation/screens/guidance_hub_screen.dart';
import '../../../outcomes/presentation/views/weekly_outcomes_view.dart';
import '../../../schedule/screens/schedule_screen.dart';
import '../../data/cepte_belge_servisi.dart';
import '../../data/cepte_niyet.dart';

/// Sohbetteki tek bir satır.
class _Mesaj {
  const _Mesaj({
    required this.metin,
    required this.benden,
    this.eylem,
    this.eylemEtiketi,
    this.secenekler = const [],
  });

  final String metin;
  final bool benden;
  final VoidCallback? eylem;
  final String? eylemEtiketi;
  final List<String> secenekler;
}

/// Cepte — konuşarak kullanılan menü.
///
/// ## Neden var
/// Uygulamada 32 ekran var ve öğretmen "ne nerede bulmak gerçekten zor"
/// diyor. Asıl kayıp yeni özellik değil, GÖRÜNÜRLÜK. Cepte yeni bir iş
/// yapmaz; var olanı bulunur kılar.
///
/// ## Neden dil modeli değil
/// Cihazda çalışan küçük bir model APK'yı 89 MB'dan 400 MB'ın üstüne
/// çıkarır ve Türkçe eğitim jargonunda kazanım UYDURABİLİR. Bu
/// uygulamanın çıktısı teftişe gidiyor. Kural tabanlı eşleme ya doğru
/// anlar ya "anlamadım" der — arada bir şey yoktur.
class CepteSohbetView extends ConsumerStatefulWidget {
  const CepteSohbetView({super.key});

  @override
  ConsumerState<CepteSohbetView> createState() => _CepteSohbetViewState();
}

class _CepteSohbetViewState extends ConsumerState<CepteSohbetView> {
  final _girdi = TextEditingController();
  final _kaydirma = ScrollController();
  final List<_Mesaj> _mesajlar = [];
  bool _calisiyor = false;

  @override
  void initState() {
    super.initState();
    _mesajlar.add(const _Mesaj(
      metin: 'Merhaba 👋\n\nBelge hazırlayabilir, ekran açabilir veya '
          'kazanım sorabilirim.',
      benden: false,
      secenekler: [
        '5. sınıf türkçe yıllık plan',
        'ders programım',
        'zümre tutanağı',
        'devamsızlık takibi',
      ],
    ));
  }

  @override
  void dispose() {
    _girdi.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  void _ekle(_Mesaj m) {
    setState(() => _mesajlar.add(m));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kaydirma.hasClients) return;
      _kaydirma.animateTo(
        _kaydirma.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _gonder([String? hazirMetin]) async {
    final metin = (hazirMetin ?? _girdi.text).trim();
    if (metin.isEmpty || _calisiyor) return;

    _girdi.clear();
    _ekle(_Mesaj(metin: metin, benden: true));
    setState(() => _calisiyor = true);

    try {
      await _isle(CepteCozumleyici.coz(metin));
    } catch (e, st) {
      debugPrint('Cepte isleme hatasi: $e\n$st');
      _ekle(const _Mesaj(
        metin: 'Bir sorun çıktı, tekrar dener misiniz?',
        benden: false,
      ));
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  Future<void> _isle(CepteNiyet niyet) async {
    switch (niyet.tur) {
      case CepteNiyetTuru.yillikPlan:
      case CepteNiyetTuru.gunlukPlan:
        await _planHazirla(niyet);
      case CepteNiyetTuru.kazanimSor:
        await _kazanimSoyle(niyet);
      case CepteNiyetTuru.ekranAc:
        _ekranAc(niyet);
      case CepteNiyetTuru.belirsiz:
        _ekle(const _Mesaj(
          metin: 'Bunu anlayamadım. Şunlardan birini deneyebilirsiniz:',
          benden: false,
          secenekler: [
            '5. sınıf türkçe yıllık plan',
            '6. sınıf matematik günlük plan',
            'oturma planı',
            'veli paneli',
          ],
        ));
    }
  }

  CepteBelgeServisi get _servis => CepteBelgeServisi(
        dersleriGetir: (sinif) =>
            DatabaseHelper.instance.mevcutDersleriGetir(sinif),
        kazanimlariGetir: ({
          required int gradeLevel,
          required String subjectCode,
          required String publisher,
        }) =>
            DatabaseHelper.instance.kazanimlariGetir(
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          publisher: publisher,
        ),
        takvimdenTarih: AppDateFormatter.getWeekDateRangeText,
      );

  Future<void> _planHazirla(CepteNiyet niyet) async {
    final gunluk = niyet.tur == CepteNiyetTuru.gunlukPlan;
    await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();

    final sonuc =
        await _servis.planHazirla(niyet, ayrintili: gunluk);
    if (!mounted) return;

    if (sonuc.durum == CepteBelgeDurumu.secimGerekli) {
      _ekle(_Mesaj(
        metin: sonuc.mesaj ?? 'Biraz daha bilgiye ihtiyacım var.',
        benden: false,
        secenekler: sonuc.secenekler,
      ));
      return;
    }
    if (sonuc.durum == CepteBelgeDurumu.yapilamaz) {
      _ekle(_Mesaj(metin: sonuc.mesaj ?? 'Bu belge hazırlanamadı.', benden: false));
      return;
    }

    final teacher = ref.read(teacherProfileProvider);
    final yil = '${AppDateFormatter.academicYearLabel()} Eğitim-Öğretim Yılı';
    final ders = sonuc.dersAdi ?? 'Ders';
    final sinifAdi = '${sonuc.sinif}. Sınıf';
    final planlar = sonuc.planlar;

    _ekle(_Mesaj(
      metin: '$ders · $sinifAdi\n${planlar.length} haftalık '
          '${gunluk ? 'günlük' : 'yıllık'} plan hazır.\n\n'
          'Belge TASLAKTIR; zümre onayından geçmelidir.',
      benden: false,
      eylemEtiketi: 'PDF olarak aç',
      eylem: () => PdfPreviewScreen.open(
        context,
        title: gunluk ? '$ders Günlük Planlar' : '$ders Yıllık Çerçeve Planı',
        subtitle: '$sinifAdi • ${planlar.length} Hafta • $yil',
        fileName: '${ders}_${sinifAdi}_'
            '${gunluk ? 'Gunluk' : 'Yillik'}_Plan.pdf',
        documentBuilder: (format) => gunluk
            ? DailyPlanPdfGenerator.generateFullYearPdf(
                allWeeksPlanData: planlar,
                teacher: teacher,
                ders: ders,
                sinif: sinifAdi,
                academicYear: yil,
                format: format,
              )
            : AnnualPlanPdfGenerator.generate(
                allWeeksPlanData: planlar,
                teacher: teacher,
                ders: ders,
                sinif: sinifAdi,
                academicYear: yil,
                format: format,
              ),
      ),
    ));
  }

  Future<void> _kazanimSoyle(CepteNiyet niyet) async {
    if (!niyet.hazir) {
      _ekle(const _Mesaj(
        metin: 'Hangi sınıf ve hangi ders için bakayım?',
        benden: false,
      ));
      return;
    }

    await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
    final sonuc = await _servis.planHazirla(niyet, ayrintili: false);
    if (!mounted) return;

    if (!sonuc.basarili) {
      _ekle(_Mesaj(
        metin: sonuc.mesaj ?? 'Kazanım bulunamadı.',
        benden: false,
        secenekler: sonuc.secenekler,
      ));
      return;
    }

    final hafta = niyet.hafta;
    final plan = hafta == null
        ? sonuc.planlar.first
        : sonuc.planlar.firstWhere(
            (p) => '${(p['meta'] as Map)['hafta']}' == '$hafta. Hafta',
            orElse: () => sonuc.planlar.first,
          );

    final meta = plan['meta'] as Map;
    final kazanimlar =
        (plan['kazanimlar_ve_surec'] as Map)['ogrenme_ciktilari'] as List;

    _ekle(_Mesaj(
      metin: '${meta['ders']} · ${meta['hafta']} (${meta['tarih_araligi']})\n'
          '${meta['tema_unite']}\n\n'
          '${kazanimlar.take(4).map((k) => '• $k').join('\n')}'
          '${kazanimlar.length > 4 ? '\n• … ve ${kazanimlar.length - 4} kazanım daha' : ''}',
      benden: false,
    ));
  }

  /// Ekran açar.
  ///
  /// Sınıfa bağlı ekranlar (oturma planı, nöbetçi listesi, devamsızlık)
  /// önce "hangi sınıf?" sorusunu gerektirdiği için doğrudan açılmaz;
  /// Sınıfım ekranına götürülür ve öğretmen sınıfı orada seçer.
  void _ekranAc(CepteNiyet niyet) {
    final ekran = niyet.ekran;
    if (ekran == null) return;

    final (Widget hedef, String ad) = switch (ekran) {
      CepteEkran.kazanimlar => (const WeeklyOutcomesView(), 'Kazanımlar'),
      CepteEkran.dersIciKatilim => (const OtherDocumentsView(), 'Ders İçi Katılım'),
      CepteEkran.sinavIslemleri => (const ExamOperationsMenuView(), 'Sınav İşlemleri'),
      CepteEkran.rehberlik => (const GuidanceHubScreen(), 'Rehberlik'),
      CepteEkran.digerEvraklar => (const OtherDocumentsView(), 'Diğer Evraklar'),
      CepteEkran.ogretmenDosyasi => (const TeacherFileView(), 'Öğretmen Dosyası'),
      CepteEkran.belirliGunler => (const SpecialDaysView(), 'Belirli Gün ve Haftalar'),
      CepteEkran.sosyalKulupler => (const ClubsHubScreen(), 'Sosyal Kulüpler'),
      CepteEkran.kurulTutanaklari => (const DocumentsHubView(), 'Kurul Tutanakları'),
      CepteEkran.dersProgrami => (const ScheduleScreen(), 'Ders Programım'),
      // Sınıfa bağlı işler: sınıf seçimi Sınıfım ekranında yapılır.
      CepteEkran.sinifim ||
      CepteEkran.veliPaneli ||
      CepteEkran.devamsizlik ||
      CepteEkran.oturmaPlani ||
      CepteEkran.nobetciListesi ||
      CepteEkran.ogrenciListesi ||
      CepteEkran.ogretmenKadrosu =>
        (const MyClassHubScreen(), 'Sınıfım'),
    };

    // EKRAN KENDİLİĞİNDEN AÇILMAZ, BUTONLA AÇILIR.
    //
    // Önce hem buton koyup hem de doğrudan `push` çağırmıştım: ekran
    // iki kez açılıyor ve öğretmen geri tuşuna iki kez basmak zorunda
    // kalıyordu. Ayrıca sohbette ne olduğunun kaydı kalmalı — yönlendirme
    // sessizce olursa öğretmen Cepte'nin ne anladığını göremez.
    _ekle(_Mesaj(
      metin: '$ad ekranına götürebilirim.',
      benden: false,
      eylemEtiketi: '$ad ekranını aç',
      eylem: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => hedef),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Cepte',
        subtitle: 'Sor, bul, hazırla',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _kaydirma,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                itemCount: _mesajlar.length,
                itemBuilder: (_, i) => _balon(_mesajlar[i], isDark),
              ),
            ),
            if (_calisiyor)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            _girdiAlani(isDark),
          ],
        ),
      ),
    );
  }

  Widget _balon(_Mesaj m, bool isDark) {
    final benden = m.benden;
    return Align(
      alignment: benden ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: benden
              ? AppColors.primary
              : (isDark ? AppColors.darkCardBackground : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(benden ? 16 : 4),
            bottomRight: Radius.circular(benden ? 4 : 16),
          ),
          border: benden
              ? null
              : Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m.metin,
              style: AppFonts.outfit(
                fontSize: 13.5,
                height: 1.45,
                color: benden
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            if (m.eylem != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: m.eylem,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: Text(m.eylemEtiketi ?? 'Aç'),
                ),
              ),
            ],
            if (m.secenekler.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in m.secenekler) _oneriCipi(s, isDark),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Öneri çipi.
  ///
  /// `ActionChip` KULLANILMIYOR: uygulamanın `chipTheme` tanımı light
  /// temada `Colors.white.withValues(alpha: 0.06)` zemin veriyor ve
  /// etiket rengi hiç verilmemiş. Beyaz zeminde çip de yazı da
  /// görünmüyordu (cihazda ölçüldü). Renkler burada elle veriliyor —
  /// aynı yaklaşım `class_report_card_comments_modal` içinde de var.
  Widget _oneriCipi(String metin, bool isDark) {
    return InkWell(
      onTap: () => _gonder(metin),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: isDark ? 0.45 : 0.28),
          ),
        ),
        child: Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _girdiAlani(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _girdi,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _gonder(),
              decoration: InputDecoration(
                hintText: 'Ne lazım? Örn: 5. sınıf türkçe yıllık plan',
                hintStyle: const TextStyle(fontSize: 13),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _calisiyor ? null : () => _gonder(),
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

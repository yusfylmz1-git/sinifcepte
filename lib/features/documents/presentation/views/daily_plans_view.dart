import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../utils/daily_plan_pdf_generator.dart';
import '../../utils/plan_week_builder.dart';

/// SınıfCepte - MEB TYMM Günlük Ders Planları Ekranı
///
/// Kademe -> Sınıf -> Branş seçimi yapıldıktan sonra
/// 1'den 36'ya kadar tüm haftaları listeleyen, her hafta için
/// tek tıkla indirme ve en üstte toplu indirme imkânı sunan ekran.
class DailyPlansView extends ConsumerStatefulWidget {
  const DailyPlansView({super.key});

  @override
  ConsumerState<DailyPlansView> createState() => _DailyPlansViewState();
}

class _DailyPlansViewState extends ConsumerState<DailyPlansView> {
  // 0: İlkokul (1-4), 1: Ortaokul (5-8), 2: Lise (9-12)
  int _kademeIndex = 1; // Varsayılan Ortaokul (5. sınıf)
  int _seciliSinif = 5;

  String? _seciliDersKodu;
  String? _seciliDersAdi;
  String? _seciliYayinci;

  List<Map<String, dynamic>> _mevcutDersler = const [];
  List<Map<String, dynamic>> _haftalikPlanlar = [];

  bool _derslerYukleniyor = false;
  bool _planlarYukleniyor = false;
  bool _ilkOdaklanmaYapildi = false;

  // Genişletilmiş hafta kartları (kart içi detay inceleme için)
  final Set<int> _acikKartHaftalari = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ogretmenProfiliyleOdaklan();
    });
  }

  /// Kullanıcı kolaylığı: Girişte öğretmenin kayıtlı okul düzeyine (İlkokul / Ortaokul / Lise)
  /// ve branşına (Bilişim, Türkçe, Matematik vb.) göre otomatik odaklanır.
  void _ogretmenProfiliyleOdaklan() {
    if (_ilkOdaklanmaYapildi) return;
    _ilkOdaklanmaYapildi = true;

    final teacher = ref.read(teacherProfileProvider);
    final classes = ref.read(classListProvider).valueOrNull ?? [];

    int kademe = 1; // Varsayılan: Ortaokul
    final sType = (teacher.schoolType ?? '').toLowerCase();
    final sName = teacher.schoolName.toLowerCase();

    if (sType.contains('ilkokul') || sType.contains('primary') || sName.contains('ilkokul')) {
      kademe = 0;
    } else if (sType.contains('lise') || sType.contains('high') || sName.contains('lise') || sName.contains('fen lisesi') || sName.contains('anadolu lisesi')) {
      kademe = 2;
    } else if (sType.contains('ortaokul') || sType.contains('middle') || sName.contains('ortaokul') || sName.contains('iho')) {
      kademe = 1;
    } else if (classes.isNotEmpty) {
      final grades = classes
          .map((c) => int.tryParse(RegExp(r'\d+').firstMatch(c.name)?.group(0) ?? ''))
          .whereType<int>()
          .toList();
      if (grades.any((g) => g >= 1 && g <= 4)) {
        kademe = 0;
      } else if (grades.any((g) => g >= 5 && g <= 8)) {
        kademe = 1;
      } else if (grades.any((g) => g >= 9 && g <= 12)) {
        kademe = 2;
      }
    }

    final siniflar = kademe == 0 ? [1, 2, 3, 4] : (kademe == 1 ? [5, 6, 7, 8] : [9, 10, 11, 12]);
    int secilecekSinif = siniflar.first;

    if (classes.isNotEmpty) {
      final kademedekiSiniflar = classes
          .map((c) => int.tryParse(RegExp(r'\d+').firstMatch(c.name)?.group(0) ?? ''))
          .whereType<int>()
          .where((g) => siniflar.contains(g))
          .toList()
        ..sort();
      if (kademedekiSiniflar.isNotEmpty) {
        secilecekSinif = kademedekiSiniflar.first;
      }
    }

    setState(() {
      _kademeIndex = kademe;
      _seciliSinif = secilecekSinif;
    });

    _dersleriYukle();
  }

  List<int> get _kademeSiniflari {
    switch (_kademeIndex) {
      case 0:
        return [1, 2, 3, 4];
      case 1:
        return [5, 6, 7, 8];
      case 2:
      default:
        return [9, 10, 11, 12];
    }
  }

  void _kademeDegisti(int index) {
    if (_kademeIndex == index) return;
    setState(() {
      _kademeIndex = index;
      _seciliSinif = _kademeSiniflari.first;
      _seciliDersKodu = null;
      _seciliDersAdi = null;
      _seciliYayinci = null;
      _haftalikPlanlar = [];
      _acikKartHaftalari.clear();
    });
    _dersleriYukle();
  }

  void _sinifDegisti(int sinif) {
    if (_seciliSinif == sinif) return;
    setState(() {
      _seciliSinif = sinif;
      _seciliDersKodu = null;
      _seciliDersAdi = null;
      _seciliYayinci = null;
      _haftalikPlanlar = [];
      _acikKartHaftalari.clear();
    });
    _dersleriYukle();
  }

  /// Dropdown öğe anahtarı.
  ///
  /// Yalnızca `subject_code` kullanılamaz: lisede aynı ders üç okul
  /// türüyle (Anadolu / Fen / Sosyal Bilimler Lisesi) ayrı satır olarak
  /// geliyor. 30 (sınıf, ders) çiftinde birden çok yayıncı var ve
  /// `DropdownButton` aynı value'dan iki tane görünce assertion ile
  /// çöküyordu — lise öğretmeni ekranı hiç açamıyordu.
  String _dersAnahtari(Map<String, dynamic> ders) =>
      '${ders['subject_code']}|${ders['publisher'] ?? ''}';

  String? get _seciliAnahtar =>
      _seciliDersKodu == null ? null : '$_seciliDersKodu|${_seciliYayinci ?? ''}';

  Future<void> _dersleriYukle() async {
    setState(() => _derslerYukleniyor = true);
    try {
      await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
      final dersler = await DatabaseHelper.instance.mevcutDersleriGetir(_seciliSinif);
      if (!mounted) return;

      setState(() {
        _mevcutDersler = dersler;
        if (dersler.isNotEmpty) {
          // Öğretmenin branşıyla eşleşen dersi otomatik seç (Auto-Focus)
          final teacher = ref.read(teacherProfileProvider);
          final brans = teacher.branch.trim().toLowerCase();

          Map<String, dynamic>? eslesenDers;
          if (brans.isNotEmpty) {
            for (final d in dersler) {
              final dAdi = (d['subject_name'] ?? '').toString().toLowerCase();
              final dKod = (d['subject_code'] ?? '').toString().toLowerCase();
              if (dAdi.contains(brans) ||
                  brans.contains(dAdi) ||
                  (brans.contains('bilişim') && (dAdi.contains('bilişim') || dKod.contains('bty') || dKod.contains('bilisim'))) ||
                  (brans.contains('türkçe') && (dAdi.contains('türkçe') || dKod.contains('turkce') || dKod.contains('trk'))) ||
                  (brans.contains('matematik') && (dAdi.contains('matematik') || dKod.contains('mat'))) ||
                  (brans.contains('fen') && (dAdi.contains('fen') || dKod.contains('fen'))) ||
                  (brans.contains('ingilizce') && (dAdi.contains('ingilizce') || dKod.contains('ing'))) ||
                  (brans.contains('sosyal') && (dAdi.contains('sosyal') || dKod.contains('sos'))) ||
                  (brans.contains('din') && (dAdi.contains('din') || dKod.contains('dkab'))) ||
                  (brans.contains('beden') && (dAdi.contains('beden') || dKod.contains('beden'))) ||
                  (brans.contains('müzik') && (dAdi.contains('müzik') || dKod.contains('muzik'))) ||
                  (brans.contains('görsel') && (dAdi.contains('görsel') || dKod.contains('gorsel')))) {
                eslesenDers = d;
                break;
              }
            }
          }

          final secilenDers = eslesenDers ?? dersler.first;
          _seciliDersKodu = secilenDers['subject_code'] as String?;
          _seciliDersAdi = secilenDers['subject_name'] as String?;
          _seciliYayinci = secilenDers['publisher'] as String?;
        } else {
          _seciliDersKodu = null;
          _seciliDersAdi = null;
          _seciliYayinci = null;
        }
        _derslerYukleniyor = false;
      });

      if (_seciliDersKodu != null) {
        _tumHaftalariYukle();
      }
    } catch (e, st) {
      debugPrint('Dersler yuklenirken hata: $e\n$st');
      if (mounted) {
        setState(() => _derslerYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders listesi yüklenirken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
          ),
        );
      }
    }
  }

  Future<void> _tumHaftalariYukle() async {
    if (_seciliDersKodu == null) return;
    setState(() => _planlarYukleniyor = true);

    try {
      final satirlar = await DatabaseHelper.instance.kazanimlariGetir(
        gradeLevel: _seciliSinif,
        subjectCode: _seciliDersKodu,
        publisher: _seciliYayinci,
      );

      if (!mounted) return;

      // 1. Ders haftalarını süz — ortak modül (bkz. PlanWeekBuilder).
      final dersSatirlari = PlanWeekBuilder.dersHaftalari(satirlar);

      // 2. Her satır KENDİ ders haftası numarasıyla dönüştürülür.
      final List<Map<String, dynamic>> planListesi = [];
      for (final satir in dersSatirlari) {
        // `ayrintili: true` günlük planın öğretme-öğrenme sürecini de
        // üretir (dikkat çekme, güdüleme, etkinlikler, farklılaştırma).
        planListesi.add(PlanWeekBuilder.haftaPlani(
          satir: satir,
          haftaNo: PlanWeekBuilder.dersHaftaNo(satir),
          sinif: _seciliSinif,
          dersKodu: _seciliDersKodu ?? '',
          dersAdi: _seciliDersAdi,
          takvimdenTarih: AppDateFormatter.getWeekDateRangeText,
          ayrintili: true,
        ));
      }

      // 3. Son ders haftası 35 ise yıl sonu değerlendirme haftası eklenir.
      if (planListesi.isNotEmpty) {
        final sonHafta = PlanWeekBuilder.dersHaftaNo(dersSatirlari.last);
        if (sonHafta == 35) {
          planListesi.add(PlanWeekBuilder.yilSonuHaftasi(
            haftaNo: 36,
            sinif: _seciliSinif,
            dersKodu: _seciliDersKodu ?? '',
            dersAdi: _seciliDersAdi ?? 'Ders',
            takvimdenTarih: AppDateFormatter.getWeekDateRangeText,
            ayrintili: true,
          ));
        }
      }

      setState(() {
        _haftalikPlanlar = planListesi;
        _planlarYukleniyor = false;
      });
    } catch (e, st) {
      debugPrint('Haftalar yuklenirken hata: $e\n$st');
      if (mounted) {
        setState(() => _planlarYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Haftalık planlar yüklenirken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
          ),
        );
      }
    }
  }



  Future<void> _tekHaftaPdfIndir(Map<String, dynamic> planData, int haftaNo) async {
    final teacher = ref.read(teacherProfileProvider);
    final academicYear = '${AppDateFormatter.academicYearLabel()} Eğitim-Öğretim Yılı';
    final ders = planData['meta']?['ders'] ?? 'Ders';
    final sinif = planData['meta']?['sinif'] ?? '';

    try {
      await PdfPreviewScreen.open(
        context,
        title: '$ders - $haftaNo. Hafta Planı',
        subtitle: '$sinif • $academicYear',
        fileName: '${ders}_${sinif}_Hafta_$haftaNo.pdf',
        documentBuilder: (format) => DailyPlanPdfGenerator.generate(
          planData: planData,
          teacher: teacher,
          academicYear: academicYear,
          format: format,
        ),
      );
    } catch (e, st) {
      debugPrint('Tekil PDF acilirken hata: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$ders ($haftaNo. Hafta) plan belgesi hazırlanırken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _topluPdfIndir() async {
    if (_haftalikPlanlar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İndirilecek plan verisi bulunamadı. Lütfen önce bir branş seçiniz.'),
        ),
      );
      return;
    }

    final teacher = ref.read(teacherProfileProvider);
    final academicYear = '${AppDateFormatter.academicYearLabel()} Eğitim-Öğretim Yılı';
    final dersAdi = _seciliDersAdi ?? 'Ders';
    final sinifAdi = '$_seciliSinif. Sınıf';

    try {
      await PdfPreviewScreen.open(
        context,
        title: '$dersAdi Günlük Planlar Dosyası',
        subtitle: '$sinifAdi • 1 - ${_haftalikPlanlar.length}. Haftalar • $academicYear',
        fileName: '${dersAdi}_${sinifAdi}_Tum_Haftalar_Plan_Dosyasi.pdf',
        documentBuilder: (format) => DailyPlanPdfGenerator.generateFullYearPdf(
          allWeeksPlanData: _haftalikPlanlar,
          teacher: teacher,
          ders: dersAdi,
          sinif: sinifAdi,
          academicYear: academicYear,
          format: format,
        ),
      );
    } catch (e, st) {
      debugPrint('Toplu PDF acilirken hata: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$dersAdi toplu plan dosyası oluşturulurken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacher = ref.watch(teacherProfileProvider);
    final academicYear = '${AppDateFormatter.academicYearLabel()} Eğitim-Öğretim Yılı';

    final okulAdi = teacher.schoolName.trim().isNotEmpty
        ? teacher.schoolName.trim().toUpperCase()
        : 'T.C. MİLLÎ EĞİTİM BAKANLIĞI';
    final ogretmenAdi = teacher.fullName.trim().isNotEmpty
        ? teacher.fullName.trim()
        : 'Ders Öğretmeni';

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Günlük Planlar (TYMM)',
      ),
      body: Column(
        children: [
          // 1. KADEME, SINIF VE BRANŞ SEÇİCİ
          _ustSeciciPanel(theme),

          // 2. OTOMATİK BİLGİ ŞERİDİ (Okul, Öğretmen, Yıl)
          _otomatikBilgiSeridi(theme, okulAdi, ogretmenAdi, academicYear),

          // 3. TOPLU İNDİR KARTI VE HAFTALAR LİSTESİ
          Expanded(
            child: _planlarYukleniyor || _derslerYukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _haftalikPlanlar.isEmpty
                    ? _bosDurumMesaji(theme)
                    : _haftalarListesi(theme),
          ),
        ],
      ),
    );
  }

  Widget _ustSeciciPanel(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KADEME SEÇİCİ
          Row(
            children: [
              _kademeButon(0, 'İlkokul (1-4)', isDark),
              const SizedBox(width: 8),
              _kademeButon(1, 'Ortaokul (5-8)', isDark),
              const SizedBox(width: 8),
              _kademeButon(2, 'Lise (9-12)', isDark),
            ],
          ),
          const SizedBox(height: 10),

          // SINIF VE BRANŞ SEÇİCİ
          Row(
            children: [
              // SINIF DROPDOWN
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _seciliSinif,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF252A34) : Colors.white,
                      items: _kademeSiniflari.map((s) {
                        return DropdownMenuItem<int>(
                          value: s,
                          child: Text(
                            '$s. Sınıf',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) _sinifDegisti(v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // BRANŞ / DERS DROPDOWN
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _seciliAnahtar,
                      isExpanded: true,
                      hint: const Text('Branş Seçin', style: TextStyle(fontSize: 13)),
                      dropdownColor: isDark ? const Color(0xFF252A34) : Colors.white,
                      items: _mevcutDersler.map((d) {
                        final ad = d['subject_name'] as String? ?? 'Ders';
                        final yayin = d['publisher'] as String? ?? '';
                        final gorunen = yayin.isNotEmpty ? '$ad ($yayin)' : ad;
                        return DropdownMenuItem<String>(
                          value: _dersAnahtari(d),
                          child: Text(
                            gorunen,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final bulunan = _mevcutDersler.firstWhere(
                          (element) => _dersAnahtari(element) == v,
                          orElse: () => _mevcutDersler.first,
                        );
                        setState(() {
                          // `v` bilesik anahtar ("TURKCE|Fen Lisesi"), ders
                          // kodu DEGIL. Dogrudan atanirsa sorgu
                          // `subject_code = 'TURKCE|'` olur ve hicbir satir
                          // donmez; ekran "plan bulunamadi" der. Cihazda
                          // gozlendi.
                          _seciliDersKodu = bulunan['subject_code'] as String?;
                          _seciliDersAdi = bulunan['subject_name'] as String?;
                          _seciliYayinci = bulunan['publisher'] as String?;
                          _haftalikPlanlar = [];
                          _acikKartHaftalari.clear();
                        });
                        _tumHaftalariYukle();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kademeButon(int index, String baslik, bool isDark) {
    final secili = _kademeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _kademeDegisti(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: secili ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: secili
                  ? AppColors.primary
                  : (isDark ? Colors.white24 : Colors.grey.shade300),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              baslik,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: secili ? FontWeight.bold : FontWeight.w500,
                color: secili
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _otomatikBilgiSeridi(
    ThemeData theme,
    String okulAdi,
    String ogretmenAdi,
    String academicYear,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF16191F) : const Color(0xFFF3F4F6),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.purple.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$okulAdi  •  $ogretmenAdi  •  $academicYear',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _haftalarListesi(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _haftalikPlanlar.length + 1, // +1: En üstteki Toplu İndir Kartı
      itemBuilder: (context, index) {
        if (index == 0) {
          return _topluIndirBanner(theme);
        }
        final haftaIndex = index - 1;
        final plan = _haftalikPlanlar[haftaIndex];
        final haftaNo = haftaIndex + 1;
        return _haftaPlaniKarti(theme, plan, haftaNo);
      },
    );
  }

  Widget _topluIndirBanner(ThemeData theme) {
    final dersAdi = _seciliDersAdi ?? 'Ders';
    final sinifAdi = '$_seciliSinif. Sınıf';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade700,
            Colors.indigo.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_zip_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tüm ${_haftalikPlanlar.length} Haftayı Toplu İndir',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dersAdi ($sinifAdi) • Taslak Kapak ve ${_haftalikPlanlar.length} Hafta Kitapçığı',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _topluPdfIndir,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded, size: 16),
                SizedBox(width: 4),
                Text('İndir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _haftaPlaniKarti(ThemeData theme, Map<String, dynamic> plan, int haftaNo) {
    final isDark = theme.brightness == Brightness.dark;
    final meta = plan['meta'] as Map<String, dynamic>? ?? {};
    final kazanimlarVeSurec = plan['kazanimlar_ve_surec'] as Map<String, dynamic>? ?? {};
    final ozelAlanlar = plan['ozel_alanlar'] as Map<String, dynamic>? ?? {};
    final ogretimSureci = plan['ogretim_sureci'] as Map<String, dynamic>? ?? {};
    final farklilastirma = ogretimSureci['farklilastirma'] as Map<String, dynamic>? ?? {};

    final temaUnite = meta['tema_unite']?.toString() ?? '$haftaNo. Hafta';
    final tarihAraligi = meta['tarih_araligi']?.toString() ?? AppDateFormatter.getWeekDateRangeText(haftaNo);

    final ciktilar = (kazanimlarVeSurec['ogrenme_ciktilari'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final ilkKazanim = ciktilar.isNotEmpty ? ciktilar.first : 'Haftalık ders işlenişi';

    final acikMi = _acikKartHaftalari.contains(haftaNo);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: acikMi
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // KART BAŞLIĞI & TEK TIKLA İNDİR BUTONU
          InkWell(
            onTap: () {
              setState(() {
                if (acikMi) {
                  _acikKartHaftalari.remove(haftaNo);
                } else {
                  _acikKartHaftalari.add(haftaNo);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // HAFTA ROZETİ
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$haftaNo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.purple.shade300 : AppColors.primary,
                            ),
                          ),
                          Text(
                            'Hafta',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: isDark ? Colors.purple.shade200 : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // TEMA VE KAZANIM METNİ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                temaUnite,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tarihAraligi,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ilkKazanim,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade300 : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // TEK TIKLA İNDİRME BUTONU
                  FilledButton.tonal(
                    onPressed: () => _tekHaftaPdfIndir(plan, haftaNo),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 16),
                        SizedBox(width: 4),
                        Text('İndir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // GENİŞLETİLEBİLİR PLAN DETAY ALANI
          if (acikMi) ...[
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detayBaslik('Öğrenme Çıktıları ve Süreç:', isDark),
                  for (final c in ciktilar)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Text(
                        '• $c',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (ozelAlanlar['alan_becerileri']?.toString().isNotEmpty == true) ...[
                    _detayBaslik('Alan Becerileri:', isDark),
                    Text(
                      ozelAlanlar['alan_becerileri'].toString(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (ozelAlanlar['degerler']?.toString().isNotEmpty == true) ...[
                    _detayBaslik('Değerler Çerçevesi:', isDark),
                    Text(
                      ozelAlanlar['degerler'].toString(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (farklilastirma['zenginlestirme']?.toString().isNotEmpty == true) ...[
                    _detayBaslik('Zenginleştirme (Farklılaştırma):', isDark),
                    Text(
                      farklilastirma['zenginlestirme'].toString(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (farklilastirma['destekleme']?.toString().isNotEmpty == true) ...[
                    _detayBaslik('Destekleme (Farklılaştırma):', isDark),
                    Text(
                      farklilastirma['destekleme'].toString(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detayBaslik(String metin, bool isDark) {
    return Text(
      metin,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.purple.shade300 : AppColors.primary,
      ),
    );
  }

  Widget _bosDurumMesaji(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 48, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Bu sınıf ve branş için plan bulunamadı.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.grey.shade200 : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            // Nedenini yaz: eskiden bu durumda 36 haftalık uydurma plan
            // sessizce üretiliyordu ve öğretmen onu hazır sanıyordu.
            Text(
              _seciliDersAdi == null
                  ? 'Lütfen yukarıdan bir branş veya sınıf seçiniz.'
                  : PlanWeekBuilder.planYokGerekcesi(_seciliDersAdi!, _seciliSinif),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _dersleriYukle,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Yeniden Dene', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

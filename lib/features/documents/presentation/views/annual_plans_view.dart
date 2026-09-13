import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../outcomes/data/models/curriculum_outcome_model.dart';
import '../../utils/annual_plan_pdf_generator.dart';
import '../../utils/plan_week_builder.dart';

/// SınıfCepte - MEB TYMM Ünitelendirilmiş Yıllık Planlar Ekranı
///
/// Kademe -> Sınıf -> Branş seçimi ile MEB Türkiye Yüzyılı Maarif Modeli
/// müfredatına tam uyumlu 36 haftalık A4 Yatay Resmî Yıllık Çerçeve Planı
/// PDF çıktısı üreten ve haftalık kazanım dağılımını gösteren modül.
class AnnualPlansView extends ConsumerStatefulWidget {
  const AnnualPlansView({super.key});

  @override
  ConsumerState<AnnualPlansView> createState() => _AnnualPlansViewState();
}

class _AnnualPlansViewState extends ConsumerState<AnnualPlansView> {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ogretmenProfiliyleOdaklan();
    });
  }

  /// Kullanıcı kolaylığı: Girişte öğretmenin kayıtlı okul düzeyine ve branşına
  /// göre otomatik odaklanır.
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

      // Tatil süzgeci ve hafta numaralama ortak modülde; iki ekran da
      // aynı kuralı kullanır (bkz. PlanWeekBuilder).
      final dersSatirlari = PlanWeekBuilder.dersHaftalari(satirlar);

      final List<Map<String, dynamic>> planListesi = [];
      for (final satir in dersSatirlari) {
        planListesi.add(_donustur(satir, PlanWeekBuilder.dersHaftaNo(satir)));
      }

      // Yıl sonu değerlendirme haftası: son ders haftası 35 ise 36. hafta
      // eklenir. Önceden `length == 35` şartına bakılıyordu; tatil
      // süzgeci hafta düşürdüğünde (28, 33 gibi) bu şart tutmuyor ama
      // ekran yine "36 Hafta Tam Akış" diyordu.
      if (planListesi.isNotEmpty) {
        final sonHafta = PlanWeekBuilder.dersHaftaNo(dersSatirlari.last);
        if (sonHafta == 35) {
          planListesi.add(_varsayilanYilSonuHaftaPlani(36));
        }
      }

      setState(() {
        _haftalikPlanlar = planListesi;
        _planlarYukleniyor = false;
      });
    } catch (e, st) {
      debugPrint('Yıllık plan haftaları yuklenirken hata: $e\n$st');
      if (mounted) {
        setState(() => _planlarYukleniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan verileri yüklenirken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _donustur(Map<String, dynamic> m, int haftaNo) {
    final dersAdi = _seciliDersAdi ?? m['subject_name']?.toString() ?? 'Ders';
    final rawUnitTitle = (m['unit_title'] ?? '').toString().trim();
    final rawTopicTitle = (m['topic_title'] ?? '').toString().trim();
    final rawDesc = (m['outcome_description'] ?? '').toString().trim();

    final kazanimKodu = (m['outcome_code'] ?? '').toString().trim();
    final outcomeParts = OutcomePart.listFromDbText(m['outcome_parts'] as String?);

    final bool hasRealContent = outcomeParts.isNotEmpty ||
        (kazanimKodu.isNotEmpty && kazanimKodu != 'TATIL') ||
        (rawDesc.isNotEmpty && !rawDesc.toLowerCase().contains('planlanmamış') && !rawDesc.toLowerCase().contains('kazanım belirtilmemiş'));

    final bool isTrulyUnplanned = !hasRealContent &&
        (rawUnitTitle.toLowerCase().contains('planlanmamış') ||
         rawTopicTitle.toLowerCase().contains('planlanmamış') ||
         rawDesc.toLowerCase().contains('planlanmamış') ||
         rawUnitTitle.toLowerCase().contains('okul temelli') ||
         rawTopicTitle.toLowerCase().contains('okul temelli'));

    final String cleanUnit = rawUnitTitle
        .replaceAll(RegExp(r'OKUL TEMELLİ PLANLAMA\*?\s*[-/]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Planlanmamış Hafta', caseSensitive: false), '')
        .trim();
    final String cleanTopic = rawTopicTitle
        .replaceAll(RegExp(r'OKUL TEMELLİ PLANLAMA\*?\s*[-/]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Planlanmamış Hafta', caseSensitive: false), '')
        .trim();

    final String fullTema;
    if (cleanUnit.isNotEmpty && cleanTopic.isNotEmpty) {
      if (cleanUnit.toLowerCase() == cleanTopic.toLowerCase()) {
        fullTema = cleanUnit;
      } else {
        fullTema = '$cleanUnit - $cleanTopic';
      }
    } else if (cleanTopic.isNotEmpty) {
      fullTema = cleanTopic;
    } else if (cleanUnit.isNotEmpty) {
      fullTema = cleanUnit;
    } else {
      fullTema = haftaNo >= 35
          ? 'Yıl Sonu Genel Değerlendirme ve Pekiştirme'
          : 'Kazanım Pekiştirme ve Ara Değerlendirme';
    }

    final List<String> ciktilar = [];
    final List<String> surecListesi = [];

    if (outcomeParts.isNotEmpty) {
      for (final part in outcomeParts) {
        final pCode = part.code?.trim() ?? '';
        final pText = part.text.trim();
        if (pText.isNotEmpty) {
          if (pCode.isNotEmpty && !pText.startsWith(pCode)) {
            ciktilar.add('$pCode. $pText');
          } else {
            ciktilar.add(pText);
          }
        }
        for (final step in part.steps) {
          if (step.trim().isNotEmpty && !surecListesi.contains(step.trim())) {
            surecListesi.add(step.trim());
          }
        }
      }
    } else if (rawDesc.isNotEmpty && !rawDesc.toLowerCase().contains('planlanmamış') && !rawDesc.toLowerCase().contains('kazanım belirtilmemiş')) {
      ciktilar.add(rawDesc);
    } else if (isTrulyUnplanned) {
      ciktilar.add(
        'MEB resmî çerçeve planı uyarınca; zümre öğretmenler kurulunca ders kapsamında kararlaştırılan kazanım pekiştirme, araştırma ve gözlem, proje çalışmaları ve telafi/pekiştirme uygulamaları yürütülür.',
      );
      surecListesi.add('a) Zümre öğretmenler kurulu kararları doğrultusunda belirlenen araştırma, gözlem ve proje hedefleri öğrencilerle paylaşılır.');
      surecListesi.add('b) Önceki ünitelerde yer alan temel kavram ve beceri eksiklikleri tespit edilerek kavram pekiştirme etkinlikleri yürütülür.');
      surecListesi.add('c) Çoklu ortam materyalleri, çalışma yaprakları ve etkileşimli tahta uygulamalarıyla pekiştirme çalışmaları tamamlanır.');
    }

    if (!isTrulyUnplanned && ciktilar.isEmpty) {
      final stepRegex = RegExp(r'([a-z]\)\s*[^a-z\)]+)');
      final stepMatches = stepRegex.allMatches(rawDesc);
      if (stepMatches.isNotEmpty) {
        for (final match in stepMatches) {
          final s = match.group(1)?.trim();
          if (s != null && s.isNotEmpty) surecListesi.add(s);
        }
        final mainText = rawDesc.replaceAll(stepRegex, '').trim().replaceAll(RegExp(r'\|\s*$'), '').trim();
        if (kazanimKodu.isNotEmpty && !mainText.startsWith(kazanimKodu)) {
          ciktilar.add('$kazanimKodu. $mainText');
        } else {
          ciktilar.add(mainText.isNotEmpty ? mainText : '$dersAdi $haftaNo. Hafta Öğrenme Çıktısı');
        }
      } else {
        if (kazanimKodu.isNotEmpty && !rawDesc.startsWith(kazanimKodu)) {
          ciktilar.add('$kazanimKodu. $rawDesc');
        } else {
          ciktilar.add(rawDesc.isNotEmpty ? rawDesc : '$dersAdi $haftaNo. Hafta Öğrenme Çıktısı');
        }
      }
    }

    final rawSkills = (m['maarif_skills'] ?? '').toString().trim();
    final rawValues = (m['maarif_values'] ?? '').toString().trim();

    String sdb = '';
    String ob = '';
    String abKb = '';

    if (rawSkills.isNotEmpty) {
      final sdbList = <String>[];
      final obList = <String>[];
      final otherList = <String>[];

      final tokens = rawSkills.split(RegExp(r',\s*|\s+(?=(?:SDB|OB|AB|KB|FBAB)\d)'));
      for (final t in tokens) {
        final token = t.trim();
        if (token.isEmpty) continue;
        if (token.startsWith('SDB')) {
          sdbList.add(token);
        } else if (token.startsWith('OB')) {
          obList.add(token);
        } else {
          otherList.add(token);
        }
      }

      sdb = sdbList.join(', ');
      ob = obList.join(', ');
      abKb = otherList.join(', ');
    }

    if (sdb.isEmpty) {
      sdb = 'SDB1.1. Kendini Tanıma, SDB1.2. Kendini Düzenleme, SDB2.1. İletişim, SDB2.2. İş Birliği';
    }
    if (ob.isEmpty) {
      ob = 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık, OB4. Görsel Okuryazarlık';
    }
    if (abKb.isEmpty) {
      abKb = 'Alan Becerileri ve Bilimsel Sorgulama, KB2.4. Çözümleme';
    }

    final String degerler = rawValues.isNotEmpty
        ? rawValues
        : 'D3. Çalışkanlık, D4. Dostluk, D14. Saygı, D16. Sorumluluk';

    // Tarih, satırın TAKVİM haftasından gelir; ders haftasından değil.
    // Yeniden numaralama yüzünden ilk tatilden sonra her tarih kayıyordu.
    final tarihAraligi = PlanWeekBuilder.tarihAraligi(
      m,
      AppDateFormatter.getWeekDateRangeText,
    );

    return {
      'meta': {
        'ders': dersAdi,
        'sinif': '$_seciliSinif. Sınıf',
        'hafta': '$haftaNo. Hafta',
        'tarih_araligi': tarihAraligi,
        'ders_saati': PlanWeekBuilder.dersSaatiMetni(
          _seciliSinif,
          _seciliDersKodu ?? '',
        ),
        'tema_unite': fullTema,
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': ciktilar.isNotEmpty ? ciktilar : ['$dersAdi $haftaNo. Hafta Öğrenme Çıktısı'],
        'surec_bilesenleri': surecListesi,
      },
      'ozel_alanlar': {
        'belirli_gun_ve_haftalar': isTrulyUnplanned
            ? 'Kazanım Pekiştirme ve Zümre Çalışmaları'
            : (m['specific_day_week']?.toString() ?? ''),
        'alan_becerileri': abKb,
        'kavramsal_beceriler': 'Kavramsal Çözümleme ve Bilgi Toplama',
        'sosyal_duygusal_ogrenme_becerileri': sdb,
        'okuryazarlik_becerileri': ob,
        'degerler': degerler,
        'disiplinler_arasi_iliskiler': 'Türkçe, Matematik, Fen Bilimleri',
      },
      'ogretim_sureci': {
        'etkinlikler': [
          'Dersin başında hazırbulunuşluk yoklaması ve kavramsal soru-cevap yürütülür.',
          'Etkileşimli tahta ve ders kitabı eşliğinde temel kavramlar açıklanır.',
          'Kazanım pekiştirme ve değerlendirme etkinlikleri tamamlanır.',
        ],
      },
    };
  }

  Map<String, dynamic> _varsayilanYilSonuHaftaPlani(int haftaNo) {
    final dersAdi = _seciliDersAdi ?? 'Ders';
    final tarihAraligi = AppDateFormatter.getWeekDateRangeText(haftaNo);

    return {
      'meta': {
        'ders': dersAdi,
        'sinif': '$_seciliSinif. Sınıf',
        'hafta': '$haftaNo. Hafta',
        'tarih_araligi': tarihAraligi,
        'ders_saati': '2',
        'tema_unite': 'Yıl Sonu Genel Değerlendirme ve Pekiştirme',
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': [
          '$dersAdi dersi yıl boyunca işlenen temel kavram, beceri ve öğrenme çıktılarının genel tekrarı ve pekiştirilmesi sağlanır.',
        ],
        'surec_bilesenleri': [
          'a) Yıl boyunca işlenen ünitelerdeki temel kazanım ve kavram haritaları incelenir.',
          'b) Öğrencilerin eksik kaldığı konular belirlenerek telafi ve soru-cevap etkinlikleri yürütülür.',
          'c) Yıl sonu ürünleri, portfolyolar ve öğrenci çalışmaları değerlendirilir.',
        ],
      },
      'ozel_alanlar': {
        'belirli_gun_ve_haftalar': 'Yıl Sonu Faaliyet Haftası',
        'alan_becerileri': 'Genel Tekrar ve Çözümleme',
        'kavramsal_beceriler': 'Özetleme ve Değerlendirme',
        'sosyal_duygusal_ogrenme_becerileri': 'SDB1.2. Kendini Düzenleme, SDB2.2. İş Birliği',
        'okuryazarlik_becerileri': 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık',
        'degerler': 'D3. Çalışkanlık, D16. Sorumluluk',
        'disiplinler_arasi_iliskiler': 'Türkçe, Sosyal Bilgiler, Fen Bilimleri',
      },
      'ogretim_sureci': {},
    };
  }

  Future<void> _yillikPlanPdfIndir() async {
    if (_haftalikPlanlar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yıllık plan verisi bulunamadı. Lütfen önce bir branş seçiniz.'),
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
        title: '$dersAdi Yıllık Çerçeve Planı',
        subtitle: '$sinifAdi • ${_haftalikPlanlar.length} Hafta Çizelge • $academicYear',
        fileName: '${dersAdi}_${sinifAdi}_Yillik_Cerceve_Plani.pdf',
        documentBuilder: (format) => AnnualPlanPdfGenerator.generate(
          allWeeksPlanData: _haftalikPlanlar,
          teacher: teacher,
          ders: dersAdi,
          sinif: sinifAdi,
          academicYear: academicYear,
          format: format,
        ),
      );
    } catch (e, st) {
      debugPrint('Yıllık Plan PDF acilirken hata: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$dersAdi yıllık plan belgesi hazırlanırken bir sorun oluştu. Lütfen tekrar deneyiniz.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Yıllık Planlar',
        subtitle: 'MEB TYMM Resmî Yıllık Çerçeve Planı',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Kademe & Sınıf & Branş Seçim Bölümü
            _ustSecimBileseni(isDark),

            // 2. Yıllık Plan Ana İçerik Alanı
            Expanded(
              child: _derslerYukleniyor || _planlarYukleniyor
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : _seciliDersKodu == null || _haftalikPlanlar.isEmpty
                      // Plan verisi yoksa uydurma plan üretmek yerine
                      // gerekçe gösterilir.
                      ? _dersSecilmediUyarisi(isDark)
                      : _icerikListesi(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ustSecimBileseni(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kademe Segmented Toggle
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _kademeButonu(0, 'İlkokul (1-4)', isDark),
                _kademeButonu(1, 'Ortaokul (5-8)', isDark),
                _kademeButonu(2, 'Lise (9-12)', isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sınıf Seçim Çipleri & Ders Seçim Dropdown
          Row(
            children: [
              // Sınıf Çipleri
              Row(
                children: _kademeSiniflari.map((sinif) {
                  final secili = _seciliSinif == sinif;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _sinifDegisti(sinif),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: secili
                              ? AppColors.primary
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$sinif. Sınıf',
                          style: AppFonts.outfit(
                            fontSize: 12,
                            fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
                            color: secili
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(width: 8),

              // Branş Dropdown
              Expanded(
                child: _mevcutDersler.isEmpty
                    ? Text(
                        'Bu sınıfta ders bulunamadı',
                        style: AppFonts.outfit(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _seciliAnahtar,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: AppFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            items: _mevcutDersler.map((d) {
                              final ad = d['subject_name']?.toString() ?? '';
                              final yayinci = d['publisher']?.toString() ?? '';
                              final label = yayinci.isNotEmpty && yayinci != 'MEB'
                                  ? '$ad ($yayinci)'
                                  : ad;
                              return DropdownMenuItem<String>(
                                value: _dersAnahtari(d),
                                child: Text(label, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (yeniAnahtar) {
                              if (yeniAnahtar == null || yeniAnahtar == _seciliAnahtar) return;
                              final ders = _mevcutDersler
                                  .firstWhere((d) => _dersAnahtari(d) == yeniAnahtar);
                              setState(() {
                                _seciliDersKodu = ders['subject_code'] as String?;
                                _seciliDersAdi = ders['subject_name'] as String?;
                                _seciliYayinci = ders['publisher'] as String?;
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

  Widget _kademeButonu(int index, String baslik, bool isDark) {
    final secili = _kademeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _kademeDegisti(index),
        child: Container(
          decoration: BoxDecoration(
            color: secili
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: secili
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            baslik,
            style: AppFonts.outfit(
              fontSize: 11.5,
              fontWeight: secili ? FontWeight.w700 : FontWeight.w500,
              color: secili
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _icerikListesi(bool isDark) {
    final dersAdi = _seciliDersAdi ?? 'Ders';
    final sinifAdi = '$_seciliSinif. Sınıf';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 1. Zirve Aksiyon Kartı (A4 Yatay Resmî Yıllık Plan İndir)
        _zirveAksiyonKarti(isDark, dersAdi, sinifAdi),

        const SizedBox(height: 20),

        // 2. Hafta Listesi Başlığı
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Gerçek hafta sayısı yazılır. Sabit "36" yazmak,
                    // tatil süzgeci hafta düşürdüğünde yalan oluyordu.
                    '${_haftalikPlanlar.length} Haftalık Müfredat Dağılımı',
                    style: AppFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A4 Yatay Tabloya aktarılacak resmî haftalık ünite ve kazanım akışı',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_haftalikPlanlar.length} Hafta',
                style: AppFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 3. Haftalık Kartlar
        for (int i = 0; i < _haftalikPlanlar.length; i++)
          _haftaOnizlemeKarti(isDark, _haftalikPlanlar[i], i + 1),
      ],
    );
  }

  Widget _zirveAksiyonKarti(bool isDark, String dersAdi, String sinifAdi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dersAdi - $sinifAdi',
                      style: AppFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'MEB Türkiye Yüzyılı Maarif Modeli Ünitelendirilmiş Yıllık Çerçeve Planı',
                      style: AppFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Özellik Rozetleri
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ozellikRozeti('A4 Yatay Tablo', Icons.view_compact_rounded, isDark),
              _ozellikRozeti(
                '${_haftalikPlanlar.length} Hafta',
                Icons.calendar_today_rounded,
                isDark,
              ),
              // Yöntem, araç ve ölçme alanlarının bir kısmı şablondur;
              // "Resmî Onay" ibaresi öğretmeni yanıltıyordu.
              _ozellikRozeti('Taslak — Zümre Onayı Gerekir', Icons.edit_note_rounded, isDark),
              _ozellikRozeti('Beceriler & Süreçler', Icons.psychology_rounded, isDark),
            ],
          ),

          const SizedBox(height: 16),

          // Ana İndir / Önizle Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _yillikPlanPdfIndir,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                'Yıllık Planı Önizle ve İndir (A4 Yatay PDF)',
                style: AppFonts.outfit(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ozellikRozeti(String metin, IconData ikon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: 13,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
          const SizedBox(width: 4),
          Text(
            metin,
            style: AppFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _haftaOnizlemeKarti(bool isDark, Map<String, dynamic> plan, int haftaNo) {
    final meta = plan['meta'] as Map<String, dynamic>? ?? {};
    final kazanimlarVeSurec = plan['kazanimlar_ve_surec'] as Map<String, dynamic>? ?? {};
    final ozelAlanlar = plan['ozel_alanlar'] as Map<String, dynamic>? ?? {};

    final tema = meta['tema_unite']?.toString() ?? '$haftaNo. Hafta';
    final tarihAraligi = meta['tarih_araligi']?.toString() ?? '';
    final dersSaati = meta['ders_saati']?.toString() ?? '2';
    final belirliGun = ozelAlanlar['belirli_gun_ve_haftalar']?.toString().trim() ?? '';

    final ciktilar = (kazanimlarVeSurec['ogrenme_ciktilari'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Hafta No + Tarih Aralığı + Saat Rozeti
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$haftaNo. Hafta',
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (tarihAraligi.isNotEmpty)
                Expanded(
                  child: Text(
                    tarihAraligi,
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$dersSaati Saat',
                  style: AppFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tema / Ünite Başlığı
          Text(
            tema,
            style: AppFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),

          if (ciktilar.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ciktilar.first,
              style: AppFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (belirliGun.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 14,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    belirliGun,
                    style: AppFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dersSecilmediUyarisi(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'Seçilen kriterlere uygun ders planı bulunamadı',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            if (_seciliDersAdi != null) ...[
              const SizedBox(height: 8),
              // Nedenini yaz: eskiden bu durumda 36 haftalık uydurma plan
              // sessizce üretiliyor, öğretmen onu hazır sanıyordu.
              Text(
                PlanWeekBuilder.planYokGerekcesi(_seciliDersAdi!, _seciliSinif),
                style: AppFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

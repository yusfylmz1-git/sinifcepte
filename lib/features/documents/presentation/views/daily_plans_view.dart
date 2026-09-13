import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../outcomes/data/models/curriculum_outcome_model.dart';
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
        planListesi.add(_donustur(satir, PlanWeekBuilder.dersHaftaNo(satir)));
      }

      // 3. Son ders haftası 35 ise yıl sonu değerlendirme haftası eklenir.
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

  Map<String, dynamic> _donustur(Map<String, dynamic> m, int haftaNo) {
    final dersAdi = _seciliDersAdi ?? m['subject_name']?.toString() ?? 'Ders';
    final rawUnitTitle = (m['unit_title'] ?? '').toString().trim();
    final rawTopicTitle = (m['topic_title'] ?? '').toString().trim();
    final rawDesc = (m['outcome_description'] ?? '').toString().trim();

    final kazanimKodu = (m['outcome_code'] ?? '').toString().trim();
    final outcomeParts = OutcomePart.listFromDbText(m['outcome_parts'] as String?);

    // MEB resmi kazanımı veya ders konusu mevcut mu?
    final bool hasRealContent = outcomeParts.isNotEmpty ||
        (kazanimKodu.isNotEmpty && kazanimKodu != 'TATIL') ||
        (rawDesc.isNotEmpty && !rawDesc.toLowerCase().contains('planlanmamış') && !rawDesc.toLowerCase().contains('kazanım belirtilmemiş'));

    // Sadece ve sadece gerçek bir konu/kazanım yoksa zümre planlaması (OTP) sayılır
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

    // 2. Beceriler ve Değerler
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
      sdb = 'SDB1.1. Kendini Tanıma (Öz Farkındalık), SDB1.2. Kendini Düzenleme (Öz Düzenleme), SDB2.1. İletişim, SDB2.2. İş Birliği';
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

    // 3. Öğretme-Öğrenme Etkinlikleri (Görsel 1 Şablonu)
    final officialAct = (m['official_activity'] ?? '').toString().trim();
    final maarifSummary = (m['maarif_summary'] ?? '').toString().trim();

    // Dikkat Çekme
    String dikkatCekme = '';
    if (isTrulyUnplanned) {
      dikkatCekme = 'Öğrencilere bu derste Zümre Öğretmenler Kurulunca belirlenen derinleştirme, araştırma ve kazanım pekiştirme etkinliklerinin yürütüleceği belirtilerek dikkatleri çekilir.';
    } else if (officialAct.contains('?')) {
      final qMatch = RegExp(r'([^.!?\n]*\?)').firstMatch(officialAct);
      if (qMatch != null) {
        dikkatCekme = qMatch.group(1)?.replaceAll(RegExp(r'^[^“"]*[“"]'), '').replaceAll(RegExp(r'[”"].*$'), '').trim() ?? '';
      }
    }
    if (dikkatCekme.isEmpty || dikkatCekme.length < 5) {
      if (dersAdi.toLowerCase().contains('bilişim')) {
        dikkatCekme = 'Bilişim teknolojileri deyince aklınıza neler geliyor?';
      } else {
        dikkatCekme = '$fullTema kavramı günlük yaşamımızda nerede ve nasıl karşımıza çıkar?';
      }
    }

    // Güdüleme
    final guduleme = isTrulyUnplanned
        ? 'Önceki haftalarda öğrenilen bilgi ve becerileri gerçek yaşam senaryolarında, araştırma ve projelerde uygulama fırsatı bulacakları vurgulanır.'
        : 'Bu derste $fullTema konusuna ilişkin temel kavramları ve uygulama alanlarını açıklayabilecek duruma geleceksiniz.';

    // Derse Geçiş
    final derseGecis = isTrulyUnplanned
        ? 'Dersin başında hazırbulunuşluk ve önceki konuların kısa bir tekrarı yapıldıktan sonra zümre kararıyla belirlenen çalışma basamaklarına geçilir.'
        : 'Öğrencilerin dikkati çekildikten ve hazırbulunuşluk düzeyleri yoklandıktan sonra konunun işlenişine geçilir.';

    // Etkinlikler (Ders Adımları)
    final List<String> etkinlikAdimlari = [];
    if (isTrulyUnplanned) {
      etkinlikAdimlari.add('Dersin başında Zümre Öğretmenler Kurulu kararıyla belirlenen konu ve pekiştirme hedefleri öğrencilerle paylaşılır.');
      etkinlikAdimlari.add('Önceki ünitelerde öğrenilen temel kavramlar soru-cevap ve kavram yoklama yöntemleriyle gözden geçirilir.');
      etkinlikAdimlari.add('Öğrencilerin bireysel veya grup hâlinde yürütecekleri araştırma, proje ve inceleme görevleri dağıtılır.');
      etkinlikAdimlari.add('Etkileşimli tahta, çalışma yaprakları ve MEB dijital içerikleri eşliğinde pekiştirme çalışmaları tamamlanır.');
      etkinlikAdimlari.add('Çalışma sonunda elde edilen ürün veya kazanım çıktıları sınıf ortamında paylaşılarak akran geri bildirimi alınır.');
    } else if (officialAct.isNotEmpty) {
      final cumleler = officialAct
          .replaceAll(RegExp(r'FARKLILAŞTIRMA.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'ÖĞRETMEN YANSITMALARI.*$', caseSensitive: false), '')
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 15 && !s.contains('http') && !s.contains('karekod'))
          .toList();
      etkinlikAdimlari.addAll(cumleler.take(5));
    }

    if (!isTrulyUnplanned && etkinlikAdimlari.isEmpty) {
      // "Öğrencilerle tanışılır" metni yalnızca 1. haftaya aittir.
      // Resmî etkinlik alanı ders haftalarının %56'sında boş olduğu için
      // eski kod bu cümleyi mart ayındaki haftalara da basıyordu.
      etkinlikAdimlari.addAll(
        PlanWeekBuilder.etkinlikAdimlari(
          satir: m,
          haftaNo: haftaNo,
          temaBasligi: fullTema,
          surecBilesenleri: surecListesi,
        ),
      );
    }

    // Bireysel ve Grupla Etkinlikler
    const bireyselEtkinlikler = 'Açık uçlu sorular, doğru-yanlış, boşluk doldurma, eşleştirme soruları, MEB ders kitabı çalışma yaprakları.';
    const gruplaEtkinlikler = 'İşbirlikli çalışma, beyin fırtınası, istasyon tekniği, akran öğrenmesi ve grup tartışmaları.';

    // Özet
    String ozet = isTrulyUnplanned
        ? 'MEB TYMM yönergesi kapsamında zümre kararıyla planlanan etkinliklerin tamamlanması, öğrencilerin öğrenme eksikliklerinin giderilmesi ve kavramsal pekiştirme sağlanması hedeflenir.'
        : (maarifSummary.isNotEmpty ? maarifSummary : '');
    if (ozet.isNotEmpty && !isTrulyUnplanned) {
      ozet += '\n\n';
      ozet += 'Öğrencilerin bireysel farklılıkları göz ardı edilmemelidir. Öğrencilerin yeni kavramları önceki kavramların üzerine eklemeleri için fırsatlar verilmeli ve cesaretlendirilmelidir. Öğrenme-öğretme sürecinde öğrencilerin düşüncelerini sözlü olarak ifade etmelerine imkân tanınmalıdır.';
    }

    // 4. Farklılaştırma
    final diffRaw = (m['differentiation'] ?? '').toString().trim();
    final String genelFarklilastirma;
    if (isTrulyUnplanned) {
      genelFarklilastirma = 'MEB Maarif Modeli çerçevesinde; zümre kararıyla belirlenen okul temelli etkinliklerde öğrencilerin hazırbulunuşluk ve ilgi düzeylerine göre esnek çalışma grupları ve basamaklandırılmış görevler oluşturulur.';
    } else if (diffRaw.isNotEmpty) {
      genelFarklilastirma = diffRaw;
    } else {
      genelFarklilastirma = 'Öğrencilerin ilgi, ihtiyaç, hazırbulunuşluk düzeyleri ve öğrenme profillerine göre içerik, süreç ve ürün boyutlarında esnek öğretim uyarlamaları uygulanır.';
    }

    const zenginlestirme = 'İleri düzeydeki ve hızlı öğrenen öğrenciler için: Konuyu derinleştirici araştırma projeleri, üst düzey problem çözme senaryoları, dijital ürün geliştirme ve akran rehberliği görevleri planlanır.';
    const destekleme = 'Öğrenme sürecinde ek zamana ve desteğe ihtiyacı olan öğrenciler için: Görsel ve somut materyaller (şemalar, resimli kartlar), basamaklandırılmış çalışma yaprakları, yönlendirici ipuçları ve birebir rehberlikle tekrar uygulamaları yürütülür.';

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
        'disiplinler_arasi_iliskiler': 'Türkçe (anlama-ifade), Matematik (mantıksal akıl yürütme), Fen Bilimleri (bilimsel sorgulama)',
      },
      'ogretim_sureci': {
        'dikkat_cekme': dikkatCekme,
        'guduleme': guduleme,
        'derse_gecis': derseGecis,
        'etkinlikler': etkinlikAdimlari,
        'bireysel_etkinlikler': bireyselEtkinlikler,
        'grupla_etkinlikler': gruplaEtkinlikler,
        'ozet': ozet,
        'temel_kabuller': 'Öğrencilerin önceki sınıf ve konulara dair temel hazırbulunuşluk düzeyleri dikkate alınır.',
        'on_degerlendirme_sureci': 'Dersin başında hazırbulunuşluğu ölçmek üzere soru-cevap ve kavram yoklama tartışması yürütülür.',
        'kopru_kurma': 'Konu günlük hayat uygulamaları, güncel olaylar ve disiplinler arası bağlantılarla ilişkilendirilir.',
        'ogrenme_ogretme_uygulamalari': etkinlikAdimlari.join('\n'),
        'farklilastirma': {
          'genel_aciklama': genelFarklilastirma,
          'zenginlestirme': zenginlestirme,
          'destekleme': destekleme,
        },
      },
    };
  }

  Map<String, dynamic> _varsayilanYilSonuHaftaPlani(int haftaNo) {
    final dersAdi = _seciliDersAdi ?? 'Ders';
    const tarihAraligi = '14 - 18 Haziran 2027';
    const tema = 'Yıl Sonu Değerlendirme, Telafi ve Genel Tekrar';

    return {
      'meta': {
        'ders': dersAdi,
        'sinif': '$_seciliSinif. Sınıf',
        'hafta': '$haftaNo. Hafta',
        'tarih_araligi': tarihAraligi,
        'ders_saati': '2',
        'tema_unite': tema,
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': [
          '$dersAdi dersinde yıl boyunca edinilen temel bilgi, beceri ve değerlerin genel değerlendirmesi ve pekiştirilmesi yapılır.',
        ],
        'surec_bilesenleri': [
          'a) Öğrencilerin yıl boyunca oluşturduğu çalışma yaprakları, projeler ve ürün dosyaları incelenir.',
          'b) Dönem sonu kazanım eksiklikleri tespit edilerek telafi ve kavram pekiştirme çalışmaları yürütülür.',
          'c) Yaz tatili sürecinde öğrenilenlerin korunması ve verimli tatil geçirme rehberliği paylaşılır.',
        ],
      },
      'ozel_alanlar': {
        'belirli_gun_ve_haftalar': 'Eğitim-Öğretim Yılı Kapanışı',
        'alan_becerileri': 'Alan Becerileri, Kavramsal Çözümleme ve Değerlendirme',
        'kavramsal_beceriler': 'Eleştirel Düşünme, Karşılaştırma ve Özetleme',
        'sosyal_duygusal_ogrenme_becerileri': 'SDB1.1. Kendini Tanıma, SDB1.2. Kendini Düzenleme, SDB2.2. İş Birliği',
        'okuryazarlik_becerileri': 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık',
        'degerler': 'D3. Çalışkanlık, D16. Sorumluluk, D4. Dostluk',
        'disiplinler_arasi_iliskiler': 'Türkçe, Matematik, Fen Bilimleri, Sosyal Bilgiler',
      },
      'ogretim_sureci': {
        'dikkat_cekme': 'Öğrencilerle öğretim yılı boyunca yapılan en ilgi çekici etkinlikler ve kazanımlar üzerine sohbet başlatılır.',
        'guduleme': 'Yıl boyunca öğrenilen bilgilerin üst sınıflardaki derslere ve günlük hayata katkısı vurgulanır.',
        'derse_gecis': 'Öğrencilerin ürün dosyaları ve etkinlik raporları incelenmek üzere masalara yerleştirilir.',
        'etkinlikler': [
          'Öğretim yılı boyunca işlenen ana ünite ve kavramlar kavram haritaları eşliğinde özetlenir.',
          'Öğrencilerin hazırladığı proje, poster veya dijital çalışmalar sınıf sergisi şeklinde paylaşılır.',
          'Akran değerlendirmesi ve öz değerlendirme formları doldurularak öğrenme süreçleri yansıtılır.',
          'Kazanım eksikliği olan öğrenciler için soru-cevap ve ek alıştırmalarla telafi yapılır.',
          'Yaz tatili için tavsiye kitap listeleri ve eğitici etkinlik önerileri paylaşılarak ders sonlandırılır.',
        ],
        'bireysel_etkinlikler': 'Öz değerlendirme formu doldurma, çalışma portfolyosu düzenleme, eksik kazanım soru çözümleri.',
        'grupla_etkinlikler': 'Sınıf sergisi, akran geri bildirimi, grup değerlendirme çemberi ve bilgi yarışması.',
        'ozet': 'Öğrencilerin yıl boyunca kaydettikleri bireysel ve akademik gelişim takdir edilerek motive edilir.',
        'temel_kabuller': 'Öğretim yılı müfredatındaki temel kazanımların işlendiği kabul edilir.',
        'on_degerlendirme_sureci': 'Yıl sonu genel hatırlatma ve kavram tarama soruları yöneltilir.',
        'kopru_kurma': 'Öğrenilen bilgi ve becerilerin üst sınıflardaki derslerle bağlantısı kurulur.',
        'ogrenme_ogretme_uygulamalari': 'Sınıf sergisi, ürün dosyası incelemesi ve genel tekrar uygulamaları yürütülür.',
        'farklilastirma': {
          'genel_aciklama': 'Tüm öğrencilerin yıl sonu gelişim düzeyine uygun esnek değerlendirme ve telafi etkinlikleri sunulur.',
          'zenginlestirme': 'İleri düzeydeki öğrencilere tatil dönemi için ileri düzey araştırma ve proje fikirleri önerilir.',
          'destekleme': 'Temel kavramlarda eksikliği olan öğrenciler için özet kılavuzlar ve pekiştirici çalışma yaprakları verilir.',
        },
      },
    };
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

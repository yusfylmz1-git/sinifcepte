import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../outcomes/data/models/curriculum_outcome_model.dart';
import '../../../outcomes/data/repositories/curriculum_outcome_repository.dart';
import '../../data/bep_developmental_bank.dart';
import '../../data/models/bep_models.dart';
import '../../data/repositories/bep_repository.dart';
import '../../utils/bep_pdf_generator.dart';
import '../../utils/bep_coarse_pdf_generator.dart';
import '../widgets/bep_short_goal_editor.dart';
import '../../data/bep_option_banks.dart';
import '../widgets/bep_option_chips.dart';

/// Kaba değerlendirme: Yapıyor / Yapamıyor → plana al → PDF.
class BepPlanView extends StatefulWidget {
  final int planId;
  final StudentModel student;
  final ClassModel classModel;
  final TeacherProfileModel teacher;

  const BepPlanView({
    super.key,
    required this.planId,
    required this.student,
    required this.classModel,
    required this.teacher,
  });

  @override
  State<BepPlanView> createState() => _BepPlanViewState();
}

class _BepPlanViewState extends State<BepPlanView>
    with SingleTickerProviderStateMixin {
  /// İki sekme: hızlı "BEP" ve isteğe bağlı "Detaylı BEP".
  ///
  /// ## Neden bölündü
  /// Ekran açılınca öğretmeni üç boş metin kutusu (okul, RAM kararı,
  /// performans) ve üç çip bloğu karşılıyordu; asıl iş olan kazanım
  /// işaretleme en alttaydı. Bu alanların hepsi İSTEĞE BAĞLI —
  /// zorunlu olan tek şey amaçları belirlemek.
  ///
  /// Artık ilk sekme doğrudan kazanım listesini açıyor, künye ve
  /// ortam düzenlemeleri ikinci sekmede duruyor.
  late final TabController _tab;

  /// Açılış sekmesi bir kez seçilir; sonraki yenilemelerde öğretmeni
  /// bulunduğu sekmeden koparmayız.
  bool _ilkSekmeSecildi = false;

  /// Yeni planda seçili gelen ortam düzenlemeleri.
  ///
  /// Sahada neredeyse her BEP'te geçen maddeler; öğretmen ekleyip
  /// çıkarabilir. `bep_option_banks.dart` listelerinden birebir
  /// alınmıştır (yazım farkı olursa çip seçili görünmez).
  static const _varsayilanFiziksel =
      'Öğretmene yakın oturtma, Dikkat dağıtıcı uyaranların azaltılması';
  static const _varsayilanSosyal =
      'Akran desteği eşleştirmesi, Yönergelerin sadeleştirilmesi, '
      'Sık ve anında geri bildirim';
  static const _varsayilanDijital =
      'Etkileşimli tahta uygulamaları, Video destekli anlatım';

  final _repo = BepRepository();
  final _outcomes = CurriculumOutcomeRepository();
  final _ram = TextEditingController();
  final _perf = TextEditingController();

  /// Egitim ortami duzenlemeleri — virgulle ayrilmis secim metni.
  String _fiziksel = '';
  String _sosyal = '';
  String _dijital = '';
  final _school = TextEditingController();
  final _diag = TextEditingController();

  /// Plan genelindeki olcut ve tarihler.
  ///
  /// Once ikisi de sabitti: her satira "4/5 (%80)" basiliyor, tarih
  /// ogretim yilindan hesaplanip bitis her zaman 31 Mayis oluyordu.
  /// Ogretmen sinifin duzeyine gore olcutu, RAM kararina gore tarihi
  /// degistiremiyordu.
  String _olcut = '';
  final _olcutAlani = TextEditingController();
  DateTime? _baslangic;
  DateTime? _bitis;

  BepPlan? _plan;
  List<BepLongGoal> _goals = const [];
  List<UniqueOutcomeHit> _bank = const [];
  Map<String, bool> _coarse = const {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tab.dispose();
    _ram.dispose();
    _perf.dispose();
    _school.dispose();
    _diag.dispose();
    _olcutAlani.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final plan = await _repo.getPlan(widget.planId);
    final goals =
        plan?.id == null ? <BepLongGoal>[] : await _repo.longGoals(plan!.id!);
    final code = plan?.subjectCode.trim() ?? '';
    var bank = <UniqueOutcomeHit>[];
    var coarse = <String, bool>{};
    if (plan != null && code.isNotEmpty) {
      if (plan.programKind == BepProgramKind.developmental) {
        bank = BepDevelopmentalBank.hits(code);
      } else if (plan.gradeLevel >= 1) {
        bank = await _outcomes.searchUniqueOutcomes(
          gradeLevel: plan.gradeLevel,
          subjectCode: code,
          limit: 200,
        );
      }
      if (plan.id != null) {
        coarse = await _repo.coarseForPlan(plan.id!);
      }
    }
    if (!mounted) return;
    if (plan != null) {
      _ram.text = plan.ramDecision;
      _perf.text = plan.performanceLevel;
      // Ortam düzenlemeleri: YENİ planda yaygın olanlar seçili gelir.
      //
      // ## Neden varsayılan veriliyor
      // Bu üç alan neredeyse her BEP'te aynı birkaç maddeyi taşıyor
      // (öne oturtma, akran desteği, etkileşimli tahta). Boş
      // bırakıldığında PDF'te yedek sabit metin basılıyordu; öğretmen
      // de onlarca çip arasından aynı üç-dört şeyi her seferinde
      // yeniden seçiyordu.
      //
      // Yalnızca alan BOŞKEN dolduruluyor: öğretmen bir kez
      // düzenlediyse (hatta hepsini kaldırdıysa) seçimi korunur.
      _fiziksel = plan.physicalArrangements.trim().isEmpty
          ? _varsayilanFiziksel
          : plan.physicalArrangements;
      _sosyal = plan.socialArrangements.trim().isEmpty
          ? _varsayilanSosyal
          : plan.socialArrangements;
      _dijital = plan.digitalSupports.trim().isEmpty
          ? _varsayilanDijital
          : plan.digitalSupports;
      _school.text = plan.schoolName.isNotEmpty
          ? plan.schoolName
          : widget.teacher.schoolName;
      _diag.text = plan.diagnosis;
      _olcut = plan.defaultCriterion;
      _olcutAlani.text = _olcut;
      _baslangic = _tarihCoz(plan.startDate);
      _bitis = _tarihCoz(plan.endDate);
    }
    // İLK AÇILIŞTA hangi sekme?
    //
    // Sıra bilinçli olarak "BEP" (amaçlar) önde: künye yılda bir kez
    // doldurulur, amaç işaretleme ve değerlendirme ise defalarca
    // yapılır. Sık yapılan işi bir sekme arkasına atmak yanlış olurdu.
    //
    // Ama YENİ planda künye tamamen boş oluyor ve öğretmen nereden
    // başlayacağını bilemiyordu. Bu durumda ekran kendisi künyeyi
    // açar; kaydedince amaçlara döner. Bir kez doldurulmuş planda
    // doğrudan amaçlar görünür.
    final kunyeBos = plan != null &&
        plan.schoolName.trim().isEmpty &&
        plan.diagnosis.trim().isEmpty &&
        plan.ramDecision.trim().isEmpty &&
        plan.performanceLevel.trim().isEmpty;
    if (kunyeBos && _goals.isEmpty && !_ilkSekmeSecildi) {
      _ilkSekmeSecildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tab.animateTo(1);
      });
    }

    setState(() {
      _plan = plan;
      _goals = goals;
      _bank = bank;
      _coarse = coarse;
      _loading = false;
    });
  }

  Set<String> get _selectedCodes {
    final codes = <String>{};
    for (final g in _goals) {
      for (final s in g.shorts) {
        if (s.outcomeCode != null && s.outcomeCode!.isNotEmpty) {
          codes.add(s.outcomeCode!);
        }
      }
    }
    return codes;
  }

  BepShortGoal? _goalFor(UniqueOutcomeHit hit) {
    for (final g in _goals) {
      for (final s in g.shorts) {
        if (hit.code.isNotEmpty && s.outcomeCode == hit.code) return s;
        if (hit.code.isEmpty && s.outcomeDescription == hit.description) {
          return s;
        }
      }
    }
    return null;
  }

  String _coarseKey(UniqueOutcomeHit hit) =>
      hit.code.trim().isNotEmpty ? hit.code.trim() : 'd:${hit.description.trim()}';

  /// true = Yapıyor, false = Yapamıyor, null = işaretlenmedi.
  bool? _canDo(UniqueOutcomeHit hit) {
    if (_goalFor(hit) != null) return false;
    return _coarse[_coarseKey(hit)];
  }

  Future<void> _setCoarse(UniqueOutcomeHit hit, bool canDo) async {
    final plan = _plan;
    if (plan?.id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _repo.setCoarse(
        planId: plan!.id!,
        unitTitle: hit.unitTitle,
        outcomeCode: hit.code,
        outcomeDescription: hit.description,
        studentFirstName: widget.student.firstName,
        canDo: canDo,
        // Kaba Degerlendirme Formunun kunyesi. Yalnizca ILK
        // isarette yazilir; ogretmene ayrica form doldurtulmuyor.
        evaluatedBy: widget.teacher.fullName,
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markUnit(List<UniqueOutcomeHit> hits, {required bool canDo}) async {
    final plan = _plan;
    if (plan?.id == null || _busy) return;
    setState(() => _busy = true);
    try {
      for (final hit in hits) {
        await _repo.setCoarse(
          planId: plan!.id!,
          unitTitle: hit.unitTitle,
          outcomeCode: hit.code,
          outcomeDescription: hit.description,
          studentFirstName: widget.student.firstName,
          canDo: canDo,
        );
      }
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Plana alinmis TUM amaclara ayni degerlendirmeyi verir.
  ///
  /// ## Neden
  /// Donem sonunda ogretmen 20-30 amaci tek tek isaretliyordu. Cogu
  /// ayni durumda oluyor; once hepsine "Devam" verip sonra istisnalari
  /// duzeltmek cok daha hizli.
  Future<void> _tumStatus(BepEvalStatus status) async {
    if (_busy) return;
    final hedef = <BepShortGoal>[];
    for (final long in _goals) {
      for (final k in long.shorts) {
        if (k.id != null && k.latestStatus != status) hedef.add(k);
      }
    }
    if (hedef.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm amaçlar zaten "${status.label}".')),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Toplu değerlendirme'),
        content: Text(
          '${hedef.length} amaç "${status.label}" olarak işaretlenecek. '
          'Sonra tek tek düzeltebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('İşaretle'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _busy = true);
    try {
      for (final k in hedef) {
        await _repo.addEvaluation(shortGoalId: k.id!, status: status);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  /// Bankadaki butun kazanimlari plana alir.
  ///
  /// Unite basina "Hepsini plana al" vardi ama 8-10 unite icin ayri
  /// ayri basmak gerekiyordu.
  Future<void> _tumunuPlanaAl() async {
    if (_bank.isEmpty || _busy) return;
    final kalan = _bank.where((h) => _canDo(h) != false).toList();
    if (kalan.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm kazanımlar zaten planda.')),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tümünü plana al'),
        content: Text(
          '${kalan.length} kazanım "Yapamıyor" işaretlenip BEP amacı '
          'olarak plana alınacak. Yapabildiklerini sonra tek tek '
          'çıkarabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Plana al'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await _markUnit(kalan, canDo: false);
  }

  Future<void> _setStatus(BepShortGoal short, BepEvalStatus status) async {
    if (short.id == null || short.latestStatus == status) return;
    await _repo.addEvaluation(shortGoalId: short.id!, status: status);
    await _reload();
  }

  Future<void> _pdf() async {
    final plan = _plan;
    if (plan == null) return;
    if (!mounted) return;
    await PdfPreviewScreen.open(
      context,
      title: 'BEP takip formu',
      subtitle: '${widget.student.fullName} · ${plan.subject}',
      fileName: 'BEP_${widget.student.fullName}_${plan.subject}.pdf',
      documentBuilder: (_) => BepPdfGenerator.build(
        plan: plan,
        student: widget.student,
        className: widget.classModel.name,
        schoolName: widget.teacher.schoolName,
        teacherName: widget.teacher.fullName,
        principalName: widget.teacher.schoolPrincipalName,
        goals: _goals,
        bank: _bank,
      ),
    );
  }

  /// Kaba Değerlendirme Formunu üretir.
  ///
  /// Bu form BEP'in girdisidir: öğretmen kazanımları "yapıyor /
  /// yapamıyor" diye işaretler, yapamadıkları plana kısa dönemli
  /// amaç olarak girer. İşaretleme zaten vardı; eksik olan belgenin
  /// kendisiydi — öğretmen formu okul dosyasına koyamıyordu.
  Future<void> _kabaDegerlendirmePdf() async {
    final plan = _plan;
    if (plan?.id == null) return;

    final marks = await _repo.coarseMarksForPlan(plan!.id!);
    if (!mounted) return;

    // Boş bir değerlendirme formu imzalanacak bir belge değil.
    if (marks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Önce amaçları "Yapıyor / Yapamıyor" olarak değerlendirin.',
          ),
        ),
      );
      return;
    }

    final kunye = await _repo.coarseHeader(plan.id!);
    if (!mounted) return;

    await PdfPreviewScreen.open(
      context,
      title: 'Kaba Değerlendirme Formu',
      subtitle: '${widget.student.fullName} · ${plan.subject}',
      fileName:
          'Kaba_Degerlendirme_${widget.student.fullName}_${plan.subject}.pdf',
      documentBuilder: (_) => BepCoarsePdfGenerator.build(
        plan: plan,
        student: widget.student,
        className: widget.classModel.name,
        schoolName: widget.teacher.schoolName,
        marks: marks,
        evaluatedAt: _tarihMetni(kunye.tarih),
        evaluatedBy: kunye.kisi,
      ),
    );
  }

  /// ISO tarihi belgeye basılacak biçime çevirir.
  static String _tarihMetni(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    String iki(int n) => n.toString().padLeft(2, '0');
    return '${iki(t.day)}.${iki(t.month)}.${t.year}';
  }

  /// "gg.aa.yyyy" -> DateTime. Bozuk kayit uygulamayi dusurmemeli.
  static DateTime? _tarihCoz(String ham) {
    final p = ham.trim().split('.');
    if (p.length != 3) return null;
    final g = int.tryParse(p[0]);
    final a = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (g == null || a == null || y == null) return null;
    if (a < 1 || a > 12 || g < 1 || g > 31) return null;
    return DateTime(y, a, g);
  }

  /// DateTime -> "gg.aa.yyyy". Bos ise bos metin: PDF o zaman eski
  /// hesabina doner.
  static String _tarihYaz(DateTime? t) {
    if (t == null) return '';
    String iki(int n) => n.toString().padLeft(2, '0');
    return '${iki(t.day)}.${iki(t.month)}.${t.year}';
  }

  /// Tarih girilmediginde belgeye basilacak deger.
  ///
  /// PDF ile AYNI hesabi kullanir ([BepPdfGenerator.planDateRange]),
  /// yoksa ekranda bir sey yazip belgeye baskasini basardik.
  String _hesaplanan(bool baslangic) {
    final plan = _plan;
    if (plan == null) return baslangic ? 'Başlangıç' : 'Bitiş';
    final aralik = BepPdfGenerator.planDateRange(
      plan.academicYear,
      plan.startMonth,
    );
    final p = aralik.split(' - ');
    if (p.length != 2) return baslangic ? 'Başlangıç' : 'Bitiş';
    return baslangic ? p[0] : p[1];
  }

  Future<void> _tarihSec({required bool baslangic}) async {
    final plan = _plan;
    // Takvim penceresi ogretim yilini kapsar; ogretmen yanlislikla
    // baska yila gitmesin diye genis ama sinirli.
    final yil = int.tryParse(
          (plan?.academicYear ?? '').split('-').first,
        ) ??
        DateTime.now().year;
    final secili = (baslangic ? _baslangic : _bitis) ??
        DateTime(yil, baslangic ? 9 : 6, baslangic ? 1 : 30);
    final sonuc = await showDatePicker(
      context: context,
      initialDate: secili,
      firstDate: DateTime(yil - 1, 1, 1),
      lastDate: DateTime(yil + 2, 12, 31),
      helpText: baslangic ? 'Başlangıç tarihi' : 'Bitiş tarihi',
    );
    if (sonuc == null || !mounted) return;
    setState(() {
      if (baslangic) {
        _baslangic = sonuc;
      } else {
        _bitis = sonuc;
      }
    });
  }

  Future<void> _saveMeta() async {
    final plan = _plan;
    if (plan == null) return;
    await _repo.updatePlan(plan.copyWith(
      ramDecision: _ram.text,
      performanceLevel: _perf.text,
      physicalArrangements: _fiziksel,
      socialArrangements: _sosyal,
      digitalSupports: _dijital,
      schoolName: _school.text,
      diagnosis: _diag.text,
      defaultCriterion: _olcut,
      startDate: _tarihYaz(_baslangic),
      endDate: _tarihYaz(_bitis),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bilgiler kaydedildi')),
    );
    // Künye tamamlandıktan sonraki adım amaçları belirlemek;
    // öğretmeni orada bırakmak yerine doğrudan götürüyoruz.
    _tab.animateTo(0);
  }

  Future<void> _customGoal() async {
    final plan = _plan;
    if (plan == null || plan.id == null) return;
    var longId = _goals.where((g) => g.title == 'Özel amaçlar').firstOrNull?.id;
    longId ??= await _repo.insertLongGoal(BepLongGoal(
      planId: plan.id!,
      title: 'Özel amaçlar',
      orderIndex: _goals.length,
    ));
    if (!mounted) return;
    final goal = await BepShortGoalEditor.show(
      context,
      longGoalId: longId,
      gradeLevel: plan.gradeLevel > 0
          ? plan.gradeLevel
          : (int.tryParse(
                InputSanitizer.extractGradeLevel(widget.classModel.name) ?? '',
              ) ??
              0),
      subjectCode: plan.subjectCode,
    );
    if (goal == null) return;
    await _repo.insertShortGoal(goal);
    await _reload();
  }

  Map<String, List<UniqueOutcomeHit>> get _grouped {
    final map = <String, List<UniqueOutcomeHit>>{};
    for (final h in _bank) {
      final key = h.unitTitle.trim().isEmpty ? 'Diğer' : h.unitTitle.trim();
      map.putIfAbsent(key, () => []).add(h);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = _plan;
    final selected = _selectedCodes;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: CustomAppBar(
        title: plan == null ? 'BEP' : 'BEP · ${plan.subject}',
        showProfileAvatar: false,
      ),
      floatingActionButton: plan == null
          ? null
          // İKİ AYRI BELGE.
          //
          // Kaba Değerlendirme Formu BEP'in girdisidir: öğretmen
          // kazanımları işaretler, yapamadıkları plana amaç olarak
          // girer. Koşulları da ayrı — KDF için işaretlenmiş amaç,
          // BEP için plana alınmış amaç gerekir.
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'kdf',
                  onPressed:
                      _coarse.isEmpty ? null : _kabaDegerlendirmePdf,
                  backgroundColor:
                      _coarse.isEmpty ? null : const Color(0xFF0F766E),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Kaba Değerlendirme'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'bep',
                  onPressed: selected.isEmpty ? null : _pdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('BEP (${selected.length})'),
                ),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : plan == null
              ? const Center(child: Text('Plan bulunamadı'))
              : Column(
                  children: [
                    _kunye(isDark, plan),
                    TabBar(
                      controller: _tab,
                      labelColor: AppColors.primary,
                      unselectedLabelColor:
                          isDark ? Colors.white60 : Colors.black54,
                      indicatorColor: AppColors.primary,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: 'BEP'),
                        Tab(text: 'BEP Detayı'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          // 1. sekme — asıl iş: amaçları belirle.
                          ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            children: [
                              _hizliIslemler(isDark, selected),
                                  if (_bank.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '${selected.length} / ${_bank.length} amaç plana alındı',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  if (_bank.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Text(
                                        plan.programKind == BepProgramKind.developmental
                                            ? 'Bu gelişim alanı için banka boş. Özel amaç yazabilirsiniz.'
                                            : '${plan.gradeLabel} ${plan.subject} için pakette kazanım yok. Özel amaç yazabilirsiniz.',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ),
                                  for (final entry in grouped.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                                      child: Row(
                                        children: [
                                          // Ünite başlığı = UZUN DÖNEMLİ AMAÇ.
                                          //
                                          // Hiyerarşi veritabanında zaten var
                                          // (bep_long_goals / bep_short_goals)
                                          // ama ekranda düz liste gibi
                                          // görünüyordu; öğretmen resmî
                                          // karşılığını tanıyamıyordu.
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'UZUN DÖNEMLİ AMAÇ',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.4,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _markUnit(entry.value, canDo: false),
                                            child: const Text('Hepsini al'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    for (final hit in entry.value)
                                      _GoalTile(
                                        hit: hit,
                                        canDo: _canDo(hit),
                                        goal: _goalFor(hit),
                                        enabled: !_busy,
                                        onCoarse: (v) => _setCoarse(hit, v),
                                        onStatus: (status) {
                                          final g = _goalFor(hit);
                                          if (g != null) _setStatus(g, status);
                                        },
                                      ),
                                  ],
                                  TextButton.icon(
                                    onPressed: _customGoal,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Listede yoksa özel amaç yaz'),
                                  ),
                            ],
                          ),
                          // 2. sekme — künye ve ortam düzenlemeleri.
                          // Hepsi isteğe bağlı; PDF bunlar boşken de
                          // üretilir.
                          ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            children: [
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _school,
                                    maxLength: 120,
                                    maxLines: 1,
                                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                                    decoration: const InputDecoration(
                                      labelText: 'Okul',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _diag,
                                    maxLength: 400,
                                    maxLines: 2,
                                    inputFormatters: [LengthLimitingTextInputFormatter(400)],
                                    decoration: const InputDecoration(
                                      labelText: 'Eğitsel tanı (RAM)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _ram,
                                    maxLength: 400,
                                    maxLines: 2,
                                    inputFormatters: [LengthLimitingTextInputFormatter(400)],
                                    decoration: const InputDecoration(
                                      labelText: 'RAM kararı (cihazda kalır)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _perf,
                                    maxLength: 400,
                                    maxLines: 2,
                                    inputFormatters: [LengthLimitingTextInputFormatter(400)],
                                    decoration: const InputDecoration(
                                      labelText: 'Mevcut performans',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Plan tarihi.
                                  //
                                  // Once tarih ogretim yilindan
                                  // HESAPLANIYORDU ve bitis her zaman
                                  // 31 Mayis'ti; RAM karari donem
                                  // ortasinda biten bir plan
                                  // ongoruyorsa yazilamiyordu.
                                  Text(
                                    'Plan tarihi',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Boş bırakırsanız okul takvimine '
                                    'göre hesaplanır.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _tarihSec(baslangic: true),
                                          icon: const Icon(
                                              Icons.event_outlined, size: 18),
                                          // Bos ise HESAPLANANI goster:
                                          // ogretmen belgeye ne
                                          // basilacagini secmeden
                                          // gormeli.
                                          label: Text(
                                            _baslangic == null
                                                ? _hesaplanan(true)
                                                : _tarihYaz(_baslangic),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _baslangic == null
                                                  ? Theme.of(context)
                                                      .hintColor
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _tarihSec(baslangic: false),
                                          icon: const Icon(
                                              Icons.event_available_outlined,
                                              size: 18),
                                          label: Text(
                                            _bitis == null
                                                ? _hesaplanan(false)
                                                : _tarihYaz(_bitis),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _bitis == null
                                                  ? Theme.of(context)
                                                      .hintColor
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_baslangic != null ||
                                          _bitis != null)
                                        IconButton(
                                          tooltip: 'Tarihi temizle',
                                          icon: const Icon(
                                              Icons.backspace_outlined,
                                              size: 18),
                                          onPressed: () => setState(() {
                                            _baslangic = null;
                                            _bitis = null;
                                          }),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Plan genelinde olcut.
                                  //
                                  // Her satira "4/5 (%80)" sabiti
                                  // basiliyordu; ogretmen sinifin
                                  // duzeyine gore degistiremiyordu.
                                  // Tek tek amaca girilen olcut
                                  // buradakinden ustundur.
                                  BepSingleChips(
                                    baslik: 'Varsayılan ölçüt',
                                    banka: bepOlcutBankasi,
                                    secili: _olcut,
                                    // Cip ile kutu ayni degeri
                                    // gosterir; biri degisince oteki de
                                    // guncellenmeli, yoksa ogretmen
                                    // cipi secip kutuda eskisini gorur.
                                    onChanged: (v) => setState(() {
                                      _olcut = v;
                                      _olcutAlani.text = v;
                                    }),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    key: const ValueKey('bep_olcut_alani'),
                                    controller: _olcutAlani,
                                    maxLength: 60,
                                    onChanged: (v) => _olcut = v,
                                    decoration: const InputDecoration(
                                      labelText: 'Kendi ölçütünüz',
                                      hintText: '%70 / 7 denemenin 5\'inde',
                                      helperText:
                                          'Boş bırakılırsa 4/5 (%80) '
                                          'kullanılır.',
                                      border: OutlineInputBorder(),
                                      counterText: '',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Egitim ortami duzenlemeleri.
                                  //
                                  // PDF'in alt blogundaki uc kutu once SADECE BASLIK
                                  // basiyordu; "one oturtma", "akran destegi" gibi
                                  // asil BEP tedbirleri belgeye hic yazilamiyordu.
                                  BepOptionChips(
                                    baslik: 'Fiziksel Ortam Düzenlemeleri',
                                    banka: bepFizikselBankasi,
                                    secili: _fiziksel,
                                    onChanged: (v) => setState(() => _fiziksel = v),
                                  ),
                                  const SizedBox(height: 12),
                                  BepOptionChips(
                                    baslik: 'Sosyal Etkileşim Ortamı',
                                    banka: bepSosyalBankasi,
                                    secili: _sosyal,
                                    onChanged: (v) => setState(() => _sosyal = v),
                                  ),
                                  const SizedBox(height: 12),
                                  BepOptionChips(
                                    baslik: 'Dijital Destekler',
                                    banka: bepDijitalBankasi,
                                    secili: _dijital,
                                    onChanged: (v) => setState(() => _dijital = v),
                                  ),
                                  const SizedBox(height: 18),
                                  // Metin düğmesi yerine tam genişlikte
                                  // birincil eylem: bu sekmenin bittiği
                                  // ve sıranın amaçlara geldiği belli
                                  // olsun.
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _saveMeta,
                                      icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18),
                                      label: const Text(
                                          'Kaydet ve amaçlara geç'),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bu sayfadaki alanlar isteğe bağlıdır; '
                                    'boş bırakıp devam edebilirsiniz.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Öğrenci ve ders künyesi — iki sekmede de üstte sabit durur.
  Widget _kunye(bool isDark, BepPlan plan) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.student.fullName} · ${widget.classModel.name} · '
            '${plan.academicYear}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color:
                  isDark ? Colors.white70 : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${plan.gradeLabel} · ${plan.subject}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// Hızlı işlem çubuğu — BEP sekmesinin en üstünde.
  ///
  /// ## Neden
  /// Öğretmen 30-40 kazanımı tek tek işaretliyordu. Ünite başına
  /// "Hepsini plana al" vardı ama listenin içine gömülüydü ve dönem
  /// sonu değerlendirmesi için toplu seçenek hiç yoktu.
  Widget _hizliIslemler(bool isDark, Set<String> selected) {
    final planlanan = _goals.fold<int>(0, (a, g) => a + g.shorts.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _bank.isEmpty
                ? '$planlanan amaç planda'
                : '${selected.length} / ${_bank.length} kazanım planda',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_bank.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _tumunuPlanaAl,
                  icon: const Icon(Icons.playlist_add_check_rounded, size: 17),
                  label: const Text('Tümünü plana al'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              if (planlanan > 0)
                for (final d in BepEvalStatus.values)
                  OutlinedButton(
                    onPressed: _busy ? null : () => _tumStatus(d),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: Text('Tümü: ${d.compactLabel}'),
                  ),
            ],
          ),
          if (planlanan > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Toplu işaretledikten sonra istisnaları tek tek '
              'düzeltebilirsiniz.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final UniqueOutcomeHit hit;
  final bool? canDo;
  final BepShortGoal? goal;
  final bool enabled;
  final ValueChanged<bool> onCoarse;
  final ValueChanged<BepEvalStatus> onStatus;

  const _GoalTile({
    required this.hit,
    required this.canDo,
    required this.goal,
    required this.enabled,
    required this.onCoarse,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final status = goal?.latestStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hit.label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.3),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => onCoarse(true) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    backgroundColor: canDo == true
                        ? const Color(0xFFDCFCE7)
                        : Colors.transparent,
                    side: BorderSide(
                      color: canDo == true
                          ? const Color(0xFF15803D)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: const Text('+ Yapıyor'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => onCoarse(false) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB45309),
                    backgroundColor: canDo == false
                        ? const Color(0xFFFEF3C7)
                        : Colors.transparent,
                    side: BorderSide(
                      color: canDo == false
                          ? const Color(0xFFB45309)
                          : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: const Text('− Yapamıyor'),
                ),
              ),
            ],
          ),
          // Donem sonu degerlendirmesi — TEK SECIM.
          //
          // Once Checkbox ile ciziliyordu. Ucu birbirini disliyor
          // (birine basinca oteki kalkiyor) ama Checkbox bagimsiz
          // ac/kapa demektir; ogretmen ucunu birden isaretlemeyi
          // deneyip olmayinca bu kutucuklarin ne ise yaradigini
          // soruyordu. ChoiceChip'te tek secim oldugu goruntuden
          // anlasiliyor.
          //
          // Isaretlenen deger PDF'in "Degerlendirme" sutununa basilir.
          if (canDo == false) ...[
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                'Dönem sonu değerlendirmesi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final s in BepEvalStatus.values)
                  ChoiceChip(
                    label: Text(
                      s.compactLabel,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    selected: status == s,
                    onSelected: enabled ? (_) => onStatus(s) : null,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

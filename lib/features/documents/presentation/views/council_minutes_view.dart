import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/name_formatter.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/repositories/student_repository.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../auth_profile/data/services/teacher_branches.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../parent_portal/providers/cloud_communication_provider.dart';
import '../../data/council_minutes.dart';
import '../../utils/council_minutes_pdf_generator.dart';

/// Zümre / ŞÖK tutanağı: önce kısa form, sonra "hazırlandı" ekranı.
///
/// Kullanıcı (10 Ekim 2026) rakibin akışını gösterdi: "adamlar güzel bir
/// sistem kurmuş, bizimkine bak". Eski düzenleyici alt penceredeydi ve
/// ilk ekranda her şey vardı (kurul, dönem, sınıf, tarih ve saat elle
/// yazılarak, yer, başkan, yazman, katılımcılar, 11 gündem maddesi).
/// Artık ilk ekranda yalnız toplantının kendisi sorulur; gündem yönergeden
/// hazır gelir, katılımcılar kadrodan; ikisi de sonra düzenlenebilir.
///
/// "Yapay zekâ ile oluştur" BİLEREK yok: tutanak okul arşivine giren
/// evraktır, karar cümlesi uydurulamaz. Gündem ve karar dili yönergeden.
class CouncilMinutesView extends ConsumerStatefulWidget {
  const CouncilMinutesView({super.key, required this.kind});

  final CouncilKind kind;

  static Future<void> open(BuildContext context, CouncilKind kind) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => CouncilMinutesView(kind: kind)));

  @override
  ConsumerState<CouncilMinutesView> createState() => _CouncilMinutesViewState();
}

class _CouncilMinutesViewState extends ConsumerState<CouncilMinutesView> {
  late final TeacherProfileModel _profile = ref.read(teacherProfileProvider);
  late final List<ClassModel> _classes = ref.read(classListProvider).valueOrNull ?? const [];
  /// Seçilen kademenin branşları; öğretmenin kendi branşı listede yoksa başa.
  List<String> get _branslar {
    final tur = switch (_kademeSecimi) {
      CouncilLevel.ilkokul => 'İlkokul',
      CouncilLevel.ortaokul => 'Ortaokul',
      CouncilLevel.ortaogretim => 'Lise',
      _ => _profile.schoolType ?? '',
    };
    final liste = [
      for (final b in TeacherBranches.forSchoolType(tur))
        if (b != TeacherBranches.other) b,
    ];
    final kendi = CouncilMinutes.stripRoleSuffix(_profile.branch);
    return [if (kendi.isNotEmpty && !liste.contains(kendi)) kendi, ...liste];
  }

  /// Kullanıcı kademeyi değiştirdiyse o; yoksa okul bilgisinden (okul türü,
  /// şube, branş). Kullanıcı kararı (10 Ekim 2026): "okul bilgisinden
  /// ortaokul mu lise mi ilkokul mu anlayabiliriz, varsayılan seçili gelsin".
  CouncilLevel? _kademeSecimi;

  late CouncilPeriod _period = CouncilMinutes.suggestedPeriod();
  late String _branch = CouncilMinutes.stripRoleSuffix(_profile.branch);
  ClassModel? _class;
  DateTime _tarih = DateTime.now();
  TimeOfDay _saat = const TimeOfDay(hour: 15, minute: 0);
  late final TextEditingController _yer = TextEditingController();

  // Oluşturulduktan sonra
  bool _hazir = false;
  List<CouncilAgendaItem> _agenda = const [];
  List<CouncilAttendee> _attendees = const [];
  String _baskan = '';
  String _yazman = '';

  bool get _sok => widget.kind == CouncilKind.sok;
  String get _ad => _sok ? 'ŞÖK tutanağı' : 'Zümre tutanağı';

  @override
  void initState() {
    super.initState();
    if (_sok || CouncilMinutes.isClassroomTeacher(_branch)) {
      _class = _classes.where((c) => c.isHomeroom).firstOrNull ?? _classes.firstOrNull;
    }
    _yer.text = CouncilMinutes.defaultLocation(widget.kind, _class?.name);
  }

  @override
  void dispose() {
    _yer.dispose();
    super.dispose();
  }

  int? get _grade => _class == null ? null : CouncilMinutes.gradeFromClassName(_class!.name);

  bool get _sokUygun =>
      CouncilMinutes.sokPermitted(grade: _grade, schoolType: _profile.schoolType);

  String? get _engel {
    if (_sok && _class?.id == null) return 'ŞÖK için önce bir şube seçin.';
    if (_sok && !_sokUygun) {
      return CouncilMinutes.sokBlockedReason(grade: _grade, schoolType: _profile.schoolType);
    }
    return null;
  }

  String get _saatMetni =>
      '${_saat.hour.toString().padLeft(2, '0')}:${_saat.minute.toString().padLeft(2, '0')}';

  Future<void> _olustur() async {
    if (_engel != null) return;
    HapticFeedback.mediumImpact();
    final attendees = CouncilMinutes.resolveAttendees(
      kind: widget.kind,
      teacherName: _profile.fullName,
      teacherBranch: _branch,
    );
    setState(() {
      _agenda = CouncilMinutes.buildAgenda(
        kind: widget.kind,
        period: _period,
        grade: _grade,
        // Kademeye özgü maddeler (ilkokulda gözlem formları, lisede önleme
        // komisyonu, ortaokulda sınıf geçme) yalnız o kademede gelir.
        level: _kademe,
      );
      _attendees = attendees;
      _baskan = attendees.where((a) => a.isChair).firstOrNull?.name ?? _profile.fullName;
      _hazir = true;
    });
    unawaited(_kadroyuOku());
  }

  /// Şubenin kadrosu buluttan bir kez okunur; gelmezse profil satırı yeter.
  Future<void> _kadroyuOku() async {
    final classId = _class?.id;
    final uid = TeacherIdentity.resolve(_profile);
    if (classId == null || !CloudIds.isValidUid(uid)) return;
    try {
      final cloudId = CloudIds.classId(teacherUid: uid, localClassId: classId);
      final staff = await ref.read(classStaffProvider(cloudId).future).timeout(const Duration(seconds: 2));
      if (!mounted || staff.isEmpty) return;
      final next = CouncilMinutes.resolveAttendees(
        kind: widget.kind,
        teacherName: _profile.fullName,
        teacherBranch: _branch,
        staff: [
          for (final m in staff)
            CouncilAttendee(name: m.teacherName, branch: m.branch, isChair: m.isHomeroom),
        ],
      );
      setState(() {
        _attendees = next;
        final chair = next.where((a) => a.isChair).firstOrNull;
        if (chair != null && _baskan == _profile.fullName) _baskan = chair.name;
      });
    } on Object {
      // Donma olmasın: kadro gelmezse eldeki liste yeter.
    }
  }

  Future<void> _onizle() async {
    final students = _class?.id == null
        ? const <StudentModel>[]
        : await StudentRepository().getStudentsByClassId(_class!.id!);
    if (!mounted) return;
    final year = (_class?.academicYear.trim().isNotEmpty == true)
        ? _class!.academicYear
        : CouncilMinutes.academicYearLabel();
    final etiket = _sok ? 'SOK' : 'Zumre';
    final tag = _sok ? (_class?.name ?? 'sube') : (_branch.trim().isEmpty ? 'alan' : _branch);
    final attendees =
        _attendees.where((a) => a.name.trim().isNotEmpty || a.branch.trim().isNotEmpty).toList();
    await PdfPreviewScreen.open(
      context,
      title: CouncilMinutes.kindLabel(widget.kind),
      subtitle: 'Taslak tutanak · ${CouncilMinutes.periodLabel(_period)}',
      fileName: '${etiket}_Tutanagi_${tag}_${CouncilMinutes.periodLabel(_period)}.pdf',
      documentBuilder: (_) => CouncilMinutesPdfGenerator.build(
        kind: widget.kind,
        period: _period,
        schoolName: _profile.schoolName,
        teacherName: _profile.fullName,
        principalName: _profile.schoolPrincipalName,
        branch: CouncilMinutes.titleBranch(profileBranch: _branch),
        academicYear: year,
        meetingDate: AppDateFormatter.gunAyYil(_tarih),
        meetingTime: _saatMetni,
        meetingLocation: _yer.text.trim(),
        chairName: _baskan.trim().isEmpty ? _profile.fullName : _baskan.trim(),
        secretaryName: _yazman.trim(),
        attendees: attendees,
        agenda: _agenda,
        city: _profile.city,
        district: _profile.district,
        className: _class?.name,
        students: students,
        meetingNo: switch (_period) {
          CouncilPeriod.yearStart => 1,
          CouncilPeriod.secondTerm => 2,
          CouncilPeriod.yearEnd => 3,
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Görünüm: SınıfCepte'nin kendi dili (10 Ekim 2026)
  //
  // AKIŞ rakipten alındı (seç → hazırla → işlemler), GÖRÜNÜŞ alınmadı.
  // Kullanıcı: "kopya yapalım demedim; sistem olarak ne güzel yaptıklarını
  // söyledim, bize özgü olmalı". İlk sürüm mor degrade başlık, beyaz yuvarlak
  // form kartı ve oklu satırlarla rakibin birebir aynısıydı.
  //
  // Uygulamanın belge ekranlarındaki gibi: CustomAppBar, ince kenarlı beyaz
  // kartlar, simge kutulu sıkı satırlar, bilgi şeritleri. Bize özgü olan:
  // * hazır gündem görünür (farkımız içerik; yönerge ve Maarif metni),
  // * toplantı takvime göre önerilir (ay ipucu, "önerilen"),
  // * "hazırlandı" ekranında tutanağın KÂĞIT hâli; dokununca PDF.
  // ---------------------------------------------------------------------------

  static const _border = Color(0xFFE2E8F0);
  static const _borderDark = Color(0xFF334155);

  CouncilLevel get _otomatikKademe =>
      CouncilMinutes.levelFrom(grade: _grade, schoolType: _profile.schoolType, branch: _branch);

  /// ŞÖK'te kademe şubeden gelir (değiştirilemez); zümrede seçilebilir.
  CouncilLevel get _kademe => (!_sok ? _kademeSecimi : null) ?? _otomatikKademe;

  List<CouncilAgendaItem> _gundemKur() => CouncilMinutes.buildAgenda(
        kind: widget.kind,
        period: _period,
        grade: _grade,
        level: _kademe,
      );

  String _donemAdi(CouncilPeriod p) => switch (p) {
        CouncilPeriod.yearStart => 'Sene başı',
        CouncilPeriod.secondTerm => '2. dönem',
        CouncilPeriod.yearEnd => 'Sene sonu',
      };

  /// Yönergedeki ay: zümre m.12/4 (ders yılı başlamadan önce, ikinci dönem
  /// başında, ders yılı sonunda); ŞÖK m.10/2 (ortaokulda ekim-şubat-haziran,
  /// ortaöğretimde kasım-nisan).
  String _ayIpucu(CouncilPeriod p) {
    if (_sok && _kademe == CouncilLevel.ortaogretim) {
      return switch (p) {
        CouncilPeriod.yearStart => 'Kasım',
        CouncilPeriod.secondTerm => 'Nisan',
        CouncilPeriod.yearEnd => 'Haziran',
      };
    }
    return switch (p) {
      CouncilPeriod.yearStart => _sok ? 'Ekim' : 'Eylül',
      CouncilPeriod.secondTerm => 'Şubat',
      CouncilPeriod.yearEnd => 'Haziran',
    };
  }

  String get _kademeAdi => switch (_kademe) {
        CouncilLevel.ilkokul => 'İlkokul',
        CouncilLevel.ortaokul => 'Ortaokul',
        CouncilLevel.ortaogretim => 'Ortaöğretim',
        CouncilLevel.bilinmiyor => 'Kademe okul türünden',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: _sok ? 'ŞÖK Tutanağı' : 'Zümre Tutanağı',
        subtitle: _hazir ? 'Tutanak hazır' : 'Maarif Modeli · Yönerge m.${_sok ? 10 : 12}',
        showProfileAvatar: false,
        showDrawerButton: false,
        showBackButton: true,
      ),
      body: SafeArea(child: _hazir ? _sonucEkrani(isDark) : _formEkrani(isDark)),
    );
  }

  Widget _formEkrani(bool isDark) {
    final engel = _engel;
    final siniflik = _sok || CouncilMinutes.isClassroomTeacher(_branch);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _baslik(isDark, 'Toplantı'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in CouncilPeriod.values) ...[
              if (p != CouncilPeriod.yearStart) const SizedBox(width: 8),
              Expanded(child: _donemKutusu(isDark, p)),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _baslik(isDark, 'Bilgiler'),
        _kart(
          isDark,
          Column(
            children: [
              if (!_sok)
                _satir(isDark,
                    anahtar: 'tutanak_kademe',
                    ikon: Icons.school_outlined,
                    etiket: _kademeSecimi == null && _otomatikKademe != CouncilLevel.bilinmiyor
                        ? 'Kademe · okul bilginizden'
                        : 'Kademe',
                    deger: _kademe == CouncilLevel.bilinmiyor ? 'Seçin' : _kademeAdi,
                    onTap: _kademeSec),
              if (!_sok)
                _satir(isDark,
                    anahtar: 'tutanak_ders',
                    ikon: Icons.menu_book_rounded,
                    etiket: _branch.isNotEmpty && _branch == CouncilMinutes.stripRoleSuffix(_profile.branch)
                        ? 'Ders · profilinizden'
                        : 'Ders',
                    deger: _branch.isEmpty ? 'Seçin' : _branch,
                    onTap: _dersSec),
              if (siniflik)
                _satir(isDark,
                    anahtar: 'tutanak_sinif',
                    ikon: Icons.class_outlined,
                    etiket: _sok ? 'Şube' : 'Sınıf',
                    deger: _class == null
                        ? (_classes.isEmpty ? 'Kayıtlı sınıf yok' : 'Seçin')
                        : '${_class!.name}${_class!.subject.trim().isEmpty ? '' : ' · ${_class!.subject}'}',
                    onTap: _classes.isEmpty ? null : _sinifSec),
              _satir(isDark,
                  anahtar: 'tutanak_tarih',
                  ikon: Icons.event_rounded,
                  etiket: 'Tarih',
                  deger: AppDateFormatter.gunAyYilGun(_tarih),
                  onTap: _tarihSec),
              _satir(isDark,
                  anahtar: 'tutanak_saat',
                  ikon: Icons.schedule_rounded,
                  etiket: 'Saat',
                  deger: _saatMetni,
                  onTap: _saatSec),
              _satir(isDark,
                  anahtar: 'tutanak_yer',
                  ikon: Icons.place_outlined,
                  etiket: 'Yer',
                  deger: _yer.text.trim().isEmpty ? 'Yazın' : _yer.text,
                  onTap: _yerSec,
                  son: true),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _hazirGundem(isDark, _gundemKur()),
        if (engel != null) ...[
          const SizedBox(height: 12),
          _serit(isDark, Icons.block_rounded, AppColors.warning, engel),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('tutanak_olustur'),
            onPressed: engel == null ? _olustur : null,
            icon: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
            label: Text('Tutanağı hazırla',
                style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sonucEkrani(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _serit(isDark, Icons.task_alt_rounded, AppColors.success,
            '$_ad hazırlandı. Kararlar e-Kurul ve Zümre Modülüne işlenir; müdür onayından sonra uygulanır.'),
        const SizedBox(height: 14),
        _kagit(isDark),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _eylem(isDark,
                  anahtar: 'tutanak_onizle',
                  ikon: Icons.picture_as_pdf_rounded,
                  baslik: 'PDF',
                  alt: 'aç · paylaş',
                  vurgu: true,
                  onTap: _onizle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _eylem(isDark,
                  anahtar: 'tutanak_gundem',
                  ikon: Icons.format_list_numbered_rounded,
                  baslik: 'Gündem',
                  alt: '${_agenda.length} madde',
                  onTap: () => _git(_GundemSayfasi(
                        agenda: _agenda,
                        degisti: (a) => setState(() => _agenda = a),
                      ))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _eylem(isDark,
                  anahtar: 'tutanak_katilimcilar',
                  ikon: Icons.draw_rounded,
                  baslik: 'İmzalar',
                  alt: '${_attendees.length} kişi',
                  onTap: () => _git(_KatilimciSayfasi(
                        attendees: _attendees,
                        baskan: _baskan,
                        yazman: _yazman,
                        degisti: (a, b, y) => setState(() {
                          _attendees = a;
                          _baskan = b;
                          _yazman = y;
                        }),
                      ))),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            key: const Key('tutanak_yeni'),
            onPressed: () => setState(() => _hazir = false),
            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
            label: const Text('Toplantı bilgilerini değiştir'),
          ),
        ),
      ],
    );
  }

  Future<void> _git(Widget sayfa) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => sayfa));

  // --- seçimler --------------------------------------------------------------

  Future<T?> _listedenSec<T>(String baslik, List<(T, String, bool)> secenekler) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(baslik, style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (deger, ad, secili) in secenekler)
                      ListTile(
                        title: Text(ad),
                        trailing: secili ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(ctx, deger),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kademeSec() async {
    final k = await _listedenSec<CouncilLevel>('Kademe', [
      for (final (l, ad) in const [
        (CouncilLevel.ilkokul, 'İlkokul'),
        (CouncilLevel.ortaokul, 'Ortaokul'),
        (CouncilLevel.ortaogretim, 'Ortaöğretim (lise)'),
      ])
        (l, ad, l == _kademe),
    ]);
    if (k == null) return;
    setState(() => _kademeSecimi = k);
  }

  Future<void> _dersSec() async {
    final b = await _listedenSec<String>('Ders', [
      for (final b in _branslar) (b, b, b == _branch),
    ]);
    if (b == null) return;
    setState(() {
      _branch = b;
      if (!CouncilMinutes.isClassroomTeacher(_branch)) _class = null;
    });
  }

  Future<void> _sinifSec() async {
    final id = await _listedenSec<int>(_sok ? 'Şube' : 'Sınıf', [
      for (final c in _classes)
        if (c.id != null)
          (c.id!, '${c.name}${c.subject.trim().isEmpty ? '' : ' · ${c.subject}'}', c.id == _class?.id),
    ]);
    if (id == null) return;
    setState(() {
      _class = _classes.where((c) => c.id == id).firstOrNull;
      _yer.text = CouncilMinutes.defaultLocation(widget.kind, _class?.name);
    });
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(_tarih.year - 1),
      lastDate: DateTime(_tarih.year + 1, 12, 31),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _saatSec() async {
    final s = await showTimePicker(
      context: context,
      initialTime: _saat,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (s != null) setState(() => _saat = s);
  }

  /// Yer: yazılabilir; okulda en çok kullanılan yerler tek dokunuşla.
  Future<void> _yerSec() async {
    final ctrl = TextEditingController(text: _yer.text);
    final oneriler = {
      'Öğretmenler odası',
      if (_class != null) '${_class!.name} dersliği',
      'Toplantı salonu',
      'Müdür yardımcısı odası',
    };
    final yeni = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplantı yeri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('tutanak_yer_metin'),
              controller: ctrl,
              maxLength: 80,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // ActionChip DEĞİL: uygulamanın chipTheme'i açık temada çipi
                // beyaz üstüne beyaz çiziyor (Cepte'de cihazda ölçüldü).
                for (final o in oneriler)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(ctx, o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(o,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Tamam')),
        ],
      ),
    );
    ctrl.dispose();
    if (yeni != null && mounted) setState(() => _yer.text = yeni.trim());
  }

  // --- parçalar --------------------------------------------------------------

  Widget _baslik(bool isDark, String metin) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      );

  Widget _kart(bool isDark, Widget child) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? _borderDark : _border),
        ),
        child: child,
      );

  Widget _donemKutusu(bool isDark, CouncilPeriod p) {
    final secili = _period == p;
    final onerilen = CouncilMinutes.suggestedPeriod() == p;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('tutanak_donem_${p.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _period = p),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: secili
                ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.08)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: secili ? AppColors.primary : (isDark ? _borderDark : _border),
              width: secili ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _donemAdi(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (secili) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                ],
              ),
              Text(_ayIpucu(p),
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
              if (onerilen) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Önerilen',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _satir(
    bool isDark, {
    required String anahtar,
    required IconData ikon,
    required String etiket,
    required String deger,
    required VoidCallback? onTap,
    bool son = false,
  }) {
    return InkWell(
      key: Key(anahtar),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: son
            ? null
            : BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? _borderDark : _border))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(ikon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiket,
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
                  Text(deger,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  /// Hazır gündem: farkımız içerik; öğretmen ne geleceğini önceden görür.
  Widget _hazirGundem(bool isDark, List<CouncilAgendaItem> g) {
    // Açılış maddesi atlanır; asıl gündem görünsün.
    final gosterilen = g.skip(1).take(3).toList();
    final kalan = g.length - 1 - gosterilen.length;
    return _kart(
      isDark,
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${g.length} gündem maddesi hazır',
                      style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Maarif Modeli',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Yönerge m.${_sok ? 10 : 12} ve TYMM ortak metnine göre · $_kademeAdi',
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            for (final i in gosterilen)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(i.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF334155))),
              ),
            if (kalan > 0)
              Text('… ve $kalan madde daha; hazırladıktan sonra düzenlenebilir.',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  /// Tutanağın kâğıt hâli: dokununca PDF önizleme açılır.
  Widget _kagit(bool isDark) {
    const yazi = Color(0xFF1E293B);
    const ince = TextStyle(fontFamily: 'serif', fontSize: 10.5, height: 1.4, color: yazi);
    final no = switch (_period) {
      CouncilPeriod.yearStart => 1,
      CouncilPeriod.secondTerm => 2,
      CouncilPeriod.yearEnd => 3,
    };
    final okul = _profile.schoolName.trim().isEmpty ? '................ OKULU' : trUpper(_profile.schoolName);
    final baslik = CouncilMinutes.documentTitle(
      kind: widget.kind,
      period: _period,
      branch: CouncilMinutes.titleBranch(profileBranch: _branch),
      className: _class?.name,
    );
    final gosterilen = _agenda.take(5).toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('tutanak_kagit'),
        onTap: _onizle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Text('T.C.', style: ince.copyWith(fontWeight: FontWeight.bold)),
              Text(okul, textAlign: TextAlign.center, style: ince.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(baslik, textAlign: TextAlign.center, style: ince.copyWith(fontSize: 11.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toplantı No: $no    Tarih: ${AppDateFormatter.gunAyYil(_tarih)}    Saat: $_saatMetni\nYer: ${_yer.text}',
                  style: ince,
                ),
              ),
              const Divider(color: _border, height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('GÜNDEM', style: ince.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
              for (final i in gosterilen)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(i.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ince),
                ),
              if (_agenda.length > gosterilen.length)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('… ${_agenda.length - gosterilen.length} madde daha',
                      style: ince.copyWith(color: const Color(0xFF64748B))),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                // Yarım genişlik: dar ekranda iki uzun ad taşıyordu (320 dp).
                children: [
                  Expanded(child: _imza(_sok ? 'Kurul Başkanı' : 'Zümre Başkanı', _baskan, ince)),
                  const SizedBox(width: 12),
                  Expanded(child: _imza('Okul Müdürü', _profile.schoolPrincipalName, ince)),
                ],
              ),
              const SizedBox(height: 10),
              Text('Önizlemek için dokunun',
                  style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imza(String gorev, String ad, TextStyle stil) => Column(
        children: [
          Text(ad.trim().isEmpty ? '................' : ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: stil.copyWith(fontWeight: FontWeight.bold)),
          Text(gorev, maxLines: 1, overflow: TextOverflow.ellipsis, style: stil),
          Text('İmza: ..........', style: stil.copyWith(color: const Color(0xFF94A3B8))),
        ],
      );

  Widget _eylem(
    bool isDark, {
    required String anahtar,
    required IconData ikon,
    required String baslik,
    required String alt,
    required VoidCallback onTap,
    bool vurgu = false,
  }) {
    final yazi = vurgu ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A));
    return Material(
      color: vurgu ? AppColors.primary : (isDark ? const Color(0xFF1E293B) : Colors.white),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key(anahtar),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: vurgu
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? _borderDark : _border),
                ),
          child: Column(
            children: [
              Icon(ikon, color: vurgu ? Colors.white : AppColors.primary),
              const SizedBox(height: 4),
              Text(baslik, style: AppFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: yazi)),
              Text(alt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: vurgu ? Colors.white70 : (isDark ? Colors.white54 : const Color(0xFF64748B)))),
            ],
          ),
        ),
      ),
    );
  }

  /// Bilgi şeridi (uygulamadaki belge ekranlarının biçimi).
  Widget _serit(bool isDark, IconData ikon, Color renk, String metin) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: renk.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(ikon, color: renk, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(metin,
                  style: TextStyle(fontSize: 12, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF0F172A))),
            ),
          ],
        ),
      );
}

/// Gündem maddeleri: dokunup düzenleme, ek madde.
class _GundemSayfasi extends StatefulWidget {
  const _GundemSayfasi({required this.agenda, required this.degisti});
  final List<CouncilAgendaItem> agenda;
  final void Function(List<CouncilAgendaItem>) degisti;

  @override
  State<_GundemSayfasi> createState() => _GundemSayfasiState();
}

class _GundemSayfasiState extends State<_GundemSayfasi> {
  late List<CouncilAgendaItem> _agenda = [...widget.agenda];

  void _kaydet(List<CouncilAgendaItem> a) {
    setState(() => _agenda = a);
    widget.degisti(a);
  }

  Future<void> _duzenle(int i) async {
    final metin = TextEditingController(text: _agenda[i].text);
    final karar = TextEditingController(text: _agenda[i].decision);
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Madde ${i + 1}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: metin,
              maxLines: 4,
              maxLength: 400,
              decoration: const InputDecoration(labelText: 'Gündem', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: karar,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Karar taslağı',
                border: OutlineInputBorder(),
                helperText: CouncilMinutes.decisionHint,
                helperMaxLines: 3,
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    final m = metin.text, k = karar.text;
    metin.dispose();
    karar.dispose();
    if (tamam == true && mounted) {
      _kaydet([..._agenda]..[i] = _agenda[i].copyWith(text: m, decision: k));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gündem (${_agenda.length} madde)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _kaydet(CouncilMinutes.addExtra(_agenda)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ek madde'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _agenda.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) => Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(_agenda[i].text, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_agenda[i].decision, maxLines: 2, overflow: TextOverflow.ellipsis),
            // Yönerge maddesi silinmez; yalnız sonradan eklenen madde.
            trailing: _agenda[i].required
                ? const Icon(Icons.edit_outlined, size: 18)
                : IconButton(
                    tooltip: 'Maddeyi sil',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _kaydet(CouncilMinutes.removeAt(_agenda, i)),
                  ),
            onTap: () => _duzenle(i),
          ),
        ),
      ),
    );
  }
}

/// Katılımcılar (imza sirküsü), başkan ve yazman.
class _KatilimciSayfasi extends StatefulWidget {
  const _KatilimciSayfasi({
    required this.attendees,
    required this.baskan,
    required this.yazman,
    required this.degisti,
  });
  final List<CouncilAttendee> attendees;
  final String baskan;
  final String yazman;
  final void Function(List<CouncilAttendee>, String baskan, String yazman) degisti;

  @override
  State<_KatilimciSayfasi> createState() => _KatilimciSayfasiState();
}

class _KatilimciSayfasiState extends State<_KatilimciSayfasi> {
  late List<CouncilAttendee> _liste = [...widget.attendees];
  late final _baskan = TextEditingController(text: widget.baskan);
  late final _yazman = TextEditingController(text: widget.yazman);

  @override
  void dispose() {
    _baskan.dispose();
    _yazman.dispose();
    super.dispose();
  }

  void _bildir() => widget.degisti(_liste, _baskan.text, _yazman.text);

  Future<void> _duzenle(int i) async {
    final ad = TextEditingController(text: _liste[i].name);
    final brans = TextEditingController(text: _liste[i].branch);
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Katılımcı'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ad,
            maxLength: 40,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: const InputDecoration(labelText: 'Ad soyad', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: brans,
            maxLength: 40,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: const InputDecoration(labelText: 'Branş', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    final a = ad.text, b = brans.text;
    ad.dispose();
    brans.dispose();
    if (tamam == true && mounted) {
      setState(() => _liste = [..._liste]..[i] = _liste[i].copyWith(name: a, branch: b));
      _bildir();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katılımcılar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          setState(() => _liste = [..._liste, const CouncilAttendee(name: '', branch: '')]);
          await _duzenle(_liste.length - 1);
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Öğretmen ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _baskan,
                maxLength: 40,
                onChanged: (_) => _bildir(),
                decoration: const InputDecoration(labelText: 'Başkan', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _yazman,
                maxLength: 40,
                onChanged: (_) => _bildir(),
                decoration: const InputDecoration(labelText: 'Yazman', border: OutlineInputBorder()),
              ),
            ),
          ]),
          for (var i = 0; i < _liste.length; i++)
            Card(
              child: ListTile(
                title: Text(_liste[i].name.trim().isEmpty ? 'Adsız' : _liste[i].name),
                subtitle: Text([
                  _liste[i].branch,
                  if (_liste[i].isChair) 'Başkan',
                ].where((s) => s.trim().isNotEmpty).join(' · ')),
                onTap: () => _duzenle(i),
                trailing: IconButton(
                  tooltip: 'Çıkar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _liste.length <= 1
                      ? null
                      : () {
                          setState(() => _liste = [..._liste]..removeAt(i));
                          _bildir();
                        },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/repositories/student_repository.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
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
  late final List<String> _branslar = [
    for (final b in TeacherBranches.forSchoolType(_profile.schoolType ?? ''))
      if (b != TeacherBranches.other) b,
  ];

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
      _agenda = CouncilMinutes.buildAgenda(kind: widget.kind, period: _period, grade: _grade);
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
        ? const <dynamic>[]
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
        students: [...students],
        meetingNo: switch (_period) {
          CouncilPeriod.yearStart => 1,
          CouncilPeriod.secondTerm => 2,
          CouncilPeriod.yearEnd => 3,
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F4F8),
      appBar: AppBar(title: Text(_sok ? 'ŞÖK Tutanağı' : 'Zümre Tutanağı'), centerTitle: true),
      body: SafeArea(
        child: _hazir ? _sonucEkrani(isDark) : _formEkrani(isDark),
      ),
    );
  }

  Widget _formEkrani(bool isDark) {
    final engel = _engel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _hero(),
        const SizedBox(height: 16),
        _kart(isDark, [
          if (!_sok) ...[
            _etiket('Ders'),
            DropdownButtonFormField<String>(
              key: const Key('tutanak_ders'),
              initialValue: _branslar.contains(_branch) ? _branch : null,
              isExpanded: true,
              hint: Text(_branch.isEmpty ? 'Ders seçin' : _branch),
              decoration: _dekor(isDark),
              items: [for (final b in _branslar) DropdownMenuItem(value: b, child: Text(b))],
              onChanged: (b) => setState(() {
                _branch = b ?? _branch;
                if (!CouncilMinutes.isClassroomTeacher(_branch)) _class = null;
              }),
            ),
            const SizedBox(height: 14),
          ],
          if (_sok || CouncilMinutes.isClassroomTeacher(_branch)) ...[
            _etiket(_sok ? 'Şube' : 'Sınıf seviyesi'),
            if (_classes.isEmpty)
              Text('Kayıtlı sınıf yok. Önce Sınıflarım ekranından bir sınıf ekleyin.',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))
            else
              DropdownButtonFormField<int?>(
                key: const Key('tutanak_sinif'),
                initialValue: _class?.id,
                isExpanded: true,
                decoration: _dekor(isDark),
                items: [
                  for (final c in _classes)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text('${c.name}${c.subject.trim().isEmpty ? '' : ' · ${c.subject}'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _class = _classes.where((c) => c.id == id).firstOrNull;
                  _yer.text = CouncilMinutes.defaultLocation(widget.kind, _class?.name);
                }),
              ),
            const SizedBox(height: 14),
          ],
          _etiket('Toplantı'),
          _secimCubugu(isDark),
          const SizedBox(height: 14),
          TextField(
            key: const Key('tutanak_yer'),
            controller: _yer,
            maxLength: 80,
            decoration: _dekor(isDark, etiket: 'Toplantı yeri', ikon: Icons.place_outlined),
          ),
          const SizedBox(height: 4),
          _secici(
            isDark,
            anahtar: 'tutanak_tarih',
            etiket: 'Tarih',
            deger: AppDateFormatter.gunAyYil(_tarih),
            ikon: Icons.calendar_today_rounded,
            onTap: () async {
              final t = await showDatePicker(
                context: context,
                initialDate: _tarih,
                firstDate: DateTime(_tarih.year - 1),
                lastDate: DateTime(_tarih.year + 1, 12, 31),
              );
              if (t != null) setState(() => _tarih = t);
            },
          ),
          const SizedBox(height: 12),
          _secici(
            isDark,
            anahtar: 'tutanak_saat',
            etiket: 'Saat',
            deger: _saatMetni,
            ikon: Icons.schedule_rounded,
            onTap: () async {
              final s = await showTimePicker(
                context: context,
                initialTime: _saat,
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (s != null) setState(() => _saat = s);
            },
          ),
        ]),
        if (engel != null) ...[
          const SizedBox(height: 12),
          Text(engel, style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            key: const Key('tutanak_olustur'),
            onPressed: engel == null ? _olustur : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Tutanağı oluştur'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Gündem yönergeye göre hazır gelir. Başkan, katılımcılar ve maddeler '
          'oluşturduktan sonra düzenlenebilir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }

  Widget _sonucEkrani(bool isDark) {
    final ozet = [
      CouncilMinutes.periodLabel(_period),
      '${AppDateFormatter.gunAyYil(_tarih)} $_saatMetni',
      if (_class != null) _class!.name,
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_ad hazırlandı.',
                      style: AppFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(ozet, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _eylem(isDark,
            anahtar: 'tutanak_onizle',
            ikon: Icons.visibility_outlined,
            baslik: 'Önizle, paylaş, yazdır',
            alt: 'PDF · taslak; e-Kurul\'a işlenir',
            vurgulu: true,
            onTap: _onizle),
        _eylem(isDark,
            anahtar: 'tutanak_gundem',
            ikon: Icons.format_list_numbered_rounded,
            baslik: 'Gündem ve kararlar',
            alt: '${_agenda.length} madde · dokunup düzenleyin',
            onTap: () => _git(_GundemSayfasi(
                  agenda: _agenda,
                  degisti: (a) => setState(() => _agenda = a),
                ))),
        _eylem(isDark,
            anahtar: 'tutanak_katilimcilar',
            ikon: Icons.groups_rounded,
            baslik: 'Katılımcılar, başkan, yazman',
            alt: '${_attendees.length} kişi · başkan: ${_baskan.isEmpty ? '—' : _baskan}',
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
        _eylem(isDark,
            anahtar: 'tutanak_yeni',
            ikon: Icons.edit_calendar_rounded,
            baslik: 'Toplantı bilgilerini değiştir',
            alt: 'Ders, dönem, tarih, yer',
            onTap: () => setState(() => _hazir = false)),
      ],
    );
  }

  Future<void> _git(Widget sayfa) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => sayfa));

  // --- parçalar ---------------------------------------------------------------

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF7C6FC4), Color(0xFF5B4FA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_sok ? Icons.account_tree_rounded : Icons.groups_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_sok ? 'Şube Öğretmenler Kurulu' : 'Zümre Öğretmenler Kurulu',
                      style: AppFonts.outfit(
                          fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Toplantıyı seçin; gündem ve karar dili yönergeye göre hazır gelir.',
                    style: AppFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _kart(bool isDark, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _etiket(String metin) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(metin, style: AppFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dekor(bool isDark, {String? etiket, IconData? ikon}) => InputDecoration(
        labelText: etiket,
        prefixIcon: ikon == null ? null : Icon(ikon),
        filled: true,
        fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7FB),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  Widget _secimCubugu(bool isDark) => SegmentedButton<CouncilPeriod>(
        key: const Key('tutanak_donem'),
        showSelectedIcon: false,
        segments: [
          for (final p in CouncilPeriod.values)
            ButtonSegment(
              value: p,
              label: Text(switch (p) {
                CouncilPeriod.yearStart => 'Sene başı',
                CouncilPeriod.secondTerm => '2. dönem',
                CouncilPeriod.yearEnd => 'Sene sonu',
              }),
            ),
        ],
        selected: {_period},
        onSelectionChanged: (s) => setState(() => _period = s.first),
      );

  Widget _secici(
    bool isDark, {
    required String anahtar,
    required String etiket,
    required String deger,
    required IconData ikon,
    required VoidCallback onTap,
  }) =>
      InkWell(
        key: Key(anahtar),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: InputDecorator(
          decoration: _dekor(isDark, etiket: etiket, ikon: ikon),
          child: Text(deger, style: const TextStyle(fontSize: 16)),
        ),
      );

  Widget _eylem(
    bool isDark, {
    required String anahtar,
    required IconData ikon,
    required String baslik,
    required String alt,
    required VoidCallback onTap,
    bool vurgulu = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: vurgulu
              ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.10)
              : (isDark ? AppColors.darkCardBackground : Colors.white),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: Key(anahtar),
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(ikon, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(baslik, style: AppFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.w700)),
                        Text(alt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
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
            trailing: const Icon(Icons.edit_outlined, size: 18),
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

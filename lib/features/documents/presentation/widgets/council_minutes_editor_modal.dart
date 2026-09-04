import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../../parent_portal/providers/cloud_communication_provider.dart';
import '../../data/council_minutes.dart';
import '../../utils/council_minutes_pdf_generator.dart';

/// Zümre / ŞÖK taslak tutanak düzenleyici.
///
/// Ağır form (11 ExpansionTile × 2 TextField) ve kadro dinleyicisi ana iş
/// parçacığını kilitliyordu (ANR). Gündem metin olarak listelenir; düzenleme
/// tek maddelik bir pencerede yapılır. Kadro arka planda bir kez okunur.
class CouncilMinutesEditorModal extends ConsumerStatefulWidget {
  final CouncilKind initialKind;
  final ClassModel? initialClass;
  final List<StudentModel>? initialStudents;

  const CouncilMinutesEditorModal({
    super.key,
    required this.initialKind,
    this.initialClass,
    this.initialStudents,
  });

  static Future<void> show(
    BuildContext context, {
    required CouncilKind kind,
    ClassModel? classModel,
    List<StudentModel>? students,
  }) async {
    final request = await ResponsiveBottomSheet.show<_CouncilPdfRequest>(
      context: context,
      title: CouncilMinutes.kindLabel(kind),
      maxFactor: 0.92,
      child: CouncilMinutesEditorModal(
        initialKind: kind,
        initialClass: classModel,
        initialStudents: students,
      ),
    );
    if (request == null || !context.mounted) return;
    await PdfPreviewScreen.open(
      context,
      title: request.title,
      subtitle: request.subtitle,
      fileName: request.fileName,
      documentBuilder: request.builder,
    );
  }

  @override
  ConsumerState<CouncilMinutesEditorModal> createState() =>
      _CouncilMinutesEditorModalState();
}

class _CouncilMinutesEditorModalState
    extends ConsumerState<CouncilMinutesEditorModal> {
  late CouncilKind _kind;
  late CouncilPeriod _period;
  ClassModel? _class;
  late final List<ClassModel> _classes;
  late final TeacherProfileModel _profile;

  late final TextEditingController _dateCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _chairCtrl;
  late final TextEditingController _secretaryCtrl;

  List<CouncilAgendaItem> _agenda = const [];
  List<CouncilAttendee> _attendees = const [];
  bool _staffLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _period = CouncilMinutes.suggestedPeriod();
    _class = widget.initialClass;
    _classes = ref.read(classListProvider).valueOrNull ?? const [];
    _profile = ref.read(teacherProfileProvider);
    if (_class == null && _classes.isNotEmpty) {
      _class = _classes.where((c) => c.isHomeroom).firstOrNull ?? _classes.first;
    }

    final now = DateTime.now();
    _dateCtrl = TextEditingController(text: AppDateFormatter.gunAyYil(now));
    _timeCtrl = TextEditingController(text: '15:00');
    _placeCtrl = TextEditingController(
      text: CouncilMinutes.defaultLocation(_kind, _class?.name),
    );
    _chairCtrl = TextEditingController(text: _profile.fullName);
    _secretaryCtrl = TextEditingController();
    _reloadAgenda();
    _attendees = CouncilMinutes.resolveAttendees(
      kind: _kind,
      teacherName: _profile.fullName,
      teacherBranch: _profile.branch,
    );
    unawaited(_loadStaffOnce());
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _placeCtrl.dispose();
    _chairCtrl.dispose();
    _secretaryCtrl.dispose();
    super.dispose();
  }

  int? get _grade =>
      _class == null ? null : CouncilMinutes.gradeFromClassName(_class!.name);

  bool get _sokOk => CouncilMinutes.sokPermitted(
        grade: _grade,
        schoolType: _profile.schoolType,
      );

  bool get _canGenerate {
    if (_kind == CouncilKind.sok) {
      if (_class == null || _class!.id == null) return false;
      if (!_sokOk) return false;
    }
    return _agenda.isNotEmpty;
  }

  void _reloadAgenda() {
    _agenda = CouncilMinutes.buildAgenda(
      kind: _kind,
      period: _period,
      grade: _grade,
    );
    _placeCtrl.text = CouncilMinutes.defaultLocation(_kind, _class?.name);
  }

  Future<void> _loadStaffOnce() async {
    if (_staffLoadStarted) return;
    _staffLoadStarted = true;
    final classId = _class?.id;
    final uid = TeacherIdentity.resolve(_profile);
    if (classId == null || !CloudIds.isValidUid(uid)) return;

    try {
      final cloudId = CloudIds.classId(teacherUid: uid, localClassId: classId);
      final staff = await ref
          .read(classStaffProvider(cloudId).future)
          .timeout(const Duration(seconds: 2));
      if (!mounted || staff.isEmpty) return;
      final mapped = [
        for (final m in staff)
          CouncilAttendee(
            name: m.teacherName,
            branch: m.branch,
            present: true,
            isChair: m.isHomeroom,
          ),
      ];
      final next = CouncilMinutes.resolveAttendees(
        kind: _kind,
        teacherName: _profile.fullName,
        teacherBranch: _profile.branch,
        staff: mapped,
      );
      if (!mounted) return;
      setState(() {
        _attendees = next;
        final chair = next.where((a) => a.isChair).firstOrNull;
        if (chair != null && _chairCtrl.text.trim() == _profile.fullName) {
          _chairCtrl.text = chair.name;
        }
      });
    } on Object {
      // Kadro gelmezse profil satırı yeter; donma olmasın.
    }
  }

  void _preview() {
    if (!_canGenerate) return;
    final year = (_class?.academicYear.trim().isNotEmpty == true)
        ? _class!.academicYear
        : CouncilMinutes.academicYearLabel();
    final students = widget.initialStudents ??
        (_class?.id == null
            ? const <StudentModel>[]
            : (ref.read(studentListProvider(_class!.id!)).valueOrNull ??
                const <StudentModel>[]));
    final attendees = _attendees
        .where((a) => a.name.trim().isNotEmpty || a.branch.trim().isNotEmpty)
        .toList();
    final kindLabel = _kind == CouncilKind.sok ? 'SOK' : 'Zumre';
    final tag = _kind == CouncilKind.sok
        ? (_class?.name ?? 'sube')
        : (_profile.branch.trim().isEmpty ? 'alan' : _profile.branch);
    Navigator.of(context).pop(
      _CouncilPdfRequest(
        title: CouncilMinutes.kindLabel(_kind),
        subtitle: 'Taslak tutanak · ${CouncilMinutes.periodLabel(_period)}',
        fileName:
            '${kindLabel}_Tutanagi_${tag}_${CouncilMinutes.periodLabel(_period)}.pdf',
        builder: (_) => CouncilMinutesPdfGenerator.build(
          kind: _kind,
          period: _period,
          schoolName: _profile.schoolName,
          teacherName: _profile.fullName,
          principalName: _profile.schoolPrincipalName,
          branch: CouncilMinutes.titleBranch(profileBranch: _profile.branch),
          academicYear: year,
          meetingDate: _dateCtrl.text.trim(),
          meetingTime: _timeCtrl.text.trim(),
          meetingLocation: _placeCtrl.text.trim(),
          chairName: _chairCtrl.text.trim().isEmpty
              ? _profile.fullName
              : _chairCtrl.text.trim(),
          secretaryName: _secretaryCtrl.text.trim(),
          attendees: attendees,
          agenda: _agenda,
          city: _profile.city,
          district: _profile.district,
          className: _class?.name,
          students: students,
          meetingNo: _period == CouncilPeriod.yearStart
              ? 1
              : _period == CouncilPeriod.secondTerm
                  ? 2
                  : 3,
        ),
      ),
    );
  }

  Future<void> _editAgenda(int index) async {
    final item = _agenda[index];
    final textCtrl = TextEditingController(text: item.text);
    final decisionCtrl = TextEditingController(text: item.decision);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Madde ${index + 1}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    labelText: 'Gündem',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: decisionCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Karar taslağı',
                    border: OutlineInputBorder(),
                    helperText: '“Karar verildi” ile bitsin',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    final text = textCtrl.text;
    final decision = decisionCtrl.text;
    textCtrl.dispose();
    decisionCtrl.dispose();
    if (saved == true && mounted) {
      setState(() {
        _agenda[index] = _agenda[index].copyWith(
          text: text,
          decision: decision,
        );
      });
    }
  }

  Future<void> _editAttendee(int index) async {
    final a = _attendees[index];
    final nameCtrl = TextEditingController(text: a.name);
    final branchCtrl = TextEditingController(text: a.branch);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Katılımcı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                maxLength: 40,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: const InputDecoration(
                  labelText: 'Ad soyad',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchCtrl,
                maxLength: 40,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: const InputDecoration(
                  labelText: 'Branş',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    final name = nameCtrl.text;
    final branch = branchCtrl.text;
    nameCtrl.dispose();
    branchCtrl.dispose();
    if (saved == true && mounted) {
      setState(() {
        _attendees[index] = _attendees[index].copyWith(
          name: name,
          branch: branch,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final muted = isDark ? Colors.white70 : AppColors.textSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(
          isDark,
          icon: Icons.info_outline_rounded,
          color: AppColors.info,
          text:
              'Taslak tutanak. Kararlar e-Kurul\'a işlenir. Maddeye dokunarak düzenleyin.',
        ),
        const SizedBox(height: 12),
        _label('Kurul', labelColor),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(
              isDark,
              CouncilMinutes.kindLabel(CouncilKind.zumre),
              _kind == CouncilKind.zumre,
              () => setState(() {
                _kind = CouncilKind.zumre;
                _reloadAgenda();
                _attendees = CouncilMinutes.resolveAttendees(
                  kind: _kind,
                  teacherName: _profile.fullName,
                  teacherBranch: _profile.branch,
                  staff: _attendees,
                );
              }),
            ),
            _chip(
              isDark,
              CouncilMinutes.kindLabel(CouncilKind.sok),
              _kind == CouncilKind.sok,
              () => setState(() {
                _kind = CouncilKind.sok;
                _reloadAgenda();
                _attendees = CouncilMinutes.resolveAttendees(
                  kind: _kind,
                  teacherName: _profile.fullName,
                  teacherBranch: _profile.branch,
                  staff: _attendees,
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _label('Toplantı dönemi', labelColor),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in CouncilPeriod.values)
              _chip(
                isDark,
                CouncilMinutes.periodLabel(p),
                _period == p,
                () => setState(() {
                  _period = p;
                  _reloadAgenda();
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _label(
          _kind == CouncilKind.sok ? 'Şube (zorunlu)' : 'Sınıf (isteğe bağlı)',
          labelColor,
        ),
        const SizedBox(height: 6),
        if (_classes.isEmpty)
          Text(
            'Kayıtlı sınıf yok. ŞÖK için önce bir şube ekleyin.',
            style: TextStyle(fontSize: 12, color: muted),
          )
        else
          DropdownButtonFormField<int?>(
            key: ValueKey('class_${_kind}_${_class?.id}'),
            initialValue: _class?.id,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              if (_kind == CouncilKind.zumre)
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sınıf seçme — branş zümresi'),
                ),
              ..._classes.map(
                (c) => DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(
                    '${c.name}${c.subject.trim().isEmpty ? '' : ' · ${c.subject}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (id) {
              setState(() {
                _class = id == null
                    ? null
                    : _classes.where((c) => c.id == id).firstOrNull;
                _reloadAgenda();
                _staffLoadStarted = false;
                _attendees = CouncilMinutes.resolveAttendees(
                  kind: _kind,
                  teacherName: _profile.fullName,
                  teacherBranch: _profile.branch,
                );
              });
              unawaited(_loadStaffOnce());
            },
          ),
        if (_kind == CouncilKind.sok && !_sokOk) ...[
          const SizedBox(height: 10),
          _banner(
            isDark,
            icon: Icons.block_rounded,
            color: AppColors.warning,
            text: CouncilMinutes.sokBlockedReason(
              grade: _grade,
              schoolType: _profile.schoolType,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dateCtrl,
                maxLength: 24,
                decoration: _dec('Tarih', Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _timeCtrl,
                maxLength: 10,
                decoration: _dec('Saat', Icons.access_time_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _placeCtrl,
          maxLength: 80,
          decoration: _dec('Yer', Icons.place_outlined),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chairCtrl,
                maxLength: 40,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: _dec('Başkan', Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _secretaryCtrl,
                maxLength: 40,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: _dec('Yazman', Icons.edit_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _label('Katılımcılar', labelColor),
        const SizedBox(height: 6),
        for (var i = 0; i < _attendees.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              _attendees[i].name.trim().isEmpty
                  ? 'Adsız'
                  : _attendees[i].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                _attendees[i].branch,
                if (_attendees[i].isChair) 'Başkan',
                if (!_attendees[i].present) 'Katılmadı',
              ].where((s) => s.trim().isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => unawaited(_editAttendee(i)),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: _attendees.length <= 1
                  ? null
                  : () => setState(() {
                        _attendees = [..._attendees]..removeAt(i);
                      }),
            ),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _attendees = [
                ..._attendees,
                const CouncilAttendee(name: '', branch: ''),
              ];
            });
            unawaited(_editAttendee(_attendees.length - 1));
          },
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Öğretmen ekle'),
        ),
        const SizedBox(height: 8),
        _label('Gündem (${_agenda.length} madde) — dokunarak düzenle', labelColor),
        const SizedBox(height: 8),
        for (var i = 0; i < _agenda.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                title: Text(
                  _agenda[i].text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _agenda[i].decision,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => unawaited(_editAgenda(i)),
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() {
            _agenda = CouncilMinutes.addExtra(_agenda);
          }),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ek madde'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _canGenerate ? _preview : null,
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            label: Text(
              'Taslağı önizle',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _chip(bool isDark, String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onTap(),
    );
  }

  Widget _banner(
    bool isDark, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
    );
  }

  InputDecoration _dec(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

class _CouncilPdfRequest {
  final String title;
  final String subtitle;
  final String fileName;
  final Future<Uint8List> Function(PdfPageFormat format) builder;

  const _CouncilPdfRequest({
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.builder,
  });
}

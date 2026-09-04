import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../../../outcomes/data/repositories/curriculum_outcome_repository.dart';
import '../../data/bep_developmental_bank.dart';
import '../../data/bep_subject_codes.dart';
import '../../data/models/bep_models.dart';
import '../../data/repositories/bep_repository.dart';
import 'bep_plan_view.dart';

class BepListView extends StatefulWidget {
  final ClassModel classModel;
  final List<StudentModel> students;
  final TeacherProfileModel teacher;

  const BepListView({
    super.key,
    required this.classModel,
    required this.students,
    required this.teacher,
  });

  @override
  State<BepListView> createState() => _BepListViewState();
}

class _BepListViewState extends State<BepListView> {
  final _repo = BepRepository();
  late final String _year;
  late final int _classGradeHint;
  List<BepStudentSummary> _summaries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _year = widget.classModel.academicYear.trim().isNotEmpty
        ? widget.classModel.academicYear
        : AppDateFormatter.academicYearLabel();
    _classGradeHint = int.tryParse(
          InputSanitizer.extractGradeLevel(widget.classModel.name) ?? '',
        ) ??
        0;
    _reload();
  }

  Future<void> _reload() async {
    final list = await _repo.summariesForClass(
      students: widget.students,
      academicYear: _year,
    );
    if (!mounted) return;
    setState(() {
      _summaries = list;
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _itemsFor({
    required BepTrack track,
    required int grade,
  }) async {
    if (!track.usesCurriculum) {
      return BepDevelopmentalBank.dropdownItems();
    }
    if (grade < 1) return const [];
    return BepSubjectCodes.uniqueByCode(
      await CurriculumOutcomeRepository().getAvailableSubjects(grade),
    );
  }

  BepStudentSummary? _rowFor(int? studentId) {
    if (studentId == null) return null;
    return _summaries.where((e) => e.studentId == studentId).firstOrNull;
  }

  Future<void> _openPlan(StudentModel student, int planId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BepPlanView(
          planId: planId,
          student: student,
          classModel: widget.classModel,
          teacher: widget.teacher,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _createFor(StudentModel student) async {
    if (student.id == null) return;
    final existing = await _repo.plansForStudent(student.id!, year: _year);
    if (!mounted) return;
    final used = existing.map((p) => p.subjectCode).where((c) => c.isNotEmpty).toSet();

    var track = BepTrack.guess(
      className: widget.classModel.name,
      branch: widget.teacher.branch,
      classGrade: _classGradeHint,
    );
    var grade = _classGradeHint;
    if (track.usesCurriculum) {
      if (!track.grades.contains(grade)) {
        grade = track.grades.contains(_classGradeHint)
            ? _classGradeHint
            : track.grades.first;
      }
    } else {
      grade = 0;
    }
    final schoolCtrl = TextEditingController(text: widget.teacher.schoolName);
    var startMonth = 'Eylül';
    var copyPrev = false;
    var items = await _itemsFor(track: track, grade: grade);
    items = items.where((s) => !used.contains(s['subject_code'] as String? ?? '')).toList();
    if (!mounted) {
      schoolCtrl.dispose();
      return;
    }
    if (items.isEmpty) {
      schoolCtrl.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kademe/ders için liste yok.')),
      );
      return;
    }

    final guessed = BepSubjectCodes.guess(widget.teacher.branch);
    Map<String, dynamic> selected = items.firstWhere(
      (s) => s['subject_code'] == guessed,
      orElse: () => items.first,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> reloadItems() async {
              var next = await _itemsFor(track: track, grade: grade);
              next = next
                  .where((s) => !used.contains(s['subject_code'] as String? ?? ''))
                  .toList();
              if (!ctx.mounted) return;
              setLocal(() {
                items = next;
                if (items.isEmpty) return;
                selected = items.firstWhere(
                  (s) => s['subject_code'] == selected['subject_code'],
                  orElse: () => items.first,
                );
              });
            }

            return AlertDialog(
              title: Text('Hızlı BEP · ${student.fullName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Kaynaştırma, hafif düzey zihin/otizm, görme-işitme → İlköğretim.\n'
                        'Uygulama okulu, orta/ağır sınıf → Özel eğitim.\n'
                        'Lise kaynaştırma → Lise.\n'
                        'Öğrenci no zorunlu değil; kademe ve ders zorunlu.',
                        style: TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: schoolCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Okul adı *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<BepTrack>(
                      key: ValueKey(track),
                      initialValue: track,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kademe *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final t in BepTrack.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() {
                          track = v;
                          if (v.usesCurriculum) {
                            grade = v.grades.contains(_classGradeHint)
                                ? _classGradeHint
                                : v.grades.first;
                          } else {
                            grade = 0;
                          }
                        });
                        reloadItems();
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(track.hint, style: const TextStyle(fontSize: 11.5, height: 1.3)),
                    if (track.usesCurriculum) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        key: ValueKey('g-$grade-${track.id}'),
                        initialValue: track.grades.contains(grade) ? grade : track.grades.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sınıf seviyesi *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final g in track.grades)
                            DropdownMenuItem(value: g, child: Text('$g. sınıf')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => grade = v);
                          reloadItems();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('${track.id}-$grade-${selected['subject_code']}'),
                      initialValue: items.any((s) => s['subject_code'] == selected['subject_code'])
                          ? selected['subject_code'] as String
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: track.usesCurriculum ? 'Ders *' : 'Gelişim alanı *',
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final s in items)
                          DropdownMenuItem(
                            value: s['subject_code'] as String,
                            child: Text(
                              '${s['subject_name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (code) {
                        setLocal(() {
                          selected = items.firstWhere(
                            (s) => s['subject_code'] == code,
                            orElse: () => items.first,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(startMonth),
                      initialValue: startMonth,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Plan başlangıç ayı *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final m in BepTrack.months)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => startMonth = v);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: copyPrev,
                      onChanged: (v) => setLocal(() => copyPrev = v ?? false),
                      title: const Text(
                        'Geçen yılın aynı alan amaçlarını kopyala',
                        style: TextStyle(fontSize: 13),
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
                  onPressed: items.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: const Text('İleri'),
                ),
              ],
            );
          },
        );
      },
    );
    final schoolName = schoolCtrl.text.trim();
    schoolCtrl.dispose();
    if (ok != true || student.id == null) return;

    final plan = await _repo.createPlan(
      student: student,
      classId: widget.classModel.id ?? 0,
      subject: selected['subject_name'] as String? ?? '',
      subjectCode: selected['subject_code'] as String? ?? '',
      gradeLevel: grade,
      teacherName: widget.teacher.fullName,
      principalName: widget.teacher.schoolPrincipalName,
      isHomeroom: widget.classModel.isHomeroom,
      academicYear: _year,
      copyFromPreviousYear: copyPrev,
      placement: track.defaultPlacement,
      programKind: track.programKind,
      track: track,
      startMonth: startMonth,
      schoolName: schoolName,
    );
    if (!mounted || plan.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BepPlanView(
          planId: plan.id!,
          student: student,
          classModel: widget.classModel,
          teacher: widget.teacher,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: const CustomAppBar(
        title: 'BEP hedef takibi',
        showProfileAvatar: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.students.isEmpty
              ? const Center(child: Text('Önce sınıfa öğrenci ekleyin.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${widget.classModel.name} · $_year\n'
                      'Kademe seç → ders/alan seç → Yapıyor/Yapamıyor işaretle → PDF.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final s in widget.students) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text(
                          s.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      for (final p in _rowFor(s.id)?.plans ?? const <BepPlanListItem>[])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(
                            p.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${p.gradeLevel > 0 ? '${p.gradeLevel}. sınıf' : 'Gelişim'}'
                            ' · ${p.achievedCount}/${p.shortGoalCount} amaç',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openPlan(s, p.planId),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_circle_outline),
                        title: const Text('Ders / gelişim alanı aç'),
                        subtitle: const Text(
                          'Kademe, yerleştirme ve dersi veya gelişim alanını seç',
                        ),
                        onTap: () => _createFor(s),
                      ),
                    ],
                  ],
                ),
    );
  }
}

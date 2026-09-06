import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/repositories/class_repository.dart';
import '../../../../data/repositories/student_repository.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../schedule/models/lesson_model.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/legacy_crud_methods.dart';
import '../../data/teacher_file_model.dart';
import '../../data/teacher_file_repository.dart';
import '../../utils/teacher_file_pdf_generator.dart';
import 'teacher_file_info_view.dart';

/// Öğretmen ders yılı dosyası — teftişte sunulan klasör.
///
/// ## Neden bu ekran
/// Öğretmen her yıl aynı evrakları elle hazırlıyor: kapak, Atatürk
/// köşesi, İstiklâl Marşı, özlük künyesi, ders programı… Hepsi
/// zaten uygulamada olan veriden üretilebiliyordu.
///
/// ## Neden hem tek tek hem toplu
/// Teftiş için tek dosya basmak pratik; ama öğretmen yıl içinde
/// tek bir formu (mesela veli görüşme çizelgesi) yeniden basmak
/// isteyebilir. İkisi de var.
class TeacherFileView extends ConsumerStatefulWidget {
  const TeacherFileView({super.key});

  @override
  ConsumerState<TeacherFileView> createState() => _TeacherFileViewState();
}

class _TeacherFileViewState extends ConsumerState<TeacherFileView> {
  final _repo = TeacherFileRepository();

  TeacherFileInfo _bilgi = const TeacherFileInfo();
  List<TeacherFileLesson> _dersler = const [];
  List<TeacherFileClass> _siniflar = const [];

  /// Toplu üretim için seçilenler. Boşsa "tümü" demek.
  final Set<TeacherFileDoc> _secili = {};

  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final bilgi = await _repo.read();

    // Ders programı — `dersler` tablosundan.
    final ham = await DatabaseHelper.instance.dersleriGetir();
    final dersler = [
      for (final m in ham)
        () {
          final l = LessonModel.fromMap(m);
          return TeacherFileLesson(
            ders: l.lessonName,
            sinif: l.className,
            gun: l.day,
            saat: l.lessonHourIndex,
          );
        }(),
    ];

    // Sınıflar ve öğrenci sayıları.
    final siniflar = <TeacherFileClass>[];
    for (final c in await ClassRepository().getAllClasses()) {
      final id = c.id;
      final ogrenciler = id == null
          ? const []
          : await StudentRepository().getStudentsByClassId(id);
      siniflar.add(TeacherFileClass(
        ad: c.name,
        ders: c.subject,
        ogrenciSayisi: ogrenciler.length,
      ));
    }

    if (!mounted) return;
    setState(() {
      _bilgi = bilgi;
      _dersler = dersler;
      _siniflar = siniflar;
      _yukleniyor = false;
    });
  }

  Future<void> _bilgileriDuzenle() async {
    final sonuc = await Navigator.push<TeacherFileInfo>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherFileInfoView(baslangic: _bilgi),
      ),
    );
    if (sonuc == null || !mounted) return;
    await _repo.write(sonuc);
    if (!mounted) return;
    setState(() => _bilgi = sonuc);
  }

  Future<void> _uret({TeacherFileDoc? tek}) async {
    final teacher = ref.read(teacherProfileProvider);

    if (tek != null) {
      await PdfPreviewScreen.open(
        context,
        title: tek.ad,
        subtitle: teacher.fullName,
        fileName: '${tek.ad.replaceAll(' ', '_')}.pdf',
        documentBuilder: (_) => TeacherFilePdfGenerator.tekBelge(
          belge: tek,
          teacher: teacher,
          bilgi: _bilgi,
          dersler: _dersler,
          siniflar: _siniflar,
        ),
      );
      return;
    }

    final sayi =
        _secili.isEmpty ? TeacherFileDoc.values.length : _secili.length;
    await PdfPreviewScreen.open(
      context,
      title: 'Öğretmen Dosyası',
      subtitle: '$sayi belge · ${teacher.fullName}',
      fileName: 'Ogretmen_Dosyasi.pdf',
      documentBuilder: (_) => TeacherFilePdfGenerator.tumDosya(
        teacher: teacher,
        bilgi: _bilgi,
        dersler: _dersler,
        siniflar: _siniflar,
        secili: _secili.isEmpty ? null : _secili,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacher = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Öğretmen Dosyası',
        subtitle: 'Teftiş evrakları',
        showProfileAvatar: false,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                children: [
                  _ozlukKarti(isDark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Belgeler',
                          style: AppFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Seçim yapılmadıysa "tümü" basılır; bu düğme
                      // seçimi hızlıca temizler.
                      if (_secili.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(_secili.clear),
                          child: const Text('Seçimi temizle'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _secili.isEmpty
                        ? 'Hiçbiri seçili değilse tümü basılır. Bir belgeye '
                            'dokunarak tek başına önizleyebilirsiniz.'
                        : '${_secili.length} belge seçildi.',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final b in TeacherFileDoc.values) ...[
                    _belgeSatiri(isDark, b, teacher.schoolName),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
      floatingActionButton: _yukleniyor
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _uret(),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _secili.isEmpty
                    ? 'Tüm dosyayı oluştur'
                    : 'Seçilenleri oluştur (${_secili.length})',
              ),
            ),
    );
  }

  /// Özlük bilgileri kartı — eksikse belgede noktalı satır çıkar.
  Widget _ozlukKarti(bool isDark) {
    final dolu = _bilgi.doluAlanSayisi;
    const toplam = TeacherFileInfo.toplamAlanSayisi;
    final tamam = dolu == toplam;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _bilgileriDuzenle,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: tamam
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (tamam ? AppColors.primary : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tamam ? Icons.badge_rounded : Icons.edit_note_rounded,
                  size: 19,
                  color: tamam ? AppColors.primary : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Özlük Bilgileri',
                      style: AppFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tamam
                          ? 'Tamamlandı · $dolu/$toplam alan'
                          : 'Eksik alanlar belgede noktalı çıkar · '
                              '$dolu/$toplam',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        color: tamam
                            ? AppColors.primary
                            : const Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sicil, mezuniyet, göreve başlama · yalnızca bu '
                      'cihazda saklanır',
                      style: AppFonts.outfit(
                        fontSize: 10.5,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: isDark ? Colors.white38 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// Tek belge satırı: onay kutusu toplu üretim için, gövde önizleme.
  Widget _belgeSatiri(bool isDark, TeacherFileDoc b, String okul) {
    final secili = _secili.contains(b);

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () => _uret(tek: b),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: secili
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: secili,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _secili.add(b);
                  } else {
                    _secili.remove(b);
                  }
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.ad,
                      style: AppFonts.outfit(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      b.aciklama,
                      style: AppFonts.outfit(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.visibility_outlined,
                  size: 17, color: isDark ? Colors.white38 : Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

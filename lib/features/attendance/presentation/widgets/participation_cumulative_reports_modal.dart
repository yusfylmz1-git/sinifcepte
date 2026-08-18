import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../providers/classroom_participation_provider.dart';
import '../../utils/participation_cumulative_pdf_generator.dart';
import '../../utils/participation_whatsapp_helper.dart';

enum StudentMeetingFilter { all, needsAttention, successful }

/// SınıfCepte - Odaklanma Korumalı, Tek Öğrenci Vitrinli ve Akıllı Veli Toplantısı Rapor Merkezi
class ParticipationCumulativeReportsModal extends ConsumerStatefulWidget {
  final int? initialClassId;

  const ParticipationCumulativeReportsModal({super.key, this.initialClassId});

  static Future<void> show(BuildContext context, {int? initialClassId}) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParticipationCumulativeReportsModal(initialClassId: initialClassId),
    );
  }

  @override
  ConsumerState<ParticipationCumulativeReportsModal> createState() =>
      _ParticipationCumulativeReportsModalState();
}

class _ParticipationCumulativeReportsModalState
    extends ConsumerState<ParticipationCumulativeReportsModal> {
  int? _selectedClassId;
  DateTime _meetingDate = DateTime.now();
  bool _showOfficialArchiveSection = false;
  bool _isActionLoading = false;
  bool _isMeetingDataLoading = false;
  bool _showAllStudentsList = false;
  StudentMeetingFilter _filterStatus = StudentMeetingFilter.all;

  // Cached Meeting Report Data (Prevents FutureBuilder unmounting & focus loss!)
  Map<String, dynamic>? _meetingReportData;
  int? _selectedStudentId;

  final TextEditingController _studentSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _studentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classes = ref.read(classListProvider).valueOrNull ?? [];
      if (classes.isNotEmpty) {
        _selectedClassId ??= classes.first.id;
        if (_selectedClassId != null) {
          _loadMeetingData();
        }
      }
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Veli Toplantısı verilerini arka planda çeker ve state'e kaydeder
  Future<void> _loadMeetingData() async {
    if (_selectedClassId == null) return;
    setState(() => _isMeetingDataLoading = true);
    try {
      final repo = ref.read(classroomParticipationRepoProvider);
      final formattedDate = _meetingDate.toIso8601String().split('T').first;
      final data = await repo.getClassCumulativeReportData(
        _selectedClassId!,
        endDate: formattedDate,
      );
      if (mounted) {
        final students = (data['students'] as List<dynamic>? ?? []);
        setState(() {
          _meetingReportData = data;
          _isMeetingDataLoading = false;
          if (students.isNotEmpty) {
            _selectedStudentId ??= (students.first['studentId'] as int?);
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('_loadMeetingData hatası: $e\n$stackTrace');
      if (mounted) setState(() => _isMeetingDataLoading = false);
    }
  }

  /// Belirtilen dönem veya tarih aralığına göre rapor verisi çeker
  Future<Map<String, dynamic>?> _fetchReportForRange({
    String? startDate,
    String? endDate,
  }) async {
    if (_selectedClassId == null) return null;
    final repo = ref.read(classroomParticipationRepoProvider);
    return await repo.getClassCumulativeReportData(
      _selectedClassId!,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Veli Toplantısı Kılavuzu Üret (Dönem Başından Seçilen Tarihe Kadar)
  Future<void> _generateMeetingReport({required bool isShare}) async {
    if (_selectedClassId == null) return;
    setState(() => _isActionLoading = true);
    try {
      final data = _meetingReportData ??
          await _fetchReportForRange(
            endDate: _meetingDate.toIso8601String().split('T').first,
          );
      if (data == null) return;

      final profile = ref.read(teacherProfileProvider);
      final turkishDate = AppDateFormatter.formatTurkishDate(_meetingDate);

      final pdfBytes = await ParticipationCumulativePdfGenerator.generateParentMeetingGuidePdf(
        reportData: data,
        teacherName: profile.fullName,
        schoolName: profile.schoolName,
        meetingDateText: turkishDate,
      );

      final filename = '${data['className']}_Veli_Toplantisi_Raporu.pdf';
      if (isShare) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Veli toplantısı raporu hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// 1. Dönem Raporu Üret
  Future<void> _generateTerm1Report({required bool isShare}) async {
    if (_selectedClassId == null) return;
    setState(() => _isActionLoading = true);
    try {
      final currentYear = DateTime.now().year;
      final data = await _fetchReportForRange(
        startDate: '$currentYear-09-01',
        endDate: '${currentYear + 1}-01-31',
      );
      if (data == null) return;

      final profile = ref.read(teacherProfileProvider);
      final pdfBytes = await ParticipationCumulativePdfGenerator.generateOfficialAdministrativePdf(
        reportData: data,
        teacherName: profile.fullName,
        termName: '$currentYear-${currentYear + 1} Eğitim-Öğretim Yılı 1. Dönem Sonu',
        schoolName: profile.schoolName,
      );

      final filename = '${data['className']}_1_Donem_Katilim_Raporu.pdf';
      if (isShare) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('1. Dönem raporu hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// 2. Dönem Raporu Üret
  Future<void> _generateTerm2Report({required bool isShare}) async {
    if (_selectedClassId == null) return;
    setState(() => _isActionLoading = true);
    try {
      final currentYear = DateTime.now().year;
      final data = await _fetchReportForRange(
        startDate: '${currentYear + 1}-02-01',
        endDate: '${currentYear + 1}-06-30',
      );
      if (data == null) return;

      final profile = ref.read(teacherProfileProvider);
      final pdfBytes = await ParticipationCumulativePdfGenerator.generateOfficialAdministrativePdf(
        reportData: data,
        teacherName: profile.fullName,
        termName: '$currentYear-${currentYear + 1} Eğitim-Öğretim Yılı 2. Dönem Sonu',
        schoolName: profile.schoolName,
      );

      final filename = '${data['className']}_2_Donem_Katilim_Raporu.pdf';
      if (isShare) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('2. Dönem raporu hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Yıl Sonu Raporu Üret
  Future<void> _generateFullYearReport({required bool isShare}) async {
    if (_selectedClassId == null) return;
    setState(() => _isActionLoading = true);
    try {
      final currentYear = DateTime.now().year;
      final data = await _fetchReportForRange();
      if (data == null) return;

      final profile = ref.read(teacherProfileProvider);
      final pdfBytes = await ParticipationCumulativePdfGenerator.generateOfficialAdministrativePdf(
        reportData: data,
        teacherName: profile.fullName,
        termName: '$currentYear-${currentYear + 1} Eğitim-Öğretim Yılı Genel Kümülatif Sonu',
        schoolName: profile.schoolName,
      );

      final filename = '${data['className']}_Yil_Sonu_Katilim_Raporu.pdf';
      if (isShare) {
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: filename,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Yıl sonu raporu hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  /// Toplantıda Veli ile Konuşurken Kullanılacak Akıllı Cümle Önerisi
  String _getMeetingTalkingTip({
    required double hwRate,
    required double matRate,
    required double avgStars,
    required String sName,
  }) {
    if (hwRate < 60 && matRate < 70) {
      return 'Evde ödev takibi ve ders araç-gereç hazırlığı konusunda veli desteği ivedilikle artırılmalı.';
    } else if (hwRate < 60) {
      return 'Ödev teslimlerinde aksama var. Evde düzenli çalışma saati ve ödev kontrol desteği önerilir.';
    } else if (matRate < 70) {
      return 'Ders araç-gereçlerini (kitap/defter) evde unutma sıklığı arttı, çanta hazırlığının akşamdan yapılması tavsiye edilir.';
    } else if (avgStars < 2.0) {
      return 'Derse katılım ve odaklanma konusunda çekingen kalıyor, evde özgüven ve motivasyon desteği sağlanabilir.';
    } else if (hwRate >= 85 && avgStars >= 2.5) {
      return 'Ders içi katılımı, sorumluluk bilinci ve ödev istikrarı son derece başarılı. Tebrik edilmeli.';
    } else {
      return 'Genel durumu dengeli ve olumlu. İstikrarlı takiple başarısı daha da yukarılara taşınabilir.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classListProvider).valueOrNull ?? [];
    final profile = ref.watch(teacherProfileProvider);
    final teacherName = profile.fullName.isNotEmpty ? profile.fullName : 'Ders Öğretmeni';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Üst Başlık & Kapat Butonu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Katılım & Veli Toplantısı Raporları',
                      style: AppFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Dönem başından bugüne anlık katılım ve toplantı analizleri',
                      style: AppFonts.outfit(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, size: 22, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sınıf Seçimi Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedClassId,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      items: classes.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.subject})',
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedClassId = val;
                            _selectedStudentId = null;
                            _studentSearchController.clear();
                            _studentSearchQuery = '';
                          });
                          _loadMeetingData();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ANA BÖLÜM: VELİ TOPLANTISI & CANLI ÖĞRENCİ LİSTESİ
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HERO KART: VELİ TOPLANTISI VE ANLIK RAPOR
                      _buildMeetingHeroCard(isDark),
                      const SizedBox(height: 12),

                      // 2. TEK ÖĞRENCİ VİTRİNİ & ARAMA ALANI
                      _buildFeaturedStudentSection(isDark, teacherName, profile.schoolName),
                      const SizedBox(height: 16),

                      // 3. ALT BÖLÜM: RESMÎ DÖNEM SONU İDARE ARŞİV EVRAKLARI (KATLANIR)
                      _buildOfficialArchiveAccordion(isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Yükleniyor Göstergesi
                if (_isActionLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Veli Toplantısı Hero Kartı (Tarih + Toplu PDF + Paylaşım)
  Widget _buildMeetingHeroCard(bool isDark) {
    final turkishDate = AppDateFormatter.formatTurkishDate(_meetingDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.4 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarih Seçici Satırı
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _meetingDate,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 1),
                      helpText: 'Veli Toplantısı Tarihini Seçin',
                      cancelText: 'Vazgeç',
                      confirmText: 'Seç',
                    );
                    if (picked != null) {
                      setState(() => _meetingDate = picked);
                      _loadMeetingData();
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFD97706).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tarih: $turkishDate',
                            style: AppFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF92400E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Değiştir',
                          style: AppFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD97706),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Dönem başından seçilen tarihe kadar olan tüm değerlendirmeler kümülatif derlenir.',
            style: AppFonts.outfit(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),

          // 2 Ana Düğme: Toplu Liste PDF & Paylaş
          Row(
            children: [
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: () => _generateMeetingReport(isShare: false),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(
                    'Toplantı Listesi (PDF)',
                    style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () => _generateMeetingReport(isShare: true),
                  icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Paylaş',
                    style: AppFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Tek Öğrenci Vitrini, Anlık Focus-Korumalı Arama ve Açılır Liste
  Widget _buildFeaturedStudentSection(bool isDark, String teacherName, String? schoolName) {
    if (_isMeetingDataLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      );
    }

    final rawStudents = _meetingReportData?['students'] as List<dynamic>? ?? [];
    final List<Map<String, dynamic>> students =
        rawStudents.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            'Bu sınıfta henüz kayıtlı öğrenci bulunamadı.',
            style: AppFonts.outfit(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    final className = _meetingReportData?['className'] as String? ?? 'Sınıf';
    final subjectName = _meetingReportData?['subjectName'] as String? ?? 'Ders';

    // İstatistik Sayaçları
    int needsAttentionCount = 0;
    int successCount = 0;
    for (var s in students) {
      final hw = (s['homeworkRate'] as num?)?.toDouble() ?? 100.0;
      if (hw < 70) {
        needsAttentionCount++;
      } else if (hw >= 85) {
        successCount++;
      }
    }

    // Filtreleme Mantığı (In-Memory, sıfır ağ gecikmesi, sıfır focus kaybı!)
    final List<Map<String, dynamic>> filteredStudents = students.where((s) {
      final hw = (s['homeworkRate'] as num?)?.toDouble() ?? 100.0;
      if (_filterStatus == StudentMeetingFilter.needsAttention && hw >= 70) {
        return false;
      }
      if (_filterStatus == StudentMeetingFilter.successful && hw < 85) {
        return false;
      }
      if (_studentSearchQuery.isEmpty) return true;
      final name = (s['studentName']?.toString() ?? '').toLowerCase();
      final numStr = s['studentNumber']?.toString() ?? '';
      final query = _studentSearchQuery.toLowerCase();
      return name.contains(query) || numStr.contains(query);
    }).toList();

    // Vitrinde gösterilecek tek öğrenci (Seçili öğrenci filtrelenen listede varsa o, yoksa ilk eşleşen)
    Map<String, dynamic>? featuredStudent;
    if (filteredStudents.isNotEmpty) {
      featuredStudent = filteredStudents.firstWhere(
        (s) => s['studentId'] == _selectedStudentId,
        orElse: () => filteredStudents.first,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Sayaç
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bireysel Öğrenci Özeti & Görüşme',
                style: AppFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${filteredStudents.length} / ${students.length} Öğrenci',
                  style: AppFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Arama Kutusu (Focus Korumalı!)
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _studentSearchController,
              focusNode: _searchFocusNode,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Öğrenci adı veya okul no ile anında bul...',
                hintStyle: AppFonts.outfit(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFD97706)),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _studentSearchController.clear();
                          setState(() => _studentSearchQuery = '');
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() => _studentSearchQuery = val.trim());
              },
            ),
          ),

          // Hızlı Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tümü (${students.length})',
                  isSelected: _filterStatus == StudentMeetingFilter.all,
                  selectedColor: const Color(0xFF3B82F6),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _filterStatus = StudentMeetingFilter.all);
                  },
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: '🔴 Görüşülmeli ($needsAttentionCount)',
                  isSelected: _filterStatus == StudentMeetingFilter.needsAttention,
                  selectedColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _filterStatus = StudentMeetingFilter.needsAttention);
                  },
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: '🟢 Başarılı ($successCount)',
                  isSelected: _filterStatus == StudentMeetingFilter.successful,
                  selectedColor: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _filterStatus = StudentMeetingFilter.successful);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 1. TEK ÖĞRENCİ VİTRİN KARTI (Arama veya Seçilen Öğrenci)
          if (featuredStudent != null) ...[
            _buildFeaturedStudentCard(
              context: context,
              isDark: isDark,
              student: featuredStudent,
              className: className,
              subjectName: subjectName,
              teacherName: teacherName,
              schoolName: schoolName,
            ),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Arama kriterine uygun öğrenci bulunamadı.',
                  style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
                ),
              ),
            ),

          // 2. TÜM LİSTEYİ AÇ/KAPAT BUTONU VE AÇILIR LİSTE
          if (_studentSearchQuery.isEmpty || filteredStudents.length > 1) ...[
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showAllStudentsList = !_showAllStudentsList);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _showAllStudentsList
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.format_list_bulleted_rounded,
                          size: 16,
                          color: const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _showAllStudentsList
                              ? (_studentSearchQuery.isNotEmpty ? 'Sonuç Listesini Kapat' : 'Tüm Sınıf Listesini Kapat')
                              : (_studentSearchQuery.isNotEmpty
                                  ? 'Eşleşen Diğer Öğrenciler (${filteredStudents.length})'
                                  : 'Tüm Sınıf Listesini Gör (${students.length} Öğrenci)'),
                          style: AppFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _showAllStudentsList
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Açılan Tüm Liste
          if (_showAllStudentsList && filteredStudents.length > 1) ...[
            const SizedBox(height: 8),
            ...filteredStudents.map((s) {
              final studentMap = s;
              final isSelected = studentMap['studentId'] == (featuredStudent?['studentId'] ?? _selectedStudentId);

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedStudentId = studentMap['studentId'] as int?;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD97706).withValues(alpha: isDark ? 0.25 : 0.12)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD97706)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF3B82F6),
                        child: Text(
                          studentMap['studentNumber']?.toString() ?? '-',
                          style: AppFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          studentMap['studentName']?.toString() ?? 'Öğrenci',
                          style: AppFonts.outfit(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Ödev: %${((studentMap['homeworkRate'] as num?)?.toDouble() ?? 100.0).toStringAsFixed(0)}',
                        style: AppFonts.outfit(
                          fontSize: 10.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFFD97706)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Tek Öğrenci Vitrin Kartı (Büyük, Zengin ve Hızlı Aksiyonlu)
  Widget _buildFeaturedStudentCard({
    required BuildContext context,
    required bool isDark,
    required Map<String, dynamic> student,
    required String className,
    required String subjectName,
    required String teacherName,
    String? schoolName,
  }) {
    final sName = student['studentName']?.toString() ?? 'Öğrenci';
    final sNum = student['studentNumber']?.toString() ?? '-';
    final hwRateNum = (student['homeworkRate'] as num?)?.toDouble() ?? 100.0;
    final matRateNum = (student['materialsRate'] as num?)?.toDouble() ?? 100.0;
    final avgStarsNum = (student['averageStars'] as num?)?.toDouble() ?? 3.0;

    final hwRate = hwRateNum.toStringAsFixed(0);
    final matRate = matRateNum.toStringAsFixed(0);
    final avgStars = avgStarsNum.toStringAsFixed(1);

    // Durum Trafik Işığı Rengi
    Color statusColor = const Color(0xFF10B981); // Yeşil
    if (hwRateNum < 60) {
      statusColor = const Color(0xFFEF4444); // Kırmızı
    } else if (hwRateNum < 80) {
      statusColor = const Color(0xFFF59E0B); // Sarı
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _showStudentDetailDialog(
          context: context,
          isDark: isDark,
          student: student,
          className: className,
          subjectName: subjectName,
          teacherName: teacherName,
          schoolName: schoolName,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.5 : 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Öğrenci Bilgisi & Detay Rozeti
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: statusColor,
                  child: Text(
                    sNum,
                    style: AppFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sName,
                        style: AppFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$className Sınıfı • $subjectName',
                        style: AppFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Detay Gör 👆',
                    style: AppFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3 Özet Metrik Kutucuğu
            Row(
              children: [
                Expanded(
                  child: _buildMiniMetricBox('Ödev Başarısı', '%$hwRate', const Color(0xFF10B981), isDark),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniMetricBox('Araç-Gereç', '%$matRate', const Color(0xFF3B82F6), isDark),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniMetricBox('Katılım', '$avgStars / 3.0', const Color(0xFFD97706), isDark),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2 Geniş Hızlı Aksiyon Butonu (WhatsApp & Karne PDF)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final turkishDate = AppDateFormatter.formatTurkishDate(_meetingDate);
                      final msg = '''*Sayın Velimiz,*\n\n$sName isimli öğrencimizin *$className* sınıfı *$subjectName* dersindeki *$turkishDate* itibarıyla ders içi gelişim özeti:\n\n📚 *Ödev Teslim Başarısı:* %$hwRate\n⭐ *Derse Katılım Ortalaması:* $avgStars / 3.0\n\n_Öğrencimizin gayretlerinin artarak devamını diler, veli toplantımıza katılımınız ve desteğiniz için teşekkür ederiz._\n\n*$teacherName - Ders Öğretmeni*''';
                      ParticipationWhatsAppHelper.showWhatsAppModal(
                        context: context,
                        messageText: msg,
                        title: '$sName Veli Bildirimi',
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 15, color: Colors.white),
                    label: Text(
                      'WhatsApp Paylaş',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final pdfBytes =
                          await ParticipationCumulativePdfGenerator.generateIndividualStudentCardPdf(
                        studentData: student,
                        className: className,
                        subjectName: subjectName,
                        teacherName: teacherName,
                        schoolName: schoolName,
                      );
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: '${sName}_Gelisim_Ozeti.pdf',
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFFEF4444)),
                    label: Text(
                      'Özet (PDF)',
                      style: AppFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetricBox(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : color,
            ),
          ),
          Text(
            label,
            style: AppFonts.outfit(
              fontSize: 9.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : selectedColor)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  /// Öğrenciye Tıklanınca Açılan Detaylı Gelişim Popover Dialogu (Akıllı Görüşme Tüyosu İçerir)
  void _showStudentDetailDialog({
    required BuildContext context,
    required bool isDark,
    required Map<String, dynamic> student,
    required String className,
    required String subjectName,
    required String teacherName,
    String? schoolName,
  }) {
    final sName = student['studentName']?.toString() ?? 'Öğrenci';
    final sNum = student['studentNumber']?.toString() ?? '-';
    final sLessons = student['totalEvaluatedSessions']?.toString() ?? '0';
    final hwDone = student['homeworkDone']?.toString() ?? '0';
    final hwPart = student['homeworkPartial']?.toString() ?? '0';
    final hwNone = student['homeworkNone']?.toString() ?? '0';
    final hwRateNum = (student['homeworkRate'] as num?)?.toDouble() ?? 100.0;
    final matRateNum = (student['materialsRate'] as num?)?.toDouble() ?? 100.0;
    final avgStarsNum = (student['averageStars'] as num?)?.toDouble() ?? 3.0;

    final hwRate = hwRateNum.toStringAsFixed(0);
    final matRate = matRateNum.toStringAsFixed(0);
    final avgStars = avgStarsNum.toStringAsFixed(1);
    final tags = (student['tags'] as List<dynamic>?)?.map((t) => t.toString()).toSet().toList() ?? [];
    final notes = (student['notes'] as List<dynamic>?)?.map((n) => n.toString()).toList() ?? [];

    final meetingTip = _getMeetingTalkingTip(
      hwRate: hwRateNum,
      matRate: matRateNum,
      avgStars: avgStarsNum,
      sName: sName,
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  sNum,
                  style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sName,
                      style: AppFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$className • $subjectName ($sLessons Ders İşlendi)',
                      style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // 3 Temel Metrik
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniMetric('Ödev Başarısı', '%$hwRate', const Color(0xFF10B981)),
                      _buildMiniMetric('Araç-Gereç', '%$matRate', const Color(0xFF3B82F6)),
                      _buildMiniMetric('Katılım Puanı', '$avgStars / 3.0', const Color(0xFFD97706)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Akıllı Veli Görüşme Tüyosu Kutusu
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD97706).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded, size: 15, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          Text(
                            'Veli Görüşme Tüyosu',
                            style: AppFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meetingTip,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : const Color(0xFF78350F),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Ödev Dağılımı Detayı
                Text(
                  'Ödev Dağılımı: $hwDone Tam • $hwPart Eksik • $hwNone Yapmadı',
                  style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                // Davranış Etiketleri
                if (tags.isNotEmpty) ...[
                  Text('Öne Çıkan Nitelikler:', style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t, style: AppFonts.outfit(fontSize: 10.5, color: Colors.blue)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Gözlem Notları
                if (notes.isNotEmpty) ...[
                  Text('Öğretmen Gözlem Notları:', style: AppFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...notes.take(3).map((n) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $n', style: AppFonts.outfit(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final turkishDate = AppDateFormatter.formatTurkishDate(_meetingDate);
                final msg = '''*Sayın Velimiz,*\n\n$sName isimli öğrencimizin *$className* sınıfı *$subjectName* dersindeki *$turkishDate* itibarıyla ders içi gelişim özeti:\n\n📚 *Ödev Teslim Başarısı:* %$hwRate\n⭐ *Derse Katılım Ortalaması:* $avgStars / 3.0\n\n_Öğrencimizin gayretlerinin artarak devamını diler, veli toplantımıza katılımınız ve desteğiniz için teşekkür ederiz._\n\n*$teacherName - Ders Öğretmeni*''';
                ParticipationWhatsAppHelper.showWhatsAppModal(
                  context: context,
                  messageText: msg,
                  title: '$sName Veli Bildirimi',
                );
              },
              icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
              label: const Text('WhatsApp Paylaş'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: AppFonts.outfit(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  /// 3. Katlanabilir Alt Bölüm: Resmî İdare Dönem & Yıl Sonu Arşiv Çizelgeleri
  Widget _buildOfficialArchiveAccordion(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showOfficialArchiveSection = !_showOfficialArchiveSection);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏛️ Resmî İdare Dönem & Yıl Sonu Evrakları',
                          style: AppFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'MEB antetli 1. Dönem, 2. Dönem ve Yıl Sonu çizelgeleri',
                          style: AppFonts.outfit(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showOfficialArchiveSection
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Açılan Arşiv Kartları
          if (_showOfficialArchiveSection) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // 1. DÖNEM
                  _buildArchiveMiniTile(
                    isDark: isDark,
                    title: '1. Dönem Değerlendirme Çizelgesi (Eylül - Ocak)',
                    badgeColor: const Color(0xFF2563EB),
                    onPreview: () => _generateTerm1Report(isShare: false),
                    onShare: () => _generateTerm1Report(isShare: true),
                  ),
                  const SizedBox(height: 8),

                  // 2. DÖNEM
                  _buildArchiveMiniTile(
                    isDark: isDark,
                    title: '2. Dönem Değerlendirme Çizelgesi (Şubat - Haziran)',
                    badgeColor: const Color(0xFF059669),
                    onPreview: () => _generateTerm2Report(isShare: false),
                    onShare: () => _generateTerm2Report(isShare: true),
                  ),
                  const SizedBox(height: 8),

                  // YIL SONU
                  _buildArchiveMiniTile(
                    isDark: isDark,
                    title: 'Yıl Sonu Kümülatif Başarı Çizelgesi (Tüm Yıl)',
                    badgeColor: const Color(0xFF7C3AED),
                    onPreview: () => _generateFullYearReport(isShare: false),
                    onShare: () => _generateFullYearReport(isShare: true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchiveMiniTile({
    required bool isDark,
    required String title,
    required Color badgeColor,
    required VoidCallback onPreview,
    required VoidCallback onShare,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onPreview,
            icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
            tooltip: 'İncele & Yazdır',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: onShare,
            icon: Icon(Icons.share_rounded, size: 18, color: badgeColor),
            tooltip: 'Paylaş',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

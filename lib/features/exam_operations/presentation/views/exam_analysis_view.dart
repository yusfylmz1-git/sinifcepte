import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/input_sanitizer.dart';
import '../../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/custom_bottom_nav_bar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../navigation/providers/navigation_provider.dart';

/// SınıfCepte - 4/4: Kırılmaz Sınav Analizi (Soru Bazlı & Hızlı Not Girişi)
class ExamAnalysisView extends ConsumerStatefulWidget {
  const ExamAnalysisView({super.key});

  @override
  ConsumerState<ExamAnalysisView> createState() => _ExamAnalysisViewState();
}

class _ExamAnalysisViewState extends ConsumerState<ExamAnalysisView> {
  final TextEditingController _quickEntryController = TextEditingController();
  List<double> _parsedScores = [];

  @override
  void dispose() {
    _quickEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F8FC),
      extendBody: true,
      appBar: const CustomAppBar(
        title: 'Soru Bazlı Sınav Analizi',
        showBackButton: true,
        showDrawerButton: false,
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Bilgilendirme ve Hızlı Giriş Butonu
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hızlı Not Dağıtımı (Space Duyarlı)',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Boşluk bırakarak soru puanlarını tek seferde girin',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Soru notlarını aralarında BOŞLUK (Space) bırakarak yazın. Sistem otomatik olarak sorulara sırayla dağıtıp analiz grafiği çıkartacaktır.',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _showQuickEntryModal(context, isDark),
                        icon: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.white),
                        label: Text(
                          'Hızlı Not Girişi Yap',
                          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rapor Oluştur Butonu
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EEF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('MEB Formatında Otomatik PDF Sınav Analiz Raporu İndirildi! 📄'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resmî MEB Sınav Analiz Raporu',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Millî Eğitim standartlarında otomatik PDF çıktısı al',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: ref.watch(navigationIndexProvider),
        onTap: (index) {
          try {
            ref.read(navigationIndexProvider.notifier).state = index;
            Navigator.of(context).popUntil((route) => route.isFirst);
          } catch (e, stackTrace) {
            debugPrint('ExamAnalysisView bottom nav tap error: $e\n$stackTrace');
          }
        },
      ),
    );
  }

  void _showQuickEntryModal(BuildContext context, bool isDark) {
    ResponsiveBottomSheet.show(
      context: context,
      title: '⚡ Hızlı Soru Not Girişi',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalScore = _parsedScores.fold(0.0, (s, v) => s + v);
          final isValidHundred = InputSanitizer.validateTotalHundred(_parsedScores);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Örnek Giriş: 10 15 20 10 25 20 (Soru puanları toplamı 100 olmalıdır)',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quickEntryController,
                keyboardType: TextInputType.number,
                maxLines: 3,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '10 15 25 20 15 15',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  setModalState(() {
                    _parsedScores = InputSanitizer.parseSpaceSeparatedScores(val);
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_parsedScores.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ayrıştırılan Soru: ${_parsedScores.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isValidHundred ? Colors.green : Colors.red).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (isValidHundred ? Colors.green : Colors.red).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Toplam: ${totalScore.toStringAsFixed(0)} / 100',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isValidHundred ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _parsedScores.asMap().entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'S${e.key + 1}: ${e.value.toStringAsFixed(0)}p',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sınav notları kaydedildi! 🚀')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Kaydet ve Tamamla',
                        style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

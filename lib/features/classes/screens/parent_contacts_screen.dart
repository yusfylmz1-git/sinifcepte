import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/student_model.dart';
import '../../../../data/models/class_model.dart';
import '../providers/student_provider.dart';
import '../utils/parent_contacts_pdf_generator.dart';
import '../../parent_portal/presentation/widgets/parent_token_card_modal.dart';
import '../../parent_portal/presentation/widgets/class_parent_communication_modal.dart';

/// Türkiye Telefon Numarası Otomatik Maskeleme Formatlayıcısı
/// Örn: 5321234567 -> 0 (532) 123 45 67 veya 05321234567 -> 0 (532) 123 45 67
class TurkishPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Maksimum 11 hane (0 ile başlayan) veya 10 hane (5 ile başlayan)
    final trimmed = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;
    final buffer = StringBuffer();

    if (trimmed.startsWith('0')) {
      for (int i = 0; i < trimmed.length; i++) {
        if (i == 1) buffer.write(' (');
        if (i == 4) buffer.write(') ');
        if (i == 7 || i == 9) buffer.write(' ');
        buffer.write(trimmed[i]);
      }
    } else {
      // 5 ile başlıyorsa başına 0 eklemeden formatla
      for (int i = 0; i < trimmed.length; i++) {
        if (i == 0) buffer.write('0 (');
        if (i == 3) buffer.write(') ');
        if (i == 6 || i == 8) buffer.write(' ');
        buffer.write(trimmed[i]);
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// SınıfCepte - Veli İletişim ve Acil Durum Rehberi Ekranı
class ParentContactsScreen extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ParentContactsScreen({super.key, required this.classModel});

  @override
  ConsumerState<ParentContactsScreen> createState() => _ParentContactsScreenState();
}

class _ParentContactsScreenState extends ConsumerState<ParentContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'missing', 'has_phone'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Telefon Numarasını Standart Türkiye Formatına (0 (5XX) XXX XX XX) Çevirici
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 11 && cleaned.startsWith('0')) {
      return '0 (${cleaned.substring(1, 4)}) ${cleaned.substring(4, 7)} ${cleaned.substring(7, 9)} ${cleaned.substring(9, 11)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('5')) {
      return '0 (${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)} ${cleaned.substring(6, 8)} ${cleaned.substring(8, 10)}';
    } else if (cleaned.length == 12 && cleaned.startsWith('90')) {
      return '0 (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)} ${cleaned.substring(8, 10)} ${cleaned.substring(10, 12)}';
    }
    // Hatalı veya aşırı uzun ise güvenli göster
    if (phone.length > 20) {
      return '${phone.substring(0, 17)}...';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentsAsync = ref.watch(studentListProvider(widget.classModel.id!));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBackground : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.classModel.name} Veli Rehberi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            studentsAsync.when(
              data: (students) {
                final withPhone = students.where((s) => s.parentPhone?.trim().isNotEmpty == true).length;
                return Text(
                  'Kayıtlı: $withPhone / ${students.length} Veli',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          // 1. ⚡ Seri Giriş Sihirbazı Butonu
          TextButton.icon(
            onPressed: () {
              final students = studentsAsync.valueOrNull ?? [];
              if (students.isEmpty) {
                _showSnack('Sınıfta kayıtlı öğrenci bulunmuyor.');
                return;
              }
              _openBatchInputWizard(context, students);
            },
            icon: const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 18),
            label: const Text(
              'Seri Giriş',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 2. A4 PDF & WhatsApp Paylaşım Butonu
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.primary),
            tooltip: 'A4 Veli Çizelgesi PDF Paylaş',
            onPressed: () {
              final students = studentsAsync.valueOrNull ?? [];
              if (students.isEmpty) {
                _showSnack('PDF oluşturmak için en az 1 öğrenci olmalıdır.');
                return;
              }
              ParentContactsPdfGenerator.generateAndShare(
                context: context,
                classModel: widget.classModel,
                students: students,
              );
            },
          ),

          // 3. 📢 Veli İletişim & Duyuru Merkezi Butonu
          IconButton(
            icon: const Icon(Icons.hub_rounded, color: AppColors.primary),
            tooltip: 'Veli İletişim & Duyuru Merkezi',
            onPressed: () {
              ClassParentCommunicationModal.show(
                context,
                classModel: widget.classModel,
              );
            },
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return _buildEmptyState(isDark);
          }

          // Filtreleme ve Arama
          final filteredStudents = students.where((s) {
            final query = _searchQuery.toLowerCase().trim();
            final matchesQuery = query.isEmpty ||
                s.fullName.toLowerCase().contains(query) ||
                s.schoolNumber.toString().contains(query) ||
                (s.parentName?.toLowerCase().contains(query) ?? false) ||
                (s.parentPhone?.contains(query) ?? false);

            if (!matchesQuery) return false;

            final hasPhone = s.parentPhone?.trim().isNotEmpty == true;
            if (_selectedFilter == 'missing') return !hasPhone;
            if (_selectedFilter == 'has_phone') return hasPhone;
            return true;
          }).toList()
            ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

          final missingCount = students.where((s) => s.parentPhone == null || s.parentPhone!.trim().isEmpty).length;
          final withPhoneCount = students.length - missingCount;

          return Column(
            children: [
              // Üst Arama Çubuğu & Hızlı Filtre Çipleri
              _buildSearchAndFilters(
                isDark: isDark,
                totalCount: students.length,
                missingCount: missingCount,
                withPhoneCount: withPhoneCount,
              ),

              // Öğrenci Veli İletişim Kartları Listesi
              Expanded(
                child: filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          'Aramanızla eşleşen öğrenci bulunamadı.',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          return _buildParentContactCard(
                            context: context,
                            student: student,
                            isDark: isDark,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(child: Text('Hata: $err')),
      ),
    );
  }

  /// Arama Çubuğu ve Filtre Çipleri
  Widget _buildSearchAndFilters({
    required bool isDark,
    required int totalCount,
    required int missingCount,
    required int withPhoneCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Arama Girişi
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Öğrenci adı, okul no veya veli ara...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Hızlı Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tümü ($totalCount)', isDark),
                const SizedBox(width: 6),
                _buildFilterChip('missing', '⚠️ Eksik Numaralar ($missingCount)', isDark, isWarning: missingCount > 0),
                const SizedBox(width: 6),
                _buildFilterChip('has_phone', '✅ Kayıtlı Olanlar ($withPhoneCount)', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark, {bool isWarning = false}) {
    final isSelected = _selectedFilter == filterKey;
    Color activeBg = AppColors.primary;
    if (isWarning && filterKey == 'missing') activeBg = Colors.orange.shade800;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: activeBg,
      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      visualDensity: VisualDensity.compact,
    );
  }

  /// Öğrenci Veli İletişim Kartı (UI-UX-MAX + Sıfır Overflow)
  Widget _buildParentContactCard({
    required BuildContext context,
    required StudentModel student,
    required bool isDark,
  }) {
    final isGirl = student.gender.toLowerCase().contains('kız');
    final avatarBg = isGirl ? Colors.pink.shade100 : Colors.blue.shade100;
    final avatarColor = isGirl ? Colors.pink.shade800 : Colors.blue.shade800;

    final hasPhone = student.parentPhone != null && student.parentPhone!.trim().isNotEmpty;
    final formattedPhone = formatPhoneNumber(student.parentPhone);
    final parentName = student.parentName?.trim();
    final notes = student.notes?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPhone
              ? (isDark ? Colors.white12 : Colors.grey.shade200)
              : Colors.orange.withValues(alpha: 0.4),
          width: hasPhone ? 1.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Avatar, Öğrenci Adı, Düzenle Butonu
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarBg,
                child: Text(
                  student.schoolNumber > 0 ? '${student.schoolNumber}' : student.firstName[0],
                  style: TextStyle(
                    color: avatarColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Text(
                      'No: ${student.schoolNumber} • ${student.gender}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // Hızlı Düzenle İkonu
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                tooltip: 'Veli Bilgisini Düzenle',
                onPressed: () => _openSingleEditModal(context, student),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Veli Bilgileri ve Hızlı Arama Butonları
          if (hasPhone) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 14, color: isDark ? Colors.white60 : Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              parentName != null && parentName.isNotEmpty ? parentName : 'Veli',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 📞 ARA BUTONU
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(student.parentPhone!),
                  icon: const Icon(Icons.call_rounded, size: 14),
                  label: const Text('Ara', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),

                // 💬 WHATSAPP BUTONU
                ElevatedButton.icon(
                  onPressed: () => _openWhatsApp(student.parentPhone!, student.fullName),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),

                // 📱 QR KOD BUTONU
                ElevatedButton.icon(
                  onPressed: () => ParentTokenCardModal.show(
                    context,
                    student: student,
                    classModel: widget.classModel,
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 14),
                  label: const Text('QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Telefon Kayıtlı Değilse Uyarı ve Hızlı Ekle.
            //
            // Uyarı metni ve iki buton tek satıra sığmıyordu (dar ekranda
            // 34px taşma). Wrap kullanılıyor: yer varsa yan yana, yoksa
            // buton grubu alt satıra iner. Böylece 320px ekranda bile
            // taşma olmaz (AGENTS.md Madde 8).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Veli Telefonu Girilmedi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Butonlar ayrı ayrı Wrap çocuğu: 320px ekranda ikisi yan
                // yana sığmadığında biri alt satıra iner. Tek Row içinde
                // tutulsalardı Wrap onları bölünemez sayar ve 69px taşardı.
                OutlinedButton.icon(
                  onPressed: () => ParentTokenCardModal.show(
                    context,
                    student: student,
                    classModel: widget.classModel,
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.primary),
                  label: const Text(
                    'Veli Kodu',
                    style: TextStyle(fontSize: 11.5, color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openSingleEditModal(context, student),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Numara Ekle',
                    style: TextStyle(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade400),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],

          // Ekstra Not / Acil Durum Bilgisi
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ⚡ SERİ GİRİŞ SİHİRBAZI (Batch Input Wizard + Full Validation)
  void _openBatchInputWizard(BuildContext context, List<StudentModel> students) {
    final sortedStudents = List<StudentModel>.from(students)
      ..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));

    final batchFormKey = GlobalKey<FormState>();
    int currentIndex = 0;
    final parentNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final focusNode = FocusNode();

    void loadStudentData(int index) {
      final s = sortedStudents[index];
      parentNameCtrl.text = s.parentName ?? '';
      phoneCtrl.text = s.parentPhone != null ? formatPhoneNumber(s.parentPhone) : '';
      notesCtrl.text = s.notes ?? '';
    }

    loadStudentData(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final student = sortedStudents[currentIndex];
            final isGirl = student.gender.toLowerCase().contains('kız');
            final progress = (currentIndex + 1) / sortedStudents.length;

            Future<bool> validateAndSaveCurrent() async {
              if (!batchFormKey.currentState!.validate()) {
                return false;
              }

              try {
                final cleanedPhone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                final formattedPhoneToSave = formatPhoneNumber(cleanedPhone);

                await ref.read(studentListProvider(widget.classModel.id!).notifier).updateParentContact(
                      studentId: student.id!,
                      parentName: parentNameCtrl.text.trim(),
                      parentPhone: formattedPhoneToSave.isNotEmpty ? formattedPhoneToSave : null,
                      notes: notesCtrl.text.trim(),
                    );
                return true;
              } catch (e, stackTrace) {
                debugPrint('---------------- HATA DETAYI (ParentContacts.batchSave) ----------------');
                debugPrint('Hata Mesajı : $e');
                debugPrint('Kod Satırı   : $stackTrace');
                debugPrint('-----------------------------------------------------------------------');
                return false;
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardBackground : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 14,
                left: 18,
                right: 18,
              ),
              child: Form(
                key: batchFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal Tutamacı
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Başlık & İlerleme
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Seri Veli Bilgi Girişi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${sortedStudents.length}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // İlerleme Çubuğu
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),

                    // Mevcut Öğrenci Bilgisi Kartı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isGirl ? Colors.pink.shade100 : Colors.blue.shade100,
                            child: Text(
                              student.schoolNumber > 0 ? '${student.schoolNumber}' : student.firstName[0],
                              style: TextStyle(
                                color: isGirl ? Colors.pink.shade800 : Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'Okul No: ${student.schoolNumber} • ${student.gender}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Form Alanları (Strict Validation)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Veli Telefonu
                            const Text('Veli Telefon Numarası', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: phoneCtrl,
                              focusNode: focusNode,
                              autofocus: true,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                                TurkishPhoneInputFormatter(),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return null; // Opsiyonel
                                final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                                if (digits.length < 10) {
                                  return 'Geçerli bir telefon giriniz (En az 10 hane)';
                                }
                                if (!digits.startsWith('05') && !digits.startsWith('5')) {
                                  return 'Telefon 05XX veya 5XX ile başlamalıdır';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: '0 (5XX) XXX XX XX',
                                prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                                filled: true,
                                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Veli Adı ve Yakınlığı
                            const Text('Veli Adı / Yakınlığı (İsteğe Bağlı)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: parentNameCtrl,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ\s\(\)\-\.]')),
                                LengthLimitingTextInputFormatter(40),
                              ],
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return null; // Opsiyonel
                                if (val.trim().length < 2) {
                                  return 'Veli adı en az 2 harf olmalıdır';
                                }
                                if (RegExp(r'[0-9]').hasMatch(val)) {
                                  return 'Veli adında rakam bulunamaz';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Örn: Fatma Yılmaz (Anne) veya Ali (Baba)',
                                prefixIcon: const Icon(Icons.person_rounded, size: 20),
                                filled: true,
                                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Acil Durum / Özel Not
                            const Text('Acil Durum / Özel Not (İsteğe Bağlı)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: notesCtrl,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(100),
                              ],
                              onFieldSubmitted: (_) async {
                                final isSaved = await validateAndSaveCurrent();
                                if (!isSaved) return;

                                if (currentIndex < sortedStudents.length - 1) {
                                  setModalState(() {
                                    currentIndex++;
                                    loadStudentData(currentIndex);
                                  });
                                  focusNode.requestFocus();
                                } else {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _showSnack('Tüm sınıfın veli bilgileri başarıyla kaydedildi! 🎉');
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Örn: Servis No: 12 / Kronik Astım',
                                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                                filled: true,
                                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Alt Aksiyon Butonları
                    Row(
                      children: [
                        if (currentIndex > 0) ...[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final isSaved = await validateAndSaveCurrent();
                              if (!isSaved) return;

                              setModalState(() {
                                currentIndex--;
                                loadStudentData(currentIndex);
                              });
                            },
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                            label: const Text('Önceki'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final isSaved = await validateAndSaveCurrent();
                              if (!isSaved) return;

                              if (currentIndex < sortedStudents.length - 1) {
                                setModalState(() {
                                  currentIndex++;
                                  loadStudentData(currentIndex);
                                });
                                focusNode.requestFocus();
                              } else {
                                if (ctx.mounted) Navigator.pop(ctx);
                                _showSnack('Tüm sınıfın veli bilgileri başarıyla kaydedildi! 🎉');
                              }
                            },
                            icon: Icon(
                              currentIndex < sortedStudents.length - 1 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded,
                              size: 16,
                            ),
                            label: Text(
                              currentIndex < sortedStudents.length - 1 ? 'Kaydet & Sonraki' : 'Tamamla ve Kaydet',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Tek Öğrenci Düzenleme Modalı (Full Validation & Formatting)
  void _openSingleEditModal(BuildContext context, StudentModel student) {
    final singleFormKey = GlobalKey<FormState>();
    final parentNameCtrl = TextEditingController(text: student.parentName ?? '');
    final phoneCtrl = TextEditingController(text: student.parentPhone != null ? formatPhoneNumber(student.parentPhone) : '');
    final notesCtrl = TextEditingController(text: student.notes ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 14,
            left: 20,
            right: 20,
          ),
          child: Form(
            key: singleFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Text(
                  '${student.fullName} - Veli Bilgileri',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 14),

                // Veli Telefonu Girişi
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                    TurkishPhoneInputFormatter(),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null; // Opsiyonel
                    final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return 'Geçerli bir telefon giriniz (En az 10 hane)';
                    }
                    if (!digits.startsWith('05') && !digits.startsWith('5')) {
                      return 'Telefon 05XX veya 5XX ile başlamalıdır';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Veli Telefonu',
                    hintText: '0 (5XX) XXX XX XX',
                    prefixIcon: const Icon(Icons.phone_rounded),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
                  ),
                ),
                const SizedBox(height: 12),

                // Veli Adı Girişi (Rakam Yasaklı)
                TextFormField(
                  controller: parentNameCtrl,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZçÇğĞıİöÖşŞüÜ\s\(\)\-\.]')),
                    LengthLimitingTextInputFormatter(40),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null; // Opsiyonel
                    if (val.trim().length < 2) {
                      return 'Veli adı en az 2 harf olmalıdır';
                    }
                    if (RegExp(r'[0-9]').hasMatch(val)) {
                      return 'Veli adında rakam bulunamaz';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Veli Adı / Yakınlığı',
                    hintText: 'Örn: Fatma Yılmaz (Anne)',
                    prefixIcon: const Icon(Icons.person_rounded),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
                  ),
                ),
                const SizedBox(height: 12),

                // Özel Not Girişi
                TextFormField(
                  controller: notesCtrl,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(100),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Acil Durum / Özel Not',
                    hintText: 'Örn: Servis No: 12',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!singleFormKey.currentState!.validate()) {
                        return;
                      }

                      try {
                        final cleanedPhone = phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final formattedPhoneToSave = formatPhoneNumber(cleanedPhone);

                        await ref.read(studentListProvider(widget.classModel.id!).notifier).updateParentContact(
                              studentId: student.id!,
                              parentName: parentNameCtrl.text.trim(),
                              parentPhone: formattedPhoneToSave.isNotEmpty ? formattedPhoneToSave : null,
                              notes: notesCtrl.text.trim(),
                            );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          _showSnack('${student.fullName} veli bilgisi güncellendi.');
                        }
                      } catch (e, stackTrace) {
                        debugPrint('---------------- HATA DETAYI (ParentContacts.singleEdit) ----------------');
                        debugPrint('Hata Mesajı : $e');
                        debugPrint('Kod Satırı   : $stackTrace');
                        debugPrint('------------------------------------------------------------------------');
                        if (context.mounted) {
                          _showSnack('Veli bilgisi güncellenirken hata oluştu.');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Telefon Arama Fonksiyonu (Dual Error Handling & Doğrulama)
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleaned.length < 10) {
        _showSnack('Geçersiz telefon numarası ($phoneNumber)');
        return;
      }

      final uri = Uri.parse('tel:$cleaned');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Arama başlatılamadı ($cleaned)');
      }
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ParentContacts._makePhoneCall) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('-----------------------------------------------------------------------------');
      _showSnack('Arama başlatılırken hata oluştu: Numara biçimini kontrol edin.');
    }
  }

  /// WhatsApp Sohbet Açma Fonksiyonu (Dual Error Handling & Doğrulama)
  Future<void> _openWhatsApp(String phoneNumber, String studentName) async {
    try {
      String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.length < 10) {
        _showSnack('Geçersiz WhatsApp telefon numarası ($phoneNumber)');
        return;
      }

      if (cleaned.startsWith('0')) {
        cleaned = '90${cleaned.substring(1)}';
      } else if (!cleaned.startsWith('90')) {
        cleaned = '90$cleaned';
      }

      final message = Uri.encodeComponent('Merhaba, $studentName öğrencimiz hakkında bilgi vermek için yazıyorum.');
      final uri = Uri.parse('https://wa.me/$cleaned?text=$message');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('WhatsApp uygulaması açılamadı ($cleaned)');
      }
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (ParentContacts._openWhatsApp) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------');
      _showSnack('WhatsApp başlatılırken hata oluştu: Uygulamanın cihazda yüklü olduğunu kontrol edin.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_phone_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Henüz Öğrenci Eklenmedi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Veli rehberi için sınıfa önce öğrenci ekleyin.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

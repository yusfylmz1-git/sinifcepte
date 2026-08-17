import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/responsive_bottom_sheet.dart';
import '../../../data/models/class_model.dart';
import '../presentation/views/student_import_preview_view.dart';
import '../providers/class_provider.dart';
import 'my_class_hub_screen.dart';
import 'student_list_screen.dart';

/// SınıfCepte - Sınıf Listesi ve Otomatik Kategori/Sıralama Yönetimi Ekranı
class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  static const List<Color> _cardAccentColors = [
    Color(0xFF7B61FF), // Mor
    Color(0xFFFF8B66), // Turuncu
    Color(0xFFD96FF8), // Pembe/Mor
    Color(0xFFF25A7F), // Kırmızı/Koyu Pembe
    Color(0xFF63C6FF), // Cyan/Açık Mavi
    Color(0xFF38BDF8), // Mavi
    Color(0xFF10B981), // Yeşil
  ];

  /// Yeni Sınıf Ekle Modal Sheet
  void _showAddClassSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final subjectController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Yeni Sınıf Ekle',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Sınıf Adı',
                hintText: 'Örn: 5-A',
                prefixIcon: Icon(Icons.class_rounded),
              ),
              onChanged: (val) {
                nameController.text = InputSanitizer.cleanClassName(val);
                nameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: nameController.text.length),
                );
              },
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Sınıf adı zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Açıklama / Ders (Opsiyonel)',
                hintText: 'Örn: Matematik, Sabah Grubu',
                prefixIcon: Icon(Icons.book_rounded),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await ref.read(classListProvider.notifier).addClass(
                        name: nameController.text.trim(),
                        subject: subjectController.text.trim(),
                        academicYear: '2025-2026',
                      );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Sınıf başarıyla eklendi! 🚀' : 'Sınıf eklenirken bir hata oluştu.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sınıfı Kaydet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Sınıf Düzenle Modal Sheet
  void _showEditClassSheet(BuildContext context, WidgetRef ref, ClassModel classModel) {
    final nameController = TextEditingController(text: classModel.name);
    final subjectController = TextEditingController(text: classModel.subject);
    final formKey = GlobalKey<FormState>();

    ResponsiveBottomSheet.show(
      context: context,
      title: '${classModel.name} Sınıfını Düzenle',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Sınıf Adı',
                prefixIcon: Icon(Icons.class_rounded),
              ),
              onChanged: (val) {
                nameController.text = InputSanitizer.cleanClassName(val);
                nameController.selection = TextSelection.fromPosition(
                  TextPosition(offset: nameController.text.length),
                );
              },
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Sınıf adı zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Açıklama / Ders (Opsiyonel)',
                hintText: 'Örn: Matematik, Sabah Grubu',
                prefixIcon: Icon(Icons.book_rounded),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final success = await ref.read(classListProvider.notifier).updateClass(
                        id: classModel.id!,
                        name: nameController.text.trim(),
                        subject: subjectController.text.trim(),
                        academicYear: classModel.academicYear,
                        description: classModel.description,
                      );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Sınıf bilgileri güncellendi! ✏️' : 'Güncelleme hatası oluştu.',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Bilgileri Güncelle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeConfirmation(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Text('Sınıfları Atlat (Yıl Sonu)', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        content: Text(
          'Tüm sınıfların adındaki ilk sayı bir (1) artırılacaktır (Örn: "5-A", "6-A" olacaktır). Mezun olan sınıflar otomatik silinmez, numarası büyür.\n\nBu işlem geri alınamaz. Onaylıyor musunuz?',
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İptal', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(classListProvider.notifier).upgradeAllClasses();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sınıflar başarıyla bir üst kademeye taşındı! 🚀'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Evet, Sınıfları Atlat'),
          ),
        ],
      ),
    );
  }

  void _showMoreActionsSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.upgrade_rounded, color: AppColors.primary),
                ),
                title: const Text('Yıl Sonu: Sınıfları Atlat', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tüm sınıfları bir üst kademeye taşı'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUpgradeConfirmation(context, ref);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classListAsync = ref.watch(classListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ÜST AKSİYON BUTONLARI (Sınıfım & Sınıf Ekle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                    onPressed: () {
                      final classes = classListAsync.value ?? [];
                      if (classes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lütfen önce bir sınıf ekleyin!')),
                        );
                        return;
                      }
                      final myClass = classes.first;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyClassHubScreen(initialClass: myClass),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_suggest_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Sınıfım',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                      elevation: 0,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(width: 8),

                  // + Sınıf Ekle Butonu
                  Expanded(
                    child: ElevatedButton.icon(
                    onPressed: () => _showAddClassSheet(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Sınıf Ekle',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Daha fazla seçenek (Alt Menü)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : const Color(0xFF1E293B), size: 20),
                      onPressed: () => _showMoreActionsSheet(context, ref),
                    ),
                  ),
                ],
              ),
            ),

            // Sınıflar İçerik Alanı
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                child: RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await ref.read(classListProvider.notifier).loadClasses();
                    } catch (e, stackTrace) {
                      debugPrint('Sınıf listesi yenileme hatası: $e\n$stackTrace');
                    }
                  },
                  child: classListAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Hata: $err',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    data: (classes) {
                      if (classes.isEmpty) {
                        return _buildEmptyState(context, ref);
                      }

                      // Gruplanmış ve Sıralanmış Sınıf Liste Widget'larını Oluştur
                      final groupedWidgets = _buildGroupedClassList(context, ref, classes, isDark);

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                        children: groupedWidgets,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sınıfları Derecelerine Göre (5, 6, 7...) Gruplayan ve Sıralayan Fonksiyon
  List<Widget> _buildGroupedClassList(
    BuildContext context,
    WidgetRef ref,
    List<ClassModel> allClasses,
    bool isDark,
  ) {
    final Map<String, List<ClassModel>> groups = {};

    for (var item in allClasses) {
      // Sınıf adından seviye önekini al (Örn: "5-A" -> "5", "Hazırlık" -> "Hazırlık")
      final parts = item.name.split('-');
      final gradeLevel = parts.isNotEmpty ? parts.first.trim() : 'Diğer';

      if (!groups.containsKey(gradeLevel)) {
        groups[gradeLevel] = [];
      }
      groups[gradeLevel]!.add(item);
    }

    // Grupları Sayısal Olarak Sırala (5, 6, 7, 8...)
    final sortedGroupKeys = groups.keys.toList();
    sortedGroupKeys.sort((a, b) {
      final intA = int.tryParse(a);
      final intB = int.tryParse(b);
      if (intA != null && intB != null) {
        return intA.compareTo(intB);
      }
      return a.compareTo(b);
    });

    List<Widget> widgets = [];
    int colorIndex = 0;

    for (var grade in sortedGroupKeys) {
      final classList = groups[grade]!;

      // Şubeleri kendi içinde alfabetik sırala (A, B, C...)
      classList.sort((a, b) => a.name.compareTo(b.name));

      // Grup Başlık Widget'ı (Örn: "5. Sınıflar" | "5 Sınıf")
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 14.0, bottom: 10.0, left: 4.0, right: 4.0),
          child: Row(
            children: [
              Text(
                RegExp(r'^\d+$').hasMatch(grade) ? '$grade. Sınıflar' : '$grade Sınıfları',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Text(
                '${classList.length} Sınıf',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

      // Sınıf Kartları (2 Sütunlu Grid Görünümü İçin Wrap)
      widgets.add(
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: classList.map((classItem) {
            final cardColor = _cardAccentColors[colorIndex % _cardAccentColors.length];
            colorIndex++;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
              child: _buildClassCard(context, ref, classItem, cardColor, isDark),
            );
          }).toList(),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildClassCard(
    BuildContext context,
    WidgetRef ref,
    ClassModel classModel,
    Color accentColor,
    bool isDark,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentListScreen(classModel: classModel),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Sol Renkli Şerit
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Sınıf Adı ve Ders Bilgisi
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classModel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (classModel.subject.isNotEmpty && classModel.subject != 'Genel Ders')
                    Text(
                      classModel.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),

            // Seçenekler Menüsü 
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 19),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditClassSheet(context, ref, classModel);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, classModel.id!, classModel.name);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit', 
                  child: Row(children: [Icon(Icons.edit_rounded, size: 17), SizedBox(width: 8), Text('Düzenle')]),
                ),
                const PopupMenuItem(
                  value: 'delete', 
                  child: Row(children: [Icon(Icons.delete_rounded, color: Colors.redAccent, size: 17), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.redAccent))]),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz Sınıf Bulunmuyor',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Manuel sınıf ekleyebilir veya e-Okul PDF / Excel dosyasından otomatik yükleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showAddClassSheet(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Manuel Sınıf Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentImportPreviewView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('PDF / Excel Aktar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int classId, String className) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        title: Text(
          '$className Sınıfını Sil',
          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
        ),
        content: Text(
          'Bu sınıfı ve sınıfa ait tüm öğrenci kayıtlarını silmek istediğinize emin misiniz? (Tüm veriler temizlenecektir)',
          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('İPTAL', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(classListProvider.notifier).deleteClass(classId);
            },
            child: const Text('SİL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

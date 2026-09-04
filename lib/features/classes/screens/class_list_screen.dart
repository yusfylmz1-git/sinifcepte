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
    bool isHomeroom = false;

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Yeni Sınıf Ekle',
      child: StatefulBuilder(
        builder: (context, setStateModal) {
          return Form(
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
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Rehberlik / Şube Sınıfım',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Bu sınıfı resmî şube rehberlik sınıfınız olarak atar.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isHomeroom,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) => setStateModal(() => isHomeroom = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final success = await ref.read(classListProvider.notifier).addClass(
                            name: nameController.text.trim(),
                            subject: subjectController.text.trim(),
                            academicYear: '2025-2026',
                            isHomeroom: isHomeroom,
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
          );
        },
      ),
    );
  }

  /// Sınıf Düzenle Modal Sheet
  void _showEditClassSheet(BuildContext context, WidgetRef ref, ClassModel classModel) {
    final nameController = TextEditingController(text: classModel.name);
    final subjectController = TextEditingController(text: classModel.subject);
    final formKey = GlobalKey<FormState>();
    bool isHomeroom = classModel.isHomeroom;

    ResponsiveBottomSheet.show(
      context: context,
      title: '${classModel.name} Sınıfını Düzenle',
      child: StatefulBuilder(
        builder: (context, setStateModal) {
          return Form(
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
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Rehberlik / Şube Sınıfım',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Bu sınıfı resmî şube rehberlik sınıfınız olarak atar.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isHomeroom,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) => setStateModal(() => isHomeroom = val),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final success = await ref.read(classListProvider.notifier).updateClass(
                            id: classModel.id!,
                            name: nameController.text.trim(),
                            subject: subjectController.text.trim(),
                            academicYear: classModel.academicYear,
                            description: classModel.description,
                            isHomeroom: isHomeroom,
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
          );
        },
      ),
    );
  }

  /// Rehberlik Sınıfı Seçme / Belirleme Modal Sheet'i
  void _showSelectHomeroomSheet(BuildContext context, WidgetRef ref, List<ClassModel> classes) {
    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce bir sınıf ekleyin!')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentHomeroom = classes.where((c) => c.isHomeroom).firstOrNull;
    int? selectedId = currentHomeroom?.id ?? classes.first.id;

    ResponsiveBottomSheet.show(
      context: context,
      title: 'Rehberlik Sınıfınızı Seçin',
      builder: (ctx, setStateModal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Şube rehber öğretmenliğini yürüttüğünüz sınıfı seçin. Resmî evraklar, oturma planı ve veli portalı bu sınıfınız üzerinden yönetilir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Sınıflarınız:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Sınıf Listesi
            ...classes.map((c) {
              final isSelected = selectedId == c.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white12 : Colors.black12),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setStateModal(() => selectedId = c.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (c.isHomeroom)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Mevcut Şube',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
      bottomActionBuilder: (ctx, setStateModal) {
        return ElevatedButton.icon(
          onPressed: selectedId == null
              ? null
              : () async {
                  final targetClass = classes.firstWhere((c) => c.id == selectedId);
                  Navigator.pop(ctx);

                  await ref.read(classListProvider.notifier).setHomeroomClass(selectedId!);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${targetClass.name} Rehberlik Sınıfınız olarak belirlendi! 🌟'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );

                    // Doğrudan Sınıfım ekranına yönlendir
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MyClassHubScreen(initialClass: targetClass),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('Kaydet ve Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        );
      },
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
                    color: const Color(0xFFFF512F).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF512F)),
                ),
                title: const Text('PDF İle Sınıf Yükle', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('e-Okul listesini okuyup sınıfı ve öğrencileri otomatik oluşturur'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentImportPreviewView(autoPickPdf: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
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
            // ÜST AKSİYON BUTONLARI (Sınıf Ekle & PDF İçe Aktar & Diğer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // + Sınıf Ekle Butonu
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddClassSheet(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Yeni Sınıf Ekle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 📄 PDF / Excel Liste Yükle Butonu
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF512F).withValues(alpha: isDark ? 0.5 : 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF512F).withValues(alpha: isDark ? 0.2 : 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF512F), size: 19),
                      tooltip: 'PDF ile Sınıf Yükle',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentImportPreviewView(autoPickPdf: true),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Daha fazla seçenek (Alt Menü)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white70 : const Color(0xFF1E293B), size: 20),
                      tooltip: 'Diğer İşlemler',
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

    final homeroomClass = allClasses.where((c) => c.isHomeroom).firstOrNull;
    List<Widget> widgets = [];

    // ⭐ VIP REHBERLİK & ŞUBE MERKEZİ HERO BANNER
    if (homeroomClass != null) {
      widgets.add(_buildHomeroomHeroBanner(context, ref, homeroomClass, isDark));
    } else {
      widgets.add(_buildNoHomeroomBanner(context, ref, allClasses, isDark));
    }

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
              width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2,
              child: _buildClassCard(context, ref, classItem, cardColor, isDark),
            );
          }).toList(),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  /// ⭐ VIP Rehberlik Sınıfı Hero Banner Widget'ı
  Widget _buildHomeroomHeroBanner(
    BuildContext context,
    WidgetRef ref,
    ClassModel homeroomClass,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4338CA), const Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF4338CA) : const Color(0xFF818CF8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.35 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MyClassHubScreen(initialClass: homeroomClass),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 15),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'REHBERLİK & ŞUBE MERKEZİ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Yönet',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${homeroomClass.name} Sınıfım',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Oturma Planı • Sosyometri • Resmî Evraklar • Veli Portalı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 📌 Rehberlik Sınıfı Belirlenmemişse Gösterilen Rehber Kartı
  Widget _buildNoHomeroomBanner(
    BuildContext context,
    WidgetRef ref,
    List<ClassModel> classes,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF271A0C), const Color(0xFF451A03)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSelectHomeroomSheet(context, ref, classes),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: isDark ? 0.25 : 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rehberlik Sınıfınızı Belirleyin',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Şube evrakları ve veli portalı için sınıf atayın.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.amber.shade200.withValues(alpha: 0.8) : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showSelectHomeroomSheet(context, ref, classes),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Belirle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

            // Sınıf Adı ve Ders / Rehberlik Bilgisi
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Sınıf Adı (5-A, 5-B) & Rehberlik Yıldızı
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          classModel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (classModel.isHomeroom) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.stars_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),

                  // 2. Alt Bilgi: Rehberlik Rozeti veya Ders Adı
                  if (classModel.isHomeroom)
                    Text(
                      classModel.subject.isNotEmpty && classModel.subject != 'Genel Ders'
                          ? 'Rehberlik • ${classModel.subject}'
                          : 'Rehberlik Sınıfı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  else if (classModel.subject.isNotEmpty && classModel.subject != 'Genel Ders')
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
              onSelected: (value) async {
                if (value == 'edit') {
                  _showEditClassSheet(context, ref, classModel);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref, classModel.id!, classModel.name);
                } else if (value == 'set_homeroom') {
                  await ref.read(classListProvider.notifier).setHomeroomClass(classModel.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${classModel.name} Rehberlik Sınıfınız olarak belirlendi! 🌟'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                } else if (value == 'clear_homeroom') {
                  await ref.read(classListProvider.notifier).clearHomeroomClass(classModel.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${classModel.name} rehberlik sınıfı unvanı kaldırıldı.'),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                if (!classModel.isHomeroom)
                  const PopupMenuItem(
                    value: 'set_homeroom',
                    child: Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.primary, size: 17),
                        SizedBox(width: 8),
                        Text('Rehberlik Sınıfı Yap'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'clear_homeroom',
                    child: Row(
                      children: [
                        Icon(Icons.star_border_rounded, size: 17),
                        SizedBox(width: 8),
                        Text('Rehberlikten Çıkar'),
                      ],
                    ),
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showAddClassSheet(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Manuel Sınıf Ekle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StudentImportPreviewView(autoPickPdf: true),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                          color: Color(0xFFFF512F),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'PDF İle Sınıf Aktar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

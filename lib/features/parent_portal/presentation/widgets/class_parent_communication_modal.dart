import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/class_announcement_model.dart';
import '../../providers/parent_portal_provider.dart';

/// SınıfCepte - Öğretmen Veli İletişim, Duyuru & Randevu Merkezi Modalı
class ClassParentCommunicationModal extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ClassParentCommunicationModal({super.key, required this.classModel});

  static Future<void> show(BuildContext context, {required ClassModel classModel}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassParentCommunicationModal(classModel: classModel),
    );
  }

  @override
  ConsumerState<ClassParentCommunicationModal> createState() => _ClassParentCommunicationModalState();
}

class _ClassParentCommunicationModalState extends ConsumerState<ClassParentCommunicationModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Tutamaç
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.classModel.name} Veli İletişim Merkezi',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Duyurular, veli bildirimleri ve randevular',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Sekmeler
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: '📢 Duyurular'),
              Tab(text: '📬 Bildirimler'),
              Tab(text: '📅 Randevular'),
            ],
          ),

          // Sekme İçerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementsTab(context, isDark),
                _buildStatusReportsTab(context, isDark),
                _buildAppointmentsTab(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. DUYURULAR SEKMESİ ---
  Widget _buildAnnouncementsTab(BuildContext context, bool isDark) {
    final announcementsAsync = ref.watch(classAnnouncementsProvider(widget.classModel.id!));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Duyuru Ekle Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openAddAnnouncementDialog(context),
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: const Text('Yeni Sınıf Duyurusu Yayınla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: announcementsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Duyurular yüklenemedi: $e')),
              data: (announcements) {
                if (announcements.isEmpty) {
                  return const Center(child: Text('Yayınlanmış duyuru bulunmuyor.'));
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: announcements.length,
                  itemBuilder: (context, idx) {
                    final a = announcements[idx];
                    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(a.createdAt);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(a.priorityIcon, size: 16, color: a.priorityColor),
                                  const SizedBox(width: 6),
                                  Text(a.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '👁️ ${a.readCount} Veli Okudu',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(a.content, style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateStr, style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.grey)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () async {
                                  final repo = ref.read(parentPortalRepositoryProvider);
                                  await repo.deleteAnnouncement(a.id);
                                  ref.invalidate(classAnnouncementsProvider(widget.classModel.id!));
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAddAnnouncementDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String priority = 'normal';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Yeni Sınıf Duyurusu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Duyuru Başlığı', hintText: 'Örn: Veli Toplantısı'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Duyuru Metni', hintText: 'Detayları buraya yazın...'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Önem Derecesi'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal Duyuru 📢')),
                  DropdownMenuItem(value: 'urgent', child: Text('Acil Bildirim 🚨')),
                  DropdownMenuItem(value: 'event', child: Text('Etkinlik / Toplantı 📅')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      priority = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isNotEmpty && content.isNotEmpty) {
                  Navigator.of(ctx).pop();
                  final teacher = ref.read(teacherProfileProvider);
                  final newAnn = ClassAnnouncementModel(
                    id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
                    classId: widget.classModel.id!,
                    className: widget.classModel.name,
                    authorTeacherId: teacher.id,
                    authorTeacherName: teacher.fullName,
                    title: title,
                    content: content,
                    priority: priority,
                    createdAt: DateTime.now(),
                  );

                  final repo = ref.read(parentPortalRepositoryProvider);
                  await repo.createAnnouncement(newAnn);
                  ref.invalidate(classAnnouncementsProvider(widget.classModel.id!));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Yayınla'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. GELEN VELİ BİLDİRİMLERİ SEKMESİ ---
  Widget _buildStatusReportsTab(BuildContext context, bool isDark) {
    final reportsAsync = ref.watch(classStatusReportsProvider(widget.classModel.id!));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Bildirimler yüklenemedi: $e')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('Gelen veli bildirimi bulunmuyor.'));
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: reports.length,
            itemBuilder: (context, idx) {
              final r = reports[idx];
              final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(r.typeIcon, size: 18, color: r.typeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '#${r.studentNumber} ${r.studentName} (${r.relation}: ${r.parentName})',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (!r.isAcknowledged)
                          ElevatedButton(
                            onPressed: () async {
                              final repo = ref.read(parentPortalRepositoryProvider);
                              await repo.acknowledgeStatusReport(r.id);
                              ref.invalidate(classStatusReportsProvider(widget.classModel.id!));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Görüldü Yap', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Görüldü ✅', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.title}: ${r.details}',
                      style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- 3. RANDEVULAR SEKMESİ ---
  Widget _buildAppointmentsTab(BuildContext context, bool isDark) {
    final appointmentsAsync = ref.watch(classAppointmentsProvider(widget.classModel.id!));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Randevular yüklenemedi: $e')),
        data: (appointments) {
          if (appointments.isEmpty) {
            return const Center(child: Text('Bekleyen veli randevu talebi bulunmuyor.'));
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: appointments.length,
            itemBuilder: (context, idx) {
              final app = appointments[idx];
              final dateStr = DateFormat('dd.MM.yyyy').format(app.appointmentDate);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${app.studentName} • ${app.parentName} (${app.relation})',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: app.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            app.statusTitleTr,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: app.statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Öğretmen: ${app.teacherName} • $dateStr ${app.timeSlot}', style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text('Konu: ${app.topic}', style: GoogleFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    if (app.isPending) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              final repo = ref.read(parentPortalRepositoryProvider);
                              await repo.updateAppointmentStatus(app.id, status: 'rejected');
                              ref.invalidate(classAppointmentsProvider(widget.classModel.id!));
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Reddet', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final repo = ref.read(parentPortalRepositoryProvider);
                              await repo.updateAppointmentStatus(app.id, status: 'confirmed');
                              ref.invalidate(classAppointmentsProvider(widget.classModel.id!));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Onayla', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

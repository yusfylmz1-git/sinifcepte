import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/class_announcement_model.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_portal_provider.dart';
import 'class_staff_manager_modal.dart';
import '../../data/services/communication_ids.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../data/models/parent_link_model.dart';
import '../../providers/parent_token_provider.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import 'parent_teacher_chat_modal.dart';

/// SınıfCepte - Öğretmen Veli İletişim, Duyuru & Randevu Merkezi Modalı
class ClassParentCommunicationModal extends ConsumerStatefulWidget {
  final ClassModel classModel;

  /// Açılışta gösterilecek sekme (0=Duyurular, 1=Mesajlar, 2=Bildirimler,
  /// 3=Randevular, 4=Kadro).
  final int initialTab;

  /// Panelin içine gömülü mü gösteriliyor?
  ///
  /// true ise alt sayfa kabuğu (tutamaç, sabit yükseklik, yuvarlak
  /// köşeler, başlık) çizilmez — bileşen bulunduğu alanı doldurur.
  /// Böylece bu ekranın kodu TEK YERDE kalır: panel onu kopyalamak
  /// yerine gömer.
  final bool embedded;

  const ClassParentCommunicationModal({
    super.key,
    required this.classModel,
    this.initialTab = 0,
    this.embedded = false,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
    int initialTab = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassParentCommunicationModal(
        classModel: classModel,
        initialTab: initialTab,
      ),
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
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Bu sınıfın bulut kimliği. Veli tarafı duyuru, bildirim ve randevuları
  /// bu kimlik altında görür.
  String get _classCloudId {
    final teacher = ref.read(teacherProfileProvider);
    return CloudIds.classId(
      // Kod üretimi ve kadro ekranıyla AYNI kimlik: `teacher.id` yer
      // tutucu olabiliyor ve farklı bir sınıf odası üretiyordu.
      teacherUid: TeacherIdentity.resolve(teacher),
      localClassId: widget.classModel.id ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Gömülü kipte alt sayfa kabuğu (sabit yükseklik, yuvarlak köşeler,
    // tutamaç, başlık) çizilmez: panel bu bileşeni kendi Scaffold'una
    // koyar. Böylece ekranın kodu TEK YERDE kalır — panel onu
    // kopyalamak yerine gömer.
    final embedded = widget.embedded;

    return Container(
      height: embedded ? null : MediaQuery.sizeOf(context).height * 0.85,
      decoration: embedded
          ? null
          : BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
      child: Column(
        children: [
          // Tutamaç
          if (!embedded)
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

          // Başlık (gömülü kipte panelin kendi başlığı var)
          if (!embedded)
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
                        style: AppFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Duyurular, veli bildirimleri ve randevular',
                        style: AppFonts.outfit(
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
            labelStyle: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: '📢 Duyurular'),
              Tab(text: '💬 Mesajlar'),
              Tab(text: '📬 Bildirimler'),
              Tab(text: '📅 Randevular'),
              Tab(text: '👥 Kadro'),
            ],
          ),

          // Sekme İçerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnnouncementsTab(context, isDark),
                _buildMessagesTab(context, isDark),
                _buildStatusReportsTab(context, isDark),
                _buildAppointmentsTab(context, isDark),
                _buildStaffTab(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. DUYURULAR SEKMESİ ---
  /// Öğretmenin mesaj kutusu.
  ///
  /// Bu sekme YOKTU: sohbet ekranı yalnızca veli tarafından açılabiliyordu,
  /// öğretmenin gelen mesajları görebileceği hiçbir yer bulunmuyordu.
  /// (Eskiden veli token kartında bir giriş vardı; o ekran kaldırılınca
  /// öğretmen tarafı tümüyle kapandı.)
  Widget _buildMessagesTab(BuildContext context, bool isDark) {
    final teacher = ref.watch(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);
    final parentsAsync =
        ref.watch(classLinkedParentsProvider(widget.classModel));

    if (!CloudIds.isValidUid(uid)) {
      return _buildInfoState(
        icon: Icons.login_rounded,
        text: 'Mesajlaşma için Google ile giriş yapmanız gerekiyor.',
        isDark: isDark,
      );
    }

    return parentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildInfoState(
        icon: Icons.error_outline_rounded,
        text: 'Veli listesi yüklenemedi.',
        isDark: isDark,
      ),
      data: (parents) {
        if (parents.isEmpty) {
          return _buildInfoState(
            icon: Icons.forum_outlined,
            text: 'Henüz bağlı veli yok.\nReferans kodlarını dağıttıktan '
                'sonra veliler burada görünecek.',
            isDark: isDark,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(classLinkedParentsProvider(widget.classModel));
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: parents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final link = parents[i];
              return Material(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => _openChatWithParent(link, uid, teacher),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            link.studentName.isNotEmpty
                                ? link.studentName.characters.first
                                    .toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
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
                                link.studentName,
                                style: AppFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${link.relation}: ${link.parentName}',
                                style: AppFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 19, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openChatWithParent(
    ParentLinkModel link,
    String uid,
    TeacherProfileModel teacher,
  ) {
    ParentTeacherChatModal.show(
      context,
      classCloudId: link.classCloudId.isNotEmpty
          ? link.classCloudId
          : CloudIds.classId(
              teacherUid: uid,
              localClassId: widget.classModel.id ?? 0,
            ),
      studentCloudId: link.studentCloudId.isNotEmpty
          ? link.studentCloudId
          : CloudIds.studentId(
              teacherUid: uid,
              localStudentId: link.studentId,
            ),
      studentName: link.studentName,
      parentUserId: link.parentUserId,
      selfName: teacher.fullName,
      selfUid: uid,
      asTeacher: true,
      counterpartName: '${link.relation}: ${link.parentName}',
      // Öğretmen kendi sohbetini açar.
      teacherUid: uid,
    );
  }

  Widget _buildInfoState({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 13),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          // Başlık uzun olabilir; rozet sabit genişlikte.
                          // Başlık Expanded içine alınmazsa rozetle birlikte
                          // taşar (AGENTS.md Madde 8).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(a.priorityIcon, size: 16, color: a.priorityColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: AppFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '👁️ ${a.readCount}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.content,
                            style: AppFonts.outfit(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateStr, style: AppFonts.outfit(fontSize: 10.5, color: Colors.grey)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                onPressed: () async {
                                  final repo = ref.read(parentPortalRepositoryProvider);
                                  await repo.deleteAnnouncement(a.id);

                                  // Buluttan da sil: aksi halde duyuru
                                  // öğretmende kaybolur ama velilerde
                                  // görünmeye devam ederdi.
                                  await ref
                                      .read(cloudCommunicationRepositoryProvider)
                                      .deleteAnnouncement(
                                        classCloudId: _classCloudId,
                                        announcementId: a.id,
                                      );

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
    // Sınav ve etkinlik duyurularında tarih sorulur; takvimde bu tarihe
    // göre sıralanır. Ayrı bir "sınav" koleksiyonu açılmadı — duyuru
    // altyapısı kullanıldığı için ek maliyet doğmaz.
    DateTime? eventAt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Yeni Sınıf Duyurusu', style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                // Uzunluk sınırı: sınırsız metin Firestore doküman
                // sınırını (1 MiB) zorluyor ve arayüzü taşırıyordu.
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Duyuru Başlığı', hintText: 'Örn: Veli Toplantısı'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Duyuru Metni', hintText: 'Detayları buraya yazın...'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Önem Derecesi'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal Duyuru 📢')),
                  DropdownMenuItem(value: 'urgent', child: Text('Acil Bildirim 🚨')),
                  DropdownMenuItem(value: 'exam', child: Text('Sınav 📝')),
                  DropdownMenuItem(value: 'event', child: Text('Etkinlik / Toplantı 📅')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      priority = val;
                      // Tarih yalnızca sınav ve etkinlikte anlamlı.
                      if (val != 'exam' && val != 'event') eventAt = null;
                    });
                  }
                },
              ),
              if (priority == 'exam' || priority == 'event') ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: eventAt ?? now.add(const Duration(days: 7)),
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                      locale: const Locale('tr', 'TR'),
                    );
                    if (picked != null) {
                      setDialogState(() => eventAt = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: priority == 'exam'
                          ? 'Sınav Tarihi'
                          : 'Etkinlik Tarihi',
                      prefixIcon: const Icon(Icons.event_rounded, size: 19),
                    ),
                    child: Text(
                      eventAt == null
                          ? 'Tarih seçin (isteğe bağlı)'
                          : AppDateFormatter.formatTurkishDate(eventAt!),
                      style: AppFonts.outfit(
                        fontSize: 13.5,
                        color: eventAt == null ? Colors.grey : null,
                      ),
                    ),
                  ),
                ),
              ],
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
                    id: CommunicationIds.announcement(
                        authorUid: teacher.id),
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

                  // Buluta da yayımla: veliler duyuruyu ancak buradan görür.
                  // Öğretmenin cihazındaki kayıt yalnızca kendi arşividir.
                  final cloudRepo =
                      ref.read(cloudCommunicationRepositoryProvider);
                  final classCloudId = CloudIds.classId(
                    teacherUid: TeacherIdentity.resolve(teacher),
                    localClassId: widget.classModel.id!,
                  );

                  // Sınıf odası yoksa duyuru yazılamaz (kurallar bu dokümanın
                  // varlığına dayanır).
                  await cloudRepo.ensureClassRoom(
                    classCloudId: classCloudId,
                    className: widget.classModel.name,
                    teacherUid: teacher.id,
                    teacherName: teacher.fullName,
                    schoolId: teacher.schoolId ?? '',
                    schoolName: teacher.schoolName,
                  );

                  final published = await cloudRepo.publishAnnouncement(
                    classCloudId: classCloudId,
                    announcementId: newAnn.id,
                    title: title,
                    content: content,
                    authorName: teacher.fullName,
                    authorUid: teacher.id,
                    priority: priority,
                    eventAt: eventAt,
                  );

                  if (context.mounted && !published) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Duyuru cihazınıza kaydedildi ancak velilere gönderilemedi. '
                          'İnternet bağlantısı gelince tekrar yayınlayın.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 6),
                      ),
                    );
                  }
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

  // --- 4. DERS ÖĞRETMENİ KADROSU SEKMESİ ---
  //
  // Kullanıcı kararı gereği duyuru yetkisi yalnızca sınıf öğretmenindedir,
  // ancak veli çocuğunun dersine giren branş öğretmenleriyle de
  // yazışabilmelidir. Mesajlaşma yetkisi bu kadrodan yönetilir.
  Widget _buildStaffTab(BuildContext context, bool isDark) {
    final teacher = ref.watch(teacherProfileProvider);

    // Google girişi yapılmamışsa bulut kimliği üretilemez. Sessizce boş
    // liste göstermek yerine sebebi söylenir.
    if (!CloudIds.isValidUid(teacher.id)) {
      return _buildSignInRequired(isDark);
    }

    final classCloudId = CloudIds.classId(
      teacherUid: teacher.id,
      localClassId: widget.classModel.id ?? 0,
    );
    final staffAsync = ref.watch(classStaffProvider(classCloudId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kadrodaki öğretmenler bu sınıfın velileriyle yazışabilir. '
            'Duyuru yayınlama yetkisi yalnızca sizde kalır.',
            style: AppFonts.outfit(
              fontSize: 12,
              color: Colors.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Kadro yüklenemedi. İnternet bağlantınızı kontrol edin.',
                  style: AppFonts.outfit(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (staff) {
                if (staff.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.groups_outlined,
                            size: 42, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'Henüz ders öğretmeni eklenmedi',
                          style: AppFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: staff.length,
                  itemBuilder: (context, idx) {
                    final m = staff[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.displayTitle,
                                  style: AppFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  m.meetingDay.isEmpty && m.meetingTime.isEmpty
                                      ? 'Yazışmaya açık'
                                      : '${m.meetingDay} ${m.meetingTime}'.trim(),
                                  style: AppFonts.outfit(
                                    fontSize: 11.5,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ClassStaffManagerModal.show(
                context,
                classModel: widget.classModel,
              ),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Kadroyu Yönet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bulut özellikleri için Google girişi gerektiğini anlatır.
  Widget _buildSignInRequired(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Google girişi gerekiyor',
              style: AppFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Duyuru, mesajlaşma ve kadro özellikleri velilerle paylaşılan '
              'buluta bağlıdır. Profil ekranından Google ile giriş yaptığınızda '
              'bu bölüm açılır. Sınıf ve öğrenci kayıtlarınız girişten '
              'bağımsız olarak cihazınızda çalışmaya devam eder.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 12.5,
                color: Colors.grey,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. GELEN VELİ BİLDİRİMLERİ SEKMESİ ---
  Widget _buildStatusReportsTab(BuildContext context, bool isDark) {
    // Bildirimler buluttan gelir: veli kendi telefonundan gönderdiği için
    // öğretmenin cihazında yerel kaydı bulunmaz.
    final reportsAsync = ref.watch(classStatusReportsCloudProvider(_classCloudId));

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
                            '${r.studentName} (${r.relation}: ${r.parentName})',
                            style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!r.isAcknowledged)
                          ElevatedButton(
                            onPressed: () async {
                              await ref
                                  .read(cloudCommunicationRepositoryProvider)
                                  .acknowledgeStatusReport(
                                    classCloudId: _classCloudId,
                                    reportId: r.id,
                                  );
                              ref.invalidate(
                                classStatusReportsCloudProvider(_classCloudId),
                              );
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
                      style: AppFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: AppFonts.outfit(fontSize: 10.5, color: Colors.grey)),
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
    // Randevu talepleri de buluttan gelir (veli kendi cihazından gönderir).
    final appointmentsAsync =
        ref.watch(classAppointmentsCloudProvider(_classCloudId));

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
                            style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    Text('Öğretmen: ${app.teacherName} • $dateStr ${app.timeSlot}', style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,),
                    const SizedBox(height: 4),
                    Text('Konu: ${app.topic}', style: AppFonts.outfit(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                    if (app.isPending) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(cloudCommunicationRepositoryProvider)
                                  .updateAppointmentStatus(
                                    classCloudId: _classCloudId,
                                    appointmentId: app.id,
                                    status: 'rejected',
                                  );
                              ref.invalidate(
                                classAppointmentsCloudProvider(_classCloudId),
                              );
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
                              await ref
                                  .read(cloudCommunicationRepositoryProvider)
                                  .updateAppointmentStatus(
                                    classCloudId: _classCloudId,
                                    appointmentId: app.id,
                                    status: 'confirmed',
                                  );
                              ref.invalidate(
                                classAppointmentsCloudProvider(_classCloudId),
                              );
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/class_model.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/class_announcement_model.dart';
import '../../data/services/communication_ids.dart';
import '../../providers/cloud_communication_provider.dart';
import '../../providers/parent_portal_provider.dart';

/// Sınıf duyurusu yazma penceresi (Veliler sayfasındaki "Duyuru yap").
///
/// Eskiden veli iletişim penceresinin "Duyurular" sekmesindeydi; o
/// pencere kalkınca buraya taşındı (18 Ekim 2026).
///
/// Yazar ve sınıf odası kimliği [TeacherIdentity.resolve] ile çözülür.
/// Eskiden `teacher.id` kullanılıyordu; profildeki kimlik yer tutucu
/// olduğunda sunucu kuralı (`authorUid == request.auth.uid`) yazmayı
/// reddediyordu.
Future<void> sinifDuyurusuYaz(
  BuildContext context,
  WidgetRef ref,
  ClassModel classModel,
) {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  String priority = 'normal';
  // Sınav ve etkinlik duyurularında tarih sorulur; takvimde bu tarihe
  // göre sıralanır. Ayrı bir "sınav" koleksiyonu açılmadı — duyuru
  // altyapısı kullanıldığı için ek maliyet doğmaz.
  DateTime? eventAt;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${classModel.name} velilerine duyuru',
          style: AppFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                // Uzunluk sınırı: sınırsız metin Firestore doküman
                // sınırını (1 MiB) zorluyor ve arayüzü taşırıyordu.
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Duyuru Başlığı',
                  hintText: 'Örn: Veli Toplantısı',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Duyuru Metni',
                  hintText: 'Detayları buraya yazın...',
                ),
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
                      labelText: priority == 'exam' ? 'Sınav Tarihi' : 'Etkinlik Tarihi',
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
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              Navigator.of(ctx).pop();
              await _yayinla(
                context,
                ref,
                classModel,
                title: title,
                content: content,
                priority: priority,
                eventAt: eventAt,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yayınla'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _yayinla(
  BuildContext context,
  WidgetRef ref,
  ClassModel classModel, {
  required String title,
  required String content,
  required String priority,
  required DateTime? eventAt,
}) async {
  final teacher = ref.read(teacherProfileProvider);
  final uid = TeacherIdentity.resolve(teacher);
  final newAnn = ClassAnnouncementModel(
    id: CommunicationIds.announcement(authorUid: uid),
    classId: classModel.id!,
    className: classModel.name,
    authorTeacherId: uid,
    authorTeacherName: teacher.fullName,
    title: title,
    content: content,
    priority: priority,
    createdAt: DateTime.now(),
  );

  // Öğretmenin cihazındaki kayıt yalnızca kendi arşividir.
  final repo = ref.read(parentPortalRepositoryProvider);
  await repo.createAnnouncement(newAnn);
  ref.invalidate(classAnnouncementsProvider(classModel.id!));

  // Buluta da yayımla: veliler duyuruyu ancak buradan görür.
  var published = false;
  if (CloudIds.isValidUid(uid)) {
    final cloudRepo = ref.read(cloudCommunicationRepositoryProvider);
    final classCloudId = CloudIds.classId(
      teacherUid: uid,
      localClassId: classModel.id!,
    );

    // Sınıf odası yoksa duyuru yazılamaz (kurallar bu dokümanın
    // varlığına dayanır).
    await cloudRepo.ensureClassRoom(
      classCloudId: classCloudId,
      className: classModel.name,
      teacherUid: uid,
      teacherName: teacher.fullName,
      schoolId: teacher.schoolId ?? '',
      schoolName: teacher.schoolName,
    );

    published = await cloudRepo.publishAnnouncement(
      classCloudId: classCloudId,
      announcementId: newAnn.id,
      title: title,
      content: content,
      authorName: teacher.fullName,
      authorUid: uid,
      priority: priority,
      eventAt: eventAt,
    );
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        published
            ? 'Duyuru velilere gönderildi.'
            : 'Duyuru cihazınıza kaydedildi ancak velilere gönderilemedi. '
                'İnternet bağlantısı gelince tekrar yayınlayın.',
      ),
      backgroundColor: published ? const Color(0xFF10B981) : Colors.orange,
      duration: Duration(seconds: published ? 3 : 6),
    ),
  );
}

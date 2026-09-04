import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../data/models/class_model.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../data/services/communication_ids.dart';
import '../../providers/cloud_communication_provider.dart';

/// Birden fazla sınıfa aynı anda duyuru gönderme.
///
/// ## Neden gerekli
/// Duyuru yayımlama tek sınıfa bağlıydı ve yalnızca **sınıf öğretmeni**
/// yapabiliyordu. Oysa matematik öğretmeni beş sınıfa giriyor ve
/// "yarın quiz var" duyurusunu hepsine yapmak istiyor; bunu ancak her
/// sınıfın rehber öğretmeninden rica ederek yapabiliyordu.
///
/// Güvenlik kuralı kadro üyeliğini doğrular: öğretmen yalnızca
/// **girdiği** sınıflara yazabilir.
class BulkAnnouncementScreen extends ConsumerStatefulWidget {
  const BulkAnnouncementScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BulkAnnouncementScreen(),
      ),
    );
  }

  @override
  ConsumerState<BulkAnnouncementScreen> createState() =>
      _BulkAnnouncementScreenState();
}

class _BulkAnnouncementScreenState
    extends ConsumerState<BulkAnnouncementScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final Set<int> _selected = {};
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending &&
      _selected.isNotEmpty &&
      _titleCtrl.text.trim().isNotEmpty &&
      _bodyCtrl.text.trim().isNotEmpty;

  Future<void> _send(List<ClassModel> classes) async {
    if (!_canSend) return;
    setState(() => _sending = true);

    final messenger = ScaffoldMessenger.of(context);
    final teacher = ref.read(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);

    if (!CloudIds.isValidUid(uid)) {
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Oturum bilgisi okunamadı.')),
      );
      return;
    }

    final repo = ref.read(cloudCommunicationRepositoryProvider);
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    var basarili = 0;
    var basarisiz = 0;

    for (final c in classes.where((c) => _selected.contains(c.id))) {
      final classCloudId = CloudIds.classId(
        teacherUid: uid,
        localClassId: c.id ?? 0,
      );

      // Sınıf odası yoksa oluştur; yoksa duyuru yazılacak yer olmaz.
      await repo.ensureClassRoom(
        classCloudId: classCloudId,
        className: c.name,
        teacherUid: uid,
        teacherName: teacher.fullName,
        schoolId: teacher.schoolId ?? '',
        schoolName: teacher.schoolName,
      );

      final ok = await repo.publishAnnouncement(
        classCloudId: classCloudId,
        announcementId: CommunicationIds.announcement(authorUid: uid),
        title: title,
        content: body,
        authorName: teacher.fullName,
        authorUid: uid,
      );

      if (ok) {
        basarili++;
      } else {
        basarisiz++;
      }
    }

    if (!mounted) return;
    setState(() => _sending = false);

    // Kaç sınıfa gittiği AÇIKÇA söylenir: "gönderildi" deyip bir
    // kısmının başarısız olması, öğretmenin duyurunun ulaştığını
    // sanmasına yol açardı.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          basarisiz == 0
              ? '$basarili sınıfa duyuru gönderildi.'
              : '$basarili sınıfa gönderildi, $basarisiz sınıfa '
                  'gönderilemedi. İnternet bağlantınızı kontrol edin.',
        ),
        backgroundColor:
            basarisiz == 0 ? const Color(0xFF10B981) : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );

    if (basarisiz == 0 && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classListProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(title: 'Toplu Duyuru'),
      body: SafeArea(
        child: classes.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Henüz sınıfınız yok. Duyuru göndermek için önce '
                    'sınıf eklemelisiniz.',
                    textAlign: TextAlign.center,
                    style: AppFonts.outfit(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Hangi sınıflara?',
                    style: AppFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Girdiğiniz tüm sınıflara aynı anda gönderebilirsiniz.',
                    style: AppFonts.outfit(
                      fontSize: 11.5,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Hepsini seç / bırak
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        if (_selected.length == classes.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(classes.map((c) => c.id ?? 0));
                        }
                      }),
                      icon: Icon(
                        _selected.length == classes.length
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _selected.length == classes.length
                            ? 'Seçimi Kaldır'
                            : 'Tümünü Seç',
                        style: AppFonts.outfit(fontSize: 12.5),
                      ),
                    ),
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: classes.map((c) {
                      final secili = _selected.contains(c.id);
                      return InkWell(
                        onTap: () => setState(() {
                          if (secili) {
                            _selected.remove(c.id);
                          } else {
                            _selected.add(c.id ?? 0);
                          }
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: secili
                                ? AppColors.primary
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: secili
                                  ? AppColors.primary
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Text(
                            c.name,
                            style: AppFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: secili
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleCtrl,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      hintText: 'Örn: Yarın Matematik Quiz',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 5,
                    maxLength: 2000,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Duyuru metni',
                      hintText: 'Örn: 3. ünite konularından 20 soruluk quiz.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _canSend ? () => _send(classes) : null,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.campaign_rounded),
                      label: Text(
                        _sending
                            ? 'Gönderiliyor...'
                            : _selected.isEmpty
                                ? 'Sınıf seçin'
                                : '${_selected.length} sınıfa gönder',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

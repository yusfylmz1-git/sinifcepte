import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/student_name_formatter.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/student_provider.dart';
import '../../data/models/parent_token_model.dart';
import '../../data/services/token_share_service.dart';
import '../../providers/parent_token_provider.dart';
import '../../../../core/cloud/cloud_ids.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/repositories/cloud_token_repository.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../../core/utils/search_debouncer.dart';
import '../../../../core/utils/turkish_text.dart';

/// SınıfCepte - Sınıf Düzeyinde Veli Referans Kodları Tek Liste Modalı & Ekranı
class ClassReferenceCodesModal extends ConsumerStatefulWidget {
  final ClassModel classModel;

  const ClassReferenceCodesModal({
    super.key,
    required this.classModel,
  });

  static Future<void> show(
    BuildContext context, {
    required ClassModel classModel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClassReferenceCodesModal(classModel: classModel),
    );
  }

  @override
  ConsumerState<ClassReferenceCodesModal> createState() => _ClassReferenceCodesModalState();
}

class _ClassReferenceCodesModalState extends ConsumerState<ClassReferenceCodesModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// 1111 satirlik modalin her tusta bastan cizilmesini onler.
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  final Set<int> _generatingStudentIds = {};
  bool _isBulkRenewing = false;
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _safeHaptic() {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  /// Tek Bir Öğrenci İçin Referans Kodunu Yenile
  /// Öğrenciye bağlı velileri gösterir.
  ///
  /// "Kodu gönderdim ama bağlandı mı?" sorusunun tek cevap yeri burasıdır.
  /// Öğretmen bağı buradan kaldırabilir (ör. velayeti olmayan biri
  /// bağlandıysa).
  Future<void> _showLinkedParents(StudentModel student) async {
    if (student.id == null) return;
    final repo = ref.read(parentTokenRepositoryProvider);
    final links = await repo.getLinkedParentsForStudent(student.id!);
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          '${student.fullName} — Bağlı Veliler',
          style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: links.isEmpty
              ? Text(
                  'Henüz kimse bağlanmadı. Referans kodunu veliye ilettikten '
                  'sonra buradan takip edebilirsiniz.',
                  style: AppFonts.outfit(fontSize: 13, color: Colors.grey),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final link in links)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_user_rounded,
                            color: Color(0xFF10B981), size: 20),
                        title: Text(link.parentName,
                            style: AppFonts.outfit(
                                fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(link.relation,
                            style: AppFonts.outfit(
                                fontSize: 11.5, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.link_off_rounded,
                              size: 18, color: Colors.redAccent),
                          tooltip: 'Bağı kaldır',
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _removeLink(student, link);
                          },
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  /// Tek bir velinin bağını kaldırır (yerel + bulut).
  Future<void> _removeLink(StudentModel student, ParentLinkModel link) async {
    final teacher = ref.read(teacherProfileProvider);
    final repo = ref.read(parentTokenRepositoryProvider);

    await repo.removeParentLink(
      link.id,
      actorId: teacher.id,
      actorRole: 'teacher',
      reason: 'Öğretmen bağı kaldırdı',
    );

    // Bulut tarafı: bağ ve sınıf erişimi silinmezse veli duyuruları
    // görmeye devam ederdi.
    var cloudOk = true;
    if (CloudIds.isValidUid(teacher.id)) {
      cloudOk = await CloudTokenRepository().unlinkParent(
        parentUid: link.parentUserId,
        studentCloudId: link.studentCloudId.isNotEmpty
            ? link.studentCloudId
            : CloudIds.studentId(
                teacherUid: teacher.id,
                localStudentId: student.id ?? 0,
              ),
        classCloudId: link.classCloudId.isNotEmpty
            ? link.classCloudId
            : CloudIds.classId(
                teacherUid: teacher.id,
                localClassId: widget.classModel.id ?? 0,
              ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cloudOk
            ? '${link.parentName} bağlantısı kaldırıldı.'
            : '${link.parentName} cihazda kaldırıldı, buluta ulaşılamadı. '
                'İnternet gelince tekrar deneyin.'),
        backgroundColor: cloudOk ? const Color(0xFF10B981) : Colors.orange,
      ),
    );
  }

  /// Ayrı yaşayan aileler için ikinci bir veli kodu üretir.
  ///
  /// Varsayılan akışta tek kod yeterlidir (anne de baba da aynı kodu
  /// girip ayrı ayrı bağlanabilir). Ancak ayrı yaşayan ailelerde bir
  /// tarafın erişimini diğerini etkilemeden kapatabilmek gerekir; bu
  /// yüzden kod veli etiketiyle üretilir.
  Future<void> _generateSecondParentCode(StudentModel student) async {
    if (student.id == null) return;

    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('İkinci Veli Kodu',
            style: AppFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              '${student.fullName} için ayrı bir kod üretilecek. '
              'Bu kodu iptal etmek diğer velinin erişimini etkilemez.',
              style: AppFonts.outfit(fontSize: 12.5, color: Colors.grey),
            ),
          ),
          for (final option in const ['Anne', 'Baba', 'Vasi'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(option),
              child: Text(option, style: AppFonts.outfit(fontSize: 14)),
            ),
        ],
      ),
    );

    if (label == null || !mounted) return;
    await _renewSingleToken(student, parentLabel: label);
  }

  /// Kodu iptal eder (yerel + bulut).
  Future<void> _confirmRevoke(
      StudentModel student, ParentTokenModel token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kod İptal Edilsin mi?'),
        content: Text(
          '${student.fullName} için üretilen ${token.code} kodu iptal '
          'edilecek. Bu kodu henüz kullanmamış veliler bağlanamaz. '
          'Zaten bağlanmış veliler etkilenmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final teacher = ref.read(teacherProfileProvider);
    final repo = ref.read(parentTokenRepositoryProvider);
    await repo.revokeToken(token.id);

    var cloudOk = true;
    if (CloudIds.isValidUid(teacher.id)) {
      cloudOk = await CloudTokenRepository().revokeToken(token.codeHash);
    }

    if (!mounted) return;
    ref.invalidate(classTokensProvider(widget.classModel));
    ref.invalidate(classActiveTokensProvider(widget.classModel.id ?? 0));
    ref.invalidate(studentActiveTokenProvider(student.id!));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cloudOk
            ? '${token.code} iptal edildi.'
            : '${token.code} cihazda iptal edildi, buluta ulaşılamadı.'),
        backgroundColor: cloudOk ? const Color(0xFF10B981) : Colors.orange,
      ),
    );
  }

  Future<void> _renewSingleToken(StudentModel student, {String parentLabel = ''}) async {
    if (student.id == null) return;
    setState(() => _generatingStudentIds.add(student.id!));

    try {
      final repo = ref.read(parentTokenRepositoryProvider);
      final teacher = ref.read(teacherProfileProvider);
      // Kimlik tek yerden çözülür: kod üretimi ile kadro ekranı farklı
      // kimlik kullanınca sınıfın bulut kimliği de farklı çıkıyor ve
      // veriler iki ayrı sınıf odasına yazılıyordu.
      final resolved = TeacherIdentity.resolve(teacher);
      final teacherUid = resolved.isNotEmpty ? resolved : 'local_teacher';

      final token = await repo.generateTokenForStudent(
        student: student,
        classModel: widget.classModel,
        teacher: teacher.copyWith(id: teacherUid),
        parentLabel: parentLabel,
      );

      // Buluta yayımla ve SONUCU BEKLE.
      //
      // Önceden `unawaited` + `catchError` + boş `catch` üçlüsüyle
      // sessizce yapılıyordu: yayımlama başarısız olsa bile öğretmen
      // "kod üretildi" mesajını görüyordu. Veli o kodla bağlandığında
      // buluttaki kayıt olmadığı için bağ eksik kuruluyor ve veli
      // hiçbir şey göremiyordu — üstelik kimse sebebi bilmiyordu.
      //
      // Süre 3 saniyeden uzun tutuldu: mobil bağlantıda ilk Firestore
      // yazması bundan uzun sürebiliyor.
      var publishedToCloud = false;
      if (CloudIds.isValidUid(teacherUid)) {
        try {
          publishedToCloud = await ref
              .read(parentLinkBridgeProvider)
              .publishTokenToCloud(
                token: token,
                teacherUid: teacherUid,
                teacherName: teacher.fullName,
              )
              .timeout(const Duration(seconds: 12), onTimeout: () => false);
        } catch (e, stackTrace) {
          debugPrint('Token buluta yayımlanamadı: $e\n$stackTrace');
        }
      }

      if (mounted) {
        _safeHaptic();
        ref.invalidate(classTokensProvider(widget.classModel));
        ref.invalidate(classActiveTokensProvider(widget.classModel.id ?? 0));
        ref.invalidate(studentActiveTokenProvider(student.id!));

        if (!publishedToCloud) {
          // Sessiz kalmak yerine sebebi söyle: veli bu kodla bağlansa
          // bile duyuru ve mesajları göremeyecek.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                CloudIds.isValidUid(teacherUid)
                    ? 'Kod üretildi ancak buluta gönderilemedi. '
                        'Veli bu kodla bağlansa bile duyuruları göremez. '
                        'İnternet bağlantınızı kontrol edip kodu yenileyin.'
                    : 'Kod yalnızca bu cihazda üretildi. Veli bağlantısı '
                        'için Google ile giriş yapmanız gerekiyor.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 7),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${StudentNameFormatter.maskLastName(student.fullName)} için yeni kod üretildi: ${token.code} 🚀'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Tekil token yenileme hatası: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.fullName} için kod üretilemedi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingStudentIds.remove(student.id));
      }
    }
  }

  /// Tüm Sınıfın Kodlarını Sıfırdan Yenile (Onaylı)
  Future<void> _renewAllTokensPrompt(List<StudentModel> students) async {
    if (students.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Tüm Kodları Yenile'),
          ],
        ),
        content: const Text(
          'Sınıftaki tüm öğrenciler için yeni referans kodları üretilecektir. Eski kodlar geçersiz kılınacaktır.\n\nDevam etmek istiyor musunuz?',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Evet, Yenile'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBulkRenewing = true);
    try {
      final repo = ref.read(parentTokenRepositoryProvider);
      final teacher = ref.read(teacherProfileProvider);
      // Kimlik tek yerden çözülür: kod üretimi ile kadro ekranı farklı
      // kimlik kullanınca sınıfın bulut kimliği de farklı çıkıyor ve
      // veriler iki ayrı sınıf odasına yazılıyordu.
      final resolved = TeacherIdentity.resolve(teacher);
      final teacherUid = resolved.isNotEmpty ? resolved : 'local_teacher';

      final generatedTokens = await repo.generateTokensForStudentsBatch(
        students: students,
        classModel: widget.classModel,
        teacher: teacher.copyWith(id: teacherUid),
      );

      for (final token in generatedTokens) {
        try {
          unawaited(
            ref
                .read(parentLinkBridgeProvider)
                .publishTokenToCloud(
                  token: token,
                  teacherUid: teacherUid,
                  teacherName: teacher.fullName,
                )
                .timeout(const Duration(seconds: 3), onTimeout: () => false)
                .catchError((e) => false),
          );
        } catch (_) {}
      }

      if (mounted) {
        _safeHaptic();
        ref.invalidate(classTokensProvider(widget.classModel));
        ref.invalidate(classActiveTokensProvider(widget.classModel.id ?? 0));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${generatedTokens.length} öğrencinin referans kodları başarıyla yenilendi! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Toplu token yenileme hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isBulkRenewing = false);
    }
  }

  /// Tüm Sınıf Listesini Panoya Kopyala (KVKK Uyumlu & Güvenli Format)
  void _copyAllClassTokens(
    List<StudentModel> students,
    Map<int, ParentTokenModel> tokens,
  ) {
    if (students.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('📋 *${widget.classModel.name} - Veli Referans Kodları Listesi*');
    buffer.writeln('Sayın Velilerimiz, SınıfCepte Veli Girişi için bağlantı kodlarınız:');
    buffer.writeln('--------------------------------------------------');

    int availableCount = 0;
    for (final student in students) {
      final token = student.id != null ? tokens[student.id] : null;
      if (token != null && token.isValid) {
        final line = StudentNameFormatter.formatPublicRowWithCode(
          fullName: student.fullName,
          code: token.code,
        );
        buffer.writeln(line);
        availableCount++;
      } else {
        final maskedName = StudentNameFormatter.maskLastName(student.fullName);
        buffer.writeln('• $maskedName ➔ (Kod Hazırlanıyor)');
      }
    }

    buffer.writeln('--------------------------------------------------');
    buffer.writeln('📌 *Giriş:* SınıfCepte > Veli Girişi > Kodunuzu & Çocuğunuzun Okul No giriniz.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _safeHaptic();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$availableCount öğrencinin veli kodu panoya kopyalandı! 📋'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Tüm Sınıfı WhatsApp'ta Paylaş
  void _shareAllWhatsApp(
    List<StudentModel> students,
    Map<int, ParentTokenModel> tokens,
  ) {
    if (students.isEmpty) return;
    final teacher = ref.read(teacherProfileProvider);
    TokenShareService.shareClassTokensViaWhatsApp(
      classModel: widget.classModel,
      teacher: teacher,
      students: students,
      tokens: tokens,
    );
  }

  /// Tüm Sınıf A4 PDF Tablosunu Yazdır / Kaydet
  Future<void> _generateClassPdf(
    List<StudentModel> students,
    Map<int, ParentTokenModel> tokens,
  ) async {
    if (students.isEmpty) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final teacher = ref.read(teacherProfileProvider);
      await TokenShareService.printOrSaveClassPdf(
        classModel: widget.classModel,
        teacher: teacher,
        students: students,
        tokens: tokens,
      );
    } catch (e, st) {
      debugPrint('Sınıf PDF tablosu oluşturma hatası: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF oluşturulurken bir hata oluştu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentsAsync = ref.watch(studentListProvider(widget.classModel.id ?? 0));
    final tokensAsync = ref.watch(classTokensProvider(widget.classModel));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.90,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // 1. Üst Tutamaç & Başlık Satırı (Sıfır Taşma Korumalı)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.classModel.name} Veli Referans Kodları',
                              style: AppFonts.outfit(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Veli Giriş & Bilgilendirme Sistemi',
                              style: AppFonts.outfit(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. Üst Hızlı Aksiyonlar & Arama Çubuğu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  studentsAsync.when(
                    data: (students) {
                      final tokens = tokensAsync.valueOrNull ?? {};
                      final validCount = students.where((s) => s.id != null && tokens.containsKey(s.id) && tokens[s.id]!.isValid).length;

                      return Column(
                        children: [
                          // 1. Satır: WhatsApp Paylaş & PDF Çıktısı
                          Row(
                            children: [
                              // 📲 WhatsApp ile Paylaş
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: students.isEmpty ? null : () => _shareAllWhatsApp(students, tokens),
                                  icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                                  label: const Text(
                                    'WhatsApp ile Paylaş',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    elevation: 1,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 📄 Sınıf PDF Tablosu
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isGeneratingPdf || students.isEmpty
                                      ? null
                                      : () => _generateClassPdf(students, tokens),
                                  icon: _isGeneratingPdf
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                                  label: const Text(
                                    'Sınıf PDF Tablosu',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    elevation: 1,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 2. Satır: Tümünü Kopyala & Tüm Kodları Yenile
                          Row(
                            children: [
                              // 📋 Tümünü Kopyala
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: students.isEmpty ? null : () => _copyAllClassTokens(students, tokens),
                                  icon: const Icon(Icons.copy_all_rounded, size: 15),
                                  label: const Text(
                                    'Tümünü Kopyala',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 🔄 Tüm Kodları Yenile
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isBulkRenewing || students.isEmpty
                                      ? null
                                      : () => _renewAllTokensPrompt(students),
                                  icon: _isBulkRenewing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 15, color: Colors.orange),
                                  label: const Text(
                                    'Kodları Yenile',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.orange),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Durum & İstatistik Rozeti
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${students.length} Öğrenci',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (validCount == students.length ? Colors.green : Colors.amber)
                                      .withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$validCount / ${students.length} Kod Hazır',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: validCount == students.length
                                        ? (isDark ? Colors.greenAccent : Colors.green.shade800)
                                        : (isDark ? Colors.amberAccent : Colors.amber.shade900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),

                  // Arama Inputu
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => _searchDebouncer.run(() {
                        if (!mounted) return;
                        // Ham metin saklanir; karsilastirma
                        // `trContains` icinde Turkce'ye duyarsiz yapilir.
                        setState(() => _searchQuery = val.trim());
                      }),
                      decoration: InputDecoration(
                        hintText: 'Öğrenci adı veya okul no ile filtrele...',
                        hintStyle: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.black38),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 3. Tek Kompakt Liste Gövdesi (Okul No - Ad S. - Referans Kodu - Kopyala - WhatsApp - Yenile)
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('Öğrenciler yüklenemedi: $err')),
                data: (students) {
                  if (students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          const Text('Sınıfta kayıtlı öğrenci bulunmuyor.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  // Arama Filtresi
                  final filteredStudents = students.where((s) {
                    if (_searchQuery.isEmpty) return true;
                    final nameMatch = trContains(s.fullName, _searchQuery);
                    final numMatch = s.schoolNumber.toString().contains(_searchQuery);
                    return nameMatch || numMatch;
                  }).toList();

                  final tokens = tokensAsync.valueOrNull ?? {};
                  final teacher = ref.read(teacherProfileProvider);

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredStudents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final token = student.id != null ? tokens[student.id] : null;
                      final isGenerating = student.id != null && _generatingStudentIds.contains(student.id);
                      final maskedName = StudentNameFormatter.maskLastName(student.fullName);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 1. Okul No Rozeti
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${student.schoolNumber}',
                                style: AppFonts.firaCode(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 2. İsim (Soyismin ilk harfi) Örn: Ahmet Y.
                            Expanded(
                              flex: 3,
                              child: Text(
                                maskedName,
                                style: AppFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 3. Referans Kodu Alanı
                            if (token != null && token.isValid) ...[
                              // Kod Alanı (Tıklayınca Kopyalar)
                              Flexible(
                                flex: 4,
                                child: InkWell(
                                  onTap: () {
                                    final textToCopy = StudentNameFormatter.formatRowWithCode(
                                      number: student.schoolNumber,
                                      fullName: student.fullName,
                                      code: token.code,
                                    );
                                    Clipboard.setData(ClipboardData(text: textToCopy));
                                    _safeHaptic();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$maskedName için kod kopyalandı! (${token.code})'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      token.code,
                                      style: AppFonts.firaCode(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 4. Kopyala Butonu
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                                tooltip: 'Kodu Kopyala',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () {
                                  final textToCopy = StudentNameFormatter.formatRowWithCode(
                                    number: student.schoolNumber,
                                    fullName: student.fullName,
                                    code: token.code,
                                  );
                                  Clipboard.setData(ClipboardData(text: textToCopy));
                                  _safeHaptic();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$maskedName: ${token.code} kopyalandı! 📋'),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),

                              // 5. Tekil WhatsApp Gönder Butonu
                              IconButton(
                                icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF16A34A)),
                                tooltip: 'WhatsApp ile Gönder',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () {
                                  TokenShareService.shareViaWhatsApp(
                                    token: token,
                                    student: student,
                                    classModel: widget.classModel,
                                    teacher: teacher,
                                  );
                                },
                              ),

                              // 6. Tekil Kodu Yenile Butonu
                              IconButton(
                                icon: isGenerating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh_rounded, size: 16, color: Colors.blueGrey),
                                tooltip: 'Kodu Yenile',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: isGenerating ? null : () => _renewSingleToken(student),
                              ),

                              // 7. Diğer İşlemler (iptal, bağlı veliler,
                              // ikinci veli kodu). Satırda yer kalmadığı
                              // için menüye alındı.
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    size: 16, color: Colors.blueGrey),
                                tooltip: 'Diğer işlemler',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'parents':
                                      _showLinkedParents(student);
                                    case 'second':
                                      _generateSecondParentCode(student);
                                    case 'revoke':
                                      _confirmRevoke(student, token);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'parents',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.people_alt_rounded,
                                          size: 18),
                                      title: Text('Bağlı veliler'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'second',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.person_add_alt_1_rounded,
                                          size: 18),
                                      title: Text('İkinci veli kodu'),
                                      subtitle: Text(
                                        'Ayrı yaşayan aileler için',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'revoke',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.block_rounded,
                                          size: 18, color: Colors.redAccent),
                                      title: Text('Kodu iptal et',
                                          style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Kod Hazırlanıyor Rozeti
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 1.5),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Hazırlanıyor...',
                                        style: TextStyle(fontSize: 11, color: Colors.amber),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

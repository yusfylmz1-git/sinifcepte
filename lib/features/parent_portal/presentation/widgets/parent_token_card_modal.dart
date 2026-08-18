import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/utils/perf_trace.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/models/parent_link_model.dart';
import '../../data/models/parent_token_model.dart';
import '../../providers/parent_token_provider.dart';
import 'parent_teacher_chat_modal.dart';

/// SınıfCepte - Öğrenci Veli Bağlantı Kartı & QR Modalı
class ParentTokenCardModal extends ConsumerStatefulWidget {
  final StudentModel student;
  final ClassModel classModel;

  const ParentTokenCardModal({
    super.key,
    required this.student,
    required this.classModel,
  });

  static Future<void> show(
    BuildContext context, {
    required StudentModel student,
    required ClassModel classModel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ParentTokenCardModal(
        student: student,
        classModel: classModel,
      ),
    );
  }

  @override
  ConsumerState<ParentTokenCardModal> createState() => _ParentTokenCardModalState();
}

class _ParentTokenCardModalState extends ConsumerState<ParentTokenCardModal> {
  bool _isLoading = false;

  Future<void> _generateNewToken() async {
    // Öğrenci henüz veritabanına yazılmamışsa kimliği yoktur; bu durumda
    // üretilecek kod hiçbir öğrenciye bağlanamaz ve ekranda görünmez.
    if (widget.student.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu öğrenci henüz kaydedilmemiş. Listeyi yenileyip tekrar deneyin.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(parentTokenRepositoryProvider);
      final teacher = ref.read(teacherProfileProvider);
      final activeUid = FirebaseAuth.instance.currentUser?.uid;
      final teacherUid = (activeUid != null && activeUid.isNotEmpty)
          ? activeUid
          : (teacher.id.isNotEmpty ? teacher.id : 'local_teacher');

      final token = await PerfTrace.run(
        'kod üretimi (yerel)',
        () => repo.generateTokenForStudent(
          student: widget.student,
          classModel: widget.classModel,
          teacher: teacher.copyWith(id: teacherUid),
        ),
      );

      // Yerel üretim tamamlandı; UI'ı hemen güncelle ki öğretmen beklemesin
      if (mounted) {
        HapticFeedback.mediumImpact();
        ref.invalidate(studentActiveTokenProvider(widget.student.id ?? 0));
      }

      // Kodu buluta yayımla (zaman aşımı korumalı, arayüzü kilitlemez)
      final publishedToCloud = await PerfTrace.run(
        'kod buluta yayımlama',
        () => ref
            .read(parentLinkBridgeProvider)
            .publishTokenToCloud(
              token: token,
              teacherUid: teacherUid,
              teacherName: teacher.fullName,
            )
            .timeout(const Duration(seconds: 3), onTimeout: () => false),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              publishedToCloud
                  ? 'Veli referans kodu ve QR kod başarıyla oluşturuldu! 🚀'
                  : 'Kod oluşturuldu ancak buluta gönderilemedi. '
                      'İnternet bağlantınızı kontrol ediniz.',
            ),
            backgroundColor: publishedToCloud ? Colors.green : Colors.orange,
            duration: Duration(seconds: publishedToCloud ? 4 : 6),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (kod üretme) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kod oluşturulamadı. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Ayrıntı',
              textColor: Colors.white,
              onPressed: () => _showErrorDetail(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Teknik hata ayrıntısını isteyen kullanıcıya gösterir.
  ///
  /// Normalde kullanıcıya teknik metin gösterilmez (proje kuralı), ancak
  /// destek istendiğinde sebebi görebilmek gerekir. Bu yüzden hata
  /// varsayılan olarak gizli, istendiğinde açılabilir tutulur.
  void _showErrorDetail(String detail) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teknik ayrıntı'),
        content: SingleChildScrollView(
          child: SelectableText(
            detail,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detail));
              Navigator.of(ctx).pop();
            },
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeCurrentToken(String tokenId, String codeHash) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kodu İptal Et'),
        content: const Text('Bu referans kodunu iptal etmek istediğinize emin misiniz? Veli bu kodla artık giriş yapamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(parentTokenRepositoryProvider);
      await repo.revokeToken(tokenId);

      // Buluttan da sil: aksi halde kod yerelde iptal görünürken veli
      // bağlanmaya devam edebilirdi.
      final removedFromCloud =
          await ref.read(parentLinkBridgeProvider).revokeTokenInCloud(codeHash);

      if (mounted) {
        HapticFeedback.lightImpact();
        ref.invalidate(studentActiveTokenProvider(widget.student.id ?? 0));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removedFromCloud
                  ? 'Referans kodu iptal edildi.'
                  : 'Kod cihazınızda iptal edildi ancak sunucuya ulaşılamadı. '
                      'İnternet bağlantısı gelince tekrar iptal edin.',
            ),
            backgroundColor: removedFromCloud ? null : Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Token iptal hatası: $e\n$stackTrace');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Öğretmen tarafından veliyle birebir yazışma ekranını açar.
  ///
  /// Sınıfın sahibi olduğu için kural motoru yazma iznini doğrudan verir;
  /// kadro üyeliği gerekmez.
  void _openChatWithParent(ParentLinkModel link) {
    final teacher = ref.read(teacherProfileProvider);

    ParentTeacherChatModal.show(
      context,
      classCloudId: CloudIds.classId(
        teacherUid: teacher.id,
        localClassId: widget.classModel.id ?? 0,
      ),
      studentCloudId: CloudIds.studentId(
        teacherUid: teacher.id,
        localStudentId: widget.student.id ?? 0,
      ),
      studentName: widget.student.fullName,
      parentUserId: link.parentUserId,
      selfName: teacher.fullName,
      selfUid: teacher.id,
      asTeacher: true,
      counterpartName: '${link.relation}: ${link.parentName}',
    );
  }

  void _shareViaWhatsApp(ParentTokenModel token) {
    final teacher = ref.read(teacherProfileProvider);
    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final expFormatted = DateFormat('dd.MM.yyyy').format(token.expiresAt);

    final message = '''
🏫 *SınıfCepte Veli Bilgilendirme Sistemi*
📍 *${schoolTitle.isNotEmpty ? schoolTitle : 'Okulumuz'}*

Sayın Velimiz,
Öğrencimiz *${widget.student.fullName}* (${widget.classModel.name} / No: ${widget.student.schoolNumber}) için hazırlanan sınıf duyuruları, ders öğretmenleri ve bilgilendirmeleri takip edebilmeniz için bağlantı kodunuz:

🔑 *Giriş Kodu:* `${token.code}`
🔒 *Güvenlik Doğrulaması:* Öğrenci Okul No (*${widget.student.schoolNumber}*)
⏳ *Son Geçerlilik:* $expFormatted (7 Gün)

📲 *Nasıl Giriş Yapılır?*
1. SınıfCepte uygulamasını açın ve "Veli Girişi"ni seçin.
2. Yukarıdaki 8 haneli kodu girin veya QR kodu taratın.
3. Öğrencinin okul numarasını onaylayarak sınıfa bağlanın.
''';

    SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: '${widget.student.fullName} - Veli Giriş Kodu',
      ),
    );
  }

  Future<void> _printOrSavePdf(ParentTokenModel token) async {
    final doc = pw.Document();
    final teacher = ref.read(teacherProfileProvider);
    final schoolTitle = teacher.fullSchoolTitle.isNotEmpty ? teacher.fullSchoolTitle : teacher.schoolName;
    final expFormatted = DateFormat('dd.MM.yyyy').format(token.expiresAt);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('SINIFCEPTE VELİ BİLGİLENDİRME KARTI', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                pw.SizedBox(height: 4),
                pw.Text(schoolTitle, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Öğrenci: ${widget.student.fullName}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Sınıf: ${widget.classModel.name}  |  Okul No: ${widget.student.schoolNumber}', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text('Öğretmen: ${teacher.fullName}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Text(token.code, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: token.code,
                  width: 110,
                  height: 110,
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: PdfColors.amber50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(
                    'Giriş esnasında güvenlik amacıyla öğrencinin okul numarası (${widget.student.schoolNumber}) sorulacaktır. Bu kod $expFormatted tarihine kadar geçerlidir.',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.brown800),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenAsync = ref.watch(studentActiveTokenProvider(widget.student.id ?? 0));
    final linkedParentsAsync = ref.watch(studentLinkedParentsProvider(widget.student.id ?? 0));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst Tutamaç & Başlık
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        // Öğrenci adı uzun olabilir: Expanded olmadan
                        // başlık satırı taşar (AGENTS.md Madde 8).
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Veli Bağlantı Kartı',
                                style: AppFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.student.fullName} (${widget.classModel.name} • No: ${widget.student.schoolNumber})',
                                style: AppFonts.outfit(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
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

          // İçerik Alanı
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: tokenAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                error: (err, st) => Center(child: Text('Hata: $err')),
                data: (token) {
                  if (token == null || !token.isValid) {
                    return _buildNoTokenView(isDark);
                  }
                  return _buildActiveTokenView(token, linkedParentsAsync.valueOrNull ?? [], isDark);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aktif Token Olmadığında Gösterilen Görünüm
  Widget _buildNoTokenView(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield_outlined, size: 48, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'Veli Bağlantı Kodu Oluşturun',
          style: AppFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Öğrencinin velisi (anne/baba), üreteceğiniz 8 haneli referans kodu veya QR kod ile SınıfCepte Veli Modülüne güvenle bağlanabilir.',
          style: AppFonts.outfit(fontSize: 13, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateNewToken,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.vpn_key_rounded, size: 18),
            label: Text('7 Günlük Güvenli Kod & QR Üret 🚀', style: AppFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  /// Aktif Kod & QR Kod Görünümü
  Widget _buildActiveTokenView(ParentTokenModel token, List<ParentLinkModel> linkedParents, bool isDark) {
    final expFormatted = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(token.expiresAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Ana Referans Kodu Kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.12),
                AppColors.secondary.withValues(alpha: isDark ? 0.2 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Text(
                'VELİ REFERANS KODU',
                style: AppFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    token.code,
                    style: AppFonts.firaCode(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'Kodu Kopyala',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: token.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Referans kodu panoya kopyalandı! 📋'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. QR Kod Görseli
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: token.code,
            version: QrVersions.auto,
            size: 150.0,
            gapless: false,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Güvenlik & Süre Rozetleri
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            Tooltip(
              message: 'Son Geçerlilik: $expFormatted',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      '${token.remainingDays} gün geçerli',
                      style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_outlined, size: 13, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Bağlı Veli: ${token.linkedParentCount} / ${token.maxLinkedParents}',
                    style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // İkinci Faktör Bilgilendirme Notu
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_person_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Veli girişinde 2. faktör olarak Öğrenci Okul No (${widget.student.schoolNumber}) doğrulanacaktır.',
                  style: AppFonts.outfit(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Bağlı Veliler Listesi
        if (linkedParents.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BAĞLI VELİLER (${linkedParents.length})',
                      style: AppFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                  ],
                ),
                const SizedBox(height: 8),
                ...linkedParents.map((lp) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(lp.relation == 'Anne' ? Icons.face_3_rounded : Icons.face_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${lp.relation}: ${lp.parentName}',
                          style: AppFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('dd.MM').format(lp.linkedAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      // Öğretmen veliyle birebir yazışabilir. Telefon
                      // numarası paylaşılmaz; iletişim uygulama içinde kalır.
                      IconButton(
                        onPressed: () => _openChatWithParent(lp),
                        icon: const Icon(Icons.forum_rounded, size: 18),
                        color: AppColors.primary,
                        tooltip: 'Mesaj Gönder',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 5. Eylem Düğmeleri (WhatsApp, Yazdır / PDF, Yenile)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () => _shareViaWhatsApp(token),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('WhatsApp ile Paylaş'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: () => _printOrSavePdf(token),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Yazdır'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Kodu Yenile / İptal Et Butonları
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _isLoading ? null : () => _generateNewToken(),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Kodu Yenile', style: TextStyle(fontSize: 11.5)),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _revokeCurrentToken(token.id, token.codeHash),
              icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
              label: const Text('Kodu İptal Et', style: TextStyle(fontSize: 11.5, color: Colors.red)),
            ),
          ],
        ),
      ],
    );
  }
}

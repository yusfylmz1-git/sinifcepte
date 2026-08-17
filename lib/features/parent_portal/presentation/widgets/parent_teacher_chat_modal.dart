import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/cloud_communication_repository.dart';
import '../../providers/cloud_communication_provider.dart';

/// Öğretmen ↔ veli birebir yazışma ekranı.
///
/// Aynı bileşen iki taraftan da açılır; farkı [asTeacher] belirler:
/// gönderilen mesajın `authorRole` alanı buna göre yazılır ve kural motoru
/// bunu doğrular (veli 'teacher' rolüyle mesaj gönderemez).
///
/// ## Yetki
/// - **Veli**: yalnızca kendi çocuğu hakkında yazışabilir
///   (`parentHasStudent` kuralı).
/// - **Öğretmen**: sınıfın sahibi ya da kadroda kayıtlı branş öğretmeni
///   olmalıdır (`isClassStaff`). Kadroya katılmamış öğretmen mesaj gönderemez.
///
/// ## Maliyet
/// Canlı dinleyici kullanılmaz (maliyet kararı #4). Mesajlar açılışta bir kez
/// çekilir, aşağı çekilerek yenilenir. Gönderim sonrası liste yerel olarak
/// güncellenir; sunucudan yeniden okuma yapılmaz.
class ParentTeacherChatModal extends ConsumerStatefulWidget {
  final String classCloudId;
  final String studentCloudId;
  final String studentName;

  /// Sohbetin ait olduğu velinin UID'si.
  ///
  /// Veli tarafında kendi UID'si; öğretmen tarafında yazıştığı velinin.
  final String parentUserId;

  /// Ekranı açan kişinin adı (mesaj imzası).
  final String selfName;

  /// Ekranı açan kişinin Firebase UID'si.
  final String selfUid;

  /// true → öğretmen görünümü, false → veli görünümü.
  final bool asTeacher;

  /// Karşı tarafın adı (başlıkta gösterilir).
  final String counterpartName;

  const ParentTeacherChatModal({
    super.key,
    required this.classCloudId,
    required this.studentCloudId,
    required this.studentName,
    required this.parentUserId,
    required this.selfName,
    required this.selfUid,
    required this.asTeacher,
    required this.counterpartName,
  });

  static Future<void> show(
    BuildContext context, {
    required String classCloudId,
    required String studentCloudId,
    required String studentName,
    required String parentUserId,
    required String selfName,
    required String selfUid,
    required bool asTeacher,
    required String counterpartName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParentTeacherChatModal(
        classCloudId: classCloudId,
        studentCloudId: studentCloudId,
        studentName: studentName,
        parentUserId: parentUserId,
        selfName: selfName,
        selfUid: selfUid,
        asTeacher: asTeacher,
        counterpartName: counterpartName,
      ),
    );
  }

  @override
  ConsumerState<ParentTeacherChatModal> createState() =>
      _ParentTeacherChatModalState();
}

class _ParentTeacherChatModalState
    extends ConsumerState<ParentTeacherChatModal> {
  final _bodyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<CloudMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Mesajları tek seferlik okur.
  ///
  /// Delta uygulanmaz: sohbet açıldığında geçmişin tamamı (son 50) görünmeli.
  /// Sohbet nadiren açıldığı için bu, listener'a kıyasla çok daha ucuzdur.
  Future<void> _loadMessages() async {
    try {
      final list = await ref.read(cloudCommunicationRepositoryProvider).fetchMessages(
            classCloudId: widget.classCloudId,
            studentCloudId: widget.studentCloudId,
          );
      if (!mounted) return;

      setState(() {
        // Depo en yeniden eskiye döner; sohbet eskiden yeniye okunur.
        _messages = list.reversed.toList();
        _loading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('Mesajlar yüklenemedi: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Mesajlar yüklenemedi. İnternet bağlantınızı kontrol edin.';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);

    final messageId =
        'msg_${widget.selfUid}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final ok = await ref.read(cloudCommunicationRepositoryProvider).sendMessage(
            classCloudId: widget.classCloudId,
            messageId: messageId,
            studentCloudId: widget.studentCloudId,
            parentUserId: widget.parentUserId,
            // Kural motoru bu alanı doğrular: veli 'teacher' yazamaz.
            authorRole: widget.asTeacher ? 'teacher' : 'parent',
            authorName: widget.selfName,
            authorUid: widget.selfUid,
            body: body,
          );

      if (!mounted) return;

      if (!ok) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mesaj gönderilemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      HapticFeedback.selectionClick();
      _bodyCtrl.clear();

      // Sunucudan yeniden okumak yerine listeyi yerel olarak büyüt:
      // gönderdiğimiz mesajın içeriğini zaten biliyoruz (maliyet kararı).
      setState(() {
        _messages = [
          ..._messages,
          CloudMessage(
            id: messageId,
            studentCloudId: widget.studentCloudId,
            parentUserId: widget.parentUserId,
            authorRole: widget.asTeacher ? 'teacher' : 'parent',
            authorName: widget.selfName,
            authorUid: widget.selfUid,
            body: body,
            createdAt: DateTime.now(),
          ),
        ];
        _sending = false;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('Mesaj gönderme hatası: $e\n$stackTrace');
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj gönderilirken bir sorun oluştu.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(isDark),
            const Divider(height: 1),
            Expanded(child: _buildBody(isDark)),
            _buildComposer(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.asTeacher
                  ? Icons.family_restroom_rounded
                  : Icons.co_present_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.counterpartName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.studentName} hakkında',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadMessages,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 42, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Henüz mesaj yok',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.asTeacher
                    ? 'Veliye ilk mesajı siz gönderebilirsiniz.'
                    : 'Öğretmene ${widget.studentName} hakkında ilk mesajı gönderebilirsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, idx) => _buildBubble(_messages[idx], isDark),
    );
  }

  Widget _buildBubble(CloudMessage m, bool isDark) {
    // "Benim mesajım mı?" — rol karşılaştırması yeterli: sohbet birebirdir.
    final isMine = widget.asTeacher ? m.isFromTeacher : !m.isFromTeacher;
    final timeStr = DateFormat('dd.MM HH:mm').format(m.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.primary
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine && m.authorName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  m.authorName,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            Text(
              m.body,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.35,
                color: isMine
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeStr,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                color: isMine ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF1F5F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.outfit(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

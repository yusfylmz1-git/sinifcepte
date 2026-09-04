import '../../features/parent_portal/data/services/communication_ids.dart';

/// Destek talebi kategorileri.
enum SupportCategory {
  codeIssue('code_issue', '🔑 Veli Referans Kodu Sorunu'),
  bugReport('bug_report', '🐛 Uygulama Hatası Bildir'),
  suggestion('suggestion', '💡 Öneri & İyileştirme'),
  other('other', '❓ Diğer Sorular');

  const SupportCategory(this.id, this.label);

  final String id;
  final String label;

  static SupportCategory fromId(String id) {
    return SupportCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => SupportCategory.other,
    );
  }
}

/// Bir destek talebi.
///
/// ## Neden bu sınıf var
/// `HelpSupportModal` "Destek Talebini Gönder" diyor ve ardından
/// "24 saat içinde yanıtlanır" vaat ediyordu. Gerçekte talep yalnızca
/// **cihazdaki yerel denetim günlüğüne** yazılıyordu — kimse görmüyordu.
/// Kullanıcı gönderdiğini sanıyor, karşılığında hiçbir şey olmuyordu.
///
/// ## Sınırlar neden var
/// Talep buluta yazılıyor; sınırsız metin hem Firestore doküman sınırını
/// (1 MiB) zorlar hem de kötü niyetli bir kullanıcının kotayı doldurmasına
/// izin verir.
class SupportRequest {
  /// Başlık üst sınırı.
  static const int maxSubjectLength = 120;

  /// Açıklama üst sınırı.
  static const int maxMessageLength = 2000;

  final String id;
  final String userId;
  final String userRole;
  final SupportCategory category;
  final String subject;
  final String message;
  final DateTime createdAt;

  /// Cihaz ve sürüm bilgisi. Hatayı tekrar üretmek için gerekli:
  /// "uygulama kapanıyor" diyen öğretmenin Android sürümü bilinmezse
  /// sorunu aramak kör bir iş olur.
  final String? appVersion;
  final String? platform;

  const SupportRequest({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.category,
    required this.subject,
    required this.message,
    required this.createdAt,
    this.appVersion,
    this.platform,
  });

  /// Kullanıcı girdisinden bir talep üretir; alanları kırpar.
  factory SupportRequest.create({
    required String userId,
    required String userRole,
    required SupportCategory category,
    required String subject,
    required String message,
    String? appVersion,
    String? platform,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    return SupportRequest(
      // Çakışmasız kimlik: aynı anda iki kullanıcı gönderirse
      // birbirlerinin talebini ezmemeli. Aynı üretici mesaj ve duyuru
      // kimliklerinde de kullanılıyor.
      id: CommunicationIds.supportRequest(authorUid: userId, now: ts),
      userId: userId,
      userRole: userRole,
      category: category,
      subject: _clamp(subject.trim(), maxSubjectLength),
      message: _clamp(message.trim(), maxMessageLength),
      createdAt: ts,
      appVersion: appVersion,
      platform: platform,
    );
  }

  static String _clamp(String raw, int max) {
    if (raw.length <= max) return raw;
    return raw.substring(0, max);
  }

  /// Başlık ve açıklama dolu mu?
  bool get isValid => subject.isNotEmpty && message.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userRole': userRole,
      'category': category.id,
      'subject': subject,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
      if (platform != null) 'platform': platform,
      // Yönetici panelinde "yanıtlandı mı" takibi için.
      'status': 'open',
    };
  }

  factory SupportRequest.fromMap(String id, Map<String, dynamic> map) {
    return SupportRequest(
      id: id,
      userId: map['userId'] as String? ?? '',
      userRole: map['userRole'] as String? ?? 'unknown',
      category: SupportCategory.fromId(map['category'] as String? ?? 'other'),
      subject: map['subject'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      appVersion: map['appVersion'] as String?,
      platform: map['platform'] as String?,
    );
  }
}

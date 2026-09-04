import '../models/app_notification.dart';
import '../repositories/cloud_communication_repository.dart';

/// Bildirim listesini mevcut verilerden üretir.
///
/// ## Maliyet
/// Hiçbir yeni Firestore isteği yapmaz. Duyurular, mesajlar ve randevular
/// ekranlar için zaten çekiliyor; bu sınıf yalnızca onları bildirime
/// dönüştürür. Gerçek push (FCM) Cloud Functions ve Blaze planı
/// gerektirdiği için seçilmedi.
///
/// Sınırı açık olsun: telefon kapalıyken bildirim gelmez.
class NotificationBuilder {
  const NotificationBuilder._();

  /// Velinin bildirim listesi.
  static List<AppNotification> forParent({
    required List<CloudAnnouncement> announcements,
    required List<CloudMessage> messages,
    required List<CloudAppointment> appointments,
    required DateTime? lastSeenMessages,
  }) {
    final out = <AppNotification>[];

    for (final a in announcements) {
      out.add(AppNotification(
        id: 'ann_${a.id}',
        // Sınav duyurusu ayrı ikon ve renkle görünür.
        kind: a.isExam ? NotificationKind.exam : NotificationKind.announcement,
        title: a.title,
        body: a.content,
        createdAt: a.createdAt,
        isRead: a.readByMe,
        targetId: a.id,
      ));
    }

    for (final m in messages) {
      // Velinin kendi gönderdiği mesaj bildirim üretmez; aksi hâlde her
      // gönderimde kendine bildirim gelirdi.
      if (!m.isFromTeacher) continue;
      out.add(_fromMessage(m, lastSeenMessages));
    }

    for (final ap in appointments) {
      // Talebi veli gönderdi; haber alması gereken şey KARARDIR.
      if (ap.status == 'pending') continue;
      out.add(AppNotification(
        id: 'apt_${ap.id}',
        kind: NotificationKind.appointment,
        title: 'Randevu ${_statusLabel(ap.status)}',
        body: '${ap.teacherName} · ${ap.timeSlot}',
        createdAt: ap.createdAt,
        targetId: ap.id,
      ));
    }

    return AppNotification.sorted(out);
  }

  /// Öğretmenin bildirim listesi.
  static List<AppNotification> forTeacher({
    required List<CloudMessage> messages,
    required List<CloudStatusReport> reports,
    required List<CloudAppointment> appointments,
    required DateTime? lastSeenMessages,
  }) {
    final out = <AppNotification>[];

    for (final m in messages) {
      // Öğretmenin kendi mesajı bildirim üretmez.
      if (m.isFromTeacher) continue;
      out.add(_fromMessage(m, lastSeenMessages));
    }

    for (final r in reports) {
      out.add(AppNotification(
        id: 'rep_${r.id}',
        kind: NotificationKind.statusReport,
        title: r.title,
        body: '${r.studentName} · ${r.parentName}',
        createdAt: r.createdAt,
        // Öğretmen onayladıysa iş bitmiştir.
        isRead: r.status == 'acknowledged',
        targetId: r.id,
      ));
    }

    for (final ap in appointments) {
      // Öğretmenin haber alması gereken şey BEKLEYEN taleptir.
      if (ap.status != 'pending') continue;
      out.add(AppNotification(
        id: 'apt_${ap.id}',
        kind: NotificationKind.appointment,
        title: 'Randevu talebi',
        body: '${ap.studentName} · ${ap.parentName} (${ap.timeSlot})',
        createdAt: ap.createdAt,
        targetId: ap.id,
      ));
    }

    return AppNotification.sorted(out);
  }

  static AppNotification _fromMessage(
    CloudMessage m,
    DateTime? lastSeen,
  ) {
    // Okundu bilgisi cihazda tutulan "son görüntüleme" damgasından
    // çıkarılır: mesaj başına okundu dokümanı tutmak her sohbet için
    // ayrı bir Firestore okuması demekti.
    final read = lastSeen != null && !m.createdAt.isAfter(lastSeen);

    return AppNotification(
      id: 'msg_${m.id}',
      kind: NotificationKind.message,
      title: m.authorName.isEmpty ? 'Yeni mesaj' : m.authorName,
      body: m.body,
      createdAt: m.createdAt,
      isRead: read,
      targetId: m.teacherUid,
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'onaylandı';
      case 'rejected':
        return 'reddedildi';
      case 'cancelled':
        return 'iptal edildi';
      case 'completed':
        return 'tamamlandı';
      default:
        return 'güncellendi';
    }
  }
}

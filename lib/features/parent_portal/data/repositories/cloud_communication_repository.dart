import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/cloud/firestore_client.dart';

/// Bulut duyurusu.
///
/// Görsel yardımcıları (`priorityIcon`, `priorityColor`) yerel
/// `ClassAnnouncementModel` ile aynı sözleşmeyi izler; böylece arayüz
/// kodu iki model arasında geçişte değişmek zorunda kalmaz.
class CloudAnnouncement {
  final String id;
  final String title;
  final String content;
  final String priority; // 'normal' | 'urgent' | 'event'
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int readCount;

  /// Bu velinin duyuruyu okuyup okumadığı.
  ///
  /// Okundu bilgisi artık duyuru dokümanında değil, ayrı bir alt
  /// koleksiyonda tutulur (maliyet kararı #1); bu alan o kayıttan
  /// doldurulur.
  final bool readByMe;

  const CloudAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    this.priority = 'normal',
    this.authorName = '',
    required this.createdAt,
    required this.updatedAt,
    this.readCount = 0,
    this.readByMe = false,
  });

  bool get isUrgent => priority == 'urgent';
  bool get isEvent => priority == 'event';

  CloudAnnouncement copyWith({bool? readByMe, int? readCount}) {
    return CloudAnnouncement(
      id: id,
      title: title,
      content: content,
      priority: priority,
      authorName: authorName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      readCount: readCount ?? this.readCount,
      readByMe: readByMe ?? this.readByMe,
    );
  }

  IconData get priorityIcon {
    switch (priority) {
      case 'urgent':
        return Icons.notification_important_rounded;
      case 'event':
        return Icons.event_available_rounded;
      case 'normal':
      default:
        return Icons.campaign_rounded;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'event':
        return const Color(0xFF8B5CF6);
      case 'normal':
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

/// Bulut mesajı.
class CloudMessage {
  final String id;
  final String studentCloudId;
  final String parentUserId;
  final String authorRole; // 'teacher' | 'parent'
  final String authorName;
  final String authorUid;
  final String body;
  final DateTime createdAt;

  const CloudMessage({
    required this.id,
    required this.studentCloudId,
    required this.parentUserId,
    required this.authorRole,
    required this.authorName,
    this.authorUid = '',
    required this.body,
    required this.createdAt,
  });

  bool get isFromTeacher => authorRole == 'teacher';
}

/// Veli durum bildirimi (ilaç, erken çıkış, özel not).
///
/// Veli oluşturur, öğretmen görür ve onaylar. Öğrencinin sağlık/durum
/// bilgisi taşıdığı için yalnızca ilgili sınıfın öğretmenleri ve bildirimi
/// gönderen veli erişebilir — kural motoru bunu zorunlu kılar.
class CloudStatusReport {
  final String id;
  final String studentCloudId;
  final String studentName;
  final String parentUserId;
  final String parentName;
  final String relation;

  /// 'medication' | 'early_leave' | 'note'
  final String type;
  final String title;
  final String details;
  final String? timeInfo;
  final DateTime createdAt;

  /// 'pending' | 'acknowledged' | 'completed'
  final String status;
  final DateTime? acknowledgedAt;
  final String? teacherNote;

  const CloudStatusReport({
    required this.id,
    required this.studentCloudId,
    required this.studentName,
    required this.parentUserId,
    required this.parentName,
    this.relation = 'Anne',
    required this.type,
    required this.title,
    required this.details,
    this.timeInfo,
    required this.createdAt,
    this.status = 'pending',
    this.acknowledgedAt,
    this.teacherNote,
  });

  bool get isAcknowledged => status == 'acknowledged' || status == 'completed';
  bool get isMedication => type == 'medication';
  bool get isEarlyLeave => type == 'early_leave';

  IconData get typeIcon {
    switch (type) {
      case 'medication':
        return Icons.medication_rounded;
      case 'early_leave':
        return Icons.directions_walk_rounded;
      case 'note':
      default:
        return Icons.sticky_note_2_rounded;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'medication':
        return const Color(0xFFEF4444);
      case 'early_leave':
        return const Color(0xFFF59E0B);
      case 'note':
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

/// Veli–öğretmen görüşme randevusu.
class CloudAppointment {
  final String id;
  final String studentCloudId;
  final String studentName;
  final String parentUserId;
  final String parentName;
  final String relation;
  final String teacherName;
  final String branch;
  final DateTime appointmentDate;
  final String timeSlot;
  final String topic;

  /// 'pending' | 'confirmed' | 'rejected' | 'completed' | 'cancelled'
  final String status;
  final DateTime createdAt;
  final String? responseNote;

  const CloudAppointment({
    required this.id,
    required this.studentCloudId,
    required this.studentName,
    required this.parentUserId,
    required this.parentName,
    this.relation = 'Anne',
    required this.teacherName,
    this.branch = '',
    required this.appointmentDate,
    required this.timeSlot,
    required this.topic,
    this.status = 'pending',
    required this.createdAt,
    this.responseNote,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';

  Color get statusColor {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return const Color(0xFF6366F1);
      case 'pending':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  /// Kullanıcıya gösterilecek Türkçe durum metni.
  ///
  /// Ad, yerel `ParentAppointmentModel` ile aynı tutulur: arayüz kodu iki
  /// model arasında geçerken değişmek zorunda kalmasın.
  String get statusTitleTr {
    switch (status) {
      case 'confirmed':
        return 'Onaylandı';
      case 'rejected':
        return 'Reddedildi';
      case 'cancelled':
        return 'İptal edildi';
      case 'completed':
        return 'Tamamlandı';
      case 'pending':
      default:
        return 'Onay bekliyor';
    }
  }
}

/// Sınıfın ders öğretmeni kadrosundan bir üye.
///
/// Mesajlaşma yetkisi **Firebase UID**'ye bağlıdır, isme değil. Sınıf
/// öğretmeni branş öğretmeninin UID'sini bilemeyeceği için kayıt iki
/// aşamada tamamlanır:
///
/// 1. **Beklemede** ([isPending]): satır yalnızca ad/branş içerir,
///    doküman kimliği geçici `pending_{kod}` biçimindedir. Veli öğretmeni
///    listede görür ama mesajlaşma açılmaz.
/// 2. **Etkin**: branş öğretmeni [joinCode] ile katılır, kayıt kendi
///    UID'siyle yeniden yazılır ve mesajlaşma açılır.
class CloudStaffMember {
  /// Etkin üyelerde Firebase UID; beklemede olanlarda `pending_{kod}`.
  final String teacherUid;
  final String teacherName;
  final String branch;
  final bool isHomeroom;
  final String meetingDay;
  final String meetingTime;

  /// Branş öğretmeninin kadroya katılmak için gireceği kod.
  final String joinCode;

  const CloudStaffMember({
    required this.teacherUid,
    required this.teacherName,
    required this.branch,
    this.isHomeroom = false,
    this.meetingDay = '',
    this.meetingTime = '',
    this.joinCode = '',
  });

  /// Öğretmen henüz katılım kodunu girmedi; mesajlaşma kapalı.
  static const String pendingPrefix = 'pending_';

  bool get isPending => teacherUid.startsWith(pendingPrefix);

  /// Veliye gösterilecek etiket: "Selin Demir — Fizik"
  String get displayTitle =>
      branch.isEmpty ? teacherName : '$teacherName — $branch';
}

/// Faz 3 — iletişim katmanının bulut erişimi.
///
/// ## Maliyet mimarisi
/// Bu sınıf, planın en pahalı üç kalemini adresler:
///
/// **#2 Delta sorgu.** Veli her açılışta tüm duyuruları indirmez; yalnızca
/// son senkrondan sonra değişenleri çeker. Sınıfta günde ortalama 0,2
/// duyuru yayımlandığı için açılışların büyük çoğunluğu **sıfır doküman**
/// okur — boş sorgu neredeyse bedavadır.
///
/// **#1 Okundu bilgisi alt dokümanda.** Duyuru dokümanındaki `readBy[]`
/// dizisi yerine `announcements/{id}/reads/{parentUid}`. Eski tasarımda 30
/// veli aynı dokümanı okuyup diziye kendini ekleyip geri yazıyordu; artık
/// her veli yalnızca kendi küçük dokümanını yazar ve çakışma olmaz.
/// Öğretmen sayıyı [countReads] ile toplama sorgusundan alır — bu, doküman
/// başına değil sorgu başına ücretlendirilir.
///
/// **#4 Dinleyici yok.** Tüm okumalar tek seferliktir; anlık bildirim
/// gerekiyorsa FCM push kullanılır.
class CloudCommunicationRepository {
  CloudCommunicationRepository({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _classRooms = 'class_rooms';

  /// Duyuruları getirir.
  ///
  /// [since] verilirse yalnızca o andan sonra güncellenenler çekilir
  /// (maliyet kararı #2). [limit] son N duyuruyla sınırlar — veli arayüzü
  /// geçmişin tamamını göstermez.
  Future<List<CloudAnnouncement>> fetchAnnouncements({
    required String classCloudId,
    required String parentUid,
    DateTime? since,
    int limit = 20,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      Query<Map<String, dynamic>> query = db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('announcements');

      if (since != null) {
        query = query.where(
          'updatedAt',
          isGreaterThan: since.toIso8601String(),
        );
      }

      final snap =
          await query.orderBy('updatedAt', descending: true).limit(limit).get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return CloudAnnouncement(
          id: d.id,
          title: data['title'] as String? ?? '',
          content: data['content'] as String? ?? '',
          priority: data['priority'] as String? ?? 'normal',
          authorName: data['authorName'] as String? ?? '',
          createdAt:
              DateTime.tryParse(data['createdAt'] as String? ?? '') ??
                  DateTime.now(),
          updatedAt:
              DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
                  DateTime.now(),
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchAnnouncements hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Sınıf odasının bulutta var olduğundan emin olur.
  ///
  /// Duyuru ve mesajlar sınıf odasının alt koleksiyonlarıdır; ayrıca veli
  /// erişim kuralları bu dokümanın varlığına dayanır. Kod üretimi sırasında
  /// zaten yazılır, ancak öğretmen kod üretmeden duyuru yayımlayabileceği
  /// için burada da güvenceye alınır.
  ///
  /// Yalnızca sınıfın kimliği, adı ve öğretmeni yazılır — öğrenci listesi
  /// buluta çıkmaz.
  Future<bool> ensureClassRoom({
    required String classCloudId,
    required String className,
    required String teacherUid,
    required String teacherName,
    String schoolId = '',
    String schoolName = '',
  }) {
    return _client.setDoc('$_classRooms/$classCloudId', {
      'classCloudId': classCloudId,
      'className': className,
      'teacherUid': teacherUid,
      'teacherName': teacherName,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Öğretmen duyuru yayımlar.
  ///
  /// `updatedAt` alanı delta sorgunun dayanağıdır; her yazımda tazelenir.
  Future<bool> publishAnnouncement({
    required String classCloudId,
    required String announcementId,
    required String title,
    required String content,
    required String authorName,
    required String authorUid,
    String priority = 'normal',
  }) async {
    final now = DateTime.now().toIso8601String();
    return _client.setDoc(
      '$_classRooms/$classCloudId/announcements/$announcementId',
      {
        'title': title,
        'content': content,
        'priority': priority,
        'authorName': authorName,
        'authorUid': authorUid,
        'createdAt': now,
        'updatedAt': now,
      },
    );
  }

  /// Öğretmen duyuruyu siler.
  ///
  /// Okundu alt koleksiyonu Firestore'da otomatik silinmez, ancak duyuru
  /// dokümanı olmadan erişilemez ve sorgulara girmez. Boyutu küçük olduğu
  /// için ayrıca temizlenmesi maliyeti hak etmiyor.
  Future<bool> deleteAnnouncement({
    required String classCloudId,
    required String announcementId,
  }) {
    return _client
        .deleteDoc('$_classRooms/$classCloudId/announcements/$announcementId');
  }

  /// Veli duyuruyu okuduğunu işaretler (maliyet kararı #1).
  ///
  /// Yalnızca kendi küçük dokümanını yazar; duyuru dokümanına dokunmaz.
  Future<bool> markAnnouncementRead({
    required String classCloudId,
    required String announcementId,
    required String parentUid,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/announcements/$announcementId/reads/$parentUid',
      {'readAt': DateTime.now().toIso8601String()},
    );
  }

  /// Bu velinin duyuruyu okuyup okumadığı (tek doküman okuması).
  Future<bool> hasRead({
    required String classCloudId,
    required String announcementId,
    required String parentUid,
  }) async {
    final data = await _client.getDoc(
      '$_classRooms/$classCloudId/announcements/$announcementId/reads/$parentUid',
    );
    return data != null;
  }

  /// Duyuruyu kaç velinin okuduğu.
  ///
  /// `count()` toplama sorgusu kullanır: 1000 dokümana kadar tek okuma
  /// olarak ücretlendirilir. Dokümanları tek tek çekmekten çok daha ucuzdur.
  Future<int> countReads({
    required String classCloudId,
    required String announcementId,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return 0;

    try {
      final agg = await db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('announcements')
          .doc(announcementId)
          .collection('reads')
          .count()
          .get();
      // Toplama sorgusu 1000 dokümana kadar tek okuma ücretlendirilir.
      await _client.recordQueryReads(1);
      return agg.count ?? 0;
    } catch (e, stackTrace) {
      debugPrint('countReads hatası: $e\n$stackTrace');
      return 0;
    }
  }

  /// Mesajları getirir (delta destekli).
  ///
  /// Veli yalnızca kendi çocuğuna ait mesajları görür; kural motoru bunu
  /// `parentHasStudent` ile zorunlu kılar, sorgu da aynı filtreyi uygular.
  Future<List<CloudMessage>> fetchMessages({
    required String classCloudId,
    required String studentCloudId,
    DateTime? since,
    int limit = 50,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      Query<Map<String, dynamic>> query = db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('messages')
          .where('studentCloudId', isEqualTo: studentCloudId);

      if (since != null) {
        query = query.where('createdAt', isGreaterThan: since.toIso8601String());
      }

      final snap =
          await query.orderBy('createdAt', descending: true).limit(limit).get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return CloudMessage(
          id: d.id,
          studentCloudId: data['studentCloudId'] as String? ?? '',
          parentUserId: data['parentUserId'] as String? ?? '',
          authorRole: data['authorRole'] as String? ?? 'teacher',
          authorName: data['authorName'] as String? ?? '',
          authorUid: data['authorUid'] as String? ?? '',
          body: data['body'] as String? ?? '',
          createdAt:
              DateTime.tryParse(data['createdAt'] as String? ?? '') ??
                  DateTime.now(),
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchMessages hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Mesaj gönderir.
  ///
  /// [authorRole] kural motorunda doğrulanır: veli 'teacher' rolüyle mesaj
  /// gönderemez (kimlik taklidi koruması).
  Future<bool> sendMessage({
    required String classCloudId,
    required String messageId,
    required String studentCloudId,
    required String parentUserId,
    required String authorRole,
    required String authorName,
    required String authorUid,
    required String body,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/messages/$messageId',
      {
        'studentCloudId': studentCloudId,
        'parentUserId': parentUserId,
        'authorRole': authorRole,
        'authorName': authorName,
        'authorUid': authorUid,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
      },
      merge: false, // mesajlar değiştirilemez
    );
  }

  /// Sınıfın ders öğretmeni kadrosunu getirir.
  ///
  /// Velinin "çocuğumun dersine kimler giriyor" listesi buradan gelir.
  Future<List<CloudStaffMember>> fetchStaff(String classCloudId) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('staff')
          .get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return CloudStaffMember(
          teacherUid: d.id,
          teacherName: data['teacherName'] as String? ?? '',
          branch: data['branch'] as String? ?? '',
          isHomeroom: data['isHomeroom'] as bool? ?? false,
          meetingDay: data['meetingDay'] as String? ?? '',
          meetingTime: data['meetingTime'] as String? ?? '',
          joinCode: data['joinCode'] as String? ?? '',
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchStaff hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Sınıf öğretmeni kadroya branş öğretmeni ekler/günceller.
  ///
  /// Kadro üyeliği mesajlaşma yetkisini belirler: yalnızca burada kayıtlı
  /// öğretmenler velilerle yazışabilir.
  Future<bool> upsertStaff({
    required String classCloudId,
    required CloudStaffMember member,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/staff/${member.teacherUid}',
      {
        'teacherUid': member.teacherUid,
        'teacherName': member.teacherName,
        'branch': member.branch,
        'isHomeroom': member.isHomeroom,
        'meetingDay': member.meetingDay,
        'meetingTime': member.meetingTime,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Kadrodan öğretmen çıkarır (mesajlaşma yetkisi de kalkar).
  Future<bool> removeStaff({
    required String classCloudId,
    required String teacherUid,
  }) {
    return _client.deleteDoc('$_classRooms/$classCloudId/staff/$teacherUid');
  }

  /// Aynı okuldaki bir öğretmeni doğrudan kadroya ekler.
  ///
  /// Tercih edilen yol budur: öğretmen okulunu zaten seçmiş olduğu için
  /// UID'si `school_teachers` dizininde bulunur. Kod alışverişine,
  /// beklemeye ve karşı tarafın işlem yapmasına gerek kalmaz —
  /// eklendiği anda mesajlaşma açılır.
  ///
  /// [addPendingStaff] yalnızca dizinde bulunmayan öğretmenler için
  /// (henüz uygulamayı açmamış veya farklı okul seçmiş) yedek yoldur.
  Future<bool> addStaffDirectly({
    required String classCloudId,
    required String teacherUid,
    required String teacherName,
    required String branch,
    String meetingDay = '',
    String meetingTime = '',
    bool isHomeroom = false,
  }) {
    return _client.setDoc('$_classRooms/$classCloudId/staff/$teacherUid', {
      'teacherUid': teacherUid,
      'teacherName': teacherName,
      'branch': branch,
      'isHomeroom': isHomeroom,
      'meetingDay': meetingDay,
      'meetingTime': meetingTime,
      'addedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Sınıf öğretmeni kadroya "beklemede" bir satır ekler.
  ///
  /// Branş öğretmeninin UID'si henüz bilinmediği için doküman kimliği
  /// geçici olarak `pending_{kod}` olur. Öğretmen [joinStaffByCode] ile
  /// katıldığında kayıt kendi UID'siyle yeniden yazılır ve bu satır silinir.
  ///
  /// Bu aşamada veli öğretmeni listede görür (kimin dersine girdiğini bilir)
  /// ama mesajlaşma açılmaz — kural motoru `pending_` kimliğine yetki vermez.
  Future<bool> addPendingStaff({
    required String classCloudId,
    required String teacherName,
    required String branch,
    String meetingDay = '',
    String meetingTime = '',
    bool isHomeroom = false,
  }) async {
    final code = _generateJoinCode();
    final pendingId = '${CloudStaffMember.pendingPrefix}$code';

    return _client.setDoc('$_classRooms/$classCloudId/staff/$pendingId', {
      'teacherName': teacherName,
      'branch': branch,
      'isHomeroom': isHomeroom,
      'meetingDay': meetingDay,
      'meetingTime': meetingTime,
      'joinCode': code,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Branş öğretmeni katılım kodunu girerek kadroya dahil olur.
  ///
  /// Beklemedeki satırı kendi UID'siyle yeniden yazar ve geçici kaydı siler.
  /// İkisi tek batch'te yapılır; yarım kalırsa öğretmen ne eski ne yeni
  /// kimlikle görünürdü.
  ///
  /// Kodu bilmek kadroya katılmaya yeter — kod sınıf öğretmeni tarafından
  /// doğrudan ilgili kişiye iletilir.
  Future<bool> joinStaffByCode({
    required String classCloudId,
    required String joinCode,
    required String teacherUid,
    required String teacherName,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return false;

    try {
      final code = joinCode.trim().toUpperCase();
      final pendingId = '${CloudStaffMember.pendingPrefix}$code';
      final pendingPath = '$_classRooms/$classCloudId/staff/$pendingId';

      final pending = await _client.getDoc(pendingPath);
      if (pending == null) return false;

      // Kadro satırını öğretmenin gerçek UID'siyle yeniden yaz, geçici
      // kaydı sil. Tek batch: yarım kalırsa öğretmen kadroda görünmezdi.
      //
      // `joinedVia` kural motoru için zorunludur: yeni kaydın gerçekten bir
      // davete dayandığını kanıtlar. Bu alan olmadan giriş yapmış herkes
      // kendini kadroya ekleyip mesajlaşma yetkisi kazanabilirdi.
      return await _client.commitBatch({
        '$_classRooms/$classCloudId/staff/$teacherUid': {
          'teacherUid': teacherUid,
          // Öğretmenin kendi hesabındaki adı esas alınır; sınıf
          // öğretmeninin yazdığı ad yalnızca yer tutucuydu.
          'teacherName':
              teacherName.isNotEmpty ? teacherName : pending['teacherName'],
          'branch': pending['branch'] ?? '',
          'isHomeroom': pending['isHomeroom'] ?? false,
          'meetingDay': pending['meetingDay'] ?? '',
          'meetingTime': pending['meetingTime'] ?? '',
          'joinedVia': pendingId,
          'joinedAt': DateTime.now().toIso8601String(),
        },
        pendingPath: null, // geçici kaydı sil
      });
    } catch (e, stackTrace) {
      debugPrint('joinStaffByCode hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Karışması kolay karakterler (0/O, 1/I) dışlanarak 6 haneli kod üretir.
  String _generateJoinCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)])
        .join();
  }

  // --- Durum bildirimleri (veli → öğretmen) ---

  /// Veli durum bildirimi gönderir (ilaç, erken çıkış, not).
  Future<bool> createStatusReport({
    required String classCloudId,
    required String reportId,
    required String studentCloudId,
    required String studentName,
    required String parentUserId,
    required String parentName,
    required String relation,
    required String type,
    required String title,
    required String details,
    String? timeInfo,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/status_reports/$reportId',
      {
        'studentCloudId': studentCloudId,
        'studentName': studentName,
        'parentUserId': parentUserId,
        'parentName': parentName,
        'relation': relation,
        'type': type,
        'title': title,
        'details': details,
        'timeInfo': timeInfo,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
      merge: false,
    );
  }

  /// Bildirimleri getirir.
  ///
  /// [studentCloudId] verilirse yalnızca o öğrenciye ait olanlar (veli
  /// görünümü); verilmezse sınıfın tamamı (öğretmen görünümü).
  Future<List<CloudStatusReport>> fetchStatusReports({
    required String classCloudId,
    String? studentCloudId,
    int limit = 50,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      Query<Map<String, dynamic>> query = db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('status_reports');

      if (studentCloudId != null) {
        query = query.where('studentCloudId', isEqualTo: studentCloudId);
      }

      final snap =
          await query.orderBy('createdAt', descending: true).limit(limit).get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return CloudStatusReport(
          id: d.id,
          studentCloudId: data['studentCloudId'] as String? ?? '',
          studentName: data['studentName'] as String? ?? '',
          parentUserId: data['parentUserId'] as String? ?? '',
          parentName: data['parentName'] as String? ?? '',
          relation: data['relation'] as String? ?? 'Anne',
          type: data['type'] as String? ?? 'note',
          title: data['title'] as String? ?? '',
          details: data['details'] as String? ?? '',
          timeInfo: data['timeInfo'] as String?,
          createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
              DateTime.now(),
          status: data['status'] as String? ?? 'pending',
          acknowledgedAt:
              DateTime.tryParse(data['acknowledgedAt'] as String? ?? ''),
          teacherNote: data['teacherNote'] as String?,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchStatusReports hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Öğretmen bildirimi "görüldü" olarak işaretler.
  Future<bool> acknowledgeStatusReport({
    required String classCloudId,
    required String reportId,
    String? teacherNote,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/status_reports/$reportId',
      {
        'status': 'acknowledged',
        'acknowledgedAt': DateTime.now().toIso8601String(),
        if (teacherNote != null && teacherNote.isNotEmpty)
          'teacherNote': teacherNote,
      },
    );
  }

  // --- Randevular (veli → öğretmen) ---

  /// Veli randevu talebi oluşturur.
  ///
  /// Çakışma denetimi çağrı öncesinde [hasAppointmentConflict] ile yapılır;
  /// kural motoru bunu doğrulayamaz (sorgu gerektirir) ama iki velinin aynı
  /// dilime düşmesi kritik bir hata değildir — öğretmen zaten onaylıyor.
  Future<bool> requestAppointment({
    required String classCloudId,
    required String appointmentId,
    required String studentCloudId,
    required String studentName,
    required String parentUserId,
    required String parentName,
    required String relation,
    required String teacherName,
    required String branch,
    required DateTime appointmentDate,
    required String timeSlot,
    required String topic,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/appointments/$appointmentId',
      {
        'studentCloudId': studentCloudId,
        'studentName': studentName,
        'parentUserId': parentUserId,
        'parentName': parentName,
        'relation': relation,
        'teacherName': teacherName,
        'branch': branch,
        'appointmentDate': appointmentDate.toIso8601String(),
        'timeSlot': timeSlot,
        'topic': topic,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      },
      merge: false,
    );
  }

  /// Aynı öğretmen ve zaman diliminde onaylanmış randevu var mı?
  Future<bool> hasAppointmentConflict({
    required String classCloudId,
    required String teacherName,
    required DateTime appointmentDate,
    required String timeSlot,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return false;

    try {
      final snap = await db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('appointments')
          .where('teacherName', isEqualTo: teacherName)
          .where('timeSlot', isEqualTo: timeSlot)
          .where('appointmentDate', isEqualTo: appointmentDate.toIso8601String())
          .limit(5)
          .get();

      // İptal/reddedilmiş randevular dilimi meşgul etmez.
      return snap.docs.any((d) {
        final status = d.data()['status'] as String? ?? 'pending';
        return status == 'pending' || status == 'confirmed';
      });
    } catch (e, stackTrace) {
      debugPrint('hasAppointmentConflict hatası: $e\n$stackTrace');
      return false; // Denetim yapılamadıysa talebi engelleme.
    }
  }

  /// Randevuları getirir.
  ///
  /// [studentCloudId] verilirse veli görünümü, verilmezse sınıfın tamamı.
  Future<List<CloudAppointment>> fetchAppointments({
    required String classCloudId,
    String? studentCloudId,
    int limit = 50,
  }) async {
    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      Query<Map<String, dynamic>> query = db
          .collection(_classRooms)
          .doc(classCloudId)
          .collection('appointments');

      if (studentCloudId != null) {
        query = query.where('studentCloudId', isEqualTo: studentCloudId);
      }

      final snap =
          await query.orderBy('createdAt', descending: true).limit(limit).get();

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs.map((d) {
        final data = d.data();
        return CloudAppointment(
          id: d.id,
          studentCloudId: data['studentCloudId'] as String? ?? '',
          studentName: data['studentName'] as String? ?? '',
          parentUserId: data['parentUserId'] as String? ?? '',
          parentName: data['parentName'] as String? ?? '',
          relation: data['relation'] as String? ?? 'Anne',
          teacherName: data['teacherName'] as String? ?? '',
          branch: data['branch'] as String? ?? '',
          appointmentDate:
              DateTime.tryParse(data['appointmentDate'] as String? ?? '') ??
                  DateTime.now(),
          timeSlot: data['timeSlot'] as String? ?? '',
          topic: data['topic'] as String? ?? '',
          status: data['status'] as String? ?? 'pending',
          createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
              DateTime.now(),
          responseNote: data['responseNote'] as String?,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('fetchAppointments hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Öğretmen randevuyu onaylar veya reddeder.
  Future<bool> updateAppointmentStatus({
    required String classCloudId,
    required String appointmentId,
    required String status,
    String? responseNote,
  }) {
    return _client.setDoc(
      '$_classRooms/$classCloudId/appointments/$appointmentId',
      {
        'status': status,
        'respondedAt': DateTime.now().toIso8601String(),
        if (responseNote != null && responseNote.isNotEmpty)
          'responseNote': responseNote,
      },
    );
  }
}

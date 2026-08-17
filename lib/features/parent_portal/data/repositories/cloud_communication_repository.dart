import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/cloud/firestore_client.dart';

/// Bulut duyurusu (yalın taşıma modeli).
class CloudAnnouncement {
  final String id;
  final String title;
  final String content;
  final String priority;
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int readCount;
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

/// Sınıfın ders öğretmeni kadrosundan bir üye.
class CloudStaffMember {
  final String teacherUid;
  final String teacherName;
  final String branch;
  final bool isHomeroom;
  final String meetingDay;
  final String meetingTime;

  const CloudStaffMember({
    required this.teacherUid,
    required this.teacherName,
    required this.branch,
    this.isHomeroom = false,
    this.meetingDay = '',
    this.meetingTime = '',
  });
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

      return snap.docs.map((d) {
        final data = d.data();
        return CloudStaffMember(
          teacherUid: d.id,
          teacherName: data['teacherName'] as String? ?? '',
          branch: data['branch'] as String? ?? '',
          isHomeroom: data['isHomeroom'] as bool? ?? false,
          meetingDay: data['meetingDay'] as String? ?? '',
          meetingTime: data['meetingTime'] as String? ?? '',
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
}

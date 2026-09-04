import 'dart:convert';
import 'package:crypto/crypto.dart';

/// SınıfCepte - Güvenli Veli Referans Token Modeli
class ParentTokenModel {
  final String id;
  final String schoolId;
  final String schoolName;
  final int classId;
  final String className;
  final int studentId;
  final String studentName;
  final int studentNumber;
  final String code; // Örn: SC-8A-9402
  final String codeHash; // SHA-256(code + salt)
  final String secondFactorHash; // SHA-256(studentNumber)
  final DateTime createdAt;
  /// Kodun son geçerlilik tarihi.
  ///
  /// Artık gün bazlı bir süre uygulanmaz: kod, öğrenci okulda olduğu
  /// sürece geçerlidir ve olayla kapanır (mezuniyet, başka okula nakil,
  /// öğrenci silme, öğretmenin elle iptali). Yeni üretilen kodlarda bu
  /// alan [noExpiry] olur; eski sürümden gelen tarihli kodlar geriye
  /// dönük uyumluluk için hâlâ saygı görür.
  final DateTime expiresAt;

  /// 'active', 'used', 'expired', 'revoked', 'graduated', 'transferred'
  final String status;
  final int linkedParentCount;
  final int maxLinkedParents;
  final String qrPayload;

  /// Kodu üreten öğretmenin bulut kimliği (Firebase UID).
  ///
  /// Bulut kimliklerini (`cls_{uid}_{id}`, `stu_{uid}_{id}`) üretmek için
  /// gerekir. Bu alan yokken veli bağı yerel yoldan kurulduğunda bulut
  /// kimlikleri boş kalıyor, `hasCloudBinding` false dönüyor ve velinin
  /// duyuru/kadro/mesaj sorguları sessizce boş liste veriyordu.
  final String teacherUid;

  /// İkinci veli kodu etiketi: 'Anne', 'Baba', 'Vasi' vb.
  ///
  /// Boş ise bu, öğrencinin ortak kodudur (anne de baba da kullanabilir).
  /// Ayrı yaşayan ailelerde öğretmen ikinci bir kod üretir ve etiketler;
  /// böylece bir tarafın erişimi diğerini etkilemeden kapatılabilir.
  final String parentLabel;

  const ParentTokenModel({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentName,
    required this.studentNumber,
    required this.code,
    required this.codeHash,
    required this.secondFactorHash,
    required this.createdAt,
    required this.expiresAt,
    this.status = 'active',
    this.linkedParentCount = 0,
    this.maxLinkedParents = 2,
    required this.qrPayload,
    this.parentLabel = '',
    this.teacherUid = '',
  });

  /// Süresiz kodlar için kullanılan uzak tarih.
  ///
  /// Ayrı bir "süresiz" bayrağı yerine uzak bir tarih kullanmak, eski
  /// kayıtları okuyan kodun (ve buluttaki dokümanların) değişmeden
  /// çalışmasını sağlar.
  static final DateTime noExpiry = DateTime.utc(2099, 12, 31);

  /// Kodun süresi doldu mu?
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Süre sınırı olmayan (olayla kapanan) bir kod mu?
  bool get isOpenEnded => !expiresAt.isBefore(noExpiry);

  /// Kod hâlâ kullanılabilir mi?
  ///
  /// Yalnızca 'active' kodlar geçerlidir; 'graduated' ve 'transferred'
  /// durumları öğrencinin okuldan ayrıldığını gösterir.
  bool get isValid =>
      status == 'active' && !isExpired && linkedParentCount < maxLinkedParents;

  /// Belirli bir veliye ayrılmış ikinci kod mu?
  bool get isSecondParentCode => parentLabel.trim().isNotEmpty;

  /// Listede gösterilecek başlık: "Ali Veli — Anne" ya da "Ali Veli".
  String get displayLabel =>
      isSecondParentCode ? '$studentName — $parentLabel' : studentName;

  /// Kalan gün sayısı (gün yuvarlama ile)
  int get remainingDays {
    final diffHours = expiresAt.difference(DateTime.now()).inHours;
    if (diffHours <= 0) return 0;
    return (diffHours / 24).ceil();
  }

  /// Kalan saat sayısı (son gün için)
  int get remainingHours {
    final diff = expiresAt.difference(DateTime.now()).inHours;
    return diff < 0 ? 0 : diff;
  }

  /// Statü metni
  String get statusText {
    if (status == 'revoked') return 'İptal Edildi 🚫';
    if (isExpired || status == 'expired') return 'Süresi Doldu ⌛';
    if (linkedParentCount >= maxLinkedParents || status == 'used') return 'Kullanıldı (Dolu) ✅';
    return 'Aktif ($remainingDays gün kaldı) 🟢';
  }

  /// Referans kodunu standart 'SC-{classTag}-{digits}' biçimine normalize eder.
  ///
  /// Desteklenen formatlar:
  /// - 'SC-8A-9402' -> 'SC-8A-9402'
  /// - 'sc-8a-9402' -> 'SC-8A-9402'
  /// - 'sc 8a 9402' -> 'SC-8A-9402'
  /// - 'SC8A9402'   -> 'SC-8A-9402'
  /// - '8A-9402'    -> 'SC-8A-9402'
  /// - '8a9402'     -> 'SC-8A-9402'
  static String normalizeCode(String input) {
    var raw = input.trim().toUpperCase().replaceAll(' ', '');
    raw = raw.replaceAll('İ', 'I').replaceAll('ı', 'I');
    if (raw.isEmpty) return '';

    final stripped = raw.replaceAll('-', '').replaceAll('/', '').replaceAll('.', '');
    String body = stripped;
    if (body.startsWith('SC')) {
      body = body.substring(2);
    }

    if (body.length >= 5) {
      final digits = body.substring(body.length - 4);
      final isDigits = RegExp(r'^\d{4}$').hasMatch(digits);
      if (isDigits) {
        final classTag = body.substring(0, body.length - 4);
        if (classTag.isNotEmpty) {
          return 'SC-$classTag-$digits';
        }
      }
    }

    if (raw.startsWith('SC-')) {
      return raw;
    }
    return raw;
  }

  /// SHA-256 Hash Yardımcısı
  static String generateSha256(String input, {String salt = 'sinifcepte_salt_2026'}) {
    final bytes = utf8.encode('$input:$salt');
    return sha256.convert(bytes).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'school_name': schoolName,
      'class_id': classId,
      'class_name': className,
      'student_id': studentId,
      'student_name': studentName,
      'student_number': studentNumber,
      'code': code,
      'code_hash': codeHash,
      'second_factor_hash': secondFactorHash,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status,
      'linked_parent_count': linkedParentCount,
      'max_linked_parents': maxLinkedParents,
      'qr_payload': qrPayload,
      'parent_label': parentLabel,
      'teacher_uid': teacherUid,
    };
  }

  factory ParentTokenModel.fromMap(Map<String, dynamic> map) {
    return ParentTokenModel(
      id: map['id'] as String,
      schoolId: map['school_id'] as String? ?? '',
      schoolName: map['school_name'] as String? ?? '',
      classId: map['class_id'] as int,
      className: map['class_name'] as String? ?? '',
      studentId: map['student_id'] as int,
      studentName: map['student_name'] as String? ?? '',
      studentNumber: map['student_number'] as int? ?? 0,
      code: map['code'] as String,
      codeHash: map['code_hash'] as String,
      secondFactorHash: map['second_factor_hash'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      status: map['status'] as String? ?? 'active',
      linkedParentCount: map['linked_parent_count'] as int? ?? 0,
      maxLinkedParents: map['max_linked_parents'] as int? ?? 2,
      qrPayload: map['qr_payload'] as String? ?? '',
      parentLabel: map['parent_label'] as String? ?? '',
      teacherUid: map['teacher_uid'] as String? ?? '',
    );
  }

  ParentTokenModel copyWith({
    String? id,
    String? schoolId,
    String? schoolName,
    int? classId,
    String? className,
    int? studentId,
    String? studentName,
    int? studentNumber,
    String? code,
    String? codeHash,
    String? secondFactorHash,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? status,
    int? linkedParentCount,
    int? maxLinkedParents,
    String? qrPayload,
    String? parentLabel,
    String? teacherUid,
  }) {
    return ParentTokenModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentNumber: studentNumber ?? this.studentNumber,
      code: code ?? this.code,
      codeHash: codeHash ?? this.codeHash,
      secondFactorHash: secondFactorHash ?? this.secondFactorHash,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      linkedParentCount: linkedParentCount ?? this.linkedParentCount,
      maxLinkedParents: maxLinkedParents ?? this.maxLinkedParents,
      qrPayload: qrPayload ?? this.qrPayload,
      parentLabel: parentLabel ?? this.parentLabel,
      teacherUid: teacherUid ?? this.teacherUid,
    );
  }
}

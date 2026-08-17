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
  final DateTime expiresAt;
  final String status; // 'active', 'used', 'expired', 'revoked'
  final int linkedParentCount;
  final int maxLinkedParents;
  final String qrPayload;

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
  });

  /// Token geçerli mi?
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => status == 'active' && !isExpired && linkedParentCount < maxLinkedParents;

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
    );
  }
}

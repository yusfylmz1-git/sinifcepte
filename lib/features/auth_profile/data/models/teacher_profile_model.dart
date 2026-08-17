/// SınıfCepte - Öğretmen Profil Modeli
class TeacherProfileModel {
  final String id;
  final String firstName;
  final String lastName;
  final String gender; // 'Erkek', 'Kadın'
  final String branch;
  final String schoolName;
  final String? city;
  final String? district;
  final String? schoolId;
  final String? schoolType;
  final String schoolPrincipalName;
  final String email;
  final String? photoUrl;
  final bool isVerifiedBySchoolAdmin;
  final DateTime? verifiedAt;
  final String? verifiedByAdminId;

  const TeacherProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.gender = 'Erkek',
    required this.branch,
    required this.schoolName,
    this.city,
    this.district,
    this.schoolId,
    this.schoolType,
    required this.schoolPrincipalName,
    required this.email,
    this.photoUrl,
    this.isVerifiedBySchoolAdmin = false,
    this.verifiedAt,
    this.verifiedByAdminId,
  });

  String get fullName => '$firstName $lastName'.trim();

  /// Kanonik bağ: meb_ / man_ / pending_. Eski sch_ / tpl_ / custom_ bağ sayılmaz.
  bool get isSchoolBound {
    final id = schoolId;
    if (id == null || id.isEmpty) return false;
    return id.startsWith('meb_') || id.startsWith('man_') || id.startsWith('pending_');
  }

  String get fullSchoolTitle => [
        schoolName,
        if (district != null && district!.isNotEmpty && city != null && city!.isNotEmpty)
          '($district, $city)'
      ].join(' ');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'branch': branch,
      'schoolName': schoolName,
      'city': city,
      'district': district,
      'schoolId': schoolId,
      'schoolType': schoolType,
      'schoolPrincipalName': schoolPrincipalName,
      'email': email,
      'photoUrl': photoUrl,
      'isVerifiedBySchoolAdmin': isVerifiedBySchoolAdmin,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'verifiedByAdminId': verifiedByAdminId,
    };
  }

  factory TeacherProfileModel.fromMap(Map<String, dynamic> map) {
    return TeacherProfileModel(
      id: map['id'] as String? ?? '',
      firstName: map['firstName'] as String? ?? map['ad'] as String? ?? '',
      lastName: map['lastName'] as String? ?? map['soyad'] as String? ?? '',
      gender: map['gender'] as String? ?? map['cinsiyet'] as String? ?? 'Erkek',
      branch: map['branch'] as String? ?? map['brans'] as String? ?? '',
      schoolName: map['schoolName'] as String? ?? map['okul'] as String? ?? '',
      city: map['city'] as String? ?? map['il'] as String?,
      district: map['district'] as String? ?? map['ilce'] as String?,
      schoolId: map['schoolId'] as String? ?? map['okulId'] as String?,
      schoolType: map['schoolType'] as String? ?? map['okulTuru'] as String?,
      schoolPrincipalName: map['schoolPrincipalName'] as String? ?? map['mudur'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? map['fotoUrl'] as String?,
      isVerifiedBySchoolAdmin: map['isVerifiedBySchoolAdmin'] as bool? ?? false,
      verifiedAt: map['verifiedAt'] != null ? DateTime.parse(map['verifiedAt'].toString()) : null,
      verifiedByAdminId: map['verifiedByAdminId'] as String?,
    );
  }

  TeacherProfileModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? gender,
    String? branch,
    String? schoolName,
    String? city,
    String? district,
    String? schoolId,
    String? schoolType,
    String? schoolPrincipalName,
    String? email,
    String? photoUrl,
    bool? isVerifiedBySchoolAdmin,
    DateTime? verifiedAt,
    String? verifiedByAdminId,
  }) {
    return TeacherProfileModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      branch: branch ?? this.branch,
      schoolName: schoolName ?? this.schoolName,
      city: city ?? this.city,
      district: district ?? this.district,
      schoolId: schoolId ?? this.schoolId,
      schoolType: schoolType ?? this.schoolType,
      schoolPrincipalName: schoolPrincipalName ?? this.schoolPrincipalName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerifiedBySchoolAdmin: isVerifiedBySchoolAdmin ?? this.isVerifiedBySchoolAdmin,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedByAdminId: verifiedByAdminId ?? this.verifiedByAdminId,
    );
  }
}

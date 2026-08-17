import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/auth_profile/data/models/school_admin_request_model.dart';
import 'package:sinifcepte/features/auth_profile/data/repositories/school_admin_repository.dart';
import 'package:sinifcepte/features/auth_profile/providers/user_role_provider.dart';

SchoolAdminRequestModel request({
  SchoolAdminStatus status = SchoolAdminStatus.pending,
  String teacherUid = 'uidAhmet',
}) {
  return SchoolAdminRequestModel(
    id: SchoolAdminRepository.requestIdFor(teacherUid),
    teacherUid: teacherUid,
    teacherName: 'Ahmet Yılmaz',
    teacherEmail: 'ahmet@example.com',
    schoolId: 'meb_16_123456',
    schoolName: 'Cumhuriyet Ortaokulu',
    city: 'Bursa',
    district: 'Nilüfer',
    note: 'Müdür yardımcısıyım.',
    status: status,
    requestedAt: DateTime(2026, 8, 18),
  );
}

void main() {
  group('Başvuru kimliği', () {
    test('Her öğretmenin tek başvurusu olur (deterministik kimlik)', () {
      // Aynı öğretmen iki kez başvursa bile kuyruğu dolduramaz.
      final id1 = SchoolAdminRepository.requestIdFor('uidAhmet');
      final id2 = SchoolAdminRepository.requestIdFor('uidAhmet');
      final id3 = SchoolAdminRepository.requestIdFor('uidMehmet');

      expect(id1, id2);
      expect(id1, isNot(id3));
      expect(id1, 'req_uidAhmet');
    });

    test('Deterministik kimlik tek get() ile okumayı sağlar', () {
      // Sorgu yerine doğrudan doküman kimliği: indeks gerekmez, tek okuma.
      final req = request();
      expect(req.id, SchoolAdminRepository.requestIdFor(req.teacherUid));
    });
  });

  group('Başvuru durumu', () {
    test('Yeni başvuru beklemede başlar', () {
      expect(request().isPending, isTrue);
      expect(request().isApproved, isFalse);
      expect(request().statusText, 'Onay bekliyor');
    });

    test('Onaylanmış başvuru doğru raporlanır', () {
      final approved = request(status: SchoolAdminStatus.approved);
      expect(approved.isApproved, isTrue);
      expect(approved.statusText, 'Onaylandı');
    });

    test('statusOf boş başvuruyu none sayar', () {
      expect(SchoolAdminRepository.statusOf(null), SchoolAdminStatus.none);
      expect(
        SchoolAdminRepository.statusOf(request()),
        SchoolAdminStatus.pending,
      );
    });

    test('toMap kural motorunun beklediği alanları taşır', () {
      final map = request().toMap();

      // firestore.rules bu iki alanı özellikle denetler.
      expect(map['status'], 'pending');
      expect(map['teacher_uid'], 'uidAhmet');
      expect(map['school_id'], 'meb_16_123456');
    });

    test('Serileştirme kayıpsızdır', () {
      final original = request(status: SchoolAdminStatus.approved);
      final restored = SchoolAdminRequestModel.fromMap(original.toMap());

      expect(restored.teacherUid, original.teacherUid);
      expect(restored.schoolId, original.schoolId);
      expect(restored.status, SchoolAdminStatus.approved);
      expect(restored.note, original.note);
    });
  });

  group('Yönetici yetkisi — opsiyonellik korunuyor', () {
    test('Onaysız öğretmen tüm özellikleri kullanır', () {
      const teacher = UserRoleState(role: UserRole.teacher, isInitialized: true);

      expect(teacher.isTeacher, isTrue);
      // Yönetici paneli kapalı ama öğretmenlik tam.
      expect(teacher.isSchoolAdmin, isFalse);
      expect(teacher.canApplyForSchoolAdmin, isTrue);
    });

    test('KRİTİK: başvuru kaydı tek başına panel açmaz', () {
      // Firestore'daki kayıt 'approved' olsa bile yetki claim'den gelir.
      // Bu durum, claim henüz tazelenmemişken oluşur.
      const notYetRefreshed = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.pending,
      );
      expect(notYetRefreshed.isSchoolAdmin, isFalse);

      const refreshed = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.approved,
      );
      expect(refreshed.isSchoolAdmin, isTrue);
    });

    test('KRİTİK: veli rolü yönetici claim taşısa bile panel açılmaz', () {
      const parentWithClaim = UserRoleState(
        role: UserRole.parent,
        adminStatus: SchoolAdminStatus.approved,
      );

      expect(parentWithClaim.isSchoolAdmin, isFalse);
      expect(parentWithClaim.canApplyForSchoolAdmin, isFalse);
    });

    test('Beklemedeki başvuru tekrar başvuruyu engeller', () {
      const pending = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.pending,
      );
      expect(pending.canApplyForSchoolAdmin, isFalse);
    });

    test('Reddedilen öğretmen yeniden başvurabilir', () {
      const rejected = UserRoleState(
        role: UserRole.teacher,
        adminStatus: SchoolAdminStatus.rejected,
      );
      expect(rejected.canApplyForSchoolAdmin, isTrue);
      expect(rejected.isSchoolAdmin, isFalse);
    });
  });

  group('Şikâyet kaydı', () {
    test('Yeni şikâyet açık durumda başlar', () {
      final report = CloudContentReport(
        id: 'rep_1',
        reporterUid: 'parentAyse',
        schoolId: 'meb_16_123456',
        contentId: 'ann_1',
        contentType: 'Duyuru',
        contentSnippet: 'Uygunsuz metin',
        reason: 'Hakaret içeriyor',
        reportedAt: DateTime(2026, 8, 18),
      );

      expect(report.isOpen, isTrue);
      expect(report.reporterRole, 'parent');
      // Okul kimliği yöneticinin yalnızca kendi okulunu görmesini sağlar.
      expect(report.schoolId, 'meb_16_123456');
    });

    test('İncelenmiş şikâyet açık sayılmaz', () {
      final reviewed = CloudContentReport(
        id: 'rep_2',
        reporterUid: 'parentAyse',
        contentId: 'ann_1',
        contentType: 'Duyuru',
        contentSnippet: '',
        reason: 'test',
        reportedAt: DateTime(2026, 8, 18),
        status: 'reviewed',
      );

      expect(reviewed.isOpen, isFalse);
    });
  });
}

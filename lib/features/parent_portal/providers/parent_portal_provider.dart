import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/class_announcement_model.dart';
import '../data/models/class_teacher_contact_model.dart';
import '../data/models/parent_appointment_model.dart';
import '../data/models/parent_status_report_model.dart';
import '../data/repositories/parent_portal_repository.dart';

/// ParentPortalRepository Provider
final parentPortalRepositoryProvider = Provider<ParentPortalRepository>((ref) {
  return ParentPortalRepository();
});

/// Öğrencinin Veli Durum Bildirimleri Provider'ı
final studentStatusReportsProvider = FutureProvider.family<List<ParentStatusReportModel>, int>((ref, studentId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getStatusReportsForStudent(studentId);
});

/// Sınıfın Tüm Veli Bildirimleri Provider'ı (Öğretmen Görünümü)
final classStatusReportsProvider = FutureProvider.family<List<ParentStatusReportModel>, int>((ref, classId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getStatusReportsForClass(classId);
});

/// Sınıf Duyuruları Provider'ı
final classAnnouncementsProvider = FutureProvider.family<List<ClassAnnouncementModel>, int>((ref, classId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getAnnouncementsForClass(classId);
});

/// Sınıf Ders Öğretmenleri Kadrosu Provider'ı
final classTeacherContactsProvider = FutureProvider.family<List<ClassTeacherContactModel>, int>((ref, classId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getTeacherContactsForClass(classId);
});

/// Velinin Randevuları Provider'ı
final parentAppointmentsProvider = FutureProvider.family<List<ParentAppointmentModel>, String>((ref, parentUserId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getAppointmentsForParent(parentUserId);
});

/// Sınıfın / Öğretmenin Randevuları Provider'ı
final classAppointmentsProvider = FutureProvider.family<List<ParentAppointmentModel>, int>((ref, classId) async {
  final repo = ref.watch(parentPortalRepositoryProvider);
  return repo.getAppointmentsForClass(classId);
});

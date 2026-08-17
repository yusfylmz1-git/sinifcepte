import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parent_status_report_model.dart';
import '../models/class_announcement_model.dart';
import '../models/class_teacher_contact_model.dart';
import '../models/parent_appointment_model.dart';

/// SınıfCepte - Veli Portalı Master Veri Deposu (Offline-First / SharedPreferences)
class ParentPortalRepository {
  static const String _statusReportsPrefKey = 'sinifcepte_parent_status_reports';
  static const String _announcementsPrefKey = 'sinifcepte_class_announcements';
  static const String _teacherContactsPrefKey = 'sinifcepte_class_teacher_contacts';
  static const String _appointmentsPrefKey = 'sinifcepte_parent_appointments';

  // --- 1. DURUM BİLDİRİMLERİ (İlaç, Erken Çıkış, Not) ---

  Future<List<ParentStatusReportModel>> _loadStatusReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_statusReportsPrefKey) ?? [];
      final list = <ParentStatusReportModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ParentStatusReportModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _loadStatusReports hatası: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> _saveStatusReports(List<ParentStatusReportModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = list.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList(_statusReportsPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _saveStatusReports hatası: $e\n$stackTrace');
    }
  }

  /// Yeni Durum Bildirimi Oluşturma (Veli)
  Future<ParentStatusReportModel> createStatusReport(ParentStatusReportModel report) async {
    final list = await _loadStatusReports();
    list.insert(0, report);
    await _saveStatusReports(list);
    return report;
  }

  /// Belirli Bir Öğrencinin Durum Bildirimleri (Veli Görünümü)
  Future<List<ParentStatusReportModel>> getStatusReportsForStudent(int studentId) async {
    final list = await _loadStatusReports();
    return list.where((r) => r.studentId == studentId).toList();
  }

  /// Belirli Bir Sınıfın Durum Bildirimleri (Öğretmen Görünümü)
  Future<List<ParentStatusReportModel>> getStatusReportsForClass(int classId) async {
    final list = await _loadStatusReports();
    return list.where((r) => r.classId == classId).toList();
  }

  /// Bildirimi "Görüldü / Onaylandı" Olarak İşaretleme (Öğretmen)
  Future<bool> acknowledgeStatusReport(String reportId, {String? teacherNote}) async {
    final list = await _loadStatusReports();
    final index = list.indexWhere((r) => r.id == reportId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        status: 'acknowledged',
        teacherAcknowledgedAt: DateTime.now(),
        teacherNote: teacherNote,
      );
      await _saveStatusReports(list);
      return true;
    }
    return false;
  }

  // --- 2. OKUNDU ONAYLI SINIF DUYURULARI ---

  Future<List<ClassAnnouncementModel>> _loadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_announcementsPrefKey) ?? [];
      final list = <ClassAnnouncementModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ClassAnnouncementModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _loadAnnouncements hatası: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> _saveAnnouncements(List<ClassAnnouncementModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = list.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_announcementsPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _saveAnnouncements hatası: $e\n$stackTrace');
    }
  }

  /// Sınıfa Yeni Duyuru Yayınlama (Öğretmen)
  Future<ClassAnnouncementModel> createAnnouncement(ClassAnnouncementModel announcement) async {
    final list = await _loadAnnouncements();
    list.insert(0, announcement);
    await _saveAnnouncements(list);
    return announcement;
  }

  /// Sınıfın Duyurularını Getirme
  Future<List<ClassAnnouncementModel>> getAnnouncementsForClass(int classId) async {
    final list = await _loadAnnouncements();
    final filtered = list.where((a) => a.classId == classId).toList();
    // Eğer sınıf için hiç duyuru yoksa varsayılan karşılama duyurusu oluştur
    if (filtered.isEmpty) {
      final defaultAnn = ClassAnnouncementModel(
        id: 'ann_def_${classId}_1',
        classId: classId,
        className: 'Sınıfım',
        authorTeacherId: 'teacher_main',
        authorTeacherName: 'Sınıf Rehber Öğretmeni',
        title: 'SınıfCepte Veli Bilgilendirme Sistemi Başladı 🚀',
        content: 'Değerli velilerimiz, öğrencilerimizin ders içi durumları, etkinlikleri ve sınıf duyuruları bu portal üzerinden güncel olarak paylaşılacaktır.',
        priority: 'event',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      list.add(defaultAnn);
      await _saveAnnouncements(list);
      return [defaultAnn];
    }
    return filtered;
  }

  /// Duyuruyu "Okundu" Olarak İşaretleme (Veli)
  Future<bool> markAnnouncementAsRead(String announcementId, String parentUserId) async {
    final list = await _loadAnnouncements();
    final index = list.indexWhere((a) => a.id == announcementId);
    if (index != -1) {
      final current = list[index];
      if (!current.readByParentUserIds.contains(parentUserId)) {
        final updatedIds = List<String>.from(current.readByParentUserIds)..add(parentUserId);
        list[index] = current.copyWith(readByParentUserIds: updatedIds);
        await _saveAnnouncements(list);
        return true;
      }
    }
    return false;
  }

  /// Duyuru Silme (Öğretmen)
  Future<bool> deleteAnnouncement(String announcementId) async {
    final list = await _loadAnnouncements();
    final countBefore = list.length;
    list.removeWhere((a) => a.id == announcementId);
    if (list.length != countBefore) {
      await _saveAnnouncements(list);
      return true;
    }
    return false;
  }

  // --- 3. DERS ÖĞRETMENLERİ KADROSU & GÖRÜŞME SAATLERİ ---

  Future<List<ClassTeacherContactModel>> _loadTeacherContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_teacherContactsPrefKey) ?? [];
      final list = <ClassTeacherContactModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ClassTeacherContactModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _loadTeacherContacts hatası: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> _saveTeacherContacts(List<ClassTeacherContactModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = list.map((c) => jsonEncode(c.toMap())).toList();
      await prefs.setStringList(_teacherContactsPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _saveTeacherContacts hatası: $e\n$stackTrace');
    }
  }

  /// Sınıfın Ders Öğretmenlerini Getirme (Yoksa Varsayılan Kadro Oluşturur)
  Future<List<ClassTeacherContactModel>> getTeacherContactsForClass(
    int classId, {
    String className = '8-A',
    String? homeroomTeacherName,
    String? homeroomBranch,
  }) async {
    final list = await _loadTeacherContacts();
    final filtered = list.where((c) => c.classId == classId).toList();

    if (filtered.isNotEmpty) return filtered;

    if (homeroomTeacherName != null && homeroomTeacherName.isNotEmpty) {
      return [
        ClassTeacherContactModel(
          id: 'tc_${classId}_homeroom',
          classId: classId,
          className: className,
          teacherName: homeroomTeacherName,
          branch: homeroomBranch?.isNotEmpty == true
              ? '$homeroomBranch (Sınıf Rehber Öğretmeni)'
              : 'Sınıf Rehber Öğretmeni',
          isHomeroomTeacher: true,
          meetingDay: '',
          meetingTime: '',
          location: '',
        ),
      ];
    }

    return [];
  }

  /// Öğretmen Kadrosuna Yeni Öğretmen Ekleme / Güncelleme
  Future<void> saveTeacherContact(ClassTeacherContactModel contact) async {
    final list = await _loadTeacherContacts();
    final index = list.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      list[index] = contact;
    } else {
      list.add(contact);
    }
    await _saveTeacherContacts(list);
  }

  // --- 4. RANDEVU & VELİ GÖRÜŞME TALEPLERİ ---

  Future<List<ParentAppointmentModel>> _loadAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_appointmentsPrefKey) ?? [];
      final list = <ParentAppointmentModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ParentAppointmentModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _loadAppointments hatası: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> _saveAppointments(List<ParentAppointmentModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = list.map((a) => jsonEncode(a.toMap())).toList();
      await prefs.setStringList(_appointmentsPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentPortalRepository _saveAppointments hatası: $e\n$stackTrace');
    }
  }

  /// Randevu Talebi Oluşturma (Çakışma Kontrolü ile)
  Future<Map<String, dynamic>> requestAppointment(ParentAppointmentModel appointment) async {
    final list = await _loadAppointments();

    // Aynı gün ve aynı saat diliminde onaylanmış randevu var mı kontrol et
    final isConflict = list.any((a) =>
        a.teacherName == appointment.teacherName &&
        a.appointmentDate.year == appointment.appointmentDate.year &&
        a.appointmentDate.month == appointment.appointmentDate.month &&
        a.appointmentDate.day == appointment.appointmentDate.day &&
        a.timeSlot == appointment.timeSlot &&
        a.status == 'confirmed');

    if (isConflict) {
      return {
        'success': false,
        'message': 'Seçtiğiniz tarih ve saatte öğretmenin başka bir randevusu bulunmaktadır. Lütfen başka bir saat seçin.',
      };
    }

    list.insert(0, appointment);
    await _saveAppointments(list);
    return {'success': true, 'appointment': appointment};
  }

  /// Veli İçin Randevular
  Future<List<ParentAppointmentModel>> getAppointmentsForParent(String parentUserId) async {
    final list = await _loadAppointments();
    return list.where((a) => a.parentUserId == parentUserId).toList();
  }

  /// Sınıf / Öğretmen İçin Randevular
  Future<List<ParentAppointmentModel>> getAppointmentsForClass(int classId) async {
    final list = await _loadAppointments();
    return list.where((a) => a.classId == classId).toList();
  }

  /// Randevu Durumu Güncelleme (Onaylama / Reddetme)
  Future<bool> updateAppointmentStatus(
    String appointmentId, {
    required String status,
    String? responseNote,
  }) async {
    final list = await _loadAppointments();
    final index = list.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        status: status,
        responseNote: responseNote,
      );
      await _saveAppointments(list);
      return true;
    }
    return false;
  }
}

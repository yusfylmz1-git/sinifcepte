/// SınıfCepte — tek kaynak SharedPreferences anahtarları.
/// Eski anahtarlar ilk okumada kanonik anahtara birleştirilir.
class PrefsKeys {
  PrefsKeys._();

  static const parentLinks = 'sinifcepte_parent_links_v1';
  static const parentLinksLegacy = 'sinifcepte_parent_links';

  static const parentTokens = 'sinifcepte_student_parent_tokens';
  static const parentTokensLegacy = 'sinifcepte_parent_tokens';

  static const auditLogs = 'sinifcepte_audit_logs';
  static const auditLogsLegacy = 'sinifcepte_audit_logs_v1';

  static const consentLogs = 'sinifcepte_consent_logs';
  static const contentReports = 'sinifcepte_content_reports';
  static const verifiedTeachers = 'sinifcepte_verified_teachers';
  static const localParentId = 'sinifcepte_local_parent_id';
  static const activeUserRole = 'sinifcepte_active_user_role';

  static const statusReports = 'sinifcepte_parent_status_reports';
  static const announcements = 'sinifcepte_class_announcements';
  static const teacherContacts = 'sinifcepte_class_teacher_contacts';
  static const appointments = 'sinifcepte_parent_appointments';
  static const classMessages = 'sinifcepte_class_messages';
  static const pendingSchoolSubmissions = 'sinifcepte_pending_school_submissions';

  /// Veli Google hesabının görünen adı (bağlantı kartlarında gösterilir).
  static const parentDisplayName = 'sinifcepte_parent_display_name';

  /// Reklam gösterimi için kullanıcı onayı ve yapılandırma durumu.
  static const adsEnabled = 'sinifcepte_ads_enabled';
}

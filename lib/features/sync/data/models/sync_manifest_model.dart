/// SınıfCepte - Bulut Senkronizasyon Versiyon Manifest Modeli
class SyncManifestModel {
  final int academicCalendarVersion;
  final int outcomesVersion;
  final int announcementsVersion;
  final String minRequiredAppVersion;
  final String latestAppVersion;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final DateTime lastUpdated;

  const SyncManifestModel({
    this.academicCalendarVersion = 1,
    this.outcomesVersion = 1,
    this.announcementsVersion = 1,
    this.minRequiredAppVersion = '1.0.0',
    this.latestAppVersion = '1.0.0',
    this.maintenanceMode = false,
    this.maintenanceMessage,
    required this.lastUpdated,
  });

  factory SyncManifestModel.fromMap(Map<String, dynamic> map) {
    return SyncManifestModel(
      academicCalendarVersion: map['calendar_version'] as int? ?? 1,
      outcomesVersion: map['outcomes_version'] as int? ?? 1,
      announcementsVersion: map['announcements_version'] as int? ?? 1,
      minRequiredAppVersion: map['min_app_version'] as String? ?? '1.0.0',
      latestAppVersion: map['latest_app_version'] as String? ?? '1.0.0',
      maintenanceMode: (map['maintenance_mode'] as bool?) ?? false,
      maintenanceMessage: map['maintenance_message'] as String?,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calendar_version': academicCalendarVersion,
      'outcomes_version': outcomesVersion,
      'announcements_version': announcementsVersion,
      'min_app_version': minRequiredAppVersion,
      'latest_app_version': latestAppVersion,
      'maintenance_mode': maintenanceMode,
      'maintenance_message': maintenanceMessage,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

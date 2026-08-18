import 'package:flutter/foundation.dart';
import '../../../core/cloud/remote_manifest_service.dart';
import '../../../core/database/database_helper.dart';

/// Senkronizasyon Sonucu
class SyncResult {
  final bool success;
  final bool hasUpdates;
  final List<String> updatedModules;
  final String? message;

  /// Sunucu bakım modunda mı?
  final bool maintenanceMode;
  final String maintenanceMessage;

  /// Yüklü sürüm artık desteklenmiyor mu?
  final bool updateRequired;

  const SyncResult({
    required this.success,
    required this.hasUpdates,
    this.updatedModules = const [],
    this.message,
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.updateRequired = false,
  });
}

/// SınıfCepte - Sıfır Maliyetli Akıllı Senkronizasyon Servisi (Offline-First)
///
/// ## Ne değişti (Faz 5)
/// Önceki sürüm bulut manifestini **kod içinde sabit üretiyordu**; yani
/// ağa hiç çıkmıyor, sonuç her zaman "verileriniz güncel" oluyordu. Admin
/// portalındaki "+1 Artır (Yayınla)" butonu bu yüzden mobil tarafı hiç
/// etkilemiyordu.
///
/// Artık sürümler **Firebase Remote Config**'ten okunuyor
/// (maliyet kararı #3: ücretsiz ve okuma kotası yok). Firestore'dan
/// okunsaydı 10M kullanıcıda aylık ~$180 gereksiz maliyet oluşurdu.
///
/// ## Offline davranışı
/// Ağ yoksa uzak manifest varsayılana düşer ve hiçbir modül güncellenmez;
/// uygulama yerel verilerle kesintisiz çalışmaya devam eder.
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const String _kCalendarSyncKey = 'sync_academic_calendar';
  static const String _kOutcomesSyncKey = 'sync_curriculum_outcomes';
  static const String _kSchoolsSyncKey = 'sync_school_directory';

  /// Uygulamanın yayımlanmış sürümü (pubspec `version` alanıyla eşleşir).
  static const String currentAppVersion = '1.0.0';

  /// Arka planda veya manuel tetiklenen akıllı senkronizasyon.
  ///
  /// [force] kullanıcı açıkça "güncellemeleri denetle" dediğinde verilir;
  /// Remote Config'in 6 saatlik önbellek aralığını atlar.
  Future<SyncResult> checkAndSyncData({bool force = false}) async {
    try {
      // 1. Uzak yapılandırmayı hazırla / tazele.
      await RemoteManifestService.instance.initialize();
      if (force) {
        await RemoteManifestService.instance.refresh(force: true);
      }
      final manifest = RemoteManifestService.instance.manifest;

      // 2. Bakım modu her şeyin önündedir: sunucu kapalıysa güncelleme
      //    denemek anlamsızdır.
      if (manifest.maintenanceMode) {
        return SyncResult(
          success: true,
          hasUpdates: false,
          maintenanceMode: true,
          maintenanceMessage: manifest.maintenanceMessage.isNotEmpty
              ? manifest.maintenanceMessage
              : 'Sistem kısa süreli bakımda. Verileriniz cihazınızda güvende.',
          message: 'Bakım modu etkin.',
        );
      }

      // 3. Yüklü sürüm desteklenmiyorsa kullanıcıyı güncellemeye yönlendir.
      final updateRequired =
          RemoteManifestService.instance.isUpdateRequired(currentAppVersion);

      // 4. Yerel sürümlerle karşılaştır.
      final db = DatabaseHelper.instance;
      final localCalendar = await db.syncMetadataVersionGetir(_kCalendarSyncKey);
      final localOutcomes = await db.syncMetadataVersionGetir(_kOutcomesSyncKey);
      final localSchools = await db.syncMetadataVersionGetir(_kSchoolsSyncKey);

      final updatedModules = <String>[];

      if (force || manifest.calendarVersion > localCalendar) {
        await db.syncMetadataVersionGuncelle(
          _kCalendarSyncKey,
          manifest.calendarVersion,
        );
        updatedModules.add('MEB Akademik Takvimi');
      }

      if (force || manifest.outcomesVersion > localOutcomes) {
        await db.syncMetadataVersionGuncelle(
          _kOutcomesSyncKey,
          manifest.outcomesVersion,
        );
        updatedModules.add('Müfredat Kazanımları');
      }

      if (force || manifest.schoolDirectoryVersion > localSchools) {
        await db.syncMetadataVersionGuncelle(
          _kSchoolsSyncKey,
          manifest.schoolDirectoryVersion,
        );
        updatedModules.add('Okul Dizini');
      }

      return SyncResult(
        success: true,
        hasUpdates: updatedModules.isNotEmpty,
        updatedModules: updatedModules,
        updateRequired: updateRequired,
        message: updatedModules.isNotEmpty
            ? '${updatedModules.join(', ')} başarıyla güncellendi 🚀'
            : 'Verileriniz zaten güncel ✨',
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (SyncService.checkAndSyncData) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------');
      return const SyncResult(
        success: false,
        hasUpdates: false,
        message: 'Senkronizasyon sırasında bir sorun oluştu. '
            'Uygulamanız yerel verilerle çalışmaya devam ediyor.',
      );
    }
  }
}

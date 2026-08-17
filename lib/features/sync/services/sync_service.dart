import 'package:flutter/foundation.dart';
import '../../../core/database/database_helper.dart';
import '../data/models/sync_manifest_model.dart';

/// Senkronizasyon Sonucu
class SyncResult {
  final bool success;
  final bool hasUpdates;
  final List<String> updatedModules;
  final String? message;

  const SyncResult({
    required this.success,
    required this.hasUpdates,
    this.updatedModules = const [],
    this.message,
  });
}

/// SınıfCepte - Sıfır Maliyetli Akıllı Bulut Senkronizasyon Servisi (Offline-First)
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const String _kCalendarSyncKey = 'sync_academic_calendar';
  static const String _kOutcomesSyncKey = 'sync_curriculum_outcomes';

  /// Arka planda veya manuel tetiklenen akıllı senkronizasyon
  Future<SyncResult> checkAndSyncData({bool force = false}) async {
    try {
      // 1. Yerel Veritabanındaki Güncel Versiyonları Oku
      final localCalendarVersion =
          await DatabaseHelper.instance.syncMetadataVersionGetir(_kCalendarSyncKey);
      final localOutcomesVersion =
          await DatabaseHelper.instance.syncMetadataVersionGetir(_kOutcomesSyncKey);

      // 2. Buluttaki Manifest Bilgisini Al (Örn: Cloud Firestore veya CDN endpoint)
      // Şimdilik varsayılan manifest simülasyonu
      final cloudManifest = SyncManifestModel(
        academicCalendarVersion: 1, // Sunucuda versiyon 1
        outcomesVersion: 1,
        announcementsVersion: 1,
        lastUpdated: DateTime.now(),
      );

      final updatedModules = <String>[];

      // A. MEB Akademik Takvim Kontrolü
      if (force || cloudManifest.academicCalendarVersion > localCalendarVersion) {
        // Buluttan yeni takvim verisini çek ve SQLite'a kaydet
        await DatabaseHelper.instance.syncMetadataVersionGuncelle(
          _kCalendarSyncKey,
          cloudManifest.academicCalendarVersion,
        );
        updatedModules.add('MEB Akademik Takvimi');
      }

      // B. Müfredat Kazanımları Kontrolü
      if (force || cloudManifest.outcomesVersion > localOutcomesVersion) {
        await DatabaseHelper.instance.syncMetadataVersionGuncelle(
          _kOutcomesSyncKey,
          cloudManifest.outcomesVersion,
        );
        updatedModules.add('Müfredat Kazanımları');
      }

      return SyncResult(
        success: true,
        hasUpdates: updatedModules.isNotEmpty,
        updatedModules: updatedModules,
        message: updatedModules.isNotEmpty
            ? '${updatedModules.join(', ')} başarıyla güncellendi 🚀'
            : 'Verileriniz zaten güncel (v$localCalendarVersion) ✨',
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (SyncService.checkAndSyncData) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------');
      return SyncResult(
        success: false,
        hasUpdates: false,
        message: 'Senkronizasyon sırasında hata oluştu: $e',
      );
    }
  }
}

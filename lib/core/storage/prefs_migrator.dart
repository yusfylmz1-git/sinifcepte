import 'package:flutter/foundation.dart';
import 'prefs_keys.dart';
import 'prefs_service.dart';

/// Eski prefs listelerini kanonik anahtara birleştirir (yinelenen id düşülür).
class PrefsMigrator {
  PrefsMigrator._();

  static final Set<String> _done = <String>{};

  @visibleForTesting
  static void resetForTest() {
    _done.clear();
  }

  static Future<void> migrateParentStores() async {
    await mergeStringLists(
      canonicalKey: PrefsKeys.parentLinks,
      legacyKeys: [PrefsKeys.parentLinksLegacy],
    );
    await mergeStringLists(
      canonicalKey: PrefsKeys.parentTokens,
      legacyKeys: [PrefsKeys.parentTokensLegacy],
    );
    await mergeStringLists(
      canonicalKey: PrefsKeys.auditLogs,
      legacyKeys: [PrefsKeys.auditLogsLegacy],
    );
  }

  static Future<void> mergeStringLists({
    required String canonicalKey,
    required List<String> legacyKeys,
  }) async {
    final stamp = '$canonicalKey|${legacyKeys.join(',')}';
    if (_done.contains(stamp)) return;
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) {
        // Depoya erişilemedi: göç atlanır, uygulama varsayılanla devam eder.
        // Bir sonraki açılışta yeniden denenir.
        return;
      }
      final merged = <String>[];
      final seen = <String>{};

      void absorb(List<String> raw) {
        for (final item in raw) {
          if (seen.add(item)) merged.add(item);
        }
      }

      final current = prefs.getStringList(canonicalKey) ?? const <String>[];
      absorb(current);

      var hadLegacy = false;
      for (final key in legacyKeys) {
        final legacy = prefs.getStringList(key);
        if (legacy != null && legacy.isNotEmpty) {
          hadLegacy = true;
          absorb(legacy);
        }
      }

      // Devralınacak eski veri yoksa YAZMA YAPMA.
      //
      // Önceden her çağrıda tüm liste diske yeniden yazılıyordu. Liste
      // büyüdükçe (her kod üretimi bir kayıt ekliyordu) bu yazma
      // yavaşlıyor ve ekran açılışını kilitliyordu. Göç yalnızca gerçekten
      // taşınacak veri varsa çalışmalıdır.
      if (!hadLegacy && merged.length == current.length) {
        _done.add(stamp);
        return;
      }

      await prefs.setStringList(canonicalKey, merged);
      for (final key in legacyKeys) {
        await prefs.remove(key);
      }
      _done.add(stamp);
    } catch (e, stackTrace) {
      debugPrint('PrefsMigrator.mergeStringLists hatası: $e\n$stackTrace');
    }
  }
}

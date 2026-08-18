import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prefs_keys.dart';

/// Eski prefs listelerini kanonik anahtara birleştirir (yinelenen id düşülür).
class PrefsMigrator {
  PrefsMigrator._();

  static final Set<String> _done = <String>{};

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
    debugPrint('IZLEME M1: merge basladi ($canonicalKey)');
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('IZLEME M2: merge prefs alindi ($canonicalKey)');
      final merged = <String>[];
      final seen = <String>{};

      void absorb(List<String> raw) {
        for (final item in raw) {
          if (seen.add(item)) merged.add(item);
        }
      }

      absorb(prefs.getStringList(canonicalKey) ?? const []);
      for (final key in legacyKeys) {
        absorb(prefs.getStringList(key) ?? const []);
      }

      await prefs.setStringList(canonicalKey, merged);
      for (final key in legacyKeys) {
        await prefs.remove(key);
      }
      _done.add(stamp);
      debugPrint('IZLEME M3: merge bitti ($canonicalKey)');
    } catch (e, stackTrace) {
      debugPrint('PrefsMigrator.mergeStringLists hatası: $e\n$stackTrace');
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/cloud/firestore_client.dart';
import '../../../../core/storage/prefs_keys.dart';
import '../../../../core/storage/prefs_service.dart';
import '../models/school_model.dart';
import '../models/school_types.dart';
import '../utils/normalized_levenshtein.dart';
import '../../../../core/utils/gzip_asset.dart';

/// İl bazlı gzip shard yükler. 55k okul RAM'e alınmaz; aynı anda tek il tutulur.
class SchoolRepository {
  List<Map<String, dynamic>>? _cachedProvinces;
  Map<String, String> _cityNameToCode = {};
  List<SchoolModel> _loadedProvinceSchools = [];
  String? _loadedCityCode;
  int _loadGen = 0;
  Map<String, dynamic>? _manifest;

  static const String _manifestAsset = 'assets/data/schools/schools_manifest.json';

  /// Türkçe karakter duyarlı normalizasyon
  static String normalizeTr(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ş', 's')
        .replaceAll('ş', 's')
        .replaceAll('Ö', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('Ç', 'c')
        .replaceAll('ç', 'c')
        .toLowerCase()
        .replaceAll('\u0307', '')
        .trim();
  }

  Future<List<Map<String, dynamic>>> getProvinces() async {
    if (_cachedProvinces != null) return _cachedProvinces!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/provinces_districts.json');
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        _cachedProvinces = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _cityNameToCode = {
          for (final p in _cachedProvinces!)
            normalizeTr(p['name']?.toString() ?? ''): p['code']?.toString().padLeft(2, '0') ?? '',
        };
        return _cachedProvinces!;
      }
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository getProvinces hatası: $e\n$stackTrace');
    }
    return [];
  }

  Future<String?> cityCodeForName(String cityName) async {
    await getProvinces();
    final code = _cityNameToCode[normalizeTr(cityName)];
    if (code == null || code.isEmpty) return null;
    return code;
  }

  Future<List<String>> getDistricts(String cityName) async {
    try {
      final provinces = await getProvinces();
      final normCity = normalizeTr(cityName);
      final province = provinces.firstWhere(
        (p) => normalizeTr(p['name']?.toString() ?? '') == normCity,
        orElse: () => {},
      );
      if (province.containsKey('districts') && province['districts'] is List) {
        return List<String>.from(province['districts'] as List);
      }
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository getDistricts hatası: $e\n$stackTrace');
    }
    return [];
  }

  Future<Map<String, dynamic>?> loadManifest() async {
    if (_manifest != null) return _manifest;
    try {
      final raw = await GzipAsset.loadString(_manifestAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _manifest = decoded;
        return _manifest;
      }
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository loadManifest hatası: $e\n$stackTrace');
    }
    return null;
  }

  Future<void> ensureProvinceLoaded(String cityName) async {
    final code = await cityCodeForName(cityName);
    if (code == null) {
      _loadedProvinceSchools = [];
      _loadedCityCode = null;
      return;
    }
    if (_loadedCityCode == code && _loadedProvinceSchools.isNotEmpty) return;

    final gen = ++_loadGen;
    final schools = await _decodeShard(code);
    if (gen != _loadGen) return;
    _loadedCityCode = code;
    _loadedProvinceSchools = schools;
  }

  Future<List<SchoolModel>> _decodeShard(String cityCode) async {
    final candidates = <String>[
      'assets/data/schools/tr_$cityCode.json',
    ];

    for (final asset in candidates) {
      try {
        final jsonStr = await GzipAsset.loadString(asset);
        final decoded = jsonDecode(jsonStr);
        final list = <SchoolModel>[];
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final school = SchoolModel.fromShardMap(Map<String, dynamic>.from(item));
              if (school.status == 'active') list.add(school);
            }
          }
        } else if (decoded is Map && decoded['schools'] is List) {
          for (final item in decoded['schools'] as List) {
            if (item is Map) {
              final school = SchoolModel.fromShardMap(Map<String, dynamic>.from(item));
              if (school.status == 'active') list.add(school);
            }
          }
        }
        return list;
      } catch (e) {
        debugPrint('SchoolRepository shard $asset okunamadı: $e');
      }
    }
    return [];
  }

  /// Okulu kimliğinden bulur.
  ///
  /// Profilde yalnızca `schoolId` ve şehir saklanıyor olabilir; okul ADI
  /// eski kayıtlarda boş kalmış. Kurulum ekranı adı buradan tamamlar,
  /// aksi hâlde öğretmen okulunu yeniden seçmek zorunda kalır.
  Future<SchoolModel?> findById({
    required String schoolId,
    required String city,
  }) async {
    if (schoolId.isEmpty || city.isEmpty) return null;
    try {
      await ensureProvinceLoaded(city);
      for (final sch in _loadedProvinceSchools) {
        if (sch.id == schoolId) return sch;
      }
    } catch (e, stackTrace) {
      debugPrint('findById hatası: $e\n$stackTrace');
    }
    return null;
  }

  Future<List<SchoolModel>> searchSchools({
    required String city,
    String? district,
    String? query,
    String? schoolType,
  }) async {
    try {
      if (city.isEmpty) return [];
      await ensureProvinceLoaded(city);

      final normDistrict = district != null && district.isNotEmpty ? normalizeTr(district) : null;
      final normQuery = query != null && query.trim().isNotEmpty ? normalizeTr(query) : null;

      final results = _loadedProvinceSchools.where((sch) {
        if (normDistrict != null && normalizeTr(sch.district) != normDistrict) return false;
        if (schoolType != null && schoolType.isNotEmpty && schoolType != SchoolTypes.allFilter && sch.type != schoolType) {
          return false;
        }
        if (normQuery != null) {
          final nameNorm = normalizeTr(sch.name);
          final distNorm = normalizeTr(sch.district);
          if (!nameNorm.contains(normQuery) && !distNorm.contains(normQuery)) {
            return false;
          }
        }
        return true;
      }).toList();

      results.sort((a, b) => a.name.compareTo(b.name));
      return results;
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository searchSchools hatası: $e\n$stackTrace');
      return [];
    }
  }

  List<SchoolModel> suggestSimilar(String name, {int limit = 3}) {
    final scored = _loadedProvinceSchools
        .map((s) => MapEntry(s, NormalizedLevenshtein.score(name, s.name)))
        .where((e) => e.value >= 0.85)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Manuel ekleme: onay kuyruğuna pending_ id. Şablon okul üretilmez.
  Future<SchoolModel?> addCustomSchool({
    required String name,
    required String city,
    required String district,
    required String type,
  }) async {
    try {
      final cleanName = name.trim();
      final cleanCity = city.trim();
      final cleanDistrict = district.trim();
      if (cleanName.isEmpty || cleanCity.isEmpty || cleanDistrict.isEmpty) return null;

      final cityCode = await cityCodeForName(cleanCity) ?? '';
      final pending = SchoolModel(
        id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        city: cleanCity,
        cityCode: cityCode,
        district: cleanDistrict,
        type: type.isNotEmpty ? type : 'Diğer',
        isCustom: true,
        status: 'pending_review',
        source: 'manuel_onayli',
      );

      final prefs = await PrefsService.instance();
      final raw = prefs?.getStringList(PrefsKeys.pendingSchoolSubmissions) ?? [];
      raw.add(jsonEncode(pending.toMap()));
      if (prefs != null) {
        await prefs.setStringList(PrefsKeys.pendingSchoolSubmissions, raw);
      }

      // Öneriyi onay kuyruğuna da gönder: yalnızca yerelde kalırsa okul
      // dizinine hiçbir zaman eklenmez ve aynı okulu ekleyen her öğretmen
      // ayrı bir kayıt oluşturmaya devam eder.
      //
      // Başarısız olması akışı bozmaz: öğretmen okulunu yerelde seçip
      // çalışmaya devam eder (offline-first).
      unawaited(_submitToMergeQueue(pending));

      return pending;
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository addCustomSchool hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Kullanıcı önerisini bulut onay kuyruğuna yazar.
  ///
  /// Kuyruğu yalnızca moderatörler okur (`firestore.rules`); istemci
  /// yazdıktan sonra kaydı ne okuyabilir ne değiştirebilir.
  Future<void> _submitToMergeQueue(SchoolModel pending) async {
    try {
      await FirestoreClient.instance.ensureConfigured();
      if (!FirestoreClient.instance.isReady) return;

      await FirestoreClient.instance.setDoc(
        'school_merge_queue/${pending.id}',
        {
          'name': pending.name,
          'city': pending.city,
          'cityCode': pending.cityCode,
          'district': pending.district,
          'type': pending.type,
          'status': 'pending_review',
          'source': 'manuel_onayli',
          'submittedAt': DateTime.now().toIso8601String(),
        },
        merge: false,
      );
    } catch (e, stackTrace) {
      debugPrint('Okul önerisi kuyruğa gönderilemedi: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<List<SchoolModel>> getCustomSchools() async {
    try {
      final prefs = await PrefsService.instance();
      final raw = prefs?.getStringList(PrefsKeys.pendingSchoolSubmissions) ?? [];
      final list = <SchoolModel>[];
      for (final item in raw) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map) {
            list.add(SchoolModel.fromMap(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {}
      }
      return list;
    } catch (e, stackTrace) {
      debugPrint('SchoolRepository getCustomSchools hatası: $e\n$stackTrace');
      return [];
    }
  }
}

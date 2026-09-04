import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/gzip_asset.dart';
import '../models/guidance_plan_model.dart';

/// Sınıf rehberlik planı verisi ve uygulama kaydı.
///
/// ## İki katman
/// * **Plan + etkinlik**: varlıktan gelir, salt okunur, bellekte
///   önbelleklenir. Öğretim yılı değişince paket yenilenir.
/// * **Uygulama kaydı**: öğretmene ait, SQLite'ta durur.
///
/// Varlık ~500 KB sıkıştırılmış / ~2 MB açık. Her ekran açılışında
/// yeniden ayrıştırmak ana iş parçacığını kilitlerdi; bir kez okunup
/// bellekte tutulur.
class GuidancePlanRepository {
  static const _varlik = 'assets/data/sinif_rehberlik_plani.json';

  static List<GuidancePlanItem>? _plan;
  static List<GuidanceActivity>? _etkinlik;
  static List<SpecialEducationActivity>? _ozelEgitim;
  static Future<void>? _yukleniyor;

  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Varlığı bir kez okur.
  ///
  /// Eşzamanlı iki çağrı gelirse ikisi de aynı Future'ı bekler;
  /// aksi hâlde 2 MB'lık JSON iki kez ayrıştırılırdı.
  Future<void> _hazirla() async {
    if (_plan != null && _etkinlik != null && _ozelEgitim != null) return;
    _yukleniyor ??= _oku();
    await _yukleniyor;
  }

  Future<void> _oku() async {
    try {
      final ham = await GzipAsset.loadString(_varlik);
      final j = jsonDecode(ham) as Map<String, dynamic>;
      _plan = (j['plan'] as List? ?? [])
          .map((e) => GuidancePlanItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _etkinlik = (j['etkinlikler'] as List? ?? [])
          .map((e) => GuidanceActivity.fromJson(e as Map<String, dynamic>))
          .toList();
      _ozelEgitim = (j['ozelEgitim'] as List? ?? [])
          .map((e) =>
              SpecialEducationActivity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Varlık okunamazsa modül boş görünür; uygulama çökmemeli.
      debugPrint('GuidancePlanRepository: varlık okunamadı ($e)');
      _plan = const [];
      _etkinlik = const [];
      _ozelEgitim = const [];
    } finally {
      _yukleniyor = null;
    }
  }

  /// Bir kademenin plan satırları, hafta sırasıyla.
  Future<List<GuidancePlanItem>> planFor(int gradeLevel) async {
    await _hazirla();
    final liste = _plan!.where((e) => e.gradeLevel == gradeLevel).toList();
    // Plandaki GERCEK sira korunur: once ay, sonra Excel satiri.
    //
    // Yalnizca `hafta` ile siralamak tatilleri listenin sonuna
    // atiyordu (hafta numaralari yok), oysa ara tatil Kasim'da,
    // yariyil Ocak'ta olmali.
    liste.sort((a, b) {
      if (a.ayIndex != b.ayIndex) return a.ayIndex.compareTo(b.ayIndex);
      return a.satirIndex.compareTo(b.satirIndex);
    });
    return liste;
  }

  /// Kademe + hafta için etkinlik.
  Future<GuidanceActivity?> activityFor({
    required int gradeLevel,
    required int hafta,
  }) async {
    await _hazirla();
    for (final e in _etkinlik!) {
      if (e.gradeLevel == gradeLevel && e.hafta == hafta) return e;
    }
    return null;
  }

  /// Bir kademenin bütün etkinlikleri.
  Future<List<GuidanceActivity>> activitiesFor(int gradeLevel) async {
    await _hazirla();
    final liste =
        _etkinlik!.where((e) => e.gradeLevel == gradeLevel).toList();
    liste.sort((a, b) => (a.hafta ?? 99).compareTo(b.hafta ?? 99));
    return liste;
  }

  /// Kademe verisi var mı? Yoksa ekranda "plan bulunamadı" gösterilir.
  Future<bool> hasPlan(int gradeLevel) async {
    await _hazirla();
    return _plan!.any((e) => e.gradeLevel == gradeLevel);
  }

  /// Özel eğitim programının etkinlikleri.
  ///
  /// [programKodu]: ozelAnaokulu / ozelIlkokul / ozelOrtaokul /
  /// ozelMeslek.
  Future<List<SpecialEducationActivity>> specialActivities(
      String programKodu) async {
    await _hazirla();
    final liste =
        _ozelEgitim!.where((e) => e.programKodu == programKodu).toList();
    liste.sort((a, b) => (a.etkinlikNo ?? 99).compareTo(b.etkinlikNo ?? 99));
    return liste;
  }

  /// Elimizdeki özel eğitim programları.
  Future<List<({String kod, String ad, int adet})>> specialPrograms() async {
    await _hazirla();
    final sayac = <String, ({String ad, int adet})>{};
    for (final e in _ozelEgitim!) {
      final v = sayac[e.programKodu];
      sayac[e.programKodu] =
          (ad: e.programAdi, adet: (v?.adet ?? 0) + 1);
    }
    return sayac.entries
        .map((e) => (kod: e.key, ad: e.value.ad, adet: e.value.adet))
        .toList();
  }

  /// BEP'li öğrenci için o haftanın uyarlama önerileri.
  ///
  /// ## Neden burada
  /// Her ORGM etkinliğinde "Özel gereksinimli öğrenciler için"
  /// bölümü var (458 etkinliğin 334'ünde dolu) ama bu metin PDF'in
  /// içinde gömülü kalıyordu. BEP planı olan öğretmen, haftanın
  /// rehberlik etkinliğini BEP'li öğrencisine nasıl uyarlayacağını
  /// buradan görür.
  Future<List<String>> bepAdaptationsFor({
    required int gradeLevel,
    required int hafta,
  }) async {
    final e = await activityFor(gradeLevel: gradeLevel, hafta: hafta);
    return e?.ozelGereksinimUyarlamalari ?? const [];
  }

  // ------------------------------------------------------- uygulama kaydı

  Future<List<GuidanceLogEntry>> logsFor({
    required int classId,
    required String academicYear,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'guidance_logs',
      where: 'class_id = ? AND academic_year = ?',
      whereArgs: [classId, academicYear],
    );
    return rows.map(GuidanceLogEntry.fromMap).toList();
  }

  /// Uygulama işaretini kaydeder.
  ///
  /// `class_id + academic_year + hafta + sira_no` tektir; aynı satır
  /// iki kez işaretlenirse üzerine yazılır.
  Future<void> saveLog(GuidanceLogEntry kayit) async {
    final db = await _db.database;
    await db.insert(
      'guidance_logs',
      kayit.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Birden çok kaydı TEK işlemde yazar.
  ///
  /// "Tümünü uygulandı işaretle" 36 kazanım için 36 ayrı `insert`
  /// demek; her biri ayrı disk işlemi olduğu için arayüz donuyor.
  /// Toplu yazma bunu tek harekete indirir.
  Future<void> saveLogs(List<GuidanceLogEntry> kayitlar) async {
    if (kayitlar.isEmpty) return;
    final db = await _db.database;
    final toplu = db.batch();
    for (final k in kayitlar) {
      toplu.insert(
        'guidance_logs',
        k.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await toplu.commit(noResult: true);
  }

  /// "36 haftanın 31'i uygulandı" özeti için.
  Future<({int uygulanan, int toplam})> progress({
    required int classId,
    required String academicYear,
    required int gradeLevel,
  }) async {
    final plan = await planFor(gradeLevel);
    final toplam = plan.where((e) => e.uygulanabilir).length;
    final kayitlar = await logsFor(classId: classId, academicYear: academicYear);
    final uygulanan = kayitlar.where((e) => e.uygulandi).length;
    return (uygulanan: uygulanan, toplam: toplam);
  }

  /// Testler için önbelleği boşaltır.
  @visibleForTesting
  static void resetCache() {
    _plan = null;
    _etkinlik = null;
    _ozelEgitim = null;
    _yukleniyor = null;
  }
}

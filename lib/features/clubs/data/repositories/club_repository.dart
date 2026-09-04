import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/gzip_asset.dart';
import '../models/club_model.dart';

/// Sosyal kulüp verisi: hazır katalog + öğretmenin kurduğu kulüpler.
///
/// ## İki katman
/// * **Katalog**: `assets/data/kulup_planlari.json.gz`, salt okunur,
///   bellekte önbelleklenir. 52 kulübün hazır yıllık planı.
/// * **Kulüp, üye, faaliyet**: öğretmene ait, SQLite'ta durur.
///
/// Katalog sıkıştırılmış 29 KB / açık 150 KB. Rehberlik paketinden
/// çok küçük ama aynı yol izlenir: bir kez okunup bellekte tutulur.
class ClubRepository {
  static const _varlik = 'assets/data/kulup_planlari.json';

  static List<ClubCatalogItem>? _katalog;
  static Future<void>? _yukleniyor;

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------
  // Katalog
  // ------------------------------------------------------------------

  Future<void> _hazirla() async {
    if (_katalog != null) return;
    _yukleniyor ??= _oku();
    await _yukleniyor;
  }

  Future<void> _oku() async {
    try {
      final ham = await GzipAsset.loadString(_varlik);
      final j = jsonDecode(ham) as Map<String, dynamic>;
      _katalog = (j['kulupler'] as List? ?? [])
          .map((e) => ClubCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Varlık okunamazsa katalog boş görünür; öğretmen yine de kendi
      // kulübünü elle kurabilir, uygulama çökmemeli.
      debugPrint('ClubRepository: varlık okunamadı ($e)');
      _katalog = const [];
    } finally {
      _yukleniyor = null;
    }
  }

  /// EK-4 çizelgesindeki 52 kulüp, sıra numarasıyla.
  Future<List<ClubCatalogItem>> katalog() async {
    await _hazirla();
    return List.unmodifiable(_katalog!);
  }

  /// Koda göre katalog kaydı. Okulun kendi kurduğu kulüpte null döner.
  Future<ClubCatalogItem?> katalogKaydi(String kod) async {
    if (kod.isEmpty) return null;
    await _hazirla();
    for (final k in _katalog!) {
      if (k.kod == kod) return k;
    }
    return null;
  }

  /// Kulübün yürürlükteki planı: katalog + öğretmenin düzenlemeleri.
  ///
  /// Düzenlenmemiş aylar katalogdan gelir; böylece paket güncellenince
  /// öğretmenin dokunmadığı aylar yeni içeriği alır.
  Future<List<ClubPlanRow>> plan(ClubModel kulup) async {
    final katalogItem = await katalogKaydi(kulup.catalogCode);
    final temel = katalogItem?.plan ??
        // Katalog dışı kulüpte hazır metin yok; boş iskelet verilir ki
        // öğretmen kendi planını yazabilsin.
        _aylar.map((a) => ClubPlanRow(ay: a, amac: '', etkinlik: '')).toList();

    return temel
        .map((satir) => kulup.planDuzenlemeleri[satir.ay] ?? satir)
        .toList();
  }

  static const _aylar = [
    'Eylül', 'Ekim', 'Kasım', 'Aralık', 'Ocak',
    'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  ];

  /// Öğretim yılının ay listesi — plan ve rapor ekranları bunu kullanır.
  static List<String> get aylar => List.unmodifiable(_aylar);

  // ------------------------------------------------------------------
  // Kulüpler
  // ------------------------------------------------------------------

  /// Bir öğretim yılının kulüpleri. Yıl boşsa hepsi döner.
  Future<List<ClubModel>> kulupler({String? ogretimYili}) async {
    final db = await _db.database;
    final satir = await db.query(
      'clubs',
      where: ogretimYili == null ? null : 'ogretim_yili = ?',
      whereArgs: ogretimYili == null ? null : [ogretimYili],
      orderBy: 'ad COLLATE NOCASE ASC',
    );
    return satir.map(ClubModel.fromMap).toList();
  }

  Future<ClubModel?> kulup(int id) async {
    final db = await _db.database;
    final satir = await db.query('clubs', where: 'id = ?', whereArgs: [id]);
    if (satir.isEmpty) return null;
    return ClubModel.fromMap(satir.first);
  }

  Future<int> kulupEkle(ClubModel kulup) async {
    final db = await _db.database;
    return db.insert('clubs', kulup.toMap());
  }

  Future<void> kulupGuncelle(ClubModel kulup) async {
    if (kulup.id == null) return;
    final db = await _db.database;
    await db.update('clubs', kulup.toMap(),
        where: 'id = ?', whereArgs: [kulup.id]);
  }

  /// Kulübü siler. Üyeler ve faaliyet kayıtları ON DELETE CASCADE ile
  /// birlikte gider.
  Future<void> kulupSil(int id) async {
    final db = await _db.database;
    await db.delete('clubs', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Üyeler
  // ------------------------------------------------------------------

  /// Kulübün üyeleri: önce sınıf, sonra okul numarası sırasıyla.
  ///
  /// Numarasız öğrenci (okulNo = 0) listenin sonuna düşer; aksi hâlde
  /// numarası girilmemiş kayıtlar başa toplanırdı.
  Future<List<ClubMember>> uyeler(int clubId) async {
    final db = await _db.database;
    final satir = await db.query(
      'club_members',
      where: 'club_id = ?',
      whereArgs: [clubId],
      orderBy: 'sinif_adi COLLATE NOCASE ASC, '
          'CASE WHEN okul_no > 0 THEN 0 ELSE 1 END ASC, '
          'okul_no ASC, ad_soyad COLLATE NOCASE ASC',
    );
    return satir.map(ClubMember.fromMap).toList();
  }

  /// Öğrencinin bu öğretim yılında üye olduğu kulüpler.
  ///
  /// MADDE 8/4 en az bir üyelik ister; öğretmen bu sorguyla kimin
  /// hiçbir kulübe yazılmadığını görebilir.
  Future<List<ClubModel>> ogrencininKulupleri(
    int studentId,
    String ogretimYili,
  ) async {
    final db = await _db.database;
    final satir = await db.rawQuery(
      '''
      SELECT c.* FROM clubs c
      INNER JOIN club_members m ON m.club_id = c.id
      WHERE m.student_id = ? AND c.ogretim_yili = ?
      ORDER BY c.ad COLLATE NOCASE ASC
      ''',
      [studentId, ogretimYili],
    );
    return satir.map(ClubModel.fromMap).toList();
  }

  /// Bu öğretim yılında hiçbir kulübe üye olmayan öğrenciler.
  ///
  /// MADDE 8/4 her öğrencinin en az bir kulübe üyeliğini zorunlu kılıyor.
  /// Öğretmen kimin açıkta kaldığını tek bakışta görebilsin diye sorgu
  /// SQL'de çözülüyor; sınıf sınıf dolaşmak 30 ayrı okuma demekti.
  ///
  /// Dönen her satır: `id`, `ad_soyad`, `okul_no`, `sinif_adi`.
  Future<List<Map<String, Object?>>> kulupsuzOgrenciler(
    String ogretimYili,
  ) async {
    final db = await _db.database;
    return db.rawQuery(
      '''
      SELECT s.id AS id,
             s.first_name || ' ' || s.last_name AS ad_soyad,
             s.school_number AS okul_no,
             c.name AS sinif_adi
      FROM students s
      INNER JOIN classes c ON c.id = s.class_id
      WHERE NOT EXISTS (
        SELECT 1 FROM club_members m
        INNER JOIN clubs k ON k.id = m.club_id
        WHERE m.student_id = s.id AND k.ogretim_yili = ?
      )
      ORDER BY c.name COLLATE NOCASE ASC,
               CASE WHEN s.school_number > 0 THEN 0 ELSE 1 END ASC,
               s.school_number ASC
      ''',
      [ogretimYili],
    );
  }

  Future<int> uyeEkle(ClubMember uye) async {
    final db = await _db.database;
    return db.insert('club_members', uye.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Birden çok öğrenciyi tek işlemde ekler.
  ///
  /// Sınıf listesinden toplu seçim yapılınca 30 ayrı yazma yerine tek
  /// toplu iş çalışır.
  Future<void> uyeEkleToplu(List<ClubMember> uyeler) async {
    if (uyeler.isEmpty) return;
    final db = await _db.database;
    final toplu = db.batch();
    for (final u in uyeler) {
      toplu.insert('club_members', u.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await toplu.commit(noResult: true);
  }

  Future<void> uyeGuncelle(ClubMember uye) async {
    if (uye.id == null) return;
    final db = await _db.database;
    await db.update('club_members', uye.toMap(),
        where: 'id = ?', whereArgs: [uye.id]);
  }

  Future<void> uyeSil(int id) async {
    final db = await _db.database;
    await db.delete('club_members', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------
  // Faaliyet kaydı
  // ------------------------------------------------------------------

  /// Kulübün ay ay faaliyet kayıtları, öğretim yılı sırasıyla.
  ///
  /// Kaydı olmayan aylar da boş olarak döner; rapor ekranı 10 satırı
  /// birden gösterebilsin diye.
  Future<List<ClubActivityLog>> faaliyetler(int clubId) async {
    final db = await _db.database;
    final satir = await db.query('club_activity_logs',
        where: 'club_id = ?', whereArgs: [clubId]);
    final kayitli = {
      for (final s in satir)
        (s['ay'] as String? ?? ''): ClubActivityLog.fromMap(s)
    };
    return _aylar
        .map((a) => kayitli[a] ?? ClubActivityLog(clubId: clubId, ay: a))
        .toList();
  }

  /// Bir ayın faaliyet kaydını yazar; yoksa oluşturur.
  Future<void> faaliyetKaydet(ClubActivityLog kayit) async {
    final db = await _db.database;
    await db.insert(
      'club_activity_logs',
      kayit.toMap(),
      // (club_id, ay) benzersiz; aynı ay ikinci kez yazılınca üzerine
      // yazılsın diye replace kullanılıyor.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Test ve varlık yenilemesi için önbelleği düşürür.
  @visibleForTesting
  static void onbellegiTemizle() {
    _katalog = null;
    _yukleniyor = null;
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart';
import '../storage/prefs_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../config/app_config.dart';
import '../../features/outcomes/data/models/curriculum_outcome_model.dart';
import '../utils/gzip_asset.dart';
import '../utils/name_formatter.dart';

/// SınıfCepte - SQLite Veritabanı Yardımcısı (DatabaseHelper)
class DatabaseHelper {
  /// Eski tek-veritabanı göçünün yapıldığını işaretler (tek seferlik).
  static const String _kLegacyMigratedKey = 'sinifcepte_legacy_db_migrated';

  /// Bu cihazda en son giriş yapan hesabın kimliği.
  static const String _kLastUidKey = 'sinifcepte_last_teacher_uid';

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _openUid;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConfig.dbName);
    return _database!;
  }

  /// Google uid başına ayrı SQLite veritabanı açar.
  ///
  /// ## Veri sahipliği (Karar: 18 Ağustos 2026 — Seçenek A)
  /// Öğrenci, sınıf ve not verileri **öğretmenin cihazında ve hesabında**
  /// kalır; buluta çıkmaz. Her Google hesabı kendi veritabanı dosyasına
  /// sahiptir. Bu, KVKK yükünü en aza indirir: uygulama sahibi öğrenci
  /// kimlik verisinin sorumlusu olmaz.
  ///
  /// Sonucu: aynı cihazda ikinci bir hesapla giriş yapmak **boş bir
  /// çalışma alanı** açar. Bu bir hata değil, bilinçli tasarımdır — ama
  /// kullanıcıya açıkça gösterilmelidir (bkz. [lastKnownUid]).
  ///
  /// ## Eski sürüm göçü — neden yalnızca BİR kez
  /// Eski sürümlerde tek ortak veritabanı vardı. İlk giriş yapan hesap
  /// onu devralır. Önceden bu göç her yeni hesap için tekrar deneniyordu:
  /// ikinci hesap da aynı eski dosyayı kopyalayınca iki hesabın verisi
  /// karışıyor ve kullanıcı "öğrencilerim kayboldu, başka sınıflar geldi"
  /// durumuyla karşılaşıyordu. Artık göç tek seferlik olarak işaretlenir.
  Future<void> openForUid(String uid) async {
    if (_openUid == uid && _database != null) return;
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _openUid = uid;

    final dbPath = await getDatabasesPath();
    final targetName = AppConfig.teacherDbName(uid);
    final targetPath = join(dbPath, targetName);
    final target = File(targetPath);

    if (!await target.exists()) {
      await _migrateLegacyOnce(dbPath, targetPath);
    }

    _database = await _initDB(targetName);
    await _rememberUid(uid);
  }

  /// Eski tek-veritabanı düzeninden göç. Yalnızca bir kez çalışır.
  ///
  /// Göç yapıldığında bir bayrak yazılır; sonraki hesaplar boş
  /// veritabanıyla başlar. Bayrak olmasaydı her yeni hesap aynı eski
  /// veriyi devralır ve hesaplar arası veri karışması sürerdi.
  Future<void> _migrateLegacyOnce(String dbPath, String targetPath) async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null || (prefs.getBool(_kLegacyMigratedKey) ?? false)) return;

      for (final legacyName in <String>[
        'sinifcepte.db',
        AppConfig.dbName,
        'sinifcepte_dev.db',
      ]) {
        final legacy = File(join(dbPath, legacyName));
        if (!await legacy.exists()) continue;

        await legacy.copy(targetPath);
        await legacy.rename(join(dbPath, '$legacyName.migrated'));
        await prefs.setBool(_kLegacyMigratedKey, true);
        debugPrint('Eski veritabanı devralındı: $legacyName');
        return;
      }

      // Devralınacak eski dosya yok; yine de işaretle ki bir daha aranmasın.
      await prefs.setBool(_kLegacyMigratedKey, true);
    } catch (e, stackTrace) {
      debugPrint('Eski veritabanı göçü başarısız: $e');
      debugPrint('$stackTrace');
    }
  }

  /// Son giriş yapılan hesabı hatırlar.
  ///
  /// Kullanıcı hesap değiştirdiğinde arayüz bunu fark edip
  /// "bu hesabın çalışma alanı ayrıdır" uyarısı gösterebilir.
  Future<void> _rememberUid(String uid) async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs != null) {
        await prefs.setString(_kLastUidKey, uid);
      }
    } catch (e, stackTrace) {
      debugPrint('Son hesap kimliği kaydedilemedi: $e');
      debugPrint('$stackTrace');
    }
  }

  /// Bu cihazda en son hangi hesapla çalışıldı? (yoksa boş)
  static Future<String> lastKnownUid() async {
    try {
      final prefs = await PrefsService.instance();
      return prefs?.getString(_kLastUidKey) ?? '';
    } catch (e, stackTrace) {
      debugPrint('Son hesap kimliği okunamadı: $e');
      debugPrint('$stackTrace');
      return '';
    }
  }

  /// Bu cihazda daha önce başka bir hesapla çalışılmış mı?
  ///
  /// `true` dönerse kullanıcıya "her hesabın verisi ayrıdır" bilgisi
  /// gösterilmelidir — sessizce boş liste göstermek kafa karıştırır.
  static Future<bool> isDifferentAccountThanLast(String uid) async {
    final last = await lastKnownUid();
    return last.isNotEmpty && last != uid;
  }

  Future<Database> _initDB(String filePath) async {
    // Windows / Linux / macOS masaüstü platformlarında FFI kullanımı
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 25,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
      onOpen: _onOpen,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Yabancı Anahtar (Foreign Key) kısıtlamalarını etkinleştir
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  Future<void> _onOpen(Database db) async {
    await _ensureParticipationTablesExist(db);
    await _ensureCloudIds(db);
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    // 1. Sınıflar Tablosu (classes)
    await db.execute('''
      CREATE TABLE classes (
        id $idType,
        name $textType,
        subject $textType,
        academic_year $textType,
        description $textNullable,
        is_homeroom $intType DEFAULT 0
      )
    ''');

    // 2. Öğrenciler Tablosu (students)
    await db.execute('''
      CREATE TABLE students (
        id $idType,
        class_id $intType,
        school_number $intType,
        first_name $textType,
        last_name $textType,
        gender $textType DEFAULT 'Erkek',
        parent_name $textNullable,
        parent_phone $textNullable,
        notes $textNullable,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // 3. Ders İçi Katılım Oturumları Tablosu (participation_sessions)
    await db.execute('''
      CREATE TABLE participation_sessions (
        id $idType,
        class_id $intType,
        date $textType,
        lesson_hour $intType,
        subject_name $textNullable,
        topic_name $textNullable,
        note $textNullable,
        created_at $textNullable,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // 4. Ders İçi Katılım Kayıtları Tablosu (participation_records)
    await db.execute('''
      CREATE TABLE participation_records (
        id $idType,
        session_id $intType,
        student_id $intType,
        homework_status $textType DEFAULT 'yapti',
        materials_status $textType DEFAULT 'tam',
        arrival_status $textType DEFAULT 'zamaninda',
        stars_count $intType DEFAULT 0,
        custom_tags $textNullable,
        badge_name $textNullable,
        score $intType DEFAULT 0,
        note $textNullable,
        -- Ders sirasinda kac kez soz aldi. Modulun asil derdi buydu ama
        -- alani yoktu; ogretmen her ogrenci icin diyalog acmak zorundaydi.
        speaking_turns $intType DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES participation_sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    await _ensureCloudIds(db);

    // 4.5. Oturma Planları Tablosu (seating_plans)
    await db.execute('''
      CREATE TABLE seating_plans (
        class_id $intType PRIMARY KEY,
        columns $intType DEFAULT 4,
        rows $intType DEFAULT 6,
        assignments $textNullable,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
      )
    ''');

    // --- ESKİ PROJEDEN (ogretmenim) GELEN TABLOLAR ---
    await _createLegacyTables(db);
  }

  Future<void> _createLegacyTables(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    // 5. DERSLER (ders programı)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dersler (
        id $idType,
        doc_id $textNullable,
        ders_adi $textType,
        sinif $textType,
        gun $textType,
        ders_saati_index $intType,
        renk $intType,
        olusturulma_tarihi $textType
      )
    ''');

    // 6. DEĞERLENDİRME KRİTERLERİ
    await db.execute('''
      CREATE TABLE IF NOT EXISTS degerlendirme_kriterleri (
        id $idType,
        baslik $textType,
        max_puan REAL NOT NULL,
        varsayilan $intType DEFAULT 1
      )
    ''');

    // Sadece tablo boşsa ekle (IF NOT EXISTS kontrol edilemediği için insert or ignore kullanılabilir ama id auto increment. Check if empty)
    final countList = await db.rawQuery('SELECT COUNT(*) as c FROM degerlendirme_kriterleri');
    final count = Sqflite.firstIntValue(countList) ?? 0;
    if (count == 0) {
      await db.execute('''
        INSERT INTO degerlendirme_kriterleri (baslik, max_puan, varsayilan) VALUES 
        ('Derse Hazırlık (Araç-Gereç)', 20.0, 1),
        ('Derse Katılım / Etkinlik', 20.0, 1),
        ('Ödev / Sorumluluk', 20.0, 1),
        ('Ders İçi Tutum / Davranış', 20.0, 1),
        ('Konuyu Kavrama', 20.0, 1)
      ''');
    }

    // 7. ANA DEĞERLENDİRME KAYDI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ogrenci_degerlendirmeleri (
        id $idType,
        doc_id $textNullable, 
        ogrenci_id $intType,
        sinif_id $intType,
        ders_adi $textType,
        tarih $textType,
        toplam_puan REAL NOT NULL
      )
    ''');

    // 8. DEĞERLENDİRME DETAYLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS degerlendirme_detaylari (
        id $idType,
        degerlendirme_id $intType,
        kriter_id $intType,
        verilen_puan REAL NOT NULL,
        FOREIGN KEY (degerlendirme_id) REFERENCES ogrenci_degerlendirmeleri (id) ON DELETE CASCADE
      )
    ''');

    // 9. PERFORMANS TABLOSU
    await db.execute('''
      CREATE TABLE IF NOT EXISTS performans (
        id $idType,
        ogrenci_id $intType, 
        tarih $textType,
        kitap $intType DEFAULT 0,
        odev $intType DEFAULT 0,
        yildiz $intType DEFAULT 1,
        puan $intType DEFAULT 0
      )
    ''');

    // 10. SİSTEM AYARLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sistem_ayarlari (
        anahtar TEXT PRIMARY KEY,
        deger TEXT
      )
    ''');

    await db.execute(
      "INSERT OR IGNORE INTO sistem_ayarlari (anahtar, deger) VALUES ('egitim_baslangic', '2025-09-08')"
    );

    // 11. KAZANIMLAR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kazanimlar (
        id $idType,
        sinif $intType,
        brans $textType,
        unite $textType,
        kazanim $textType,
        hafta $intType,
        ders_tipi $textType
      )
    ''');

    // 12. SINAVLAR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sinavlar (
        id $idType,
        sinav_adi $textType,
        sinif $textType,
        ders $textType,
        tarih $textType,
        ortalama REAL,
        not_sayisi INTEGER,
        sinav_tipi TEXT DEFAULT 'klasik',
        soru_sayisi INTEGER DEFAULT 0,
        soru_puanlari TEXT
      )
    ''');

    // 13. SINAV NOTLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sinav_notlari (
        id $idType,
        sinav_id $intType,
        ogrenci_id $intType,
        ogrenci_ad_soyad $textNullable,
        notu INTEGER,
        toplam_not REAL,
        soru_bazli_notlar TEXT,
        FOREIGN KEY (sinav_id) REFERENCES sinavlar (id) ON DELETE CASCADE
      )
    ''');

    // 14. GENEL SINAVLAR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS genel_sinavlar (
        id $idType,
        doc_id $textNullable,
        sinav_adi $textType,
        kurum $textType,
        sinav_tarihi $textType,
        son_basvuru_tarihi $textNullable,
        basvuru_linki $textNullable,
        sinif $textNullable
      )
    ''');

    // 15. FAVORİ SINAVLAR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favori_sinavlar (
        doc_id TEXT PRIMARY KEY
      )
    ''');

    // 16. KİŞİSEL SINAVLAR
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kisisel_sinavlar (
        id $idType,
        doc_id $textNullable,
        sinav_adi $textType,
        kurum $textType,
        sinav_tarihi $textType,
        son_basvuru_tarihi $textNullable,
        basvuru_linki $textNullable
      )
    ''');

    // 17. QUIZ ÇİZELGELERİ
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_cizelgeleri (
        id $idType,
        sinif $textType,
        ders $textType,
        olusturulma_tarihi $textType,
        kategori TEXT NOT NULL DEFAULT 'quiz'
      )
    ''');

    // 18. QUIZ KOLONLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_kolonlari (
        id $idType,
        cizelge_id $intType,
        baslik $textType,
        tip TEXT NOT NULL DEFAULT 'quiz',
        sira INTEGER NOT NULL DEFAULT 0,
        tarih $textType,
        FOREIGN KEY (cizelge_id) REFERENCES quiz_cizelgeleri (id) ON DELETE CASCADE
      )
    ''');

    // 19. QUIZ NOTLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_notlari (
        id $idType,
        kolon_id $intType,
        ogrenci_id $intType,
        puan INTEGER,
        UNIQUE(kolon_id, ogrenci_id),
        FOREIGN KEY (kolon_id) REFERENCES quiz_kolonlari (id) ON DELETE CASCADE
      )
    ''');

    // 20. PROJE TAKİP
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proje_takip (
        id $idType,
        sinif $textType,
        ogrenci_id $intType,
        ogrenci_ad $textType,
        ders $textType,
        odev_konusu $textType,
        olusturulma_tarihi $textType,
        teslim_etti INTEGER NOT NULL DEFAULT 0,
        toplam_puan INTEGER,
        degerlendirildi INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 21. PROJE KRİTERLERİ
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proje_kriterleri (
        id $idType,
        baslik $textType,
        max_puan $intType,
        sira INTEGER NOT NULL DEFAULT 0
      )
    ''');

    final projeSeed = await db.query(
      'sistem_ayarlari',
      where: 'anahtar = ?',
      whereArgs: ['proje_kriter_seed_v2'],
    );
    if (projeSeed.isEmpty) {
      const varsayilanKriterler = [
        'Konunun amaca uygunluğu',
        'Araştırma ve bilgi doğruluğu',
        'Özgünlük ve yaratıcılık',
        'İçeriğin yeterliliği ve kapsamı',
        'Düzen, tertip ve temizlik',
        'Görsel ve materyal kullanımı',
        'Kaynakların doğru kullanımı',
        'Yazım ve dil bilgisi kurallarına uyum',
        'Sunum ve anlatım becerisi',
        'Zamanında teslim',
      ];
      await db.transaction((txn) async {
        await txn.delete('proje_kriterleri');
        for (int i = 0; i < varsayilanKriterler.length; i++) {
          await txn.insert('proje_kriterleri', {
            'baslik': varsayilanKriterler[i],
            'max_puan': 10,
            'sira': i,
          });
        }
        await txn.insert('sistem_ayarlari', {
          'anahtar': 'proje_kriter_seed_v2',
          'deger': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }

    // 22. PROJE PUANLARI
    await db.execute('''
      CREATE TABLE IF NOT EXISTS proje_puanlari (
        id $idType,
        proje_id $intType,
        kriter_id $intType,
        puan $intType,
        UNIQUE(proje_id, kriter_id),
        FOREIGN KEY (proje_id) REFERENCES proje_takip (id) ON DELETE CASCADE
      )
    ''');

    // 23. MEB AKADEMİK TAKVİM VE KAZANIM TABLOLARI
    await _createSyncAndCalendarTables(db);
  }

  Future<void> _createSyncAndCalendarTables(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const intNullable = 'INTEGER';

    // A. MEB Akademik Takvim Olayları Tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS academic_calendar_events (
        id $idType,
        doc_id $textNullable,
        title $textType,
        description $textNullable,
        start_date $textType,
        end_date $textType,
        category $textType,
        academic_year $textType,
        is_official_holiday $intType DEFAULT 0
      )
    ''');

    // B. Müfredat Kazanımları Tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS curriculum_outcomes (
        id $idType,
        doc_id $textNullable,
        grade_level $intType,
        subject_code $textType,
        subject_name $textType,
        publisher $textNullable,
        full_title $textNullable,
        week_number $intType,
        teaching_week_number $intNullable,
        unit_title $textType,
        topic_title $textType,
        outcome_code $textNullable,
        outcome_description $textType,
        category $textNullable,
        academic_year $textType,
        is_holiday_week $intType DEFAULT 0,
        holiday_note $textNullable,
        -- Maarif Modeli icerigi. Bu sutunlar olmadigi icin
        -- `outcome_carousel_card.dart` icindeki "MAARIF DERS OZETI"
        -- panelleri hep bos goruntuleniyordu: veri APK ile tasiniyor,
        -- acilista ayristiriliyor ve atiliyordu.
        outcome_parts $textNullable,
        suggested_activities $textNullable,
        official_activity $textNullable,
        maarif_summary $textNullable,
        maarif_values $textNullable,
        maarif_skills $textNullable,
        differentiation $textNullable,
        span_index $intNullable,
        span_total $intNullable,
        date_range_str $textNullable,
        is_estimated_schedule $intType DEFAULT 0,
        is_otp_week $intType DEFAULT 0,
        is_social_event_week $intType DEFAULT 0,
        -- Kaynak bilgisi. Maarif rozeti BURADAN turer.
        --
        -- Once bu sutunlar yoktu ve rozet metin aramasiyla
        -- veriliyordu (publisher'da "maarif" geciyor mu). Olcum: 89
        -- ders rozet almasi gerekirken almiyor, 2 ders yanlis
        -- aliyordu. Ustelik veri her kayda isMaarif=true diyordu,
        -- Maarif'in yururlukte olmadigi 4, 8 ve 12. siniflar dahil.
        is_maarif $intType DEFAULT 0,
        source_portal $textNullable,
        source_program $textNullable
      )
    ''');

    // C. Senkronizasyon Meta Verileri Tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key $textType PRIMARY KEY,
        version $intType,
        last_synced_at $textType
      )
    ''');

    // D. Kazanım Öğretmen Özel Notları Tablosu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outcome_notes (
        id $idType,
        grade $intType,
        subject_code $textType,
        publisher $textType,
        week_number $intType,
        note_text $textType,
        updated_at $textType,
        UNIQUE(grade, subject_code, publisher, week_number)
      )
    ''');

    await _createBepTables(db);
    await _createGuidanceTables(db);

    // D. 2025-2026 Resmî MEB Çalışma Takvimi Tohumlama (Seed Data)
    final calendarCountQuery = await db.rawQuery('SELECT COUNT(*) as c FROM academic_calendar_events');
    final calendarCount = Sqflite.firstIntValue(calendarCountQuery) ?? 0;
    if (calendarCount == 0) {
      final meb2025_2026Events = [
        {
          'doc_id': 'meb_2025_donem1_baslangic',
          'title': '1. Dönem Ders Başlangıcı',
          'description': '2025-2026 Eğitim Öğretim Yılı 1. Dönem Açılışı',
          'start_date': '2025-09-14T08:00:00',
          'end_date': '2025-09-14T17:00:00',
          'category': 'period',
          'academic_year': '2025-2026',
          'is_official_holiday': 0,
        },
        {
          'doc_id': 'meb_2025_29ekim',
          'title': '29 Ekim Cumhuriyet Bayramı',
          'description': 'Cumhuriyetimizin Kuruluş Yıldönümü Resmî Tatili',
          'start_date': '2025-10-29T00:00:00',
          'end_date': '2025-10-29T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2025_ara_tatil_1',
          'title': '1. Dönem Ara Tatili',
          'description': 'Kasım Ara Tatil Haftası (Öğrenciler ve Öğretmenler Dinlenme/Seminer)',
          'start_date': '2025-11-10T00:00:00',
          'end_date': '2025-11-14T23:59:59',
          'category': 'breakHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_yilbasi',
          'title': 'Yılbaşı Tatili',
          'description': '1 Ocak Resmî Tatil',
          'start_date': '2026-01-01T00:00:00',
          'end_date': '2026-01-01T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_somestr',
          'title': 'Yarıyıl (Sömestr) Tatili',
          'description': '1. Dönem Sonu Karneler ve 2 Haftalık Yarıyıl Dinlenme Tatili',
          'start_date': '2026-01-19T00:00:00',
          'end_date': '2026-01-30T23:59:59',
          'category': 'breakHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_donem2_baslangic',
          'title': '2. Dönem Ders Başlangıcı',
          'description': '2025-2026 Eğitim Öğretim Yılı 2. Dönem Açılışı',
          'start_date': '2026-02-02T08:00:00',
          'end_date': '2026-02-02T17:00:00',
          'category': 'period',
          'academic_year': '2025-2026',
          'is_official_holiday': 0,
        },
        {
          'doc_id': 'meb_2026_ramazan_bayrami',
          'title': 'Ramazan Bayramı Tatili',
          'description': 'Ramazan Bayramı Resmî Tatil Günleri',
          'start_date': '2026-03-20T00:00:00',
          'end_date': '2026-03-22T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_ara_tatil_2',
          'title': '2. Dönem Ara Tatili',
          'description': 'Nisan Ara Tatil Haftası',
          'start_date': '2026-04-06T00:00:00',
          'end_date': '2026-04-10T23:59:59',
          'category': 'breakHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_23nisan',
          'title': '23 Nisan Ulusal Egemenlik ve Çocuk Bayramı',
          'description': 'Resmî Bayram ve Tatil',
          'start_date': '2026-04-23T00:00:00',
          'end_date': '2026-04-23T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_1mayis',
          'title': '1 Mayıs Emek ve Dayanışma Günü',
          'description': 'Resmî Tatil',
          'start_date': '2026-05-01T00:00:00',
          'end_date': '2026-05-01T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_19mayis',
          'title': '19 Mayıs Atatürk\'ü Anma, Gençlik ve Spor Bayramı',
          'description': 'Resmî Bayram ve Tatil',
          'start_date': '2026-05-19T00:00:00',
          'end_date': '2026-05-19T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_kurban_bayrami',
          'title': 'Kurban Bayramı Tatili',
          'description': 'Kurban Bayramı Resmî Tatil Günleri',
          'start_date': '2026-05-27T00:00:00',
          'end_date': '2026-05-30T23:59:59',
          'category': 'officialHoliday',
          'academic_year': '2025-2026',
          'is_official_holiday': 1,
        },
        {
          'doc_id': 'meb_2026_donem2_kapanis',
          'title': 'Eğitim Öğretim Yılı Sonu (Karne Günü)',
          'description': '2025-2026 Eğitim Öğretim Yılı Kapanışı ve Yaz Tatili Başlangıcı',
          'start_date': '2026-06-19T08:00:00',
          'end_date': '2026-06-19T17:00:00',
          'category': 'period',
          'academic_year': '2025-2026',
          'is_official_holiday': 0,
        },
      ];

      for (final ev in meb2025_2026Events) {
        await db.insert('academic_calendar_events', ev);
      }
    }
  }


  /// Sinif rehberlik plani uygulama kaydi.
  ///
  /// Plan verisi VARLIKTAN gelir (degismez); bu tablo yalnizca
  /// ogretmenin "uyguladim" isaretini ve notunu tutar. Ikisi ayri
  /// durmasaydi varlik her guncellendiginde ogretmenin kaydi silinirdi.
  Future<void> _createGuidanceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS guidance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        academic_year TEXT NOT NULL,
        grade_level INTEGER NOT NULL,
        hafta INTEGER NOT NULL,
        sira_no INTEGER NOT NULL,
        uygulandi INTEGER NOT NULL DEFAULT 0,
        -- `not` SQLite'ta AYRILMIS SOZCUK; sutun adi olarak
        -- kullanilinca CREATE TABLE sozdizimi hatasi veriyor ve
        -- tablo hic olusmuyor. Bu yuzden `ogretmen_notu`.
        ogretmen_notu TEXT,
        uygulanma_tarihi TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        UNIQUE(class_id, academic_year, hafta, sira_no)
      )
    ''');
  }

  Future<void> _createBepTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bep_plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        academic_year TEXT NOT NULL,
        subject TEXT NOT NULL,
        subject_code TEXT NOT NULL DEFAULT '',
        grade_level INTEGER NOT NULL DEFAULT 0,
        placement TEXT NOT NULL DEFAULT 'inclusion',
        program_kind TEXT NOT NULL DEFAULT 'general',
        school_name TEXT NOT NULL DEFAULT '',
        diagnosis TEXT NOT NULL DEFAULT '',
        track TEXT NOT NULL DEFAULT 'primary',
        start_month TEXT NOT NULL DEFAULT 'Eylül',
        start_date TEXT NOT NULL DEFAULT '',
        end_date TEXT NOT NULL DEFAULT '',
        default_criterion TEXT NOT NULL DEFAULT '',
        ram_decision TEXT,
        performance_level TEXT,
        physical_arrangements TEXT,
        social_arrangements TEXT,
        digital_supports TEXT,
        committee_json TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE,
        UNIQUE(student_id, academic_year, subject_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bep_long_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (plan_id) REFERENCES bep_plans (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bep_short_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        long_goal_id INTEGER NOT NULL,
        condition_text TEXT NOT NULL,
        behavior_text TEXT NOT NULL,
        criterion_text TEXT NOT NULL,
        method TEXT,
        materials TEXT,
        assessment TEXT,
        outcome_code TEXT,
        outcome_description TEXT,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (long_goal_id) REFERENCES bep_long_goals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bep_evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        short_goal_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        note TEXT,
        evaluated_at TEXT NOT NULL,
        FOREIGN KEY (short_goal_id) REFERENCES bep_short_goals (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bep_coarse (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL,
        outcome_code TEXT NOT NULL,
        outcome_description TEXT NOT NULL,
        unit_title TEXT,
        can_do INTEGER NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES bep_plans (id) ON DELETE CASCADE,
        UNIQUE(plan_id, outcome_code)
      )
    ''');

    // Sosyal kulup (MEB Sosyal Etkinlikler Yonetmeligi MADDE 8).
    //
    // Kulup SINIFA degil OKULA baglidir: brans ogretmeni farkli
    // subelerden ogrenci alir. Bu yuzden uyelik students tablosunda bir
    // sutun degil, ayri club_members tablosudur.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clubs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        catalog_code TEXT NOT NULL DEFAULT '',
        ad TEXT NOT NULL,
        tema TEXT NOT NULL DEFAULT 'toplum',
        ogretim_yili TEXT NOT NULL,
        temsilci_uye_id INTEGER,
        plan_duzenlemeleri TEXT NOT NULL DEFAULT '',
        olusturma_tarihi TEXT NOT NULL
      )
    ''');
    // Ogrenci silinirse uyelik satiri KALIR, student_id null olur:
    // imzalanmis uye listesi ve yil sonu raporu tutarli kalsin diye.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS club_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        club_id INTEGER NOT NULL,
        student_id INTEGER,
        ad_soyad TEXT NOT NULL,
        okul_no INTEGER NOT NULL DEFAULT 0,
        sinif_adi TEXT NOT NULL DEFAULT '',
        gorev TEXT NOT NULL DEFAULT 'Üye',
        FOREIGN KEY (club_id) REFERENCES clubs (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE SET NULL,
        UNIQUE(club_id, student_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS club_activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        club_id INTEGER NOT NULL,
        ay TEXT NOT NULL,
        yapilan_calisma TEXT NOT NULL DEFAULT '',
        katilan_sayisi INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (club_id) REFERENCES clubs (id) ON DELETE CASCADE,
        UNIQUE(club_id, ay)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_club_members_club '
      'ON club_members (club_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_club_members_student '
      'ON club_members (student_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 25) {
      // Kaynak bilgisi: Maarif rozeti artik metin aramasiyla degil bu
      // sutunlardan karar veriliyor.
      //
      // Sutunlar eklendikten sonra mufredat YENIDEN TOHUMLANMALI;
      // eski kayitlarda bu alanlar bos. Tohumlama zaten varlik
      // parmak izi degisince kendiliginden calisiyor ve bu surumde
      // varlik da degisti.
      const kaynakSutunlari = <String, String>{
        'is_maarif': 'INTEGER DEFAULT 0',
        'source_portal': 'TEXT',
        'source_program': 'TEXT',
      };
      for (final entry in kaynakSutunlari.entries) {
        try {
          await db.execute(
            'ALTER TABLE curriculum_outcomes ADD COLUMN '
            '${entry.key} ${entry.value}',
          );
        } catch (e) {
          debugPrint('DB Upgrade (curriculum_outcomes.${entry.key}): $e');
        }
      }
    }

    if (oldVersion < 24) {
      // Ogretmenin kendi belirledigi tarih ve olcut.
      //
      // Tarih bugune kadar academic_year + start_month'tan
      // HESAPLANIYORDU ve bitis her zaman 31 Mayis'ti. Olcut de her
      // satirda "4/5 (%80)" sabitiyle basiliyordu. Ikisi de artik
      // plana yazilabiliyor; bos kalirsa eski hesap surer, boylece
      // mevcut planlar oldugu gibi calismaya devam eder.
      Future<void> ekle(String sql, String etiket) async {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('DB Upgrade (bep_plans.$etiket): $e');
        }
      }

      await ekle(
        "ALTER TABLE bep_plans ADD COLUMN start_date TEXT NOT NULL DEFAULT ''",
        'start_date',
      );
      await ekle(
        "ALTER TABLE bep_plans ADD COLUMN end_date TEXT NOT NULL DEFAULT ''",
        'end_date',
      );
      await ekle(
        "ALTER TABLE bep_plans ADD COLUMN default_criterion TEXT NOT NULL "
        "DEFAULT ''",
        'default_criterion',
      );
    }

    if (oldVersion < 23) {
      // Sosyal kulup modulu. Uc tablo birlikte gelir; biri olusup digeri
      // olusmazsa modul yarim calisir, o yuzden her biri ayri sarilir ve
      // hata yutulmaz, loglanir.
      Future<void> kur(String sql, String etiket) async {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('DB Upgrade (clubs.$etiket): $e');
        }
      }

      await kur('''
        CREATE TABLE IF NOT EXISTS clubs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          catalog_code TEXT NOT NULL DEFAULT '',
          ad TEXT NOT NULL,
          tema TEXT NOT NULL DEFAULT 'toplum',
          ogretim_yili TEXT NOT NULL,
          temsilci_uye_id INTEGER,
          plan_duzenlemeleri TEXT NOT NULL DEFAULT '',
          olusturma_tarihi TEXT NOT NULL
        )
      ''', 'clubs');
      await kur('''
        CREATE TABLE IF NOT EXISTS club_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          club_id INTEGER NOT NULL,
          student_id INTEGER,
          ad_soyad TEXT NOT NULL,
          okul_no INTEGER NOT NULL DEFAULT 0,
          sinif_adi TEXT NOT NULL DEFAULT '',
          gorev TEXT NOT NULL DEFAULT 'Üye',
          FOREIGN KEY (club_id) REFERENCES clubs (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE SET NULL,
          UNIQUE(club_id, student_id)
        )
      ''', 'club_members');
      await kur('''
        CREATE TABLE IF NOT EXISTS club_activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          club_id INTEGER NOT NULL,
          ay TEXT NOT NULL,
          yapilan_calisma TEXT NOT NULL DEFAULT '',
          katilan_sayisi INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (club_id) REFERENCES clubs (id) ON DELETE CASCADE,
          UNIQUE(club_id, ay)
        )
      ''', 'club_activity_logs');
      await kur(
        'CREATE INDEX IF NOT EXISTS idx_club_members_club '
        'ON club_members (club_id)',
        'idx_club',
      );
      await kur(
        'CREATE INDEX IF NOT EXISTS idx_club_members_student '
        'ON club_members (student_id)',
        'idx_student',
      );
    }

    if (oldVersion < 20) {
      try {
        await db.execute(
          "ALTER TABLE bep_plans ADD COLUMN track TEXT NOT NULL DEFAULT 'primary'",
        );
      } catch (e) {
        debugPrint('DB Upgrade (bep_plans.track): $e');
      }
      try {
        await db.execute(
          "ALTER TABLE bep_plans ADD COLUMN start_month TEXT NOT NULL DEFAULT 'Eylül'",
        );
      } catch (e) {
        debugPrint('DB Upgrade (bep_plans.start_month): $e');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bep_coarse (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER NOT NULL,
            outcome_code TEXT NOT NULL,
            outcome_description TEXT NOT NULL,
            unit_title TEXT,
            can_do INTEGER NOT NULL,
            FOREIGN KEY (plan_id) REFERENCES bep_plans (id) ON DELETE CASCADE,
            UNIQUE(plan_id, outcome_code)
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade (bep_coarse): $e');
      }
    }

    if (oldVersion < 19) {
      Future<void> add(String sql, String label) async {
        try {
          await db.execute(sql);
        } catch (e) {
          debugPrint('DB Upgrade (bep_plans.$label): $e');
        }
      }

      await add(
        "ALTER TABLE bep_plans ADD COLUMN placement TEXT NOT NULL DEFAULT 'inclusion'",
        'placement',
      );
      await add(
        "ALTER TABLE bep_plans ADD COLUMN program_kind TEXT NOT NULL DEFAULT 'general'",
        'program_kind',
      );
      await add(
        "ALTER TABLE bep_plans ADD COLUMN school_name TEXT NOT NULL DEFAULT ''",
        'school_name',
      );
      await add(
        "ALTER TABLE bep_plans ADD COLUMN diagnosis TEXT NOT NULL DEFAULT ''",
        'diagnosis',
      );
    }

    if (oldVersion < 18) {
      try {
        await db.execute(
          "ALTER TABLE bep_plans ADD COLUMN subject_code TEXT NOT NULL DEFAULT ''",
        );
      } catch (e) {
        debugPrint('DB Upgrade (bep_plans.subject_code): $e');
      }
      try {
        await db.execute(
          'ALTER TABLE bep_plans ADD COLUMN grade_level INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        debugPrint('DB Upgrade (bep_plans.grade_level): $e');
      }
      try {
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS bep_plans_student_year_code '
          'ON bep_plans(student_id, academic_year, subject_code)',
        );
      } catch (e) {
        debugPrint('DB Upgrade (bep_plans unique code): $e');
      }
    }

    if (oldVersion < 22) {
      // Sinif rehberlik plani uygulama kaydi.
      await _createGuidanceTables(db);
    }

    if (oldVersion < 21) {
      // BEP tablosunun "Kullanilacak Materyaller" ve
      // "Olcme-Degerlendirme" sutunlari.
      //
      // PDF bu iki sutunu BASIYORDU ama veri modelinde alan yoktu:
      // her satira ayni sabit metin yaziliyordu ("Akilli Tahta,
      // Projeksiyon..."). Bilisim dersi icin yazilmis liste oz bakim
      // BEP'inde de aynen cikiyor, ogretmen degistiremiyordu.
      for (final sutun in ['materials', 'assessment']) {
        try {
          await db.execute(
            'ALTER TABLE bep_short_goals ADD COLUMN $sutun TEXT',
          );
        } catch (e) {
          debugPrint('DB Upgrade (bep_short_goals.$sutun): $e');
        }
      }

      // Egitim ortami duzenlemeleri. PDF'in alt blogundaki uc kutu
      // SADECE BASLIK basiyordu; "one oturtma", "akran destegi" gibi
      // asil BEP tedbirleri belgeye hic yazilamiyordu.
      for (final sutun in [
        'physical_arrangements',
        'social_arrangements',
        'digital_supports',
      ]) {
        try {
          await db.execute(
            'ALTER TABLE bep_plans ADD COLUMN $sutun TEXT',
          );
        } catch (e) {
          debugPrint('DB Upgrade (bep_plans.$sutun): $e');
        }
      }
    }

    if (oldVersion < 17) {
      await _createBepTables(db);
    }

    if (oldVersion < 16) {
      // Ad-soyad yazim standardi: "Yusuf YILMAZ".
      //
      // Yeni kayitlar bicimlendirilerek yazilmaya baslandi ama ESKI
      // kayitlar oldugu gibi duruyordu: ayni listede "Yusuf YILMAZ" ile
      // "Semih Uzum" yan yana gorunuyordu. Tutarsizlik kalici olmasin
      // diye mevcut veri de bir kez donusturulur.
      await _migrateNameFormat(db);
    }

    if (oldVersion < 15) {
      // Soz hakki sayaci. Katilim modulu yeniden kurgulandi: ogrenci
      // adina tek dokunus bu sayaci ilerletiyor, diyalog acilmiyor.
      try {
        await db.execute(
          'ALTER TABLE participation_records '
          'ADD COLUMN speaking_turns INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        debugPrint('DB Upgrade (speaking_turns): $e');
      }
    }

    if (oldVersion < 14) {
      // Maarif icerigi sutunlari hic olmamisti: model bunlari okumaya
      // calisiyor ama tabloda bulunmadigi icin sessizce bos donuyordu.
      // Sonuc: kazanim kartlarindaki "MAARIF DERS OZETI" paneli, resmi
      // etkinlik, degerler, beceriler ve farklilastirma bolumleri
      // uygulamanin ilk gunuden beri BOS goruntuleniyordu.
      const yeniSutunlar = <String, String>{
        'category': 'TEXT',
        'outcome_parts': 'TEXT',
        'suggested_activities': 'TEXT',
        'official_activity': 'TEXT',
        'maarif_summary': 'TEXT',
        'maarif_values': 'TEXT',
        'maarif_skills': 'TEXT',
        'differentiation': 'TEXT',
        'span_index': 'INTEGER',
        'span_total': 'INTEGER',
        'date_range_str': 'TEXT',
        'is_estimated_schedule': 'INTEGER DEFAULT 0',
        'is_otp_week': 'INTEGER DEFAULT 0',
        'is_social_event_week': 'INTEGER DEFAULT 0',
      };

      for (final entry in yeniSutunlar.entries) {
        try {
          await db.execute(
            'ALTER TABLE curriculum_outcomes ADD COLUMN '
            '${entry.key} ${entry.value}',
          );
        } catch (e) {
          // Sutun zaten varsa yoksay.
          debugPrint('DB Upgrade (curriculum_outcomes.${entry.key}): $e');
        }
      }

      // Mevcut satirlarda bu alanlar bos; yeniden tohumlanmalari gerekiyor.
      // Tohumlama `count >= 1000` gorunce atliyordu, bu yuzden tabloyu
      // bosaltiyoruz ki acilista yeni alanlarla dolsun.
      try {
        await db.delete('curriculum_outcomes');
      } catch (e) {
        debugPrint('DB Upgrade (curriculum_outcomes temizleme): $e');
      }
    }

    if (oldVersion < 13) {
      // Okul sinavina secilen sinif adi `basvuru_linki` sutununa yaziliyordu:
      // tabloda `sinif` sutunu hic yoktu ama model onu okumaya calisiyordu.
      //
      // Sonuc: ogretmenin sectigi sinif geri okunamiyor, ustelik ekran
      // dolu bir "basvuru linki" gorup tiklanabilir bir baglanti cizip
      // "5-A"yi adres olarak acmaya calisiyordu.
      try {
        await db.execute(
          'ALTER TABLE kisisel_sinavlar ADD COLUMN sinif TEXT',
        );
        // Eski kayitlarda sinif adi yanlis sutunda duruyor; tasi ve temizle.
        // Gercek basvuru linkleri http ile basladigi icin ayirt edilebilir.
        await db.execute('''
          UPDATE kisisel_sinavlar
          SET sinif = basvuru_linki, basvuru_linki = NULL
          WHERE basvuru_linki IS NOT NULL
            AND basvuru_linki != ''
            AND basvuru_linki NOT LIKE 'http%'
        ''');
      } catch (e) {
        // Sutun zaten varsa yoksay.
        debugPrint('DB Upgrade (kisisel_sinavlar.sinif): $e');
      }
    }

    if (oldVersion < 12) {
      // `is_homeroom` sütunu şemada yoktu ama model ve depo katmanı onu
      // yazıyordu: sınıf eklemek "table classes has no column named
      // is_homeroom" hatasıyla düşüyordu.
      //
      // Testler bunu yakalamadı çünkü her test şemayı sıfırdan kuruyor;
      // hata yalnızca ESKİ veritabanına sahip cihazlarda görülüyordu.
      try {
        await db.execute(
          'ALTER TABLE classes ADD COLUMN is_homeroom INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Sütun zaten varsa yoksay.
        debugPrint('DB Upgrade (is_homeroom): $e');
      }
    }

    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE students ADD COLUMN gender TEXT DEFAULT 'Erkek'");
      } catch (e) {
        debugPrint('DB Upgrade (gender column): $e');
      }
    }
    
    if (oldVersion < 3) {
      try {
        await _createLegacyTables(db);
      } catch (e) {
        debugPrint('DB Upgrade (legacy tables): $e');
      }
    }
    
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS seating_plans (
            class_id INTEGER PRIMARY KEY,
            columns INTEGER DEFAULT 4,
            rows INTEGER DEFAULT 6,
            assignments TEXT,
            FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade (seating_plans): $e');
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE students ADD COLUMN parent_name TEXT");
      } catch (e) {
        debugPrint('DB Upgrade (parent_name column): $e');
      }
    }

    if (oldVersion < 6) {
      try {
        await _createSyncAndCalendarTables(db);
      } catch (e) {
        debugPrint('DB Upgrade (sync & academic calendar tables): $e');
      }
    }

    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE curriculum_outcomes ADD COLUMN publisher TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE curriculum_outcomes ADD COLUMN full_title TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE curriculum_outcomes ADD COLUMN teaching_week_number INTEGER");
      } catch (_) {}
    }

    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS outcome_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grade INTEGER NOT NULL,
            subject_code TEXT NOT NULL,
            publisher TEXT NOT NULL,
            week_number INTEGER NOT NULL,
            note_text TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(grade, subject_code, publisher, week_number)
          )
        ''');
      } catch (e) {
        debugPrint('DB Upgrade (outcome_notes table): $e');
      }
    }

    if (oldVersion < 10) {
      await _ensureParticipationTablesExist(db);
    }

    if (oldVersion < 11) {
      await _ensureCloudIds(db);
    }
  }

  /// Ders içi katılım tablolarının her açılışta ve versiyon geçişinde eksiksiz varlığını garanti eder
  Future<void> ensureParticipationTablesExist() async {
    final db = await database;
    await _ensureParticipationTablesExist(db);
  }

  Future<void> _ensureParticipationTablesExist(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    try {
      // 1. participation_sessions tablosunu oluştur
      await db.execute('''
        CREATE TABLE IF NOT EXISTS participation_sessions (
          id $idType,
          class_id $intType,
          date $textType,
          lesson_hour $intType,
          subject_name $textNullable,
          topic_name $textNullable,
          note $textNullable,
          created_at $textNullable,
          FOREIGN KEY (class_id) REFERENCES classes (id) ON DELETE CASCADE
        )
      ''');

      // 2. participation_records tablosunu oluştur
      await db.execute('''
        CREATE TABLE IF NOT EXISTS participation_records (
          id $idType,
          session_id $intType,
          student_id $intType,
          homework_status $textType DEFAULT 'yapti',
          materials_status $textType DEFAULT 'tam',
          arrival_status $textType DEFAULT 'zamaninda',
          stars_count $intType DEFAULT 0,
          custom_tags $textNullable,
          badge_name $textNullable,
          score $intType DEFAULT 0,
          note $textNullable,
          FOREIGN KEY (session_id) REFERENCES participation_sessions (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
        )
      ''');

      // 3. Eksik kolonlar varsa güvenli şekilde ekle
      await _safeAddColumn(db, 'participation_sessions', 'subject_name', 'TEXT');
      await _safeAddColumn(db, 'participation_sessions', 'topic_name', 'TEXT');
      await _safeAddColumn(db, 'participation_sessions', 'note', 'TEXT');
      await _safeAddColumn(db, 'participation_sessions', 'created_at', 'TEXT');

      await _safeAddColumn(db, 'participation_records', 'homework_status', "TEXT DEFAULT 'yapti'");
      await _safeAddColumn(db, 'participation_records', 'materials_status', "TEXT DEFAULT 'tam'");
      await _safeAddColumn(db, 'participation_records', 'arrival_status', "TEXT DEFAULT 'zamaninda'");
      await _safeAddColumn(db, 'participation_records', 'stars_count', "INTEGER DEFAULT 0");
      await _safeAddColumn(db, 'participation_records', 'custom_tags', 'TEXT');
      await _safeAddColumn(db, 'participation_records', 'badge_name', 'TEXT');
      await _safeAddColumn(db, 'participation_records', 'score', "INTEGER DEFAULT 0");
      await _safeAddColumn(db, 'participation_records', 'note', 'TEXT');
    } catch (e, stackTrace) {
      debugPrint('ensureParticipationTablesExist Hatası: $e\n$stackTrace');
    }
  }

  Future<void> _ensureCloudIds(Database db) async {
    try {
      await _safeAddColumn(db, 'classes', 'cloud_id', 'TEXT');
      await _safeAddColumn(db, 'students', 'cloud_id', 'TEXT');
      final rng = Random();
      for (final table in ['classes', 'students']) {
        final rows = await db.query(table, columns: ['id', 'cloud_id']);
        for (final row in rows) {
          final existing = row['cloud_id']?.toString() ?? '';
          if (existing.isNotEmpty) continue;
          final id = row['id'];
          final cloudId =
              '${table[0]}_${DateTime.now().microsecondsSinceEpoch}_${rng.nextInt(1 << 32)}';
          await db.update(table, {'cloud_id': cloudId}, where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ensureCloudIds hatası: $e\n$stackTrace');
    }
  }

  Future<void> _safeAddColumn(Database db, String table, String column, String definition) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      final hasCol = info.any((row) => row['name'] == column);
      if (!hasCol) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    } catch (e, stackTrace) {
      debugPrint('safeAddColumn ($table.$column) Hatası: $e\n$stackTrace');
    }
  }

  // --- MEB AKADEMİK TAKVİM SORGULARI ---

  Future<List<Map<String, dynamic>>> academicCalendarGetir({String? academicYear}) async {
    try {
      final db = await instance.database;
      if (academicYear != null) {
        return await db.query(
          'academic_calendar_events',
          where: 'academic_year = ?',
          whereArgs: [academicYear],
          orderBy: 'start_date ASC',
        );
      }
      return await db.query('academic_calendar_events', orderBy: 'start_date ASC');
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.academicCalendarGetir) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      return [];
    }
  }

  Future<int> academicCalendarEkle(Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      return await db.insert('academic_calendar_events', data);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.academicCalendarEkle) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      return -1;
    }
  }

  Future<void> academicCalendarTopluGuncelle(List<Map<String, dynamic>> items, {String? academicYear}) async {
    try {
      final db = await instance.database;
      await db.transaction((txn) async {
        if (academicYear != null) {
          await txn.delete('academic_calendar_events', where: 'academic_year = ?', whereArgs: [academicYear]);
        } else {
          await txn.delete('academic_calendar_events');
        }
        for (final item in items) {
          final cleanItem = Map<String, dynamic>.from(item)..remove('id');
          await txn.insert('academic_calendar_events', cleanItem);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.academicCalendarTopluGuncelle) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('------------------------------------------------------------------------------------------');
    }
  }

  // --- MÜFREDAT KAZANIM SORGULARI ---

  /// Assets içindeki 2.301 resmî kazanım verisini SQLite veritabanına aktarır (%100 Offline)
  Future<void> seedCurriculumOutcomesFromAssets({bool force = false}) async {
    try {
      final db = await instance.database;
      final countQuery = await db.rawQuery('SELECT COUNT(*) as c FROM curriculum_outcomes');
      final count = Sqflite.firstIntValue(countQuery) ?? 0;
      
      // Eğer force değilse ve zaten veriler yüklüyse tekrar yükleme yapma
      if (count >= 1000 && !force) {
        return;
      }

      // Sikistirilmis surum okunur (23.9 MB -> 1.6 MB). Yoksa duz
      // dosyaya geri dusulur.
      final jsonString = await GzipAsset.loadString(
        'assets/data/official_maarif_kazanimlar.json',
      );

      // JSON ayrıştırma ve model dönüşümü AYRI İZOLATTA.
      //
      // 9087 kayıt için bu iş telefonda ~2 saniye sürüyor ve ana iş
      // parçacığında yapılırsa arayüz o süre boyunca donuyordu:
      // logda arka arkaya "DONMA: ana iş parçacığı 1359 ms bloke"
      // satırları çıkıyordu. En görünür sonucu, ilk açılışta PDF
      // ekranının "Belge Hazırlanıyor"da takılı kalmasıydı — belge
      // üretimi 1.5 saniyede bitiyor ama ekranı çizecek iş parçacığı
      // tohumlamayla meşgul olduğu için sonuç görünmüyordu.
      final satirlar = await compute(_kazanimSatirlariniHazirla, jsonString);

      // Tek tek insert yerine toplu batch: 2300 kayıt için 2300 ayrı
      // sorgu çalıştırmak hem yavaş hem bellek baskısı yaratıyordu.
      // Batch, hepsini tek turda yazar.
      await db.transaction((txn) async {
        await txn.delete('curriculum_outcomes');
        final batch = txn.batch();
        for (final row in satirlar) {
          batch.insert('curriculum_outcomes', row);
        }
        // noResult: sonuçları biriktirme — 9087 sonuç nesnesi belleği
        // gereksiz şişiriyordu.
        await batch.commit(noResult: true);
      });
      debugPrint('DatabaseHelper: ${satirlar.length} resmî kazanım assets üzerinden SQLite veritabanına başarıyla yüklendi 🚀');
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.seedCurriculumOutcomesFromAssets) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('---------------------------------------------------------------------------------------------');
    }
  }

  /// Veritabanında mevcut tüm sınıf seviyelerini (1..12) getirir
  Future<List<int>> mevcutSiniflariGetir() async {
    try {
      final db = await instance.database;
      final res = await db.rawQuery('SELECT DISTINCT grade_level FROM curriculum_outcomes ORDER BY grade_level ASC');
      return res.map((r) => r['grade_level'] as int).toList();
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.mevcutSiniflariGetir) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      return [1, 2, 3, 4, 5, 6, 7, 8];
    }
  }

  /// Seçilen sınıfa ait mevcut branşları ve yayınevlerini getirir
  Future<List<Map<String, dynamic>>> mevcutDersleriGetir(int gradeLevel) async {
    try {
      final db = await instance.database;
      // SIRALAMA: temel dersler ustte, secmeli/CYDEM altta.
      //
      // Ogretmen kendi dersini ararken pilot okul dersleri (Coklu
      // Yabanci Dil) ve secmeliler arasinda kaybolmamali. Kategori
      // alani zaten var: 'core' temel, 'iho' imam hatip, gerisi
      // secmeli.
      //
      // is_maarif ve kaynak sutunlari da getirilir: rozet artik metin
      // aramasiyla degil bu alandan karar veriliyor.
      return await db.rawQuery('''
        SELECT
          subject_code,
          subject_name,
          COALESCE(publisher, '') as publisher,
          COALESCE(full_title, '') as full_title,
          COALESCE(category, 'core') as category,
          MAX(COALESCE(is_maarif, 0)) as is_maarif,
          COALESCE(MAX(source_portal), '') as source_portal,
          COUNT(*) as outcome_count
        FROM curriculum_outcomes
        WHERE grade_level = ?
        GROUP BY subject_code, publisher
        ORDER BY
          CASE COALESCE(category, 'core')
            WHEN 'core' THEN 0
            WHEN 'iho' THEN 1
            ELSE 2
          END ASC,
          subject_name ASC
      ''', [gradeLevel]);
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.mevcutDersleriGetir) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> kazanimlariGetir({
    int? gradeLevel,
    String? subjectCode,
    String? publisher,
    int? weekNumber,
    String? searchQuery,
  }) async {
    try {
      final db = await instance.database;
      final conditions = <String>[];
      final whereArgs = <dynamic>[];

      if (gradeLevel != null) {
        conditions.add('grade_level = ?');
        whereArgs.add(gradeLevel);
      }
      if (subjectCode != null && subjectCode != 'ALL') {
        conditions.add('subject_code = ?');
        whereArgs.add(subjectCode);
      }
      if (publisher != null && publisher != 'ALL') {
        conditions.add('publisher = ?');
        whereArgs.add(publisher);
      }
      if (weekNumber != null) {
        conditions.add('week_number = ?');
        whereArgs.add(weekNumber);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        conditions.add('(outcome_description LIKE ? OR unit_title LIKE ? OR outcome_code LIKE ?)');
        final q = '%${searchQuery.trim()}%';
        whereArgs.addAll([q, q, q]);
      }

      return await db.query(
        'curriculum_outcomes',
        where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'week_number ASC, id ASC',
      );
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.kazanimlariGetir) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('------------------------------------------------------------------------------');
      return [];
    }
  }

  Future<void> kazanimTopluGuncelle(List<Map<String, dynamic>> items, {int? gradeLevel, String? subjectCode}) async {
    try {
      final db = await instance.database;
      await db.transaction((txn) async {
        if (gradeLevel != null && subjectCode != null) {
          await txn.delete(
            'curriculum_outcomes',
            where: 'grade_level = ? AND subject_code = ?',
            whereArgs: [gradeLevel, subjectCode],
          );
        }
        for (final item in items) {
          final cleanItem = Map<String, dynamic>.from(item)..remove('id');
          await txn.insert('curriculum_outcomes', cleanItem);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('---------------- HATA DETAYI (DatabaseHelper.kazanimTopluGuncelle) ----------------');
      debugPrint('Hata Mesajı : $e');
      debugPrint('Kod Satırı   : $stackTrace');
      debugPrint('----------------------------------------------------------------------------------');
    }
  }

  // --- SENKRONİZASYON META VERİLERİ ---

  Future<int> syncMetadataVersionGetir(String key) async {
    try {
      final db = await instance.database;
      final res = await db.query('sync_metadata', where: 'key = ?', whereArgs: [key]);
      if (res.isNotEmpty) {
        return (res.first['version'] as int?) ?? 1;
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  Future<void> syncMetadataVersionGuncelle(String key, int version) async {
    try {
      final db = await instance.database;
      await db.insert('sync_metadata', {
        'key': key,
        'version': version,
        'last_synced_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stackTrace) {
      debugPrint('Sync metadata update error: $e\n$stackTrace');
    }
  }

  // --- KAZANIM ÖZEL NOTLARI (outcome_notes) ---

  Future<String?> getOutcomeNote({
    required int grade,
    required String subjectCode,
    required String publisher,
    required int weekNumber,
  }) async {
    try {
      final db = await instance.database;
      final res = await db.query(
        'outcome_notes',
        columns: ['note_text'],
        where: 'grade = ? AND subject_code = ? AND publisher = ? AND week_number = ?',
        whereArgs: [grade, subjectCode, publisher, weekNumber],
      );
      if (res.isNotEmpty) {
        return res.first['note_text'] as String?;
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getOutcomeNote error: $e\n$stackTrace');
      return null;
    }
  }

  Future<Map<int, String>> getAllOutcomeNotesForSubject({
    required int grade,
    required String subjectCode,
    required String publisher,
  }) async {
    try {
      final db = await instance.database;
      final res = await db.query(
        'outcome_notes',
        columns: ['week_number', 'note_text'],
        where: 'grade = ? AND subject_code = ? AND publisher = ?',
        whereArgs: [grade, subjectCode, publisher],
      );
      final map = <int, String>{};
      for (final row in res) {
        final week = row['week_number'] as int?;
        final note = row['note_text'] as String?;
        if (week != null && note != null && note.trim().isNotEmpty) {
          map[week] = note;
        }
      }
      return map;
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getAllOutcomeNotesForSubject error: $e\n$stackTrace');
      return {};
    }
  }

  Future<void> saveOutcomeNote({
    required int grade,
    required String subjectCode,
    required String publisher,
    required int weekNumber,
    required String noteText,
  }) async {
    try {
      final db = await instance.database;
      if (noteText.trim().isEmpty) {
        await deleteOutcomeNote(
          grade: grade,
          subjectCode: subjectCode,
          publisher: publisher,
          weekNumber: weekNumber,
        );
        return;
      }
      await db.insert(
        'outcome_notes',
        {
          'grade': grade,
          'subject_code': subjectCode,
          'publisher': publisher,
          'week_number': weekNumber,
          'note_text': noteText.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.saveOutcomeNote error: $e\n$stackTrace');
    }
  }

  Future<void> deleteOutcomeNote({
    required int grade,
    required String subjectCode,
    required String publisher,
    required int weekNumber,
  }) async {
    try {
      final db = await instance.database;
      await db.delete(
        'outcome_notes',
        where: 'grade = ? AND subject_code = ? AND publisher = ? AND week_number = ?',
        whereArgs: [grade, subjectCode, publisher, weekNumber],
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.deleteOutcomeNote error: $e\n$stackTrace');
    }
  }

  // ==========================================
  // --- SINAV İŞLEMLERİ 1: QUIZ & SÖZLÜ TABLOSU ---
  // ==========================================

  Future<Map<String, dynamic>> getOrCreateQuizCizelge(String className, String subject, {String category = 'quiz'}) async {
    try {
      final db = await instance.database;
      final res = await db.query(
        'quiz_cizelgeleri',
        where: 'sinif = ? AND ders = ? AND kategori = ?',
        whereArgs: [className, subject, category],
      );

      if (res.isNotEmpty) {
        return res.first;
      }

      final newId = await db.insert('quiz_cizelgeleri', {
        'sinif': className,
        'ders': subject,
        'olusturulma_tarihi': DateTime.now().toIso8601String(),
        'kategori': category,
      });

      // Varsayılan olarak 2 kolon (Quiz 1 ve Sözlü 1) ekleyelim
      await db.insert('quiz_kolonlari', {
        'cizelge_id': newId,
        'baslik': '1. Quiz',
        'tip': 'quiz',
        'sira': 0,
        'tarih': DateTime.now().toIso8601String(),
      });
      await db.insert('quiz_kolonlari', {
        'cizelge_id': newId,
        'baslik': '1. Sözlü',
        'tip': 'sozlu',
        'sira': 1,
        'tarih': DateTime.now().toIso8601String(),
      });

      final created = await db.query('quiz_cizelgeleri', where: 'id = ?', whereArgs: [newId]);
      return created.first;
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getOrCreateQuizCizelge error: $e\n$stackTrace');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getQuizKolonlari(int cizelgeId) async {
    try {
      final db = await instance.database;
      return await db.query(
        'quiz_kolonlari',
        where: 'cizelge_id = ?',
        whereArgs: [cizelgeId],
        orderBy: 'sira ASC, id ASC',
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getQuizKolonlari error: $e\n$stackTrace');
      return [];
    }
  }

  Future<int> addQuizKolon(Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      return await db.insert('quiz_kolonlari', data);
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.addQuizKolon error: $e\n$stackTrace');
      return -1;
    }
  }

  Future<void> deleteQuizKolon(int kolonId) async {
    try {
      final db = await instance.database;
      await db.delete('quiz_kolonlari', where: 'id = ?', whereArgs: [kolonId]);
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.deleteQuizKolon error: $e\n$stackTrace');
    }
  }

  Future<List<Map<String, dynamic>>> getQuizNotlariForCizelge(int cizelgeId) async {
    try {
      final db = await instance.database;
      return await db.rawQuery('''
        SELECT qn.kolon_id, qn.ogrenci_id, qn.puan
        FROM quiz_notlari qn
        INNER JOIN quiz_kolonlari qk ON qn.kolon_id = qk.id
        WHERE qk.cizelge_id = ?
      ''', [cizelgeId]);
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getQuizNotlariForCizelge error: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> saveQuizNot(int kolonId, int studentId, int? score) async {
    try {
      final db = await instance.database;
      if (score == null) {
        await db.delete(
          'quiz_notlari',
          where: 'kolon_id = ? AND ogrenci_id = ?',
          whereArgs: [kolonId, studentId],
        );
      } else {
        await db.insert(
          'quiz_notlari',
          {
            'kolon_id': kolonId,
            'ogrenci_id': studentId,
            'puan': score,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.saveQuizNot error: $e\n$stackTrace');
    }
  }

  // ==========================================
  // --- SINAV İŞLEMLERİ 2: PROJE & ÖDEV RUBRIC ---
  // ==========================================

  Future<List<Map<String, dynamic>>> getProjectKriterleri() async {
    try {
      final db = await instance.database;
      return await db.query('proje_kriterleri', orderBy: 'sira ASC, id ASC');
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getProjectKriterleri error: $e\n$stackTrace');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjectTakipList(String className, String subject) async {
    try {
      final db = await instance.database;
      return await db.query(
        'proje_takip',
        where: 'sinif = ? AND ders = ?',
        whereArgs: [className, subject],
        orderBy: 'id ASC',
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getProjectTakipList error: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> initProjectTakipForClass(
    String className,
    String subject,
    List<Map<String, dynamic>> students, {
    String defaultTopic = 'Dönem Projesi / Ödevi',
  }) async {
    try {
      final db = await instance.database;
      await db.transaction((txn) async {
        for (final s in students) {
          final studentId = s['id'] as int;
          final studentName = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
          final exists = await txn.query(
            'proje_takip',
            where: 'sinif = ? AND ders = ? AND ogrenci_id = ?',
            whereArgs: [className, subject, studentId],
          );

          if (exists.isEmpty) {
            await txn.insert('proje_takip', {
              'sinif': className,
              'ogrenci_id': studentId,
              'ogrenci_ad': studentName.isEmpty ? 'Öğrenci' : studentName,
              'ders': subject,
              'odev_konusu': defaultTopic,
              'olusturulma_tarihi': DateTime.now().toIso8601String(),
              'teslim_etti': 0,
              'toplam_puan': null,
              'degerlendirildi': 0,
            });
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.initProjectTakipForClass error: $e\n$stackTrace');
    }
  }

  Future<void> toggleProjectSubmission(int projectId, bool isSubmitted) async {
    try {
      final db = await instance.database;
      await db.update(
        'proje_takip',
        {'teslim_etti': isSubmitted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [projectId],
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.toggleProjectSubmission error: $e\n$stackTrace');
    }
  }

  Future<void> updateProjectTopic(int projectId, String newTopic) async {
    try {
      final db = await instance.database;
      await db.update(
        'proje_takip',
        {'odev_konusu': newTopic},
        where: 'id = ?',
        whereArgs: [projectId],
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.updateProjectTopic error: $e\n$stackTrace');
    }
  }

  Future<List<Map<String, dynamic>>> getProjectPuanlari(int projectId) async {
    try {
      final db = await instance.database;
      return await db.query(
        'proje_puanlari',
        where: 'proje_id = ?',
        whereArgs: [projectId],
      );
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getProjectPuanlari error: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> saveProjectRubricEvaluation(
    int projectId,
    Map<int, int> kriterPuanlari,
    int totalScore,
  ) async {
    try {
      final db = await instance.database;
      await db.transaction((txn) async {
        await txn.delete('proje_puanlari', where: 'proje_id = ?', whereArgs: [projectId]);

        for (final entry in kriterPuanlari.entries) {
          await txn.insert('proje_puanlari', {
            'proje_id': projectId,
            'kriter_id': entry.key,
            'puan': entry.value,
          });
        }

        await txn.update(
          'proje_takip',
          {
            'toplam_puan': totalScore,
            'degerlendirildi': 1,
            'teslim_etti': 1,
          },
          where: 'id = ?',
          whereArgs: [projectId],
        );
      });
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.saveProjectRubricEvaluation error: $e\n$stackTrace');
    }
  }

  // ==========================================
  // --- SINAV İŞLEMLERİ 3: MERKEZİ & OKUL SINAVLARI ---
  // ==========================================

  Future<void> seedGenelSinavlarIfEmpty() async {
    try {
      final db = await instance.database;
      final countQuery = await db.rawQuery('SELECT COUNT(*) as c FROM genel_sinavlar');
      final count = Sqflite.firstIntValue(countQuery) ?? 0;
      if (count == 0) {
        final defaultExams = [
          {
            'doc_id': 'meb_ortak_sinav_1',
            'sinav_adi': '1. Dönem 1. Ortak Yazılı Sınavları (MEB Geneli)',
            'kurum': 'MEB',
            'sinav_tarihi': '2025-10-27T09:00:00',
            'son_basvuru_tarihi': '2025-10-20T23:59:59',
            'basvuru_linki': 'https://odsgm.meb.gov.tr',
          },
          {
            'doc_id': 'meb_ortak_sinav_2',
            'sinav_adi': '1. Dönem 2. Ortak Yazılı Sınavları',
            'kurum': 'MEB',
            'sinav_tarihi': '2025-12-22T09:00:00',
            'son_basvuru_tarihi': '2025-12-15T23:59:59',
            'basvuru_linki': 'https://odsgm.meb.gov.tr',
          },
          {
            'doc_id': 'meb_lgs_2026',
            'sinav_adi': 'LGS - Liselere Geçiş Sistemi Sınavı',
            'kurum': 'MEB',
            'sinav_tarihi': '2026-06-14T09:30:00',
            'son_basvuru_tarihi': '2026-04-15T23:59:59',
            'basvuru_linki': 'https://meb.gov.tr',
          },
          {
            'doc_id': 'osym_yks_tyt_2026',
            'sinav_adi': 'YKS 1. Oturum - TYT (Temel Yeterlilik Testi)',
            'kurum': 'ÖSYM',
            'sinav_tarihi': '2026-06-20T10:15:00',
            'son_basvuru_tarihi': '2026-03-05T23:59:59',
            'basvuru_linki': 'https://ais.osym.gov.tr',
          },
          {
            'doc_id': 'osym_yks_ayt_2026',
            'sinav_adi': 'YKS 2. Oturum - AYT (Alan Yeterlilik Testi)',
            'kurum': 'ÖSYM',
            'sinav_tarihi': '2026-06-21T10:15:00',
            'son_basvuru_tarihi': '2026-03-05T23:59:59',
            'basvuru_linki': 'https://ais.osym.gov.tr',
          },
          {
            'doc_id': 'osym_kpss_lisans_2026',
            'sinav_adi': 'KPSS Lisans (Genel Yetenek - Genel Kültür & ÖABT)',
            'kurum': 'ÖSYM',
            'sinav_tarihi': '2026-07-19T10:15:00',
            'son_basvuru_tarihi': '2026-05-15T23:59:59',
            'basvuru_linki': 'https://ais.osym.gov.tr',
          },
        ];

        for (final exam in defaultExams) {
          await db.insert('genel_sinavlar', exam);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.seedGenelSinavlarIfEmpty error: $e\n$stackTrace');
    }
  }

  Future<List<Map<String, dynamic>>> getGenelSinavlar() async {
    try {
      final db = await instance.database;
      await seedGenelSinavlarIfEmpty();
      return await db.query('genel_sinavlar', orderBy: 'sinav_tarihi ASC');
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getGenelSinavlar error: $e\n$stackTrace');
      return [];
    }
  }

  Future<List<String>> getFavoriSinavDocIds() async {
    try {
      final db = await instance.database;
      final res = await db.query('favori_sinavlar');
      return res.map((r) => r['doc_id'] as String).toList();
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getFavoriSinavDocIds error: $e\n$stackTrace');
      return [];
    }
  }

  Future<bool> toggleFavoriSinav(String docId) async {
    try {
      final db = await instance.database;
      final exists = await db.query('favori_sinavlar', where: 'doc_id = ?', whereArgs: [docId]);
      if (exists.isNotEmpty) {
        await db.delete('favori_sinavlar', where: 'doc_id = ?', whereArgs: [docId]);
        return false;
      } else {
        await db.insert('favori_sinavlar', {'doc_id': docId});
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.toggleFavoriSinav error: $e\n$stackTrace');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getKisiselSinavlar() async {
    try {
      final db = await instance.database;
      return await db.query('kisisel_sinavlar', orderBy: 'sinav_tarihi ASC');
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.getKisiselSinavlar error: $e\n$stackTrace');
      return [];
    }
  }

  Future<int> addKisiselSinav(Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      return await db.insert('kisisel_sinavlar', data);
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.addKisiselSinav error: $e\n$stackTrace');
      return -1;
    }
  }

  Future<void> deleteKisiselSinav(int id) async {
    try {
      final db = await instance.database;
      await db.delete('kisisel_sinavlar', where: 'id = ?', whereArgs: [id]);
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.deleteKisiselSinav error: $e\n$stackTrace');
    }
  }

  Future<void> insertOrUpdateGenelSinav(Map<String, dynamic> data) async {
    try {
      final db = await instance.database;
      final docId = data['doc_id'] as String?;
      if (docId == null) return;

      final existing = await db.query('genel_sinavlar', where: 'doc_id = ?', whereArgs: [docId]);
      if (existing.isNotEmpty) {
        await db.update('genel_sinavlar', data, where: 'doc_id = ?', whereArgs: [docId]);
      } else {
        await db.insert('genel_sinavlar', data);
      }
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.insertOrUpdateGenelSinav error: $e\n$stackTrace');
    }
  }

  Future<int> bulkUpsertGenelSinavlar(List<Map<String, dynamic>> examMaps) async {
    try {
      final db = await instance.database;
      int count = 0;
      await db.transaction((txn) async {
        for (final data in examMaps) {
          final docId = data['doc_id'] as String?;
          if (docId != null) {
            final existing = await txn.query('genel_sinavlar', where: 'doc_id = ?', whereArgs: [docId]);
            if (existing.isNotEmpty) {
              await txn.update('genel_sinavlar', data, where: 'doc_id = ?', whereArgs: [docId]);
            } else {
              await txn.insert('genel_sinavlar', data);
            }
            count++;
          }
        }
      });
      return count;
    } catch (e, stackTrace) {
      debugPrint('DatabaseHelper.bulkUpsertGenelSinavlar error: $e\n$stackTrace');
      return 0;
    }
  }

  /// Testler icin veritabanini sifirlar.
  ///
  /// Her testin temiz bir semayla baslamasini saglar; aksi halde bir
  /// testin yazdigi kayitlar digerine sizar.
  /// Mevcut ad-soyad kayitlarini "Yusuf YILMAZ" standardina cevirir.
  ///
  /// Yalnizca bir kez calisir (surum 16 gocu). Bicimlendirme kararlidir:
  /// zaten dogru yazilmis kayit degismez.
  Future<void> _migrateNameFormat(Database db) async {
    try {
      final ogrenciler = await db.query(
        'students',
        columns: ['id', 'first_name', 'last_name'],
      );

      final batch = db.batch();
      for (final r in ogrenciler) {
        final ad = NameFormatter.formatFirstName(
          (r['first_name'] as String?) ?? '',
        );
        final soyad = NameFormatter.formatLastName(
          (r['last_name'] as String?) ?? '',
        );

        batch.update(
          'students',
          {'first_name': ad, 'last_name': soyad},
          where: 'id = ?',
          whereArgs: [r['id']],
        );
      }
      await batch.commit(noResult: true);

      debugPrint(
        'Ad-soyad standardi: ${ogrenciler.length} ogrenci kaydi donusturuldu.',
      );
    } catch (e, stackTrace) {
      // Donusum basarisiz olsa da uygulama calismaya devam etmeli;
      // isimler eski bicimde kalir, veri kaybi olmaz.
      debugPrint('Ad-soyad goc hatasi: $e\n$stackTrace');
    }
  }

  /// Bağlantıyı kapatır ve alanı temizler.
  ///
  /// `close()` tek başına yetmez: `_database` alanı dolu kalırsa sonraki
  /// çağrı kapalı örneği döndürür ve "database_closed" hatası düşer.
  /// Alan temizlenince `database` getter'ı kendiliğinden yeniden açar.
  ///
  /// Yedekten geri yükleme sırasında kullanılır: dosyanın üzerine
  /// yazmadan önce bağlantı kapatılmalıdır.
  Future<void> closeConnection() async {
    try {
      await _database?.close();
    } catch (e) {
      debugPrint('closeConnection hatası: $e');
    }
    _database = null;
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    // close() yalnizca baglantiyi kapatir; _database alani dolu kalirsa
    // sonraki cagri kapali ornegi dondurur (database_closed hatasi).
    try {
      await _database?.close();
    } catch (_) {}
    _database = null;

    try {
      final dbPath = await getDatabasesPath();
      await deleteDatabase(join(dbPath, AppConfig.dbName));
    } catch (e) {
      debugPrint('resetForTests silme hatasi: $e');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}

/// Kazanım JSON'unu veritabanı satırlarına çevirir.
///
/// `compute()` ile AYRI İZOLATTA çalışır; üst düzey fonksiyon olması
/// zorunlu. Ana iş parçacığında çalıştırıldığında 9087 kayıt telefonda
/// ~2 saniye arayüzü donduruyordu.
///
/// Alanlar elle eşlenmiyor: model `fromJson` ile JSON'u, `toMap` ile
/// veritabanı satırını üretiyor. Elle eşlemede yalnızca 15 alan
/// yazılıyordu ve Maarif içeriği (ders özeti, resmî etkinlik, değerler,
/// beceriler, farklılaştırma) ayrıştırılıp ATILIYORDU.
List<Map<String, dynamic>> _kazanimSatirlariniHazirla(String jsonString) {
  final list = json.decode(jsonString) as List<dynamic>;
  return [
    for (final item in list)
      CurriculumOutcomeModel.fromJson(item as Map<String, dynamic>).toMap()
        ..remove('id'),
  ];
}

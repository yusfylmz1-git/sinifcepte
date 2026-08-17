import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

extension LegacyCrudMethods on DatabaseHelper {
  // --- SINAV İŞLEMLERİ ---

  Future<int> sinavEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('sinavlar', row);
  }

  Future<List<Map<String, dynamic>>> sinavlariGetir() async {
    final db = await database;

    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sinavlar_tarih ON sinavlar(tarih DESC)',
      );
    } catch (e) {
      debugPrint("⚠️ Index hatası: $e");
    }

    return await db.query('sinavlar', orderBy: 'tarih DESC');
  }

  Future<int> sinavSil(int id) async {
    final db = await database;
    await db.delete('sinav_notlari', where: 'sinav_id = ?', whereArgs: [id]);
    return await db.delete('sinavlar', where: 'id = ?', whereArgs: [id]);
  }

  // --- MEVCUT SINAVI GÜNCELLEME ---
  Future<void> sinavGuncelle({
    required int sinavId,
    required Map<String, dynamic> sinavBilgileri,
    required List<Map<String, dynamic>> yeniNotlar,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'sinavlar',
        sinavBilgileri,
        where: 'id = ?',
        whereArgs: [sinavId],
      );
      await txn.delete(
        'sinav_notlari',
        where: 'sinav_id = ?',
        whereArgs: [sinavId],
      );

      for (var not in yeniNotlar) {
        final notVerisi = Map<String, dynamic>.from(not);
        notVerisi['sinav_id'] = sinavId;
        await txn.insert('sinav_notlari', notVerisi);
      }
    });
  }

  Future<Map<String, dynamic>?> sinavGetirById(int id) async {
    final db = await database;
    final results = await db.query(
      'sinavlar',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> sinavVeNotlariTopluKaydet({
    required Map<String, dynamic> sinavMap,
    required List<Map<String, dynamic>> notlarListesi,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final sinavId = await txn.insert('sinavlar', sinavMap);
      for (var not in notlarListesi) {
        final yeniNot = Map<String, dynamic>.from(not);
        yeniNot['sinav_id'] = sinavId;
        await txn.insert('sinav_notlari', yeniNot);
      }
    });
  }

  // --- NOT İŞLEMLERİ (GÜNCELLENEN KISIM) ---

  Future<void> notKaydet(Map<String, dynamic> row) async {
    final db = await database;
    final varMi = await db.query(
      'sinav_notlari',
      where: 'sinav_id = ? AND ogrenci_id = ?',
      whereArgs: [row['sinav_id'], row['ogrenci_id']],
    );

    if (varMi.isNotEmpty) {
      await db.update(
        'sinav_notlari',
        row,
        where: 'sinav_id = ? AND ogrenci_id = ?',
        whereArgs: [row['sinav_id'], row['ogrenci_id']],
      );
    } else {
      await db.insert('sinav_notlari', row);
    }
  }

  // 🔥 DÜZELTME BURADA: Artık öğrencilerden numarayı da çekiyor (JOIN işlemi)
  Future<List<Map<String, dynamic>>> notlariGetir(int sinavId) async {
    final db = await database;
    // rawQuery ile iki tabloyu birleştiriyoruz: notlar + ogrenciler(numara)
    return await db.rawQuery(
      '''
      SELECT sinav_notlari.*, ogrenciler.numara 
      FROM sinav_notlari 
      LEFT JOIN ogrenciler ON sinav_notlari.ogrenci_id = ogrenciler.id 
      WHERE sinav_notlari.sinav_id = ?
      ORDER BY sinav_notlari.notu DESC
    ''',
      [sinavId],
    );
  }

  // --- DİĞER STANDART İŞLEMLER ---

  Future<void> kazanimlariTemizle() async {
    final db = await database;
    await db.delete('kazanimlar');
  }

  Future<void> topluKazanimEkle(
    List<Map<String, dynamic>> kazanimListesi,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var kazanim in kazanimListesi) {
        await txn.insert('kazanimlar', kazanim);
      }
    });
  }

  Future<List<Map<String, dynamic>>> planlariGetir(
    int sinif,
    String brans,
  ) async {
    final db = await database;
    return await db.query(
      'kazanimlar',
      where: 'sinif = ? AND brans = ?',
      whereArgs: [sinif, brans],
      orderBy: 'hafta ASC',
    );
  }

  Future<int> sinifEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'siniflar',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> siniflariGetir() async {
    final db = await database;
    return await db.query('siniflar', orderBy: 'id DESC');
  }

  Future<int> sinifSil(int id) async {
    final db = await database;
    return await db.delete('siniflar', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> ogrenciEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('ogrenciler', row);
  }

  Future<List<Map<String, dynamic>>> ogrencileriGetir(int sinifId) async {
    final db = await database;
    return await db.query(
      'ogrenciler',
      where: 'sinif_id = ?',
      whereArgs: [sinifId],
      orderBy: 'numara ASC',
    );
  }

  Future<Map<String, dynamic>?> ogrenciGetir(int id) async {
    final db = await database;
    final maps = await db.query('ogrenciler', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> ogrenciSil(int id) async {
    final db = await database;
    return await db.delete('ogrenciler', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> ogrenciGuncelle(Map<String, dynamic> row) async {
    final db = await database;
    int id = row['id'];
    return await db.update('ogrenciler', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> dersEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('dersler', row);
  }

  Future<List<Map<String, dynamic>>> dersleriGetir() async {
    final db = await database;
    return await db.query('dersler', orderBy: 'ders_saati_index ASC');
  }

  Future<int> dersSil(int id) async {
    final db = await database;
    return await db.delete('dersler', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> dersGuncelle(Map<String, dynamic> row) async {
    final db = await database;
    int id = row['id'];
    return await db.update('dersler', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> performansEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(
      'performans',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> performanslariGetir() async {
    final db = await database;
    return await db.query('performans');
  }

  Future<int> performansGuncelle(Map<String, dynamic> row) async {
    final db = await database;
    int id = row['id'];
    return await db.update('performans', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> gunlukPerformanslariGetir(
    String tarih,
  ) async {
    final db = await database;
    return await db.query('performans', where: 'tarih = ?', whereArgs: [tarih]);
  }

  Future<List<Map<String, dynamic>>> ogrenciNotlariniGetir(
    int ogrenciId,
    String dersAdi,
  ) async {
    final db = await database;
    return await db.query(
      'ogrenci_degerlendirmeleri',
      where: 'ogrenci_id = ? AND ders_adi = ?',
      whereArgs: [ogrenciId, dersAdi],
      orderBy: 'tarih DESC',
    );
  }

  Future<void> ayarKaydet(String anahtar, String deger) async {
    final db = await database;
    await db.insert('sistem_ayarlari', {
      'anahtar': anahtar,
      'deger': deger,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> ayarGetir(String anahtar) async {
    final db = await database;
    final maps = await db.query(
      'sistem_ayarlari',
      columns: ['deger'],
      where: 'anahtar = ?',
      whereArgs: [anahtar],
    );
    if (maps.isNotEmpty) return maps.first['deger'] as String;
    return null;
  }

  // ==========================================================================
  // SINAV TAKİBİ İŞLEMLERİ (Genel Sınavlar + Favoriler)
  // ==========================================================================

  // Genel sınav listesini yerelden getir (tarihe göre yakın olan önce)
  Future<List<Map<String, dynamic>>> genelSinavlariGetir() async {
    final db = await database; // Tablo yoksa oluştur (güvenlik)
    return await db.query('genel_sinavlar', orderBy: 'sinav_tarihi ASC');
  }

  // Buluttan gelen listeyi yerele toplu yaz (önce temizle, sonra ekle)
  Future<void> genelSinavlariTopluKaydet(
    List<Map<String, dynamic>> sinavlar,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('genel_sinavlar');
      for (var sinav in sinavlar) {
        await txn.insert('genel_sinavlar', sinav);
      }
    });
  }

  // Tek bir genel sınavı yerele ekle (admin ekleyince)
  Future<int> genelSinavEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('genel_sinavlar', row);
  }

  // --- FAVORİLER ---

  // Kullanıcının favori sınavlarının bulut ID'lerini getir
  Future<Set<String>> favoriSinavIdleriniGetir() async {
    final db = await database;
    final maps = await db.query('favori_sinavlar', columns: ['doc_id']);
    return maps.map((e) => e['doc_id'].toString()).toSet();
  }

  // Favoriye ekle (aynı kayıt varsa görmezden gel)
  Future<void> favoriEkle(String docId) async {
    final db = await database;
    await db.insert('favori_sinavlar', {
      'doc_id': docId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Favoriden çıkar
  Future<void> favoriCikar(String docId) async {
    final db = await database;
    await db.delete('favori_sinavlar', where: 'doc_id = ?', whereArgs: [docId]);
  }

  // --- KİŞİSEL SINAVLAR ---

  // Kullanıcının kişisel sınavlarını getir
  Future<List<Map<String, dynamic>>> kisiselSinavlariGetir() async {
    final db = await database;
    return await db.query('kisisel_sinavlar', orderBy: 'sinav_tarihi ASC');
  }

  // Kişisel sınav ekle (yeni ID döner)
  Future<int> kisiselSinavEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('kisisel_sinavlar', row);
  }

  // Kişisel sınav güncelle
  Future<int> kisiselSinavGuncelle(Map<String, dynamic> row) async {
    final db = await database;
    final int id = row['id'];
    return await db.update(
      'kisisel_sinavlar',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Kişisel sınav sil (yerel id ile)
  Future<int> kisiselSinavSil(int id) async {
    final db = await database;
    return await db.delete(
      'kisisel_sinavlar',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Buluttan gelen kişisel sınavları yerele toplu yaz (temizle + ekle)
  Future<void> kisiselSinavlariTopluKaydet(
    List<Map<String, dynamic>> sinavlar,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('kisisel_sinavlar');
      for (var sinav in sinavlar) {
        await txn.insert('kisisel_sinavlar', sinav);
      }
    });
  }

  // ==========================================================================
  // QUIZ & SÖZLÜ TAKİBİ İŞLEMLERİ (Çizelge + Kolon + Not)
  // ==========================================================================

  // --- ÇİZELGELER ---

  // Çizelgeleri kolon sayısıyla birlikte getir (yeni eklenen önce)
  // kategori: 'quiz' | 'performans' | 'odev'
  Future<List<Map<String, dynamic>>> quizCizelgeleriGetir(
    String kategori,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.*,
        (SELECT COUNT(*) FROM quiz_kolonlari k WHERE k.cizelge_id = c.id) AS kolon_sayisi
      FROM quiz_cizelgeleri c
      WHERE c.kategori = ?
      ORDER BY c.id DESC
    ''',
      [kategori],
    );
  }

  // Yeni çizelge ekle (yeni id döner)
  Future<int> quizCizelgeEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('quiz_cizelgeleri', row);
  }

  // Çizelge sil (kolon ve notlar CASCADE ile silinir)
  Future<int> quizCizelgeSil(int id) async {
    final db = await database;
    return await db.delete(
      'quiz_cizelgeleri',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- KOLONLAR ---

  // Bir çizelgenin kolonlarını sıraya göre getir
  Future<List<Map<String, dynamic>>> quizKolonlariGetir(int cizelgeId) async {
    final db = await database;
    return await db.query(
      'quiz_kolonlari',
      where: 'cizelge_id = ?',
      whereArgs: [cizelgeId],
      orderBy: 'sira ASC, id ASC',
    );
  }

  // Yeni kolon ekle (yeni id döner)
  Future<int> quizKolonEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('quiz_kolonlari', row);
  }

  // Kolon başlığını/tipini güncelle
  Future<int> quizKolonGuncelle(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'quiz_kolonlari',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Kolon sil (notları CASCADE ile silinir)
  Future<int> quizKolonSil(int id) async {
    final db = await database;
    return await db.delete('quiz_kolonlari', where: 'id = ?', whereArgs: [id]);
  }

  // --- NOTLAR ---

  // Bir çizelgedeki tüm notları getir (kolon üzerinden JOIN)
  Future<List<Map<String, dynamic>>> quizNotlariGetir(int cizelgeId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT n.kolon_id, n.ogrenci_id, n.puan
      FROM quiz_notlari n
      JOIN quiz_kolonlari k ON n.kolon_id = k.id
      WHERE k.cizelge_id = ?
    ''',
      [cizelgeId],
    );
  }

  // Tek bir notu kaydet/güncelle. puan null ise notu siler (hücre boşaltma).
  Future<void> quizNotKaydet(int kolonId, int ogrenciId, int? puan) async {
    final db = await database;
    if (puan == null) {
      await db.delete(
        'quiz_notlari',
        where: 'kolon_id = ? AND ogrenci_id = ?',
        whereArgs: [kolonId, ogrenciId],
      );
      return;
    }
    await db.insert('quiz_notlari', {
      'kolon_id': kolonId,
      'ogrenci_id': ogrenciId,
      'puan': puan,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Bir kolonun tüm notlarını toplu kaydet (hızlı giriş için).
  // notlar: { ogrenciId: puan? }  -> puan null ise o öğrencinin notu silinir.
  Future<void> quizKolonNotlariniKaydet(
    int kolonId,
    Map<int, int?> notlar,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final giris in notlar.entries) {
        if (giris.value == null) {
          await txn.delete(
            'quiz_notlari',
            where: 'kolon_id = ? AND ogrenci_id = ?',
            whereArgs: [kolonId, giris.key],
          );
        } else {
          await txn.insert('quiz_notlari', {
            'kolon_id': kolonId,
            'ogrenci_id': giris.key,
            'puan': giris.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  // ==========================================================================
  // PROJE TAKİBİ İŞLEMLERİ
  // ==========================================================================

  // Tüm proje takip kayıtlarını getir (yeni eklenen önce)
  Future<List<Map<String, dynamic>>> projeTakipleriGetir() async {
    final db = await database;
    return await db.query('proje_takip', orderBy: 'id DESC');
  }

  // Proje takip kaydı ekle (yeni id döner)
  Future<int> projeTakipEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('proje_takip', row);
  }

  // Proje takip kaydı sil
  Future<int> projeTakipSil(int id) async {
    final db = await database;
    return await db.delete('proje_takip', where: 'id = ?', whereArgs: [id]);
  }

  // --- PROJE KRİTERLERİ ---

  Future<List<Map<String, dynamic>>> projeKriterleriGetir() async {
    final db = await database;
    return await db.query('proje_kriterleri', orderBy: 'sira ASC, id ASC');
  }

  Future<int> projeKriterEkle(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('proje_kriterleri', row);
  }

  Future<int> projeKriterGuncelle(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update(
      'proje_kriterleri',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> projeKriterSil(int id) async {
    final db = await database;
    return await db.delete('proje_kriterleri', where: 'id = ?', whereArgs: [id]);
  }

  // --- PROJE DEĞERLENDİRME (PUANLAR) ---

  // Bir proje kaydının kriter puanlarını getir: { kriterId: puan }
  Future<Map<int, int>> projePuanlariGetir(int projeId) async {
    final db = await database;
    final rows = await db.query(
      'proje_puanlari',
      where: 'proje_id = ?',
      whereArgs: [projeId],
    );
    final sonuc = <int, int>{};
    for (final r in rows) {
      sonuc[r['kriter_id'] as int] = r['puan'] as int;
    }
    return sonuc;
  }

  // Değerlendirmeyi kaydet: kriter puanları + teslim durumu + toplam
  Future<void> projeDegerlendirmeKaydet({
    required int projeId,
    required bool teslimEtti,
    required int toplamPuan,
    required Map<int, int> puanlar,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Önce eski puanları temizle
      await txn.delete(
        'proje_puanlari',
        where: 'proje_id = ?',
        whereArgs: [projeId],
      );
      for (final giris in puanlar.entries) {
        await txn.insert('proje_puanlari', {
          'proje_id': projeId,
          'kriter_id': giris.key,
          'puan': giris.value,
        });
      }
      await txn.update(
        'proje_takip',
        {
          'teslim_etti': teslimEtti ? 1 : 0,
          'toplam_puan': toplamPuan,
          'degerlendirildi': 1,
        },
        where: 'id = ?',
        whereArgs: [projeId],
      );
    });
  }
}

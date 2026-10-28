import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';
import '../../../core/storage/prefs_service.dart';
import 'ogretmen_tahta_deposu.dart';

/// İdarenin Ana Program'dan gönderdiği, öğretmenin telefonunda görünen
/// duyuru (28 Ekim 2026 kararı: uygulama açılınca, bildirim yok).
///
/// ## Güven
/// Ana Program duyuruyu Ed25519 ile imzalar. Açık anahtar tahta
/// karekodunun 7. alanında gelir ([OgretmenTahtaKaydi.anaProgramAnahtari]).
/// Buluttan gelen her duyurunun imzası BURADA doğrulanır; bulut ele geçse
/// de sahte "idare duyurusu" görünmez. Belgedeki `acik` alanına bakılmaz,
/// yalnız karekoddan gelen anahtar geçerli.
///
/// İmzalanan metin üç dilde aynı (functions/idare_duyurusu.js,
/// Ana Program `cekirdek/idare_duyurusu.py`); ortak örnek
/// `functions/test/veri/idare_duyurusu_ornek.json`.
class IdareDuyurusu {
  const IdareDuyurusu({
    required this.okulId,
    required this.id,
    required this.olusturma,
    required this.baslangic,
    required this.bitis,
    required this.baslik,
    required this.metin,
    this.okulAdi = '',
  });

  final String okulId;
  final String id;

  /// Unix saniyesi.
  final int olusturma;
  final int baslangic;
  final int bitis;
  final String baslik;
  final String metin;

  /// Gösterim için (karekoddan).
  final String okulAdi;

  static const String onek = 'SCDUYURU1';

  DateTime get olusturmaZamani => DateTime.fromMillisecondsSinceEpoch(olusturma * 1000);

  bool gorunurMu(DateTime simdi) {
    final sn = simdi.millisecondsSinceEpoch ~/ 1000;
    return baslangic <= sn && sn < bitis;
  }

  /// İmzalanan bayt dizisi.
  Uint8List get mesaj => Uint8List.fromList(utf8.encode(
        [onek, okulId, id, '$olusturma', '$baslangic', '$bitis', baslik, metin].join('\n'),
      ));

  /// Bulut belgesini okur ve imzasını [acik] anahtarla doğrular. Bozuk,
  /// başka okulun ya da imzası tutmayan belge için `null`.
  static IdareDuyurusu? dogrula(
    Map<String, dynamic> belge, {
    required Uint8List acik,
    required String okulId,
    String okulAdi = '',
  }) {
    int? sayi(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
    final d = belge;
    final olusturma = sayi(d['olusturma']);
    final baslangic = sayi(d['baslangic']);
    final bitis = sayi(d['bitis']);
    final id = d['id'];
    final baslik = d['baslik'];
    final metin = d['metin'];
    final imzaB64 = d['imza'];
    if (olusturma == null || baslangic == null || bitis == null) return null;
    if (id is! String || baslik is! String || metin is! String || imzaB64 is! String) return null;
    if (d['okulId'] != okulId) return null;

    final duyuru = IdareDuyurusu(
      okulId: okulId,
      id: id,
      olusturma: olusturma,
      baslangic: baslangic,
      bitis: bitis,
      baslik: baslik,
      metin: metin,
      okulAdi: okulAdi,
    );
    try {
      final imza = base64.decode(imzaB64);
      if (imza.length != 64 || acik.length != 32) return null;
      return ed.verify(ed.PublicKey(acik), duyuru.mesaj, imza) ? duyuru : null;
    } catch (_) {
      return null;
    }
  }
}

/// Kanal kimliği: `{okulId}_{SHA-256(anahtar) ilk 16 hane}`.
String idareKanali(String okulId, Uint8List acik) =>
    '${okulId}_${sha256.convert(acik).toString().substring(0, 16)}';

/// Öğretmenin kayıtlı okullarının idare duyuruları.
///
/// Maliyet: kanal başına en çok 10 belge okunur, 10 dakikada bir.
class IdareDuyurusuDeposu {
  IdareDuyurusuDeposu({
    OgretmenTahtaDeposu? tahtalar,
    Future<List<Map<String, dynamic>>> Function(String kanal)? kanalOku,
  })  : _tahtalar = tahtalar ?? OgretmenTahtaDeposu(),
        _kanalOku = kanalOku ?? _firestoredan;

  final OgretmenTahtaDeposu _tahtalar;
  final Future<List<Map<String, dynamic>>> Function(String kanal) _kanalOku;

  static const String _kapatilanlar = 'idare_duyurusu_kapatilan_v1';
  static const Duration _tazelik = Duration(minutes: 10);
  static final Map<String, (DateTime, List<Map<String, dynamic>>)> _onbellek = {};

  @visibleForTesting
  static void onbellegiBosalt() => _onbellek.clear();

  static Future<List<Map<String, dynamic>>> _firestoredan(String kanal) async {
    final client = FirestoreClient.instance;
    await client.ensureConfigured();
    final db = client.db;
    if (db == null) return const [];
    final snap = await db
        .collection('okul_duyurulari')
        .doc(kanal)
        .collection('duyurular')
        .orderBy('olusturma', descending: true)
        .limit(10)
        .get()
        .timeout(const Duration(seconds: 8));
    await client.recordQueryReads(snap.docs.length);
    return [for (final d in snap.docs) d.data()];
  }

  /// Görünür, kapatılmamış duyurular; yeniden eskiye.
  Future<List<IdareDuyurusu>> getir({DateTime? simdi}) async {
    final an = simdi ?? DateTime.now();
    final kapatilan = await _kapatilanlariOku();
    final sonuc = <IdareDuyurusu>[];
    for (final k in await _tahtalar.tumu()) {
      if (k.anaProgramAnahtari.isEmpty) continue;
      final Uint8List acik;
      try {
        acik = base64Url.decode(base64Url.normalize(k.anaProgramAnahtari));
      } catch (_) {
        continue;
      }
      final kanal = idareKanali(k.okulId, acik);
      final List<Map<String, dynamic>> belgeler;
      try {
        belgeler = await _kanaliGetir(kanal, an);
      } catch (e) {
        debugPrint('İdare duyurusu okunamadı ($kanal): $e');
        continue;
      }
      for (final b in belgeler) {
        final d = IdareDuyurusu.dogrula(b, acik: acik, okulId: k.okulId, okulAdi: k.okulGorunenAdi);
        if (d == null) {
          debugPrint('İdare duyurusu imzası tutmadı, gösterilmiyor: ${b['id']}');
          continue;
        }
        if (d.gorunurMu(an) && !kapatilan.contains(d.id)) sonuc.add(d);
      }
    }
    sonuc.sort((a, b) => b.olusturma.compareTo(a.olusturma));
    return sonuc;
  }

  Future<List<Map<String, dynamic>>> _kanaliGetir(String kanal, DateTime an) async {
    final onceki = _onbellek[kanal];
    if (onceki != null && an.difference(onceki.$1) < _tazelik) return onceki.$2;
    final yeni = await _kanalOku(kanal);
    _onbellek[kanal] = (an, yeni);
    return yeni;
  }

  /// "Tamam": bu telefonda bir daha gösterme.
  Future<void> kapat(String id) async {
    final prefs = await PrefsService.instance();
    if (prefs == null) return;
    final liste = prefs.getStringList(_kapatilanlar) ?? const [];
    // Liste sınırsız büyümesin; 60 günlük duyuru için 200 yeter.
    final yeni = [...liste.where((x) => x != id), id];
    await prefs.setStringList(_kapatilanlar, yeni.length > 200 ? yeni.sublist(yeni.length - 200) : yeni);
  }

  Future<Set<String>> _kapatilanlariOku() async {
    final prefs = await PrefsService.instance();
    return (prefs?.getStringList(_kapatilanlar) ?? const []).toSet();
  }
}

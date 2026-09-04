import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/gzip_asset.dart';

/// Bir belirli gün veya hafta.
class SpecialDay {
  final String ad;

  /// Çizelgedeki tarih ifadesi — "23 Nisan", "Eylül ayının 3. haftası".
  final String tarihMetni;

  /// sabit | aralik | kural
  final String tur;

  /// 1-12. Değişken tarihli bazı maddelerde null.
  final int? ay;
  final int? baslangicGun;
  final int? bitisGun;

  /// İki aya yayılan haftalarda bitiş ayı ("29 Ekim-4 Kasım").
  final int? bitisAy;

  /// Okulda pano/tören çalışması yapılan gün mü?
  ///
  /// Çizelgedeki 61 maddenin hepsi için pano hazırlanmaz; "Dünya
  /// Fikrî Mülkiyet Günü" anılır ama sınıflar çalışma yapmaz.
  final bool etkinlikli;

  const SpecialDay({
    required this.ad,
    required this.tarihMetni,
    required this.tur,
    this.ay,
    this.baslangicGun,
    this.bitisGun,
    this.bitisAy,
    this.etkinlikli = false,
  });

  factory SpecialDay.fromJson(Map<String, dynamic> j) => SpecialDay(
        ad: j['ad'] as String? ?? '',
        tarihMetni: j['tarihMetni'] as String? ?? '',
        tur: j['tur'] as String? ?? 'kural',
        ay: j['ay'] as int?,
        baslangicGun: j['baslangicGun'] as int?,
        bitisGun: j['bitisGun'] as int?,
        bitisAy: j['bitisAy'] as int?,
        etkinlikli: j['etkinlikli'] as bool? ?? false,
      );

  /// Tarihi kesin hesaplanabiliyor mu?
  ///
  /// "Mayıs ayının 2. pazarı" gibi kural tipi maddeler takvim yılına
  /// göre değişir; uydurmak yerine metin gösterilir.
  bool get kesinTarihli => tur != 'kural' && ay != null;

  /// [gun] bu maddenin kapsamında mı?
  bool kapsar(DateTime gun) {
    if (!kesinTarihli) return false;
    final b = baslangicGun;
    if (b == null) return false;

    if (tur == 'sabit') {
      return gun.month == ay && gun.day == b;
    }
    // aralik
    final s = bitisGun ?? b;
    if (bitisAy != null && bitisAy != ay) {
      // Ay atlayan hafta: "29 Ekim-4 Kasım"
      if (gun.month == ay && gun.day >= b) return true;
      if (gun.month == bitisAy && gun.day <= s) return true;
      return false;
    }
    return gun.month == ay && gun.day >= b && gun.day <= s;
  }
}

/// MEB Belirli Gün ve Haftalar çizelgesi.
///
/// ## Veri nereden geliyor
/// `assets/data/belirli_gun_hafta.json.gz` — MEB'in resmî çizelgesinden
/// `tool/build_belirli_gun_dataset.py` ile üretilir. 60 madde, 1.6 KB.
/// APK ile taşınır, Firestore'a çıkmaz.
class SpecialDaysRepository {
  static const _varlik = 'assets/data/belirli_gun_hafta.json';

  static List<SpecialDay>? _liste;
  static Future<void>? _yukleniyor;

  Future<void> _hazirla() async {
    if (_liste != null) return;
    _yukleniyor ??= _oku();
    await _yukleniyor;
  }

  Future<void> _oku() async {
    try {
      final ham = await GzipAsset.loadString(_varlik);
      final j = jsonDecode(ham) as Map<String, dynamic>;
      _liste = (j['maddeler'] as List? ?? [])
          .map((e) => SpecialDay.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SpecialDaysRepository: varlık okunamadı ($e)');
      _liste = const [];
    } finally {
      _yukleniyor = null;
    }
  }

  /// Öğretim yılı sırasına dizili tam çizelge (Eylül → Ağustos).
  Future<List<SpecialDay>> all() async {
    await _hazirla();
    return _liste!;
  }

  /// Belirli bir güne denk gelen maddeler.
  Future<List<SpecialDay>> forDay(DateTime gun) async {
    await _hazirla();
    return _liste!.where((e) => e.kapsar(gun)).toList();
  }

  /// Önümüzdeki [gunSayisi] gün içindeki maddeler.
  ///
  /// Öğretmen "bu ay ne var" diye bakar; yaklaşanları öne çıkarmak
  /// listenin tamamını taramaktan hızlı.
  Future<List<({SpecialDay madde, DateTime tarih})>> upcoming({
    DateTime? bugun,
    int gunSayisi = 30,
  }) async {
    await _hazirla();
    final bas = bugun ?? DateTime.now();
    final cikti = <({SpecialDay madde, DateTime tarih})>[];
    for (var i = 0; i < gunSayisi; i++) {
      final g = DateTime(bas.year, bas.month, bas.day + i);
      for (final m in _liste!.where((e) => e.kapsar(g))) {
        // Bir hafta birden çok güne yayılır; ilk gününü alırız.
        if (cikti.any((x) => x.madde.ad == m.ad)) continue;
        cikti.add((madde: m, tarih: g));
      }
    }
    return cikti;
  }

  /// Pano/tören çalışması yapılan günler.
  ///
  /// Öğretmen "hangi güne pano hazırlamam gerek" diye bakar; 61
  /// maddenin tamamını taramak yerine bu liste yeter.
  Future<List<SpecialDay>> withActivities() async {
    await _hazirla();
    return _liste!.where((e) => e.etkinlikli).toList();
  }

  /// Aya göre gruplanmış çizelge — ekranda başlıklarla göstermek için.
  Future<Map<int, List<SpecialDay>>> byMonth() async {
    await _hazirla();
    final harita = <int, List<SpecialDay>>{};
    for (final m in _liste!) {
      harita.putIfAbsent(m.ay ?? 0, () => []).add(m);
    }
    return harita;
  }

  @visibleForTesting
  static void resetCache() {
    _liste = null;
    _yukleniyor = null;
  }
}

/// Bir belirli gün için pano ve etkinlik içeriği.
///
/// ## İçerik nereden geliyor
/// [kaynak] alanı ayrımı taşır:
///   * `meb`   — MEB Temel Eğitim Genel Müdürlüğü etkinlik rehberinden
///   * `genel` — tarihsel gerçeklere dayanan, bu uygulama için
///               yazılmış içerik; resmî bir MEB yayını DEĞİLDİR
///
/// Ayrım ekranda gösterilir: uydurulmuş bir metni "MEB kaynaklı" gibi
/// sunmak, öğretmeni resmî evrakta yanlış bilgiye sürükler.
class PanoContent {
  final String ad;
  final String kaynak;
  final String ozet;
  final List<String> sloganlar;
  final List<PanoActivity> etkinlikler;
  final String panoBaslik;
  final List<String> program;
  final String mudurKonusmasi;
  final List<PanoSpeech> konusmalar;
  final List<PanoPoem> siirler;
  final List<PanoCard> panoKartlar;

  /// Tören içi bahçe/salon oyunları — etkinlik planında sırayla yürür.
  final List<PanoGame> oyunlar;

  /// Pano başlık sayfasına basılacak vecize (çoğunlukla Atatürk).
  final String vecize;
  final String vecizeKaynak;

  /// Günün anlamı — pano 2. sayfa paragrafları.
  final List<String> panoParagraflar;

  /// Tarih kutuları: başlık = yıl, metin = olay.
  final List<PanoCard> kronoloji;

  final String ogrenciGoreviBaslik;
  final String ogrenciGoreviYonerge;

  /// Kesilip asılacak kısa dörtlükler.
  final List<PanoPoem> panoDortlukler;

  /// “Biliyor muydunuz?” kartı — kısa olgular.
  final List<String> biliyorMuydunuz;

  /// “Önce ve Sonra” pano kurgusu için karşılaştırma çiftleri.
  ///
  /// Yalnızca bir değişimi anlatan günlerde bulunur (29 Ekim, İstiklâl
  /// Marşı). Orman Haftası'nın öncesi/sonrası yoktur; orada boş kalır ve
  /// o kurgu listelenmez.
  final List<PanoCompare> oncesiSonrasi;

  /// “Soru–Cevap Kapakçığı” kurgusu — kapağın altında cevap durur.
  final List<PanoQA> soruCevap;

  /// “Söz Panosu” kurgusu — öğrencinin tamamlayacağı söz kalıpları.
  final List<String> sozler;

  /// Günün kavram sözlüğü — pano ve tören öncesi ortak dil kurar.
  final List<PanoTerm> sozluk;

  /// Müdür konuşmasının ton seçenekleri (resmî / samimi / kısa).
  ///
  /// Boşsa [mudurKonusmasi] tek metin olarak kullanılır; okulların
  /// çoğu için tek metin yeterliydi, ton ayrımı sonradan eklendi.
  final List<PanoSpeech> mudurKonusmalari;

  const PanoContent({
    required this.ad,
    required this.kaynak,
    required this.ozet,
    this.sloganlar = const [],
    this.etkinlikler = const [],
    this.panoBaslik = '',
    this.program = const [],
    this.mudurKonusmasi = '',
    this.konusmalar = const [],
    this.siirler = const [],
    this.panoKartlar = const [],
    this.oyunlar = const [],
    this.vecize = '',
    this.vecizeKaynak = '',
    this.panoParagraflar = const [],
    this.kronoloji = const [],
    this.ogrenciGoreviBaslik = '',
    this.ogrenciGoreviYonerge = '',
    this.panoDortlukler = const [],
    this.biliyorMuydunuz = const [],
    this.oncesiSonrasi = const [],
    this.soruCevap = const [],
    this.sozler = const [],
    this.sozluk = const [],
    this.mudurKonusmalari = const [],
  });

  bool get mebKaynakli => kaynak == 'meb';

  /// Yatay afiş + kesme kartları + öğrenci formu üretilecek mi?
  bool get zenginPano =>
      vecize.trim().isNotEmpty && ogrenciGoreviBaslik.trim().isNotEmpty;

  bool get torenVar =>
      program.isNotEmpty ||
      mudurKonusmasi.trim().isNotEmpty ||
      konusmalar.isNotEmpty ||
      siirler.isNotEmpty;

  factory PanoContent.fromJson(Map<String, dynamic> j) => PanoContent(
        ad: j['ad'] as String? ?? '',
        kaynak: j['kaynak'] as String? ?? 'genel',
        ozet: j['ozet'] as String? ?? '',
        sloganlar: (j['sloganlar'] as List? ?? []).map((e) => '$e').toList(),
        etkinlikler: (j['etkinlikler'] as List? ?? [])
            .map((e) => PanoActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
        panoBaslik: j['panoBaslik'] as String? ?? '',
        program: (j['program'] as List? ?? []).map((e) => '$e').toList(),
        mudurKonusmasi: j['mudurKonusmasi'] as String? ?? '',
        konusmalar: (j['ogrenciKonusmalari'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoSpeech.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        siirler: (j['siirler'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoPoem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        panoKartlar: (j['panoKartlar'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoCard.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        oyunlar: (j['oyunlar'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoGame.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        vecize: j['vecize'] as String? ?? '',
        vecizeKaynak: j['vecizeKaynak'] as String? ?? '',
        panoParagraflar:
            (j['panoParagraflar'] as List? ?? []).map((e) => '$e').toList(),
        kronoloji: (j['kronoloji'] as List? ?? []).whereType<Map>().map((e) {
          final m = Map<String, dynamic>.from(e);
          return PanoCard(
            baslik: '${m['yil'] ?? m['baslik'] ?? ''}',
            metin: '${m['olay'] ?? m['metin'] ?? ''}',
          );
        }).toList(),
        ogrenciGoreviBaslik:
            ((j['ogrenciGorevi'] as Map?)?['baslik'] as String?) ?? '',
        ogrenciGoreviYonerge:
            ((j['ogrenciGorevi'] as Map?)?['yonerge'] as String?) ?? '',
        panoDortlukler: (j['panoDortlukler'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoPoem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        biliyorMuydunuz:
            (j['biliyorMuydunuz'] as List? ?? []).map((e) => '$e').toList(),
        oncesiSonrasi: (j['oncesiSonrasi'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoCompare.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        soruCevap: (j['soruCevap'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoQA.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        sozler: (j['sozler'] as List? ?? []).map((e) => '$e').toList(),
        sozluk: (j['sozluk'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoTerm.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        mudurKonusmalari: (j['mudurKonusmalari'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PanoSpeech.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// “Önce ve Sonra” karşılaştırma çifti.
///
/// Panonun solunda [oncesi], sağında [sonrasi] durur. [baslik] ikisinin
/// ortak konusudur ("Kadın hakları", "Okuryazarlık").
class PanoCompare {
  final String baslik;
  final String oncesi;
  final String sonrasi;

  const PanoCompare({
    required this.baslik,
    required this.oncesi,
    required this.sonrasi,
  });

  factory PanoCompare.fromJson(Map<String, dynamic> j) => PanoCompare(
        baslik: j['baslik'] as String? ?? '',
        oncesi: j['oncesi'] as String? ?? '',
        sonrasi: j['sonrasi'] as String? ?? '',
      );
}

/// Kapakçık kurgusu: üstte [soru], katlanan kapağın altında [cevap].
/// Sözlük maddesi — günün kavramları.
///
/// Soru–cevaptan ayrı tutuldu: burada tanım vardır, orada muhakeme.
/// "Darbe nedir" bir tanımdır; "darbe ile seçimin farkı nedir" bir
/// sorudur ve ayrı kurguya girer.
class PanoTerm {
  final String kavram;
  final String tanim;

  const PanoTerm({required this.kavram, required this.tanim});

  factory PanoTerm.fromJson(Map<String, dynamic> j) => PanoTerm(
        kavram: j['kavram'] as String? ?? '',
        tanim: j['tanim'] as String? ?? '',
      );
}

class PanoQA {
  final String soru;
  final String cevap;

  const PanoQA({required this.soru, required this.cevap});

  factory PanoQA.fromJson(Map<String, dynamic> j) => PanoQA(
        soru: j['soru'] as String? ?? '',
        cevap: j['cevap'] as String? ?? '',
      );
}

class PanoGame {
  final String ad;
  final String sunucu;
  final String yonerge;
  final String malzeme;

  const PanoGame({
    required this.ad,
    this.sunucu = '',
    this.yonerge = '',
    this.malzeme = '',
  });

  factory PanoGame.fromJson(Map<String, dynamic> j) => PanoGame(
        ad: j['ad'] as String? ?? '',
        sunucu: j['sunucu'] as String? ?? '',
        yonerge: j['yonerge'] as String? ?? '',
        malzeme: j['malzeme'] as String? ?? '',
      );
}

class PanoCard {
  final String baslik;
  final String metin;

  const PanoCard({required this.baslik, required this.metin});

  factory PanoCard.fromJson(Map<String, dynamic> j) => PanoCard(
        baslik: j['baslik'] as String? ?? '',
        metin: j['metin'] as String? ?? '',
      );
}

class PanoSpeech {
  final String baslik;
  final String metin;

  /// Hedef sınıf düzeyi: '1-2', '3-4', '5-8' veya 'hepsi'.
  /// Boşsa metin her düzeye uygundur (eski kayıtlar).
  final String duzey;

  /// Konuşma tonu: 'resmî', 'samimi', 'kısa'. Müdür konuşmalarında
  /// dolu, öğrenci konuşmalarında boştur.
  final String ton;

  const PanoSpeech({
    required this.baslik,
    required this.metin,
    this.duzey = '',
    this.ton = '',
  });

  factory PanoSpeech.fromJson(Map<String, dynamic> j) => PanoSpeech(
        baslik: j['baslik'] as String? ?? '',
        metin: j['metin'] as String? ?? '',
        duzey: j['duzey'] as String? ?? '',
        ton: j['ton'] as String? ?? '',
      );
}

class PanoPoem {
  final String baslik;
  final String metin;

  /// Hedef sınıf düzeyi: '1-2', '3-4', '5-8' veya 'hepsi'.
  /// Boşsa şiir her düzeye uygundur (eski kayıtlar).
  final String duzey;

  const PanoPoem({
    required this.baslik,
    required this.metin,
    this.duzey = '',
  });

  factory PanoPoem.fromJson(Map<String, dynamic> j) => PanoPoem(
        baslik: j['baslik'] as String? ?? '',
        metin: j['metin'] as String? ?? '',
        duzey: j['duzey'] as String? ?? '',
      );
}

/// Sınıf içi etkinlik — MEB rehberinin biçimi:
/// "Gerekli Malzemeler" + "Etkinliğin Uygulanışı".
class PanoActivity {
  final String ad;
  final List<String> malzeme;
  final List<String> adimlar;

  const PanoActivity({
    required this.ad,
    this.malzeme = const [],
    this.adimlar = const [],
  });

  factory PanoActivity.fromJson(Map<String, dynamic> j) => PanoActivity(
        ad: j['ad'] as String? ?? '',
        malzeme:
            (j['malzeme'] as List? ?? []).map((e) => '$e').toList(),
        adimlar:
            (j['adimlar'] as List? ?? []).map((e) => '$e').toList(),
      );
}

/// Pano içerikleri deposu.
class PanoContentRepository {
  static const _varlik = 'assets/data/pano_icerikleri.json';

  static Map<String, PanoContent>? _harita;
  static Future<void>? _yukleniyor;

  Future<void> _hazirla() async {
    if (_harita != null) return;
    _yukleniyor ??= _oku();
    await _yukleniyor;
  }

  Future<void> _oku() async {
    try {
      final ham = await GzipAsset.loadString(_varlik);
      final j = jsonDecode(ham) as Map<String, dynamic>;
      _harita = {
        for (final e in (j['icerikler'] as List? ?? []))
          (e as Map<String, dynamic>)['ad'] as String:
              PanoContent.fromJson(e),
      };
    } catch (e) {
      debugPrint('PanoContentRepository: varlık okunamadı ($e)');
      _harita = const {};
    } finally {
      _yukleniyor = null;
    }
  }

  /// Bir günün içeriği; yoksa null.
  Future<PanoContent?> forDay(String ad) async {
    await _hazirla();
    return _harita![ad];
  }

  /// İçeriği hazır olan gün adları.
  Future<Set<String>> availableDays() async {
    await _hazirla();
    return _harita!.keys.toSet();
  }

  @visibleForTesting
  static void resetCache() {
    _harita = null;
    _yukleniyor = null;
  }
}

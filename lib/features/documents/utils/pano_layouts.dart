/// Pano kurguları — bir belirli gün için on ayrı pano düzeni.
///
/// ## Neden on kurgu
///
/// Tek düzen "bu günü böyle kutlayın" der. Öğretmenin sınıfı, mekânı,
/// süresi ve malzemesi farklı; aynı panoyu herkes asamaz. Havuzdan
/// seçmek, tek plan dayatmaktan iyidir.
///
/// ## Neden hepsi her güne uymaz
///
/// [PanoKurgular.uygunOlanlar] her kurgunun önkoşulunu bilir. "Önce ve
/// Sonra" bir değişim anlatır — Orman Haftası'na oturmaz. "Tarih Şeridi"
/// kronoloji ister. Uymayan kurgu listelenmez; öğretmene çalışmayacak
/// bir seçenek gösterilmez.
///
/// ## Siyah-beyaz baskı
///
/// Renkler [PanoPalette] üzerinden gelir ve gri merdivene oturur.
/// Kurgular renge değil, **basamağa** güvenir: koyu zeminde beyaz metin,
/// açık zeminde siyah metin. Böylece s/b çıktıda düzen korunur.
library;

import '../data/special_days_repository.dart';

/// Bir pano kurgusu.
class PanoLayout {
  /// Öğretmene gösterilen ad.
  final String ad;

  /// Ne işe yaradığı — seçim ekranında tek satır.
  final String aciklama;

  /// Kaç A4 sayfası çıkar. 0 ise içeriğe göre değişir ([sayfaNotu] anlatır).
  final int sayfa;

  /// Hazırlık yükü: 'yok' | 'basit' | 'onceden'
  final String hazirlik;

  /// Öğrenci elle bir şey dolduruyor mu?
  ///
  /// Öğretmen "sınıfça yapılacak iş" ile "sadece asılacak" arasında
  /// ayrım yapabilsin diye ayrı tutulur.
  final bool ogrenciDoldurur;

  const PanoLayout({
    required this.ad,
    required this.aciklama,
    required this.sayfa,
    required this.hazirlik,
    this.ogrenciDoldurur = false,
  });

  /// Hazırlık yükünün okunur karşılığı.
  String get hazirlikMetni => switch (hazirlik) {
        'yok' => 'Hazırlık yok',
        'basit' => 'Basit hazırlık',
        'onceden' => 'Önceden hazırlık',
        _ => hazirlik,
      };

  /// Sayfa sayısının okunur karşılığı.
  String get sayfaNotu =>
      sayfa == 0 ? 'İçeriğe göre değişir' : '$sayfa sayfa';
}

/// Kurgu kimlikleri. Sıra öncelik değil, ayırt etme içindir.
enum PanoKurgu {
  devBaslik,
  tarihSeridi,
  onceSonra,
  merkezVecize,
  ogrenciAgaci,
  soruCevap,
  siirDuvari,
  biliyorMuydunuz,
  sozPanosu,
  kartDestesi,
  kavramSozlugu,
}

/// Kurgu tanımları ve hangi güne uyduğu.
class PanoKurgular {
  PanoKurgular._();

  static const tanimlar = <PanoKurgu, PanoLayout>{
    PanoKurgu.devBaslik: PanoLayout(
      ad: 'Dev Başlık Harfleri',
      aciklama: 'Günün adı harf harf; öğrenciler içini boyar, üst banda dizilir.',
      sayfa: 0, // harf sayısına göre değişir
      hazirlik: 'basit',
      ogrenciDoldurur: true,
    ),
    PanoKurgu.tarihSeridi: PanoLayout(
      ad: 'Tarih Şeridi',
      aciklama: 'Kronolojik kartlar; ipe mandallanır veya raptiyelenir.',
      sayfa: 2,
      hazirlik: 'basit',
    ),
    PanoKurgu.onceSonra: PanoLayout(
      ad: 'Önce ve Sonra',
      aciklama: 'Pano ikiye ayrılır; solda önceki durum, sağda sonrası.',
      sayfa: 2,
      hazirlik: 'basit',
    ),
    PanoKurgu.merkezVecize: PanoLayout(
      ad: 'Merkez Vecize',
      aciklama: 'Ortada vecize çerçevesi, çevresinde dört bilgi kartı.',
      sayfa: 2,
      hazirlik: 'yok',
    ),
    PanoKurgu.ogrenciAgaci: PanoLayout(
      ad: 'Öğrenci Ağacı',
      aciklama: 'Her öğrenci bir yaprak doldurup asar; yarım cümle tamamlanır.',
      sayfa: 2,
      hazirlik: 'basit',
      ogrenciDoldurur: true,
    ),
    PanoKurgu.soruCevap: PanoLayout(
      ad: 'Soru–Cevap Kapakçığı',
      aciklama: 'Üstte soru, katlanan kapağın altında cevap.',
      sayfa: 2,
      hazirlik: 'onceden',
    ),
    PanoKurgu.siirDuvari: PanoLayout(
      ad: 'Şiir Duvarı',
      aciklama: 'Düzeye ayrılmış dörtlükler; süsleme az, tipografi öne çıkar.',
      sayfa: 1,
      hazirlik: 'yok',
    ),
    PanoKurgu.biliyorMuydunuz: PanoLayout(
      ad: 'Biliyor muydunuz?',
      aciklama: 'Kısa olgular, tam genişlikte kartlarda. Uzaktan okunur.',
      sayfa: 1,
      hazirlik: 'yok',
    ),
    PanoKurgu.sozPanosu: PanoLayout(
      ad: 'Söz Panosu',
      aciklama: 'Her öğrenci bir söz verir ve imzalar; yıl sonunda okunur.',
      sayfa: 1,
      hazirlik: 'yok',
      ogrenciDoldurur: true,
    ),
    PanoKurgu.kartDestesi: PanoLayout(
      ad: 'Kart Destesi',
      aciklama: 'Günün anlamı dört büyük kartta; klasik ve güvenli düzen.',
      sayfa: 1,
      hazirlik: 'yok',
    ),
    PanoKurgu.kavramSozlugu: PanoLayout(
      ad: 'Kavram Sözlüğü',
      aciklama: 'Günün kavramları ve tanımları; panoya asılır, derste '
          'ortak dil kurar.',
      sayfa: 1,
      hazirlik: 'yok',
    ),
  };

  /// Bu gün için üretilebilecek kurgular.
  ///
  /// İçerikte karşılığı olmayan kurgu listelenmez: kronolojisi olmayan
  /// güne "Tarih Şeridi" göstermek, öğretmeni boş bir PDF'e götürür.
  static List<PanoKurgu> uygunOlanlar(SpecialDay gun, PanoContent? icerik) {
    final c = icerik;
    final uygun = <PanoKurgu>[];

    // Her gün için çalışır — günün adı yeterli.
    uygun.add(PanoKurgu.devBaslik);

    if ((c?.kronoloji.length ?? 0) >= 3) {
      uygun.add(PanoKurgu.tarihSeridi);
    }
    if ((c?.oncesiSonrasi.length ?? 0) >= 2) {
      uygun.add(PanoKurgu.onceSonra);
    }
    if (c?.vecize.trim().isNotEmpty == true) {
      uygun.add(PanoKurgu.merkezVecize);
    }
    if (c?.ogrenciGoreviBaslik.trim().isNotEmpty == true) {
      uygun.add(PanoKurgu.ogrenciAgaci);
    }
    if ((c?.soruCevap.length ?? 0) >= 4) {
      uygun.add(PanoKurgu.soruCevap);
    }
    if ((c?.panoDortlukler.length ?? 0) >= 3) {
      uygun.add(PanoKurgu.siirDuvari);
    }
    // Üç olgu bir panoyu doldurur; dördü şart koşmak zengin içerikli
    // günleri bile dışarıda bırakıyordu.
    if ((c?.biliyorMuydunuz.length ?? 0) >= 3) {
      uygun.add(PanoKurgu.biliyorMuydunuz);
    }
    if ((c?.sozler.length ?? 0) >= 1) {
      uygun.add(PanoKurgu.sozPanosu);
    }
    // Kart destesi her zaman üretilebilir; içerik yoksa da özetten
    // kart türetilir (bkz. _kartDestesi).
    uygun.add(PanoKurgu.kartDestesi);

    // Sözlük: dört kavramdan azı bir panoyu doldurmuyor.
    if ((c?.sozluk.length ?? 0) >= 4) {
      uygun.add(PanoKurgu.kavramSozlugu);
    }

    return uygun;
  }
}

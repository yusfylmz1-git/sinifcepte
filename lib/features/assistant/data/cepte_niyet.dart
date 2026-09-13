import '../../../core/utils/turkish_text.dart';

/// Cepte'nin anladığı iş türleri.
enum CepteNiyetTuru {
  /// Belge üretilir: yıllık plan.
  yillikPlan,

  /// Belge üretilir: günlük plan.
  gunlukPlan,

  /// Kazanım sorusu: "5. sınıf türkçe 3. hafta ne işleyeceğim".
  kazanimSor,

  /// Ekran açılır (üretim yok, öğretmen girdisi gerekiyor).
  ekranAc,

  /// Anlaşılamadı. Cepte TAHMİN ETMEZ, sorar.
  belirsiz,
}

/// Cepte'nin açabileceği ekranlar.
///
/// Uygulamada 32 ekran var ve öğretmen "ne nerede" bulamıyordu. Sohbet
/// bunları tek yerden erişilebilir kılar; liste büyüdükçe buraya eklenir.
enum CepteEkran {
  kazanimlar,
  dersIciKatilim,
  sinavIslemleri,
  rehberlik,
  digerEvraklar,
  ogretmenDosyasi,
  belirliGunler,
  sosyalKulupler,
  kurulTutanaklari,
  sinifim,
  dersProgrami,
  veliPaneli,
  devamsizlik,
  oturmaPlani,
  nobetciListesi,
  ogrenciListesi,
  ogretmenKadrosu,
}

/// Bir cümleden çıkarılan iş.
class CepteNiyet {
  const CepteNiyet({
    required this.tur,
    this.sinif,
    this.dersKodu,
    this.dersAdi,
    this.hafta,
    this.ekran,
    this.eksikler = const [],
  });

  final CepteNiyetTuru tur;
  final int? sinif;
  final String? dersKodu;
  final String? dersAdi;
  final int? hafta;
  final CepteEkran? ekran;

  /// İş yapılabilmesi için öğretmenden istenmesi gereken bilgiler.
  ///
  /// Boş değilse Cepte üretime GEÇMEZ; sorar. Yanlış belge basmaktansa
  /// bir soru sormak iyidir — bu uygulamanın çıktısı teftişe gidiyor.
  final List<String> eksikler;

  bool get hazir => tur != CepteNiyetTuru.belirsiz && eksikler.isEmpty;

  @override
  String toString() => 'CepteNiyet($tur, sinif=$sinif, ders=$dersKodu, '
      'hafta=$hafta, ekran=$ekran, eksik=$eksikler)';
}

/// Öğretmenin yazdığı cümleyi işe çevirir.
///
/// ## Neden model değil kural
/// Cihazda çalışan küçük bir dil modeli Türkçe eğitim jargonunda kazanım
/// UYDURABİLİR; bu uygulamanın en büyük riski yanlış resmî evrak basmak.
/// Kural tabanlı eşleme ise ya doğru anlar ya "anlamadım" der. APK da
/// büyümez, internet gerekmez.
class CepteCozumleyici {
  const CepteCozumleyici._();

  /// Ders adı/kısaltması → müfredat paketindeki ders kodu.
  ///
  /// Anahtarlar `trFold` ile katlanmış hâlde aranır; öğretmen "türkçe",
  /// "Turkce" veya "TÜRKÇE" yazabilir.
  static const Map<String, String> _dersEslemesi = {
    'turkce': 'TURKCE',
    'matematik': 'MAT',
    'mat': 'MAT',
    'fen bilimleri': 'FEN',
    'fen': 'FEN',
    'sosyal bilgiler': 'SOSYAL',
    'sosyal': 'SOSYAL',
    'hayat bilgisi': 'HAYAT',
    'ingilizce': 'INGILIZCE',
    'almanca': 'ALMANCA',
    'arapca': 'ARAPCA',
    'din kulturu': 'DIN',
    'din kulturu ve ahlak bilgisi': 'DIN',
    'dkab': 'DIN',
    'gorsel sanatlar': 'GORSEL',
    'gorsel': 'GORSEL',
    'muzik': 'MUZIK',
    'beden egitimi': 'BEDEN',
    'beden': 'BEDEN',
    'beden egitimi ve oyun': 'BEDEN_OYUN',
    'bilisim': 'BILISIM',
    'bilisim teknolojileri': 'BILISIM',
    'bty': 'BILISIM',
    'edebiyat': 'EDEBIYAT',
    'turk dili ve edebiyati': 'EDEBIYAT',
    'fizik': 'FIZIK',
    'kimya': 'KIMYA',
    'biyoloji': 'BIYOLOJI',
    'tarih': 'TARIH',
    'cografya': 'COGRAFYA',
    'felsefe': 'FELSEFE',
    'inkilap': 'INKILAP',
    'inkilap tarihi': 'INKILAP',
    'kuran': 'KURAN',
    'kuran-i kerim': 'KURAN',
    'peygamberimizin hayati': 'PEYGAMBER',
    'siyer': 'SIYER',
    'teknoloji ve tasarim': 'TEKNO_TASARIM',
    'trafik guvenligi': 'TRAFIK',
    'psikoloji': 'PSIKOLOJI',
    'sosyoloji': 'SOSYOLOJI',
    'mantik': 'MANTIK',
  };

  /// Kısa ve başka kelimelerin içinde geçebilen kodlar.
  ///
  /// "din" kelimesi "aydın"da, "fen" kelimesi "telefon"da, "mat"
  /// "matbaa"da eşleşmemeli. Bunlar kelime sınırıyla aranır — aynı
  /// tuzak `content_guard` içinde de yaşanmıştı ("top" / "toplantı").
  static const Set<String> _kelimeSiniriGerekenler = {
    'mat',
    'fen',
    'din',
    'beden',
    'gorsel',
    'sosyal',
    'bty',
    'dkab',
  };

  static const Map<CepteEkran, List<String>> _ekranAnahtarlari = {
    CepteEkran.kazanimlar: ['kazanim', 'mufredat', 'konu'],
    CepteEkran.dersIciKatilim: [
      'ders ici katilim',
      'katilim',
      'arti eksi',
      'yildiz',
    ],
    CepteEkran.sinavIslemleri: ['sinav', 'not girisi', 'quiz', 'yazili'],
    CepteEkran.rehberlik: ['rehberlik', 'bep', 'ozel egitim'],
    CepteEkran.digerEvraklar: ['diger evrak', 'evraklar', 'belge'],
    CepteEkran.ogretmenDosyasi: ['ogretmen dosyasi', 'ozluk'],
    CepteEkran.belirliGunler: ['belirli gun', 'pano', 'belirli hafta'],
    CepteEkran.sosyalKulupler: ['kulup', 'sosyal kulup', 'ek-4'],
    CepteEkran.kurulTutanaklari: [
      'zumre',
      'sok',
      'kurul',
      'tutanak',
    ],
    CepteEkran.sinifim: ['sinifim', 'sinif yonetimi'],
    CepteEkran.dersProgrami: ['ders programi', 'program', 'haftalik program'],
    CepteEkran.veliPaneli: ['veli', 'veli paneli', 'veli mesaj', 'duyuru'],
    CepteEkran.devamsizlik: ['devamsizlik', 'yoklama', 'gelmeyenler'],
    CepteEkran.oturmaPlani: ['oturma plani', 'kroki', 'oturma duzeni'],
    CepteEkran.nobetciListesi: ['nobetci', 'nobet'],
    CepteEkran.ogrenciListesi: ['ogrenci listesi', 'sinif listesi'],
    CepteEkran.ogretmenKadrosu: [
      'ogretmen kadrosu',
      'ogretmen ekle',
      'derse giren',
    ],
  };

  /// Cümleyi çözümler.
  static CepteNiyet coz(String cumle) {
    final metin = trFold(cumle.trim());
    if (metin.isEmpty) {
      return const CepteNiyet(tur: CepteNiyetTuru.belirsiz);
    }

    final sinif = _sinifBul(metin);
    final ders = _dersBul(metin);
    final hafta = _haftaBul(metin);

    // 1. Belge üretimi — en belirgin niyet.
    final yillik = _gecer(metin, ['yillik plan', 'yillik']);
    final gunluk = _gecer(metin, ['gunluk plan', 'gunluk ders plani', 'gunluk']);

    if (yillik || gunluk) {
      final tur =
          yillik ? CepteNiyetTuru.yillikPlan : CepteNiyetTuru.gunlukPlan;
      final eksik = <String>[];
      if (sinif == null) eksik.add('sinif');
      if (ders == null) eksik.add('ders');
      return CepteNiyet(
        tur: tur,
        sinif: sinif,
        dersKodu: ders,
        hafta: hafta,
        eksikler: eksik,
      );
    }

    // 2. Kazanım sorusu: hafta bilgisi varsa ve plan istenmiyorsa.
    if (_gecer(metin, ['ne isleyecegim', 'ne islenecek', 'hangi kazanim']) ||
        (hafta != null && _gecer(metin, ['kazanim', 'konu']))) {
      final eksik = <String>[];
      if (sinif == null) eksik.add('sinif');
      if (ders == null) eksik.add('ders');
      return CepteNiyet(
        tur: CepteNiyetTuru.kazanimSor,
        sinif: sinif,
        dersKodu: ders,
        hafta: hafta,
        eksikler: eksik,
      );
    }

    // 3. Ekran açma — en uzun anahtar kazanır ki "veli" isteği
    //    "veli paneli"ne, "ogrenci listesi" de kendi ekranına gitsin.
    CepteEkran? enIyi;
    var enUzun = 0;
    _ekranAnahtarlari.forEach((ekran, anahtarlar) {
      for (final a in anahtarlar) {
        if (_gecer(metin, [a]) && a.length > enUzun) {
          enIyi = ekran;
          enUzun = a.length;
        }
      }
    });
    if (enIyi != null) {
      return CepteNiyet(
        tur: CepteNiyetTuru.ekranAc,
        ekran: enIyi,
        sinif: sinif,
        dersKodu: ders,
      );
    }

    return CepteNiyet(
      tur: CepteNiyetTuru.belirsiz,
      sinif: sinif,
      dersKodu: ders,
      hafta: hafta,
    );
  }

  /// "5. sınıf", "5.sinif", "5-A", "5a" → 5
  static int? _sinifBul(String katlanmis) {
    final desenler = [
      RegExp(r'(\d{1,2})\s*\.?\s*sinif'),
      RegExp(r'(\d{1,2})\s*[-/]\s*[a-z]\b'),
      RegExp(r'\b(\d{1,2})[a-z]\b'),
    ];
    for (final d in desenler) {
      final m = d.firstMatch(katlanmis);
      if (m == null) continue;
      final n = int.tryParse(m.group(1) ?? '');
      if (n != null && n >= 1 && n <= 12) return n;
    }
    return null;
  }

  /// "3. hafta" → 3 · "bu hafta" → null (takvimden okunur)
  static int? _haftaBul(String katlanmis) {
    final m = RegExp(r'(\d{1,2})\s*\.?\s*hafta').firstMatch(katlanmis);
    final n = int.tryParse(m?.group(1) ?? '');
    if (n != null && n >= 1 && n <= 40) return n;
    return null;
  }

  static String? _dersBul(String katlanmis) {
    String? bulunan;
    var enUzun = 0;
    // En UZUN eşleşme kazanır: "beden egitimi ve oyun" yazan öğretmen
    // BEDEN'e değil BEDEN_OYUN'a gitmeli.
    _dersEslemesi.forEach((ad, kod) {
      if (ad.length > enUzun && _gecer(katlanmis, [ad])) {
        bulunan = kod;
        enUzun = ad.length;
      }
    });
    return bulunan;
  }

  /// Anahtarlardan biri metinde geçiyor mu?
  static bool _gecer(String katlanmis, List<String> anahtarlar) {
    for (final ham in anahtarlar) {
      final a = trFold(ham);
      if (a.isEmpty) continue;
      if (_kelimeSiniriGerekenler.contains(a)) {
        final desen = RegExp('(^|[^a-z0-9])${RegExp.escape(a)}([^a-z0-9]|\$)');
        if (desen.hasMatch(katlanmis)) return true;
      } else if (katlanmis.contains(a)) {
        return true;
      }
    }
    return false;
  }
}

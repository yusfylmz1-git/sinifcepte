/// Hata denetimi: kodda daha önce hata çıkarmış kalıpları tarar.
///
/// ## Neden
///
/// Analizci (`flutter analyze`) dil kurallarını denetler ama bu projede
/// telefonda görülen hataların çoğu analizcinin bakmadığı kalıplardan
/// çıktı: sayfadan çıkınca `setState`, boş sınıfta sıfıra bölme, Türkçe
/// `İ`/`ı` harfi, eleman bulunamayınca `firstWhere`. Bu araç onları
/// dosya ve satırıyla listeler.
///
/// İki derece var:
///   * **kapı**: uygulamayı düşüren ya da kırmızı hata ekranı açan kalıp.
///     `test/hata_denetimi_test.dart` bunlarda yeni bulgu girerse kırılır.
///   * **inceleme**: çoğu zaman zararsız, bazen hata. Rapor edilir, test
///     kırılmaz; denetimde tek tek okunur.
///
/// Bilerek bırakılan yer satırın sonuna ya da hemen üstüne
/// `// denetim: <kural> — gerekçe` yazılarak susturulur. Gerekçe
/// yazılmadan susturmak, kuralı silmekle aynı şeydir.
///
/// Çalıştırma:
///   dart run tool/hata_denetimi.dart              (kapı + özet)
///   dart run tool/hata_denetimi.dart --hepsi      (inceleme dahil, satır satır)
///   dart run tool/hata_denetimi.dart --kural=turkce-harf
///
/// Metin ve yorum içindeki kalıplara bakılmaz: tarayıcı önce kaynağın
/// yorumlarını ve metin içlerini boşlukla örter (`${...}` içi kod sayılır).
library;

import 'dart:io';

enum Derece { kapi, inceleme }

class Kural {
  const Kural(this.kod, this.derece, this.baslik, this.neden);

  final String kod;
  final Derece derece;
  final String baslik;
  final String neden;
}

const List<Kural> kurallar = [
  Kural(
    'await-setstate',
    Derece.kapi,
    'await ya da geri çağırmadan sonra mounted denetimsiz setState',
    'Öğretmen işlem sürerken sayfadan çıkarsa "setState() called after '
        'dispose()" hatası düşer. await ile setState arasına '
        '`if (!mounted) return;` konmalı.',
  ),
  Kural(
    'await-state',
    Derece.kapi,
    'StateNotifier içinde await sonrası mounted denetimsiz `state =`',
    'Sağlayıcı okuma sürerken kapanırsa (hesap değişimi, sayfa kapanışı) '
        '"Tried to use X after dispose" hatası düşer (18 Ekim).',
  ),
  Kural(
    'sifira-bolme',
    Derece.kapi,
    'paydası denetlenmeyen bölme tamsayıya çevriliyor',
    'Payda 0 ise sonuç Infinity/NaN olur; round()/toInt() bunu '
        'UnsupportedError ile düşürür, `~/` 0 ile hata fırlatır, '
        'toStringAsFixed "NaN" yazar. Boş sınıfta, öğrencisiz sınavda ekran '
        'çöker.',
  ),
  Kural(
    'orelse-yok',
    Derece.kapi,
    'firstWhere/singleWhere/lastWhere orElse olmadan',
    'Aranan eleman yoksa "Bad state: No element" fırlatır. Silinmiş ders, '
        'değişmiş liste, buluttan eksik gelen kayıt bunu tetikler. '
        'firstWhereOrNull ya da orElse kullanılmalı.',
  ),
  Kural(
    'isolate-kapanis',
    Derece.kapi,
    'Isolate.run/compute kapanışla çağrılıyor',
    'Kapanış örnek yönteminde yaratılınca çevresini (this, sağlayıcı) '
        'taşır; telefonda "object is unsendable" ile düşer, düz test '
        'çalıştırıcısı bunu göstermez (bkz. seeding_isolate_test).',
  ),
  Kural(
    'kapatilmayan',
    Derece.kapi,
    'AnimationController/Timer/StreamSubscription kapatılmıyor',
    'Sayfa kapanınca saat ya da dinleyici çalışmaya devam eder: kapanmış '
        'sayfaya yazar, "disposed with an active Ticker" hatası, pil ve '
        'bellek kaybı.',
  ),
  Kural(
    'denetleyici-sizinti',
    Derece.inceleme,
    'TextEditingController/FocusNode/ScrollController dispose edilmiyor',
    'Bellek sızıntısı; tek başına çökertmez. Uzun açık kalan sayfalarda '
        'önemli.',
  ),
  Kural(
    'bos-liste',
    Derece.inceleme,
    '.first/.last/.single/.reduce denetimsiz',
    'Liste boşsa "Bad state: No element". Yakında isEmpty/length denetimi '
        'görülmeyen kullanımlar.',
  ),
  Kural(
    'parse',
    Derece.inceleme,
    'int/double/DateTime.parse değişkenle',
    'Biçim bozuksa FormatException. Kullanıcı girdisi ya da buluttan gelen '
        'veri için tryParse kullanılmalı.',
  ),
  Kural(
    'turkce-buyuk',
    Derece.kapi,
    'toUpperCase (Türkçe "i" → "I")',
    'Resmî belgede "Ali" "ALI", "Pazartesi" "PAZARTESI" basılıyordu. '
        'Ekran ve belge metninde `.toUpperTr()`. Kod (veli kodu, ders kodu) '
        'büyütülüyorsa toUpperCase doğrudur; gerekçeyle susturulur.',
  ),
  Kural(
    'turkce-kucuk',
    Derece.inceleme,
    'toLowerCase',
    '"İ".toLowerCase() iki kod noktası verir, "I" → "i" olur ("ı" değil). '
        'Arama/karşılaştırmada trFold/trContains, gösterimde trLower.',
  ),
  Kural(
    'bos-catch',
    Derece.inceleme,
    'boş catch / catchError',
    'Hata sessizce yutulur: öğretmen düğmeye basar, hiçbir şey olmaz, '
        'kayıt da kalmaz.',
  ),
  Kural(
    'ham-hata',
    Derece.inceleme,
    'kullanıcıya ham hata metni',
    'Ekrana "Exception: PlatformException(...)" gibi İngilizce teknik metin '
        'basılır. Öğretmenin anlayacağı cümle + günlüğe ham hata.',
  ),
  Kural(
    'zorla-harita',
    Derece.inceleme,
    'harita/liste erişimi `]!` ile zorlanıyor',
    'Anahtar yoksa "Null check operator used on a null value".',
  ),
  Kural(
    'substring',
    Derece.inceleme,
    'substring ile kesme',
    'Metin beklenenden kısaysa RangeError (boş ad, tek harfli soyad).',
  ),
  Kural(
    'zaman-bombasi',
    Derece.inceleme,
    'kodda sabit yıl',
    'Takvim ilerleyince kod değişmeden yanlış sonuç verir. Yıllık tablo '
        'ise bilerek; değilse bugünün tarihinden türetilmeli.',
  ),
];

class Bulgu {
  Bulgu(this.kural, this.dosya, this.satir, this.metin);

  final String kural;
  final String dosya;
  final int satir;
  final String metin;

  @override
  String toString() => '$dosya:$satir  $metin';
}

/// [kok] altındaki tüm `.dart` dosyalarını tarar.
List<Bulgu> denetle(Directory kok) {
  final dosyalar = kok
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final metinler = {
    for (final f in dosyalar)
      f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
  };
  final sabitler = <String>{
    for (final m in metinler.values) ...sayisalSabitler(m),
  };
  return [
    for (final e in metinler.entries)
      ...denetleKaynak(e.key, e.value, sabitler: sabitler),
  ];
}

/// `const double eokulOran = …`, `static const int adimSn = 30` gibi sıfır
/// olmayan sayısal sabitlerin adları. Bunlara bölmek tehlikesiz.
Set<String> sayisalSabitler(String metin) => {
      for (final m in _sabitDeseni.allMatches(metin)) m.group(1)!,
    };

final _sabitDeseni = RegExp(
  r'\bconst\s+(?:(?:double|int|num)\s+)?([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*'
  r'(?:[1-9][\d.]*|0\.\d*[1-9]|[A-Za-z_$][A-Za-z0-9_$]*\s*/\s*[A-Za-z_$])',
);

/// Tek bir kaynağı tarar. Testler örnek metinle doğrudan çağırır.
List<Bulgu> denetleKaynak(
  String yol,
  String metin, {
  Set<String> sabitler = const {},
}) {
  final k = _Kaynak(yol, metin);
  final t = _Tarayici(k, {...sabitler, ...sayisalSabitler(metin)})..tara();
  final gorulen = <String>{};
  return [
    for (final b in t.bulgular)
      if (!k.susturuldu(b.kural, b.satir) &&
          gorulen.add('${b.kural}:${b.satir}'))
        b,
  ];
}

// ---------------------------------------------------------------------------
// Kaynak: yorum ve metin içleri örtülmüş kopya
// ---------------------------------------------------------------------------

class _Cerceve {
  _Cerceve.kod(this.aradeger)
      : kodMu = true,
        tirnak = 0,
        uclu = false,
        ham = false,
        bas = 0;
  _Cerceve.metin(this.tirnak, this.uclu, this.ham, this.bas)
      : kodMu = false,
        aradeger = false;

  final bool kodMu;
  final bool aradeger;
  final int tirnak;
  final bool uclu;
  final bool ham;
  final int bas;
  int derinlik = 0;
}

class _Kaynak {
  _Kaynak(this.yol, this.ham) {
    satirlar = ham.split('\n');
    satirBaslari = [0];
    for (var i = 0; i < ham.length; i++) {
      if (ham.codeUnitAt(i) == 10) satirBaslari.add(i + 1);
    }
    kod = _ort();
  }

  final String yol;
  final String ham;
  late final List<String> satirlar;
  late final List<int> satirBaslari;
  late final String kod;

  /// Metin sabitlerinin ham kaynaktaki aralıkları (tırnaklar hariç).
  final List<(int, int)> metinler = [];

  int satirNo(int konum) {
    var a = 0, z = satirBaslari.length - 1;
    while (a < z) {
      final m = (a + z + 1) >> 1;
      if (satirBaslari[m] <= konum) {
        a = m;
      } else {
        z = m - 1;
      }
    }
    return a + 1;
  }

  String satirMetni(int no) => satirlar[no - 1].trim();

  /// `// denetim-dosya: <kural> — gerekçe`: tüm dosya için (hesap dosyaları).
  static final _dosyaSusturma =
      RegExp(r'//\s*denetim-dosya:\s*([a-z\-]+(?:\s*,\s*[a-z\-]+)*)');

  static final _susturma = RegExp(r'//\s*denetim:\s*([a-z\-]+(?:\s*,\s*[a-z\-]+)*)');

  /// Satırın kendisinde ya da hemen üstündeki yorum bloğunda
  /// `// denetim: <kural>` var mı?
  bool susturuldu(String kural, int satir) {
    final dosya = _dosyaSusturma.firstMatch(ham);
    if (dosya != null &&
        dosya.group(1)!.split(',').map((x) => x.trim()).contains(kural)) {
      return true;
    }
    bool icerir(String s) {
      final m = _susturma.firstMatch(s);
      if (m == null) return false;
      return m.group(1)!.split(',').map((x) => x.trim()).contains(kural);
    }

    if (icerir(satirlar[satir - 1])) return true;
    for (var i = satir - 2; i >= 0; i--) {
      final s = satirlar[i].trim();
      if (!s.startsWith('//')) break;
      if (icerir(s)) return true;
    }
    return false;
  }

  static bool _kimlik(int c) =>
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95 ||
      c == 36;

  String _ort() {
    final s = ham;
    final n = s.length;
    final b = s.codeUnits.toList();
    void sil(int a, int z) {
      for (var k = a; k < z && k < n; k++) {
        if (b[k] != 10) b[k] = 32;
      }
    }

    final yigin = <_Cerceve>[_Cerceve.kod(false)];
    var i = 0;
    while (i < n) {
      final ust = yigin.last;
      final c = s.codeUnitAt(i);
      if (ust.kodMu) {
        if (c == 0x2F && i + 1 < n) {
          final d = s.codeUnitAt(i + 1);
          if (d == 0x2F) {
            final e = s.indexOf('\n', i);
            final z = e == -1 ? n : e;
            sil(i, z);
            i = z;
            continue;
          }
          if (d == 0x2A) {
            var derin = 1;
            var k = i + 2;
            while (k < n && derin > 0) {
              if (s.startsWith('/*', k)) {
                derin++;
                k += 2;
              } else if (s.startsWith('*/', k)) {
                derin--;
                k += 2;
              } else {
                k++;
              }
            }
            sil(i, k);
            i = k;
            continue;
          }
        }
        if (c == 0x27 || c == 0x22) {
          final hamMetin = i > 0 &&
              s.codeUnitAt(i - 1) == 0x72 &&
              (i < 2 || !_kimlik(s.codeUnitAt(i - 2)));
          final uclu = s.startsWith(String.fromCharCodes([c, c, c]), i);
          final acilis = uclu ? 3 : 1;
          yigin.add(_Cerceve.metin(c, uclu, hamMetin, i + acilis));
          i += acilis;
          continue;
        }
        if (ust.aradeger) {
          if (c == 0x7B) {
            ust.derinlik++;
          } else if (c == 0x7D) {
            if (ust.derinlik == 0) {
              yigin.removeLast();
              b[i] = 32;
              i++;
              continue;
            }
            ust.derinlik--;
          }
        }
        i++;
        continue;
      }

      // Metin içi.
      if (!ust.ham && c == 0x5C) {
        sil(i, i + 2);
        i += 2;
        continue;
      }
      final kapanis = ust.uclu
          ? String.fromCharCodes([ust.tirnak, ust.tirnak, ust.tirnak])
          : String.fromCharCode(ust.tirnak);
      if (s.startsWith(kapanis, i)) {
        metinler.add((ust.bas, i));
        yigin.removeLast();
        i += kapanis.length;
        continue;
      }
      if (!ust.uclu && c == 10) {
        // Kapanmamış metin: satır sonunda bırak (bozuk kaynakta takılmasın).
        metinler.add((ust.bas, i));
        yigin.removeLast();
        continue;
      }
      if (!ust.ham && c == 0x24 && i + 1 < n && s.codeUnitAt(i + 1) == 0x7B) {
        sil(i, i + 2);
        yigin.add(_Cerceve.kod(true));
        i += 2;
        continue;
      }
      if (c != 10) b[i] = 32;
      i++;
    }
    return String.fromCharCodes(b);
  }
}

// ---------------------------------------------------------------------------
// Tarayıcı
// ---------------------------------------------------------------------------

class _Jeton {
  _Jeton(this.m, this.konum);
  final String m;
  final int konum;
}

class _Islev {
  _Islev(this.geriCagirma, int bas) : sonAwait = geriCagirma ? bas : -1;
  final bool geriCagirma;
  int sonAwait;
  bool mountedSonra = false;
}

class _Kapsam {
  _Kapsam(this.tur, this.islev, [this.dis, this.oncekiDal]);
  final String tur; // islev | blok | sinif
  final _Islev? islev;

  /// Blok açılırken dıştaki işlevin durumu. Blok `return` ile biterse
  /// (`if (!mounted) { await x.kapat(); return; }`) içindeki await sonraki
  /// kodu etkilemez; durum buna geri alınır.
  final (_Islev, int, bool)? dis;

  /// `else` dalıysa: `if` dalının çıkış durumu. `if` dalındaki await
  /// `else` dalını etkilemez; iki dal kapanınca birleştirilir.
  final (int, bool)? oncekiDal;
}

/// Kapanan son bloğun işlevi, giriş ve çıkış durumu (else dalı için).
class _SonBlok {
  _SonBlok(this.f, this.giris, this.cikis, this.kapa);
  final _Islev f;
  final (int, bool) giris;
  final (int, bool) cikis;
  final int kapa;
}

/// Geri çağırmanın sonradan, sayfa kapanmış olabilirken çalıştığı çağrılar.
const _geriCagirmalar = {
  'then',
  'whenComplete',
  'catchError',
  'delayed',
  'listen',
  'periodic',
  'Timer',
  'microtask',
};

const _kontrolAnahtarlari = {'if', 'for', 'while', 'switch', 'catch'};

final _jetonDeseni = RegExp(
  r'[A-Za-z_$][A-Za-z0-9_$]*|\d[\d.]*(?:e[+-]?\d+)?|=>|==|!=|~/|<=|>=|\?\?|\?\.|\.\.|&&|\|\||\S',
);

final _sayi = RegExp(r'^\d');
final _kimlikDeseni = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

class _Tarayici {
  _Tarayici(this.k, this.sabitler)
      : j = [
          for (final m in _jetonDeseni.allMatches(k.kod))
            _Jeton(m.group(0)!, m.start),
        ];

  final _Kaynak k;
  final List<_Jeton> j;
  final Set<String> sabitler;
  final List<Bulgu> bulgular = [];

  /// Her `(` jetonunun eşi olan `)` jetonu ve tersi.
  late final Map<int, int> _es = _eslestir();

  bool get _notifierDosyasi => k.kod.contains('extends StateNotifier');

  void _ekle(String kural, int jeton) {
    final satir = k.satirNo(j[jeton].konum);
    bulgular.add(Bulgu(kural, k.yol, satir, k.satirMetni(satir)));
  }

  void _ekleKonum(String kural, int konum) {
    final satir = k.satirNo(konum);
    bulgular.add(Bulgu(kural, k.yol, satir, k.satirMetni(satir)));
  }

  String _m(int i) => i >= 0 && i < j.length ? j[i].m : '';

  Map<int, int> _eslestir() {
    final es = <int, int>{};
    final yigin = <int>[];
    for (var i = 0; i < j.length; i++) {
      final m = j[i].m;
      if (m == '(' || m == '[' || m == '{') {
        yigin.add(i);
      } else if (m == ')' || m == ']' || m == '}') {
        if (yigin.isNotEmpty) {
          final a = yigin.removeLast();
          es[a] = i;
          es[i] = a;
        }
      }
    }
    return es;
  }

  /// `(` jetonundan önceki ad (çağrılan işlev ya da anahtar sözcük).
  String _parenAdi(int ac) {
    final o = _m(ac - 1);
    return _kimlikDeseni.hasMatch(o) ? o : '';
  }

  void tara() {
    _kapsamlar();
    _bolme();
    _orElse();
    _kapatilmayan();
    _bosListe();
    _parse();
    _turkceHarf();
    _bosCatch();
    _hamHata();
    _zorlaHarita();
    _substring();
    _zamanBombasi();
  }

  // -- await-setstate / await-state ----------------------------------------

  void _kapsamlar() {
    final kapsam = <_Kapsam>[];
    final acikParen = <int>[];
    _Islev? islev() {
      for (var i = kapsam.length - 1; i >= 0; i--) {
        final f = kapsam[i].islev;
        if (f != null) return f;
        if (kapsam[i].tur == 'sinif') return null;
      }
      return null;
    }

    // Ok gövdeli geri çağırma: `.then((_) => setState(...))`.
    final okGeriCagirma = <int>[]; // açık `(` jetonları
    _SonBlok? sonBlok;

    for (var i = 0; i < j.length; i++) {
      final m = j[i].m;
      if (m == '(') {
        acikParen.add(i);
        if (_geriCagirmalar.contains(_parenAdi(i))) okGeriCagirma.add(i);
        continue;
      }
      if (m == ')') {
        if (acikParen.isNotEmpty) {
          final ac = acikParen.removeLast();
          if (okGeriCagirma.isNotEmpty && okGeriCagirma.last == ac) {
            okGeriCagirma.removeLast();
            _okGeriCagirmaDenetle(ac, i);
          }
        }
        continue;
      }
      if (m == '{') {
        final tur = _suslu(i);
        if (tur == 'islev') {
          final ic = acikParen.isEmpty ? '' : _parenAdi(acikParen.last);
          kapsam.add(_Kapsam('islev', _Islev(_geriCagirmalar.contains(ic), i)));
        } else {
          final f = tur == 'blok' ? islev() : null;
          (int, bool)? oncekiDal;
          final sb = sonBlok;
          if (f != null && sb != null && sb.f == f && _elseDali(i, sb.kapa)) {
            oncekiDal = sb.cikis;
            f.sonAwait = sb.giris.$1;
            f.mountedSonra = sb.giris.$2;
          }
          kapsam.add(_Kapsam(
            tur,
            null,
            f == null ? null : (f, f.sonAwait, f.mountedSonra),
            oncekiDal,
          ));
        }
        continue;
      }
      if (m == '}') {
        if (kapsam.isNotEmpty) {
          final cikan = kapsam.removeLast();
          final dis = cikan.dis;
          if (dis != null) {
            final f = dis.$1;
            if (_donusleBiter(i)) {
              f.sonAwait = dis.$2;
              f.mountedSonra = dis.$3;
            }
            final once = cikan.oncekiDal;
            if (once != null) {
              final tehlikeli = (once.$1 >= 0 && !once.$2) ||
                  (f.sonAwait >= 0 && !f.mountedSonra);
              f.sonAwait = once.$1 > f.sonAwait ? once.$1 : f.sonAwait;
              if (tehlikeli) f.mountedSonra = false;
            }
            sonBlok = _SonBlok(
              f,
              (dis.$2, dis.$3),
              (f.sonAwait, f.mountedSonra),
              i,
            );
          }
        }
        continue;
      }
      if (m == 'Isolate' || m == 'compute') {
        _isolate(i, kapsam.any((x) => x.tur == 'sinif'));
        continue;
      }
      if (m == 'await') {
        final f = islev();
        if (f != null) {
          f.sonAwait = i;
          f.mountedSonra = false;
        }
        continue;
      }
      if (m == 'mounted') {
        islev()?.mountedSonra = true;
        continue;
      }
      if (m == 'setState' && _m(i + 1) == '(' && _m(i - 1) != '.') {
        final f = islev();
        if (f != null && f.sonAwait >= 0 && !f.mountedSonra) {
          _ekle('await-setstate', i);
        }
        continue;
      }
      if (m == 'state' &&
          _m(i + 1) == '=' &&
          _m(i - 1) != '.' &&
          _notifierDosyasi) {
        final f = islev();
        if (f != null && f.sonAwait >= 0 && !f.mountedSonra) {
          _ekle('await-state', i);
        }
      }
    }
  }

  /// [ac] `{` jetonu, [kapa]'da kapanan bloğun `else` / `else if (…)` dalı mı?
  bool _elseDali(int ac, int kapa) {
    if (_m(kapa + 1) != 'else') return false;
    if (ac == kapa + 2) return true; // } else {
    // } else if (…) {
    return _m(kapa + 2) == 'if' &&
        _m(kapa + 3) == '(' &&
        _es[kapa + 3] == ac - 1;
  }

  /// `}` jetonundan önceki son deyim return/throw/continue/break mi?
  bool _donusleBiter(int kapa) {
    var i = kapa - 1;
    if (_m(i) != ';') return false;
    i--;
    while (i >= 0) {
      final m = j[i].m;
      if (m == ';' || m == '{' || (m == '}' && _es[i] == null)) break;
      if (m == ')' || m == ']' || m == '}') {
        final es = _es[i];
        if (es == null) break;
        i = es - 1;
        continue;
      }
      i--;
    }
    final ilk = _m(i + 1);
    return ilk == 'return' || ilk == 'throw' || ilk == 'continue' || ilk == 'break';
  }

  void _okGeriCagirmaDenetle(int ac, int kapa) {
    var mounted = false;
    for (var i = ac; i < kapa; i++) {
      final m = j[i].m;
      if (m == 'mounted') mounted = true;
      if (m == 'setState' && _m(i + 1) == '(' && !mounted) {
        _ekle('await-setstate', i);
      }
    }
  }

  /// `{` neyi açıyor: islev gövdesi, blok ya da sınıf gövdesi.
  String _suslu(int i) {
    final o = _m(i - 1);
    if (o == 'async' || o == 'sync') return 'islev';
    if (o == '*' && (_m(i - 2) == 'async' || _m(i - 2) == 'sync')) {
      return 'islev';
    }
    if (o == ')') {
      final ac = _es[i - 1];
      if (ac == null) return 'blok';
      final ad = _parenAdi(ac);
      if (_kontrolAnahtarlari.contains(ad)) return 'blok';
      // `on Hata catch (e) {` ve `} catch (e) {` yukarıda; `when (..)` yok.
      return 'islev';
    }
    if (o == 'else' || o == 'try' || o == 'finally' || o == 'do') {
      return 'blok';
    }
    if (_kimlikDeseni.hasMatch(o) || o == '>' || o == '?') {
      for (var g = i - 1; g >= 0 && g > i - 60; g--) {
        final x = j[g].m;
        if (x == ';' || x == '}' || x == '{' || x == ')') break;
        if (x == 'class' || x == 'mixin' || x == 'extension' || x == 'enum') {
          return 'sinif';
        }
      }
      if (o == 'get' || _m(i - 2) == 'get') return 'islev';
    }
    return 'blok';
  }

  // -- sifira-bolme ---------------------------------------------------------

  static const _tamsayiya = {'round', 'toInt', 'floor', 'ceil', 'truncate'};

  void _bolme() {
    for (var i = 1; i < j.length - 2; i++) {
      final m = j[i].m;
      if (m == '~/') {
        final payda = _paydaMetni(i + 1);
        if (payda != null && !_paydaKorunuyor(payda, j[i].konum)) {
          _ekle('sifira-bolme', i);
        }
        continue;
      }
      if (m != '.' || !(_tamsayiya.contains(_m(i + 1)) ||
          _m(i + 1) == 'toStringAsFixed')) {
        continue;
      }
      if (_m(i + 2) != '(') continue;
      final alici = i - 1;
      if (_m(alici) == ')') {
        final ac = _es[alici];
        if (ac == null) continue;
        final bol = _ustDuzeyBolme(ac + 1, alici);
        if (bol == null) continue;
        final payda = _paydaMetni(bol + 1);
        if (payda != null && !_paydaKorunuyor(payda, j[i].konum)) {
          _ekle('sifira-bolme', i);
        }
      } else if (_kimlikDeseni.hasMatch(_m(alici))) {
        final bol = _degiskenBolmesi(alici);
        if (bol == null) continue;
        final payda = _paydaMetni(bol + 1);
        if (payda != null && !_paydaKorunuyor(payda, j[i].konum)) {
          _ekle('sifira-bolme', i);
        }
      }
    }
  }

  /// [a, z) aralığında `/` jetonunu bulur (iç parantezler dahil).
  int? _ustDuzeyBolme(int a, int z) {
    for (var i = a; i < z; i++) {
      if (j[i].m == '/') return i;
    }
    return null;
  }

  /// `oran.round()` için yakındaki `oran = a / b;` atamasını bulur.
  int? _degiskenBolmesi(int alici) {
    final ad = j[alici].m;
    for (var i = alici - 1; i >= 0 && i > alici - 400; i--) {
      if (j[i].m == ad && _m(i + 1) == '=') {
        for (var k = i + 2; k < j.length && j[k].m != ';'; k++) {
          if (j[k].m == '/') return k;
          if (j[k].m == '{') break;
        }
        return null;
      }
    }
    return null;
  }

  /// `/` ya da `~/` sonrası paydanın metni; sabit sayıysa null.
  String? _paydaMetni(int bas) {
    if (bas >= j.length) return null;
    if (_sayi.hasMatch(j[bas].m)) return null;
    final b = StringBuffer();
    var derin = 0;
    for (var i = bas; i < j.length; i++) {
      final m = j[i].m;
      if (m == '(' || m == '[') derin++;
      if (m == ')' || m == ']') {
        if (derin == 0) break;
        derin--;
      }
      if (derin == 0 &&
          const {'+', '-', '*', '/', '~/', ';', ',', '?', ':', '??', '}', '<', '>', '<=', '>=', '==', '!='}
              .contains(m)) {
        break;
      }
      b.write(m);
    }
    final s = b.toString();
    if (s.isEmpty) return null;
    // `(x == 0 ? 1 : x)`, `max(1, n)`, `.clamp(1, …)` paydayı korur.
    if (s.contains('?') || s.startsWith('max(') || s.contains('clamp(1')) {
      return null;
    }
    if (RegExp(r'^\(?\d[\d.]*\)?$').hasMatch(s)) return null;
    if (sabitler.contains(s.split('.').last)) return null;
    return s;
  }

  /// Bölmeden önceki yakın kodda payda sıfıra karşı denetleniyor mu?
  bool _paydaKorunuyor(String payda, int konum) {
    final temel = payda
        .replaceAll(RegExp(r'\.(length|toDouble\(\)|abs\(\))$'), '')
        .replaceAll(RegExp(r'^\(|\)$'), '');
    final satir = k.satirNo(konum);
    final basSatir = satir > 25 ? satir - 25 : 1;
    final pencere = k.kod.substring(
      k.satirBaslari[basSatir - 1],
      konum + 200 > k.kod.length ? k.kod.length : konum + 200,
    );
    final kac = RegExp.escape(payda);
    final kacTemel = RegExp.escape(temel);
    final denetim = RegExp(
      // `seatsPerRow = max(2, …)`, `n = x.clamp(1, …)`, `n = a ?? 1`
      '\\b$kac\\s*=\\s*(max\\(\\s*[1-9]|[^;]*\\.clamp\\(\\s*[1-9]|[^;]*\\?\\?\\s*[1-9])|'
      '($kac|$kacTemel)\\s*(==|!=|>|<=|>=|<)\\s*[01]\\b|'
      '[01]\\s*(<|>=|==|!=)\\s*($kac|$kacTemel)\\b|'
      '$kacTemel\\s*\\.\\s*(isEmpty|isNotEmpty)|'
      '$kacTemel\\s*\\?\\?\\s*[1-9]',
    );
    return denetim.hasMatch(pencere);
  }

  // -- orelse-yok -----------------------------------------------------------

  void _orElse() {
    for (var i = 0; i < j.length - 2; i++) {
      if (j[i].m != '.') continue;
      final ad = _m(i + 1);
      if (ad != 'firstWhere' && ad != 'singleWhere' && ad != 'lastWhere') {
        continue;
      }
      if (_m(i + 2) != '(') continue;
      final kapa = _es[i + 2];
      if (kapa == null) continue;
      var var_ = false;
      for (var k = i + 3; k < kapa; k++) {
        if (j[k].m == 'orElse') {
          var_ = true;
          break;
        }
      }
      if (!var_) _ekle('orelse-yok', i + 1);
    }
  }

  // -- isolate-kapanis ------------------------------------------------------

  /// Sınıf gövdesindeyken `Isolate.run((…) …)` / `compute((…) …)`.
  /// Üst düzey işlevdeki kapanış yalnız yerelleri taşır, tehlikesiz.
  void _isolate(int i, bool sinifIcinde) {
    if (!sinifIcinde) return;
    final m = j[i].m;
    final run = m == 'Isolate' && _m(i + 1) == '.' && _m(i + 2) == 'run';
    final hesap = m == 'compute' && _m(i - 1) != '.';
    if (!run && !hesap) return;
    final ac = run ? i + 3 : i + 1;
    if (_m(ac) != '(') return;
    if (_m(ac + 1) == '(') _ekle('isolate-kapanis', i);
  }

  // -- kapatilmayan / denetleyici-sizinti -----------------------------------

  static final _kaynakAtama = RegExp(
    r'\b([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*(?:[A-Za-z_$][A-Za-z0-9_$.]*\s*\.\s*)?'
    r'(AnimationController|Timer\s*\.\s*periodic|Timer|StreamController|'
    r'TextEditingController|FocusNode|ScrollController|TabController|'
    r'PageController|listen)\b(?:<[^>()]*>)?(?:\s*\.\s*broadcast)?\s*\(',
  );

  void _kapatilmayan() {
    for (final m in _kaynakAtama.allMatches(k.kod)) {
      final ad = m.group(1)!;
      final tur = m.group(2)!.replaceAll(RegExp(r'\s'), '');
      if (ad == 'final' || ad == 'var') continue;
      final kapatma = RegExp(
        '\\b${RegExp.escape(ad)}\\s*(\\?|!)?\\s*\\.\\s*(dispose|cancel|close)\\s*\\(',
      );
      // `..dispose()` zinciri ve listeye toplayıp kapatma da sayılır.
      final topluKapatma = RegExp(
        '\\b${RegExp.escape(ad)}\\b[^;]*\\]\\s*\\)\\s*\\{?[^}]*\\.(dispose|cancel)\\(|'
        'for\\s*\\([^)]*\\b${RegExp.escape(ad)}\\b',
      );
      if (kapatma.hasMatch(k.kod) || topluKapatma.hasMatch(k.kod)) continue;
      final agir = tur == 'AnimationController' ||
          tur.startsWith('Timer') ||
          tur == 'StreamController' ||
          tur == 'listen';
      // Yerel değişken (işlev içinde tek seferlik): `final t = Timer(...)`.
      // Tek atımlık Timer kendi kendine biter; yalnız periyodik ağır.
      if (tur == 'Timer' && !_alanMi(ad)) continue;
      _ekleKonum(agir ? 'kapatilmayan' : 'denetleyici-sizinti', m.start);
    }
  }

  /// [ad] sınıf alanı mı (alt çizgiyle başlayan ya da sınıf gövdesinde
  /// tanımlı)? Kaba ama yeterli: alanlar bu projede `_` ile başlar.
  bool _alanMi(String ad) => ad.startsWith('_');

  // -- bos-liste ------------------------------------------------------------

  void _bosListe() {
    for (var i = 1; i < j.length - 1; i++) {
      if (j[i].m != '.') continue;
      final ad = _m(i + 1);
      final reduce = ad == 'reduce' && _m(i + 2) == '(';
      if (!(ad == 'first' || ad == 'last' || ad == 'single' || reduce)) {
        continue;
      }
      // `.first(`: yöntem değil, başka bir şey (ör. `first()` yok).
      if (!reduce && _m(i + 2) == '(') continue;
      final alici = _alici(i);
      if (alici.isEmpty) continue;
      // split() hiçbir zaman boş liste vermez (boş metinde bile `['']`).
      if (alici.endsWith('split()')) continue;
      if (_bosDenetimiVar(alici, j[i].konum)) continue;
      _ekle('bos-liste', i + 1);
    }
  }

  /// `.` jetonundan geriye alıcının metni (`a.b.c` ya da `x)`).
  String _alici(int nokta) {
    var i = nokta - 1;
    final parca = <String>[];
    while (i >= 0) {
      final m = j[i].m;
      if (m == ')' || m == ']') {
        final ac = _es[i];
        if (ac == null) break;
        final ad = _m(ac - 1);
        parca.insert(0, m == ')' ? '()' : '[]');
        if (_kimlikDeseni.hasMatch(ad)) {
          parca.insert(0, ad);
          i = ac - 2;
        } else {
          break;
        }
      } else if (_kimlikDeseni.hasMatch(m)) {
        parca.insert(0, m);
        i--;
      } else {
        break;
      }
      if (i >= 0 && (j[i].m == '.' || j[i].m == '?.' || j[i].m == '!')) {
        if (j[i].m == '!') i--;
        if (i >= 0 && (j[i].m == '.' || j[i].m == '?.')) {
          i--;
          continue;
        }
      }
      break;
    }
    return parca.join('.').replaceAll('.()', '()').replaceAll('.[]', '[]');
  }

  bool _bosDenetimiVar(String alici, int konum) {
    final temel = alici.split('.').first.replaceAll(RegExp(r'[\[\]()]'), '');
    final satir = k.satirNo(konum);
    final basSatir = satir > 15 ? satir - 15 : 1;
    final pencere = k.kod.substring(k.satirBaslari[basSatir - 1], konum + 1);
    final t = RegExp.escape(temel);
    return RegExp(
      '\\b$t\\b[^;{}]*\\.\\s*(isEmpty|isNotEmpty|length)|'
      '\\b$t\\b\\s*(==|!=)\\s*null',
    ).hasMatch(pencere);
  }

  // -- parse ----------------------------------------------------------------

  void _parse() {
    for (var i = 0; i < j.length - 4; i++) {
      final m = j[i].m;
      if (m != 'int' && m != 'double' && m != 'num' && m != 'DateTime') {
        continue;
      }
      if (_m(i + 1) != '.' || _m(i + 2) != 'parse' || _m(i + 3) != '(') {
        continue;
      }
      final arg = _m(i + 4);
      if (arg == "'" || arg == '"' || _sayi.hasMatch(arg)) continue;
      _ekle('parse', i);
    }
  }

  // -- turkce-harf ----------------------------------------------------------

  void _turkceHarf() {
    if (k.yol.endsWith('turkish_text.dart') ||
        k.yol.endsWith('name_formatter.dart')) {
      return;
    }
    for (var i = 0; i < j.length - 2; i++) {
      if (j[i].m != '.') continue;
      final ad = _m(i + 1);
      if (ad != 'toUpperCase' && ad != 'toLowerCase') continue;
      if (_m(i + 2) != '(') continue;
      _ekle(ad == 'toUpperCase' ? 'turkce-buyuk' : 'turkce-kucuk', i + 1);
    }
  }

  // -- bos-catch ------------------------------------------------------------

  void _bosCatch() {
    for (var i = 0; i < j.length - 1; i++) {
      final m = j[i].m;
      if (m == 'catch' && _m(i + 1) == '(') {
        final kapa = _es[i + 1];
        if (kapa == null) continue;
        if (_m(kapa + 1) == '{' && _m(kapa + 2) == '}') _ekle('bos-catch', i);
      } else if (m == 'catchError' && _m(i + 1) == '(') {
        final kapa = _es[i + 1];
        if (kapa == null) continue;
        // catchError((_) {}) ya da catchError((_) => null)
        final ic = j.sublist(i + 2, kapa).map((x) => x.m).join(' ');
        if (RegExp(r'^\( [^)]* \) \{ \}$').hasMatch(ic) ||
            RegExp(r'^\( [^)]* \) => (null|\{ \})$').hasMatch(ic)) {
          _ekle('bos-catch', i);
        }
      }
    }
  }

  // -- ham-hata -------------------------------------------------------------

  /// `$e`, `${e}`, `${e.toString()}`; `${e.key}` gibi alan erişimi değil.
  static final _hataAradeger = RegExp(
    r'\$(?:\{\s*)?(e|err|error|hata|ex|exception|ex2)\b(?:\.toString\(\))?(?!\s*[.(\[?!])',
  );

  /// [ad] yakında bir hata yakalayıcının değişkeni mi?
  /// `catch (e`, `error: (e, _)`, `onError: (e`, `catchError((e`.
  bool _hataDegiskeni(String ad, int konum) {
    final bas = konum > 4000 ? konum - 4000 : 0;
    final once = k.kod.substring(bas, konum);
    final a = RegExp.escape(ad);
    return RegExp(
      '(catch\\s*\\(\\s*$a\\b|\\berror\\s*:\\s*\\(\\s*$a\\b|'
      'onError\\s*:\\s*\\(\\s*$a\\b|catchError\\s*\\(\\s*\\(\\s*$a\\b)',
    ).hasMatch(once);
  }

  static const _gunlukCagrilari = {
    'debugPrint',
    'print',
    'log',
    'record',
    'Exception',
    'StateError',
    'ArgumentError',
    'FormatException',
    'UnsupportedError',
    'Bulgu',
    'fail',
  };

  void _hamHata() {
    // Açık parantezlerin kaynak aralıkları ve adları.
    final aralik = <(int, int, String)>[];
    for (var i = 0; i < j.length; i++) {
      if (j[i].m != '(') continue;
      final kapa = _es[i];
      if (kapa == null) continue;
      aralik.add((j[i].konum, j[kapa].konum, _parenAdi(i)));
    }
    for (final (bas, son) in k.metinler) {
      final ic = k.ham.substring(bas, son);
      final esler = _hataAradeger.allMatches(ic);
      if (!esler.any((m) => _hataDegiskeni(m.group(1)!, bas))) continue;
      var enIc = '';
      var enIcBas = -1;
      for (final (a, z, ad) in aralik) {
        if (a < bas && z > son && a > enIcBas) {
          enIcBas = a;
          enIc = ad;
        }
      }
      if (_gunlukCagrilari.contains(enIc)) continue;
      final satir = k.satirNo(bas);
      final s = k.satirlar[satir - 1];
      if (s.contains('throw ') || s.contains('debugPrint(')) continue;
      _ekleKonum('ham-hata', bas);
    }
  }

  // -- zorla-harita ---------------------------------------------------------

  void _zorlaHarita() {
    for (var i = 0; i < j.length - 1; i++) {
      if (j[i].m == ']' && _m(i + 1) == '!' && _m(i + 2) != '=') {
        _ekle('zorla-harita', i);
      }
    }
  }

  // -- substring ------------------------------------------------------------

  void _substring() {
    for (var i = 0; i < j.length - 2; i++) {
      if (j[i].m == '.' && _m(i + 1) == 'substring' && _m(i + 2) == '(') {
        _ekle('substring', i + 1);
      }
    }
  }

  // -- zaman-bombasi --------------------------------------------------------

  static final _sabitYil = RegExp(r'\bDateTime\s*\(\s*20\d\d\b');

  void _zamanBombasi() {
    for (final m in _sabitYil.allMatches(k.kod)) {
      _ekleKonum('zaman-bombasi', m.start);
    }
  }
}

// ---------------------------------------------------------------------------
// Komut satırı
// ---------------------------------------------------------------------------

void main(List<String> args) {
  final hepsi = args.contains('--hepsi');
  final secili = args
      .where((a) => a.startsWith('--kural='))
      .map((a) => a.substring('--kural='.length))
      .toSet();
  final bulgular = denetle(Directory('lib'));

  var kapiToplam = 0;
  for (final kural in kurallar) {
    if (secili.isNotEmpty && !secili.contains(kural.kod)) continue;
    final b = bulgular.where((x) => x.kural == kural.kod).toList();
    if (kural.derece == Derece.kapi) kapiToplam += b.length;
    final etiket = kural.derece == Derece.kapi ? 'KAPI    ' : 'inceleme';
    stdout.writeln('[$etiket] ${kural.kod.padRight(20)} ${b.length.toString().padLeft(4)}  ${kural.baslik}');
    final ayrinti = secili.isNotEmpty || hepsi || kural.derece == Derece.kapi;
    if (ayrinti && b.isNotEmpty) {
      for (final x in b) {
        stdout.writeln('    $x');
      }
    }
  }
  stdout.writeln('');
  stdout.writeln(kapiToplam == 0
      ? 'Kapı kurallarında bulgu yok.'
      : 'Kapı kurallarında $kapiToplam bulgu.');
  if (kapiToplam > 0 && secili.isEmpty) exitCode = 1;
}

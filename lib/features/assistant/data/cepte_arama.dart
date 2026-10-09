import '../../../core/utils/turkish_text.dart';
import 'cepte_niyet.dart';

/// Cepte araması: öğretmen yazdıkça uygulamadaki her şey (ekran, belge,
/// sınıf, öğrenci, belirli gün, kulüp, kazanım) altta listelenir.
///
/// ## Neden sohbet değil arama
/// Kullanıcı (9 Ekim 2026): "kutu yukarıda olsun, yazdıkça altta öneri
/// gelsin; senaryolar çeşitli değil, kullanıcı deneyimi berbat". Sohbette
/// öğretmen cümleyi bitirip gönderiyor, cevabı okuyor, sonra düğmeye
/// basıyordu (üç adım) ve yalnız 17 ekran tanınıyordu. Aramada yazarken
/// hedef görünür, tek dokunuşla açılır. Sohbet havası, Cepte'nin soru
/// sorması gereken yerde (plan için sınıf/ders) kalır.
///
/// Saf Dart: arayüz yok, veritabanı yok. Katalog dışarıda kurulur.

/// Sonuçların gruplandığı başlıklar; sıra ekrandaki sıradır.
enum CepteKategori {
  hazirla('Hazırla'),
  ekran('Ekranlar'),
  sinif('Sınıflarım'),
  ogrenci('Öğrenciler'),
  kazanim('Kazanım ve planlar'),
  belirliGun('Belirli gün ve haftalar'),
  kulup('Sosyal kulüpler'),
  ayar('Hesap ve ayarlar');

  const CepteKategori(this.baslik);
  final String baslik;
}

/// Sınıfa bağlı ekranlar: her sınıf için ayrı sonuç olur
/// ("Oturma planı · 5-A").
enum CepteSinifEkrani {
  sinifim,
  ogrenciListesi,
  oturmaPlani,
  devamsizlik,
  veliIletisim,
  veliPaneli,
  islenenDersler,
  artiEksi,
  eokulFoto,
}

/// Sonuca dokununca ne olacağı. Arayüz katmanı bunu ekrana çevirir.
sealed class CepteEylem {
  const CepteEylem();
}

class EkranEylemi extends CepteEylem {
  const EkranEylemi(this.ekran);
  final CepteEkran ekran;
}

class SinifEkraniEylemi extends CepteEylem {
  const SinifEkraniEylemi(this.ekran, this.classId);
  final CepteSinifEkrani ekran;
  final int classId;
}

class OgrenciEylemi extends CepteEylem {
  const OgrenciEylemi(this.studentId, this.classId);
  final int studentId;
  final int classId;
}

class BelirliGunEylemi extends CepteEylem {
  const BelirliGunEylemi(this.ad, {required this.etkinlikli});
  final String ad;

  /// Etkinlikliyse kendi panosu (pano, konuşma, şiir) açılır; değilse
  /// çizelge.
  final bool etkinlikli;
}

class KulupEylemi extends CepteEylem {
  const KulupEylemi(this.kulupId);

  /// Öğretmenin kurduğu kulüp; `null` ise katalogdaki (henüz kurulmamış)
  /// kulüp: kulüpler ekranı açılır, kulüp oradan kurulur.
  final int? kulupId;
}

class KazanimEylemi extends CepteEylem {
  const KazanimEylemi({
    required this.sinif,
    required this.dersKodu,
    required this.dersAdi,
    this.yayinci = '',
  });
  final int sinif;
  final String dersKodu;
  final String dersAdi;
  final String yayinci;
}

/// Plan hazırlama (yıllık ya da günlük). Eksik bilgi varsa Cepte sorar.
class PlanEylemi extends CepteEylem {
  const PlanEylemi(this.niyet);
  final CepteNiyet niyet;
}

/// Aramada çıkan tek bir şey.
class CepteHedef {
  CepteHedef({
    required this.id,
    required this.baslik,
    required this.kategori,
    required this.eylem,
    this.yol = '',
    this.anahtarlar = const [],
    this.oncelik = 0,
  })  : _baslikKelimeleri = _kelimeler(baslik),
        _anahtarKelimeleri = [for (final a in anahtarlar) _kelimeler(a)],
        _yolKelimeleri = _kelimeler(yol),
        _baslikDuz = cepteNormalize(baslik),
        _anahtarDuz = [for (final a in anahtarlar) cepteNormalize(a)];

  /// Kalıcı kimlik ("Son açtıklarınız" için).
  final String id;
  final String baslik;

  /// Nerede durduğu: "Belgeler › Belirli Günler". Öğretmen ekranı sonra
  /// kendisi de bulabilsin.
  final String yol;
  final CepteKategori kategori;

  /// Eş anlamlılar ve öğretmenin kullandığı sözler ("kroki", "yoklama").
  final List<String> anahtarlar;
  final CepteEylem eylem;

  /// Sık kullanılan ekranlara küçük öncelik.
  final int oncelik;

  final List<String> _baslikKelimeleri;
  final List<List<String>> _anahtarKelimeleri;
  final List<String> _yolKelimeleri;
  final String _baslikDuz;
  final List<String> _anahtarDuz;
}

class CepteSonuc {
  const CepteSonuc(this.hedef, this.puan);
  final CepteHedef hedef;
  final int puan;
}

/// Karşılaştırma biçimi: Türkçe harf duyarsız, küçük harf; noktalama
/// boşluk olur; rakam ile harf ayrılır ("5a" → "5 a", "23nisan" →
/// "23 nisan", "5-A" → "5 a", "5.sınıf" → "5 sinif").
String cepteNormalize(String ham) {
  var s = trFold(ham);
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  s = s.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> _kelimeler(String ham) {
  final s = cepteNormalize(ham);
  return s.isEmpty ? const [] : s.split(' ');
}

/// Aramayı süzmeyen sözler: "oturma planı nerede", "yoklamayı aç".
const Set<String> _dolgu = {
  'ac', 'acar', 'acmak', 'goster', 'nerede', 'nasil', 'icin', 'bana',
  'lutfen', 'istiyorum', 'bul', 'git', 'var', 'mi', 'mu', 'ne', 'ile',
  'bir', 'su', 'bu', 'olan', 'ekrani', 'sayfasi', 'sayfa', 'ekran',
};

/// Sorgunun bir kelimesi hedefin bir kelimesine uyuyor mu?
///
/// 1. Yazılan, kelimenin başı: "devams" → "devamsizlik". Arama yazarken
///    çalışır. Kelime BAŞI şart: "din" "aydin"da eşleşmez.
/// 2. Ek almış kelime: "planini" ⊃ "plani", "velilere" ⊃ "veli".
/// 3. Ünsüz yumuşaması: "devamsizligi" ~ "devamsizlik" (k→ğ), "kitabi" ~
///    "kitap" (p→b): son harf dışında aynı.
bool _kelimeUyar(String sorguKelimesi, String kelime) {
  if (kelime.startsWith(sorguKelimesi)) return true;
  if (kelime.length >= 3 && sorguKelimesi.startsWith(kelime)) return true;
  if (kelime.length >= 5 && sorguKelimesi.length >= kelime.length) {
    final govde = kelime.substring(0, kelime.length - 1);
    if (sorguKelimesi.startsWith(govde)) return true;
  }
  return false;
}

/// Kelime tam mı (yazılanın tamamı, ek almadan)?
bool _kelimeTam(String sorguKelimesi, String kelime) => sorguKelimesi == kelime;

/// Puan: 0 → eşleşmedi.
int ceptePuanla(CepteHedef h, List<String> sorgu, String sorguDuz) {
  if (sorgu.isEmpty) return 0;
  var toplam = 0;
  for (final k in sorgu) {
    // Rakamlar ("5", "23") kelimenin tamamı olmalı: "5" yazan "15"i
    // ya da "2025"i istemiyor. Başka kelimeyle birlikte yazılan tek harf
    // de öyle: "5-A"daki "a" şubedir, "Ali"nin baş harfi değil. Tek
    // başına yazılan harf ise yazarken öneri verir.
    final tam = RegExp(r'^\d+$').hasMatch(k) || (k.length == 1 && sorgu.length > 1);
    bool uy(String w) => tam ? w == k : _kelimeUyar(k, w);

    var enIyi = 0;
    for (final w in h._baslikKelimeleri) {
      if (uy(w)) {
        enIyi = _kelimeTam(k, w) ? 30 : 20;
        break;
      }
    }
    if (enIyi < 30) {
      for (final ak in h._anahtarKelimeleri) {
        for (final w in ak) {
          if (uy(w)) {
            final p = _kelimeTam(k, w) ? 18 : 12;
            if (p > enIyi) enIyi = p;
          }
        }
      }
    }
    if (enIyi == 0) {
      for (final w in h._yolKelimeleri) {
        if (uy(w)) {
          enIyi = 5;
          break;
        }
      }
    }
    if (enIyi == 0) return 0; // her kelime bir yerde geçmeli
    toplam += enIyi;
  }

  // Bütün ifade başlığın ya da bir anahtarın kendisi/başıysa güçlü işaret.
  // Birebir anahtar ("yedek") kelime ortasında başlayan başlıktan
  // ("Yedekten geri yükle") güçlü olmalı.
  if (h._baslikDuz == sorguDuz) {
    toplam += 40;
  } else if (h._baslikDuz.startsWith('$sorguDuz ')) {
    toplam += 25;
  } else if (h._baslikDuz.startsWith(sorguDuz)) {
    toplam += 10;
  }
  var anahtarBonusu = 0;
  for (final a in h._anahtarDuz) {
    final b = a == sorguDuz
        ? 30
        : a.startsWith('$sorguDuz ')
            ? 12
            : a.startsWith(sorguDuz)
                ? 5
                : 0;
    if (b > anahtarBonusu) anahtarBonusu = b;
  }
  toplam += anahtarBonusu;
  // Kısa başlık önde: "Kazanımlar", "5. sınıf Türkçe kazanımları"ndan önce.
  toplam -= (h._baslikKelimeleri.length - sorgu.length).clamp(0, 6);
  return toplam + h.oncelik;
}

/// Sorguyu kelimelerine ayırır; dolgu sözleri atılır (hepsi dolguysa
/// atılmaz).
List<String> cepteSorguKelimeleri(String sorgu) {
  final hepsi = _kelimeler(sorgu);
  final anlamli = hepsi.where((k) => !_dolgu.contains(k)).toList();
  return anlamli.isEmpty ? hepsi : anlamli;
}

/// Kataloğu arar; en iyi [sinir] sonuç, puana göre.
List<CepteSonuc> cepteAra(String sorgu, List<CepteHedef> katalog, {int sinir = 40}) {
  final kelimeler = cepteSorguKelimeleri(sorgu);
  if (kelimeler.isEmpty) return const [];
  final duz = kelimeler.join(' ');
  final sonuclar = <CepteSonuc>[];
  for (final h in katalog) {
    final p = ceptePuanla(h, kelimeler, duz);
    if (p > 0) sonuclar.add(CepteSonuc(h, p));
  }
  sonuclar.sort((a, b) {
    final c = b.puan.compareTo(a.puan);
    return c != 0 ? c : a.hedef.baslik.length.compareTo(b.hedef.baslik.length);
  });
  return sonuclar.length > sinir ? sonuclar.sublist(0, sinir) : sonuclar;
}

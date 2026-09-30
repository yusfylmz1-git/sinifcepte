import '../../../data/models/class_model.dart';
import '../../../data/models/student_model.dart';
import '../data/foto_paylasim.dart';
import 'ogrenci_foto.dart';

/// Dışa aktarmada bir öğrencinin durumu.
///
/// İlk üçü ENGELLER (plan §10.1): çözülmeden paket üretilmez. Son ikisi
/// eksik sayılır; pakete girmez ama eksikler listesinde açıkça yazar.
enum AktarimDurumu {
  /// Pakete girer.
  tamam,

  /// Çekimdeki numara/ad güncel kayıttan farklı. Öğretmen yeniden
  /// onaylamadan pakete girmez (yanlış eşleşme ya da sonradan değişen
  /// bilgi — sessizce geçilmez).
  kimlikFarkli,

  /// Aynı sınıfta aynı okul numarası birden fazla öğrencide.
  numaraCakismasi,

  /// Ad ya da soyad boş: dosya adı üretilemez.
  adEksik,

  /// Fotoğraf hiç yok.
  fotografYok,

  /// Kayıt var ama dosya bu cihazda yok.
  dosyaKayip,
}

extension AktarimDurumuMetni on AktarimDurumu {
  bool get engeller =>
      this == AktarimDurumu.kimlikFarkli ||
      this == AktarimDurumu.numaraCakismasi ||
      this == AktarimDurumu.adEksik;

  String get metin => switch (this) {
        AktarimDurumu.tamam => 'Kimlik doğrulandı',
        AktarimDurumu.kimlikFarkli => 'Kimlik kontrolü gerekli',
        AktarimDurumu.numaraCakismasi => 'Numara çakışması',
        AktarimDurumu.adEksik => 'Ad/soyad eksik',
        AktarimDurumu.fotografYok => 'Fotoğraf yok',
        AktarimDurumu.dosyaKayip => 'Dosya kayıp',
      };
}

/// Paketteki bir öğrenci satırı. Fotoğraf revizyonu burada SABİTLENİR:
/// iş sürerken yeniden çekilen fotoğraf yarıdaki pakete karışmaz
/// (plan §13) — aktarıcı dosyayı bu kayıttaki özetle doğrular.
class AktarimKalemi {
  const AktarimKalemi({
    required this.sinif,
    required this.ogrenci,
    required this.foto,
    required this.klasor,
    required this.dosyaAdi,
    required this.durum,
  });

  final ClassModel sinif;
  final StudentModel ogrenci;
  final OgrenciFoto? foto;

  /// Paketteki sınıf klasörü (güvenli ad).
  final String klasor;

  /// `<no>_<Ad>_<SOYAD>.jpg`
  final String dosyaAdi;
  final AktarimDurumu durum;

  String get adSoyad => '${ogrenci.firstName} ${ogrenci.lastName}'.trim();

  /// Paket içindeki yol (paket kök klasörü hariç).
  String get paketYolu => '$klasor/$dosyaAdi';
}

class DisaAktarimPlani {
  const DisaAktarimPlani({required this.paketAdi, required this.kalemler});

  /// Paketin kök klasör adı: `SinifCepte_Fotograflar_2026-2027_20260930_143000`.
  final String paketAdi;
  final List<AktarimKalemi> kalemler;

  List<AktarimKalemi> get aktarilacak =>
      kalemler.where((k) => k.durum == AktarimDurumu.tamam).toList();

  List<AktarimKalemi> get engelleyenler => kalemler.where((k) => k.durum.engeller).toList();

  List<AktarimKalemi> get eksikler => kalemler
      .where((k) => k.durum == AktarimDurumu.fotografYok || k.durum == AktarimDurumu.dosyaKayip)
      .toList();

  /// Paket yalnızca engel yokken ve en az bir fotoğraf varken üretilir.
  bool get uretilebilir => engelleyenler.isEmpty && aktarilacak.isNotEmpty;

  /// Neden üretilemediğini söyler (düğme pasifken gösterilir).
  String? get engelNedeni {
    if (engelleyenler.isNotEmpty) {
      return '${engelleyenler.length} öğrencide çözülmesi gereken sorun var '
          '(işaretli satırlar).';
    }
    if (aktarilacak.isEmpty) return 'Aktarılacak fotoğraf yok.';
    return null;
  }
}

/// Sınıf adını klasör adına çevirir: `5/A` → `5-A`.
String guvenliKlasorAdi(String sinifAdi) {
  var s = sinifAdi
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '-')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  // Windows: sonda nokta/boşluk olamaz; "." ve ".." klasör adı olamaz.
  s = s.replaceAll(RegExp(r'[. ]+$'), '');
  if (s.isEmpty || RegExp(r'^\.+$').hasMatch(s)) s = 'Sinif';
  return s.length > 60 ? s.substring(0, 60) : s;
}

String _iki(int n) => n.toString().padLeft(2, '0');

/// Dışa aktarma planı — saf hesap, disk ve veritabanına dokunmaz.
///
/// [siniflar] seçilen sınıflar ve öğrencileri; [fotolar] öğrenci
/// kimliğine göre güncel fotoğraflar; [dosyaVar] fotoğraf dosyası bu
/// cihazda duruyor mu (ekran önceden kontrol eder).
DisaAktarimPlani disaAktarimPlanla({
  required List<(ClassModel, List<StudentModel>)> siniflar,
  required Map<int, OgrenciFoto> fotolar,
  required DateTime zaman,
  bool Function(OgrenciFoto foto)? dosyaVar,
}) {
  // Klasör adları: iki sınıf aynı güvenli ada düşerse kararlı ek
  // (sınıf kimliği sırasına göre " (2)", " (3)").
  final sirali = [...siniflar]..sort((a, b) => (a.$1.id ?? 0).compareTo(b.$1.id ?? 0));
  final klasorler = <int, String>{};
  final kullanilan = <String, int>{};
  for (final (sinif, _) in sirali) {
    final temel = guvenliKlasorAdi(sinif.name);
    final anahtar = temel.toLowerCase(); // Windows büyük/küçük harf ayırmaz
    final n = (kullanilan[anahtar] ?? 0) + 1;
    kullanilan[anahtar] = n;
    klasorler[sinif.id ?? 0] = n == 1 ? temel : '${temel}_($n)';
  }

  final kalemler = <AktarimKalemi>[];
  for (final (sinif, ogrenciler) in siniflar) {
    final numaraSayisi = <int, int>{};
    for (final o in ogrenciler) {
      numaraSayisi[o.schoolNumber] = (numaraSayisi[o.schoolNumber] ?? 0) + 1;
    }
    final siraliOgr = [...ogrenciler]..sort((a, b) => a.schoolNumber.compareTo(b.schoolNumber));
    for (final o in siraliOgr) {
      final f = fotolar[o.id];
      final AktarimDurumu durum;
      if (f == null) {
        durum = AktarimDurumu.fotografYok;
      } else if (!f.hazirMi || (dosyaVar != null && !dosyaVar(f))) {
        durum = AktarimDurumu.dosyaKayip;
      } else if (o.firstName.trim().isEmpty || o.lastName.trim().isEmpty) {
        durum = AktarimDurumu.adEksik;
      } else if ((numaraSayisi[o.schoolNumber] ?? 0) > 1) {
        durum = AktarimDurumu.numaraCakismasi;
      } else if (f.kimlikFarkli(okulNo: o.schoolNumber, adSoyad: '${o.firstName} ${o.lastName}')) {
        durum = AktarimDurumu.kimlikFarkli;
      } else {
        durum = AktarimDurumu.tamam;
      }
      kalemler.add(AktarimKalemi(
        sinif: sinif,
        ogrenci: o,
        foto: f,
        klasor: klasorler[sinif.id ?? 0]!,
        dosyaAdi: eokulDosyaAdi(okulNo: o.schoolNumber, ad: o.firstName, soyad: o.lastName),
        durum: durum,
      ));
    }
  }

  final yillar = siniflar.map((s) => s.$1.academicYear.trim()).where((y) => y.isNotEmpty).toSet();
  final yil = yillar.length == 1 ? '_${guvenliKlasorAdi(yillar.first)}' : '';
  final z = zaman;
  final damga = '${z.year}${_iki(z.month)}${_iki(z.day)}_${_iki(z.hour)}${_iki(z.minute)}${_iki(z.second)}';
  return DisaAktarimPlani(paketAdi: 'SinifCepte_Fotograflar${yil}_$damga', kalemler: kalemler);
}

// ---------------------------------------------------------------------
// Kontrol listeleri (CSV)
// ---------------------------------------------------------------------

/// Excel'in Türkçe ayarında liste ayırıcı `;`. Başta BOM: Excel UTF-8'i
/// ancak böyle tanıyor, yoksa "Ş" → "Å" olur.
const String _bom = '\uFEFF';

String _hucre(String s) {
  var d = s;
  // CSV formül enjeksiyonu: "=", "+", "-", "@" ile başlayan hücre Excel'de
  // formül olarak çalışır.
  if (d.isNotEmpty && '=+-@'.contains(d[0])) d = "'$d";
  if (d.contains(';') || d.contains('"') || d.contains('\n') || d.contains('\r')) {
    d = '"${d.replaceAll('"', '""')}"';
  }
  return d;
}

String _csv(List<List<String>> satirlar) =>
    '$_bom${satirlar.map((s) => s.map(_hucre).join(';')).join('\r\n')}\r\n';

/// Pakete giren her fotoğraf: sınıf, numara, ad, soyad, dosya adı, özet.
String eslestirmeCsv(DisaAktarimPlani plan) => _csv([
      ['Sınıf', 'Okul No', 'Ad', 'Soyad', 'Klasör', 'Dosya Adı', 'SHA-256'],
      for (final k in plan.aktarilacak)
        [
          k.sinif.name,
          '${k.ogrenci.schoolNumber}',
          k.ogrenci.firstName,
          k.ogrenci.lastName,
          k.klasor,
          k.dosyaAdi,
          k.foto!.checksum,
        ],
    ]);

/// Fotoğrafı olmayan ya da pakete giremeyen öğrenciler.
String eksiklerCsv(DisaAktarimPlani plan) => _csv([
      ['Sınıf', 'Okul No', 'Ad', 'Soyad', 'Durum'],
      for (final k in plan.kalemler.where((k) => k.durum != AktarimDurumu.tamam))
        [k.sinif.name, '${k.ogrenci.schoolNumber}', k.ogrenci.firstName, k.ogrenci.lastName, k.durum.metin],
    ]);

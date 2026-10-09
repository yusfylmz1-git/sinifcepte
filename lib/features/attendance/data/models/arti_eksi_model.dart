/// SınıfCepte - Artı-Eksi Listesi
///
/// Kullanıcı kararı (9 Ekim 2026): öğretmenler her derste görebildikleri,
/// eklendikçe güncellenen bir artı-eksi listesi istedi. Öğretmen + ya da −
/// verir; söz hakkı ve ödevden AYRIDIR. Eksi tek dokunuştur, neden sorulmaz
/// (ders akarken hızlı olmalı). Kayıtlar dönem boyunca birikir.
library;

/// Tek bir artı ya da eksi.
class ArtiEksiKaydi {
  final int id;
  final int classId;
  final int studentId;

  /// `1` artı, `-1` eksi.
  final int deger;

  /// Dersin tarihi, `YYYY-MM-DD`.
  final String tarih;

  const ArtiEksiKaydi({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.deger,
    required this.tarih,
  });

  bool get artiMi => deger > 0;

  factory ArtiEksiKaydi.fromMap(Map<String, dynamic> m) => ArtiEksiKaydi(
        id: m['id'] as int,
        classId: m['class_id'] as int,
        studentId: m['student_id'] as int,
        deger: m['deger'] as int,
        tarih: m['tarih'] as String,
      );
}

/// Bir öğrencinin seçili aralıktaki toplamı.
class ArtiEksiOzeti {
  final int arti;
  final int eksi;

  /// Son kayıtlar, eskiden yeniye (`true` artı). Satırda "+ + − +" diye
  /// görünür; öğretmen sayının yanında gidişatı da görür.
  final List<bool> son;

  const ArtiEksiOzeti({this.arti = 0, this.eksi = 0, this.son = const []});

  static const bos = ArtiEksiOzeti();
}

/// Satırda gösterilen son kayıt sayısı.
const int artiEksiSonKayitSayisi = 8;

/// Kayıtları öğrenci başına toplar. Kayıtlar eklenme sırasıyla gelmeli.
Map<int, ArtiEksiOzeti> artiEksiOzetle(List<ArtiEksiKaydi> kayitlar) {
  final arti = <int, int>{};
  final eksi = <int, int>{};
  final son = <int, List<bool>>{};
  for (final k in kayitlar) {
    if (k.artiMi) {
      arti[k.studentId] = (arti[k.studentId] ?? 0) + 1;
    } else {
      eksi[k.studentId] = (eksi[k.studentId] ?? 0) + 1;
    }
    (son[k.studentId] ??= []).add(k.artiMi);
  }
  return {
    for (final id in son.keys)
      id: ArtiEksiOzeti(
        arti: arti[id] ?? 0,
        eksi: eksi[id] ?? 0,
        son: son[id]!.length <= artiEksiSonKayitSayisi
            ? son[id]!
            : son[id]!.sublist(son[id]!.length - artiEksiSonKayitSayisi),
      ),
  };
}

/// Listenin gösterdiği tarih aralığı (uçlar dahil, `YYYY-MM-DD`).
class ArtiEksiAraligi {
  final String baslangic;
  final String bitis;
  final String ad;

  const ArtiEksiAraligi(this.baslangic, this.bitis, this.ad);

  @override
  bool operator ==(Object other) =>
      other is ArtiEksiAraligi && other.baslangic == baslangic && other.bitis == bitis;

  @override
  int get hashCode => Object.hash(baslangic, bitis);
}

/// Eğitim yılının başladığı takvim yılı: Ağustos ve sonrası o yıl,
/// Ocak–Temmuz bir önceki yıl.
int _yilBasi(DateTime gun) => gun.month >= 8 ? gun.year : gun.year - 1;

/// Günün dönemi. 1. dönem Ağustos–Ocak, 2. dönem Şubat–Temmuz.
///
/// Uygulamada dönem tarihi tutan bir takvim yok (yalnız 2025-2026 tohum
/// verisi var). Yarıyıl tatili ocak sonu ile şubat başına düştüğü için
/// ay sınırı hiçbir ders gününü yanlış döneme koymaz.
ArtiEksiAraligi artiEksiDonemi(DateTime gun) {
  final y = _yilBasi(gun);
  if (gun.month >= 8 || gun.month == 1) {
    return ArtiEksiAraligi('$y-08-01', '${y + 1}-01-31', '1. dönem');
  }
  return ArtiEksiAraligi('${y + 1}-02-01', '${y + 1}-07-31', '2. dönem');
}

/// Günün eğitim yılı (1 Ağustos – 31 Temmuz).
ArtiEksiAraligi artiEksiYili(DateTime gun) {
  final y = _yilBasi(gun);
  return ArtiEksiAraligi('$y-08-01', '${y + 1}-07-31', 'Tüm yıl');
}

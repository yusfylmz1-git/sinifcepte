/// Sosyal kulüp modülünün veri türleri.
///
/// ## Neden bu modül var
/// Sosyal Etkinlikler Yönetmeliği (RG 08.06.2017/30090) MADDE 8/4
/// "her öğrencinin en az bir kulübe üye olması zorunludur" diyor.
/// Danışman öğretmenden yıl içinde üç evrak isteniyor: yıllık çalışma
/// planı, üye listesi ve yıl sonu faaliyet raporu. Üçü de her yıl
/// elle yeniden yazılıyordu.
///
/// ## Kulüp neden sınıfa bağlı değil
/// Yönetmelik kulübü **okul** düzeyinde tanımlar; branş öğretmeni
/// farklı şubelerden öğrenci alır. Bu yüzden üyelik `students` tablosuna
/// bir sütun olarak değil, ayrı `club_members` tablosuna yazılır —
/// bir kulüp birden çok sınıftan öğrenci taşıyabilsin diye.
///
/// ## Hazır içerik nereden geliyor
/// `assets/data/kulup_planlari.json.gz` — 52 kulübün 10 aylık çalışma
/// planı. Paket `tool/build_kulup_dataset.py` ile üretilir, APK ile
/// taşınır, Firestore'a çıkmaz.
library;

/// Yıllık çalışma planındaki bir ay satırı.
class ClubPlanRow {
  /// "Eylül" … "Haziran". Öğretim yılı sırasıyla 10 ay.
  final String ay;

  /// O ayın amacı — plandaki "AMAÇ" sütunu.
  final String amac;

  /// O ay yapılacaklar — plandaki "YAPILACAK ETKİNLİKLER" sütunu.
  final String etkinlik;

  const ClubPlanRow({
    required this.ay,
    required this.amac,
    required this.etkinlik,
  });

  factory ClubPlanRow.fromJson(Map<String, dynamic> j) => ClubPlanRow(
        ay: j['ay'] as String? ?? '',
        amac: j['amac'] as String? ?? '',
        etkinlik: j['etkinlik'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ay': ay,
        'amac': amac,
        'etkinlik': etkinlik,
      };

  ClubPlanRow copyWith({String? amac, String? etkinlik}) => ClubPlanRow(
        ay: ay,
        amac: amac ?? this.amac,
        etkinlik: etkinlik ?? this.etkinlik,
      );
}

/// EK-4 çizelgesindeki bir kulüp ve hazır planı.
///
/// Salt okunur katalog kaydı — öğretmenin kurduğu kulüp [ClubModel].
class ClubCatalogItem {
  /// EK-4 sıra numarası (1-52). Okulun kendi kurduğu kulüpte 0.
  final int no;

  final String ad;

  /// Kısa kod — `club_members.club_code` bu değeri tutar.
  final String kod;

  /// Liste rengi ve gruplama için: bilim, kultur, sanat, spor, doga,
  /// toplum, saglik, degerler.
  final String tema;

  /// 10 aylık hazır çalışma planı.
  final List<ClubPlanRow> plan;

  const ClubCatalogItem({
    required this.no,
    required this.ad,
    required this.kod,
    required this.tema,
    required this.plan,
  });

  factory ClubCatalogItem.fromJson(Map<String, dynamic> j) => ClubCatalogItem(
        no: (j['no'] as num?)?.toInt() ?? 0,
        ad: j['ad'] as String? ?? '',
        kod: j['kod'] as String? ?? '',
        tema: j['tema'] as String? ?? 'toplum',
        plan: (j['plan'] as List? ?? [])
            .map((e) => ClubPlanRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Öğretmenin kurduğu kulüp.
///
/// Yönetmelik MADDE 8/1 çizelge dışında kulüp kurulmasına izin verir;
/// o yüzden [catalogCode] boş olabilir ve [ad] serbesttir.
class ClubModel {
  final int? id;

  /// Katalog kodu. Okulun kendi kurduğu kulüpte boş.
  final String catalogCode;

  /// Kulübün adı. Katalogdan seçildiyse oradan gelir, sonra
  /// değiştirilebilir.
  final String ad;

  final String tema;

  /// "2025-2026". Üyelik yılla sınırlı (MADDE 8/7), yeni yılda kulüp
  /// yeniden kurulur.
  final String ogretimYili;

  /// Kulüp temsilcisi öğrencinin `club_members.id` değeri.
  ///
  /// MADDE 2/e temsilciyi "danışman öğretmenle birlikte çalışmaları
  /// yürüten üye" olarak tanımlar. Henüz seçilmediyse null.
  final int? temsilciUyeId;

  /// Öğretmenin plan üzerinde yaptığı değişiklikler.
  ///
  /// Boşsa katalogdaki hazır plan olduğu gibi kullanılır. Bir ay
  /// düzenlenirse yalnızca o ay burada saklanır — katalog güncellenince
  /// dokunulmamış aylar yeni içeriği alır.
  final Map<String, ClubPlanRow> planDuzenlemeleri;

  final DateTime olusturmaTarihi;

  const ClubModel({
    this.id,
    this.catalogCode = '',
    required this.ad,
    this.tema = 'toplum',
    required this.ogretimYili,
    this.temsilciUyeId,
    this.planDuzenlemeleri = const {},
    required this.olusturmaTarihi,
  });

  /// Katalog dışı, okulun kendi kurduğu kulüp mü.
  bool get ozelKulup => catalogCode.isEmpty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'catalog_code': catalogCode,
        'ad': ad,
        'tema': tema,
        'ogretim_yili': ogretimYili,
        'temsilci_uye_id': temsilciUyeId,
        'plan_duzenlemeleri': planDuzenlemeleri.isEmpty
            ? ''
            : _duzenlemeKodla(planDuzenlemeleri),
        'olusturma_tarihi': olusturmaTarihi.toIso8601String(),
      };

  factory ClubModel.fromMap(Map<String, dynamic> m) => ClubModel(
        id: m['id'] as int?,
        catalogCode: m['catalog_code'] as String? ?? '',
        ad: m['ad'] as String? ?? '',
        tema: m['tema'] as String? ?? 'toplum',
        ogretimYili: m['ogretim_yili'] as String? ?? '',
        temsilciUyeId: m['temsilci_uye_id'] as int?,
        planDuzenlemeleri: _duzenlemeCoz(m['plan_duzenlemeleri'] as String?),
        olusturmaTarihi:
            DateTime.tryParse(m['olusturma_tarihi'] as String? ?? '') ??
                DateTime.now(),
      );

  ClubModel copyWith({
    int? id,
    String? ad,
    String? tema,
    int? temsilciUyeId,
    bool temsilciTemizle = false,
    Map<String, ClubPlanRow>? planDuzenlemeleri,
  }) =>
      ClubModel(
        id: id ?? this.id,
        catalogCode: catalogCode,
        ad: ad ?? this.ad,
        tema: tema ?? this.tema,
        ogretimYili: ogretimYili,
        temsilciUyeId:
            temsilciTemizle ? null : (temsilciUyeId ?? this.temsilciUyeId),
        planDuzenlemeleri: planDuzenlemeleri ?? this.planDuzenlemeleri,
        olusturmaTarihi: olusturmaTarihi,
      );
}

/// Kulübe üye bir öğrenci.
///
/// Öğrenci farklı şubelerden gelebildiği için sınıf adı burada
/// **kopyalanarak** tutulur: öğrenci silinse ya da şube değiştirse bile
/// yılın üye listesi ve imzalanmış evrak tutarlı kalsın diye.
class ClubMember {
  final int? id;
  final int clubId;

  /// `students.id`. Öğrenci kaydı silinirse null olur, satır kalır.
  final int? studentId;

  final String adSoyad;

  /// Okul numarası. Bilinmiyorsa 0.
  final int okulNo;

  /// "5-A" gibi. Üye eklendiği andaki şube.
  final String sinifAdi;

  /// "Üye" veya "Kulüp Temsilcisi", "Başkan Yardımcısı", "Yazman" gibi
  /// kulübün kendi belirlediği görev.
  final String gorev;

  const ClubMember({
    this.id,
    required this.clubId,
    this.studentId,
    required this.adSoyad,
    this.okulNo = 0,
    this.sinifAdi = '',
    this.gorev = 'Üye',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'club_id': clubId,
        'student_id': studentId,
        'ad_soyad': adSoyad,
        'okul_no': okulNo,
        'sinif_adi': sinifAdi,
        'gorev': gorev,
      };

  factory ClubMember.fromMap(Map<String, dynamic> m) => ClubMember(
        id: m['id'] as int?,
        clubId: m['club_id'] as int? ?? 0,
        studentId: m['student_id'] as int?,
        adSoyad: m['ad_soyad'] as String? ?? '',
        okulNo: (m['okul_no'] as num?)?.toInt() ?? 0,
        sinifAdi: m['sinif_adi'] as String? ?? '',
        gorev: m['gorev'] as String? ?? 'Üye',
      );

  ClubMember copyWith({String? gorev}) => ClubMember(
        id: id,
        clubId: clubId,
        studentId: studentId,
        adSoyad: adSoyad,
        okulNo: okulNo,
        sinifAdi: sinifAdi,
        gorev: gorev ?? this.gorev,
      );
}

/// Yıl sonu faaliyet raporundaki bir ay kaydı.
///
/// Planda "ne yapılacak" yazar; burada "ne yapıldı" tutulur. İkisi
/// yan yana basılınca rapor kendiliğinden oluşur.
class ClubActivityLog {
  final int? id;
  final int clubId;

  /// "Eylül" … "Haziran".
  final String ay;

  /// O ay gerçekleşen çalışma. Boşsa rapora "—" basılır.
  final String yapilanCalisma;

  /// Katılan üye sayısı. 0 ise rapora yazılmaz.
  final int katilanSayisi;

  const ClubActivityLog({
    this.id,
    required this.clubId,
    required this.ay,
    this.yapilanCalisma = '',
    this.katilanSayisi = 0,
  });

  bool get dolu => yapilanCalisma.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'club_id': clubId,
        'ay': ay,
        'yapilan_calisma': yapilanCalisma,
        'katilan_sayisi': katilanSayisi,
      };

  factory ClubActivityLog.fromMap(Map<String, dynamic> m) => ClubActivityLog(
        id: m['id'] as int?,
        clubId: m['club_id'] as int? ?? 0,
        ay: m['ay'] as String? ?? '',
        yapilanCalisma: m['yapilan_calisma'] as String? ?? '',
        katilanSayisi: (m['katilan_sayisi'] as num?)?.toInt() ?? 0,
      );
}

// ---------------------------------------------------------------------
// Plan düzenlemelerinin saklanması
//
// SQLite'ta ayrı tablo açmak yerine tek sütunda tutuluyor: düzenleme
// nadir, satır sayısı en fazla 10 ve sorgulanmıyor — yalnızca kulüple
// birlikte okunuyor.
//
// Ayraç olarak birim ayırıcı (U+001F) ve kayıt ayırıcı (U+001E)
// kullanılıyor; plan metinlerinde geçemeyecek karakterler oldukları
// için ayrıca kaçış gerekmiyor.
// ---------------------------------------------------------------------

const String _birimAyrac = '\u001F';
const String _kayitAyrac = '\u001E';

String _duzenlemeKodla(Map<String, ClubPlanRow> m) => m.entries
    .map((e) => [
          e.key,
          e.value.amac,
          e.value.etkinlik,
        ].join(_birimAyrac))
    .join(_kayitAyrac);

Map<String, ClubPlanRow> _duzenlemeCoz(String? ham) {
  if (ham == null || ham.isEmpty) return const {};
  final sonuc = <String, ClubPlanRow>{};
  for (final kayit in ham.split(_kayitAyrac)) {
    final parca = kayit.split(_birimAyrac);
    if (parca.length != 3) continue;
    sonuc[parca[0]] = ClubPlanRow(
      ay: parca[0],
      amac: parca[1],
      etkinlik: parca[2],
    );
  }
  return sonuc;
}

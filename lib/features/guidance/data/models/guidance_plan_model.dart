/// Sınıf rehberlik planı ve ORGM etkinlikleri.
///
/// ## Veri nereden geliyor
/// `assets/data/sinif_rehberlik_plani.json.gz` — 13 kademenin
/// (okul öncesi + 1-12) MEB rehberlik planları ve ORGM'nin 458
/// rehberlik etkinliği. Paket `tool/build_rehberlik_dataset.py` ile
/// üretilir, APK ile taşınır, Firestore'a çıkmaz.
///
/// ## Neden bu modül var
/// Rehberlik planı her yıl elle Excel'den kopyalanıyor, etkinlikler
/// ise 745 sayfalık PDF'lerin içinde aranıyordu. Uygulamanın haftalık
/// takvimi zaten var; "bu hafta hangi rehberlik etkinliği" sorusunu
/// otomatik cevaplayabiliyoruz.
library;

/// Plandaki bir satır: kazanım, idari iş veya tatil.
class GuidancePlanItem {
  /// 0 = okul öncesi, 1-12 sınıf düzeyi.
  final int gradeLevel;

  final String ay;

  /// Planın gerçek sırası — tatiller doğru yere otursun diye.
  ///
  /// Tatillerin hafta numarası yok; sıralama yalnızca [hafta] ile
  /// yapılınca hepsi listenin SONUNA düşüyordu. Oysa ara tatil
  /// Kasım'da, yarıyıl Ocak'ta.
  final int ayIndex;
  final int satirIndex;

  /// Kazanım sıra numarası (1-36). İdari iş ve tatilde null.
  final int? siraNo;

  /// Öğretim yılının kaçıncı haftası.
  final int? hafta;

  /// "14-18 EYLÜL" gibi.
  final String tarihAraligi;

  final String kazanim;

  /// Excel'de "(Etkinlik: ...)" parantezinde yazan ad.
  final String? etkinlikAdi;

  /// Ara tatil / yarıyıl tatili satırı.
  final bool tatilMi;

  /// "Rehberlik Yürütme Komisyonu Toplantısı" gibi kazanım olmayan iş.
  final bool idariIsMi;

  const GuidancePlanItem({
    required this.gradeLevel,
    required this.ay,
    this.ayIndex = 99,
    this.satirIndex = 0,
    this.siraNo,
    this.hafta,
    this.tarihAraligi = '',
    required this.kazanim,
    this.etkinlikAdi,
    this.tatilMi = false,
    this.idariIsMi = false,
  });

  factory GuidancePlanItem.fromJson(Map<String, dynamic> j) =>
      GuidancePlanItem(
        gradeLevel: j['gradeLevel'] as int? ?? 0,
        ay: j['ay'] as String? ?? '',
        ayIndex: j['ayIndex'] as int? ?? 99,
        satirIndex: j['satirIndex'] as int? ?? 0,
        siraNo: j['siraNo'] as int?,
        hafta: j['hafta'] as int?,
        tarihAraligi: j['tarihAraligi'] as String? ?? '',
        kazanim: j['kazanim'] as String? ?? '',
        etkinlikAdi: j['etkinlikAdi'] as String?,
        tatilMi: j['tatilMi'] as bool? ?? false,
        idariIsMi: j['idariIsMi'] as bool? ?? false,
      );

  /// Öğretmenin uygulayacağı bir rehberlik kazanımı mı?
  bool get uygulanabilir => siraNo != null && !tatilMi;
}

/// ORGM sınıf rehberlik etkinliği.
class GuidanceActivity {
  final int gradeLevel;
  final int? hafta;
  final String etkinlikAdi;

  /// Akademik / Sosyal Duygusal / Kariyer.
  final String gelisimAlani;

  final String yeterlikAlani;
  final String kazanim;
  final String sure;

  final List<String> onHazirlik;
  final List<String> aracGerecler;

  /// Uygulama basamakları — etkinliğin gövdesi.
  final List<String> surec;

  final String degerlendirme;
  final String uygulayiciyaNot;

  /// "Özel gereksinimli öğrenciler için" uyarlama önerileri.
  ///
  /// BEP'li öğrencisi olan öğretmen için asıl değerli kısım burası;
  /// 458 etkinliğin 334'ünde dolu.
  final List<String> ozelGereksinimUyarlamalari;

  /// Kaynak PDF'teki sayfa — belgeye atıf için.
  final int kaynakSayfa;

  const GuidanceActivity({
    required this.gradeLevel,
    this.hafta,
    required this.etkinlikAdi,
    this.gelisimAlani = '',
    this.yeterlikAlani = '',
    this.kazanim = '',
    this.sure = '',
    this.onHazirlik = const [],
    this.aracGerecler = const [],
    this.surec = const [],
    this.degerlendirme = '',
    this.uygulayiciyaNot = '',
    this.ozelGereksinimUyarlamalari = const [],
    this.kaynakSayfa = 0,
  });

  static List<String> _liste(Object? v) =>
      v is List ? v.map((e) => '$e').toList() : const [];

  factory GuidanceActivity.fromJson(Map<String, dynamic> j) => GuidanceActivity(
        gradeLevel: j['gradeLevel'] as int? ?? 0,
        hafta: j['hafta'] as int?,
        etkinlikAdi: j['etkinlikAdi'] as String? ?? '',
        gelisimAlani: j['gelisimAlani'] as String? ?? '',
        yeterlikAlani: j['yeterlikAlani'] as String? ?? '',
        kazanim: j['kazanim'] as String? ?? '',
        sure: j['sure'] as String? ?? '',
        onHazirlik: _liste(j['onHazirlik']),
        aracGerecler: _liste(j['aracGerecler']),
        surec: _liste(j['surec']),
        degerlendirme: j['degerlendirme'] as String? ?? '',
        uygulayiciyaNot: j['uygulayiciyaNot'] as String? ?? '',
        ozelGereksinimUyarlamalari:
            _liste(j['ozelGereksinimUyarlamalari']),
        kaynakSayfa: j['kaynakSayfa'] as int? ?? 0,
      );

  bool get bepUyarlamasiVar => ozelGereksinimUyarlamalari.isNotEmpty;
}

/// Bir haftanın uygulama kaydı.
///
/// ## Neden ayrı tablo
/// Plan sabit veridir (varlıktan gelir, değişmez). Öğretmenin
/// "uyguladım" işareti ve notu ise kişiseldir; cihazda saklanır.
/// İkisini karıştırmak, varlık her güncellendiğinde öğretmenin
/// kaydını silmek demek olurdu.
class GuidanceLogEntry {
  final int? id;
  final int classId;
  final String academicYear;
  final int gradeLevel;
  final int hafta;

  /// Plandaki kazanım sıra numarası.
  final int siraNo;

  final bool uygulandi;
  final String not;
  final DateTime? uygulanmaTarihi;
  final DateTime updatedAt;

  const GuidanceLogEntry({
    this.id,
    required this.classId,
    required this.academicYear,
    required this.gradeLevel,
    required this.hafta,
    required this.siraNo,
    this.uygulandi = false,
    this.not = '',
    this.uygulanmaTarihi,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'class_id': classId,
        'academic_year': academicYear,
        'grade_level': gradeLevel,
        'hafta': hafta,
        'sira_no': siraNo,
        'uygulandi': uygulandi ? 1 : 0,
        'ogretmen_notu': not,
        'uygulanma_tarihi': uygulanmaTarihi?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory GuidanceLogEntry.fromMap(Map<String, dynamic> m) => GuidanceLogEntry(
        id: m['id'] as int?,
        classId: m['class_id'] as int,
        academicYear: m['academic_year'] as String? ?? '',
        gradeLevel: m['grade_level'] as int? ?? 0,
        hafta: m['hafta'] as int? ?? 0,
        siraNo: m['sira_no'] as int? ?? 0,
        uygulandi: (m['uygulandi'] as int? ?? 0) == 1,
        not: m['ogretmen_notu'] as String? ?? '',
        uygulanmaTarihi: (m['uygulanma_tarihi'] as String?) == null
            ? null
            : DateTime.tryParse(m['uygulanma_tarihi'] as String),
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  GuidanceLogEntry copyWith({
    int? id,
    bool? uygulandi,
    String? not,
    DateTime? uygulanmaTarihi,
  }) =>
      GuidanceLogEntry(
        id: id ?? this.id,
        classId: classId,
        academicYear: academicYear,
        gradeLevel: gradeLevel,
        hafta: hafta,
        siraNo: siraNo,
        uygulandi: uygulandi ?? this.uygulandi,
        not: not ?? this.not,
        uygulanmaTarihi: uygulanmaTarihi ?? this.uygulanmaTarihi,
        updatedAt: DateTime.now(),
      );
}

/// Özel eğitim okulları için özelleştirilmiş rehberlik etkinliği.
///
/// ## Neden ayrı tür
/// ORGM özel eğitim okulları (anaokulu / ilkokul / ortaokul / meslek
/// okulu) için AYRI programlar yayımlıyor ve bunların yapısı genel
/// setten farklı: hafta yok, etkinlik numarası var; kazanımın altında
/// **göstergeler** bulunuyor. Genel plan özel eğitim sınıfında
/// uygulanamadığı için bu belgeler o öğretmenin asıl kaynağı.
class SpecialEducationActivity {
  /// ozelAnaokulu / ozelIlkokul / ozelOrtaokul / ozelMeslek
  final String programKodu;
  final String programAdi;

  final int? etkinlikNo;
  final String gelisimAlani;
  final String kazanim;

  /// Kazanımın ölçülebilir göstergeleri.
  final List<String> gostergeler;

  final List<String> yontemTeknik;
  final List<String> aracGerecler;
  final String sure;
  final List<String> surec;
  final int kaynakSayfa;

  const SpecialEducationActivity({
    required this.programKodu,
    required this.programAdi,
    this.etkinlikNo,
    this.gelisimAlani = '',
    required this.kazanim,
    this.gostergeler = const [],
    this.yontemTeknik = const [],
    this.aracGerecler = const [],
    this.sure = '',
    this.surec = const [],
    this.kaynakSayfa = 0,
  });

  factory SpecialEducationActivity.fromJson(Map<String, dynamic> j) =>
      SpecialEducationActivity(
        programKodu: j['programKodu'] as String? ?? '',
        programAdi: j['programAdi'] as String? ?? '',
        etkinlikNo: j['etkinlikNo'] as int?,
        gelisimAlani: j['gelisimAlani'] as String? ?? '',
        kazanim: j['kazanim'] as String? ?? '',
        gostergeler: GuidanceActivity._liste(j['gostergeler']),
        yontemTeknik: GuidanceActivity._liste(j['yontemTeknik']),
        aracGerecler: GuidanceActivity._liste(j['aracGerecler']),
        sure: j['sure'] as String? ?? '',
        surec: GuidanceActivity._liste(j['surec']),
        kaynakSayfa: j['kaynakSayfa'] as int? ?? 0,
      );
}

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

import '../../../../core/utils/name_formatter.dart';

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

/// Takvim haftasının plandaki karşılığı.
///
/// [hafta]: bu takvim haftasına kadar gelmiş son plan haftası; tatil
/// haftasında tatilden önceki hafta. [tatil]: bu hafta ders yok (ara
/// tatil, yarıyıl ya da yaz). [tatilAdi]: plandaki tatil satırı.
typedef PlanHaftasi = ({int hafta, bool tatil, String? tatilAdi});

/// Takvim haftasını (tatiller dahil sayılır) plan haftasına çevirir.
///
/// ## Neden (29 Ekim 2026)
/// `AppDateFormatter.getCurrentAcademicWeek` tatil haftalarını da sayar,
/// plandaki hafta numarası ise tatilleri atlar: ara tatilden sonra
/// takvimin 11. haftası planın 10. haftasıdır, yarıyıldan sonra fark
/// üç haftaya çıkar. İkisi doğrudan karşılaştırıldığında "bu hafta"
/// işareti kayıyor, toplu işaretleme de henüz gelmemiş haftaları
/// "uygulandı" yapıyordu. Planda her takvim haftasının bir tarih aralığı
/// satırı var (tatiller dahil, boşluksuz); eşleme bu sırayla yapılır.
PlanHaftasi planHaftasi(List<GuidancePlanItem> plan, int takvimHaftasi) {
  final araliklar = <String>[];
  for (final m in plan) {
    if (m.tarihAraligi.isNotEmpty && !araliklar.contains(m.tarihAraligi)) {
      araliklar.add(m.tarihAraligi);
    }
  }
  // Tarih aralığı yoksa eşlenecek bir şey yok; eski davranış.
  if (araliklar.isEmpty) return (hafta: takvimHaftasi, tatil: false, tatilAdi: null);

  final yazda = takvimHaftasi > araliklar.length;
  final i = (takvimHaftasi - 1).clamp(0, araliklar.length - 1);
  final gecen = araliklar.sublist(0, i + 1).toSet();
  var hafta = 0;
  for (final m in plan) {
    if (gecen.contains(m.tarihAraligi) && !m.tatilMi && (m.hafta ?? 0) > hafta) {
      hafta = m.hafta!;
    }
  }
  if (yazda) return (hafta: hafta, tatil: true, tatilAdi: 'YAZ TATİLİ');
  final tatilSatiri = plan
      .where((m) => m.tarihAraligi == araliklar[i] && m.tatilMi)
      .firstOrNull;
  return (hafta: hafta, tatil: tatilSatiri != null, tatilAdi: tatilSatiri?.kazanim);
}

/// Planın 1. dönem satırları: ilk "YARIYIL" tatil satırından öncekiler.
///
/// Yarıyıl satırı bulunamazsa 18. haftaya kadar olanlar alınır (MEB
/// takviminde 1. dönem 18 ders haftası).
List<GuidancePlanItem> birinciDonemMaddeleri(List<GuidancePlanItem> plan) {
  final i = plan.indexWhere((m) => m.tatilMi && m.kazanim.toUpperTr().contains('YARIYIL'));
  if (i >= 0) return plan.sublist(0, i);
  return plan.where((m) => m.hafta == null || m.hafta! <= 18).toList();
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

/// Öğretmen dosyasının özlük bilgileri.
///
/// ## Neden profilde değil de ayrı
/// [TeacherProfileModel] buluta yazılıyor (okul dizini, veli
/// ekranı). Sicil numarası, TC kimlik, mezuniyet ve göreve başlama
/// tarihi **özlük verisi**; projenin veri sahipliği kararı gereği
/// bunlar cihazda kalır, buluta çıkmaz.
///
/// Ad, okul, branş ve müdür adı burada TUTULMAZ — onlar profilde
/// zaten var, iki yerde tutulursa biri eskir.
class TeacherFileInfo {
  /// TC kimlik numarası. Teftiş dosyasında istenir.
  final String nationalId;

  /// MEB sicil numarası.
  final String registryNo;

  /// Mezun olunan yükseköğretim kurumu ve bölüm.
  final String graduation;

  /// Göreve ilk başlama tarihi (gg.aa.yyyy).
  final String startedDutyAt;

  /// Bu okulda göreve başlama tarihi (gg.aa.yyyy).
  final String startedSchoolAt;

  /// Görev/unvan: "Sınıf Öğretmeni", "Müdür Yardımcısı" gibi.
  final String title;

  /// Kadro durumu: "Kadrolu", "Sözleşmeli", "Ücretli".
  final String employmentType;

  /// Öğretmenin telefonu. Dosyada bulunması istenir.
  final String phone;

  /// Kan grubu — acil durum bilgisi olarak dosyada yer alır.
  final String bloodType;

  const TeacherFileInfo({
    this.nationalId = '',
    this.registryNo = '',
    this.graduation = '',
    this.startedDutyAt = '',
    this.startedSchoolAt = '',
    this.title = '',
    this.employmentType = '',
    this.phone = '',
    this.bloodType = '',
  });

  /// Hiçbir alan doldurulmamışsa true.
  ///
  /// Ekran bu durumda "bilgileri doldurun" uyarısı gösterir; belge
  /// yine üretilir ama satırlar noktalı çıkar.
  bool get isEmpty =>
      nationalId.trim().isEmpty &&
      registryNo.trim().isEmpty &&
      graduation.trim().isEmpty &&
      startedDutyAt.trim().isEmpty &&
      startedSchoolAt.trim().isEmpty &&
      title.trim().isEmpty &&
      employmentType.trim().isEmpty &&
      phone.trim().isEmpty &&
      bloodType.trim().isEmpty;

  /// Kaç alanın dolu olduğu — ekranda ilerleme göstermek için.
  int get doluAlanSayisi => [
        nationalId,
        registryNo,
        graduation,
        startedDutyAt,
        startedSchoolAt,
        title,
        employmentType,
        phone,
        bloodType,
      ].where((a) => a.trim().isNotEmpty).length;

  static const int toplamAlanSayisi = 9;

  Map<String, String> toMap() => {
        'national_id': nationalId,
        'registry_no': registryNo,
        'graduation': graduation,
        'started_duty_at': startedDutyAt,
        'started_school_at': startedSchoolAt,
        'title': title,
        'employment_type': employmentType,
        'phone': phone,
        'blood_type': bloodType,
      };

  factory TeacherFileInfo.fromMap(Map<String, dynamic> map) {
    String al(String k) => (map[k] as String?)?.trim() ?? '';
    return TeacherFileInfo(
      nationalId: al('national_id'),
      registryNo: al('registry_no'),
      graduation: al('graduation'),
      startedDutyAt: al('started_duty_at'),
      startedSchoolAt: al('started_school_at'),
      title: al('title'),
      employmentType: al('employment_type'),
      phone: al('phone'),
      bloodType: al('blood_type'),
    );
  }

  TeacherFileInfo copyWith({
    String? nationalId,
    String? registryNo,
    String? graduation,
    String? startedDutyAt,
    String? startedSchoolAt,
    String? title,
    String? employmentType,
    String? phone,
    String? bloodType,
  }) {
    return TeacherFileInfo(
      nationalId: nationalId ?? this.nationalId,
      registryNo: registryNo ?? this.registryNo,
      graduation: graduation ?? this.graduation,
      startedDutyAt: startedDutyAt ?? this.startedDutyAt,
      startedSchoolAt: startedSchoolAt ?? this.startedSchoolAt,
      title: title ?? this.title,
      employmentType: employmentType ?? this.employmentType,
      phone: phone ?? this.phone,
      bloodType: bloodType ?? this.bloodType,
    );
  }
}

/// Öğretmen dosyasında üretilebilecek belgeler.
///
/// Sıra, dosyada durması gereken sırayla aynı — "Tümünü indir"
/// bu sırayla basar.
enum TeacherFileDoc {
  kapak(
    'Dosya Kapağı',
    'Öğretmen adı, branş, okul ve öğretim yılı',
    'MEB.ÖD.01',
  ),
  ataturk(
    'Atatürk Köşesi',
    'Atatürk portresi ve Öğretmenlere Hitap',
    'MEB.ÖD.02',
  ),
  istiklalMarsi(
    'İstiklâl Marşı',
    'On kıtanın tamamı',
    'MEB.ÖD.03',
  ),
  gencligeHitabe(
    'Gençliğe Hitabe',
    'Tam metin',
    'MEB.ÖD.04',
  ),
  kisiselBilgiler(
    'Kişisel Bilgiler Formu',
    'Özlük künyesi — sicil, mezuniyet, göreve başlama',
    'MEB.ÖD.05',
  ),
  dersProgrami(
    'Haftalık Ders Programı',
    'Ders programı ekranındaki veriden',
    'MEB.ÖD.06',
  ),
  sinifListeleri(
    'Sınıf Listeleri',
    'Derse girilen sınıflar ve öğrenci sayıları',
    'MEB.ÖD.07',
  ),
  nobetCizelgesi(
    'Nöbet Çizelgesi',
    'Haftalık nöbet yeri ve saatleri',
    'MEB.ÖD.08',
  ),
  zumreTutanagi(
    'Zümre Toplantı Tutanağı',
    'Gündem maddeli boş tutanak şablonu',
    'MEB.ÖD.09',
  ),
  veliGorusme(
    'Veli Görüşme Kayıt Formu',
    'Tarih, veli, konu ve sonuç sütunlu çizelge',
    'MEB.ÖD.10',
  ),
  yillikPlanKapagi(
    'Ünitelendirilmiş Yıllık Plan Kapağı',
    'Ders, sınıf ve onay bloğu',
    'MEB.ÖD.11',
  ),
  kanaatFormu(
    'Öğrenci Gelişim ve Kanaat Formu',
    'Dönem sonu kanaat çizelgesi',
    'MEB.ÖD.12',
  ),
  odevTakip(
    'Ödev Takip Çizelgesi',
    'Verilen ödev, teslim tarihi ve durum',
    'MEB.ÖD.13',
  );

  const TeacherFileDoc(this.ad, this.aciklama, this.belgeKodu);

  final String ad;
  final String aciklama;
  final String belgeKodu;
}

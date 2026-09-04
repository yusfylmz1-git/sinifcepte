import '../../outcomes/data/models/curriculum_outcome_model.dart';

/// Özel eğitim BEP'inde kullanılan gelişim alanları.
///
/// Bu liste resmi Özel Eğitim Öğretim Programı Excel'i değildir.
/// Destek eğitim programları ve uygulama okulu ders çizelgesindeki
/// alan adlarıyla aynıdır; amaç cümleleri sahada yazılan ölçülebilir
/// davranışlardır. Öğretmen kendi öğrencisine göre işaretler / düzeltir.
class BepDevelopmentalBank {
  BepDevelopmentalBank._();

  static const List<BepDevArea> areas = [
    BepDevArea(
      code: 'DEV_OZBAKIM',
      name: 'Öz bakım',
      skills: [
        'Ellerini bağımsız yıkar ve kurular.',
        'Dişlerini fırçalar.',
        'Yüzünü yıkar.',
        'Tuvalet ihtiyacını bağımsız giderir.',
        'Giysilerini giyer ve çıkarır.',
        'Ayakkabılarını giyer ve çıkarır.',
        'Saçını tarar.',
        'Burnunu siler / mendil kullanır.',
      ],
    ),
    BepDevArea(
      code: 'DEV_GUNLUK',
      name: 'Günlük yaşam',
      skills: [
        'Beslenme sırasında uygun aracı kullanır.',
        'Yemeğini bağımsız yer.',
        'Masayı kurar veya toplar.',
        'Sınıf eşyasını yerine koyar.',
        'Çantasını hazırlar.',
        'Basit bir temizlik işini tamamlar.',
        'Eşyalarını isimlendirerek ister.',
        'Günlük iş sırasında sıra bekler.',
      ],
    ),
    BepDevArea(
      code: 'DEV_TOPLUM',
      name: 'Toplumsal yaşam',
      skills: [
        'Okul içinde hedefe bağımsız gider.',
        'Karşıdan karşıya geçerken beklemeyi uygular.',
        'Alışverişte para / kart uzatır.',
        'Toplu taşımada bilet veya kart kullanır.',
        'Yardım isterken uygun cümle kurar.',
        'Sıra ve kurala uyar.',
        'Tehlike işaretini fark eder, durur.',
        'Tanımadığı kişiye kişisel bilgi vermez.',
      ],
    ),
    BepDevArea(
      code: 'DEV_ILETISIM',
      name: 'Dil ve iletişim',
      skills: [
        'Adı söylendiğinde bakış veya tepki verir.',
        'Tek basamaklı yönergeyi yerine getirir.',
        'İki basamaklı yönergeyi yerine getirir.',
        'İsteklerini sözcük / cümle / alternatif iletişimle belirtir.',
        'Evet-hayır sorusuna uygun cevap verir.',
        'Görüşme sırasında sırasını bekler.',
        'Selam verir ve veda eder.',
        'Kısa bir olayı sırayla anlatır.',
      ],
    ),
    BepDevArea(
      code: 'DEV_SOSYAL',
      name: 'Sosyal beceriler',
      skills: [
        'Akranının yanına uygun mesafede oturur.',
        'Sırasını bekler, paylaşır.',
        'Oyuna katılma isteğini belirtir.',
        'Çatışmada yetişkinden yardım ister.',
        'Öfkesini kabul edilen yolla ifade eder.',
        'Başkasının çalışmasına zarar vermez.',
        'Grup etkinliğinde verilen rolü yapar.',
        'Teşekkür ve özür ifadelerini kullanır.',
      ],
    ),
    BepDevArea(
      code: 'DEV_MOTOR',
      name: 'Motor beceriler',
      skills: [
        'Kalemi uygun kavrar.',
        'Çizgiyi başlangıçtan bitişe çizer.',
        'Makasla basit şekil keser.',
        'Küçük nesneyi başparmak-işaret parmağıyla alır.',
        'Denge tahtasında destekle yürür.',
        'Topu iki elle tutar / atar.',
        'Merdiven iner ve çıkar.',
        'Düğme veya fermuar açıp kapar.',
      ],
    ),
    BepDevArea(
      code: 'DEV_BILISSEL',
      name: 'Bilişsel / öğrenmeye destek',
      skills: [
        'Nesneleri renge göre ayırır.',
        'Nesneleri büyüklüğe göre sıralar.',
        '1-10 arası nesneyi sayar.',
        'Aynı-farklı ayrımı yapar.',
        'Basit neden-sonuç sorusuna cevap verir.',
        'Modeli taklit ederek deseni tamamlar.',
        'İşlemi modelden bakarak adım adım yapar.',
        'Kısa bir yönergeyi işitince işe başlar.',
      ],
    ),
    BepDevArea(
      code: 'DEV_OKUMA',
      name: 'Okuma-yazma (işlevsel)',
      skills: [
        'Adını yazar.',
        'Adını okur.',
        'Sık görülen çevre yazılarını okur (WC, çıkış, kantin).',
        'Ses-harf eşlemesi yapar.',
        'Kısa hece ve kelime okur.',
        'Kısa cümleyi kopya eder.',
        'Günlük çizelgedeki resmi/yazıyı takip eder.',
        'Deftere satır aralığında yazar.',
      ],
    ),
    BepDevArea(
      code: 'DEV_MATEMATIK',
      name: 'Matematik (işlevsel)',
      skills: [
        '1-10 arası ritmik sayar.',
        'Nesne sayısını rakamla eşler.',
        'İki grup nesneyi az-çok diye karşılaştırır.',
        'Toplama gerektiren somut problemi nesneyle çözer.',
        'Paranın miktarını günlük alışverişte kullanır.',
        'Saat/çizelgede etkinlik saatini gösterir.',
        'Basit ölçme yapar (uzun-kısa, dolu-boş).',
        'Sıra sayısı söyler (birinci, ikinci).',
      ],
    ),
    BepDevArea(
      code: 'DEV_GUVENLIK',
      name: 'Sağlıklı yaşam ve güvenlik',
      skills: [
        'Tehlike durumunda durur ve yetişkine haber verir.',
        'İlaç/temizlik maddesine dokunmaz.',
        'Yabancıyla gitmez.',
        'Yangın/deprem tatbikatında yönergeyi izler.',
        'Yaralanınca yardım ister.',
        'Besin alerjisi/yasak yiyeceği reddeder.',
        'Okul bahçesi sınırında kalır.',
        'Araç içi emniyet kemerini takar (yardımla veya bağımsız).',
      ],
    ),
  ];

  static List<Map<String, dynamic>> dropdownItems() {
    return [
      for (final a in areas)
        {'subject_code': a.code, 'subject_name': a.name},
    ];
  }

  static BepDevArea? areaByCode(String code) {
    final c = code.trim();
    for (final a in areas) {
      if (a.code == c) return a;
    }
    return null;
  }

  static List<UniqueOutcomeHit> hits(String areaCode) {
    final area = areaByCode(areaCode);
    if (area == null) return const [];
    return [
      for (var i = 0; i < area.skills.length; i++)
        UniqueOutcomeHit(
          code: '${area.code}.${i + 1}',
          description: area.skills[i],
          unitTitle: area.name,
          subjectCode: area.code,
          subjectName: area.name,
        ),
    ];
  }
}

class BepDevArea {
  final String code;
  final String name;
  final List<String> skills;

  const BepDevArea({
    required this.code,
    required this.name,
    required this.skills,
  });
}

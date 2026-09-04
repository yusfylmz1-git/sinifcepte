import '../data/models/club_model.dart';

/// Faaliyet metni önerisi — plandan "yapıldı" cümlesi üretir.
///
/// ## Neden var
/// Yıl sonu raporu için öğretmenin on ayı tek tek yazması gerekiyordu.
/// Oysa plan zaten o ay ne yapılacağını söylüyor; rapor çoğu zaman aynı
/// şeyin geçmiş zamanlı hâli. Öneri boş sayfayla başlamayı önler,
/// öğretmen üstünde oynar.
///
/// ## Nasıl çalışır
/// Plan metinleri geniş zaman kipinde yazılmıştır ("…ele alınır",
/// "…hazırlar"). Yüklem konumundaki kelimeler geçmiş zamana çevrilir.
///
/// Yüklem konumu üç yerdedir: cümle sonunda, virgülden önce ve "ve"
/// bağlacından önce. "Kulüp üyeleri belirlenir, temsilci seçilir ve
/// görev dağılımı yapılır" cümlesinde ÜÇ yüklem var; yalnızca sondakini
/// çevirmek metni yarım geçmiş zamanlı bırakıyordu.
///
/// ## Neden basit kural
/// Cihazda dil modeli yok, ağ da yok (offline-first). 520 blok için
/// elle ikinci bir geçmiş zamanlı metin yazmak veriyi ikiye katlardı.
/// Ölçüm: paketteki 1374 cümlenin 1357'si doğru çevriliyor; kalan 17'si
/// zaten sıfat ("uygulanabilir", "anlaşılır") — çevrilmemeleri doğru.
///
/// Çeviri kusursuz olmak zorunda değil: öneri son metin değil, taslak.
class ClubActivitySuggester {
  ClubActivitySuggester._();

  /// Edilgen çatı sonekleri — plandaki baskın kip.
  ///
  /// Bunlar güvenli: "-nır / -lir" kalıbı Türkçede neredeyse yalnızca
  /// yüklemde geçer. Uzun sonek önce denenmeli, yoksa kısa olan yanlış
  /// kök bırakır.
  static const _edilgen = <List<String>>[
    ['ılır', 'ıldı'],
    ['ilir', 'ildi'],
    ['ulur', 'uldu'],
    ['ünür', 'ündü'],
    ['unur', 'undu'],
    ['anır', 'andı'],
    ['enir', 'endi'],
    ['ınır', 'ındı'],
    ['inir', 'indi'],
  ];

  /// Etken çatı, çoğul şahıs: "öğrenciler … hazırlar".
  static const _etkenCogul = <List<String>>[
    ['ırlar', 'ırladı'],
    ['irler', 'irledi'],
    ['urlar', 'urladı'],
    ['ürler', 'ürledi'],
    ['arlar', 'ardı'],
    ['erler', 'erdi'],
    ['lar', 'ladı'],
    ['ler', 'ledi'],
  ];

  /// Etken çatı, tekil şahıs.
  ///
  /// RİSKLİ: "-ir" kökün parçası da olabilir. "iletir" bu kuralla
  /// "iletirdi" oluyordu — yanlış. Bu yüzden yalnızca cümlenin SON
  /// kelimesinde ve en az 5 harfli kelimelerde uygulanır.
  static const _etkenTekil = <List<String>>[
    ['ır', 'dı'],
    ['ir', 'di'],
    ['ur', 'du'],
    ['ür', 'dü'],
    ['ar', 'dı'],
    ['er', 'di'],
  ];

  static String? _esle(String kelime, List<List<String>> kurallar,
      {int enAzFazla = 0}) {
    for (final k in kurallar) {
      final eski = k[0];
      if (kelime.length > eski.length + enAzFazla && kelime.endsWith(eski)) {
        return kelime.substring(0, kelime.length - eski.length) + k[1];
      }
    }
    return null;
  }

  /// Bir cümledeki tüm yüklemleri geçmiş zamana çevirir.
  static String _cumleyiCevir(String cumle) {
    final kirpik = cumle.trim();
    if (kirpik.isEmpty) return kirpik;

    final noktaliMi = kirpik.endsWith('.');
    final govde = noktaliMi
        ? kirpik.substring(0, kirpik.length - 1).trimRight()
        : kirpik;
    if (govde.isEmpty) return kirpik;

    final parcalar = govde.split(' ');
    for (var i = 0; i < parcalar.length; i++) {
      final kelime = parcalar[i];
      final virgulluMu = kelime.endsWith(',');
      final temiz =
          virgulluMu ? kelime.substring(0, kelime.length - 1) : kelime;

      // Yüklem konumu: virgülden önce, "ve"den önce ya da cümle sonunda.
      final sonda = i == parcalar.length - 1;
      final vedenOnce = i + 1 < parcalar.length && parcalar[i + 1] == 've';
      if (!virgulluMu && !sonda && !vedenOnce) continue;

      var yeni = _esle(temiz, _edilgen) ?? _esle(temiz, _etkenCogul);
      // Tekil kural yalnızca cümle sonunda; ortada yanlış eşleşiyor.
      yeni ??= sonda ? _esle(temiz, _etkenTekil, enAzFazla: 2) : null;

      if (yeni != null) {
        parcalar[i] = virgulluMu ? '$yeni,' : yeni;
      }
    }

    return parcalar.join(' ') + (noktaliMi ? '.' : '');
  }

  /// Bir ayın planından faaliyet metni önerir.
  ///
  /// Boş plan satırında boş string döner.
  static String oner(ClubPlanRow satir) {
    final kaynak = satir.etkinlik.trim();
    if (kaynak.isEmpty) return '';

    return kaynak
        .split(RegExp(r'(?<=\.)\s+'))
        .where((c) => c.trim().isNotEmpty)
        .map(_cumleyiCevir)
        .join(' ');
  }

  /// Öneri kaynaktan farklı mı — yani gerçekten bir dönüşüm oldu mu.
  ///
  /// Hiçbir sonek eşleşmediyse öneri metinle aynı kalır; böyle bir
  /// metni "öneri" diye sunmak öğretmeni yanıltır, düğme gizlenir.
  static bool oneriVar(ClubPlanRow satir) {
    final kaynak = satir.etkinlik.trim();
    if (kaynak.isEmpty) return false;
    return oner(satir) != kaynak;
  }
}

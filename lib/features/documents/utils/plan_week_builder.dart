import '../../outcomes/data/models/curriculum_outcome_model.dart';

/// Yıllık ve günlük plan ekranlarının ORTAK hafta üretimi.
///
/// ## Neden ayrı dosya
/// Bu mantık iki ekrana (yillik/gunluk) kopyalanmıştı: ~1400 satırın
/// her biri kendi `_donustur` kopyasını taşıyordu ve kopyalar zaten
/// birbirinden sapmıştı — günlük plan tarihi satırdaki `dateRangeStr`
/// alanından, yıllık plan ise yeniden numaralanmış hafta sırasından
/// hesaplıyordu. Aynı ders iki ekranda iki farklı tarih gösteriyordu.
/// Bir hatayı birinde düzeltip diğerinde unutmak kaçınılmazdı.
///
/// Üretim kuralları tek yerde toplandı; iki ekran da buradan okur.
class PlanWeekBuilder {
  PlanWeekBuilder._();

  /// Ders haftalarını süzer.
  ///
  /// ## Neden `teaching_week_number`
  /// Önceki süzgeç `is_holiday_week` yanında ünite/konu metninde
  /// "tatil" kelimesi arıyordu. Veri incelendiğinde bu metin aramasının
  /// 77 GERÇEK ders satırını sildiği görüldü:
  ///
  ///   - 10. sınıf Arapça "ÜNİTE 4: Tatile Hazırlanıyorum" → 7 hafta
  ///   - Beden Eğitimi, Almanca, seçmeliler → "Yarıyıl Tatili" başlıklı
  ///     ama `teaching_week_number` dolu, yani işlenen ders haftası
  ///
  /// Paket verisinde `teaching_week_number` ile `is_holiday_week`
  /// TAM ÖRTÜŞÜYOR: 1036 tatil satırının hepsinde alan null, 9065 ders
  /// satırının hepsinde dolu. Tek ölçüt bu alan; metin araması yok.
  static List<Map<String, dynamic>> dersHaftalari(
    List<Map<String, dynamic>> satirlar,
  ) {
    // Eski tohumlamada sutun bos olabilir.
    //
    // `teaching_week_number` tabloya ALTER TABLE ile sonradan eklendi;
    // ALTER ile eklenen sutun mevcut satirlarda NULL kalir. Paket surumu
    // artmadan guncelleme alan cihazda tum satirlarda bos olur ve tek
    // olcut bu sutun olursa HER SATIR elenir — ekran "plan bulunamadi"
    // der. Cihazda bire bir gozlendi.
    //
    // Paket surumu 6'ya cikarilarak sutun dolduruluyor, ama yine de
    // hicbir satirda deger yoksa eski olcute (`is_holiday_week`)
    // duselim: bos ekran gostermektense tatil haftasi biraz sapsin.
    final sutunDolu = satirlar.any((s) => s['teaching_week_number'] != null);

    final dersler = sutunDolu
        ? satirlar.where((s) => s['teaching_week_number'] != null).toList()
        : satirlar
            .where((s) => (s['is_holiday_week'] as int? ?? 0) != 1)
            .toList();

    if (!sutunDolu) {
      // Sutun yoksa kaynak sira korunur; hafta no `week_number`den okunur.
      dersler.sort((a, b) {
        final ha = (a['week_number'] as num?)?.toInt() ?? 0;
        final hb = (b['week_number'] as num?)?.toInt() ?? 0;
        return ha.compareTo(hb);
      });
      return dersler;
    }

    // Aynı ders haftasına birden çok kazanım satırı düşebilir; plan
    // haftası tekil olmalı. Sıralama ders haftasına göre yapılır.
    dersler.sort((a, b) {
      final ha = (a['teaching_week_number'] as num).toInt();
      final hb = (b['teaching_week_number'] as num).toInt();
      if (ha != hb) return ha.compareTo(hb);
      final ia = (a['id'] as num?)?.toInt() ?? 0;
      final ib = (b['id'] as num?)?.toInt() ?? 0;
      return ia.compareTo(ib);
    });

    return dersler;
  }

  /// Satırın kendi ders haftası numarası.
  ///
  /// Sıra indeksi (`i + 1`) KULLANILMAZ. Tatil haftaları atıldıktan
  /// sonra yeniden numaralamak, takvim haftasıyla ders haftasını
  /// birbirine karıştırıyordu: 10. ders haftası, takvimdeki 10. haftanın
  /// (ara tatil) tarihini alıyordu. İlk tatilden sonra PDF'teki her
  /// tarih bir hafta kayıyordu.
  /// Sutun bos olan eski tohumlamada `week_number`e duser.
  static int dersHaftaNo(Map<String, dynamic> satir) =>
      (satir['teaching_week_number'] as num?)?.toInt() ??
      (satir['week_number'] as num?)?.toInt() ??
      1;

  /// Satırın takvim haftası — tarih aralığı bundan hesaplanır.
  static int takvimHaftaNo(Map<String, dynamic> satir) =>
      (satir['week_number'] as num?)?.toInt() ?? dersHaftaNo(satir);

  /// Haftanın tarih aralığı.
  ///
  /// Öncelik satırdaki hazır `date_range_str` alanındadır; MEB
  /// takvimiyle üretilmiş olduğu için en güvenilir kaynak odur.
  /// Yoksa TAKVİM haftasından hesaplanır (ders haftasından değil).
  static String tarihAraligi(
    Map<String, dynamic> satir,
    String Function(int) takvimdenHesapla,
  ) {
    final ham = (satir['date_range_str'] ?? '').toString().trim();
    final temiz = ham.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (temiz.isNotEmpty) return temiz;
    return takvimdenHesapla(takvimHaftaNo(satir));
  }

  /// Dersin MEB haftalık ders saati.
  ///
  /// ## Neden elle harita
  /// Müfredat paketinde (10.101 kayıt, 39 alan) haftalık ders saati
  /// alanı HİÇ YOK. Kod `m['lesson_hours'] ?? '2'` yazdığı için her
  /// ders PDF'te "2 saat" görünüyordu: Türkçe 6, Matematik 5, Beden 5
  /// saatken. Teftişte ilk bakılan kolon budur.
  ///
  /// Kaynak: MEB Talim ve Terbiye Kurulu haftalık ders çizelgeleri.
  /// Bilinmeyen ders için null döner; çağıran taraf kolonu boş bırakıp
  /// öğretmenin doldurmasını ister — yanlış sayı basmaktan iyidir.
  static int? haftalikDersSaati(int sinif, String dersKodu) {
    final kod = dersKodu.toUpperCase();

    // İlkokul (1-4)
    if (sinif >= 1 && sinif <= 4) {
      const ilkokul = <String, List<int>>{
        // kod: [1.sınıf, 2, 3, 4]
        'TURKCE': [10, 10, 8, 8],
        'MAT': [5, 5, 5, 5],
        'HAYAT': [4, 4, 3, 0],
        'FEN': [0, 0, 3, 3],
        'SOSYAL': [0, 0, 0, 3],
        'DIN': [0, 0, 0, 2],
        'INGILIZCE': [0, 2, 2, 2],
        'GORSEL': [1, 1, 1, 1],
        'MUZIK': [1, 1, 1, 1],
        'BEDEN_OYUN': [5, 5, 5, 2],
        'BEDEN': [5, 5, 5, 2],
        // 4. sınıfta zorunlu, 1-3'te uygulanmıyor.
        'INSAN_HAKLARI_YURTTASLIK': [0, 0, 0, 2],
        'TRAFIK': [0, 0, 0, 1],
        'SAGLIK': [0, 0, 0, 1],
        'TEMEL_DINI': [2, 2, 0, 0],
        'KURAN_ANLAM': [2, 2, 0, 0],
      };
      final satir = ilkokul[kod];
      if (satir == null) return null;
      final saat = satir[sinif - 1];
      return saat > 0 ? saat : null;
    }

    // Ortaokul (5-8)
    if (sinif >= 5 && sinif <= 8) {
      const ortaokul = <String, List<int>>{
        // kod: [5.sınıf, 6, 7, 8]
        'TURKCE': [6, 6, 5, 5],
        'MAT': [5, 5, 5, 5],
        'FEN': [4, 4, 4, 4],
        'SOSYAL': [3, 3, 3, 0],
        'INKILAP': [0, 0, 0, 2],
        'DIN': [2, 2, 2, 2],
        'INGILIZCE': [3, 4, 4, 4],
        'GORSEL': [1, 1, 1, 1],
        'MUZIK': [1, 1, 1, 1],
        'BEDEN': [2, 2, 2, 2],
        'BILISIM': [2, 2, 0, 0],
        'ARAPCA': [2, 2, 2, 2],
        'ALMANCA': [2, 2, 2, 2],
        'ALMANCA_CYDEM': [2, 2, 2, 2],
        'INGILIZCE_CYDEM': [2, 2, 2, 2],
        'KURAN': [2, 2, 2, 2],
        'PEYGAMBER': [2, 2, 2, 2],
        'TEMEL_DINI': [2, 2, 2, 2],
        'BILIM_UYG': [2, 2, 2, 2],
        'MAT_BILIM_UYG': [2, 2, 2, 2],
        'MASAL_VE_DESTANLARIMIZ': [2, 2, 0, 0],
        'GORGU_KURALLARI_VE_NEZAK': [2, 2, 2, 2],
        'RITIM_EGITIMI_VE_HALK_OY': [2, 2, 2, 2],
        'YAZARLIK_VE_YAZMA_BECERI': [0, 2, 2, 2],
        'TEKNO_TASARIM': [0, 0, 2, 2],
        'INSAN_HAKLARI_YURTTASLIK': [0, 0, 0, 0],
      };
      final satir = ortaokul[kod];
      if (satir == null) return null;
      final saat = satir[sinif - 5];
      return saat > 0 ? saat : null;
    }

    // Lise (9-12)
    if (sinif >= 9 && sinif <= 12) {
      const lise = <String, List<int>>{
        // kod: [9.sınıf, 10, 11, 12]
        'EDEBIYAT': [5, 5, 5, 5],
        'TURKCE': [5, 5, 5, 5],
        'MAT': [6, 6, 6, 6],
        'FIZIK': [2, 2, 4, 4],
        'KIMYA': [2, 2, 4, 4],
        'BIYOLOJI': [2, 2, 4, 4],
        'TARIH': [2, 2, 2, 0],
        'INKILAP': [0, 0, 0, 2],
        'COGRAFYA': [2, 2, 2, 2],
        'DIN': [2, 2, 2, 2],
        'INGILIZCE': [4, 4, 4, 4],
        'FELSEFE': [0, 2, 2, 0],
        'SAGLIK': [2, 0, 0, 0],
        'GORSEL': [2, 2, 2, 2],
        'MUZIK': [2, 2, 2, 2],
        'BEDEN': [2, 2, 2, 2],
        'BEDEN_TEMEL': [2, 2, 2, 2],
        'ATLETIK_PERF': [2, 2, 2, 2],
        'ARAPCA': [2, 2, 2, 2],
        'ALMANCA': [2, 2, 2, 2],
        'MATEMATIK': [6, 6, 6, 6],
        'PSIKOLOJI': [0, 0, 2, 0],
        'SOSYOLOJI': [0, 0, 2, 0],
        'MANTIK': [0, 0, 2, 0],
        'SOSYAL_BILIM': [0, 0, 2, 2],
        // İmam Hatip meslek dersleri
        'KURAN': [4, 4, 4, 4],
        'PEYGAMBER': [2, 2, 2, 2],
        'TEMEL_DINI': [2, 2, 2, 2],
        'FIKIH': [0, 2, 2, 2],
        'HADIS': [0, 2, 2, 2],
        'SIYER': [0, 2, 2, 2],
        'AKAID': [0, 0, 2, 2],
        'TEFSIR': [0, 0, 2, 2],
        'KELAM': [0, 0, 0, 2],
        'HITABET': [0, 0, 2, 2],
        'ISLAM_KULTUR': [0, 0, 0, 2],
      };
      final satir = lise[kod];
      if (satir == null) return null;
      final saat = satir[sinif - 9];
      return saat > 0 ? saat : null;
    }

    return null;
  }

  /// PDF'te ders saati kolonuna yazılacak metin.
  ///
  /// Bilinmeyen derste sayı UYDURULMAZ; öğretmenin elle doldurması için
  /// çizgi basılır.
  static String dersSaatiMetni(int sinif, String dersKodu) {
    final saat = haftalikDersSaati(sinif, dersKodu);
    return saat?.toString() ?? '—';
  }

  /// Haftanın öğretim etkinlikleri.
  ///
  /// ## Neden hafta numarasına bakılıyor
  /// Resmî etkinlik alanı ders haftalarının %56'sında (9065 satırın
  /// 5043'ünde) boş. Eski kod boş olan HER haftaya "Öğretim yılının ilk
  /// dersi olduğu için öğrencilerle tanışılır" cümlesini basıyordu —
  /// mart ayındaki 22. haftanın planında bile. 5. sınıf Türkçe'de bu
  /// alan 35 haftanın hepsinde boş, yani öğretmen 35 kez "ilk ders"
  /// yazan bir plan indiriyordu.
  ///
  /// Tanışma metni yalnızca 1. haftada kullanılır. Diğer haftalarda
  /// dersin kendi Maarif özeti (`maarif_summary`, veride %100 dolu)
  /// kaynak alınır.
  static List<String> etkinlikAdimlari({
    required Map<String, dynamic> satir,
    required int haftaNo,
    required String temaBasligi,
    required List<String> surecBilesenleri,
  }) {
    final resmiEtkinlik = (satir['official_activity'] ?? '').toString().trim();

    if (resmiEtkinlik.isNotEmpty) {
      final cumleler = resmiEtkinlik
          .replaceAll(RegExp(r'FARKLILAŞTIRMA.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'ÖĞRETMEN YANSITMALARI.*$', caseSensitive: false), '')
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 15 && !s.contains('http') && !s.contains('karekod'))
          .toList();
      if (cumleler.isNotEmpty) return cumleler.take(5).toList();
    }

    final adimlar = <String>[];

    // Tanışma YALNIZCA gerçekten ilk haftada.
    if (haftaNo == 1) {
      adimlar.add(
        'Öğretim yılının ilk dersi olduğu için öğrencilerle tanışılır, dersin içeriği ve işleyişi hakkında bilgi verilir.',
      );
      adimlar.add(
        'Ders işlenişinde izlenecek yöntemler ve derslik kuralları beyin fırtınası yöntemiyle öğrencilerle birlikte belirlenir.',
      );
    }

    final ozet = (satir['maarif_summary'] ?? '').toString().trim();
    if (ozet.isNotEmpty) {
      adimlar.add(ozet);
    }

    adimlar.add(
      'Etkileşimli tahta ve ders kitabı eşliğinde $temaBasligi konusuna ilişkin temel kavramlar soru-cevap yöntemiyle açıklanır.',
    );

    for (final adim in surecBilesenleri.take(3)) {
      adimlar.add(adim);
    }

    adimlar.add(
      'Kazanım pekiştirme ve değerlendirme etkinlikleriyle ders sonlandırılır.',
    );

    return adimlar;
  }

  /// Plan üretilebilir mi?
  ///
  /// Veri yokken 36 haftalık UYDURMA plan üretiliyordu (`_varsayilanHaftaPlani`),
  /// hem de sessizce: öğretmen boş bir dersin planını "hazır" sanıp
  /// teftişe götürebiliyordu. Artık üretilmiyor; ekran nedenini yazıyor.
  static bool planUretilebilir(List<Map<String, dynamic>> dersHaftalari) =>
      dersHaftalari.isNotEmpty;

  /// Pasif kartta gösterilecek gerekçe.
  static String planYokGerekcesi(String dersAdi, int sinif) =>
      '$dersAdi ($sinif. sınıf) dersinin haftalık plan verisi bu müfredat '
      'paketinde bulunmuyor. Plan üretilebilmesi için kazanım verisinin '
      'pakete eklenmesi gerekir.';

  /// Kazanım metinlerini ve süreç bileşenlerini ayrıştırır.
  static ({List<String> ciktilar, List<String> surec}) kazanimlar(
    Map<String, dynamic> satir,
    String dersAdi,
    int haftaNo,
  ) {
    final ciktilar = <String>[];
    final surec = <String>[];

    final parcalar = OutcomePart.listFromDbText(satir['outcome_parts'] as String?);
    final kazanimKodu = (satir['outcome_code'] ?? '').toString().trim();
    final aciklama = (satir['outcome_description'] ?? '').toString().trim();

    if (parcalar.isNotEmpty) {
      for (final p in parcalar) {
        final kod = p.code?.trim() ?? '';
        final metin = p.text.trim();
        if (metin.isNotEmpty) {
          ciktilar.add(kod.isNotEmpty && !metin.startsWith(kod) ? '$kod. $metin' : metin);
        }
        for (final adim in p.steps) {
          final temiz = adim.trim();
          if (temiz.isNotEmpty && !surec.contains(temiz)) surec.add(temiz);
        }
      }
    } else if (aciklama.isNotEmpty) {
      ciktilar.add(
        kazanimKodu.isNotEmpty && !aciklama.startsWith(kazanimKodu)
            ? '$kazanimKodu. $aciklama'
            : aciklama,
      );
    }

    if (ciktilar.isEmpty) {
      ciktilar.add('$dersAdi $haftaNo. Hafta Öğrenme Çıktısı');
    }

    return (ciktilar: ciktilar, surec: surec);
  }
}

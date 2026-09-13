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

  /// Bir ders haftasının tam plan haritasını kurar.
  ///
  /// ## Neden burada
  /// Bu mantık iki ekrana (`annual_plans_view`, `daily_plans_view`)
  /// `_donustur` adıyla KOPYALANMIŞTI ve kopyalar birbirinden sapmıştı:
  /// SDB varsayılan metni, disiplinler arası ilişki cümlesi ve yıl sonu
  /// haftası üçü de farklıydı. Daha önce aynı kopyalardan bir tarih
  /// hatası çıkmıştı (bkz. `tarihAraligi`).
  ///
  /// Ayrıca iki kopya da ekran DURUMUNA bağlıydı (`_seciliSinif`,
  /// `_seciliDersKodu`…), yani ekran açmadan plan üretmek imkânsızdı.
  /// Sohbet asistanının "5. sınıf türkçe yıllık plan" diyebilmesi için
  /// bu bağın kopması gerekiyordu: fonksiyon artık parametre alıyor.
  ///
  /// [ayrintili] günlük plan içindir: dikkat çekme, güdüleme, derse
  /// geçiş, etkinlik adımları, özet ve farklılaştırma yalnızca orada
  /// basılır. Yıllık PDF `ogretim_sureci` alanlarını hiç okumaz.
  static Map<String, dynamic> haftaPlani({
    required Map<String, dynamic> satir,
    required int haftaNo,
    required int sinif,
    required String dersKodu,
    required String Function(int) takvimdenTarih,
    String? dersAdi,
    bool ayrintili = false,
  }) {
    final ad = dersAdi ?? satir['subject_name']?.toString() ?? 'Ders';
    final rawUnitTitle = (satir['unit_title'] ?? '').toString().trim();
    final rawTopicTitle = (satir['topic_title'] ?? '').toString().trim();
    final rawDesc = (satir['outcome_description'] ?? '').toString().trim();
    final kazanimKodu = (satir['outcome_code'] ?? '').toString().trim();
    final parcalar =
        OutcomePart.listFromDbText(satir['outcome_parts'] as String?);

    // MEB resmî kazanımı veya ders konusu mevcut mu?
    final bool gercekIcerik = parcalar.isNotEmpty ||
        (kazanimKodu.isNotEmpty && kazanimKodu != 'TATIL') ||
        (rawDesc.isNotEmpty &&
            !rawDesc.toLowerCase().contains('planlanmamış') &&
            !rawDesc.toLowerCase().contains('kazanım belirtilmemiş'));

    // Yalnızca gerçek konu/kazanım YOKSA zümre planlaması (OTP) sayılır.
    final bool otpHaftasi = !gercekIcerik &&
        (rawUnitTitle.toLowerCase().contains('planlanmamış') ||
            rawTopicTitle.toLowerCase().contains('planlanmamış') ||
            rawDesc.toLowerCase().contains('planlanmamış') ||
            rawUnitTitle.toLowerCase().contains('okul temelli') ||
            rawTopicTitle.toLowerCase().contains('okul temelli'));

    String temizle(String s) => s
        .replaceAll(
            RegExp(r'OKUL TEMELLİ PLANLAMA\*?\s*[-/]?\s*',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'Planlanmamış Hafta', caseSensitive: false), '')
        .trim();

    final cleanUnit = temizle(rawUnitTitle);
    final cleanTopic = temizle(rawTopicTitle);

    final String tema;
    if (cleanUnit.isNotEmpty && cleanTopic.isNotEmpty) {
      tema = cleanUnit.toLowerCase() == cleanTopic.toLowerCase()
          ? cleanUnit
          : '$cleanUnit - $cleanTopic';
    } else if (cleanTopic.isNotEmpty) {
      tema = cleanTopic;
    } else if (cleanUnit.isNotEmpty) {
      tema = cleanUnit;
    } else {
      tema = haftaNo >= 35
          ? 'Yıl Sonu Genel Değerlendirme ve Pekiştirme'
          : 'Kazanım Pekiştirme ve Ara Değerlendirme';
    }

    final ciktilar = <String>[];
    final surec = <String>[];

    if (parcalar.isNotEmpty) {
      for (final p in parcalar) {
        final kod = p.code?.trim() ?? '';
        final metin = p.text.trim();
        if (metin.isNotEmpty) {
          ciktilar.add(
              kod.isNotEmpty && !metin.startsWith(kod) ? '$kod. $metin' : metin);
        }
        for (final adim in p.steps) {
          final t = adim.trim();
          if (t.isNotEmpty && !surec.contains(t)) surec.add(t);
        }
      }
    } else if (rawDesc.isNotEmpty &&
        !rawDesc.toLowerCase().contains('planlanmamış') &&
        !rawDesc.toLowerCase().contains('kazanım belirtilmemiş')) {
      ciktilar.add(rawDesc);
    } else if (otpHaftasi) {
      ciktilar.add(
        'MEB resmî çerçeve planı uyarınca; zümre öğretmenler kurulunca ders '
        'kapsamında kararlaştırılan kazanım pekiştirme, araştırma ve gözlem, '
        'proje çalışmaları ve telafi/pekiştirme uygulamaları yürütülür.',
      );
      surec.addAll([
        'a) Zümre öğretmenler kurulu kararları doğrultusunda belirlenen araştırma, gözlem ve proje hedefleri öğrencilerle paylaşılır.',
        'b) Önceki ünitelerde yer alan temel kavram ve beceri eksiklikleri tespit edilerek kavram pekiştirme etkinlikleri yürütülür.',
        'c) Çoklu ortam materyalleri, çalışma yaprakları ve etkileşimli tahta uygulamalarıyla pekiştirme çalışmaları tamamlanır.',
      ]);
    }

    if (!otpHaftasi && ciktilar.isEmpty) {
      final adimDeseni = RegExp(r'([a-z]\)\s*[^a-z\)]+)');
      final eslesmeler = adimDeseni.allMatches(rawDesc);
      if (eslesmeler.isNotEmpty) {
        for (final m in eslesmeler) {
          final s = m.group(1)?.trim();
          if (s != null && s.isNotEmpty) surec.add(s);
        }
        final govde = rawDesc
            .replaceAll(adimDeseni, '')
            .trim()
            .replaceAll(RegExp(r'\|\s*$'), '')
            .trim();
        ciktilar.add(kazanimKodu.isNotEmpty && !govde.startsWith(kazanimKodu)
            ? '$kazanimKodu. $govde'
            : (govde.isNotEmpty ? govde : '$ad $haftaNo. Hafta Öğrenme Çıktısı'));
      } else {
        ciktilar.add(kazanimKodu.isNotEmpty && !rawDesc.startsWith(kazanimKodu)
            ? '$kazanimKodu. $rawDesc'
            : (rawDesc.isNotEmpty
                ? rawDesc
                : '$ad $haftaNo. Hafta Öğrenme Çıktısı'));
      }
    }

    // Beceriler ve değerler
    final rawSkills = (satir['maarif_skills'] ?? '').toString().trim();
    final rawValues = (satir['maarif_values'] ?? '').toString().trim();

    var sdb = '';
    var ob = '';
    var abKb = '';
    if (rawSkills.isNotEmpty) {
      final sdbList = <String>[];
      final obList = <String>[];
      final digerList = <String>[];
      for (final t in rawSkills
          .split(RegExp(r',\s*|\s+(?=(?:SDB|OB|AB|KB|FBAB)\d)'))) {
        final token = t.trim();
        if (token.isEmpty) continue;
        if (token.startsWith('SDB')) {
          sdbList.add(token);
        } else if (token.startsWith('OB')) {
          obList.add(token);
        } else {
          digerList.add(token);
        }
      }
      sdb = sdbList.join(', ');
      ob = obList.join(', ');
      abKb = digerList.join(', ');
    }
    if (sdb.isEmpty) {
      sdb = 'SDB1.1. Kendini Tanıma (Öz Farkındalık), SDB1.2. Kendini '
          'Düzenleme (Öz Düzenleme), SDB2.1. İletişim, SDB2.2. İş Birliği';
    }
    if (ob.isEmpty) {
      ob = 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık, '
          'OB4. Görsel Okuryazarlık';
    }
    if (abKb.isEmpty) {
      abKb = 'Alan Becerileri ve Bilimsel Sorgulama, KB2.4. Çözümleme';
    }
    final degerler = rawValues.isNotEmpty
        ? rawValues
        : 'D3. Çalışkanlık, D4. Dostluk, D14. Saygı, D16. Sorumluluk';

    final plan = <String, dynamic>{
      'meta': {
        'ders': ad,
        'sinif': '$sinif. Sınıf',
        'hafta': '$haftaNo. Hafta',
        'tarih_araligi': tarihAraligi(satir, takvimdenTarih),
        'ders_saati': dersSaatiMetni(sinif, dersKodu),
        'tema_unite': tema,
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': ciktilar.isNotEmpty
            ? ciktilar
            : ['$ad $haftaNo. Hafta Öğrenme Çıktısı'],
        'surec_bilesenleri': surec,
      },
      'ozel_alanlar': {
        'belirli_gun_ve_haftalar': otpHaftasi
            ? 'Kazanım Pekiştirme ve Zümre Çalışmaları'
            : (satir['specific_day_week']?.toString() ?? ''),
        'alan_becerileri': abKb,
        'kavramsal_beceriler': 'Kavramsal Çözümleme ve Bilgi Toplama',
        'sosyal_duygusal_ogrenme_becerileri': sdb,
        'okuryazarlik_becerileri': ob,
        'degerler': degerler,
        'disiplinler_arasi_iliskiler': 'Türkçe (anlama-ifade), Matematik '
            '(mantıksal akıl yürütme), Fen Bilimleri (bilimsel sorgulama)',
      },
    };

    if (!ayrintili) {
      plan['ogretim_sureci'] = {
        'etkinlikler': [
          'Dersin başında hazırbulunuşluk yoklaması ve kavramsal soru-cevap yürütülür.',
          'Etkileşimli tahta ve ders kitabı eşliğinde temel kavramlar açıklanır.',
          'Kazanım pekiştirme ve değerlendirme etkinlikleri tamamlanır.',
        ],
      };
      return plan;
    }

    // --- Günlük plan: öğretme-öğrenme süreci ---
    final resmiEtkinlik = (satir['official_activity'] ?? '').toString().trim();
    final maarifOzet = (satir['maarif_summary'] ?? '').toString().trim();

    var dikkatCekme = '';
    if (otpHaftasi) {
      dikkatCekme = 'Öğrencilere bu derste Zümre Öğretmenler Kurulunca '
          'belirlenen derinleştirme, araştırma ve kazanım pekiştirme '
          'etkinliklerinin yürütüleceği belirtilerek dikkatleri çekilir.';
    } else if (resmiEtkinlik.contains('?')) {
      final soru = RegExp(r'([^.!?\n]*\?)').firstMatch(resmiEtkinlik);
      dikkatCekme = soru
              ?.group(1)
              ?.replaceAll(RegExp(r'^[^“"]*[“"]'), '')
              .replaceAll(RegExp(r'[”"].*$'), '')
              .trim() ??
          '';
    }
    if (dikkatCekme.isEmpty || dikkatCekme.length < 5) {
      dikkatCekme = ad.toLowerCase().contains('bilişim')
          ? 'Bilişim teknolojileri deyince aklınıza neler geliyor?'
          : '$tema kavramı günlük yaşamımızda nerede ve nasıl karşımıza çıkar?';
    }

    final guduleme = otpHaftasi
        ? 'Önceki haftalarda öğrenilen bilgi ve becerileri gerçek yaşam '
            'senaryolarında, araştırma ve projelerde uygulama fırsatı '
            'bulacakları vurgulanır.'
        : 'Bu derste $tema konusuna ilişkin temel kavramları ve uygulama '
            'alanlarını açıklayabilecek duruma geleceksiniz.';

    final derseGecis = otpHaftasi
        ? 'Dersin başında hazırbulunuşluk ve önceki konuların kısa bir '
            'tekrarı yapıldıktan sonra zümre kararıyla belirlenen çalışma '
            'basamaklarına geçilir.'
        : 'Öğrencilerin dikkati çekildikten ve hazırbulunuşluk düzeyleri '
            'yoklandıktan sonra konunun işlenişine geçilir.';

    final adimlar = <String>[];
    if (otpHaftasi) {
      adimlar.addAll([
        'Dersin başında Zümre Öğretmenler Kurulu kararıyla belirlenen konu ve pekiştirme hedefleri öğrencilerle paylaşılır.',
        'Önceki ünitelerde öğrenilen temel kavramlar soru-cevap ve kavram yoklama yöntemleriyle gözden geçirilir.',
        'Öğrencilerin bireysel veya grup hâlinde yürütecekleri araştırma, proje ve inceleme görevleri dağıtılır.',
        'Etkileşimli tahta, çalışma yaprakları ve MEB dijital içerikleri eşliğinde pekiştirme çalışmaları tamamlanır.',
        'Çalışma sonunda elde edilen ürün veya kazanım çıktıları sınıf ortamında paylaşılarak akran geri bildirimi alınır.',
      ]);
    } else if (resmiEtkinlik.isNotEmpty) {
      adimlar.addAll(resmiEtkinlik
          .replaceAll(RegExp(r'FARKLILAŞTIRMA.*$', caseSensitive: false), '')
          .replaceAll(
              RegExp(r'ÖĞRETMEN YANSITMALARI.*$', caseSensitive: false), '')
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) =>
              s.length > 15 && !s.contains('http') && !s.contains('karekod'))
          .take(5));
    }
    if (!otpHaftasi && adimlar.isEmpty) {
      adimlar.addAll(etkinlikAdimlari(
        satir: satir,
        haftaNo: haftaNo,
        temaBasligi: tema,
        surecBilesenleri: surec,
      ));
    }

    var ozet = otpHaftasi
        ? 'MEB TYMM yönergesi kapsamında zümre kararıyla planlanan '
            'etkinliklerin tamamlanması, öğrencilerin öğrenme eksikliklerinin '
            'giderilmesi ve kavramsal pekiştirme sağlanması hedeflenir.'
        : maarifOzet;
    if (ozet.isNotEmpty && !otpHaftasi) {
      ozet += '\n\nÖğrencilerin bireysel farklılıkları göz ardı '
          'edilmemelidir. Öğrencilerin yeni kavramları önceki kavramların '
          'üzerine eklemeleri için fırsatlar verilmeli ve '
          'cesaretlendirilmelidir. Öğrenme-öğretme sürecinde öğrencilerin '
          'düşüncelerini sözlü olarak ifade etmelerine imkân tanınmalıdır.';
    }

    final farkRaw = (satir['differentiation'] ?? '').toString().trim();
    final String genelFark;
    if (otpHaftasi) {
      genelFark = 'MEB Maarif Modeli çerçevesinde; zümre kararıyla belirlenen '
          'okul temelli etkinliklerde öğrencilerin hazırbulunuşluk ve ilgi '
          'düzeylerine göre esnek çalışma grupları ve basamaklandırılmış '
          'görevler oluşturulur.';
    } else if (farkRaw.isNotEmpty) {
      genelFark = farkRaw;
    } else {
      genelFark = 'Öğrencilerin ilgi, ihtiyaç, hazırbulunuşluk düzeyleri ve '
          'öğrenme profillerine göre içerik, süreç ve ürün boyutlarında esnek '
          'öğretim uyarlamaları uygulanır.';
    }

    plan['ogretim_sureci'] = {
      'dikkat_cekme': dikkatCekme,
      'guduleme': guduleme,
      'derse_gecis': derseGecis,
      'etkinlikler': adimlar,
      'bireysel_etkinlikler':
          'Açık uçlu sorular, doğru-yanlış, boşluk doldurma, eşleştirme '
              'soruları, MEB ders kitabı çalışma yaprakları.',
      'grupla_etkinlikler':
          'İşbirlikli çalışma, beyin fırtınası, istasyon tekniği, akran '
              'öğrenmesi ve grup tartışmaları.',
      'ozet': ozet,
      'temel_kabuller': 'Öğrencilerin önceki sınıf ve konulara dair temel '
          'hazırbulunuşluk düzeyleri dikkate alınır.',
      'on_degerlendirme_sureci': 'Dersin başında hazırbulunuşluğu ölçmek üzere '
          'soru-cevap ve kavram yoklama tartışması yürütülür.',
      'kopru_kurma': 'Konu günlük hayat uygulamaları, güncel olaylar ve '
          'disiplinler arası bağlantılarla ilişkilendirilir.',
      'ogrenme_ogretme_uygulamalari': adimlar.join('\n'),
      'farklilastirma': {
        'genel_aciklama': genelFark,
        'zenginlestirme': 'İleri düzeydeki ve hızlı öğrenen öğrenciler için: '
            'Konuyu derinleştirici araştırma projeleri, üst düzey problem '
            'çözme senaryoları, dijital ürün geliştirme ve akran rehberliği '
            'görevleri planlanır.',
        'destekleme': 'Öğrenme sürecinde ek zamana ve desteğe ihtiyacı olan '
            'öğrenciler için: Görsel ve somut materyaller (şemalar, resimli '
            'kartlar), basamaklandırılmış çalışma yaprakları, yönlendirici '
            'ipuçları ve birebir rehberlikle tekrar uygulamaları yürütülür.',
      },
    };
    return plan;
  }

  /// 36. hafta: yıl sonu değerlendirme kartı.
  ///
  /// Kaynak planlar 35 ders haftası yazar; MEB mevzuatı 36. haftayı yıl
  /// sonu değerlendirme ve telafi haftası sayar. İki ekranda iki AYRI
  /// metin vardı ve günlük sürümdeki tarih `'14 - 18 Haziran 2027'` diye
  /// SABİTLENMİŞTİ — 2027-2028'de yanlış basacaktı. Tarih artık takvimden.
  static Map<String, dynamic> yilSonuHaftasi({
    required int haftaNo,
    required int sinif,
    required String dersKodu,
    required String dersAdi,
    required String Function(int) takvimdenTarih,
    bool ayrintili = false,
  }) {
    final plan = <String, dynamic>{
      'meta': {
        'ders': dersAdi,
        'sinif': '$sinif. Sınıf',
        'hafta': '$haftaNo. Hafta',
        'tarih_araligi': takvimdenTarih(haftaNo),
        'ders_saati': dersSaatiMetni(sinif, dersKodu),
        'tema_unite': 'Yıl Sonu Değerlendirme, Telafi ve Genel Tekrar',
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': [
          '$dersAdi dersinde yıl boyunca edinilen temel bilgi, beceri ve '
              'değerlerin genel değerlendirmesi ve pekiştirilmesi yapılır.',
        ],
        'surec_bilesenleri': [
          'a) Öğrencilerin yıl boyunca oluşturduğu çalışma yaprakları, projeler ve ürün dosyaları incelenir.',
          'b) Dönem sonu kazanım eksiklikleri tespit edilerek telafi ve kavram pekiştirme çalışmaları yürütülür.',
          'c) Yaz tatili sürecinde öğrenilenlerin korunması ve verimli tatil geçirme rehberliği paylaşılır.',
        ],
      },
      'ozel_alanlar': {
        'belirli_gun_ve_haftalar': 'Eğitim-Öğretim Yılı Kapanışı',
        'alan_becerileri':
            'Alan Becerileri, Kavramsal Çözümleme ve Değerlendirme',
        'kavramsal_beceriler':
            'Eleştirel Düşünme, Karşılaştırma ve Özetleme',
        'sosyal_duygusal_ogrenme_becerileri':
            'SDB1.1. Kendini Tanıma, SDB1.2. Kendini Düzenleme, SDB2.2. İş Birliği',
        'okuryazarlik_becerileri':
            'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık',
        'degerler': 'D3. Çalışkanlık, D16. Sorumluluk, D4. Dostluk',
        'disiplinler_arasi_iliskiler':
            'Türkçe, Matematik, Fen Bilimleri, Sosyal Bilgiler',
      },
    };

    if (!ayrintili) {
      plan['ogretim_sureci'] = const {};
      return plan;
    }

    plan['ogretim_sureci'] = {
      'dikkat_cekme': 'Öğrencilerle öğretim yılı boyunca yapılan en ilgi çekici etkinlikler ve kazanımlar üzerine sohbet başlatılır.',
      'guduleme': 'Yıl boyunca öğrenilen bilgilerin üst sınıflardaki derslere ve günlük hayata katkısı vurgulanır.',
      'derse_gecis': 'Öğrencilerin ürün dosyaları ve etkinlik raporları incelenmek üzere masalara yerleştirilir.',
      'etkinlikler': [
        'Öğretim yılı boyunca işlenen ana ünite ve kavramlar kavram haritaları eşliğinde özetlenir.',
        'Öğrencilerin hazırladığı proje, poster veya dijital çalışmalar sınıf sergisi şeklinde paylaşılır.',
        'Akran değerlendirmesi ve öz değerlendirme formları doldurularak öğrenme süreçleri yansıtılır.',
        'Kazanım eksikliği olan öğrenciler için soru-cevap ve ek alıştırmalarla telafi yapılır.',
        'Yaz tatili için tavsiye kitap listeleri ve eğitici etkinlik önerileri paylaşılarak ders sonlandırılır.',
      ],
      'bireysel_etkinlikler': 'Öz değerlendirme formu doldurma, çalışma portfolyosu düzenleme, eksik kazanım soru çözümleri.',
      'grupla_etkinlikler': 'Sınıf sergisi, akran geri bildirimi, grup değerlendirme çemberi ve bilgi yarışması.',
      'ozet': 'Öğrencilerin yıl boyunca kaydettikleri bireysel ve akademik gelişim takdir edilerek motive edilir.',
      'temel_kabuller': 'Öğretim yılı müfredatındaki temel kazanımların işlendiği kabul edilir.',
      'on_degerlendirme_sureci': 'Yıl sonu genel hatırlatma ve kavram tarama soruları yöneltilir.',
      'kopru_kurma': 'Öğrenilen bilgi ve becerilerin üst sınıflardaki derslerle bağlantısı kurulur.',
      'ogrenme_ogretme_uygulamalari': 'Sınıf sergisi, ürün dosyası incelemesi ve genel tekrar uygulamaları yürütülür.',
      'farklilastirma': {
        'genel_aciklama': 'Tüm öğrencilerin yıl sonu gelişim düzeyine uygun esnek değerlendirme ve telafi etkinlikleri sunulur.',
        'zenginlestirme': 'İleri düzeydeki öğrencilere tatil dönemi için ileri düzey araştırma ve proje fikirleri önerilir.',
        'destekleme': 'Temel kavramlarda eksikliği olan öğrenciler için özet kılavuzlar ve pekiştirici çalışma yaprakları verilir.',
      },
    };
    return plan;
  }

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

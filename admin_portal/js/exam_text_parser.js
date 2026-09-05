/**
 * MEB sınav duyurusundan tarih ayıklayıcı.
 *
 * ## Neden var
 * MEB sınav tarihlerini yapılandırılmış veri olarak yayımlamıyor —
 * duyuru metni ve PDF içinde geçiyor, biçim her yıl değişiyor. ÖSYM'de
 * yaptığımız gibi sayfayı otomatik okumak burada güvenilmez.
 *
 * Bu araç ortayı buluyor: yönetici duyuru metnini KOPYALAYIP
 * YAPIŞTIRIYOR, ayıklayıcı tarihleri çıkarıyor, o onaylıyor. Sıfırdan
 * elle girmek yok; yanlış ayrıştırmaya karşı da onay adımı var.
 *
 * `smart_circular_parser.js` ile aynı yaklaşım — o akademik takvim
 * (tatiller) için, bu sınavlar için.
 */
class ExamTextParser {
  static aylar = {
    ocak: '01', şubat: '02', mart: '03', nisan: '04',
    mayıs: '05', haziran: '06', temmuz: '07', ağustos: '08',
    eylül: '09', ekim: '10', kasım: '11', aralık: '12',
  };

  /**
   * Türkçe büyük/küçük harf tuzağı.
   *
   * `toLowerCase()` "İ" harfini "i̇" (noktalı i + birleşen nokta) yapıyor
   * ve arama tutmuyor. Harfler elle eşleniyor.
   */
  static kucult(metin) {
    if (!metin) return '';
    return metin
      .replace(/İ/g, 'i').replace(/I/g, 'ı')
      .replace(/Ğ/g, 'ğ').replace(/Ü/g, 'ü')
      .replace(/Ş/g, 'ş').replace(/Ö/g, 'ö')
      .replace(/Ç/g, 'ç')
      .toLowerCase();
  }

  /**
   * Tanınan sınavlar.
   *
   * Sıra ÖNEMLİ: "1. dönem 2. ortak yazılı" ile "1. dönem 1. ortak
   * yazılı" karışmasın diye özgül kalıplar önce denenir.
   */
  static kurallar = [
    {
      kaliplar: [/lgs/, /liselere geçiş/, /merkezi sınav/],
      baslik: 'LGS - Liselere Geçiş Sistemi Sınavı',
      kurum: 'MEB',
      url: 'https://e-okul.meb.gov.tr',
      aciklama: '8. sınıf merkezî sınavı.',
      kod: 'meb_lgs',
    },
    {
      kaliplar: [/iokbs/, /bursluluk/, /ilköğretim ve ortaöğretim.*burs/],
      baslik: 'İOKBS - Bursluluk Sınavı',
      kurum: 'MEB',
      url: 'https://odsgm.meb.gov.tr',
      aciklama: 'Devlet parasız yatılılık ve bursluluk sınavı.',
      kod: 'meb_iokbs',
    },
    {
      kaliplar: [/1\.?\s*dönem\s*1\.?\s*(ortak|yazılı)/, /birinci dönem birinci ortak/],
      baslik: '1. Dönem 1. Ortak Yazılı Sınavları',
      kurum: 'MEB',
      url: 'https://odsgm.meb.gov.tr',
      aciklama: 'Ülke geneli ortak yazılı sınavı.',
      kod: 'meb_ortak_1_1',
    },
    {
      kaliplar: [/1\.?\s*dönem\s*2\.?\s*(ortak|yazılı)/, /birinci dönem ikinci ortak/],
      baslik: '1. Dönem 2. Ortak Yazılı Sınavları',
      kurum: 'MEB',
      url: 'https://odsgm.meb.gov.tr',
      aciklama: 'Ülke geneli ortak yazılı sınavı.',
      kod: 'meb_ortak_1_2',
    },
    {
      kaliplar: [/2\.?\s*dönem\s*1\.?\s*(ortak|yazılı)/, /ikinci dönem birinci ortak/],
      baslik: '2. Dönem 1. Ortak Yazılı Sınavları',
      kurum: 'MEB',
      url: 'https://odsgm.meb.gov.tr',
      aciklama: 'Ülke geneli ortak yazılı sınavı.',
      kod: 'meb_ortak_2_1',
    },
    {
      kaliplar: [/2\.?\s*dönem\s*2\.?\s*(ortak|yazılı)/, /ikinci dönem ikinci ortak/],
      baslik: '2. Dönem 2. Ortak Yazılı Sınavları',
      kurum: 'MEB',
      url: 'https://odsgm.meb.gov.tr',
      aciklama: 'Ülke geneli ortak yazılı sınavı.',
      kod: 'meb_ortak_2_2',
    },
    {
      kaliplar: [/bilsem/, /bilim ve sanat merkez/],
      baslik: 'BİLSEM - Tanılama Sınavı',
      kurum: 'BİLSEM',
      url: 'https://orgm.meb.gov.tr',
      aciklama: 'Bilim ve sanat merkezi tanılama sınavı.',
      kod: 'meb_bilsem',
    },
    {
      kaliplar: [/açık (lise|öğretim|ortaokul)/, /aöl/, /aök/],
      baslik: 'Açık Öğretim Sınavı',
      kurum: 'e-Sınav',
      url: 'https://aol.meb.gov.tr',
      aciklama: 'Açık lise ve ortaokul dönem sınavı.',
      kod: 'meb_aol',
    },
  ];

  /**
   * Metinden tarih çıkarır.
   *
   * İki biçim tanınıyor:
   *   "14 Haziran 2026"  (yazıyla ay)
   *   "14.06.2026"       (noktalı)
   */
  static tarihBul(metin) {
    const kucuk = this.kucult(metin);

    // "14 Haziran 2026" veya "14-15 Haziran 2026"
    const yaziyla = /(\d{1,2})(?:\s*[-–]\s*\d{1,2})?\s+(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)\s+(\d{4})/.exec(kucuk);
    if (yaziyla) {
      const [, gun, ay, yil] = yaziyla;
      return `${yil}-${this.aylar[ay]}-${gun.padStart(2, '0')}`;
    }

    // "14.06.2026"
    const noktali = /(\d{1,2})\.(\d{1,2})\.(\d{4})/.exec(kucuk);
    if (noktali) {
      const [, gun, ay, yil] = noktali;
      return `${yil}-${ay.padStart(2, '0')}-${gun.padStart(2, '0')}`;
    }

    return null;
  }

  /** Metinde saat geçiyorsa onu, yoksa 09:00. */
  static saatBul(metin) {
    const m = /(?:saat\s*)?(\d{1,2})[.:](\d{2})/.exec(this.kucult(metin));
    if (!m) return '09:00';
    const saat = parseInt(m[1], 10);
    // "1. dönem 2. sınav" gibi ifadeler saat sanılmasın.
    if (saat > 23) return '09:00';
    return `${String(saat).padStart(2, '0')}:${m[2]}`;
  }

  /**
   * Duyuru metnini ayrıştırır.
   *
   * @returns {{sinavlar: Array, taninmayan: Array}}
   */
  static ayristir(hamMetin) {
    if (!hamMetin || !hamMetin.trim()) {
      return { sinavlar: [], taninmayan: [] };
    }

    // Satırlara böl.
    //
    // ## Nokta tuzağı
    // Türkçede sıra sayıları noktayla yazılıyor: "1. Dönem 2. Ortak
    // Yazılı". Her noktadan bölünce "1. Dönem 1." kısmı kopuyor ve
    // hangi sınav olduğu anlaşılmıyordu — ortak yazılıların hiçbiri
    // tanınmıyordu.
    //
    // Çözüm: yalnızca SATIR SONLARINDAN böl. Bir satırda birden çok
    // sınav olması nadir; olursa ikincisi "tanınmayan" listesine düşer
    // ve yönetici görür.
    const parcalar = hamMetin
      .replace(/\r\n/g, '\n')
      .split(/\n+/)
      .map((x) => x.trim())
      .filter((x) => x.length > 8);

    const bulunanlar = new Map();
    const taninmayan = [];

    for (const parca of parcalar) {
      const kucuk = this.kucult(parca);
      const tarih = this.tarihBul(parca);
      if (!tarih) continue;

      let eslesti = false;
      for (const kural of this.kurallar) {
        if (!kural.kaliplar.some((k) => k.test(kucuk))) continue;

        eslesti = true;
        // Aynı sınav birden çok satırda geçebiliyor; ilki tutulur.
        if (bulunanlar.has(kural.kod)) break;

        const saat = this.saatBul(parca);
        const yil = tarih.slice(0, 4);

        bulunanlar.set(kural.kod, {
          doc_id: `${kural.kod}_${tarih.replace(/-/g, '')}`,
          title: kural.baslik,
          institution: kural.kurum,
          examDate: `${tarih}T${saat}:00.000`,
          applicationDeadline: null,
          applicationUrl: kural.url,
          description: kural.aciklama,
          category: kural.kurum,
          kaynakSatir: parca.slice(0, 120),
          yil,
        });
        break;
      }

      // Tarihi var ama hangi sınav olduğu anlaşılmadı: yöneticiye
      // gösteriliyor, sessizce atılmıyor.
      if (!eslesti && /sınav|yazılı|değerlendirme/.test(kucuk)) {
        taninmayan.push({ satir: parca.slice(0, 120), tarih });
      }
    }

    return {
      sinavlar: [...bulunanlar.values()],
      taninmayan,
    };
  }
}

window.ExamTextParser = ExamTextParser;

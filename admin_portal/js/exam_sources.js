/**
 * Sınav takvimi kaynakları.
 *
 * ## Neden bu dosya var
 * Sınav tarihleri elle giriliyor ve yönetici her seferinde "bu sınavın
 * tarihi nerede yayımlanıyordu?" diye aramak zorunda kalıyordu. Kaynak
 * adresleri burada duruyor; panel her kurumun yanına bağlantı basıyor.
 *
 * ÖSYM sınavları ayrıca OTOMATİK çekiliyor (`fetchOsymTakvim`), ama
 * kaynak yine de gösteriliyor: yönetici çekilen veriyi doğrulamak
 * isteyebilir.
 */
window.SinavKaynaklari = {
  /**
   * Kurum başına takvim kaynağı.
   *
   * `otomatik: true` olanlar panelden çekilebiliyor; diğerleri elle
   * girilir ve bağlantı yalnızca yol gösterir.
   */
  kurumlar: {
    ÖSYM: {
      ad: 'ÖSYM Sınav Takvimi',
      url: 'https://www.osym.gov.tr/Sayfa/SinavTakvimi',
      aciklama:
        'YKS, ALES, YDS, MSÜ, EKYS, AGS. Yıllık takvim genelde Aralık ' +
        'ayında yayımlanır.',
      otomatik: true,
      nezaman: 'Aralık',
    },
    AGS: {
      ad: 'ÖSYM Sınav Takvimi',
      url: 'https://www.osym.gov.tr/Sayfa/SinavTakvimi',
      aciklama: 'MEB Akademi Giriş Sınavı — ÖSYM takviminde yer alır.',
      otomatik: true,
      nezaman: 'Aralık',
    },
    EKYS: {
      ad: 'ÖSYM Sınav Takvimi',
      url: 'https://www.osym.gov.tr/Sayfa/SinavTakvimi',
      aciklama: 'Yönetici Seçme Sınavı — ÖSYM takviminde yer alır.',
      otomatik: true,
      nezaman: 'Aralık',
    },
    MSÜ: {
      ad: 'ÖSYM Sınav Takvimi',
      url: 'https://www.osym.gov.tr/Sayfa/SinavTakvimi',
      aciklama: 'Askerî öğrenci aday belirleme — ÖSYM takviminde.',
      otomatik: true,
      nezaman: 'Aralık',
    },
    MEB: {
      ad: 'MEB Ölçme ve Değerlendirme (ODSGM)',
      url: 'https://odsgm.meb.gov.tr/www/duyurular/kategori/1',
      aciklama:
        'Ortak yazılılar, LGS, bursluluk (İOKBS). Çalışma takvimi ' +
        'genelde Ağustos ayında duyurulur.',
      otomatik: false,
      nezaman: 'Ağustos',
      ekKaynaklar: [
        { ad: 'MEB Duyurular', url: 'https://www.meb.gov.tr/duyurular/' },
        { ad: 'e-Okul', url: 'https://e-okul.meb.gov.tr' },
      ],
    },
    BİLSEM: {
      ad: 'MEB Özel Eğitim (ORGM)',
      url: 'https://orgm.meb.gov.tr/www/duyurular/kategori/1',
      aciklama:
        'Bireysel değerlendirme ve tarama takvimi. Başvurular genelde ' +
        'Şubat–Mart döneminde açılır.',
      otomatik: false,
      nezaman: 'Şubat',
    },
    MTSK: {
      ad: 'MEB e-Sınav Takvimi',
      url: 'https://esinav.meb.gov.tr',
      aciklama:
        'Ehliyet teori sınavları. Sürekli sınav; oturumlar dönemsel ' +
        'olarak açıklanır.',
      otomatik: false,
      nezaman: 'Dönemsel',
      ekKaynaklar: [{ ad: 'MEBBİS', url: 'https://mebbis.meb.gov.tr' }],
    },
    'e-Sınav': {
      ad: 'MEB e-Sınav / Açık Öğretim',
      url: 'https://aol.meb.gov.tr',
      aciklama:
        'Açık lise/ortaokul ve MESEM sınavları. Dönem başlarında ' +
        'duyurulur.',
      otomatik: false,
      nezaman: 'Dönemsel',
      ekKaynaklar: [
        { ad: 'MESEM', url: 'https://mesem.meb.gov.tr' },
        { ad: 'e-Sınav', url: 'https://esinav.meb.gov.tr' },
      ],
    },
    AÖF: {
      ad: 'Anadolu Üniversitesi AÖF',
      url: 'https://www.anadolu.edu.tr/acikogretim/duyurular',
      aciklama: 'Ara sınav ve dönem sonu takvimi; gözetmenlik görevleri.',
      otomatik: false,
      nezaman: 'Dönemsel',
    },
  },

  /** Bir kurumun kaynağını döndürür; tanımsızsa null. */
  bul(kurum) {
    return this.kurumlar[kurum] || null;
  },

  /** Otomatik çekilebilen kurumlar. */
  otomatikOlanlar() {
    return Object.entries(this.kurumlar)
      .filter(([, k]) => k.otomatik)
      .map(([ad]) => ad);
  },
};

/**
 * SınıfCepte Web Admin Paneli - MEB Eğitim Yılı Takvim Sihirbazı (Standart Şablon Motoru)
 */
class CalendarWizard {
  /**
   * Yıl bazlı Ramazan ve Kurban Bayramı yaklaşık tarihleri
   */
  static getReligiousHolidays(year) {
    const holidays = {
      2025: {
        ramazan: { start: '2025-03-30', end: '2025-04-01' },
        kurban: { start: '2025-06-06', end: '2025-06-09' },
      },
      2026: {
        ramazan: { start: '2026-03-20', end: '2026-03-22' },
        kurban: { start: '2026-05-27', end: '2026-05-30' },
      },
      2027: {
        ramazan: { start: '2027-03-10', end: '2027-03-12' },
        kurban: { start: '2027-05-17', end: '2027-05-20' },
      },
      2028: {
        ramazan: { start: '2028-02-27', end: '2028-02-29' },
        kurban: { start: '2028-05-05', end: '2028-05-08' },
      },
    };

    return holidays[year] || {
      ramazan: { start: `${year}-03-15`, end: `${year}-03-17` },
      kurban: { start: `${year}-05-20`, end: `${year}-05-23` },
    };
  }

  /**
   * Seçilen 1. Dönem açılış tarihine göre eksiksiz ve standart MEB takvim olayları listesini üretir
   */
  static generateFullCalendar(startDateStr, academicYear = '2026-2027') {
    const startDate = new Date(startDateStr);
    const baseYear = startDate.getFullYear();
    const nextYear = parseInt(academicYear.split('-')[1]) || (baseYear + 1);

    const formatDate = (d) => {
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    };

    const addDays = (d, days) => {
      const res = new Date(d);
      res.setDate(res.getDate() + days);
      return res;
    };

    // 1. Dönem Başlangıcı
    const donem1Start = new Date(startDate);

    // Hafta numarasından o haftanın pazartesisini verir.
    // N. hafta, başlangıçtan (N-1) hafta sonradır; eskiden N ile çarpılıyordu
    // ve bu yüzden tüm tatiller bir hafta ileri kayıyordu.
    const weekMonday = (weekNo) => addDays(donem1Start, (weekNo - 1) * 7);

    // MEB standart yapısı (39 takvim haftası):
    //   10. hafta        -> 1. Dönem Ara Tatili
    //   19-20. hafta     -> Yarıyıl (sömestr) tatili, 2 hafta
    //   21. hafta        -> 2. Dönem başlangıcı
    //   28. hafta        -> 2. Dönem Ara Tatili
    //   39. hafta Cuma   -> Kapanış / karne
    const araTatil1Start = weekMonday(10);
    const araTatil1End = addDays(araTatil1Start, 4); // Cuma

    const somestrStart = weekMonday(19);
    const somestrEnd = addDays(somestrStart, 11); // 2. haftanın Cuma'sı

    const donem2Start = weekMonday(21);

    const araTatil2Start = weekMonday(28);
    const araTatil2End = addDays(araTatil2Start, 4);

    // Kapanış: 39. haftanın Cuma günü
    const kapanisDate = addDays(weekMonday(39), 4);

    // Dini Bayramlar
    const religious = this.getReligiousHolidays(nextYear);

    const events = [
      // 1. MEB ANA DÖNÜM NOKTALARI
      {
        id: `wiz_${academicYear}_donem1_baslangic`,
        title: '1. Dönem Ders Başlangıcı',
        description: `${academicYear} Eğitim Öğretim Yılı 1. Dönem Açılışı`,
        startDate: formatDate(donem1Start),
        endDate: formatDate(donem1Start),
        category: 'period',
        academicYear: academicYear,
        isOfficialHoliday: false,
      },
      {
        id: `wiz_${academicYear}_ara_tatil_1`,
        title: '1. Dönem Ara Tatili',
        description: 'Kasım Ara Tatil Haftası (Öğrenci Dinlenme / Öğretmen Semineri)',
        startDate: formatDate(araTatil1Start),
        endDate: formatDate(araTatil1End),
        category: 'breakHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_somestr`,
        title: 'Yarıyıl (Sömestr) Tatili',
        description: '1. Dönem Sonu Karneler ve 2 Haftalık Yarıyıl Dinlenme Tatili',
        startDate: formatDate(somestrStart),
        endDate: formatDate(somestrEnd),
        category: 'breakHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_donem2_baslangic`,
        title: '2. Dönem Ders Başlangıcı',
        description: `${academicYear} Eğitim Öğretim Yılı 2. Dönem Açılışı`,
        startDate: formatDate(donem2Start),
        endDate: formatDate(donem2Start),
        category: 'period',
        academicYear: academicYear,
        isOfficialHoliday: false,
      },
      {
        id: `wiz_${academicYear}_ara_tatil_2`,
        title: '2. Dönem Ara Tatili',
        description: 'Nisan Ara Tatil Haftası',
        startDate: formatDate(araTatil2Start),
        endDate: formatDate(araTatil2End),
        category: 'breakHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_donem2_kapanis`,
        title: 'Eğitim Öğretim Yılı Sonu (Bitiş Tarihi / Karne)',
        description: `${academicYear} Eğitim Öğretim Yılı Kapanışı ve Karnelerin Dağıtımı`,
        startDate: formatDate(kapanisDate),
        endDate: formatDate(kapanisDate),
        category: 'period',
        academicYear: academicYear,
        isOfficialHoliday: false,
      },

      // 2. SABİT RESMÎ TATİLLER
      {
        id: `wiz_${academicYear}_29ekim`,
        title: '29 Ekim Cumhuriyet Bayramı',
        description: 'Cumhuriyetimizin Kuruluş Yıldönümü Resmî Tatili',
        startDate: `${baseYear}-10-29`,
        endDate: `${baseYear}-10-29`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_yilbasi`,
        title: '1 Ocak Yılbaşı Tatili',
        description: '1 Ocak Resmî Tatil',
        startDate: `${nextYear}-01-01`,
        endDate: `${nextYear}-01-01`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_23nisan`,
        title: '23 Nisan Ulusal Egemenlik ve Çocuk Bayramı',
        description: 'Resmî Bayram ve Tatil',
        startDate: `${nextYear}-04-23`,
        endDate: `${nextYear}-04-23`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_1mayis`,
        title: '1 Mayıs Emek ve Dayanışma Günü',
        description: 'Resmî Tatil',
        startDate: `${nextYear}-05-01`,
        endDate: `${nextYear}-05-01`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_19mayis`,
        title: "19 Mayıs Atatürk'ü Anma, Gençlik ve Spor Bayramı",
        description: 'Resmî Bayram ve Tatil',
        startDate: `${nextYear}-05-19`,
        endDate: `${nextYear}-05-19`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_15temmuz`,
        title: '15 Temmuz Demokrasi ve Millî Birlik Günü',
        description: 'Resmî Tatil',
        startDate: `${nextYear}-07-15`,
        endDate: `${nextYear}-07-15`,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },

      // 3. DİNİ BAYRAMLAR
      {
        id: `wiz_${academicYear}_ramazan_bayrami`,
        title: 'Ramazan Bayramı Tatili',
        description: 'Ramazan Bayramı Resmî Tatil Günleri',
        startDate: religious.ramazan.start,
        endDate: religious.ramazan.end,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
      {
        id: `wiz_${academicYear}_kurban_bayrami`,
        title: 'Kurban Bayramı Tatili',
        description: 'Kurban Bayramı Resmî Tatil Günleri',
        startDate: religious.kurban.start,
        endDate: religious.kurban.end,
        category: 'officialHoliday',
        academicYear: academicYear,
        isOfficialHoliday: true,
      },
    ];

    return events.sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
  }
}

window.CalendarWizard = CalendarWizard;

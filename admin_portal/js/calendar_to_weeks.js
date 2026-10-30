/**
 * SınıfCepte Admin Paneli - Takvim → Hafta Yapısı Köprüsü
 *
 * Panelde MEB takvimi ile kazanım kartları BİRBİRİNDEN BAĞIMSIZ iki sistemdi:
 * takvim sayfasında ara tatili değiştirmek kartlardaki tatil haftalarını
 * etkilemiyordu. Bu modül takvim olaylarını tek doğruluk kaynağı yapar ve
 * kartların ihtiyaç duyduğu haftalık yapıyı türetir. Hafta sayısı takvimdeki
 * yıl sonu (karne) olayından gelir; olay yoksa DEFAULT_WEEKS.
 *
 * Üretilen yapı, Python tarafındaki scripts/maarif/academic_calendar.py
 * çıktısıyla aynı biçimdedir; ikisi de overrides JSON'una çevrilebilir.
 */
class CalendarToWeeks {
  // 30 Ekim 2026'ya kadar sabit 39 idi; hiçbir yıla uymuyordu (2026-2027:
  // 14 Eylül - 25 Haziran = 41 hafta). Python tarafı: academic_calendar.py.
  static DEFAULT_WEEKS = 41;

  static MONTHS = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  /** 'YYYY-MM-DD' -> yerel saat diliminde Date (UTC kayması olmadan). */
  static parseDate(value) {
    if (value instanceof Date) return new Date(value.getFullYear(), value.getMonth(), value.getDate());
    const [year, month, day] = String(value).split('-').map(Number);
    return new Date(year, month - 1, day);
  }

  static formatDate(date) {
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }

  static addDays(date, days) {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  /** O tarihi içeren haftanın pazartesisi. */
  static mondayOf(date) {
    const result = new Date(date);
    // getDay(): 0=Pazar ... 6=Cumartesi. Pazar'ı önceki haftaya bağla.
    const offset = (result.getDay() + 6) % 7;
    return this.addDays(result, -offset);
  }

  static formatRange(start, end) {
    const startMonth = this.MONTHS[start.getMonth()];
    const endMonth = this.MONTHS[end.getMonth()];
    if (start.getFullYear() !== end.getFullYear()) {
      return `${start.getDate()} ${startMonth} ${start.getFullYear()} - ${end.getDate()} ${endMonth} ${end.getFullYear()}`;
    }
    if (start.getMonth() !== end.getMonth()) {
      return `${start.getDate()} ${startMonth} - ${end.getDate()} ${endMonth} ${end.getFullYear()}`;
    }
    return `${start.getDate()} - ${end.getDate()} ${startMonth} ${start.getFullYear()}`;
  }

  /**
   * Takvim olaylarından haftalık yapıyı üretir.
   *
   * @param {Array} events  CalendarManager.getEvents() çıktısı
   * @returns {{weeks: Array, startDate: string, warnings: string[]}}
   */
  static buildWeeks(events) {
    const warnings = [];
    const list = Array.isArray(events) ? events : [];

    // 1) Eğitim öğretim yılının başlangıcı: "1. Dönem Ders Başlangıcı"
    const opening = list.find(
      (e) => e.category === 'period' && /1\.\s*dönem/i.test(e.title || '')
    );
    if (!opening) {
      return {
        weeks: [],
        startDate: null,
        warnings: ['Takvimde "1. Dönem Ders Başlangıcı" olayı yok; hafta yapısı üretilemedi.'],
      };
    }

    const rawStart = this.parseDate(opening.startDate);
    const startMonday = this.mondayOf(rawStart);
    if (rawStart.getDay() !== 1) {
      warnings.push(
        `Okul açılışı (${opening.startDate}) pazartesi değil; hafta başlangıcı ${this.formatDate(startMonday)} kabul edildi.`
      );
    }

    // 2) Eğitime ara verilen aralıklar: ara tatil ve sömestr
    const breaks = list.filter((e) => e.category === 'breakHoliday');

    // 3) Yılın uzunluğu: yıl sonu (karne) olayının haftası.
    const closing = list.find(
      (e) => e.category === 'period' && /(yılı sonu|kapanış|karne)/i.test(e.title || '')
    );
    let totalWeeks = this.DEFAULT_WEEKS;
    let endDate = null;
    if (closing) {
      const closingMonday = this.mondayOf(this.parseDate(closing.startDate));
      totalWeeks = Math.round((closingMonday - startMonday) / (7 * 864e5)) + 1;
      endDate = this.formatDate(this.addDays(closingMonday, 4));
    } else {
      warnings.push(
        `Takvimde yıl sonu (karne) olayı yok; ${this.DEFAULT_WEEKS} hafta varsayıldı.`
      );
    }

    // 4) Haftaları kur; her haftayı tatil aralıklarıyla karşılaştır
    const weeks = [];
    let teachingWeek = 0;

    for (let weekNo = 1; weekNo <= totalWeeks; weekNo += 1) {
      const start = this.addDays(startMonday, (weekNo - 1) * 7);
      const end = this.addDays(start, 4); // Pazartesi - Cuma

      // Haftanın ders günleri tatil aralığıyla örtüşüyor mu?
      const covering = breaks.find((brk) => {
        const brkStart = this.parseDate(brk.startDate);
        const brkEnd = this.parseDate(brk.endDate || brk.startDate);
        return brkStart <= end && brkEnd >= start;
      });

      const isHoliday = Boolean(covering);
      if (isHoliday) {
        teachingWeek = teachingWeek; // tatil haftası ders sırasını ilerletmez
      } else {
        teachingWeek += 1;
      }

      weeks.push({
        weekNumber: weekNo,
        startDate: this.formatDate(start),
        endDate: this.formatDate(end),
        formatted: this.formatRange(start, end) + (isHoliday ? ` (${covering.title})` : ''),
        isHolidayWeek: isHoliday,
        holidayNote: isHoliday ? covering.title : null,
        teachingWeekNumber: isHoliday ? null : teachingWeek,
      });
    }

    // 5) Karne cuma değilse uyar (Python endDate'i cuma ister).
    if (closing && this.parseDate(closing.startDate).getDay() !== 5) {
      warnings.push(
        `Yıl sonu (${closing.startDate}) cuma değil; o haftanın cuması (${endDate}) kabul edildi.`
      );
    }

    const holidayCount = weeks.filter((w) => w.isHolidayWeek).length;
    if (holidayCount === 0) {
      warnings.push('Takvimde hiçbir ara tatil/sömestr haftası bulunamadı.');
    }

    return { weeks, startDate: this.formatDate(startMonday), endDate, warnings };
  }

  /**
   * Hafta yapısını Python boru hattının okuduğu overrides biçimine çevirir.
   * Bu JSON `scripts/maarif/overrides/<yıl>.json` olarak kaydedilir.
   */
  static toOverrideJson(events, academicYear, options = {}) {
    const { weeks, startDate, endDate, warnings } = this.buildWeeks(events);
    if (!weeks.length) return { override: null, warnings };

    const holidayWeeks = {};
    weeks.forEach((week) => {
      if (week.isHolidayWeek) holidayWeeks[week.weekNumber] = week.holidayNote;
    });

    // 2. dönemin başladığı hafta: sömestr sonrası ilk ders haftası.
    const list = Array.isArray(events) ? events : [];
    const term2 = list.find(
      (e) => e.category === 'period' && /2\.\s*dönem/i.test(e.title || '')
    );
    let secondTermStartWeek = 21;
    if (term2) {
      const term2Monday = this.mondayOf(this.parseDate(term2.startDate));
      const match = weeks.find((w) => w.startDate === this.formatDate(term2Monday));
      if (match) secondTermStartWeek = match.weekNumber;
    }

    return {
      override: {
        _comment:
          `${academicYear} - SınıfCepte admin panelindeki MEB takviminden üretildi. ` +
          'scripts/maarif/overrides/ altına kaydedin.',
        startDate,
        ...(endDate ? { endDate } : {}),
        secondTermStartWeek,
        holidayWeeks,
        otpWeeks: options.otpWeeks || [],
        socialEventWeeks: options.socialEventWeeks || [],
      },
      warnings,
    };
  }
}

window.CalendarToWeeks = CalendarToWeeks;

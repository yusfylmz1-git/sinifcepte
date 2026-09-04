/**
 * SınıfCepte Admin Paneli - Takvim testleri
 *
 *   node admin_portal/js/test_calendar.js
 *
 * Tarayıcı gerektirmez; dosyalar window üzerinden yüklenir.
 */

const assert = require('assert');
const path = require('path');

global.window = {};
require(path.join(__dirname, 'calendar_wizard.js'));
require(path.join(__dirname, 'calendar_to_weeks.js'));

const { CalendarWizard, CalendarToWeeks } = global.window;

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ok   ${name}`);
    passed += 1;
  } catch (error) {
    console.log(`  FAIL ${name}\n       ${error.message}`);
    failed += 1;
  }
}

/** Bir tarihin, okul açılışına göre kaçıncı takvim haftasına düştüğü. */
function weekOf(dateStr, startStr) {
  const diff = CalendarToWeeks.parseDate(dateStr) - CalendarToWeeks.parseDate(startStr);
  return Math.floor(diff / (7 * 864e5)) + 1;
}

console.log('\nCalendarWizard - MEB standart yapısı');

test('1. Dönem Ara Tatili 10. haftaya denk gelir', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const item = events.find((e) => e.title.includes('1. Dönem Ara'));
  assert.strictEqual(weekOf(item.startDate, '2026-09-14'), 10);
  assert.strictEqual(item.startDate, '2026-11-16');
});

test('Yarıyıl tatili 19. haftada başlar ve iki hafta sürer', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const item = events.find((e) => e.title.includes('Yarıyıl'));
  assert.strictEqual(weekOf(item.startDate, '2026-09-14'), 19);
  assert.strictEqual(item.startDate, '2027-01-18');
  assert.strictEqual(item.endDate, '2027-01-29');
});

test('2. Dönem 21. haftada başlar', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const item = events.find((e) => e.title.includes('2. Dönem Ders'));
  assert.strictEqual(weekOf(item.startDate, '2026-09-14'), 21);
  assert.strictEqual(item.startDate, '2027-02-01');
});

test('2. Dönem Ara Tatili 28. haftaya denk gelir', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const item = events.find((e) => e.title.includes('2. Dönem Ara'));
  assert.strictEqual(weekOf(item.startDate, '2026-09-14'), 28);
  assert.strictEqual(item.startDate, '2027-03-22');
});

test('Yıl sonu 39. haftanın cuması olur', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const item = events.find((e) => e.title.includes('Yılı Sonu'));
  assert.strictEqual(weekOf(item.startDate, '2026-09-14'), 39);
  assert.strictEqual(item.startDate, '2027-06-11');
});

test('Tüm dönüm noktaları pazartesi başlar (yıl sonu hariç)', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  ['1. Dönem Ara', 'Yarıyıl', '2. Dönem Ders', '2. Dönem Ara'].forEach((title) => {
    const item = events.find((e) => e.title.includes(title));
    const day = CalendarToWeeks.parseDate(item.startDate).getDay();
    assert.strictEqual(day, 1, `${title} pazartesi değil`);
  });
});

console.log('\nCalendarToWeeks - takvimden hafta yapısı');

test('Standart takvimden 10, 19, 20, 28 tatil haftaları çıkar', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { weeks } = CalendarToWeeks.buildWeeks(events);
  const holidays = weeks.filter((w) => w.isHolidayWeek).map((w) => w.weekNumber);
  assert.deepStrictEqual(holidays, [10, 19, 20, 28]);
});

test('39 takvim haftası, 35 ders haftası üretilir', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { weeks } = CalendarToWeeks.buildWeeks(events);
  assert.strictEqual(weeks.length, 39);
  const teaching = weeks.filter((w) => w.teachingWeekNumber !== null);
  assert.strictEqual(teaching.length, 35);
  assert.strictEqual(Math.max(...teaching.map((w) => w.teachingWeekNumber)), 35);
});

test('Tatil haftaları ders sırasını ilerletmez', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { weeks } = CalendarToWeeks.buildWeeks(events);
  weeks.forEach((week) => {
    if (week.isHolidayWeek) assert.strictEqual(week.teachingWeekNumber, null);
  });
  // 9. hafta ders 9; 10. hafta tatil; 11. hafta ders 10 olmalı
  assert.strictEqual(weeks[8].teachingWeekNumber, 9);
  assert.strictEqual(weeks[9].teachingWeekNumber, null);
  assert.strictEqual(weeks[10].teachingWeekNumber, 10);
});

test('Her hafta pazartesi başlar ve cuma biter', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { weeks } = CalendarToWeeks.buildWeeks(events);
  weeks.forEach((week) => {
    assert.strictEqual(CalendarToWeeks.parseDate(week.startDate).getDay(), 1);
    assert.strictEqual(CalendarToWeeks.parseDate(week.endDate).getDay(), 5);
  });
});

test('Takvimde tatil taşınınca hafta yapısı da taşınır', () => {
  let events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  events = events.map((e) =>
    e.title.includes('1. Dönem Ara')
      ? { ...e, startDate: '2026-11-30', endDate: '2026-12-04' }
      : e
  );
  const { weeks } = CalendarToWeeks.buildWeeks(events);
  const holidays = weeks.filter((w) => w.isHolidayWeek).map((w) => w.weekNumber);
  assert.deepStrictEqual(holidays, [12, 19, 20, 28]);
});

test('Açılış pazartesi değilse uyarır ama üretmeye devam eder', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-16', '2026-2027');
  const { weeks, warnings } = CalendarToWeeks.buildWeeks(events);
  assert.strictEqual(weeks.length, 39);
  assert.ok(warnings.some((w) => w.includes('pazartesi değil')));
});

test('Açılış olayı yoksa boş döner ve sebebini söyler', () => {
  const { weeks, warnings } = CalendarToWeeks.buildWeeks([]);
  assert.strictEqual(weeks.length, 0);
  assert.ok(warnings[0].includes('1. Dönem Ders Başlangıcı'));
});

console.log('\nCalendarToWeeks - overrides JSON üretimi');

test('Python boru hattının beklediği alanları üretir', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { override } = CalendarToWeeks.toOverrideJson(events, '2026-2027', {
    otpWeeks: [8, 17, 29],
    socialEventWeeks: [18, 37],
  });
  assert.strictEqual(override.startDate, '2026-09-14');
  assert.strictEqual(override.secondTermStartWeek, 21);
  assert.deepStrictEqual(Object.keys(override.holidayWeeks).map(Number), [10, 19, 20, 28]);
  assert.deepStrictEqual(override.otpWeeks, [8, 17, 29]);
});

test('Tarih biçimi ISO (YYYY-MM-DD) kalır', () => {
  const events = CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027');
  const { override } = CalendarToWeeks.toOverrideJson(events, '2026-2027');
  assert.match(override.startDate, /^\d{4}-\d{2}-\d{2}$/);
});

console.log('\nTarih biçimlendirme');

test('Ay ve yıl geçişleri doğru yazılır', () => {
  const f = (a, b) => CalendarToWeeks.formatRange(
    CalendarToWeeks.parseDate(a), CalendarToWeeks.parseDate(b));
  assert.strictEqual(f('2026-09-14', '2026-09-18'), '14 - 18 Eylül 2026');
  assert.strictEqual(f('2026-09-28', '2026-10-02'), '28 Eylül - 2 Ekim 2026');
  assert.strictEqual(f('2026-12-28', '2027-01-01'), '28 Aralık 2026 - 1 Ocak 2027');
});

console.log(`\n${passed} basarili, ${failed} basarisiz\n`);
process.exit(failed === 0 ? 0 : 1);

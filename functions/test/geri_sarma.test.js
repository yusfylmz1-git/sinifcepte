/**
 * Remote Config sürüm geri sarma koruması.
 *
 * ## Neden kritik
 *
 * Panel yayın sırasında yerel manifestin TAMAMINI gönderiyor. Yeni bir
 * tarayıcıda localStorage boşsa varsayılanlar gidiyor
 * (`exams_version: 1`). Sunucu karşılaştırma yapmadan üzerine
 * yazıyordu.
 *
 * Senaryo: A yönetici v10 yayınlar. B başka bir tarayıcıdan "sınav
 * yayınla" der ve canlı sürüm 10'dan 1'e düşer. Cihazlar
 * `uzakSurum <= yerelSurum` ile yeni sınavı YOK SAYAR; öğretmenler
 * eski sınav tarihiyle kalır ve veliye yanlış başvuru tarihi söyler.
 *
 * Bağımsız incelemede bildirildi (19 Eylül 2026'da doğrulandı).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { geriSarmaKontrol, SURUM_ALANLARI } from '../validate.js';

/** Remote Config şablonunu taklit eder. */
function sablon(degerler) {
  const p = {};
  for (const [k, v] of Object.entries(degerler)) {
    p[k] = { defaultValue: { value: String(v) } };
  }
  return p;
}

test('KRİTİK: sürüm düşüşü reddedilir', () => {
  const sonuc = geriSarmaKontrol(
    { exams_version: '1' },
    sablon({ exams_version: 10 }),
  );

  assert.equal(sonuc.ok, false);
  assert.equal(sonuc.kod, 'failed-precondition');
  // Mesaj SEBEBİ ve ÇÖZÜMÜ söylemeli: "reddedildi" demek yöneticiyi
  // yeniden denemeye iter ve aynı hata tekrarlanır.
  assert.match(sonuc.mesaj, /10 -> 1/);
  assert.match(sonuc.mesaj, /Canlıdan Çek/);
});

test('KRİTİK: yeni tarayıcı senaryosu — varsayılan 1 gönderiliyor', () => {
  // localStorage boş: panel tüm varsayılanları gönderiyor.
  const sonuc = geriSarmaKontrol(
    {
      exams_version: '1',
      calendar_version: '1',
      outcomes_version: '1',
    },
    sablon({ exams_version: 42, calendar_version: 17, outcomes_version: 8 }),
  );

  assert.equal(sonuc.ok, false);
  // ÜÇÜ de bildirilmeli; yalnızca ilkini söylemek eksik teşhis olurdu.
  assert.match(sonuc.mesaj, /exams_version/);
  assert.match(sonuc.mesaj, /calendar_version/);
  assert.match(sonuc.mesaj, /outcomes_version/);
});

test('sürüm artışı geçer', () => {
  const sonuc = geriSarmaKontrol(
    { exams_version: '11' },
    sablon({ exams_version: 10 }),
  );
  assert.equal(sonuc.ok, true);
});

test('AYNI sürüm geçer — yeniden yayın meşru', () => {
  // Aynı içeriği tekrar yayınlamak normal bir iş; yalnızca DÜŞÜŞ
  // engelleniyor.
  const sonuc = geriSarmaKontrol(
    { exams_version: '10' },
    sablon({ exams_version: 10 }),
  );
  assert.equal(sonuc.ok, true);
});

test('ilk yayın geçer (şablonda alan yok)', () => {
  const sonuc = geriSarmaKontrol({ exams_version: '1' }, {});
  assert.equal(sonuc.ok, true);
});

test('gönderilmeyen alan denetlenmez', () => {
  // Panel yalnızca takvim yayınlıyorsa sınav sürümüne dokunulmamalı.
  const sonuc = geriSarmaKontrol(
    { calendar_version: '5' },
    sablon({ exams_version: 99, calendar_version: 4 }),
  );
  assert.equal(sonuc.ok, true);
});

test('sürüm DIŞI alanlar denetlenmez', () => {
  // `maintenance_mode` ve `min_app_version` ayrı bir sorun (K8'in
  // ikinci yarısı) ve sayısal sürüm mantığına girmiyor.
  const sonuc = geriSarmaKontrol(
    { maintenance_mode: 'false', exams_payload: '[]' },
    sablon({ exams_version: 10 }),
  );
  assert.equal(sonuc.ok, true);
});

test('sayıya çevrilemeyen değer çökmüyor', () => {
  const sonuc = geriSarmaKontrol(
    { exams_version: 'abc' },
    sablon({ exams_version: 10 }),
  );
  // `dogrula` biçim denetimini zaten yapıyor; burada yalnızca
  // çökmemesi önemli.
  assert.equal(sonuc.ok, true);
});

test('boş girdi çökmüyor', () => {
  assert.equal(geriSarmaKontrol({}, {}).ok, true);
  assert.equal(geriSarmaKontrol(null, null).ok, true);
});

test('SURUM_ALANLARI panelin yayınladığı alanları kapsıyor', () => {
  // Yeni bir sürüm alanı eklenirse buraya da girmeli; unutulursa
  // koruma o alanda çalışmaz ve kimse fark etmez.
  for (const alan of ['exams_version', 'calendar_version', 'outcomes_version']) {
    assert.ok(SURUM_ALANLARI.includes(alan), `${alan} listede yok`);
  }
});

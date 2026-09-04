/**
 * Yayın doğrulamasının güvenlik testleri.
 *
 * ## Neden bu testler var
 * Bu fonksiyon TÜM kullanıcıların gördüğü veriyi değiştiriyor. Yetki
 * kontrolünde bir gedik, 30.000 öğretmenin sınav takviminin yabancı
 * biri tarafından değiştirilmesi demek.
 *
 * Panelde eskiden gerçek giriş yoktu: `localStorage`'a 'super' yazan
 * herkes yönetici görünüyordu. Fonksiyon o yüzden istemciye HİÇ
 * güvenmiyor — claim'i sunucuda çözüyor. Bu testler o sınırın yerinde
 * durduğunu doğruluyor.
 *
 * Çalıştırma: cd functions && npm test
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { dogrula, yetkiKontrol, AZAMI_BAYT } from '../validate.js';

// ---------------------------------------------------------------- yetki

test('KRITIK: oturumsuz cagri reddediliyor', () => {
  const s = yetkiKontrol(null);
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'unauthenticated');
});

test('KRITIK: claim tasimayan kullanici reddediliyor', () => {
  // Sıradan öğretmen hesabı: token var ama adminRole yok.
  const s = yetkiKontrol({ token: { email: 'ogretmen@example.com' } });
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'permission-denied');
});

test('KRITIK: moderator yayinlayamiyor', () => {
  // Moderatör içerik düzenleyebilir ama yayın TÜM kullanıcıları
  // etkiliyor — firestore.rules içindeki isSuper() ayrımının aynısı.
  const s = yetkiKontrol({ token: { adminRole: 'moderator' } });
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'permission-denied');
});

test('KRITIK: sahte claim degeri gecmiyor', () => {
  // İstemci "adminRole: true" gibi bir şey uydurmaya çalışırsa.
  for (const sahte of [true, 1, 'SUPER', 'super_admin', {}, []]) {
    const s = yetkiKontrol({ token: { adminRole: sahte } });
    assert.equal(s.ok, false, `sahte claim geçti: ${JSON.stringify(sahte)}`);
  }
});

test('super admin gecebiliyor', () => {
  assert.equal(yetkiKontrol({ token: { adminRole: 'super' } }).ok, true);
});

// ----------------------------------------------------------- parametre

test('KRITIK: beyaz liste disi parametre reddediliyor', () => {
  const s = dogrula({ exams_version: 2, kotu_parametre: 'x' });
  assert.equal(s.ok, false);
  assert.match(s.mesaj, /kotu_parametre/);
});

test('KRITIK: bozuk JSON yuku reddediliyor', () => {
  // Bozuk veri yayınlanırsa mobil taraf ayrıştıramaz ve öğretmen
  // sessizce eski veriyle kalır.
  const s = dogrula({ exams_payload: '{bozuk' });
  assert.equal(s.ok, false);
  assert.match(s.mesaj, /JSON/);
});

test('KRITIK: dizi olmayan yuk reddediliyor', () => {
  // Sınav verisi dizi olmalı; nesne gelirse ExamSyncService 0 kayıt
  // yazar ve kimse fark etmez.
  const s = dogrula({ exams_payload: '{"a":1}' });
  assert.equal(s.ok, false);
  assert.match(s.mesaj, /dizi/);
});

test('KRITIK: asiri buyuk yuk reddediliyor', () => {
  const kocaman = JSON.stringify([{ x: 'a'.repeat(AZAMI_BAYT) }]);
  const s = dogrula({ exams_payload: kocaman });
  assert.equal(s.ok, false);
  assert.match(s.mesaj, /büyük/);
});

test('bos istek reddediliyor', () => {
  assert.equal(dogrula({}).ok, false);
  assert.equal(dogrula(null).ok, false);
  assert.equal(dogrula([]).ok, false);
  assert.equal(dogrula('metin').ok, false);
});

test('null deger reddediliyor', () => {
  const s = dogrula({ exams_version: null });
  assert.equal(s.ok, false);
});

test('gecerli yuk kabul ediliyor ve metne cevriliyor', () => {
  const sinavlar = [
    {
      doc_id: 'lgs_2026',
      title: 'LGS 2026',
      institution: 'MEB',
      examDate: '2026-06-14T09:30:00.000',
    },
  ];
  const s = dogrula({
    exams_version: 3,
    exams_payload: JSON.stringify(sinavlar),
    maintenance_mode: false,
  });

  assert.equal(s.ok, true);
  // Remote Config her değeri metin olarak saklar.
  assert.equal(s.params.exams_version, '3');
  assert.equal(s.params.maintenance_mode, 'false');
  assert.equal(JSON.parse(s.params.exams_payload)[0].doc_id, 'lgs_2026');
});

test('gercek sinav paketi sinirlarda kaliyor', async () => {
  // Uygulamadaki asıl veriyle sağlama: 20 sınav ~7 KB.
  const { readFileSync } = await import('node:fs');
  const ham = readFileSync(
    new URL('../../assets/data/official_exams.json', import.meta.url),
    'utf8'
  );
  const s = dogrula({ exams_version: 2, exams_payload: ham });
  assert.equal(s.ok, true);
  assert.ok(
    Buffer.byteLength(ham, 'utf8') < AZAMI_BAYT,
    'gerçek paket sınırı aşıyor'
  );
});

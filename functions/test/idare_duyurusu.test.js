/**
 * İdare duyurusu — sunucu yarısı.
 *
 * `veri/idare_duyurusu_ornek.json` üç dilin ortak örneği: Ana Program
 * (Python) aynı tohumla AYNI imzayı üretmeli, telefon (Dart) bu imzayı
 * doğrulamalı. Örnek RFC 8032 Test 1 tohumuyla imzalı.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  GUNLUK_SINIR,
  istekDogrula,
  kanalKimligi,
  uygula,
  yayinMesaji,
} from '../idare_duyurusu.js';

const ORNEK = JSON.parse(readFileSync(new URL('./veri/idare_duyurusu_ornek.json', import.meta.url), 'utf8'));
const SIMDI = ORNEK.duyuru.olusturma + 60;

const yayin = (ek = {}) => ({
  islem: 'yayinla',
  ...ORNEK.duyuru,
  acik: ORNEK.acik,
  imza: ORNEK.imza,
  ...ek,
});

test('KRITIK: imzalanan metin ortak örnekle birebir', () => {
  assert.equal(yayinMesaji(ORNEK.duyuru).toString('hex'), ORNEK.mesajHex);
});

test('KRITIK: geçerli duyuru kabul edilir, kanal anahtarın parmak iziyle', () => {
  const s = istekDogrula(yayin(), SIMDI);
  assert.equal(s.ok, true, s.mesaj);
  assert.equal(s.kanal, ORNEK.kanal);
  assert.equal(s.kanal, kanalKimligi('meb_775214', Buffer.from(ORNEK.acik, 'base64')));
  assert.equal(s.belge.imza, ORNEK.imza);
});

test('KRITIK: tek harfi değişen duyuru reddedilir', () => {
  for (const ek of [
    { metin: ORNEK.duyuru.metin + '!' },
    { baslik: 'Öğretmenler Kurulu' },
    { bitis: ORNEK.duyuru.bitis + 1 },
    { okulId: 'meb_775215' },
    { id: 'd_1761690000_a1b2c4' },
  ]) {
    const s = istekDogrula(yayin(ek), SIMDI);
    assert.equal(s.ok, false, JSON.stringify(ek));
    assert.equal(s.kod, 'permission-denied', JSON.stringify(ek));
  }
});

test('KRITIK: imza gönderilen anahtara uymazsa reddedilir', () => {
  // Okulun anahtarı yanına başkasının anahtarı yazılamaz. Kendi anahtarıyla
  // imzalayan biri de yalnız KENDİ kanalına yazabilir; öğretmenler onu
  // okumaz (kanal = okul kodu + anahtar parmak izi).
  const baska = Buffer.alloc(32, 7).toString('base64');
  const s = istekDogrula(yayin({ acik: baska }), SIMDI);
  assert.equal(s.ok, false);
});

test('eski ya da ileri tarihli istek reddedilir (saat ve tekrar oynatma)', () => {
  assert.equal(istekDogrula(yayin(), ORNEK.duyuru.olusturma + 3600).kod, 'failed-precondition');
  assert.equal(istekDogrula(yayin(), ORNEK.duyuru.olusturma - 3600).kod, 'failed-precondition');
});

test('biçim sınırları', () => {
  assert.equal(istekDogrula(yayin({ islem: 'yaz' }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ okulId: 'x' }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ id: 'a/b' }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ imza: 'kisa' }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ baslik: 'a'.repeat(81) }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ baslik: 'iki\nsatır' }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ metin: 'a'.repeat(1001) }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ bitis: ORNEK.duyuru.olusturma + 61 * 86400 }), SIMDI).ok, false);
  assert.equal(istekDogrula(yayin({ olusturma: '1761690000' }), SIMDI).ok, false);
});

test('silme isteği imzayla', () => {
  const sil = { islem: 'sil', ...ORNEK.silme, acik: ORNEK.acik };
  const s = istekDogrula(sil, ORNEK.silme.zaman);
  assert.equal(s.ok, true, s.mesaj);
  assert.equal(s.kanal, ORNEK.kanal);
  assert.equal(istekDogrula({ ...sil, id: 'd_baska_duyuru' }, ORNEK.silme.zaman).kod, 'permission-denied');
});

function sahteDb(baslangic = {}) {
  const belgeler = new Map(Object.entries(baslangic));
  const docRef = (yol) => ({
    path: yol,
    id: yol.split('/').at(-1),
    set: async (v) => belgeler.set(yol, v),
    delete: async () => belgeler.delete(yol),
  });
  const colRef = (yol) => ({
    doc: (id) => ({ ...docRef(`${yol}/${id}`), collection: (ad) => colRef(`${yol}/${id}/${ad}`) }),
    get: async () => ({
      docs: [...belgeler.keys()]
        .filter((y) => y.startsWith(`${yol}/`) && !y.slice(yol.length + 1).includes('/'))
        .map((y) => ({ id: y.split('/').at(-1), ref: docRef(y), data: () => belgeler.get(y) })),
    }),
  });
  return {
    belgeler,
    collection: colRef,
    batch: () => {
      const sil = [];
      return { delete: (r) => sil.push(r.path), commit: async () => sil.forEach((y) => belgeler.delete(y)) };
    },
  };
}

test('KRITIK: yazılır, süresi geçen silinir, aynı istek ikinci kez yazılmaz', async () => {
  const kanal = `okul_duyurulari/${ORNEK.kanal}/duyurular`;
  const db = sahteDb({ [`${kanal}/eski`]: { bitis: SIMDI - 1, olusturma: SIMDI - 999 } });
  const s = istekDogrula(yayin(), SIMDI);
  assert.deepEqual(await uygula(db, s, SIMDI), { ok: true });
  assert.ok(db.belgeler.has(`${kanal}/${ORNEK.duyuru.id}`));
  assert.ok(!db.belgeler.has(`${kanal}/eski`));
  assert.deepEqual(await uygula(db, s, SIMDI), { ok: true, zatenVar: true });
});

test('günlük sınır aşılınca yazılmaz', async () => {
  const kanal = `okul_duyurulari/${ORNEK.kanal}/duyurular`;
  const dolu = {};
  for (let i = 0; i < GUNLUK_SINIR; i++) dolu[`${kanal}/d${i}`] = { bitis: SIMDI + 999, olusturma: SIMDI - i };
  const db = sahteDb(dolu);
  const s = await uygula(db, istekDogrula(yayin(), SIMDI), SIMDI);
  assert.equal(s.kod, 'resource-exhausted');
});

test('silme belgeyi kaldırır', async () => {
  const kanal = `okul_duyurulari/${ORNEK.kanal}/duyurular`;
  const db = sahteDb({ [`${kanal}/${ORNEK.duyuru.id}`]: {} });
  const s = istekDogrula({ islem: 'sil', ...ORNEK.silme, acik: ORNEK.acik }, ORNEK.silme.zaman);
  await uygula(db, s, ORNEK.silme.zaman);
  assert.ok(!db.belgeler.has(`${kanal}/${ORNEK.duyuru.id}`));
});

/**
 * K8, ikinci yarı: panel yalnızca değiştirilen ayarı güncellesin.
 *
 * Eskiden sınav yayını yerel kaydın TAMAMINI gönderiyordu; başka bir
 * tarayıcıda açılan bakım modu sessizce kapanıyordu. Karar (28 Eylül
 * 2026): yalnızca değiştirilen ayar gider, diğerlerine dokunulmaz.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  AYAR_ALANLARI,
  IZINLI_PARAMETRELER,
  SURUM_ALANLARI,
  cakismaKontrol,
  canliDegerler,
  okumaYetkisi,
} from '../validate.js';

const sablon = (degerler) =>
  Object.fromEntries(
    Object.entries(degerler).map(([a, d]) => [a, { defaultValue: { value: d } }])
  );

const CANLI = sablon({
  maintenance_mode: 'true',
  maintenance_message: 'Bakım var',
  min_app_version: '1.2.0',
  exams_version: '7',
});

test('KRITIK: başkası bakım modunu değiştirdiyse yayın reddediliyor', () => {
  // Panel "false" görmüştü; bu arada biri "true" yaptı.
  const s = cakismaKontrol(
    { maintenance_mode: 'false' },
    { maintenance_mode: 'false' },
    CANLI
  );
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'aborted');
  assert.match(s.mesaj, /maintenance_mode/);
});

test('gördüğü değer canlıdakiyle aynıysa geçiyor', () => {
  const s = cakismaKontrol(
    { maintenance_mode: 'false' },
    { maintenance_mode: 'true' },
    CANLI
  );
  assert.equal(s.ok, true);
});

test('KRITIK: önceki değer taşımayan ayar yayını reddediliyor (eski panel)', () => {
  const s = cakismaKontrol({ min_app_version: '1.0.0' }, undefined, CANLI);
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'failed-precondition');
  assert.match(s.mesaj, /yenileyin/);
});

test('bir ayarın öncesi eksikse reddediliyor', () => {
  const s = cakismaKontrol(
    { maintenance_mode: 'false', min_app_version: '1.3.0' },
    { maintenance_mode: 'true' },
    CANLI
  );
  assert.equal(s.ok, false);
  assert.equal(s.kod, 'invalid-argument');
});

test('canlıda olmayan ayar: önceki null ile geçiyor', () => {
  const s = cakismaKontrol({ admin_notice: 'Merhaba' }, { admin_notice: null }, CANLI);
  assert.equal(s.ok, true);
});

test('canlıda olmayan ayar: önceki dolu gönderilirse çakışma', () => {
  const s = cakismaKontrol({ admin_notice: 'Merhaba' }, { admin_notice: 'Eski' }, CANLI);
  assert.equal(s.kod, 'aborted');
});

test('KRITIK: sınav yayını ayar taşımadığı için önceki gerekmiyor', () => {
  const s = cakismaKontrol(
    { exams_version: '8', exams_payload: '[]' },
    undefined,
    CANLI
  );
  assert.equal(s.ok, true);
});

test('dizi ya da metin önceki reddediliyor', () => {
  for (const kotu of [[], 'x', 5]) {
    assert.equal(cakismaKontrol({ maintenance_mode: 'false' }, kotu, CANLI).ok, false);
  }
});

test('her beyaz liste parametresi ya sürüm ya ayar ya da sınav verisi', () => {
  // Yeni bir parametre eklenir de sınıflandırılmazsa korumasız kalır.
  for (const p of IZINLI_PARAMETRELER) {
    const sinifli =
      SURUM_ALANLARI.includes(p) || AYAR_ALANLARI.includes(p) ||
      p === 'exams_payload' || p === 'school_directory_version';
    assert.ok(sinifli, `${p} sınıflandırılmamış`);
  }
});

test('canlı değerler yalnızca beyaz listeden', () => {
  const d = canliDegerler({
    ...CANLI,
    gizli_console_parametresi: { defaultValue: { value: 'x' } },
    kosullu: { conditionalValues: {} },
  });
  assert.deepEqual(Object.keys(d).sort(), [
    'exams_version',
    'maintenance_message',
    'maintenance_mode',
    'min_app_version',
  ]);
  assert.equal(d.maintenance_mode, 'true');
});

test('canlı değerler boş şablonda çökmüyor', () => {
  assert.deepEqual(canliDegerler(undefined), {});
  assert.deepEqual(canliDegerler({}), {});
});

test('okuma yetkisi: süper ve moderatör görür, diğerleri görmez', () => {
  assert.equal(okumaYetkisi({ token: { adminRole: 'super' } }).ok, true);
  assert.equal(okumaYetkisi({ token: { adminRole: 'moderator' } }).ok, true);
  assert.equal(okumaYetkisi({ token: {} }).kod, 'permission-denied');
  assert.equal(okumaYetkisi({ token: { adminRole: 'SUPER' } }).ok, false);
  assert.equal(okumaYetkisi(null).kod, 'unauthenticated');
});

test('KRITIK: yayın fonksiyonu çakışma denetimini gerçekten çağırıyor', async () => {
  const { readFileSync } = await import('node:fs');
  const kaynak = readFileSync(new URL('../index.js', import.meta.url), 'utf8');
  const govde = kaynak.slice(
    kaynak.indexOf('export const publishRemoteConfig'),
    kaynak.indexOf('export const readRemoteConfig')
  );
  assert.match(govde, /cakismaKontrol\(\s*sonuc\.params,\s*request\.data\?\.onceki,\s*sablon\.parameters\s*\)/);
  // Sonuç KULLANILIYOR: çağırıp sonucu yok saymak korumasızlıktır.
  assert.match(govde, /if \(!cakisma\.ok\) \{\s*throw new HttpsError\(cakisma\.kod, cakisma\.mesaj\);/);
  // Denetim, yayından ÖNCE.
  assert.ok(govde.indexOf('cakismaKontrol(') < govde.indexOf('publishTemplate('));
});

test('okuma fonksiyonu okuma yetkisini denetliyor, yayın yetkisini değil', async () => {
  const { readFileSync } = await import('node:fs');
  const kaynak = readFileSync(new URL('../index.js', import.meta.url), 'utf8');
  const govde = kaynak.slice(kaynak.indexOf('export const readRemoteConfig'));
  assert.ok(govde.slice(0, 600).includes('okumaYetkisi(request.auth)'));
  assert.ok(!govde.slice(0, 900).includes('publishTemplate'), 'okuma fonksiyonu yazıyor');
});

/**
 * Destek kodu — sunucu yarısı.
 *
 * Ana Program yarısı ve İKİ YARININ UYUMU `sinifcepte-tahta/tests/
 * test_destek.py` içinde: o test bu dosyadaki `destek.js`'i Node ile
 * çalıştırıp çıkan kodu Ana Program'ın doğrulayıcısına veriyor.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  acikAnahtar,
  base32,
  imzala,
  istekDogrula,
  kodBicimle,
  mesaj,
  talepCoz,
  temizle,
} from '../destek.js';

// RFC 8032 bölüm 7.1, Test 1 ve Test 2.
const T1 = {
  tohum: '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
  acik: 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
  mesaj: '',
  imza:
    'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
};
const T2 = {
  tohum: '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
  acik: '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c',
  mesaj: '72',
  imza:
    '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
};
const b64 = (hex) => Buffer.from(hex, 'hex').toString('base64');

test('KRITIK: imza RFC 8032 vektörleriyle birebir', () => {
  for (const v of [T1, T2]) {
    assert.equal(imzala(b64(v.tohum), Buffer.from(v.mesaj, 'hex')).toString('hex'), v.imza);
    assert.equal(Buffer.from(acikAnahtar(b64(v.tohum)), 'base64').toString('hex'), v.acik);
  }
});

test('base32 RFC 4648 vektörleriyle birebir (dolgusuz)', () => {
  const v = { '': '', f: 'MY', fo: 'MZXQ', foo: 'MZXW6', foob: 'MZXW6YQ', fooba: 'MZXW6YTB', foobar: 'MZXW6YTBOI' };
  for (const [girdi, beklenen] of Object.entries(v)) {
    assert.equal(base32(Buffer.from(girdi)), beklenen, girdi);
  }
});

test('kod 103 karakter, 5\'erli gruplar', () => {
  const kod = kodBicimle(imzala(b64(T1.tohum), mesaj('775214', 'K7MQ2XPA')));
  assert.equal(kod.replace(/-/g, '').length, 103);
  assert.ok(kod.split('-').every((g) => g.length <= 5));
});

test('KRITIK: mesaj biçimi Ana Program ile aynı', () => {
  const py = readFileSync(
    new URL('../../../sinifcepte-tahta/ana_program/cekirdek/destek.py', import.meta.url),
    'utf8'
  );
  assert.match(py, /MESAJ_ONEKI = "SCDESTEK1"/);
  assert.match(py, /f"\{MESAJ_ONEKI\}\|\{kurum_kodu\}\|\{talep_numarasi\}"/);
  assert.equal(mesaj('775214', 'K7MQ2XPA').toString(), 'SCDESTEK1|775214|K7MQ2XPA');
});

test('elle yazım: küçük harf, tire, 0/1/8 karışıklığı', () => {
  assert.equal(temizle('k7m0-1x8a'), 'K7MOIXBA');
  assert.equal(talepCoz(' k7mq-2xpa '), 'K7MQ2XPA');
  assert.equal(talepCoz('K7MQ2XP'), null);
  assert.equal(talepCoz('K7MQ2XPAB'), null);
});

test('istek doğrulama: kurum kodu 6 hane, talep 8 karakter, gerekçe zorunlu', () => {
  const iyi = { kurumKodu: '775214', talep: 'K7MQ-2XPA', gerekce: 'Müdür aradı, kod okul e-postasına' };
  assert.deepEqual(istekDogrula(iyi), {
    ok: true, kurumKodu: '775214', talep: 'K7MQ2XPA', gerekce: iyi.gerekce,
  });
  assert.equal(istekDogrula({ ...iyi, kurumKodu: '77521' }).ok, false);
  assert.equal(istekDogrula({ ...iyi, kurumKodu: 'meb_775214' }).ok, false);
  assert.equal(istekDogrula({ ...iyi, talep: 'KISA' }).ok, false);
  assert.equal(istekDogrula({ ...iyi, gerekce: '  ' }).ok, false);
  assert.equal(istekDogrula(undefined).ok, false);
});

test('bozuk tohum anlaşılır hata veriyor', () => {
  assert.throws(() => imzala('kisa', Buffer.alloc(0)), /32 bayt/);
});

// --- Bağlantı ---

const kaynak = readFileSync(new URL('../index.js', import.meta.url), 'utf8');
const govde = kaynak.slice(kaynak.indexOf('export const issueSupportCode'));

test('KRITIK: kodu yalnızca süper yönetici üretiyor', () => {
  assert.ok(govde.includes('yetkiKontrol(request.auth)'));
  assert.ok(!govde.includes('okumaYetkisi'));
});

test('KRITIK: kod ancak denetim kaydı yazıldıktan SONRA dönüyor', () => {
  // Kayıt `try` içinde yutulsaydı izi olmayan kod verilebilirdi.
  const kayit = govde.indexOf("tur: 'destek_kodu'");
  const donus = govde.indexOf('return { ok: true, kod');
  assert.ok(kayit > 0 && donus > kayit);
  // Kayıt ile dönüş arasında hata yutan bir blok olmamalı.
  assert.ok(!govde.slice(kayit, donus).includes('catch'), 'kayıt hatası yutuluyor');
  const imzaSonrasi = govde.slice(govde.indexOf('DESTEK_IMZA_TOHUMU.value()'), kayit);
  assert.equal((imzaSonrasi.match(/\btry\b/g) || []).length, 0, 'kayıt try içinde');
  assert.ok(govde.includes("okulId: `meb_${i.kurumKodu}`"), 'okul geçmişinde görünmüyor');
});

test('KRITIK: gizli anahtar koddan değil gizli değer deposundan', () => {
  assert.match(kaynak, /defineSecret\('DESTEK_IMZA_TOHUMU'\)/);
  assert.match(govde, /secrets: \[DESTEK_IMZA_TOHUMU\]/);
  assert.ok(govde.includes('DESTEK_IMZA_TOHUMU.value()'));
});

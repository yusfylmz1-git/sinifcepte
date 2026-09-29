/**
 * Okul yöneticiliği kararı (Y17, ikinci yarı) — panelden, sunucuda.
 *
 * Yetkiyi custom claim veriyor; burada hata iki yönde de pahalı:
 * fazladan yetki (başka okulun şikâyetlerini okumak) ya da başka bir
 * yetkinin (adminRole) sessizce silinmesi.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  basvuruGuncellemesi,
  basvuruKimligi,
  basvuruOzeti,
  kararDogrula,
  kararUygunMu,
  okulKimligiGecerli,
  yeniClaimler,
} from '../okul_yonetici.js';

test('KRITIK: onay DİĞER yetkileri koruyor', () => {
  // setCustomUserClaims nesnenin tamamını değiştirir.
  const c = yeniClaimler({ adminRole: 'moderator', x: 1 }, 'onay', 'meb_775214');
  assert.deepEqual(c, {
    adminRole: 'moderator',
    x: 1,
    schoolAdminStatus: 'approved',
    schoolId: 'meb_775214',
  });
});

test('KRITIK: ret ve geri alma yalnızca yöneticilik alanlarını siliyor', () => {
  const mevcut = { adminRole: 'super', schoolAdminStatus: 'approved', schoolId: 'meb_1' };
  for (const karar of ['red', 'geri_al']) {
    assert.deepEqual(yeniClaimler(mevcut, karar, 'meb_1'), { adminRole: 'super' });
  }
  assert.equal(mevcut.schoolId, 'meb_1', 'girdi nesnesi değişmemeli');
});

test('claim yoksa da çalışıyor', () => {
  assert.deepEqual(yeniClaimler(undefined, 'onay', 'man_x'), {
    schoolAdminStatus: 'approved',
    schoolId: 'man_x',
  });
  assert.deepEqual(yeniClaimler(null, 'red', 'man_x'), {});
});

test('KRITIK: karar yalnızca uygun durumda', () => {
  assert.equal(kararUygunMu('pending', 'onay').ok, true);
  assert.equal(kararUygunMu('pending', 'red').ok, true);
  assert.equal(kararUygunMu('approved', 'geri_al').ok, true);
  // Zaten karara bağlanmış başvuru yeniden onaylanamaz/reddedilemez.
  assert.equal(kararUygunMu('approved', 'onay').ok, false);
  assert.equal(kararUygunMu('rejected', 'onay').ok, false);
  assert.equal(kararUygunMu('approved', 'red').ok, false);
  // Onaylanmamış biri "geri alınamaz".
  assert.equal(kararUygunMu('pending', 'geri_al').ok, false);
  assert.equal(kararUygunMu('rejected', 'geri_al').ok, false);
});

test('KRITIK: geri alma mobilin tanıdığı durumla yazılıyor', () => {
  // Mobil parseStatus yalnızca pending/approved/rejected tanıyor;
  // bilinmeyen durum "Başvuru yok" diye görünürdü.
  const dart = readFileSync(
    new URL('../../lib/features/auth_profile/data/models/school_admin_request_model.dart', import.meta.url),
    'utf8'
  );
  const tanınan = [...dart.slice(dart.indexOf('parseStatus')).matchAll(/case '(\w+)':/g)].map((m) => m[1]);
  for (const karar of ['onay', 'red', 'geri_al']) {
    const g = basvuruGuncellemesi(karar, 'admin', 'sebep', '2026-09-29T10:00:00Z');
    assert.ok(tanınan.includes(g.status), `${karar} -> ${g.status} mobilde tanınmıyor`);
  }
});

test('geri alma öğretmene sebebiyle görünüyor, panel ayırt ediyor', () => {
  const g = basvuruGuncellemesi('geri_al', 'admin_uid', 'Okuldan ayrıldı', '2026-09-29T10:00:00Z');
  assert.equal(g.status, 'rejected');
  assert.equal(g.rejection_reason, 'Yöneticilik geri alındı: Okuldan ayrıldı');
  assert.equal(g.revoked_at, '2026-09-29T10:00:00Z');
  assert.equal(g.decided_by_uid, 'admin_uid');
  assert.equal(basvuruOzeti({ status: 'rejected', revoked_at: g.revoked_at }, false).geriAlindi, true);
});

test('onayda ret gerekçesi yazılmıyor', () => {
  const g = basvuruGuncellemesi('onay', 'a', 'yok sayılır', 't');
  assert.deepEqual(Object.keys(g).sort(), ['decided_at', 'decided_by_uid', 'status']);
});

test('KRITIK: karar isteği doğrulanıyor', () => {
  assert.equal(kararDogrula({ uid: 'u1', karar: 'onay' }).ok, true);
  assert.equal(kararDogrula({ uid: 'u1', karar: 'yetki_ver' }).ok, false);
  assert.equal(kararDogrula({ uid: '', karar: 'onay' }).ok, false);
  // uid belge yoluna giriyor: '/' başka bir belgeye işaret ederdi.
  assert.equal(kararDogrula({ uid: 'a/b', karar: 'onay' }).ok, false);
  assert.equal(kararDogrula({ uid: 'x'.repeat(129), karar: 'onay' }).ok, false);
  assert.equal(kararDogrula(null).ok, false);
});

test('ret ve geri almada gerekçe zorunlu, 500 karakter sınırı', () => {
  assert.equal(kararDogrula({ uid: 'u', karar: 'red' }).ok, false);
  assert.equal(kararDogrula({ uid: 'u', karar: 'geri_al', gerekce: '  ' }).ok, false);
  assert.equal(kararDogrula({ uid: 'u', karar: 'red', gerekce: 'Belge yok' }).ok, true);
  assert.equal(kararDogrula({ uid: 'u', karar: 'red', gerekce: 'x'.repeat(501) }).ok, false);
});

test('okul kimliği yalnızca kanonik biçimde', () => {
  assert.ok(okulKimligiGecerli('meb_775214'));
  assert.ok(okulKimligiGecerli('man_ozel-okul_1'));
  for (const kotu of ['Mimar Sinan', 'meb_', 'meb_1/2', 'xyz_1', '', null, 5]) {
    assert.equal(okulKimligiGecerli(kotu), false, String(kotu));
  }
});

test('başvuru kimliği mobil depoyla aynı', () => {
  const dart = readFileSync(
    new URL('../../lib/features/auth_profile/data/repositories/school_admin_repository.dart', import.meta.url),
    'utf8'
  );
  assert.match(dart, /requestIdFor\(String teacherUid\) => 'req_\$teacherUid'/);
  assert.equal(basvuruKimligi('abc'), 'req_abc');
});

// --- Sunucu fonksiyonlarının bağlantısı ---

const kaynak = readFileSync(new URL('../index.js', import.meta.url), 'utf8');
/** Bir fonksiyonun gövdesi: bir sonraki dışa aktarıma kadar. */
const govde = (ad) => {
  const bas = kaynak.indexOf(`export const ${ad}`);
  const son = kaynak.indexOf('export const ', bas + 10);
  return kaynak.slice(bas, son < 0 ? undefined : son);
};

test('KRITIK: kararı yalnızca süper yönetici veriyor', () => {
  const g = govde('decideSchoolAdmin');
  assert.ok(g.includes('yetkiKontrol(request.auth)'), 'süper yönetici denetimi yok');
  assert.ok(!g.includes('okumaYetkisi'), 'moderatör karar verebilir');
});

test('KRITIK: karar sırası — doğrula, durum, claim, belge', () => {
  const g = govde('decideSchoolAdmin');
  const sira = [
    'kararDogrula(',
    'kararUygunMu(',
    'okulKimligiGecerli(',
    'setCustomUserClaims(',
    'ref.update(',
  ].map((s) => g.indexOf(s));
  assert.ok(sira.every((i) => i > 0), sira.join(','));
  assert.deepEqual([...sira].sort((a, b) => a - b), sira, 'sıra bozuk');
  // Mevcut claim'ler korunuyor.
  assert.match(g, /yeniClaimler\(kullanici\.customClaims, k\.karar, veri\.school_id\)/);
});

test('listeyi moderatör de görebiliyor, liste yazmıyor', () => {
  const g = govde('listSchoolAdminRequests');
  assert.ok(g.includes('okumaYetkisi(request.auth)'));
  assert.ok(!/\.(update|set|add|delete)\(/.test(g), 'liste fonksiyonu yazıyor');
});

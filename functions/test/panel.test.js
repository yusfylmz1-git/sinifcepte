/**
 * Panelin güvenlik sözleşmesi.
 *
 * ## Neden bu testler var
 * Panel derlenmiyor; bir dosyayı yanlış düzenlemek sessizce güvenlik
 * açığı bırakabilir. Bu testler kaynağa bakarak eski `localStorage`
 * rol seçicinin geri gelmediğini ve yayının sunucudan geçtiğini
 * doğruluyor.
 *
 * Çalıştırma: cd functions && npm test
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const oku = (yol) => readFileSync(new URL(yol, import.meta.url), 'utf8');

/**
 * Yorumları eler.
 *
 * Dosya başındaki açıklama ESKİ kodu örnek olarak gösteriyor
 * (`localStorage.setItem(...)`). Ham metinde arama yapılırsa test
 * kendi belgesine takılıp yanlış alarm verir; aranan şey ÇALIŞAN kod.
 */
function kodu(kaynak) {
  return kaynak
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
}

const authGate = kodu(oku('../../admin_portal/js/auth_gate.js'));
const adminApp = kodu(oku('../../admin_portal/js/admin_app.js'));
const indexHtml = oku('../../admin_portal/index.html');

test('KRITIK: localStorage rol secici geri gelmedi', () => {
  // Eski hâli: signInAs(role) { localStorage.setItem(KEY, role) }
  // Konsoldan 'super' yazan herkes yönetici oluyordu.
  assert.ok(
    !/localStorage\.setItem\([^)]*admin_role/i.test(authGate),
    'rol localStorage’a yazılıyor — sahte yetki mümkün'
  );
  assert.ok(
    !authGate.includes('signInAs'),
    'signInAs geri gelmiş — gerçek giriş bypass edilebilir'
  );
});

test('KRITIK: yetki custom claim uzerinden okunuyor', () => {
  assert.ok(
    authGate.includes('getIdTokenResult'),
    'claim okunmuyor'
  );
  assert.ok(
    authGate.includes('adminRole'),
    'adminRole claim’i kontrol edilmiyor'
  );
  // firestore.rules ile aynı kaynağı kullanmalı.
  const rules = oku('../../firestore.rules');
  assert.ok(
    rules.includes('adminRole'),
    'kurallar farklı bir yetki kaynağı kullanıyor'
  );
});

test('KRITIK: claim zorla tazeleniyor', () => {
  // setCustomUserClaims sonrası token ~1 saat eski claim'i taşır.
  // Yetkiyi yeni alan yönetici beklemek zorunda kalmamalı.
  assert.match(
    authGate,
    /getIdTokenResult\(true\)/,
    'token tazelenmiyor; yeni verilen yetki 1 saat görünmez'
  );
});

test('KRITIK: yetkisiz kullanici oturumu kapatiliyor', () => {
  // Giriş yapıp yetkisi olmayan kullanıcı açıkta bırakılmamalı.
  const blok = authGate.slice(authGate.indexOf('onAuthStateChanged'));
  assert.ok(
    blok.includes('fbSignOut'),
    'yetkisiz kullanıcı oturumda bırakılıyor'
  );
});

test('KRITIK: panel icerigi giris olmadan gizli', () => {
  assert.ok(
    indexHtml.includes('id="admin-shell"'),
    'panel kabuğu sarmalanmamış'
  );
  assert.ok(
    indexHtml.includes('id="admin-login-gate"'),
    'giriş kapısı yok'
  );
  // Kabuk varsayılan olarak gizli başlamalı; giriş gelince açılır.
  assert.match(
    indexHtml,
    /id="admin-shell"[^>]*style="display:\s*none/,
    'panel kabuğu varsayılan olarak açık — içerik bir an görünür'
  );
});

test('KRITIK: yayin sunucudan geciyor, dosya inmiyor', () => {
  const govde = adminApp.slice(
    adminApp.indexOf('publishExamsToMobile'),
    adminApp.indexOf('yayinHatasi')
  );
  assert.ok(
    govde.includes('publishRemoteConfig'),
    'yayın Cloud Function’a gitmiyor'
  );
  assert.ok(
    !govde.includes('downloadRemoteConfigJson'),
    'hâlâ dosya indiriyor — eski akış geri gelmiş'
  );
});

test('KRITIK: yayin basarisiz olursa surum sayaci geri aliniyor', () => {
  // Sayaç ilerler ve yayın başarısız olursa, bir dahaki denemede
  // "zaten güncel" sanılır ve veri hiç gitmez.
  const govde = adminApp.slice(adminApp.indexOf('publishExamsToMobile'));
  const catchBlok = govde.slice(govde.indexOf('catch'), govde.indexOf('finally'));
  assert.ok(
    catchBlok.includes('oncekiSurum'),
    'hata durumunda sürüm geri alınmıyor'
  );
});

test('fonksiyon bolgesi panel ile ayni', () => {
  const fn = oku('../index.js');
  const bolgeFn = fn.match(/BOLGE\s*=\s*'([^']+)'/)?.[1];
  const bolgePanel = authGate.match(/BOLGE\s*=\s*'([^']+)'/)?.[1];
  assert.equal(
    bolgePanel,
    bolgeFn,
    'panel ile fonksiyon farklı bölgeye bakıyor — çağrı 404 döner'
  );
});

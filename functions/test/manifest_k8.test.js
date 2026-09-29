/**
 * Panelin ayar farkı hesabı (K8) — gerçek `manifest_manager.js` kodu.
 *
 * Karar (28 Eylül 2026): panel yalnızca değiştirilen ayarı güncellesin.
 * Hesap yanlışsa ya fazlası gider (başka ayar ezilir) ya eksiği (yönetici
 * yayınladığını sanır, hiçbir şey değişmez).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const kaynak = readFileSync(
  new URL('../../admin_portal/js/manifest_manager.js', import.meta.url),
  'utf8'
);

function yukle() {
  const depo = new Map();
  const baglam = {
    console,
    window: {},
    localStorage: {
      getItem: (a) => (depo.has(a) ? depo.get(a) : null),
      setItem: (a, d) => depo.set(a, String(d)),
    },
  };
  vm.runInNewContext(`${kaynak}\n;globalThis.ManifestManager = ManifestManager;`, baglam);
  return { ManifestManager: baglam.ManifestManager, depo };
}

const { ManifestManager } = yukle();
const fark = (form, canli) => ManifestManager.ayarDegisiklikleri(form, canli);
const FORM = { minApp: '1.2.0', bakim: true, bakimMesaji: 'Bakım var' };
const CANLI = {
  min_app_version: '1.2.0',
  maintenance_mode: 'true',
  maintenance_message: 'Bakım var',
  exams_version: '7',
};

test('KRITIK: değişiklik yoksa hiçbir şey gönderilmiyor', () => {
  assert.deepEqual({ ...fark(FORM, CANLI).params }, {});
});

test('KRITIK: yalnızca değişen ayar gidiyor, öncesiyle', () => {
  const { params, onceki } = fark({ ...FORM, bakim: false }, CANLI);
  assert.deepEqual({ ...params }, { maintenance_mode: 'false' });
  assert.deepEqual({ ...onceki }, { maintenance_mode: 'true' });
});

test('sürüm ve sınav alanları ayar formundan asla gitmiyor', () => {
  const { params } = fark({ minApp: '9.9.9', bakim: false, bakimMesaji: '' }, {});
  for (const a of Object.keys(params)) {
    assert.ok(['min_app_version', 'maintenance_mode', 'maintenance_message'].includes(a), a);
  }
});

test('KRITIK: canlıda olmayan ayar mobil varsayılanıyla karşılaştırılıyor', () => {
  // Canlıda bakım alanları yok: mobil "kapalı, boş mesaj" kullanıyor.
  // Form da kapalı/boş gösteriyorsa bu bir değişiklik DEĞİL.
  const { params } = fark({ minApp: '1.0.0', bakim: false, bakimMesaji: '' }, {});
  assert.deepEqual({ ...params }, {});
});

test('canlıda olmayan ayar değişince öncesi null gidiyor', () => {
  const { params, onceki } = fark({ minApp: '1.0.0', bakim: true, bakimMesaji: '' }, {});
  assert.deepEqual({ ...params }, { maintenance_mode: 'true' });
  assert.deepEqual({ ...onceki }, { maintenance_mode: null });
});

test('boşluklar farka sayılmıyor', () => {
  const { params } = fark({ minApp: ' 1.2.0 ', bakim: true, bakimMesaji: 'Bakım var  ' }, CANLI);
  assert.deepEqual({ ...params }, {});
});

test('KRITIK: canlı değerler yerel kaydın önüne geçiyor', () => {
  const { ManifestManager: M, depo } = yukle();
  // Bu tarayıcıda eski bir yerel kayıt var: bakım kapalı, uzun mesaj.
  depo.set('sinifcepte_admin_manifest', JSON.stringify({
    maintenanceMode: false, maintenanceMessage: 'Eski yerel mesaj', examsVersion: 1,
  }));
  const m = new M();
  assert.equal(m.manifest.maintenanceMessage, 'Eski yerel mesaj');

  m.canliUygula(CANLI);

  assert.equal(m.manifest.maintenanceMode, true);
  assert.equal(m.manifest.maintenanceMessage, 'Bakım var');
  assert.equal(m.manifest.examsVersion, 7);
});

test('KRITIK: canlıda olmayan alan eski yerel değerle KALMIYOR', () => {
  // Kalsaydı formda görünür, "değişiklik" sanılıp yayınlanırdı.
  const { ManifestManager: M, depo } = yukle();
  depo.set('sinifcepte_admin_manifest', JSON.stringify({ maintenanceMessage: 'Eski yerel mesaj' }));
  const m = new M();
  m.canliUygula({});
  assert.equal(m.manifest.maintenanceMessage, '');
  assert.equal(m.manifest.maintenanceMode, false);
  assert.equal(m.manifest.minRequiredAppVersion, '1.0.0');
});

test('mobil varsayılanlar mobil koddakiyle aynı', () => {
  const dart = readFileSync(
    new URL('../../lib/core/cloud/remote_manifest_service.dart', import.meta.url),
    'utf8'
  );
  for (const [anahtar, deger] of Object.entries(ManifestManager.MOBIL_VARSAYILAN)) {
    const satir = dart.match(new RegExp(`'${anahtar}':\s*([^,]+),`));
    assert.ok(satir, `${anahtar} mobil varsayılanlarda yok`);
    const dartDeger = satir[1].trim().replace(/^'|'$/g, '');
    assert.equal(dartDeger, deger, anahtar);
  }
});

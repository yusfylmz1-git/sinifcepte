/**
 * `index.js` gerçekten yükleniyor mu?
 *
 * Diğer testler bu dosyayı METİN olarak okuyor: sözdizimi bozuk bir
 * `index.js` hepsinden geçerdi ve hata ancak yayında görünürdü
 * (29 Eylül 2026'da bir mutasyon denemesi bunu gösterdi).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

test('KRITIK: index.js yükleniyor, her fonksiyon dışa aktarılıyor', async () => {
  process.env.GCLOUD_PROJECT ??= 'sinifcepte';
  const m = await import('../index.js');
  assert.deepEqual(Object.keys(m).sort(), [
    'decideSchoolAdmin',
    'fetchOsymTakvim',
    'findPerson',
    'issueSupportCode',
    'listSchoolAdminRequests',
    'publishRemoteConfig',
    'readRemoteConfig',
    'removeFromSchoolDirectory',
    'schoolOverview',
  ]);
});

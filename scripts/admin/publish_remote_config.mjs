#!/usr/bin/env node
/**
 * Admin panelinden indirilen parametreleri Firebase Remote Config'e yayınlar.
 *
 * ## Neden bu adım var
 * Remote Config'e yazmak Admin SDK gerektirir; admin paneli tarayıcıda
 * çalıştığı için doğrudan yayın yapamaz. Panel parametreleri JSON olarak
 * indirir, bu betik yayınlar.
 *
 * ## Neden Firestore değil Remote Config
 * Sürüm/bakım kontrolü her uygulama açılışında yapılır. Firestore'dan
 * okunsaydı 10M kullanıcıda aylık ~$180 maliyet oluşurdu. Remote Config
 * ücretsizdir ve okuma kotası yoktur.
 *
 * ## Kullanım
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json
 *   node scripts/admin/publish_remote_config.mjs remote_config_params.json
 *   node scripts/admin/publish_remote_config.mjs --show
 */
import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const showOnly = args.includes('--show');
const file = args.find((a) => !a.startsWith('--'));

if (!showOnly && !file) {
  console.error(`
Kullanım:
  node scripts/admin/publish_remote_config.mjs <params.json>   Yayınlar
  node scripts/admin/publish_remote_config.mjs --show          Mevcut değerleri gösterir

Parametre dosyası admin panelindeki "Remote Config JSON indir" ile üretilir.
`);
  process.exit(1);
}

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
try {
  readFileSync(credPath, 'utf8');
} catch {
  console.error('GOOGLE_APPLICATION_CREDENTIALS ayarlı değil veya okunamıyor.');
  console.error('Firebase Console > Project Settings > Service accounts > Generate new private key');
  process.exit(1);
}

let admin;
try {
  admin = await import('firebase-admin');
} catch {
  console.error('firebase-admin bulunamadı:  cd scripts/admin && npm i firebase-admin');
  process.exit(1);
}

const app = admin.default.initializeApp({
  credential: admin.default.credential.applicationDefault(),
});
const rc = admin.default.remoteConfig(app);

const template = await rc.getTemplate();

if (showOnly) {
  console.log('\nMevcut Remote Config parametreleri:\n');
  for (const [key, param] of Object.entries(template.parameters)) {
    const value = String(param.defaultValue?.value ?? '(tanımsız)');
    const gosterim =
      value.length > 60 ? `${value.slice(0, 45)}… (${value.length} bayt)` : value;
    console.log(`  ${key.padEnd(26)} = ${gosterim}`);
  }
  console.log(`\nSürüm: ${template.version?.versionNumber ?? '?'}\n`);
  process.exit(0);
}

let params;
try {
  params = JSON.parse(readFileSync(file, 'utf8'));
} catch (err) {
  console.error(`Parametre dosyası okunamadı: ${file}`);
  console.error(err.message);
  process.exit(1);
}

// Mobil tarafın (RemoteManifestService) beklediği anahtarlar.
const ALLOWED = new Set([
  'calendar_version',
  'outcomes_version',
  'announcements_version',
  'school_directory_version',
  'min_app_version',
  'latest_app_version',
  'maintenance_mode',
  'maintenance_message',
]);

const unknown = Object.keys(params).filter((k) => !ALLOWED.has(k));
if (unknown.length) {
  console.error(`Tanınmayan parametre(ler): ${unknown.join(', ')}`);
  console.error('Mobil taraf bunları okumaz; yayın iptal edildi.');
  process.exit(1);
}

for (const [key, value] of Object.entries(params)) {
  template.parameters[key] = {
    defaultValue: { value: String(value) },
    description: 'SınıfCepte manifest parametresi',
  };
}

// validateTemplate: hatalı şablon yayınlanıp uygulamayı bozmasın.
await rc.validateTemplate(template);
const published = await rc.publishTemplate(template);

console.log('\n✓ Remote Config yayınlandı.');
console.log(`  Sürüm: ${published.version?.versionNumber}`);
console.log('\nYayınlanan değerler:');
for (const [key, value] of Object.entries(params)) {
  // Veri tasiyan parametreler (exams_payload gibi) kilobaytlarca JSON
  // olabiliyor; konsolu bogmasin diye ozetlenir.
  const str = String(value);
  const gosterim = str.length > 60 ? `${str.slice(0, 45)}… (${str.length} bayt)` : str;
  console.log(`  ${key.padEnd(26)} = ${gosterim}`);
}
console.log(
  '\nMobil cihazlar en geç 6 saat içinde alır; kullanıcı "senkronize et"\n' +
    'dediğinde ise anında çekilir.\n'
);

process.exit(0);

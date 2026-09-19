#!/usr/bin/env node
/**
 * İlk süper admin tohumu. Firebase Console'da custom claim UI yoktur.
 *
 * ## Neden bu script gerçekten iş yapıyor
 *
 * Önceki sürüm hiçbir şey yapmıyordu: yapılması gerekenleri `console.log`
 * ile yazdırıp çıkıyordu. Yani üretim hattının anahtarı bir print
 * ifadesiydi ve ilk süper admin hiç oluşmuyordu — portal "yetkiniz yok"
 * diyordu (bağımsız incelemede bildirildi, 19 Eylül 2026'da doğrulandı).
 *
 * ## Kullanım
 *
 *   # PowerShell
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secrets\sinifcepte-sa.json"
 *   node scripts/admin/bootstrap_super_admin.mjs --email sen@gmail.com --uid FIREBASE_UID
 *
 *   # Ne yapacağını görmek için (hiçbir şey yazmaz)
 *   node scripts/admin/bootstrap_super_admin.mjs --email ... --uid ... --dry-run
 *
 * Service account JSON **asla commit edilmez**.
 *
 * ## Yazdıkları
 *
 *   1. Custom claim: `adminRole: 'super'`
 *   2. `admin_users/{uid}` belgesi
 *
 * İkisi birlikte gerekli: kurallar claim'e bakıyor, panel belgeye.
 */
import { existsSync } from 'node:fs';

function arg(name) {
  const idx = process.argv.indexOf(name);
  return idx >= 0 ? process.argv[idx + 1] : '';
}

const email = arg('--email');
const uid = arg('--uid');
const dryRun = process.argv.includes('--dry-run');

if (!email || !uid) {
  console.error(
    'Kullanım: node scripts/admin/bootstrap_super_admin.mjs ' +
      '--email you@gmail.com --uid <uid> [--dry-run]',
  );
  process.exit(1);
}

// UID biçimi: Firebase 28 karakterlik bir dize üretiyor. Yanlış UID'ye
// yetki vermek geri alınamaz bir hata sınıfı — en azından kaba bir
// denetim yapılmalı.
if (uid.length < 20 || uid.includes('@') || /\s/.test(uid)) {
  console.error(`HATA: '${uid}' bir Firebase UID'sine benzemiyor.`);
  console.error('UID e-posta DEĞİLDİR; Firebase Console > Authentication');
  console.error("altındaki 'User UID' sütunundan alınır.");
  process.exit(1);
}

const kimlikYolu = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';

console.log('SınıfCepte — süper admin tohumu');
console.log(`  hedef : ${email}`);
console.log(`  uid   : ${uid}`);
console.log(`  claim : adminRole=super`);
console.log('');

if (dryRun) {
  console.log('--dry-run verildi; hiçbir şey yazılmadı.');
  process.exit(0);
}

if (!kimlikYolu || !existsSync(kimlikYolu)) {
  console.error('HATA: GOOGLE_APPLICATION_CREDENTIALS yok ya da dosya bulunamadı.');
  console.error('');
  console.error('  1) Firebase Console > Proje ayarları > Hizmet hesapları');
  console.error('  2) "Yeni özel anahtar oluştur" ile JSON indir');
  console.error('  3) PowerShell:');
  console.error('     $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\\secrets\\sa.json"');
  console.error('');
  console.error('Bu dosya ASLA commit edilmez.');
  // Çıkış kodu 1: sessizce "başarılı" görünmek, yetkinin verildiği
  // sanılmasına yol açardı ve hata ancak portalda fark edilirdi.
  process.exit(1);
}

let admin;
try {
  admin = await import('firebase-admin');
} catch (hata) {
  console.error('HATA: firebase-admin bulunamadı.');
  console.error('  cd scripts/admin && npm install');
  console.error(`  (${hata.message})`);
  process.exit(1);
}

try {
  const app = admin.default.initializeApp({
    credential: admin.default.credential.applicationDefault(),
  });

  const auth = admin.default.auth(app);
  const db = admin.default.firestore(app);

  // Kullanıcı GERÇEKTEN var mı?
  //
  // `setCustomUserClaims` var olmayan UID'de hata veriyor ama mesajı
  // yeterince açık değil. Önce okuyup e-postayı karşılaştırmak, yanlış
  // hesaba yetki vermeyi önlüyor — geri alınması zor bir hata.
  const kullanici = await auth.getUser(uid);

  if (kullanici.email && kullanici.email.toLowerCase() !== email.toLowerCase()) {
    console.error('HATA: UID ile e-posta eşleşmiyor.');
    console.error(`  verilen : ${email}`);
    console.error(`  gerçek  : ${kullanici.email}`);
    console.error('Yanlış hesaba süper yetki vermemek için durduruldu.');
    process.exit(1);
  }

  // Mevcut claim'ler korunuyor: üzerine yazmak başka yetkileri silerdi.
  const mevcutClaim = kullanici.customClaims || {};
  await auth.setCustomUserClaims(uid, { ...mevcutClaim, adminRole: 'super' });

  await db.doc(`admin_users/${uid}`).set(
    {
      email,
      role: 'super',
      disabled: false,
      updatedAt: new Date().toISOString(),
    },
    { merge: true },
  );

  console.log('✓ Custom claim yazıldı: adminRole=super');
  console.log(`✓ admin_users/${uid} belgesi yazıldı`);
  console.log('');
  console.log('SON ADIM: portalda çıkış yapıp tekrar girin.');
  console.log('Claim yalnızca YENİ token ile gelir; açık oturum eski');
  console.log("token'ı taşır ve panel hâlâ 'yetkiniz yok' der.");
  process.exit(0);
} catch (hata) {
  console.error(`HATA: ${hata.message}`);
  if (hata.code === 'auth/user-not-found') {
    console.error('');
    console.error('Bu UID ile kullanıcı yok. Önce o hesapla uygulamaya');
    console.error('bir kez giriş yapın; Firebase kullanıcıyı o an oluşturur.');
  }
  process.exit(1);
}

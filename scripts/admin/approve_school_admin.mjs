#!/usr/bin/env node
/**
 * Okul yöneticiliği başvurusunu onaylar veya reddeder.
 *
 * ## Neden betik, neden uygulama içi değil
 * Yetkiyi veren şey Firebase **custom claim**'dir ve claim yalnızca
 * Admin SDK ile (yani sunucu tarafında) yazılabilir. İstemci hiçbir
 * koşulda kendine yönetici diyememelidir; firestore.rules de başvuranın
 * kendi kaydını 'approved' yapmasını ayrıca engeller.
 *
 * ## Kullanım
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json
 *   node scripts/admin/approve_school_admin.mjs --list
 *   node scripts/admin/approve_school_admin.mjs --uid <ogretmenUid> --approve
 *   node scripts/admin/approve_school_admin.mjs --uid <ogretmenUid> --reject --reason "..."
 *
 * Onay sonrası öğretmenin uygulamada çıkış/giriş yapması ya da
 * "Yetkiyi yenile" düğmesine basması gerekir: claim'ler ID token içinde
 * taşınır ve token varsayılan olarak saatte bir yenilenir.
 */
import { readFileSync } from 'node:fs';

function arg(name) {
  const idx = process.argv.indexOf(name);
  return idx >= 0 ? process.argv[idx + 1] : '';
}
const has = (name) => process.argv.includes(name);

const uid = arg('--uid');
const reason = arg('--reason') || '';
const wantList = has('--list');
const wantApprove = has('--approve');
const wantReject = has('--reject');

if (!wantList && !uid) {
  console.error(`
Kullanım:
  --list                          Bekleyen başvuruları listeler
  --uid <uid> --approve           Başvuruyu onaylar (claim yazar)
  --uid <uid> --reject [--reason] Başvuruyu reddeder
`);
  process.exit(1);
}

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
try {
  readFileSync(credPath, 'utf8');
} catch {
  console.error('GOOGLE_APPLICATION_CREDENTIALS ayarlı değil veya dosya okunamıyor.');
  console.error('Firebase Console > Project Settings > Service accounts > Generate new private key');
  console.error('Ardından:  set GOOGLE_APPLICATION_CREDENTIALS=C:\\secrets\\sinifcepte-sa.json');
  process.exit(1);
}

let admin;
try {
  admin = await import('firebase-admin');
} catch {
  console.error('firebase-admin bulunamadı. Kurulum:  cd scripts/admin && npm i firebase-admin');
  process.exit(1);
}

const app = admin.default.initializeApp({
  credential: admin.default.credential.applicationDefault(),
});
const auth = admin.default.auth(app);
const db = admin.default.firestore(app);

const REQUESTS = 'school_admin_requests';

if (wantList) {
  const snap = await db
    .collection(REQUESTS)
    .where('status', '==', 'pending')
    .limit(50)
    .get();

  if (snap.empty) {
    console.log('Bekleyen başvuru yok.');
  } else {
    console.log(`\n${snap.size} bekleyen başvuru:\n`);
    snap.forEach((doc) => {
      const d = doc.data();
      console.log(`  UID   : ${d.teacher_uid}`);
      console.log(`  Ad    : ${d.teacher_name} <${d.teacher_email}>`);
      console.log(`  Okul  : ${d.city} / ${d.district} — ${d.school_name}`);
      console.log(`  Not   : ${d.note || '(yok)'}`);
      console.log(`  Tarih : ${d.requested_at}`);
      console.log(`  Onay  : node scripts/admin/approve_school_admin.mjs --uid ${d.teacher_uid} --approve\n`);
    });
  }
  process.exit(0);
}

const docId = `req_${uid}`;
const ref = db.collection(REQUESTS).doc(docId);
const doc = await ref.get();

if (!doc.exists) {
  console.error(`Başvuru bulunamadı: ${docId}`);
  process.exit(1);
}

const data = doc.data();

if (wantApprove) {
  // 1. Mevcut claim'leri koru, yalnızca yöneticilik alanlarını ekle.
  //    Aksi halde adminRole gibi başka yetkiler silinirdi.
  //
  //    schoolId claim'i şart: firestore.rules yöneticinin yalnızca KENDİ
  //    okulunun şikâyetlerini görmesini bu alanla sınırlar.
  const user = await auth.getUser(uid);
  const claims = {
    ...(user.customClaims || {}),
    schoolAdminStatus: 'approved',
    schoolId: data.school_id,
  };
  await auth.setCustomUserClaims(uid, claims);

  // 2. Başvuru kaydını güncelle (gösterim ve denetim izi için).
  await ref.update({
    status: 'approved',
    decided_at: new Date().toISOString(),
    decided_by_uid: 'super-admin-script',
  });

  console.log(`✓ Onaylandı: ${data.teacher_name} (${data.school_name})`);
  console.log('  Öğretmenin uygulamada çıkış/giriş yapması veya');
  console.log('  "Yetkiyi yenile" düğmesine basması gerekiyor.');
} else if (wantReject) {
  const user = await auth.getUser(uid);
  const claims = { ...(user.customClaims || {}) };
  delete claims.schoolAdminStatus;
  delete claims.schoolId;
  await auth.setCustomUserClaims(uid, claims);

  await ref.update({
    status: 'rejected',
    decided_at: new Date().toISOString(),
    decided_by_uid: 'super-admin-script',
    rejection_reason: reason,
  });

  console.log(`✗ Reddedildi: ${data.teacher_name}${reason ? ` — ${reason}` : ''}`);
} else {
  console.log('Başvuru bilgisi:');
  console.log(JSON.stringify(data, null, 2));
  console.log('\nKarar için --approve veya --reject ekleyin.');
}

process.exit(0);

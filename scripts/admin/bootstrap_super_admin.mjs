#!/usr/bin/env node
/**
 * İlk süper admin tohumu. Firebase Console'da custom claim UI yoktur.
 *
 * Kullanım (senin makinen, service account asla commit edilmez):
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\secrets\sinifcepte-sa.json
 *   node scripts/admin/bootstrap_super_admin.mjs --email sen@gmail.com --uid FIREBASE_UID
 */
import { readFileSync } from 'node:fs';

function arg(name) {
  const idx = process.argv.indexOf(name);
  return idx >= 0 ? process.argv[idx + 1] : '';
}

const email = arg('--email');
const uid = arg('--uid');
if (!email || !uid) {
  console.error('Kullanım: node scripts/admin/bootstrap_super_admin.mjs --email you@gmail.com --uid <uid>');
  process.exit(1);
}

console.log('Bu script firebase-admin ister.');
console.log('1) Firebase projesi oluştur');
console.log('2) Service account JSON indir, GOOGLE_APPLICATION_CREDENTIALS ver');
console.log('3) npm i firebase-admin (scripts/admin içinde)');
console.log(`Hedef: ${email} / ${uid} -> adminRole=super`);
console.log('Kurulum bitince aşağıdaki çağrı çalışır:');
console.log(`  auth.setCustomUserClaims('${uid}', { adminRole: 'super' })`);
console.log(`  firestore.doc('admin_users/${uid}').set({ email: '${email}', role: 'super', disabled: false })`);
console.log('Ardından portalda çıkış / tekrar giriş veya getIdToken(true).');

try {
  readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS || '', 'utf8');
} catch (_) {
  console.log('GOOGLE_APPLICATION_CREDENTIALS yok — şimdilik yalnızca runbook yazdırıldı.');
}

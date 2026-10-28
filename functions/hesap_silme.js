/**
 * Hesap silme — kullanıcının buluttaki bütün kayıtları ve hesabı.
 *
 * ## Neden bu dosya var
 * Google Play, hesap açılan uygulamada uygulama içinden hesap silmeyi
 * şart koşuyor; KVKK m.7 de silme hakkı tanıyor. 28 Ekim 2026'ya kadar
 * yalnızca "destek adresine yazın" deniyordu.
 *
 * Silme istemcide yapılamazdı: başka öğretmenin sınıfındaki mesajlar,
 * diğer velilerin sınıf erişimleri ve duyuru okuma işaretleri kuralla
 * kullanıcıya kapalı. Admin SDK hepsine ulaşıyor.
 *
 * Bir uid hem öğretmen hem veli olabilir (çocuğu başka okulda okuyan
 * öğretmen); plan iki rolün kayıtlarını birlikte siler.
 *
 * Firebase'e bağlı değil: `db` Admin SDK'nın Firestore'u ya da testteki
 * sahtesi. Kullanılan yüzey: collection/collectionGroup + where + get,
 * doc, recursiveDelete, batch.
 */

/**
 * Kullanıcının uid'sini taşıyan alanlar. `grup` koleksiyon grubu
 * sorgusudur ve `firestore.indexes.json`'da COLLECTION_GROUP tek alan
 * dizini ister (`hesap_silme.test.js` bunu denetliyor).
 */
export const SILME_PLANI = Object.freeze([
  // Öğretmen
  { kapsam: 'koleksiyon', ad: 'parent_tokens', alan: 'teacherUid' },
  { kapsam: 'koleksiyon', ad: 'parent_links', alan: 'teacherUid' },
  { kapsam: 'koleksiyon', ad: 'school_teachers', alan: 'teacherUid' },
  { kapsam: 'grup', ad: 'staff', alan: 'teacherUid' },
  { kapsam: 'grup', ad: 'messages', alan: 'teacherUid' },
  { kapsam: 'grup', ad: 'appointments', alan: 'teacherUid' },
  // Veli
  { kapsam: 'koleksiyon', ad: 'parent_links', alan: 'parentUid' },
  { kapsam: 'koleksiyon', ad: 'parent_class_access', alan: 'parentUid' },
  { kapsam: 'grup', ad: 'messages', alan: 'parentUserId' },
  { kapsam: 'grup', ad: 'appointments', alan: 'parentUserId' },
  { kapsam: 'grup', ad: 'status_reports', alan: 'parentUserId' },
  // İkisi
  { kapsam: 'koleksiyon', ad: 'user_blocks', alan: 'blockerUid' },
  { kapsam: 'koleksiyon', ad: 'user_blocks', alan: 'blockedUid' },
  { kapsam: 'koleksiyon', ad: 'support_requests', alan: 'userId' },
]);

/** Firestore `in` sorgusu en çok 30 değer alır. */
const IN_SINIRI = 30;
/** Bir toplu yazma en çok 500 işlem; pay bırakılır. */
const TOPLU_SINIR = 400;

const uidGecerli = (uid) => typeof uid === 'string' && /^[A-Za-z0-9]{10,128}$/.test(uid);

/**
 * Silinecekleri toplar; hiçbir şeyi silmez.
 *
 * @returns {{ siniflar: object[], belgeler: object[] }}
 *   `siniflar` alt koleksiyonlarıyla (duyuru, okuma, mesaj, randevu,
 *   kadro, durum bildirimi) silinir; `belgeler` tek tek.
 */
export async function silinecekleriTopla(db, uid) {
  if (!uidGecerli(uid)) throw new Error('geçersiz uid');

  const siniflar = (await db.collection('class_rooms').where('teacherUid', '==', uid).get()).docs.map(
    (d) => d.ref
  );

  const belgeler = new Map();
  const ekle = (ref) => belgeler.set(ref.path, ref);

  for (const p of SILME_PLANI) {
    const kaynak = p.kapsam === 'grup' ? db.collectionGroup(p.ad) : db.collection(p.ad);
    const snap = await kaynak.where(p.alan, '==', uid).get();
    for (const d of snap.docs) ekle(d.ref);
  }

  // Başka velilerin, silinen sınıflara erişim kayıtları: sınıf gidince
  // geriye öğrenci kimliği taşıyan sahipsiz satır kalmasın.
  const sinifKimlikleri = siniflar.map((r) => r.id);
  for (let i = 0; i < sinifKimlikleri.length; i += IN_SINIRI) {
    const parca = sinifKimlikleri.slice(i, i + IN_SINIRI);
    const snap = await db.collection('parent_class_access').where('classCloudId', 'in', parca).get();
    for (const d of snap.docs) ekle(d.ref);
  }

  // Velinin duyuru okuma işaretleri: belge kimliği velinin uid'si, içinde
  // uid alanı yok; velinin sınıflarındaki duyurulardan bulunur.
  const veliErisimleri = await db.collection('parent_class_access').where('parentUid', '==', uid).get();
  const veliSiniflari = new Set(veliErisimleri.docs.map((d) => String(d.data().classCloudId ?? '')));
  for (const sinif of veliSiniflari) {
    if (!sinif) continue;
    const duyurular = await db.collection('class_rooms').doc(sinif).collection('announcements').get();
    for (const d of duyurular.docs) ekle(d.ref.collection('reads').doc(uid));
  }

  // Kendi sınıflarının içindeki belgeler sınıfla birlikte gidiyor.
  const icerde = (yol) => sinifKimlikleri.some((k) => yol.startsWith(`class_rooms/${k}/`));
  return {
    siniflar,
    belgeler: [...belgeler.values()].filter((r) => !icerde(r.path)),
  };
}

/**
 * Siler ve sayıları döndürür. Yeniden çağrılabilir: yarıda kalırsa ikinci
 * çağrı kalanı siler.
 */
export async function bulutVerisiniSil(db, uid) {
  const { siniflar, belgeler } = await silinecekleriTopla(db, uid);
  for (const ref of siniflar) {
    await db.recursiveDelete(ref);
  }
  for (let i = 0; i < belgeler.length; i += TOPLU_SINIR) {
    const toplu = db.batch();
    for (const ref of belgeler.slice(i, i + TOPLU_SINIR)) toplu.delete(ref);
    await toplu.commit();
  }
  await db.collection('users').doc(uid).delete();
  return { sinif: siniflar.length, belge: belgeler.length };
}

/**
 * Hesap silme: kullanıcının izi kalmıyor, başkasının verisine dokunulmuyor.
 *
 * Firestore yerine bellekte duran küçük bir sahte kullanılır; yalnızca
 * `hesap_silme.js`'in kullandığı yüzeyi taklit eder.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { SILME_PLANI, bulutVerisiniSil, silinecekleriTopla } from '../hesap_silme.js';

function sahteDb(baslangic) {
  const belgeler = new Map(Object.entries(baslangic));

  const docRef = (yol) => ({
    path: yol,
    id: yol.split('/').at(-1),
    collection: (ad) => colRef(`${yol}/${ad}`),
    delete: async () => belgeler.delete(yol),
  });
  const snap = (yollar) => ({
    docs: yollar.map((y) => ({ id: y.split('/').at(-1), ref: docRef(y), data: () => belgeler.get(y) })),
  });
  const uyar = (veri, f, op, v) => (op === 'in' ? v.includes(veri?.[f]) : veri?.[f] === v);
  const sorgu = (secici, filtre = []) => ({
    where: (f, op, v) => sorgu(secici, [...filtre, [f, op, v]]),
    get: async () =>
      snap([...belgeler.keys()].filter((y) => secici(y) && filtre.every(([f, op, v]) => uyar(belgeler.get(y), f, op, v)))),
  });
  const colRef = (yol) => ({
    ...sorgu((y) => y.startsWith(`${yol}/`) && y.split('/').length === yol.split('/').length + 1),
    doc: (id) => docRef(`${yol}/${id}`),
  });

  return {
    belgeler,
    collection: colRef,
    collectionGroup: (ad) => sorgu((y) => y.split('/').at(-2) === ad),
    recursiveDelete: async (ref) => {
      for (const y of [...belgeler.keys()]) {
        if (y === ref.path || y.startsWith(`${ref.path}/`)) belgeler.delete(y);
      }
    },
    batch: () => {
      const silinecek = [];
      return {
        delete: (ref) => silinecek.push(ref.path),
        commit: async () => silinecek.forEach((y) => belgeler.delete(y)),
      };
    },
  };
}

const OGRETMEN = 'ogretmenTTTTTTTTTT01';
const BASKA = 'ogretmenXXXXXXXXXX02';
const VELI = 'veliPPPPPPPPPPPPPP03';
const BASKA_VELI = 'veliQQQQQQQQQQQQQQ04';

function okul() {
  const sinifim = `cls_${OGRETMEN}_1`;
  const baskaSinif = `cls_${BASKA}_7`;
  return {
    [`class_rooms/${sinifim}`]: { teacherUid: OGRETMEN },
    [`class_rooms/${sinifim}/announcements/a1`]: { authorUid: OGRETMEN },
    [`class_rooms/${sinifim}/announcements/a1/reads/${VELI}`]: { readAt: 'x' },
    [`class_rooms/${sinifim}/messages/m1`]: { teacherUid: OGRETMEN, parentUserId: VELI },
    [`class_rooms/${sinifim}/staff/${BASKA}`]: { teacherUid: BASKA },
    [`parent_tokens/h1`]: { teacherUid: OGRETMEN },
    [`parent_links/${VELI}_stu_${OGRETMEN}_4`]: { teacherUid: OGRETMEN, parentUid: VELI },
    [`parent_class_access/${VELI}_${sinifim}`]: { parentUid: VELI, classCloudId: sinifim },
    [`school_teachers/meb_1_${OGRETMEN}`]: { teacherUid: OGRETMEN },
    [`users/${OGRETMEN}`]: { rol: 'ogretmen' },
    // Öğretmen başka sınıfın kadrosunda.
    [`class_rooms/${baskaSinif}`]: { teacherUid: BASKA },
    [`class_rooms/${baskaSinif}/staff/${OGRETMEN}`]: { teacherUid: OGRETMEN },
    [`class_rooms/${baskaSinif}/messages/m2`]: { teacherUid: OGRETMEN, parentUserId: BASKA_VELI },
    [`class_rooms/${baskaSinif}/messages/m3`]: { teacherUid: BASKA, parentUserId: BASKA_VELI },
    [`class_rooms/${baskaSinif}/appointments/r1`]: { teacherUid: OGRETMEN, parentUserId: BASKA_VELI },
    [`class_rooms/${baskaSinif}/announcements/a9`]: { authorUid: BASKA },
    [`class_rooms/${baskaSinif}/announcements/a9/reads/${BASKA_VELI}`]: { readAt: 'x' },
    [`class_rooms/${baskaSinif}/announcements/a9/reads/${VELI}`]: { readAt: 'x' },
    [`class_rooms/${baskaSinif}/status_reports/s1`]: { parentUserId: BASKA_VELI },
    [`parent_class_access/${BASKA_VELI}_${baskaSinif}`]: { parentUid: BASKA_VELI, classCloudId: baskaSinif },
    [`parent_links/${BASKA_VELI}_stu_${BASKA}_9`]: { teacherUid: BASKA, parentUid: BASKA_VELI },
    [`school_teachers/meb_1_${BASKA}`]: { teacherUid: BASKA },
    [`user_blocks/${OGRETMEN}_${BASKA_VELI}`]: { blockerUid: OGRETMEN, blockedUid: BASKA_VELI },
    [`user_blocks/${BASKA_VELI}_${OGRETMEN}`]: { blockerUid: BASKA_VELI, blockedUid: OGRETMEN },
    [`support_requests/d1`]: { userId: OGRETMEN },
    [`support_requests/d2`]: { userId: BASKA },
  };
}

test('KRITIK: öğretmen silinince sınıfı, kodları, bağları, kadro izi gider', async () => {
  const db = sahteDb(okul());
  await bulutVerisiniSil(db, OGRETMEN);
  const kalan = [...db.belgeler.keys()];

  assert.equal(kalan.filter((y) => y.includes(OGRETMEN)).length, 0, kalan.filter((y) => y.includes(OGRETMEN)).join('\n'));
  for (const [y, v] of db.belgeler) {
    assert.ok(!Object.values(v).includes(OGRETMEN), `${y} hâlâ öğretmeni taşıyor`);
  }
  // Silinen sınıfa bağlı velinin erişim satırı da gider.
  assert.ok(!db.belgeler.has(`parent_class_access/${VELI}_cls_${OGRETMEN}_1`));
});

test('KRITIK: başkasının sınıfı ve mesajları yerinde kalır', async () => {
  const db = sahteDb(okul());
  await bulutVerisiniSil(db, OGRETMEN);
  const baskaSinif = `class_rooms/cls_${BASKA}_7`;
  for (const y of [
    baskaSinif,
    `${baskaSinif}/messages/m3`,
    `${baskaSinif}/announcements/a9`,
    `${baskaSinif}/announcements/a9/reads/${BASKA_VELI}`,
    `${baskaSinif}/status_reports/s1`,
    `parent_class_access/${BASKA_VELI}_cls_${BASKA}_7`,
    `parent_links/${BASKA_VELI}_stu_${BASKA}_9`,
    `school_teachers/meb_1_${BASKA}`,
    'support_requests/d2',
  ]) {
    assert.ok(db.belgeler.has(y), `${y} silinmemeliydi`);
  }
});

test('KRITIK: veli silinince bağları, mesajları, randevu ve okuma işaretleri gider', async () => {
  const db = sahteDb(okul());
  await bulutVerisiniSil(db, BASKA_VELI);
  const baskaSinif = `class_rooms/cls_${BASKA}_7`;
  for (const y of [
    `parent_links/${BASKA_VELI}_stu_${BASKA}_9`,
    `parent_class_access/${BASKA_VELI}_cls_${BASKA}_7`,
    `${baskaSinif}/messages/m2`,
    `${baskaSinif}/messages/m3`,
    `${baskaSinif}/appointments/r1`,
    `${baskaSinif}/status_reports/s1`,
    `${baskaSinif}/announcements/a9/reads/${BASKA_VELI}`,
    `user_blocks/${BASKA_VELI}_${OGRETMEN}`,
    `user_blocks/${OGRETMEN}_${BASKA_VELI}`,
  ]) {
    assert.ok(!db.belgeler.has(y), `${y} kalmamalıydı`);
  }
  // Öğretmenin sınıfı ve duyurusu, öbür velinin okuma işareti kalır.
  assert.ok(db.belgeler.has(baskaSinif));
  assert.ok(db.belgeler.has(`${baskaSinif}/announcements/a9`));
  assert.ok(db.belgeler.has(`${baskaSinif}/announcements/a9/reads/${VELI}`));
});

test('ikinci çağrı hata vermez, silinecek bir şey bulmaz', async () => {
  const db = sahteDb(okul());
  await bulutVerisiniSil(db, OGRETMEN);
  const ikinci = await bulutVerisiniSil(db, OGRETMEN);
  assert.deepEqual(ikinci, { sinif: 0, belge: 0 });
});

test('sınıfın içindekiler tek tek değil sınıfla birlikte silinir', async () => {
  const { siniflar, belgeler } = await silinecekleriTopla(sahteDb(okul()), OGRETMEN);
  assert.equal(siniflar.length, 1);
  assert.ok(belgeler.every((r) => !r.path.startsWith(`class_rooms/cls_${OGRETMEN}_1/`)));
});

test('KRITIK: geçersiz uid ile hiçbir şey sorgulanmaz', async () => {
  for (const uid of ['', 'a', null, undefined, '../x', 'a'.repeat(200)]) {
    await assert.rejects(() => silinecekleriTopla(sahteDb(okul()), uid));
  }
});

test('KRITIK: her koleksiyon grubu sorgusunun dizini firestore.indexes.json\'da', () => {
  const dizin = JSON.parse(readFileSync(new URL('../../firestore.indexes.json', import.meta.url), 'utf8'));
  for (const p of SILME_PLANI.filter((x) => x.kapsam === 'grup')) {
    const o = (dizin.fieldOverrides ?? []).find((f) => f.collectionGroup === p.ad && f.fieldPath === p.alan);
    assert.ok(o, `${p.ad}.${p.alan} için fieldOverride yok`);
    assert.ok(
      o.indexes.some((i) => i.queryScope === 'COLLECTION_GROUP'),
      `${p.ad}.${p.alan} koleksiyon grubu dizini yok`
    );
    // Override, alanın normal (koleksiyon) dizinlerinin yerine geçer;
    // uygulamanın kendi sorguları bozulmasın.
    for (const sira of ['ASCENDING', 'DESCENDING']) {
      assert.ok(
        o.indexes.some((i) => i.queryScope === 'COLLECTION' && i.order === sira),
        `${p.ad}.${p.alan} koleksiyon ${sira} dizini düşmüş`
      );
    }
  }
});

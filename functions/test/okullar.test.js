/**
 * Okullar ve kişiler görünümü — kişisel veri gösteren tek panel yeri.
 *
 * Kimlik çözümü belge yoluna ve sorguya giriyor; yazan işlemler yalnızca
 * süper yöneticide; her görüntüleme denetim kaydına düşüyor.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  cikarmaDogrula,
  dizinKimligi,
  epostaGecerli,
  kayitOzetleri,
  ogretmenOzeti,
  okulKimligiCoz,
  yoneticilikEkle,
} from '../okullar.js';

test('kurum kodu kanonik kimliğe çevriliyor', () => {
  assert.equal(okulKimligiCoz('775214'), 'meb_775214');
  assert.equal(okulKimligiCoz(' 775214 '), 'meb_775214');
  assert.equal(okulKimligiCoz('meb_775214'), 'meb_775214');
  assert.equal(okulKimligiCoz('man_ozel-kolej_1'), 'man_ozel-kolej_1');
});

test('KRITIK: yol kaçışı ve serbest metin reddediliyor', () => {
  for (const kotu of ['12345', 'meb_775214/../x', 'Mimar Sinan', '', null, 'xyz_1', '775214; drop']) {
    assert.equal(okulKimligiCoz(kotu), null, String(kotu));
  }
});

test('dizin kimliği mobil depoyla aynı', () => {
  const dart = readFileSync(
    new URL('../../lib/features/auth_profile/data/repositories/school_directory_repository.dart', import.meta.url),
    'utf8'
  );
  assert.match(dart, /'\$\{schoolId\}_\$teacherUid'/);
  assert.equal(dizinKimligi('meb_1', 'u'), 'meb_1_u');
});

test('öğretmen özeti yalnızca gösterilecek alanlar', () => {
  const o = ogretmenOzeti({
    teacherUid: 'u1', fullName: 'Ayşe', branch: 'Matematik', email: 'a@x.com',
    updatedAt: '2026-09-01', gizliAlan: 'x',
  });
  assert.deepEqual(Object.keys(o).sort(), ['ad', 'brans', 'eposta', 'guncelleme', 'uid']);
});

test('yöneticilik durumu başvurudan ekleniyor; geri alınan ayırt ediliyor', () => {
  const liste = yoneticilikEkle(
    [{ uid: 'u1' }, { uid: 'u2' }, { uid: 'u3' }, { uid: 'u4' }],
    [
      { teacher_uid: 'u1', status: 'approved' },
      { teacher_uid: 'u2', status: 'pending' },
      { teacher_uid: 'u3', status: 'rejected', revoked_at: '2026-09-29' },
    ]
  );
  assert.deepEqual(liste.map((o) => o.yoneticilik), ['approved', 'pending', 'geri_alindi', '']);
});

test('kayıtlar en yeni başta; Firestore zaman damgası da okunuyor', () => {
  const k = kayitOzetleri([
    { tur: 'a', olusturmaZamani: '2026-09-01T00:00:00.000Z' },
    { tur: 'b', olusturmaZamani: { toDate: () => new Date('2026-09-29T00:00:00Z') } },
    { tur: 'c', olusturmaZamani: null },
  ]);
  assert.deepEqual(k.map((x) => x.tur), ['b', 'a', 'c']);
});

test('dizinden çıkarma: gerekçe zorunlu, kimlikler doğrulanıyor', () => {
  assert.equal(cikarmaDogrula({ okulId: '775214', uid: 'u1', gerekce: 'Okuldan ayrıldı' }).ok, true);
  assert.equal(cikarmaDogrula({ okulId: '775214', uid: 'u1', gerekce: ' ' }).ok, false);
  assert.equal(cikarmaDogrula({ okulId: '775214', uid: 'a/b', gerekce: 'x' }).ok, false);
  assert.equal(cikarmaDogrula({ okulId: 'Mimar', uid: 'u1', gerekce: 'x' }).ok, false);
  assert.equal(cikarmaDogrula(undefined).ok, false);
});

test('e-posta kaba denetimi', () => {
  assert.ok(epostaGecerli('ayse@meb.k12.tr'));
  for (const kotu of ['', 'ayse', 'a b@x.com', '@x.com', null]) {
    assert.equal(epostaGecerli(kotu), false, String(kotu));
  }
});

// --- Bağlantı ---

const kaynak = readFileSync(new URL('../index.js', import.meta.url), 'utf8');
const govde = (ad) => {
  const bas = kaynak.indexOf(`export const ${ad}`);
  const son = kaynak.indexOf('export const ', bas + 10);
  return kaynak.slice(bas, son < 0 ? undefined : son);
};

test('KRITIK: dizinden çıkarmayı yalnızca süper yönetici yapıyor', () => {
  const g = govde('removeFromSchoolDirectory');
  assert.ok(g.includes('yetkiKontrol(request.auth)'));
  assert.ok(!g.includes('okumaYetkisi'));
  assert.ok(g.indexOf('cikarmaDogrula(') < g.indexOf('.delete()'));
});

test('KRITIK: kişisel veri gösteren her görünüm görüntüleme kaydı bırakıyor', () => {
  assert.ok(govde('schoolOverview').includes("goruntulemeKaydet(request, 'okul_goruntuleme'"));
  const kisi = govde('findPerson');
  // Kişi bulunsa da bulunmasa da.
  assert.equal((kisi.match(/goruntulemeKaydet\(request, 'kisi_goruntuleme'/g) || []).length, 2);
});

test('görünümler yazmıyor (görüntüleme kaydı dışında)', () => {
  for (const ad of ['schoolOverview', 'findPerson']) {
    const g = govde(ad);
    assert.ok(g.includes('okumaYetkisi(request.auth)'), ad);
    assert.ok(!/\.(update|set|delete)\(/.test(g), `${ad} yazıyor`);
  }
});

test('görüntüleme kaydı okul geçmişine karışmıyor', () => {
  // Okul geçmişi `okulId` alanıyla sorgulanıyor; görüntüleme kaydı o
  // alanı taşısaydı her bakış geçmişi doldururdu.
  const bas = kaynak.indexOf('async function goruntulemeKaydet');
  const g = kaynak.slice(bas, kaynak.indexOf('\n}\n', bas));
  assert.ok(!g.includes('okulId'));
  assert.ok(govde('schoolOverview').includes(".where('okulId', '==', okulId)"));
});

/**
 * Bildirimler sekmesi (18 Ekim 2026): uygulamadan bildirilen içerikler ve
 * destek talepleri yöneticinin önüne düşmeli (Google Play kullanıcı
 * içeriği kuralı). Bildirilen metin kullanıcı içeriği: panelde HTML
 * olarak çalışmamalı.
 *
 * Tarayıcı betiği `vm` içinde, en küçük `window`/`document` taklidiyle
 * çalıştırılıyor.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const kaynak = readFileSync(new URL('../../admin_portal/js/bildirimler.js', import.meta.url), 'utf8');

/** `admin_app.js`'teki kaçış yardımcılarının aynısı (DOM'suz). */
function kacisliMetin(x) {
  return String(x ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
function kacisliOznitelik(x) {
  return String(x ?? '')
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function panelKur(talepler) {
  const ogeler = {
    'bildirim-tablo': { innerHTML: '' },
    'bildirim-bilgi': { textContent: '' },
    'bildirim-suzgec': { value: 'acik' },
  };
  function AdminApp() {}
  AdminApp.prototype.kacisliMetin = kacisliMetin;
  AdminApp.prototype.kacisliOznitelik = kacisliOznitelik;
  AdminApp.prototype.yayinHatasi = (e) => String(e?.message ?? e);
  const kapatilan = [];
  const window = {
    AdminApp,
    SinifCepteAdminAuth: {
      listSupportRequests: async () => talepler,
      resolveSupportRequest: async (id, not) => kapatilan.push({ id, not }),
    },
    prompt: () => 'Hesap kapatıldı',
  };
  vm.runInNewContext(kaynak, { window, document: { getElementById: (id) => ogeler[id] ?? null } });
  const app = new AdminApp();
  app.showToast = () => {};
  return { app, ogeler, kapatilan, window };
}

const TALEPLER = [
  {
    id: 'sup_1',
    category: 'content_report',
    status: 'open',
    userId: 'ogretmenUid',
    userRole: 'teacher',
    reportedUid: 'veliUid',
    reportedName: 'Ayşe Veli',
    reason: 'hakaret',
    excerpt: '<img src=x onerror=alert(1)> hakaret',
    message: 'Ek not yok.',
    contentType: 'message',
    contentId: 'msg_1',
    classCloudId: 'cls_o_1',
    createdAt: '2026-10-18T10:00:00.000',
  },
  {
    id: 'sup_2',
    category: 'bug_report',
    status: 'open',
    userId: 'veliUid',
    userRole: 'parent',
    subject: 'Uygulama kapanıyor',
    message: 'Açılışta kapanıyor.',
    createdAt: '2026-10-17T10:00:00.000',
  },
  {
    id: 'sup_3"><b>',
    category: 'content_report',
    status: 'resolved',
    adminNote: 'İhlal yok',
    resolvedAt: '2026-10-18T12:00:00.000',
    userId: 'veliUid',
    userRole: 'parent',
    reportedUid: 'ogretmenUid',
    reportedName: 'Ahmet Öğretmen',
    reason: 'uygunsuz',
    excerpt: 'Cuma müzeye gidiyoruz.',
    contentTitle: 'Gezi',
    message: 'Ek not yok.',
    contentType: 'announcement',
    contentId: 'a1',
    classCloudId: 'cls_o_1',
    createdAt: '2026-10-16T10:00:00.000',
  },
];

test('KRITIK: bildirilen metin HTML olarak çalışmıyor', async () => {
  const { app, ogeler } = panelKur(TALEPLER);
  await app.bildirimleriYukle();
  const html = ogeler['bildirim-tablo'].innerHTML;
  assert.ok(!html.includes('<img'), 'kaçışsız kullanıcı içeriği');
  assert.ok(html.includes('&lt;img src=x onerror=alert(1)&gt; hakaret'));
  assert.ok(html.includes('class_rooms/cls_o_1/messages/msg_1'), 'içerik yolu gösterilmeli');
  assert.ok(html.includes('Hakaret veya taciz'));
});

test('süzgeç: açık olanlar, açık içerik bildirimleri, hepsi', async () => {
  const { app, ogeler } = panelKur(TALEPLER);
  await app.bildirimleriYukle();
  const satirlar = () => (ogeler['bildirim-tablo'].innerHTML.match(/<tr>/g) || []).length;
  assert.equal(satirlar(), 2, 'açık olanlar varsayılan');
  app.bildirimTablosuCiz('icerik');
  assert.equal(satirlar(), 1);
  app.bildirimTablosuCiz('hepsi');
  assert.equal(satirlar(), 3);
  assert.match(ogeler['bildirim-bilgi'].textContent, /3 kayıt \(2 içerik bildirimi\)/);
});

test('kapatılan kayıt notuyla görünüyor; kimlik öznitelikte kaçışlı', async () => {
  const { app, ogeler } = panelKur(TALEPLER);
  await app.bildirimleriYukle();
  app.bildirimTablosuCiz('hepsi');
  const html = ogeler['bildirim-tablo'].innerHTML;
  assert.ok(html.includes('Kapatıldı'));
  assert.ok(html.includes('İhlal yok'));
  assert.ok(html.includes('class_rooms/cls_o_1/announcements/a1'));
  assert.ok(!html.includes('sup_3"><b>'), 'kimlik özniteliği kırmamalı');
});

test('Kapat: not sorulur, kayıt kapatılır, liste tazelenir', async () => {
  const { app, kapatilan } = panelKur(TALEPLER);
  await app.bildirimleriYukle();
  await app.bildirimiKapat('sup_1');
  assert.deepEqual(kapatilan, [{ id: 'sup_1', not: 'Hesap kapatıldı' }]);
});

test('Kapat: vazgeçilirse hiçbir şey yazılmaz', async () => {
  const { app, kapatilan, window } = panelKur(TALEPLER);
  window.prompt = () => null;
  await app.bildirimiKapat('sup_1');
  assert.deepEqual(kapatilan, []);
});

test('panel okuma ve kapatma doğrudan Firestore, kural yalnız yöneticiye açık', () => {
  const kapi = readFileSync(new URL('../../admin_portal/js/auth_gate.js', import.meta.url), 'utf8');
  assert.match(kapi, /collection\(db, 'support_requests'\), orderBy\('createdAt', 'desc'\), limit\(200\)/);
  assert.match(kapi, /status: 'resolved'/);
  const kural = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
  const blok = kural.slice(kural.indexOf('match /support_requests/{requestId}'));
  assert.match(blok, /allow update: if isAdmin\(\);/);
});

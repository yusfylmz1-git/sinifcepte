/**
 * SınıfCepte Admin Paneli - MEB duyurusundan sınav ayıklayıcı testleri
 *
 *   node admin_portal/js/test_exam_parser.js
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ok   ${name}`);
    passed += 1;
  } catch (error) {
    console.log(`  FAIL ${name}\n       ${error.message}`);
    failed += 1;
  }
}

global.window = {};
// eslint-disable-next-line no-eval
eval(fs.readFileSync(path.join(__dirname, 'exam_text_parser.js'), 'utf8'));
const P = window.ExamTextParser;

// ÖDSGM "2026-2027 Eğitim Öğretim Yılı Ülke Geneli Ortak Yazılı Sınav
// Takvimi" PDF'inden kopyalanan metin (odsgm.meb.gov.tr, Eylül 2026).
const ODSGM_2026 = `2026-2027 Eğitim Öğretim Yılı Ülke Geneli Ortak Yazılı Sınav Takvimi
1. Dönem 1. Yazılı Sınavları
Sınıf Ders Adı Sınav Tarihi
6. Sınıf Matematik 11 Kasım 2026 Çarşamba
10. Sınıf Türk Dili ve Edebiyatı 12 Kasım 2026 Perşembe
1. Dönem 2. Yazılı Sınavları
Sınıf Ders Adı Sınav Tarihi
7. Sınıf Türkçe 5 Ocak 2027 Salı
9. Sınıf Matematik 6 Ocak 2027 Çarşamba
2. Dönem 1. Yazılı Sınavları
Sınıf Ders Adı Sınav Tarihi
7. Sınıf Matematik 6 Nisan 2027 Salı
9. Sınıf Türk Dili ve Edebiyatı 7 Nisan 2027 Çarşamba
2. Dönem 2. Yazılı Sınavları
Sınıf Ders Adı Sınav Tarihi
6. Sınıf Türkçe 8 Haziran 2027 Salı
10. Sınıf Matematik 9 Haziran 2027 Çarşamba`;

console.log('ÖDSGM ortak yazılı tablosu');

test('KRITIK: resmî tablodaki 8 sınavın hepsi tanınıyor', () => {
  const r = P.ayristir(ODSGM_2026);
  assert.strictEqual(r.sinavlar.length, 8, JSON.stringify(r, null, 1));
  assert.deepStrictEqual(r.taninmayan, []);
});

test('her satır sınıf ve dersiyle ayrı kayıt, tarih doğru', () => {
  const r = P.ayristir(ODSGM_2026);
  const satirlar = r.sinavlar.map((s) => `${s.title} | ${s.examDate.slice(0, 10)}`);
  assert.deepStrictEqual(satirlar, [
    '6. Sınıf Matematik Ortak Yazılısı | 2026-11-11',
    '10. Sınıf Türk Dili ve Edebiyatı Ortak Yazılısı | 2026-11-12',
    '7. Sınıf Türkçe Ortak Yazılısı | 2027-01-05',
    '9. Sınıf Matematik Ortak Yazılısı | 2027-01-06',
    '7. Sınıf Matematik Ortak Yazılısı | 2027-04-06',
    '9. Sınıf Türk Dili ve Edebiyatı Ortak Yazılısı | 2027-04-07',
    '6. Sınıf Türkçe Ortak Yazılısı | 2027-06-08',
    '10. Sınıf Matematik Ortak Yazılısı | 2027-06-09',
  ]);
});

test('KRITIK: saat duyurulmadıysa 00:00, uydurma 09:00 yok', () => {
  const r = P.ayristir(ODSGM_2026);
  for (const s of r.sinavlar) {
    assert.ok(s.examDate.endsWith('T00:00:00.000'), s.examDate);
  }
});

test('kimlik ASCII ve kararlı, dönem açıklamada', () => {
  const s = P.ayristir(ODSGM_2026).sinavlar[1];
  assert.strictEqual(s.doc_id, 'meb_ortak_10_turk_dili_ve_edebiyati_20261112');
  assert.strictEqual(s.institution, 'MEB');
  assert.strictEqual(s.description, 'Ülke geneli ortak yazılı sınavı (1. Dönem 1. Yazılı).');
  assert.strictEqual(P.ayristir(ODSGM_2026).sinavlar[1].doc_id, s.doc_id);
});

test('açıkça yazılmış saat alınıyor, noktalı tarih saat sanılmıyor', () => {
  const r = P.ayristir(
    'Ortak Yazılı Sınav Takvimi\n1. Dönem 1. Yazılı\n6. Sınıf Matematik 11.11.2026 saat 10.30'
  );
  assert.strictEqual(r.sinavlar[0].examDate, '2026-11-11T10:30:00.000');
  const r2 = P.ayristir('Ortak Yazılı Sınav Takvimi\n1. Dönem 1. Yazılı\n6. Sınıf Matematik 11.11.2026');
  assert.strictEqual(r2.sinavlar[0].examDate, '2026-11-11T00:00:00.000');
});

test('ortak yazılı belgesinde tanınmayan tarihli satır sessizce atılmıyor', () => {
  const r = P.ayristir('Ortak Yazılı Sınav Takvimi\n1. Dönem 1. Yazılı\nMazeret: 20 Kasım 2026 Cuma');
  assert.strictEqual(r.sinavlar.length, 0);
  assert.strictEqual(r.taninmayan.length, 1);
});

console.log('Eski duyuru biçimi');

test('tek satırlık ortak yazılı duyurusu eskisi gibi tanınıyor', () => {
  const r = P.ayristir('1. Dönem 1. Ortak Yazılı Sınavları 12 Kasım 2026 tarihinde yapılacaktır.');
  assert.strictEqual(r.sinavlar.length, 1);
  assert.strictEqual(r.sinavlar[0].title, '1. Dönem 1. Ortak Yazılı Sınavları');
});

test('ortak yazılı olmayan duyuruda "8. Sınıf" satırı tablo sanılmıyor', () => {
  const r = P.ayristir('Bursluluk sınavı 2. dönem\n8. Sınıf öğrencileri 25 Nisan 2027 Pazar');
  assert.ok(!r.sinavlar.some((s) => s.doc_id.startsWith('meb_ortak_8')), JSON.stringify(r));
});

test('LGS duyurusu eskisi gibi', () => {
  const r = P.ayristir('LGS merkezi sınavı 13 Haziran 2027 Pazar günü saat 09.30\'da yapılacak.');
  assert.strictEqual(r.sinavlar.length, 1);
  assert.strictEqual(r.sinavlar[0].examDate, '2027-06-13T09:30:00.000');
});

console.log(`\n${passed} geçti, ${failed} kaldı`);
process.exit(failed > 0 ? 1 : 0);

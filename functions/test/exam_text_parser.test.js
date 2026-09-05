/**
 * MEB duyuru metni ayıklayıcısının testleri.
 *
 * ## Neden bu testler var
 * Ayrıştırma MEB'in yazım biçimine bağlı ve o biçim her yıl değişiyor.
 * Sessizce bozulursa yönetici yanlış LGS tarihi yayınlayabilir.
 *
 * Ayrıştırıcı tarayıcı dosyası (`window.ExamTextParser`); burada
 * kaynağı okuyup Node'da değerlendiriyoruz. Panel derlenmediği için
 * başka yolu yok.
 *
 * Çalıştırma: cd functions && npm test
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

/** Tarayıcı sınıfını Node ortamında yükler. */
function ayikayiciYukle() {
  const kod = readFileSync(
    new URL('../../admin_portal/js/exam_text_parser.js', import.meta.url),
    'utf8'
  ).replace('window.ExamTextParser = ExamTextParser;', '');
  // eslint-disable-next-line no-eval
  return eval(`(function(){ ${kod}; return ExamTextParser; })()`);
}

const P = ayikayiciYukle();

/** MEB duyurularının gerçek yazım biçimi. */
const DUYURU = `
2026-2027 EĞİTİM ÖĞRETİM YILI ORTAK SINAV TARİHLERİ

1. Dönem 1. Ortak Yazılı Sınavları 12-13 Kasım 2026 tarihlerinde yapılacaktır.
1. Dönem 2. Ortak Yazılı Sınavları 24-25 Aralık 2026 tarihlerinde yapılacaktır.
2. Dönem 1. Ortak Yazılı Sınavları 18-19 Mart 2027 tarihinde gerçekleştirilecektir.
2. Dönem 2. Ortak Yazılı Sınavları 13-14 Mayıs 2027 tarihinde yapılacaktır.
LGS merkezi sınavı 13 Haziran 2027 Pazar günü saat 09.30'da yapılacaktır.
İOKBS bursluluk sınavı 25 Nisan 2027 tarihinde uygulanacaktır.
BİLSEM tanılama süreci 20 Şubat 2027 tarihinde başlayacaktır.
Öğretmenler kurulu toplantısı 5 Eylül 2026 tarihinde yapılacaktır.
`;

test('KRITIK: ortak yazililar SIRA NUMARASIYLA ayirt ediliyor', () => {
  // YAŞANDI: satırlar noktalardan bölününce "1. Dönem 1." kısmı
  // kopuyor, hangi sınav olduğu anlaşılmıyordu — dört ortak yazılının
  // hiçbiri tanınmadı. Türkçede sıra sayıları noktayla yazılıyor.
  const r = P.ayristir(DUYURU);
  const baslıklar = r.sinavlar.map((s) => s.title);

  assert.ok(baslıklar.includes('1. Dönem 1. Ortak Yazılı Sınavları'));
  assert.ok(baslıklar.includes('1. Dönem 2. Ortak Yazılı Sınavları'));
  assert.ok(baslıklar.includes('2. Dönem 1. Ortak Yazılı Sınavları'));
  assert.ok(baslıklar.includes('2. Dönem 2. Ortak Yazılı Sınavları'));
});

test('KRITIK: yaziyla ay adi tarihe cevriliyor', () => {
  const r = P.ayristir(DUYURU);
  const lgs = r.sinavlar.find((s) => s.title.startsWith('LGS'));
  assert.ok(lgs, 'LGS bulunamadı');
  assert.equal(lgs.examDate, '2027-06-13T09:30:00.000');
});

test('KRITIK: saat metinden okunuyor, yoksa 09:00', () => {
  const r = P.ayristir(DUYURU);
  const lgs = r.sinavlar.find((s) => s.title.startsWith('LGS'));
  const iokbs = r.sinavlar.find((s) => s.title.startsWith('İOKBS'));

  assert.match(lgs.examDate, /T09:30/, 'metindeki saat alınmadı');
  assert.match(iokbs.examDate, /T09:00/, 'varsayılan saat yanlış');
});

test('KRITIK: aralikli tarihte ILK gun aliniyor', () => {
  // "12-13 Kasım 2026" iki günlük sınav; takvimde ilk gün gösterilir.
  const r = P.ayristir(DUYURU);
  const ilk = r.sinavlar.find((s) => s.title === '1. Dönem 1. Ortak Yazılı Sınavları');
  assert.match(ilk.examDate, /^2026-11-12/);
});

test('sinav olmayan satir atlaniyor', () => {
  const r = P.ayristir(DUYURU);
  assert.ok(
    !r.sinavlar.some((s) => /kurul/i.test(s.title)),
    'öğretmenler kurulu sınav sanıldı'
  );
});

test('noktali tarih bicimi de taniniyor', () => {
  const r = P.ayristir('LGS merkezi sınavı 13.06.2027 tarihinde yapılacaktır.');
  assert.equal(r.sinavlar.length, 1);
  assert.match(r.sinavlar[0].examDate, /^2027-06-13/);
});

test('KRITIK: Turkce buyuk I harfi eslesmeyi bozmuyor', () => {
  // toLowerCase() "İ" harfini bozuyor; ayıklayıcı harfleri elle eşliyor.
  const r = P.ayristir('İOKBS BURSLULUK SINAVI 25 NİSAN 2027 TARİHİNDE.');
  assert.equal(r.sinavlar.length, 1, 'büyük harfli metin tanınmadı');
});

test('taninmayan satirlar sessizce atilmiyor', () => {
  // Tarihi olan ama eşleşmeyen satır yöneticiye gösterilmeli.
  const r = P.ayristir('Şube öğretmenler kurulu sınavı 3 Mart 2027 tarihinde.');
  assert.ok(
    r.sinavlar.length === 0 && r.taninmayan.length === 1,
    'tanınmayan satır bildirilmedi'
  );
});

test('ayni sinav iki kez gecerse tek kayit', () => {
  const tekrar = `
LGS merkezi sınavı 13 Haziran 2027 tarihinde yapılacaktır.
LGS sınavı ile ilgili duyuru 13 Haziran 2027 tarihlidir.
`;
  const r = P.ayristir(tekrar);
  assert.equal(r.sinavlar.length, 1);
});

test('bos girdi cokmeye yol acmiyor', () => {
  for (const x of ['', '   ', null, undefined]) {
    const r = P.ayristir(x);
    assert.equal(r.sinavlar.length, 0);
    assert.equal(r.taninmayan.length, 0);
  }
});

test('tarihsiz metinden sinav uretilmiyor', () => {
  const r = P.ayristir('LGS sınavı ile ilgili duyuru yakında yapılacaktır.');
  assert.equal(r.sinavlar.length, 0, 'tarihsiz satırdan sınav uydurdu');
});

/**
 * ÖSYM ayrıştırıcısının testleri.
 *
 * ## Neden bu testler var
 * Ayrıştırma dış bir sitenin HTML yapısına bağlı. ÖSYM sayfayı
 * değiştirirse kod sessizce yanlış veri üretebilir — ve o veri 30.000
 * öğretmene gider. Bu testler iki şeyi güvenceye alıyor:
 *
 * 1. Bilinen yapı doğru ayrıştırılıyor
 * 2. Yapı bozulduğunda SESSİZ KALMIYOR, açık hata veriyor
 *
 * Çalıştırma: cd functions && npm test
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ayristir, karsilastir } from '../osym_parser.js';

/**
 * ÖSYM'nin gerçek sayfa yapısı.
 *
 * Türkçe karakterler SAYISAL VARLIK olarak yazılı — sayfa gerçekten
 * böyle geliyor ve bu bir kez ayrıştırmayı tamamen kırmıştı.
 */
const GERCEK_YAPI = `
<html><body>
<table>
  <tr><th>S&#x131;nav Ad&#x131;</th><th>&#xD6;n Ba&#x15F;vuru Tarihi</th>
      <th>Ba&#x15F;vuru Tarihi</th><th>S&#x131;nav Tarihi</th></tr>
  <tr><td>EKPSS</td><td>-</td><td>07.01.2026</td><td>19.04.2026</td></tr>
</table>
<table>
  <tr><th>S&#x131;nav Ad&#x131;</th><th>S&#x131;nav Tarihi</th>
      <th>Ba&#x15F;vuru Tarihi</th><th>Ge&#xE7; Ba&#x15F;vuru</th></tr>
  <tr><td>MS&#xDC; Mill&#xEE; Savunma &#xDC;niversitesi</td>
      <td>01.03.2026 10:15</td>
      <td>05.01.2026 10:30 29.01.2026 23:59</td><td>03.02.2026</td></tr>
  <tr><td>YKS Y&#xFC;ksek&#xF6;&#x11F;retim Kurumlar&#x131; S&#x131;nav&#x131;</td>
      <td>20.06.2026</td><td>10.02.2026 05.03.2026</td><td>-</td></tr>
  <tr><td>Tarihsiz S&#x131;nav</td><td>-</td><td>-</td><td>-</td></tr>
</table>
</body></html>`;

test('KRITIK: sayisal varlikli Turkce karakterler cozuluyor', () => {
  // YAŞANDI: sayfa "Sınav Adı"yı `S&#x131;nav Ad&#x131;` diye
  // gönderiyor. Varlıklar çözülmeyince başlık eşleşmiyor ve doğru
  // tablo hiç bulunamıyordu.
  const r = ayristir(GERCEK_YAPI);
  assert.equal(r.ok, true, r.mesaj);
  assert.match(r.sinavlar[0].title, /MSÜ/, 'Türkçe karakter bozuk');
  assert.match(r.sinavlar[1].title, /Yükseköğretim/);
});

test('KRITIK: dogru tablo secildi (basvuru tablosu degil)', () => {
  // YAŞANDI: iki tabloda da "Sınav Tarihi" sütunu var. Yalnızca
  // sütun adına bakınca BAŞVURU tablosu seçiliyordu.
  // Ayırt edici: aranan tabloda sınav tarihi İKİNCİ sütun.
  const r = ayristir(GERCEK_YAPI);
  assert.equal(r.ok, true);
  assert.equal(r.sinavlar.length, 2, 'yanlış tablo seçilmiş olabilir');
  // Başvuru tablosundaki EKPSS gelmemeli.
  assert.ok(
    !r.sinavlar.some((s) => s.title.includes('EKPSS')),
    'başvuru tablosundan satır sızdı'
  );
});

test('KRITIK: tarih ve saat dogru cevriliyor', () => {
  const r = ayristir(GERCEK_YAPI);
  assert.equal(r.sinavlar[0].examDate, '2026-03-01T10:15:00.000');
  // Saat yoksa 09:00 varsayılır.
  assert.equal(r.sinavlar[1].examDate, '2026-06-20T09:00:00.000');
});

test('son basvuru tarihi hucredeki SON tarihten aliniyor', () => {
  // "05.01.2026 10:30 29.01.2026 23:59" → son gün 29.01
  const r = ayristir(GERCEK_YAPI);
  assert.match(r.sinavlar[0].applicationDeadline, /^2026-01-29/);
});

test('tarihsiz satir atlaniyor, sayaci tutuluyor', () => {
  const r = ayristir(GERCEK_YAPI);
  assert.equal(r.atlanan, 1);
});

test('KRITIK: sayfa yapisi bozulunca SESSIZ KALMIYOR', () => {
  // En tehlikeli senaryo: ÖSYM sayfayı değiştirir, kod boş veri
  // üretir, yönetici farkında olmadan yayınlar.
  const bozuk = `<html><body><div>Takvim yakında</div></body></html>`.repeat(60);
  const r = ayristir(bozuk);
  assert.equal(r.ok, false);
  assert.match(r.mesaj, /elle kontrol/, 'uyarı yönlendirici değil');
});

test('bos veya kisa sayfa reddediliyor', () => {
  assert.equal(ayristir('').ok, false);
  assert.equal(ayristir(null).ok, false);
  assert.equal(ayristir('<html></html>').ok, false);
});

test('gecersiz tarih ayristirilmiyor', () => {
  const gecersiz = GERCEK_YAPI.replace('01.03.2026 10:15', '32.13.2026');
  const r = ayristir(gecersiz);
  assert.equal(r.ok, true);
  // Geçersiz tarihli satır atlanmalı, uydurulmamalı.
  assert.ok(
    !r.sinavlar.some((s) => s.title.includes('MSÜ')),
    'geçersiz tarih kabul edildi'
  );
});

// --------------------------------------------------------- karşılaştırma

test('KRITIK: degisen tarih yakalaniyor', () => {
  const mevcut = [
    { doc_id: 'osym_yks_20260620', title: 'YKS', examDate: '2026-06-20T09:00:00.000' },
  ];
  const gelen = [
    { doc_id: 'osym_yks_20260620', title: 'YKS', examDate: '2026-06-27T09:00:00.000' },
  ];
  const f = karsilastir(mevcut, gelen);
  assert.equal(f.degisen.length, 1);
  assert.equal(f.degisen[0].eski.examDate, '2026-06-20T09:00:00.000');
  assert.equal(f.degisen[0].yeni.examDate, '2026-06-27T09:00:00.000');
});

test('yeni sinav ayirt ediliyor', () => {
  const f = karsilastir([], [{ doc_id: 'a', examDate: '2026-01-01T09:00:00.000' }]);
  assert.equal(f.yeni.length, 1);
  assert.equal(f.degisen.length, 0);
});

test('degismeyen sinav "ayni" sayiliyor', () => {
  const s = { doc_id: 'a', examDate: '2026-01-01T09:00:00.000' };
  const f = karsilastir([s], [s]);
  assert.equal(f.ayni.length, 1);
  assert.equal(f.yeni.length, 0);
  assert.equal(f.degisen.length, 0);
});

test('bos mevcut liste cokmeye yol acmiyor', () => {
  assert.doesNotThrow(() => karsilastir(null, []));
  assert.doesNotThrow(() => karsilastir(undefined, [{ doc_id: 'a' }]));
});

// ---------------------------------------------------- öğretmen süzgeci

/** Öğretmenle ilgili ve ilgisiz sınavları birlikte taşıyan sayfa. */
const KARISIK = `
<table>
  <tr><th>S&#x131;nav Ad&#x131;</th><th>S&#x131;nav Tarihi</th><th>Ba&#x15F;vuru</th></tr>
  <tr><td>TUS T&#x131;pta Uzmanl&#x131;k E&#x11F;itimi Giri&#x15F; S&#x131;nav&#x131; 2026-TUS</td>
      <td>15.03.2026</td><td>-</td></tr>
  <tr><td>HMGS Hukuk Mesleklerine Giri&#x15F; S&#x131;nav&#x131; 2026-HMGS/1</td>
      <td>26.04.2026</td><td>-</td></tr>
  <tr><td>YKS Y&#xFC;ksek&#xF6;&#x11F;retim Kurumlar&#x131; S&#x131;nav&#x131; 2026-YKS 1. Oturum (TYT)</td>
      <td>20.06.2026</td><td>-</td></tr>
  <tr><td>MEB-AGS Mill&#xEE; E&#x11F;itim Bakanl&#x131;&#x11F;&#x131; Akademi Giri&#x15F; S&#x131;nav&#x131; 2026-MEB-AGS</td>
      <td>26.07.2026</td><td>-</td></tr>
</table>`;

test('KRITIK: ogretmeni ilgilendirmeyen sinavlar eleniyor', () => {
  // ÖSYM takviminde 67 sınav var; çoğu tıp/hukuk/tarım uzmanlık
  // sınavı. Hepsi listelenince öğretmen kendi sınavını bulamıyordu.
  const r = ayristir(KARISIK);
  assert.equal(r.ok, true, r.mesaj);
  assert.equal(r.sinavlar.length, 2, 'süzgeç çalışmıyor');
  assert.equal(r.elenen, 2);
  assert.ok(!r.sinavlar.some((s) => /TUS|HMGS/.test(s.title)));
});

test('KRITIK: sinav adi kisaltiliyor', () => {
  // "MEB-AGS Millî Eğitim Bakanlığı Akademi Giriş Sınavı 2026-MEB-AGS"
  // telefon ekranına sığmıyordu.
  const r = ayristir(KARISIK);
  const ags = r.sinavlar.find((s) => s.title.startsWith('AGS'));
  assert.ok(ags, 'AGS bulunamadı');
  assert.ok(ags.title.length < 40, `ad hâlâ uzun: ${ags.title}`);
  assert.ok(!ags.title.includes('2026-'), 'yıl-kod tekrarı kalmış');
});

test('oturum bilgisi korunuyor', () => {
  // Aynı gün birden çok oturum olabiliyor; ayırt edilmeli.
  const r = ayristir(KARISIK);
  const yks = r.sinavlar.find((s) => s.title.startsWith('YKS'));
  assert.match(yks.title, /1\. Oturum/);
});

test('KRITIK: aciklama TEK CUMLE', () => {
  const r = ayristir(KARISIK);
  for (const s of r.sinavlar) {
    const nokta = (s.description.match(/\./g) || []).length;
    assert.ok(
      nokta <= 1,
      `açıklama birden çok cümle: "${s.description}"`
    );
    assert.ok(
      s.description.length < 70,
      `açıklama çok uzun: "${s.description}"`
    );
  }
});

test('tumu elenirse aciklayici mesaj veriliyor', () => {
  const sadeceIlgisiz = KARISIK.replace(/YKS[\s\S]*?<\/tr>/, '')
    .replace(/MEB-AGS[\s\S]*?<\/tr>/, '');
  const r = ayristir(sadeceIlgisiz);
  assert.equal(r.ok, false);
  assert.match(r.mesaj, /ilgilendirmiyor/);
});

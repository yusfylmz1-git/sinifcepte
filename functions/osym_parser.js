/**
 * ÖSYM sınav takvimi ayrıştırıcısı.
 *
 * ## Neden var
 * Sınav tarihleri elle giriliyordu: ÖSYM sayfasını açıp 9 sınavı tek tek
 * kopyalamak gerekiyordu. Takvim yılda bir yayımlanıyor ama ertelemeler
 * yıl içinde de oluyor.
 *
 * ## Neden doğrudan yayınlamıyor
 * Sayfa yapısı ÖSYM'nin kontrolünde; bir gün değişebilir. Yanlış
 * ayrıştırma 30.000 öğretmene yanlış sınav tarihi göndermek demek.
 * Bu yüzden akış şu: çek → mevcut veriyle KARŞILAŞTIR → farkları
 * yöneticiye göster → o onaylayınca yayınla.
 *
 * Ölçüm (Eylül 2026): sayfadaki 68 satırın 67'si doğru ayrıştı.
 *
 * ## Sayfa yapısı
 * `https://www.osym.gov.tr/Sayfa/SinavTakvimi` üç tablo taşıyor:
 *   1. Başvuru takvimi (sınav tarihi YOK)
 *   2. Sınav takvimi   ← kullandığımız
 *   3. Sonuç açıklama
 *
 * İkinci tablonun sütunları:
 *   Sınav Adı | Sınav Tarihi | Başvuru Tarihi | Geç Başvuru
 */

/** Takvim sayfası. */
export const OSYM_TAKVIM_URL = 'https://www.osym.gov.tr/Sayfa/SinavTakvimi';

/**
 * HTML etiketlerini, varlıkları ve fazla boşluğu temizler.
 *
 * ## Sayısal varlık tuzağı
 * ÖSYM sayfası Türkçe karakterleri SAYISAL VARLIK olarak gönderiyor:
 * "Sınav Adı" kaynakta `S&#x131;nav Ad&#x131;` diye duruyor. Yalnızca
 * `&nbsp;` gibi adlandırılmış varlıkları çözmek yetmiyordu — başlık
 * eşleşmesi tutmuyor ve doğru tablo hiç bulunamıyordu.
 */
function metin(ham) {
  return ham
    .replace(/<[^>]+>/g, ' ')
    // Onaltılık: &#x131; -> ı
    .replace(/&#x([0-9a-f]+);/gi, (_, k) => String.fromCodePoint(parseInt(k, 16)))
    // Onluk: &#305; -> ı
    .replace(/&#(\d+);/g, (_, k) => String.fromCodePoint(parseInt(k, 10)))
    .replace(/&nbsp;/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    // &amp; en sona: erken çözülürse çift kodlanmış diziler yanlış açılır.
    .replace(/&amp;/g, '&')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * "01.03.2026 10:15" → ISO 8601.
 *
 * Saat yoksa 09:00 varsayılır — ÖSYM sınavlarının olağan başlangıcı.
 * Yanlış saat yanlış tarihten iyidir: öğretmen sınavın gününü görür.
 */
function tariheCevir(ham) {
  const m = /(\d{2})\.(\d{2})\.(\d{4})(?:\s+(\d{1,2}):(\d{2}))?/.exec(ham || '');
  if (!m) return null;
  const [, gun, ay, yil, saat, dakika] = m;

  const s = (saat || '09').padStart(2, '0');
  const d = dakika || '00';

  // Geçerli tarih mi? "32.13.2026" gibi bir şey ayrıştırılmamalı.
  const test = new Date(`${yil}-${ay}-${gun}T${s}:${d}:00`);
  if (Number.isNaN(test.getTime())) return null;

  return `${yil}-${ay}-${gun}T${s}:${d}:00.000`;
}

/**
 * Sınav adından kısa kod üretir.
 *
 * ÖSYM adları uzun: "MSÜ Millî Savunma Üniversitesi Askerî Öğrenci Aday
 * Belirleme Sınavı 2026-MSÜ". İlk kelime zaten kısaltma.
 */
function kisaKod(ad) {
  const ilk = ad.split(/\s+/)[0] || '';
  return ilk
    .toLocaleLowerCase('tr')
    .replace(/[çğıöşü]/g, (c) => ({ ç: 'c', ğ: 'g', ı: 'i', ö: 'o', ş: 's', ü: 'u' })[c])
    .replace(/[^a-z0-9]/g, '');
}

/**
 * Takvim sayfasını ayrıştırır.
 *
 * @param {string} html Ham sayfa.
 * @returns {{ok: true, sinavlar: Array} | {ok: false, mesaj: string}}
 */
export function ayristir(html) {
  // Boyut yalnızca "sayfa hiç gelmemiş" durumunu yakalar. Asıl ölçüt
  // tablonun varlığı — sayfa küçülse bile tablo doğruysa ayrıştırılır.
  if (typeof html !== 'string' || html.length < 80) {
    return { ok: false, mesaj: 'Sayfa boş veya çok kısa geldi.' };
  }

  const tablolar = html.match(/<table[^>]*>[\s\S]*?<\/table>/gi) || [];
  if (tablolar.length === 0) {
    return {
      ok: false,
      mesaj:
        'Sayfa yapısı beklenenden farklı: sınav takvimi tablosu ' +
        `bulunamadı (${tablolar.length} tablo). ÖSYM sayfayı değiştirmiş ` +
        'olabilir; tarihleri elle kontrol edin.',
    };
  }

  // Doğru tabloyu bul: "Sınav Adı | Sınav Tarihi | ..." düzeni.
  //
  // Tablo sırasına güvenilmez, ÖSYM tablo ekleyip çıkarabilir. Ama
  // yalnızca "Sınav Tarihi" geçiyor mu diye bakmak da yetmez: BAŞVURU
  // tablosunda da bu sütun var (5. sırada) ve yanlış tablo seçiliyordu.
  //
  // Ayırt edici olan KONUM: aradığımız tabloda sınav tarihi İKİNCİ
  // sütundur, hemen sınav adından sonra.
  let hedef = null;
  for (const t of tablolar) {
    const basliklar = (t.match(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/gi) || [])
      .slice(0, 3)
      .map(metin);
    if (
      basliklar.length >= 2 &&
      /Sınav\s*Adı/i.test(basliklar[0]) &&
      /Sınav\s*Tarihi/i.test(basliklar[1])
    ) {
      hedef = t;
      break;
    }
  }

  if (!hedef) {
    return {
      ok: false,
      mesaj:
        '"Sınav Adı | Sınav Tarihi" düzeninde tablo bulunamadı. ÖSYM ' +
        'sayfa yapısını değiştirmiş olabilir; tarihleri elle kontrol edin.',
    };
  }

  const satirlar = hedef.match(/<tr[^>]*>[\s\S]*?<\/tr>/gi) || [];
  const sinavlar = [];
  let atlanan = 0;

  for (const satir of satirlar) {
    const hucre = (satir.match(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/gi) || []).map(metin);
    if (hucre.length < 2) continue;

    const ad = hucre[0];
    if (!ad || /Sınav\s*Adı/i.test(ad)) continue; // başlık satırı

    const tarih = tariheCevir(hucre[1]);
    if (!tarih) {
      atlanan++;
      continue;
    }

    // Başvuru bitişi: hücrede iki tarih varsa ikincisi son gündür.
    const basvuruHam = hucre[2] || '';
    const basvuruTarihleri = basvuruHam.match(/\d{2}\.\d{2}\.\d{4}[^\d]*(?:\d{1,2}:\d{2})?/g) || [];
    const sonBasvuru =
      basvuruTarihleri.length > 0
        ? tariheCevir(basvuruTarihleri[basvuruTarihleri.length - 1])
        : null;

    const kod = kisaKod(ad);
    const yil = tarih.slice(0, 4);

    sinavlar.push({
      doc_id: `osym_${kod}_${tarih.slice(0, 10).replace(/-/g, '')}`,
      title: ad,
      institution: 'ÖSYM',
      examDate: tarih,
      applicationDeadline: sonBasvuru,
      applicationUrl: 'https://ais.osym.gov.tr',
      category: 'ÖSYM',
      description: `${yil} yılı ÖSYM sınav takviminden alındı.`,
    });
  }

  if (sinavlar.length === 0) {
    return {
      ok: false,
      mesaj:
        'Tablo bulundu ama hiçbir satır ayrıştırılamadı. Sayfa yapısı ' +
        'değişmiş olabilir; tarihleri elle kontrol edin.',
    };
  }

  return { ok: true, sinavlar, atlanan };
}

/**
 * Çekilen veriyi mevcutla karşılaştırır.
 *
 * Yönetici NE DEĞİŞTİĞİNİ görmeden onaylamamalı. Kör bir "hepsini
 * güncelle" düğmesi, ayrıştırma bozulduğunda sessizce yanlış veri
 * yayınlardı.
 *
 * @param {Array} mevcut Paneldeki sınavlar.
 * @param {Array} gelen  ÖSYM'den çekilenler.
 */
export function karsilastir(mevcut, gelen) {
  const eskiler = new Map();
  for (const s of mevcut || []) {
    if (s?.doc_id) eskiler.set(s.doc_id, s);
  }

  const yeni = [];
  const degisen = [];
  const ayni = [];

  for (const g of gelen) {
    const e = eskiler.get(g.doc_id);
    if (!e) {
      yeni.push(g);
    } else if (e.examDate !== g.examDate) {
      degisen.push({ eski: e, yeni: g });
    } else {
      ayni.push(g);
    }
  }

  return { yeni, degisen, ayni };
}

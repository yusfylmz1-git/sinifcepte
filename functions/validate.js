/**
 * Remote Config yayın isteğinin doğrulaması.
 *
 * ## Neden ayrı dosya
 * Bu mantık Firebase Admin SDK'ya bağlı DEĞİL: saf girdi kontrolü.
 * Ayrı tutulunca emülatör veya servis hesabı olmadan test edilebiliyor
 * (`node --test`). Güvenlik kararlarının test edilebilir olması şart.
 */

/**
 * Yayınlanmasına izin verilen parametreler.
 *
 * Beyaz liste, kara liste değil: panele yeni bir alan eklenirse burada
 * da tanımlanmadıkça yayınlanamaz. Böylece istemci, sunucunun bilmediği
 * bir parametreyi Remote Config'e sokamaz.
 */
export const IZINLI_PARAMETRELER = new Set([
  'calendar_version',
  'outcomes_version',
  'announcements_version',
  'school_directory_version',
  'exams_version',
  'exams_payload',
  'min_app_version',
  'latest_app_version',
  'maintenance_mode',
  'maintenance_message',
  'admin_notice',
  'admin_notice_id',
]);

/**
 * Veri taşıyan parametreler — JSON dizisi olmak zorunda.
 *
 * Bozuk JSON yayınlanırsa mobil taraf ayrıştıramaz ve öğretmen sessizce
 * eski veriyle kalır. Hatayı burada yakalamak, 30.000 cihazda
 * yakalamaktan iyidir.
 */
const JSON_DIZI_BEKLEYENLER = new Set(['exams_payload']);

/**
 * Toplam yük sınırı.
 *
 * Remote Config parametre başına 1 MB'a izin veriyor; 800 KB'da
 * durdurup pay bırakıyoruz. Sınav paketi ~7 KB, yani bu sınır ancak bir
 * hata durumunda devreye girer.
 */
export const AZAMI_BAYT = 800 * 1024;

/**
 * Yayın isteğini doğrular.
 *
 * @param {unknown} params Panelden gelen parametre nesnesi.
 * @returns {{ok: true, params: Record<string, string>} | {ok: false, kod: string, mesaj: string}}
 */
export function dogrula(params) {
  if (params === null || typeof params !== 'object' || Array.isArray(params)) {
    return {
      ok: false,
      kod: 'invalid-argument',
      mesaj: 'params bir nesne olmalı.',
    };
  }

  const girisler = Object.entries(params);
  if (girisler.length === 0) {
    return {
      ok: false,
      kod: 'invalid-argument',
      mesaj: 'Yayınlanacak parametre yok.',
    };
  }

  const temiz = {};
  let toplamBayt = 0;

  for (const [anahtar, deger] of girisler) {
    if (!IZINLI_PARAMETRELER.has(anahtar)) {
      return {
        ok: false,
        kod: 'invalid-argument',
        mesaj: `Bilinmeyen parametre: ${anahtar}`,
      };
    }

    if (deger === null || deger === undefined) {
      return {
        ok: false,
        kod: 'invalid-argument',
        mesaj: `${anahtar} boş olamaz.`,
      };
    }

    // Remote Config her değeri metin olarak saklar.
    const metin = typeof deger === 'string' ? deger : String(deger);

    if (JSON_DIZI_BEKLEYENLER.has(anahtar)) {
      let cozulen;
      try {
        cozulen = JSON.parse(metin);
      } catch {
        return {
          ok: false,
          kod: 'invalid-argument',
          mesaj: `${anahtar} geçerli JSON değil.`,
        };
      }
      if (!Array.isArray(cozulen)) {
        return {
          ok: false,
          kod: 'invalid-argument',
          mesaj: `${anahtar} bir dizi olmalı.`,
        };
      }
    }

    toplamBayt += Buffer.byteLength(metin, 'utf8');
    temiz[anahtar] = metin;
  }

  if (toplamBayt > AZAMI_BAYT) {
    return {
      ok: false,
      kod: 'invalid-argument',
      mesaj: `Yük çok büyük: ${toplamBayt} bayt (sınır ${AZAMI_BAYT}).`,
    };
  }

  return { ok: true, params: temiz };
}

/**
 * Çağıranın yayın yetkisi var mı?
 *
 * ## Neden yalnızca 'super'
 * Remote Config yayını TÜM kullanıcıları etkiler. Moderatör içerik
 * düzenleyebilir ama yayınlayamaz — `firestore.rules` içindeki
 * `isSuper()` ayrımının aynısı.
 *
 * Claim sunucuda çözülür: istemcinin "ben adminim" demesi hiçbir şey
 * ifade etmez.
 *
 * @param {{token?: Record<string, unknown>} | null | undefined} auth
 */
export function yetkiKontrol(auth) {
  if (!auth) {
    return {
      ok: false,
      kod: 'unauthenticated',
      mesaj: 'Önce giriş yapmalısınız.',
    };
  }
  if (auth.token?.adminRole !== 'super') {
    return {
      ok: false,
      kod: 'permission-denied',
      mesaj: 'Bu işlem için süper yönetici yetkisi gerekir.',
    };
  }
  return { ok: true };
}

/**
 * Sürüm alanları — yalnızca ARTABİLİR.
 *
 * Bu alanlar cihazın "yeni veri var mı" kararını veriyor
 * (`uzakSurum <= yerelSurum` ise yok sayılır).
 */
export const SURUM_ALANLARI = [
  'exams_version',
  'calendar_version',
  'outcomes_version',
  'announcements_version',
];

/**
 * Yayın sürümü geriye alınıyor mu?
 *
 * ## Neden gerekli
 *
 * Panel yayın sırasında yerel manifestin TAMAMINI gönderiyor. Yeni bir
 * tarayıcıda localStorage boşsa varsayılanlar gidiyor:
 * `exams_version: 1`, `maintenance_mode: false`, `min_app_version: 1.0.0`.
 *
 * Senaryo: A yönetici v10 yayınlar. B başka bir tarayıcıdan "sınav
 * yayınla" der ve canlı sürüm 10'dan 1'e DÜŞER. Cihazlar yeni sınavı
 * yok sayar; öğretmenler eski sınav tarihiyle kalır ve veliye yanlış
 * başvuru tarihi söylenir.
 *
 * (Bağımsız incelemede bildirildi, 19 Eylül 2026'da doğrulandı:
 * sunucu gelen anahtarları karşılaştırmadan üzerine yazıyordu.)
 *
 * ## Eşit değer GEÇER
 *
 * Aynı içeriği yeniden yayınlamak meşru bir iş; yalnızca DÜŞÜŞ
 * engelleniyor.
 *
 * @param {Record<string, unknown>} gelen Yayınlanmak istenen parametreler
 * @param {Record<string, {defaultValue?: {value?: string}}>} mevcutSablon
 *        Remote Config'in şu anki parametreleri
 * @returns {{ok: true} | {ok: false, kod: string, mesaj: string}}
 */
export function geriSarmaKontrol(gelen, mevcutSablon) {
  const dusenler = [];

  for (const alan of SURUM_ALANLARI) {
    if (!(alan in (gelen ?? {}))) continue;

    const mevcutHam = mevcutSablon?.[alan]?.defaultValue?.value;
    const mevcut = Number.parseInt(mevcutHam ?? '0', 10);
    const yeni = Number.parseInt(String(gelen[alan] ?? '0'), 10);

    // Sayıya çevrilemeyen değer burada ELENMİYOR: `dogrula` zaten
    // biçim denetimi yapıyor ve iki yerde aynı kuralı tutmak
    // ayrışmaya açık.
    if (!Number.isFinite(mevcut) || !Number.isFinite(yeni)) continue;

    if (yeni < mevcut) dusenler.push(`${alan}: ${mevcut} -> ${yeni}`);
  }

  if (dusenler.length === 0) return { ok: true };

  // Sessizce düzeltmek YANLIŞ olurdu: yönetici yayınladığını sanır,
  // oysa veri eski kalır. Mesaj ne yapılacağını söylüyor.
  return {
    ok: false,
    kod: 'failed-precondition',
    mesaj:
      'Sürüm geriye alınamaz (' +
      dusenler.join(', ') +
      '). Bu genellikle paneli YENİ bir tarayıcıda açmaktan olur: ' +
      'yerel kayıt boş olduğu için varsayılan sürüm gönderiliyor. ' +
      'Önce "Canlıdan Çek" ile mevcut durumu alın, sonra yayınlayın.',
  };
}

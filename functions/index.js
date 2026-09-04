/**
 * SınıfCepte yönetim işlevleri.
 *
 * ## Neden bu dosya var
 * Admin paneli tarayıcıda çalışıyor ve Remote Config'e yazmak Admin SDK
 * gerektiriyor. Servis hesabı anahtarı tarayıcıya konulamaz — konulsaydı
 * paneli açan herkes projenin tam yetkisini alırdı.
 *
 * Önceki akış şuydu: panel JSON indiriyor, yönetici terminalde
 * `publish_remote_config.mjs` çalıştırıyordu. Kullanılabilir değildi.
 * Bu fonksiyon aradaki köprü: panel çağırır, fonksiyon yetkiyi
 * doğrulayıp yayınlar.
 *
 * ## Bölge
 * `europe-west1` — Firestore `eur3` ile aynı kıta.
 */
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { initializeApp } from 'firebase-admin/app';
import { getRemoteConfig } from 'firebase-admin/remote-config';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

import { dogrula, yetkiKontrol } from './validate.js';
import { ayristir, karsilastir, OSYM_TAKVIM_URL } from './osym_parser.js';

initializeApp();

const BOLGE = 'europe-west1';

/**
 * Remote Config parametrelerini yayınlar.
 *
 * Girdi : { params: { exams_version: 3, exams_payload: '[...]' , ... } }
 * Çıktı : { ok: true, version: 42, parametreler: ['exams_version', ...] }
 *
 * ## Güvenlik sırası
 * 1. Oturum var mı
 * 2. `adminRole == 'super'` mi (claim SUNUCUDA çözülür)
 * 3. Parametreler beyaz listede mi
 * 4. Veri alanları geçerli JSON mu, boyut sınırda mı
 *
 * Doğrulama `validate.js` içinde; Firebase'e bağlı olmadığı için
 * emülatörsüz test edilebiliyor.
 */
export const publishRemoteConfig = onCall(
  {
    region: BOLGE,
    // Yılda birkaç çağrı; tek örnek fazlasıyla yeter ve soğuk başlangıç
    // maliyeti önemsiz.
    maxInstances: 3,
    cors: true,
  },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }

    const sonuc = dogrula(request.data?.params);
    if (!sonuc.ok) {
      throw new HttpsError(sonuc.kod, sonuc.mesaj);
    }

    const rc = getRemoteConfig();

    let sablon;
    try {
      sablon = await rc.getTemplate();
    } catch (e) {
      throw new HttpsError(
        'internal',
        `Remote Config şablonu okunamadı: ${e.message}`
      );
    }

    for (const [anahtar, deger] of Object.entries(sonuc.params)) {
      sablon.parameters[anahtar] = {
        defaultValue: { value: deger },
        description: 'SınıfCepte yönetim paneli',
      };
    }

    try {
      // validateTemplate: hatalı şablon yayınlanıp uygulamayı bozmasın.
      await rc.validateTemplate(sablon);
    } catch (e) {
      throw new HttpsError('invalid-argument', `Şablon geçersiz: ${e.message}`);
    }

    let yayinlanan;
    try {
      yayinlanan = await rc.publishTemplate(sablon);
    } catch (e) {
      throw new HttpsError('internal', `Yayın başarısız: ${e.message}`);
    }

    const surum = yayinlanan.version?.versionNumber ?? null;
    const anahtarlar = Object.keys(sonuc.params);

    // Denetim kaydı. Kural `allow create: if false` — yalnızca Admin SDK
    // yazabilir, panelden sahte kayıt atılamaz.
    //
    // Yayın BAŞARILI olduktan sonra yazılıyor: kayıt varsa işlem
    // gerçekten olmuştur. Kayıt atılamazsa yayın geri alınmaz —
    // denetim kaydının eksikliği yayını bozmaktan iyidir.
    try {
      await getFirestore().collection('audit_logs').add({
        tur: 'remote_config_publish',
        uid: request.auth.uid,
        email: request.auth.token.email ?? '',
        parametreler: anahtarlar,
        rcSurum: surum,
        olusturmaZamani: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('Denetim kaydı yazılamadı:', e);
    }

    return { ok: true, version: surum, parametreler: anahtarlar };
  }
);

/**
 * ÖSYM sınav takvimini çeker ve mevcut veriyle karşılaştırır.
 *
 * Girdi : { mevcut: [ {doc_id, examDate, ...}, ... ] }
 * Çıktı : { ok, yeni: [...], degisen: [...], ayniSayisi, toplam, atlanan }
 *
 * ## YAYINLAMAZ
 * Yalnızca okur ve karşılaştırır. Yayın ayrı bir çağrı
 * (`publishRemoteConfig`) ve yöneticinin onayını gerektirir.
 *
 * Sebep: sayfa yapısı ÖSYM'nin kontrolünde. Bir gün değişirse
 * ayrıştırma bozulur; yanlış tarih 30.000 öğretmene gitmemeli.
 * Yönetici NE DEĞİŞTİĞİNİ görüp onaylar.
 *
 * ## Neden sunucudan çekiliyor
 * Tarayıcı başka bir alan adından HTML çekemez (CORS). Ayrıca ÖSYM
 * sayfası 1 MB; sunucuda ayrıştırıp yalnızca farkları göndermek
 * yöneticinin bağlantısını yormaz.
 */
export const fetchOsymTakvim = onCall(
  {
    region: BOLGE,
    maxInstances: 3,
    cors: true,
    // ÖSYM sayfası yavaş yanıt verebiliyor.
    timeoutSeconds: 60,
  },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }

    let html;
    try {
      const yanit = await fetch(OSYM_TAKVIM_URL, {
        headers: {
          // Varsayılan istemci başlığıyla bazı kamu siteleri yanıt
          // vermiyor.
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
            '(KHTML, like Gecko) Chrome/131.0 Safari/537.36',
          'Accept-Language': 'tr-TR,tr;q=0.9',
        },
        signal: AbortSignal.timeout(40000),
      });

      if (!yanit.ok) {
        throw new HttpsError(
          'unavailable',
          `ÖSYM sayfası ${yanit.status} döndü. Site geçici olarak ` +
            'erişilemez olabilir; sonra tekrar deneyin.'
        );
      }
      html = await yanit.text();
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError(
        'unavailable',
        `ÖSYM sayfasına ulaşılamadı: ${e.message}`
      );
    }

    const sonuc = ayristir(html);
    if (!sonuc.ok) {
      // Ayrıştırma bozulduğunda SESSİZ KALMIYORUZ: yönetici elle
      // kontrol etmeli.
      throw new HttpsError('failed-precondition', sonuc.mesaj);
    }

    const fark = karsilastir(request.data?.mevcut, sonuc.sinavlar);

    return {
      ok: true,
      yeni: fark.yeni,
      degisen: fark.degisen,
      ayniSayisi: fark.ayni.length,
      toplam: sonuc.sinavlar.length,
      atlanan: sonuc.atlanan,
      kaynak: OSYM_TAKVIM_URL,
      cekilmeZamani: new Date().toISOString(),
    };
  }
);

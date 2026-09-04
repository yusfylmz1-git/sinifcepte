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

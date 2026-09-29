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
import { getAuth } from 'firebase-admin/auth';

import {
  dogrula,
  yetkiKontrol,
  geriSarmaKontrol,
  okumaYetkisi,
  canliDegerler,
  cakismaKontrol,
} from './validate.js';
import { ayristir, karsilastir, OSYM_TAKVIM_URL } from './osym_parser.js';
import {
  LISTE_DURUMLARI,
  basvuruGuncellemesi,
  basvuruKimligi,
  basvuruOzeti,
  kararDogrula,
  kararUygunMu,
  okulKimligiGecerli,
  yeniClaimler,
} from './okul_yonetici.js';

initializeApp();

const BOLGE = 'europe-west1';

/**
 * Remote Config parametrelerini yayınlar.
 *
 * Girdi : { params: { maintenance_mode: 'true' },
 *           onceki: { maintenance_mode: 'false' } }
 * Çıktı : { ok: true, version: 42, parametreler: ['maintenance_mode'] }
 *
 * Yalnızca GÖNDERİLEN parametreler değişir; şablondaki diğerleri olduğu
 * gibi kalır. Panel yalnızca değiştirilen ayarı gönderiyor (K8).
 *
 * ## Güvenlik sırası
 * 1. Oturum var mı
 * 2. `adminRole == 'super'` mi (claim SUNUCUDA çözülür)
 * 3. Parametreler beyaz listede mi
 * 4. Veri alanları geçerli JSON mu, boyut sınırda mı
 * 5. Sürüm geriye gitmiyor mu; ayar, panel onu okuduktan sonra
 *    başkasınca değiştirilmemiş mi
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

    // Sürüm alanları geriye alınamaz — mantık `validate.js` içinde,
    // orada Admin SDK'sız test edilebiliyor.
    const geri = geriSarmaKontrol(sonuc.params, sablon.parameters);
    if (!geri.ok) {
      throw new HttpsError(geri.kod, geri.mesaj);
    }

    const cakisma = cakismaKontrol(
      sonuc.params,
      request.data?.onceki,
      sablon.parameters
    );
    if (!cakisma.ok) {
      throw new HttpsError(cakisma.kod, cakisma.mesaj);
    }

    // Denetim kaydı için: neyin neyden neye değiştiği. Sınav verisi
    // büyük ve zaten sürümüyle izleniyor; kayda girmiyor.
    const degisiklikler = {};
    for (const [anahtar, deger] of Object.entries(sonuc.params)) {
      if (anahtar === 'exams_payload') continue;
      degisiklikler[anahtar] = {
        onceki: sablon.parameters[anahtar]?.defaultValue?.value ?? null,
        yeni: deger,
      };
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
        degisiklikler,
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
 * Panelin yönettiği Remote Config parametrelerinin CANLI değerleri.
 *
 * Girdi : {}
 * Çıktı : { ok: true, degerler: { maintenance_mode: 'false', ... },
 *           version: 42 }
 *
 * ## Neden
 * Panel eskiden yerel kaydını (localStorage) gerçek sanıyordu: yeni bir
 * tarayıcıda bakım modu "kapalı", sürüm "1" görünüyordu ve bu değerler
 * sonraki yayınla canlıya gidiyordu (K8). Panel artık ekranı ve
 * yayınları canlı değerlerden kuruyor.
 *
 * Okur, YAZMAZ: moderatör de görebilir.
 */
export const readRemoteConfig = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = okumaYetkisi(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    let sablon;
    try {
      sablon = await getRemoteConfig().getTemplate();
    } catch (e) {
      throw new HttpsError('internal', `Remote Config şablonu okunamadı: ${e.message}`);
    }
    return {
      ok: true,
      degerler: canliDegerler(sablon.parameters),
      version: sablon.version?.versionNumber ?? null,
    };
  }
);

/**
 * ÖSYM sayfasını indirir — kararsız sunucu için yeniden denemeli.
 *
 * ## Neden yeniden deneme gerekiyor
 * Sunucu tutarsız davranıyor. Aynı istek 20 saniye arayla üç kez
 * gönderildiğinde ölçülen (Eylül 2026):
 *
 *     deneme 1: 25000 ms  TIMEOUT
 *     deneme 2:   276 ms  HTTP 200, 1 MB
 *     deneme 3: 25000 ms  TIMEOUT
 *
 * HTTP 200 başlığı hemen geliyor ama gövde bazen hiç akmıyor.
 * Başlıklarla ilgisi yok — önce User-Agent sanılmıştı, ölçüm çürüttü.
 *
 * Tek denemede başarı şansı ~1/3. Üç denemeyle ~%97'ye çıkıyor.
 */
async function osymSayfasiniAl() {
  // ÖSYM bazen uzun süre hiç yanıt vermiyor. Ölçüm (5 Eylül 2026):
  // üç deneme de 12 sn'de takıldı. Deneme sayısı 5'e çıkarıldı;
  // fonksiyon zaman aşımı 60 sn, 5 × (12 + 1.5) = 67 sn'yi aşmasın
  // diye bekleme 1 sn'ye indirildi.
  const DENEME = 5;
  let sonHata = null;

  for (let i = 1; i <= DENEME; i++) {
    try {
      const yanit = await fetch(OSYM_TAKVIM_URL, {
        headers: { 'User-Agent': 'Mozilla/5.0 Chrome/131.0' },
        // Kısa tutuluyor: başarılı yanıt 300 ms'de geliyor, bekleyen
        // istek zaten hiç dönmeyecek. Erken vazgeçip yeniden denemek
        // uzun beklemekten iyi.
        signal: AbortSignal.timeout(12000),
      });

      if (!yanit.ok) {
        sonHata = new Error(`sunucu ${yanit.status} döndü`);
        continue;
      }

      const govde = await yanit.text();
      if (govde.length < 1000) {
        sonHata = new Error('sayfa eksik geldi');
        continue;
      }
      return govde;
    } catch (e) {
      sonHata = e;
      // Son denemeden sonra beklemeye gerek yok.
      if (i < DENEME) {
        await new Promise((r) => setTimeout(r, 1000));
      }
    }
  }

  // 'unavailable' yerine 'deadline-exceeded': panel bunu "internet
  // bağlantınızı kontrol edin" diye çeviriyordu ve kullanıcıyı yanlış
  // yere baktırıyordu. Sorun ÖSYM'de.
  throw new HttpsError(
    'deadline-exceeded',
    `ÖSYM sitesi ${DENEME} denemede yanıt vermedi. Sorun sizin ` +
      'bağlantınızda değil — ÖSYM sunucusu şu an yavaş. Birkaç dakika ' +
      'sonra tekrar deneyin; acele ediyorsanız tarihleri elle ' +
      'girebilirsiniz.'
  );
}

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
    // 5 deneme × (12 sn zaman aşımı + 1 sn bekleme) = 65 sn.
    timeoutSeconds: 90,
  },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }

    const html = await osymSayfasiniAl();

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

/**
 * Okul yöneticiliği başvuruları — panel listesi.
 *
 * Girdi : { durum: 'pending' | 'approved' | 'rejected' }
 * Çıktı : { ok: true, basvurular: [ { uid, ad, okulId, dizindeMi, ... } ] }
 *
 * Her başvuru için KANIT da dönüyor: başvuran o okulun öğretmen
 * dizininde (`school_teachers/{okulId}_{uid}`) kayıtlı mı? Kayıt onaysız
 * oluşuyor (Y9), yani kesin kanıt değil; ama dizinde olmayan birinin o
 * okulun yöneticisi olmak istemesi soru işaretidir.
 *
 * Okur, YAZMAZ: moderatör de görebilir; karar süper yöneticide.
 */
export const listSchoolAdminRequests = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = okumaYetkisi(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const durum = request.data?.durum ?? 'pending';
    if (!LISTE_DURUMLARI.has(durum)) {
      throw new HttpsError('invalid-argument', `Bilinmeyen durum: ${durum}`);
    }

    const db = getFirestore();
    // Sıralama bellekte: `where + orderBy` bileşik dizin isterdi.
    const snap = await db
      .collection('school_admin_requests')
      .where('status', '==', durum)
      .limit(200)
      .get();

    const dizinYollari = snap.docs.map((b) => {
      const v = b.data();
      return okulKimligiGecerli(v.school_id) && typeof v.teacher_uid === 'string'
        ? db.doc(`school_teachers/${v.school_id}_${v.teacher_uid}`)
        : null;
    });
    const okunacak = dizinYollari.filter(Boolean);
    const dizin = okunacak.length ? await db.getAll(...okunacak) : [];
    const kayitli = new Set(dizin.filter((s) => s.exists).map((s) => s.ref.path));

    const basvurular = snap.docs.map((b, i) =>
      basvuruOzeti(b.data(), dizinYollari[i] !== null && kayitli.has(dizinYollari[i].path))
    );
    // Bekleyenler en eskiden (sıra), kararlılar en yeniden.
    basvurular.sort((a, b) =>
      durum === 'pending' ? a.tarih.localeCompare(b.tarih) : b.kararTarihi.localeCompare(a.kararTarihi)
    );
    return { ok: true, basvurular };
  }
);

/**
 * Okul yöneticiliği kararı: onay, ret ya da geri alma.
 *
 * Girdi : { uid, karar: 'onay' | 'red' | 'geri_al', gerekce? }
 * Çıktı : { ok: true, durum: 'approved' | 'rejected' }
 *
 * Y17 (ikinci yarı): eskiden yalnızca komut satırı betiği
 * (`scripts/admin/approve_school_admin.mjs`). Aynı sıra korunuyor:
 * önce claim, sonra başvuru belgesi; claim yazılamazsa belge "onaylı"
 * görünmesin.
 *
 * ## Geri alma ne zaman etkili olur
 * Claim ID token'da taşınıyor ve token saatte bir yenileniyor: öğretmen
 * en geç ~1 saat içinde yetkiyi kaybeder. Oturumunu zorla kapatmak
 * (`revokeRefreshTokens`) onu uygulamanın TAMAMINDAN atardı; bilerek
 * yapılmıyor.
 */
export const decideSchoolAdmin = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const k = kararDogrula(request.data);
    if (!k.ok) {
      throw new HttpsError(k.kod, k.mesaj);
    }

    const db = getFirestore();
    const ref = db.collection('school_admin_requests').doc(basvuruKimligi(k.uid));
    const belge = await ref.get();
    if (!belge.exists) {
      throw new HttpsError('not-found', 'Başvuru bulunamadı.');
    }
    const veri = belge.data();
    const uygun = kararUygunMu(veri.status, k.karar);
    if (!uygun.ok) {
      throw new HttpsError(uygun.kod, uygun.mesaj);
    }
    if (k.karar === 'onay' && !okulKimligiGecerli(veri.school_id)) {
      throw new HttpsError(
        'failed-precondition',
        `Başvurudaki okul kimliği geçersiz (${veri.school_id}). ` +
          'Öğretmenden okulunu listeden seçip yeniden başvurmasını isteyin.'
      );
    }

    const auth = getAuth();
    let kullanici;
    try {
      kullanici = await auth.getUser(k.uid);
    } catch {
      throw new HttpsError('not-found', 'Kullanıcı hesabı bulunamadı (silinmiş olabilir).');
    }

    await auth.setCustomUserClaims(
      k.uid,
      yeniClaimler(kullanici.customClaims, k.karar, veri.school_id)
    );
    const guncelleme = basvuruGuncellemesi(
      k.karar,
      request.auth.uid,
      k.gerekce,
      new Date().toISOString()
    );
    await ref.update(guncelleme);

    // Denetim kaydı: yayın gibi, kayıt atılamazsa karar geri alınmıyor.
    try {
      await db.collection('audit_logs').add({
        tur: 'school_admin_decision',
        uid: request.auth.uid,
        email: request.auth.token.email ?? '',
        hedefUid: k.uid,
        okulId: veri.school_id ?? '',
        karar: k.karar,
        gerekce: k.gerekce,
        olusturmaZamani: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('Denetim kaydı yazılamadı:', e);
    }

    return { ok: true, durum: guncelleme.status };
  }
);

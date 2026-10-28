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
import { defineSecret } from 'firebase-functions/params';
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
  cikarmaDogrula,
  dizinKimligi,
  epostaGecerli,
  kayitOzetleri,
  ogretmenOzeti,
  okulKimligiCoz,
} from './okullar.js';
import { imzala, istekDogrula, kodBicimle, mesaj as destekMesaji } from './destek.js';
import { bulutVerisiniSil } from './hesap_silme.js';
import { istekDogrula as duyuruIstegi, uygula as duyuruUygula } from './idare_duyurusu.js';

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
 * Kişisel veri görüntüleme kaydı.
 *
 * Panel öğretmen adı ve e-postası gösteriyor; kimin neye baktığı iz
 * bırakmalı (KVKK hesap verebilirlik). Kayıt atılamazsa görüntüleme
 * engellenmiyor: destek işi durmasın.
 */
async function goruntulemeKaydet(request, tur, hedef) {
  try {
    await getFirestore().collection('audit_logs').add({
      tur,
      uid: request.auth.uid,
      email: request.auth.token.email ?? '',
      goruntulenen: hedef,
      olusturmaZamani: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error('Görüntüleme kaydı yazılamadı:', e);
  }
}

/**
 * Bir okulun görünümü: kayıtlı öğretmenler ve geçmiş.
 *
 * Girdi : { okul: '775214' | 'meb_775214' }
 * Çıktı : { ok, okulId, ogretmenler: [...], kayitlar: [...] }
 *
 * Okul yöneticiliği 18 Ekim 2026'da kalktı; başvuru listesi ve
 * yöneticilik sütunu 29 Ekim'de çıktı.
 *
 * Okur, YAZMAZ (görüntüleme kaydı hariç): moderatör de görebilir.
 */
export const schoolOverview = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = okumaYetkisi(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const okulId = okulKimligiCoz(request.data?.okul);
    if (!okulId) {
      throw new HttpsError('invalid-argument', 'Kurum kodunu 6 haneli yazın (ör. 775214).');
    }

    const db = getFirestore();
    const [dizin, kayit] = await Promise.all([
      db.collection('school_teachers').where('schoolId', '==', okulId).limit(500).get(),
      db.collection('audit_logs').where('okulId', '==', okulId).limit(100).get(),
    ]);
    await goruntulemeKaydet(request, 'okul_goruntuleme', okulId);

    const ogretmenler = dizin.docs
      .map((b) => ogretmenOzeti(b.data()))
      .sort((a, b) => a.ad.localeCompare(b.ad, 'tr'));

    return {
      ok: true,
      okulId,
      ogretmenler,
      kayitlar: kayitOzetleri(kayit.docs.map((b) => b.data())),
    };
  }
);

/**
 * E-postayla kişi arama: hesap, yetkiler, kayıtlı olduğu okullar.
 *
 * Girdi : { eposta }
 * Çıktı : { ok, kisi: { uid, ad, eposta, olusturma, sonGiris, devreDisi,
 *                       yetkiler, okullar } | null }
 *
 * Destek için: "hesabım çalışmıyor" diyen öğretmenin hangi okula
 * kayıtlı olduğu ve panel yetkisi tek bakışta görünsün.
 */
export const findPerson = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = okumaYetkisi(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const eposta = String(request.data?.eposta ?? '').trim().toLowerCase();
    if (!epostaGecerli(eposta)) {
      throw new HttpsError('invalid-argument', 'Geçerli bir e-posta yazın.');
    }

    let kullanici;
    try {
      kullanici = await getAuth().getUserByEmail(eposta);
    } catch (e) {
      if (e?.code === 'auth/user-not-found') {
        await goruntulemeKaydet(request, 'kisi_goruntuleme', eposta);
        return { ok: true, kisi: null };
      }
      throw new HttpsError('internal', `Hesap okunamadı: ${e.message}`);
    }
    const dizin = await getFirestore()
      .collection('school_teachers')
      .where('teacherUid', '==', kullanici.uid)
      .limit(20)
      .get();
    await goruntulemeKaydet(request, 'kisi_goruntuleme', kullanici.uid);

    const c = kullanici.customClaims || {};
    return {
      ok: true,
      kisi: {
        uid: kullanici.uid,
        ad: kullanici.displayName ?? '',
        eposta: kullanici.email ?? '',
        olusturma: kullanici.metadata?.creationTime ?? '',
        sonGiris: kullanici.metadata?.lastSignInTime ?? '',
        devreDisi: Boolean(kullanici.disabled),
        yetkiler: {
          adminRole: c.adminRole ?? '',
        },
        okullar: dizin.docs.map((b) => {
          const v = b.data();
          return { okulId: String(v.schoolId ?? ''), brans: String(v.branch ?? '') };
        }),
      },
    };
  }
);

/**
 * Bir öğretmeni okulun dizininden çıkarır.
 *
 * Girdi : { okulId, uid, gerekce }
 *
 * Ne için: okuldan ayrılan öğretmen ya da okula ait olmadığı hâlde
 * kendini eklemiş biri. Dizin kaydı onaysız oluşuyor (Y9); kişi okulunu
 * uygulamada yeniden seçerse kayıt yeniden oluşur — bu bir yasak değil,
 * temizlik.
 *
 * Yalnızca süper yönetici.
 */
export const removeFromSchoolDirectory = onCall(
  { region: BOLGE, maxInstances: 3, cors: true },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const c = cikarmaDogrula(request.data);
    if (!c.ok) {
      throw new HttpsError(c.kod, c.mesaj);
    }
    const db = getFirestore();
    const ref = db.collection('school_teachers').doc(dizinKimligi(c.okulId, c.uid));
    const belge = await ref.get();
    if (!belge.exists) {
      throw new HttpsError('not-found', 'Bu öğretmen bu okulun dizininde değil.');
    }
    const ad = String(belge.data().fullName ?? '');
    await ref.delete();

    try {
      await db.collection('audit_logs').add({
        tur: 'okul_dizininden_cikarma',
        uid: request.auth.uid,
        email: request.auth.token.email ?? '',
        hedefUid: c.uid,
        okulId: c.okulId,
        karar: `${ad} dizinden çıkarıldı`,
        gerekce: c.gerekce,
        olusturmaZamani: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('Denetim kaydı yazılamadı:', e);
    }
    return { ok: true };
  }
);

/**
 * Destek kodunun gizli imza anahtarı (Ed25519 tohumu, base64).
 *
 * Firebase gizli değer deposunda; kodda ve depoda YOK. Açık yarısı Ana
 * Program'a gömülü. Yayından önce bir kez:
 *   firebase functions:secrets:set DESTEK_IMZA_TOHUMU --data-file <dosya>
 */
const DESTEK_IMZA_TOHUMU = defineSecret('DESTEK_IMZA_TOHUMU');

/**
 * Ana Program parolası için destek kodu üretir (yedek yoksa).
 *
 * Girdi : { kurumKodu: '775214', talep: 'K7MQ-2XPA', gerekce }
 * Çıktı : { ok, kod: 'EOYE3-ECDL2-…', eposta: '775214@meb.k12.tr' }
 *
 * Yalnızca süper yönetici. Kod yalnızca o okul ve o talep için geçerli;
 * talebi okulun bilgisayarı üretiyor ve 24 saatlik, tek kullanımlık.
 * Her kod denetim kaydına ve okulun geçmişine düşüyor.
 *
 * Kod okulun resmî e-postasına gönderilmeli: telefonda "müdür
 * yardımcısıyım" diyen herkese değil.
 */
export const issueSupportCode = onCall(
  { region: BOLGE, maxInstances: 3, cors: true, secrets: [DESTEK_IMZA_TOHUMU] },
  async (request) => {
    const yetki = yetkiKontrol(request.auth);
    if (!yetki.ok) {
      throw new HttpsError(yetki.kod, yetki.mesaj);
    }
    const i = istekDogrula(request.data);
    if (!i.ok) {
      throw new HttpsError(i.kod, i.mesaj);
    }

    let kod;
    try {
      kod = kodBicimle(imzala(DESTEK_IMZA_TOHUMU.value(), destekMesaji(i.kurumKodu, i.talep)));
    } catch (e) {
      // Tohum eksik ya da bozuk: yayın adımı unutulmuş.
      console.error('Destek kodu imzalanamadı:', e);
      throw new HttpsError('failed-precondition', 'Destek imza anahtarı ayarlı değil.');
    }

    // Kod ancak kayıt yazıldıktan SONRA dönüyor: izi olmayan kod olmasın.
    await getFirestore().collection('audit_logs').add({
      tur: 'destek_kodu',
      uid: request.auth.uid,
      email: request.auth.token.email ?? '',
      okulId: `meb_${i.kurumKodu}`,
      talep: i.talep,
      gerekce: i.gerekce,
      olusturmaZamani: FieldValue.serverTimestamp(),
    });

    return { ok: true, kod, eposta: `${i.kurumKodu}@meb.k12.tr` };
  }
);

/**
 * Kullanıcının kendi hesabını siler (Google Play şartı, KVKK m.7).
 *
 * Girdi : { onay: 'SİL' }
 * Çıktı : { ok: true, sinif: 2, belge: 41 }
 *
 * Yalnızca oturumdaki kişi KENDİNİ silebilir; uid istekten değil
 * kimlikten okunur. Önce buluttaki kayıtlar, en son Firebase hesabı
 * silinir: hesap önce gitseydi yarıda kalan silme bir daha
 * çağrılamazdı. Öğretmenin telefondaki öğrenci verisine buradan
 * ulaşılmaz; onu uygulama siler.
 *
 * Denetim kaydında yalnız uid ve sayılar durur (e-posta yok): silme
 * talebinin yerine getirildiğinin kanıtı.
 */
export const hesabimiSil = onCall(
  { region: BOLGE, maxInstances: 10, timeoutSeconds: 300 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Oturum açılmamış.');
    }
    if (request.data?.onay !== 'SİL') {
      throw new HttpsError('invalid-argument', 'Silme onayı eksik.');
    }

    const sayilar = await bulutVerisiniSil(getFirestore(), uid);
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if (e?.code !== 'auth/user-not-found') throw e;
    }

    try {
      await getFirestore().collection('audit_logs').add({
        tur: 'hesap_silme',
        uid,
        ...sayilar,
        olusturmaZamani: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error('Denetim kaydı yazılamadı:', e);
    }
    return { ok: true, ...sayilar };
  }
);

/**
 * Ana Program'ın idare duyurusunu öğretmen telefonlarının okuduğu kanala
 * yazar ya da kanaldan siler (28 Ekim 2026 kararı).
 *
 * Girdi : { islem: 'yayinla', okulId, id, olusturma, baslangic, bitis,
 *           baslik, metin, acik, imza }  |  { islem: 'sil', okulId, id,
 *           zaman, acik, imza }
 *
 * Oturum İSTENMEZ: Ana Program'ın Firebase hesabı yok. Kimliği Ed25519
 * imzası kanıtlar ve yazılan kanal anahtarın parmak izini taşır.
 * Telefon imzayı yine kendisi doğrular (`idare_duyurusu.js`).
 */
export const idareDuyurusu = onCall(
  { region: BOLGE, maxInstances: 5 },
  async (request) => {
    const simdi = Math.floor(Date.now() / 1000);
    const istek = duyuruIstegi(request.data, simdi);
    if (!istek.ok) {
      throw new HttpsError(istek.kod, istek.mesaj);
    }
    const sonuc = await duyuruUygula(getFirestore(), istek, simdi);
    if (!sonuc.ok) {
      throw new HttpsError(sonuc.kod, sonuc.mesaj);
    }
    return sonuc;
  }
);

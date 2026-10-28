/**
 * İdare duyurusu — Ana Program'dan öğretmenlerin telefonuna.
 *
 * ## Neden bu dosya var
 * Öğretmenler okul ağına bağlanmıyor, mobil veride (4 Ekim 2026); Ana
 * Program telefonlara okul ağından ulaşamaz. Kullanıcı 28 Ekim'de idare
 * duyurusunun telefonda, uygulama açılınca görünmesini seçti. Ana
 * Program için "bulut yok" kararı YALNIZ bu tek yönlü kanal için esnedi.
 *
 * ## Güven modeli
 * Ana Program duyuruyu kendi Ed25519 anahtarıyla imzalar. Öğretmenin
 * telefonu açık anahtarı tahta karekodundan (SCT yükü, 7. alan) alır ve
 * her duyurunun imzasını KENDİSİ doğrular. Bu fonksiyon da doğrular ama
 * ona güvenilmez: sunucu ele geçse bile sahte duyuru telefonda görünmez.
 *
 * Kanal kimliği `{okulId}_{parmakIzi}`: aynı okul kodunu yazan başka biri
 * kendi anahtarıyla AYRI bir kanala yazar, öğretmenler onu okumaz.
 * Oturum gerekmez; kimliği imza kanıtlar.
 *
 * Firebase'e bağlı değil: `db` Admin SDK'nın Firestore'u ya da sahtesi.
 */
import { createHash, createPublicKey, verify } from 'node:crypto';

export const YAYIN_ONEKI = 'SCDUYURU1';
export const SILME_ONEKI = 'SCDUYURUSIL1';

/** Ana Program saatiyle sunucu saati arasındaki en büyük fark. */
export const SAAT_PAYI_SN = 10 * 60;
/** Bir duyuru en çok bu kadar yayında kalır. */
export const EN_UZUN_SN = 60 * 24 * 3600;
/** Bir kanala 24 saatte en çok bu kadar duyuru. */
export const GUNLUK_SINIR = 30;

export const BASLIK_SINIRI = 80;
export const METIN_SINIRI = 1000;

const SPKI_ONEK = Buffer.from('302a300506032b6570032100', 'hex');

const okulIdGecerli = (v) => typeof v === 'string' && /^(meb|man)_[A-Za-z0-9-]{1,40}$/.test(v);
const duyuruIdGecerli = (v) => typeof v === 'string' && /^[A-Za-z0-9_-]{6,64}$/.test(v);
const tamSayi = (v) => Number.isSafeInteger(v) && v >= 0;

function b64(v, uzunluk) {
  if (typeof v !== 'string' || v.length > 200) return null;
  const b = Buffer.from(v, 'base64');
  return b.length === uzunluk ? b : null;
}

/** Açık anahtarın parmak izi: SHA-256'nın ilk 16 onaltılık hanesi. */
export function parmakIzi(acik) {
  return createHash('sha256').update(acik).digest('hex').slice(0, 16);
}

export function kanalKimligi(okulId, acik) {
  return `${okulId}_${parmakIzi(acik)}`;
}

/** İmzalanan metin. Ana Program (Python) ve telefon (Dart) birebir aynısını kurar. */
export function yayinMesaji(d) {
  return Buffer.from(
    [YAYIN_ONEKI, d.okulId, d.id, d.olusturma, d.baslangic, d.bitis, d.baslik, d.metin].join('\n'),
    'utf8'
  );
}

export function silmeMesaji(d) {
  return Buffer.from([SILME_ONEKI, d.okulId, d.id, d.zaman].join('\n'), 'utf8');
}

export function imzaDogru(acik, mesaj, imza) {
  try {
    const anahtar = createPublicKey({ key: Buffer.concat([SPKI_ONEK, acik]), format: 'der', type: 'spki' });
    return verify(null, mesaj, anahtar, imza);
  } catch {
    return false;
  }
}

const hata = (kod, mesaj) => ({ ok: false, kod, mesaj });

/**
 * Ana Program'dan gelen isteği doğrular.
 *
 * @param {object} veri  { islem, okulId, acik, imza, id, ... }
 * @param {number} simdi Unix saniyesi (sunucu saati).
 */
export function istekDogrula(veri, simdi) {
  const islem = veri?.islem;
  if (islem !== 'yayinla' && islem !== 'sil') return hata('invalid-argument', 'İşlem bilinmiyor.');
  if (!okulIdGecerli(veri.okulId)) return hata('invalid-argument', 'Okul kimliği geçersiz.');
  if (!duyuruIdGecerli(veri.id)) return hata('invalid-argument', 'Duyuru kimliği geçersiz.');
  const acik = b64(veri.acik, 32);
  const imza = b64(veri.imza, 64);
  if (!acik || !imza) return hata('invalid-argument', 'Anahtar ya da imza bozuk.');

  if (islem === 'sil') {
    if (!tamSayi(veri.zaman) || Math.abs(veri.zaman - simdi) > SAAT_PAYI_SN) {
      return hata('failed-precondition', 'Bilgisayarın saati yanlış.');
    }
    if (!imzaDogru(acik, silmeMesaji(veri), imza)) return hata('permission-denied', 'İmza geçersiz.');
    return { ok: true, islem, kanal: kanalKimligi(veri.okulId, acik), id: veri.id };
  }

  const { olusturma, baslangic, bitis, baslik, metin } = veri;
  if (![olusturma, baslangic, bitis].every(tamSayi)) return hata('invalid-argument', 'Tarih alanları geçersiz.');
  if (Math.abs(olusturma - simdi) > SAAT_PAYI_SN) {
    return hata('failed-precondition', 'Bilgisayarın saati yanlış.');
  }
  if (bitis <= baslangic || bitis <= simdi || bitis - olusturma > EN_UZUN_SN) {
    return hata('invalid-argument', 'Bitiş tarihi geçersiz (en çok 60 gün).');
  }
  if (typeof baslik !== 'string' || !baslik.trim() || baslik.length > BASLIK_SINIRI || /[\r\n]/.test(baslik)) {
    return hata('invalid-argument', `Başlık 1-${BASLIK_SINIRI} karakter, tek satır olmalı.`);
  }
  if (typeof metin !== 'string' || metin.length > METIN_SINIRI) {
    return hata('invalid-argument', `Metin en çok ${METIN_SINIRI} karakter.`);
  }
  const duyuru = { okulId: veri.okulId, id: veri.id, olusturma, baslangic, bitis, baslik, metin };
  if (!imzaDogru(acik, yayinMesaji(duyuru), imza)) return hata('permission-denied', 'İmza geçersiz.');

  return {
    ok: true,
    islem,
    kanal: kanalKimligi(veri.okulId, acik),
    id: veri.id,
    // Telefon imzayı kendisi doğrulasın diye imza ve anahtar da saklanır.
    belge: { ...duyuru, imza: veri.imza, acik: veri.acik },
  };
}

/**
 * Doğrulanmış isteği uygular. Süresi geçenleri de temizler: kanal en çok
 * 60 günlük duyuru tutar, telefon az okur.
 */
export async function uygula(db, istek, simdi) {
  const duyurular = db.collection('okul_duyurulari').doc(istek.kanal).collection('duyurular');
  const ref = duyurular.doc(istek.id);

  if (istek.islem === 'sil') {
    await ref.delete();
    return { ok: true };
  }

  const tumu = await duyurular.get();
  const toplu = db.batch();
  let son24 = 0;
  for (const d of tumu.docs) {
    const v = d.data();
    if (Number(v.bitis) <= simdi) toplu.delete(d.ref);
    else if (Number(v.olusturma) > simdi - 24 * 3600) son24 += 1;
  }
  await toplu.commit();
  if (tumu.docs.some((d) => d.id === istek.id)) return { ok: true, zatenVar: true };
  if (son24 >= GUNLUK_SINIR) {
    return hata('resource-exhausted', `Bir günde en çok ${GUNLUK_SINIR} duyuru gönderilebilir.`);
  }
  await ref.set(istek.belge);
  return { ok: true };
}

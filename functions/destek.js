/**
 * Destek kodu — Ana Program parolasını yedeksiz sıfırlamak için.
 *
 * ## Neden (28 Eylül 2026)
 * Kullanıcı: "Bir okul şifresini unuttu diyelim. Bizimle iletişime
 * geçtiğinde şifre sıfırlama gibi işlemleri yapabilmemiz lazım."
 *
 * Ana Program internete çıkmıyor; biz o bilgisayara hiçbir şey
 * gönderemeyiz. Bu yüzden kod İMZA: program bir talep numarası
 * gösteriyor, biz `SCDESTEK1|<kurum kodu>|<talep>` metnini gizli
 * anahtarla imzalıyoruz, program gömülü açık anahtarla internetsiz
 * doğruluyor (`sinifcepte-tahta/ana_program/cekirdek/destek.py`).
 *
 * Kod yalnızca o okul ve o talep için geçerli; talep o bilgisayarda
 * üretiliyor, 24 saatlik ve tek kullanımlık.
 *
 * Saf işlevler burada: emülatörsüz test edilebilsinler.
 */
import { createPrivateKey, createPublicKey, sign } from 'node:crypto';

export const MESAJ_ONEKI = 'SCDESTEK1';
const ALFABE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/**
 * Elle yazımı temizler: büyük harf, yalnızca base32 alfabesi.
 * 0→O, 1→I, 8→B: alfabede bu rakamlar yok, telefonda okunurken karışıyor.
 * Ana Program'daki `_temizle` ile AYNI.
 */
export function temizle(metin) {
  const ust = String(metin ?? '')
    .toUpperCase()
    .replace(/0/g, 'O')
    .replace(/1/g, 'I')
    .replace(/8/g, 'B');
  return [...ust].filter((h) => ALFABE.includes(h)).join('');
}

/** Talep numarası: 8 karakter base32 (Ana Program `TALEP_UZUNLUGU`). */
export function talepCoz(metin) {
  const t = temizle(metin);
  return t.length === 8 ? t : null;
}

/** MEBBİS kurum kodu: Ana Program ilk kurulumda 6 hane istiyor. */
export function kurumKoduGecerli(kod) {
  return typeof kod === 'string' && /^\d{6}$/.test(kod);
}

/** İmzalanan metin — Ana Program `destek.mesaj` ile AYNI. */
export function mesaj(kurumKodu, talep) {
  return Buffer.from(`${MESAJ_ONEKI}|${kurumKodu}|${talep}`, 'ascii');
}

/** RFC 4648 base32, dolgusuz. */
export function base32(baytlar) {
  let bitler = 0;
  let deger = 0;
  let cikti = '';
  for (const b of baytlar) {
    deger = (deger << 8) | b;
    bitler += 8;
    while (bitler >= 5) {
      cikti += ALFABE[(deger >>> (bitler - 5)) & 31];
      bitler -= 5;
    }
  }
  if (bitler > 0) cikti += ALFABE[(deger << (5 - bitler)) & 31];
  return cikti;
}

/** 5'erli gruplar: telefonda okunurken yer kaybedilmesin. */
export function kodBicimle(imza) {
  return base32(imza).match(/.{1,5}/g).join('-');
}

// Ed25519 ham tohumu (32 bayt) PKCS#8 zarfına: Node ham anahtar almıyor.
const PKCS8_ONEK = Buffer.from('302e020100300506032b657004220420', 'hex');

function ozelAnahtar(tohumB64) {
  const tohum = Buffer.from(String(tohumB64 ?? '').trim(), 'base64');
  if (tohum.length !== 32) {
    throw new Error('Destek imza tohumu 32 bayt olmalı (DESTEK_IMZA_TOHUMU).');
  }
  return createPrivateKey({ key: Buffer.concat([PKCS8_ONEK, tohum]), format: 'der', type: 'pkcs8' });
}

/** 64 baytlık Ed25519 imzası. */
export function imzala(tohumB64, govde) {
  return sign(null, govde, ozelAnahtar(tohumB64));
}

/** Tohumun açık anahtarı (base64) — Ana Program'a gömülü olanla karşılaştırmak için. */
export function acikAnahtar(tohumB64) {
  const der = createPublicKey(ozelAnahtar(tohumB64)).export({ format: 'der', type: 'spki' });
  // SPKI zarfının son 32 baytı ham açık anahtar.
  return der.subarray(der.length - 32).toString('base64');
}

/**
 * Kod üretme isteğini doğrular.
 *
 * `gerekce` zorunlu: kimin istediği ve nasıl teyit edildiği denetim
 * kaydına girsin ("Müdür Ahmet Bey aradı, kod okul e-postasına").
 */
export function istekDogrula(veri) {
  const kurumKodu = String(veri?.kurumKodu ?? '').trim();
  if (!kurumKoduGecerli(kurumKodu)) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Kurum kodu 6 haneli olmalı.' };
  }
  const talep = talepCoz(veri?.talep);
  if (!talep) {
    return {
      ok: false,
      kod: 'invalid-argument',
      mesaj: 'Talep numarası 8 karakter olmalı (ör. K7MQ-2XPA).',
    };
  }
  const gerekce = typeof veri?.gerekce === 'string' ? veri.gerekce.trim() : '';
  if (!gerekce || gerekce.length > 500) {
    return {
      ok: false,
      kod: 'invalid-argument',
      mesaj: 'Kimin istediğini ve nasıl teyit ettiğinizi yazın (en fazla 500 karakter).',
    };
  }
  return { ok: true, kurumKodu, talep, gerekce };
}

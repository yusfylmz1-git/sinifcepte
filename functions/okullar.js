/**
 * Okullar ve kişiler — panel görünümünün saf mantığı.
 *
 * ## Neden
 * Kullanıcı (28 Eylül 2026): "Bize kayıtlı okulları ve kişileri
 * yönetebilmemiz çok önemli." Okul arayınca kimlerin kayıtlı olduğu,
 * kimin yönetici olduğu ve o okulda neler yapıldığı görünmeli.
 *
 * Kişisel veri (ad, e-posta) gösteriliyor: yalnızca yöneticiye, ve her
 * görüntüleme denetim kaydına yazılıyor (kim, hangi okulu/kişiyi, ne
 * zaman). Öğrenci verisi bu görünümde YOK — zaten buluta çıkmıyor.
 */

/**
 * Panelde yazılan okulu kanonik kimliğe çevirir.
 *
 *   "775214"      → "meb_775214"   (MEBBİS kurum kodu)
 *   "meb_775214"  → "meb_775214"
 *   "man_ozel_1"  → "man_ozel_1"   (elle eklenmiş okul)
 *
 * Geçersizse null: kimlik belge yoluna ve sorguya giriyor.
 */
export function okulKimligiCoz(girdi) {
  const temiz = String(girdi ?? '').trim();
  if (/^\d{6,8}$/.test(temiz)) return `meb_${temiz}`;
  if (/^(meb|man)_[A-Za-z0-9_-]{1,64}$/.test(temiz)) return temiz;
  return null;
}

/** E-posta biçimi (yalnızca kaba denetim; asıl kontrol Auth'ta). */
export function epostaGecerli(eposta) {
  return typeof eposta === 'string' && eposta.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(eposta.trim());
}

/** Dizin kaydından panelde gösterilecek alanlar. */
export function ogretmenOzeti(belge) {
  const d = belge || {};
  return {
    uid: String(d.teacherUid ?? ''),
    ad: String(d.fullName ?? ''),
    brans: String(d.branch ?? ''),
    eposta: String(d.email ?? ''),
    guncelleme: String(d.updatedAt ?? ''),
  };
}

/**
 * Öğretmen listesine yöneticilik durumunu ekler.
 *
 * Kaynak başvuru belgeleri (`school_admin_requests`), claim değil:
 * claim'i okumak her öğretmen için bir Auth çağrısı olurdu. Belge,
 * `decideSchoolAdmin` ile claim'den hemen sonra yazılıyor.
 */
export function yoneticilikEkle(ogretmenler, basvurular) {
  const durum = new Map();
  for (const b of basvurular || []) {
    if (b?.teacher_uid) {
      durum.set(String(b.teacher_uid), b.revoked_at ? 'geri_alindi' : String(b.status ?? ''));
    }
  }
  return (ogretmenler || []).map((o) => ({ ...o, yoneticilik: durum.get(o.uid) ?? '' }));
}

/**
 * Denetim kaydını panele uygun biçime getirir (en yeni başta).
 *
 * Firestore zaman damgası `toDate()` taşıyor; saf test için düz ISO
 * metin ya da Date de kabul ediliyor.
 */
export function kayitOzetleri(belgeler) {
  const iso = (z) => {
    if (!z) return '';
    if (typeof z.toDate === 'function') return z.toDate().toISOString();
    if (z instanceof Date) return z.toISOString();
    return String(z);
  };
  return (belgeler || [])
    .map((d) => ({
      tur: String(d?.tur ?? ''),
      eposta: String(d?.email ?? ''),
      karar: String(d?.karar ?? ''),
      gerekce: String(d?.gerekce ?? ''),
      hedefUid: String(d?.hedefUid ?? ''),
      zaman: iso(d?.olusturmaZamani),
    }))
    .sort((a, b) => b.zaman.localeCompare(a.zaman));
}

/**
 * Dizinden çıkarma isteğini doğrular.
 *
 * @returns {{ok: true, okulId: string, uid: string, gerekce: string} |
 *           {ok: false, kod: string, mesaj: string}}
 */
export function cikarmaDogrula(veri) {
  const okulId = okulKimligiCoz(veri?.okulId);
  if (!okulId) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Geçersiz okul kimliği.' };
  }
  const uid = typeof veri?.uid === 'string' ? veri.uid.trim() : '';
  if (!uid || uid.length > 128 || uid.includes('/')) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Geçersiz kullanıcı kimliği.' };
  }
  const gerekce = typeof veri?.gerekce === 'string' ? veri.gerekce.trim() : '';
  if (!gerekce || gerekce.length > 500) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Gerekçe zorunlu (en fazla 500 karakter).' };
  }
  return { ok: true, okulId, uid, gerekce };
}

/** Dizin belgesinin kimliği — mobil `school_directory_repository.dart` ile aynı. */
export const dizinKimligi = (okulId, uid) => `${okulId}_${uid}`;

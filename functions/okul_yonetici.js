/**
 * Okul yöneticiliği başvurusu — karar mantığı (Firebase'e bağlı değil).
 *
 * ## Neden (Y17, ikinci yarı)
 * Karar yalnızca süper yöneticinin bilgisayarındaki komut satırı
 * betiğiyle (`scripts/admin/approve_school_admin.mjs`) veriliyordu:
 * servis hesabı anahtarı + terminal. 1000 okulda sürdürülemez. Karar
 * (28 Eylül 2026): onay sunucu fonksiyonuyla ve panelden.
 *
 * Yetkiyi yine custom claim veriyor ve claim yalnızca sunucuda
 * yazılıyor; panel yalnızca "şunu onayla" diyor. `firestore.rules`
 * değişmedi: başvuranın kendi kaydını onaylayamaması aynen duruyor.
 *
 * Saf işlevler burada: emülatörsüz test edilebilsinler.
 */

export const KARARLAR = new Set(['onay', 'red', 'geri_al']);

/** Başvuru belgesinin kimliği — mobil `SchoolAdminRequestModel` ile aynı. */
export const basvuruKimligi = (uid) => `req_${uid}`;

/**
 * Karar isteğini doğrular.
 *
 * @param {unknown} veri { uid, karar, gerekce? }
 * @returns {{ok: true, uid: string, karar: string, gerekce: string} |
 *           {ok: false, kod: string, mesaj: string}}
 */
export function kararDogrula(veri) {
  const uid = typeof veri?.uid === 'string' ? veri.uid.trim() : '';
  // Firebase uid: 1-128 karakter; belge yoluna girdiği için '/' olamaz.
  if (!uid || uid.length > 128 || uid.includes('/')) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Geçersiz kullanıcı kimliği.' };
  }
  const karar = veri?.karar;
  if (!KARARLAR.has(karar)) {
    return { ok: false, kod: 'invalid-argument', mesaj: `Bilinmeyen karar: ${karar}` };
  }
  const gerekce = typeof veri?.gerekce === 'string' ? veri.gerekce.trim() : '';
  if (gerekce.length > 500) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Gerekçe en fazla 500 karakter.' };
  }
  // Ret ve geri alma öğretmene gösteriliyor: sebepsiz ret "neden?"
  // sorusunu destek kuyruğuna taşır.
  if ((karar === 'red' || karar === 'geri_al') && !gerekce) {
    return { ok: false, kod: 'invalid-argument', mesaj: 'Ret ve geri almada gerekçe zorunlu.' };
  }
  return { ok: true, uid, karar, gerekce };
}

/**
 * Hangi başvuru durumunda hangi karar verilebilir?
 *
 * - onay/red: yalnızca BEKLEYEN başvuru. Onaylanmış birini "reddetmek"
 *   yetkiyi almaz gibi görünür ama kafa karıştırır; onun adı geri_al.
 * - geri_al: yalnızca ONAYLANMIŞ başvuru.
 */
export function kararUygunMu(durum, karar) {
  if (karar === 'geri_al') {
    return durum === 'approved'
      ? { ok: true }
      : { ok: false, kod: 'failed-precondition', mesaj: 'Yalnızca onaylanmış yöneticilik geri alınabilir.' };
  }
  return durum === 'pending'
    ? { ok: true }
    : {
        ok: false,
        kod: 'failed-precondition',
        mesaj: `Bu başvuru zaten karara bağlanmış (${durum}). Sayfayı yenileyin.`,
      };
}

/**
 * Yeni custom claim'ler — DİĞER yetkiler korunarak.
 *
 * `setCustomUserClaims` claim nesnesinin TAMAMINI değiştirir: yalnızca
 * yöneticilik alanlarını yazmak, kullanıcının `adminRole` gibi başka
 * yetkilerini silerdi.
 *
 * `schoolId` şart: `firestore.rules` yöneticinin yalnızca KENDİ okulunu
 * görmesini bu alanla sınırlıyor.
 */
export function yeniClaimler(mevcut, karar, okulId) {
  const claimler = { ...(mevcut || {}) };
  if (karar === 'onay') {
    claimler.schoolAdminStatus = 'approved';
    claimler.schoolId = okulId;
  } else {
    delete claimler.schoolAdminStatus;
    delete claimler.schoolId;
  }
  return claimler;
}

/**
 * Başvuru belgesine yazılacak alanlar (mobil snake_case alan adları).
 *
 * ## Geri alma neden 'rejected'
 * Mobil `SchoolAdminRequestModel.parseStatus` yalnızca pending /
 * approved / rejected tanıyor; bilinmeyen durum "Başvuru yok" diye
 * görünürdü. Geri alma 'rejected' + açıklayıcı gerekçe olarak yazılıyor
 * (öğretmen "Reddedildi — Yöneticilik geri alındı: …" görür); panel
 * `revoked_at` alanıyla ayırt ediyor. Mobil kod değişmedi.
 */
export function basvuruGuncellemesi(karar, kararVerenUid, gerekce, simdiIso) {
  const g = {
    status: karar === 'onay' ? 'approved' : 'rejected',
    decided_at: simdiIso,
    decided_by_uid: kararVerenUid,
  };
  if (karar === 'red') g.rejection_reason = gerekce;
  if (karar === 'geri_al') {
    g.rejection_reason = `Yöneticilik geri alındı: ${gerekce}`;
    g.revoked_at = simdiIso;
  }
  return g;
}

/**
 * Onay yalnızca kanonik okul kimliğine verilir.
 *
 * `school_boards/{schoolId}` ve kurallar `meb_*` / `man_*` kimliğine
 * dayanıyor; serbest metin okul adıyla verilen yetki hiçbir okula
 * bağlanmaz ama claim'de durur.
 */
export function okulKimligiGecerli(okulId) {
  return typeof okulId === 'string' && /^(meb|man)_[A-Za-z0-9_-]{1,64}$/.test(okulId);
}

/** Panelde gösterilecek satır — belgeden yalnızca gereken alanlar. */
export function basvuruOzeti(belge, dizindeMi) {
  const d = belge || {};
  return {
    uid: String(d.teacher_uid ?? ''),
    ad: String(d.teacher_name ?? ''),
    eposta: String(d.teacher_email ?? ''),
    okulId: String(d.school_id ?? ''),
    okulAdi: String(d.school_name ?? ''),
    il: String(d.city ?? ''),
    ilce: String(d.district ?? ''),
    not: String(d.note ?? ''),
    durum: String(d.status ?? ''),
    tarih: String(d.requested_at ?? ''),
    kararTarihi: String(d.decided_at ?? ''),
    gerekce: String(d.rejection_reason ?? ''),
    geriAlindi: Boolean(d.revoked_at),
    // Karar için kanıt: başvuran bu okulun öğretmen dizininde mi?
    dizindeMi: Boolean(dizindeMi),
    okulKimligiGecerli: okulKimligiGecerli(d.school_id),
  };
}

export const LISTE_DURUMLARI = new Set(['pending', 'approved', 'rejected']);

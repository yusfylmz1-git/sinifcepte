/**
 * Panel düğmeleri — satır içi olay işleyicisi YOK.
 *
 * ## Neden
 * Panelde 92 `onclick="window.adminApp..."` vardı. Güvenlik başlığı
 * (`Content-Security-Policy`, `script-src 'self'`) satır içi işleyicileri
 * engelliyor: başlık zorunlu olsaydı panelin HİÇBİR düğmesi çalışmazdı.
 * Raporlayan kipte de her tıklama konsola ihlal yazardı ve "bir hafta
 * konsolda sorun görünmezse zorunlu yap" kararı hiç sağlanamazdı
 * (29 Eylül 2026).
 *
 * `'unsafe-inline'` eklemek çözüm değil: XSS'e karşı asıl korumayı,
 * yani enjekte edilen betiğin çalışmamasını ortadan kaldırır.
 *
 * ## Nasıl
 * Düğme ne yapacağını data-* öznitelikleriyle söylüyor; bu dosya belge
 * düzeyinde dinleyip `window.adminApp`'in yöntemini çağırıyor. Sonradan
 * üretilen satırlar (tablo düğmeleri) da aynı yolla çalışıyor.
 *
 *   data-eylem="yontem"   tıklayınca  adminApp.yontem(...)
 *   data-degisim="yontem" değişince   (select, dosya girdisi)
 *   data-girdi="yontem"   yazınca     (arama kutusu)
 *   data-sekme="takvim"   önce sekmeye geç (data-eylem ile birlikte de olur)
 *   data-tikla="kimlik"   o öğeye tıkla (gizli dosya girdisi)
 *
 * Argümanlar, bu sırayla:
 *   data-arg="x"  → "x"          data-deger → öğenin değeri
 *   data-olay     → olay nesnesi data-oge   → öğenin kendisi
 *
 * Değer yalnızca öznitelik olarak kaçırılıyor; artık JS dizesi içine
 * gömülmediği için ikinci kaçış katmanı gerekmiyor.
 */
(function (kok) {
  'use strict';

  /** `adminApp` dışındaki eylemler. */
  const OZEL = {
    tumVeriyiIndir: (a) =>
      kok.CloudExporter.exportAllBundle(
        a.calendarManager,
        a.outcomesManager,
        a.manifestManager,
        a.examsManager
      ),
    takvimiIndir: (a) => kok.CloudExporter.exportCalendar(a.calendarManager),
    manifestiIndir: (a) => kok.CloudExporter.exportManifest(a.manifestManager),
    kazanimlariIndir: (a) => kok.CloudExporter.exportOutcomes(a.outcomesManager),
    girisYap: () => kok.SinifCepteAdminAuth.signIn(),
    cikisYap: () => kok.SinifCepteAdminAuth.signOut(),
  };

  // Yalnızca düz yöntem adı; `constructor` gibi nesne iç yapısı çağrılmasın.
  const YONTEM_ADI = /^[A-Za-z][A-Za-z0-9]*$/;
  const YASAK = new Set(['constructor']);

  function argumanlar(el, olay) {
    const d = el.dataset;
    const liste = [];
    if ('arg' in d) liste.push(d.arg);
    if ('deger' in d) liste.push(el.value);
    if ('olay' in d) liste.push(olay);
    if ('oge' in d) liste.push(el);
    return liste;
  }

  /** Adı verilen eylemi çalıştırır; bulunamazsa konsola yazar. */
  function cagir(ad, el, olay) {
    const app = kok.adminApp;
    const args = argumanlar(el, olay);
    let sonuc;
    if (Object.prototype.hasOwnProperty.call(OZEL, ad)) {
      sonuc = OZEL[ad](app, ...args);
    } else if (
      YONTEM_ADI.test(ad) &&
      !YASAK.has(ad) &&
      app &&
      typeof app[ad] === 'function'
    ) {
      sonuc = app[ad](...args);
    } else {
      // Sessiz kalmıyoruz: ölü düğme sebebi görünmeyen hatadır.
      console.error(`Panel eylemi bulunamadı: ${ad}`);
      return;
    }
    if (sonuc && typeof sonuc.then === 'function') {
      sonuc.catch((e) => console.error(`Panel eylemi başarısız: ${ad}`, e));
    }
  }

  function tiklama(olay) {
    const hedef = olay.target;
    const el =
      hedef && hedef.closest
        ? hedef.closest('[data-eylem],[data-sekme],[data-tikla]')
        : null;
    if (!el) return;
    // `<a href="#">` adres çubuğuna # eklemesin, sayfa başa kaymasın.
    if (el.tagName === 'A' && el.getAttribute('href') === '#') {
      olay.preventDefault();
    }
    const d = el.dataset;
    if (d.sekme) kok.adminApp.switchTab(d.sekme);
    if (d.tikla) {
      const ic = kok.document.getElementById(d.tikla);
      if (ic) ic.click();
      else console.error(`Panel öğesi bulunamadı: ${d.tikla}`);
    }
    if (d.eylem) cagir(d.eylem, el, olay);
  }

  function dinleyici(oznitelik, anahtar) {
    return (olay) => {
      const hedef = olay.target;
      const el = hedef && hedef.closest ? hedef.closest(`[${oznitelik}]`) : null;
      if (el) cagir(el.dataset[anahtar], el, olay);
    };
  }

  kok.SinifCepteEylemler = { OZEL, cagir, tiklama };

  kok.document.addEventListener('click', tiklama);
  kok.document.addEventListener('change', dinleyici('data-degisim', 'degisim'));
  kok.document.addEventListener('input', dinleyici('data-girdi', 'girdi'));
})(window);

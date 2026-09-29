/**
 * Panelin güvenlik başlığı (CSP) ile uyumu.
 *
 * ## Neden
 * Panelde 92 satır içi `onclick` vardı ve `script-src 'self'` bunları
 * engelliyor: başlık zorunlu olsaydı hiçbir düğme çalışmazdı (29 Eylül
 * 2026). Düğmeler artık `data-eylem` ile `js/eylemler.js` üzerinden
 * çalışıyor. Bu testler iki şeyi kilitliyor:
 *
 * 1. Satır içi işleyici geri gelmesin.
 * 2. Her `data-eylem` gerçekten var olan bir yöntemi göstersin — elle
 *    yapılan dönüşümdeki tek harflik yazım hatası ölü düğme demek ve
 *    ancak tıklanınca konsolda görünür.
 *
 * Karar (28 Eylül 2026): başlık önce yalnızca RAPORLAYAN kipte
 * yayımlanır; bir hafta tarayıcı konsolunda ihlal görünmezse zorunlu
 * (`Content-Security-Policy`) yapılır.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import vm from 'node:vm';

const oku = (yol) => readFileSync(new URL(yol, import.meta.url), 'utf8');
const PANEL = '../../admin_portal/';

/** Yorumları eler (belgeler eski `onclick` örneklerini anlatıyor). */
function kodu(kaynak) {
  return kaynak
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');
}

const indexHtml = oku(PANEL + 'index.html');
const jsDosyalari = readdirSync(new URL(PANEL + 'js/', import.meta.url))
  .filter((ad) => ad.endsWith('.js'))
  .map((ad) => ({ ad, kod: kodu(oku(PANEL + 'js/' + ad)) }));
const adminApp = jsDosyalari.find((d) => d.ad === 'admin_app.js').kod;
const eylemlerKaynak = oku(PANEL + 'js/eylemler.js');

/** HTML yorumları dışındaki işaretleme. */
const isaretleme = indexHtml.replace(/<!--[\s\S]*?-->/g, '');

// --- 1. Satır içi işleyici yok ---

test('KRITIK: index.html’de satır içi olay işleyicisi yok', () => {
  const bulunan = isaretleme.match(/<[^>]*\son[a-z]+\s*=/gi) || [];
  assert.deepEqual(bulunan, [], bulunan.join('\n'));
});

test('KRITIK: JS’in ürettiği HTML’de satır içi olay işleyicisi yok', () => {
  for (const { ad, kod } of jsDosyalari) {
    const bulunan = kod.match(/\son(click|change|input|submit|key\w+|mouse\w+)\s*=\s*["']/gi);
    assert.equal(bulunan, null, `${ad}: ${bulunan}`);
  }
});

test('KRITIK: satır içi <script> bloğu yok', () => {
  const bloklar = isaretleme.match(/<script(?![^>]*\ssrc=)[^>]*>/gi) || [];
  assert.deepEqual(bloklar, []);
});

// --- 2. Her eylem var olan bir yöntemi gösteriyor ---

/** AdminApp sınıfındaki yöntem adları. */
const yontemler = new Set(
  [...adminApp.matchAll(/^ {2}(?:async\s+)?([A-Za-z][A-Za-z0-9]*)\s*\([^)]*\)\s*\{/gm)].map(
    (m) => m[1]
  )
);

/**
 * Ayrı dosyalarda `Object.assign(window.AdminApp.prototype, {...})` ile
 * eklenen yöntemler (ör. okul_yonetimi.js). Yalnızca o blok taranıyor:
 * başka sınıfların yöntemleri sayılsaydı yanlış yere bağlı düğme geçerdi.
 */
for (const { kod } of jsDosyalari) {
  const bas = kod.indexOf('Object.assign(window.AdminApp.prototype, {');
  if (bas < 0) continue;
  for (const m of kod.slice(bas).matchAll(/^ {4}(?:async\s+)?([A-Za-z][A-Za-z0-9]*)\s*\([^)]*\)\s*\{/gm)) {
    yontemler.add(m[1]);
  }
}

/** eylemler.js'teki özel eylemler (adminApp dışı). */
const ozel = new Set(
  [...eylemlerKaynak.match(/const OZEL = \{([\s\S]*?)\n {2}\};/)[1].matchAll(/^ {4}(\w+):/gm)].map(
    (m) => m[1]
  )
);

function eylemAdlari(metin) {
  return [...metin.matchAll(/data-(?:eylem|degisim|girdi)="([^"$]+)"/g)].map((m) => m[1]);
}

test('KRITIK: her data-eylem gerçek bir yöntemi gösteriyor', () => {
  assert.ok(yontemler.size > 50, `yöntem listesi okunamadı (${yontemler.size})`);
  const adlar = [
    ...eylemAdlari(isaretleme),
    ...jsDosyalari.flatMap(({ kod }) => eylemAdlari(kod)),
  ];
  assert.ok(adlar.length >= 80, `beklenenden az eylem: ${adlar.length}`);
  const olmayan = [...new Set(adlar)].filter((ad) => !yontemler.has(ad) && !ozel.has(ad));
  assert.deepEqual(olmayan, []);
});

test('her data-sekme gerçek bir sekmeyi gösteriyor', () => {
  for (const [, sekme] of isaretleme.matchAll(/data-sekme="([^"]+)"/g)) {
    assert.ok(isaretleme.includes(`id="tab-${sekme}"`), sekme);
  }
});

test('her data-tikla gerçek bir öğeyi gösteriyor', () => {
  for (const [, kimlik] of isaretleme.matchAll(/data-tikla="([^"]+)"/g)) {
    assert.ok(isaretleme.includes(`id="${kimlik}"`), kimlik);
  }
});

test('eylemler.js paneli yükleyen betiklerle birlikte yükleniyor', () => {
  const sira = [...isaretleme.matchAll(/<script[^>]*src="js\/([^"?]+)/g)].map((m) => m[1]);
  assert.ok(sira.indexOf('eylemler.js') > sira.indexOf('admin_app.js'));
  // Eklenti dosyaları AdminApp tanımlandıktan SONRA.
  for (const { ad, kod } of jsDosyalari) {
    if (kod.includes('window.AdminApp.prototype')) {
      assert.ok(sira.indexOf(ad) > sira.indexOf('admin_app.js'), ad);
    }
  }
});

// --- 3. Dağıtıcının davranışı ---

function ortam() {
  const dinleyiciler = {};
  const cagrilar = [];
  const hatalar = [];
  const app = new Proxy(
    {},
    {
      get(_, ad) {
        if (ad === 'then') return undefined;
        return (...args) => cagrilar.push([ad, ...args]);
      },
    }
  );
  const window = {
    adminApp: app,
    CloudExporter: { exportCalendar: (m) => cagrilar.push(['exportCalendar', m]) },
    document: {
      addEventListener: (tur, fn) => (dinleyiciler[tur] = fn),
      getElementById: (id) => ({ click: () => cagrilar.push(['click', id]) }),
    },
  };
  app.calendarManager; // Proxy: özellik de işlev döner, önemsiz.
  vm.runInNewContext(eylemlerKaynak, {
    window,
    console: { error: (...a) => hatalar.push(a.join(' ')) },
  });
  return { dinleyiciler, cagrilar, hatalar };
}

function oge(dataset, ek = {}) {
  const el = {
    dataset,
    tagName: 'BUTTON',
    getAttribute: () => null,
    ...ek,
  };
  el.closest = () => el;
  return el;
}

test('KRITIK: tıklama yöntemi argümanlarıyla çağırıyor', () => {
  const { dinleyiciler, cagrilar } = ortam();
  const el = oge({ eylem: 'setCategoryFilter', arg: 'core', oge: '' });
  dinleyiciler.click({ target: el, preventDefault() {} });
  assert.equal(cagrilar.length, 1);
  assert.equal(cagrilar[0][0], 'setCategoryFilter');
  assert.equal(cagrilar[0][1], 'core');
  assert.equal(cagrilar[0][2], el);
});

test('sekme önce, eylem sonra', () => {
  const { dinleyiciler, cagrilar } = ortam();
  dinleyiciler.click({
    target: oge({ sekme: 'calendar', eylem: 'openCalendarWizardModal' }),
    preventDefault() {},
  });
  assert.deepEqual(
    cagrilar.map((c) => c.slice(0, 2)),
    [['switchTab', 'calendar'], ['openCalendarWizardModal']]
  );
});

test('değişim öğenin değerini, dosya girdisi olay nesnesini veriyor', () => {
  const { dinleyiciler, cagrilar } = ortam();
  dinleyiciler.change({ target: oge({ degisim: 'handleCalendarYearChange', deger: '' }, { value: '2027' }) });
  const olay = { target: oge({ degisim: 'importExamsJSON', olay: '' }) };
  dinleyiciler.change(olay);
  assert.deepEqual(cagrilar[0], ['handleCalendarYearChange', '2027']);
  assert.equal(cagrilar[1][1], olay);
});

test('arama kutusu yazdıkça çağırıyor', () => {
  const { dinleyiciler, cagrilar } = ortam();
  dinleyiciler.input({ target: oge({ girdi: 'handleExamsSearch', deger: '' }, { value: 'lgs' }) });
  assert.deepEqual(cagrilar[0], ['handleExamsSearch', 'lgs']);
});

test('özel eylem adminApp dışına gidiyor; data-tikla öğeye tıklıyor', () => {
  const { dinleyiciler, cagrilar } = ortam();
  dinleyiciler.click({ target: oge({ eylem: 'takvimiIndir' }), preventDefault() {} });
  dinleyiciler.click({ target: oge({ tikla: 'exams-file-input' }), preventDefault() {} });
  assert.equal(cagrilar[0][0], 'exportCalendar');
  assert.deepEqual(cagrilar[1], ['click', 'exams-file-input']);
});

test('KRITIK: bozuk eylem adı çağrılmıyor, konsola yazılıyor', () => {
  const { dinleyiciler, cagrilar, hatalar } = ortam();
  for (const ad of ['constructor', 'a.b', 'x()', '__proto__']) {
    dinleyiciler.click({ target: oge({ eylem: ad }), preventDefault() {} });
  }
  assert.deepEqual(cagrilar, []);
  assert.equal(hatalar.length, 4);
});

test('eylemsiz tıklama hiçbir şey yapmıyor', () => {
  const { dinleyiciler, cagrilar } = ortam();
  const el = { closest: () => null };
  dinleyiciler.click({ target: el, preventDefault() {} });
  assert.deepEqual(cagrilar, []);
});

// --- 4. Başlık ---

const firebase = JSON.parse(oku('../../firebase.json'));
const basliklar = firebase.hosting.headers.flatMap((h) => h.headers);
const csp = basliklar.find((b) => b.key.startsWith('Content-Security-Policy'));
const yonergeler = Object.fromEntries(
  csp.value.split(';').map((y) => {
    const [ad, ...kaynaklar] = y.trim().split(/\s+/);
    return [ad, kaynaklar];
  })
);

test('KRITIK: başlık şimdilik RAPORLAYAN kipte (karar: bir hafta gözlem)', () => {
  assert.equal(csp.key, 'Content-Security-Policy-Report-Only');
});

test('KRITIK: script-src satır içi betiğe izin vermiyor', () => {
  assert.ok(!yonergeler['script-src'].includes("'unsafe-inline'"));
  assert.ok(!yonergeler['script-src'].includes("'unsafe-eval'"));
});

test('KRITIK: paneldeki her dış betik başlıkta izinli', () => {
  const kaynaklar = [
    ...[...isaretleme.matchAll(/<script[^>]*\ssrc="(https:[^"]+)"/g)].map((m) => m[1]),
    ...[...kodu(oku(PANEL + 'js/auth_gate.js')).matchAll(/from '(https:[^']+)'/g)].map((m) => m[1]),
  ];
  assert.ok(kaynaklar.length >= 4);
  for (const adres of kaynaklar) {
    const kok = new URL(adres).origin;
    assert.ok(yonergeler['script-src'].includes(kok), `${kok} script-src’te yok`);
  }
});

test('KRITIK: Google girişinin açılır pencere düzeni izinli', () => {
  // signInWithPopup apis.google.com'dan betik yüklüyor ve
  // authDomain'den gizli bir çerçeve açıyor. Biri eksik olsaydı başlık
  // zorunlu hâle gelince panele hiç girilemezdi.
  const authDomain = oku(PANEL + 'js/auth_gate.js').match(/authDomain: '([^']+)'/)[1];
  assert.ok(yonergeler['script-src'].includes('https://apis.google.com'));
  assert.ok(yonergeler['frame-src'].includes(`https://${authDomain}`));
});

test('paneldeki her dış stil başlıkta izinli', () => {
  for (const [, adres] of isaretleme.matchAll(/<link[^>]*rel="stylesheet"[^>]*href="(https:[^"]+)"/g)) {
    assert.ok(yonergeler['style-src'].includes(new URL(adres).origin), adres);
  }
});

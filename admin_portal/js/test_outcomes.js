/**
 * SınıfCepte Admin Paneli - Kazanım yöneticisi testleri
 *
 *   node admin_portal/js/test_outcomes.js
 */

const assert = require('assert');
const path = require('path');

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ok   ${name}`);
    passed += 1;
  } catch (error) {
    console.log(`  FAIL ${name}\n       ${error.message}`);
    failed += 1;
  }
}

/** Tarayıcı localStorage'ını kota sınırıyla birlikte taklit eder. */
function makeStorage(quotaBytes = 5 * 1024 * 1024) {
  const store = {};
  return {
    store,
    api: {
      getItem: (k) => (k in store ? store[k] : null),
      setItem: (k, v) => {
        v = String(v);
        if (v.length > quotaBytes) {
          const e = new Error(`Setting the value of '${k}' exceeded the quota.`);
          e.name = 'QuotaExceededError';
          throw e;
        }
        store[k] = v;
      },
      removeItem: (k) => { delete store[k]; },
    },
  };
}

function loadManager(storage) {
  // Modüller window üzerine yazar; her testte temiz bir ortam kurulur.
  global.localStorage = storage.api;
  global.window = { localStorage: storage.api };
  delete require.cache[require.resolve(path.resolve('admin_portal/js/curriculum_presets.js'))];
  delete require.cache[require.resolve(path.resolve('admin_portal/js/outcomes_manager.js'))];
  require(path.resolve('admin_portal/js/curriculum_presets.js'));
  global.CurriculumPresets = global.window.CurriculumPresets;
  require(path.resolve('admin_portal/js/outcomes_manager.js'));
  return global.window.OutcomesManager;
}

console.log('\nOutcomesManager - localStorage kotası');

test('Kota dolu olsa bile yapıcı çökmez', () => {
  // ASIL HATA: tüm kayıtları (~9 MB) localStorage'a yazmak
  // QuotaExceededError fırlatıyordu; hata yapıcıdan sızınca AdminApp hiç
  // kurulmuyor ve paneldeki HİÇBİR düğme çalışmıyordu.
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  assert.ok(om.outcomes.length > 0, 'kayıtlar yüklenmeli');
});

test('Tüm veri localStorage\'a yazılmaz', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  om.save();
  const written = storage.store[OM.OVERRIDES_KEY] || '';
  assert.ok(written.length < 10 * 1024,
    `düzenleme yokken yazım küçük olmalı, ${written.length} bayt yazıldı`);
  assert.strictEqual(storage.store['sinifcepte_admin_outcomes'], undefined,
    'eski dev kayıt bırakılmamalı');
});

test('Elle düzenleme saklanır ve yeniden yüklenir', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const targetId = om.outcomes[3].id;
  om.outcomes[3].outcomeDescription = 'ELLE DÜZENLENDİ';
  om.outcomes[3].maarifValues = 'D1. Adalet';
  assert.strictEqual(om.save(), true);

  const om2 = new OM();
  const reloaded = om2.outcomes.find((o) => o.id === targetId);
  assert.strictEqual(reloaded.outcomeDescription, 'ELLE DÜZENLENDİ');
  assert.strictEqual(reloaded.maarifValues, 'D1. Adalet');
});

test('Düzenlenmemiş kayıtlar paket verisinde kalır', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const untouchedId = om.outcomes[10].id;
  const original = om.outcomes[10].outcomeDescription;
  om.outcomes[3].outcomeDescription = 'DEĞİŞTİ';
  om.save();

  const om2 = new OM();
  const untouched = om2.outcomes.find((o) => o.id === untouchedId);
  assert.strictEqual(untouched.outcomeDescription, original);
});

test('Senkronizasyon elle düzenlemeleri temizler', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const targetId = om.outcomes[3].id;
  const original = om.outcomes[3].outcomeDescription;
  om.outcomes[3].outcomeDescription = 'DEĞİŞTİ';
  om.save();

  om.syncWithOfficialPresets();
  const after = om.outcomes.find((o) => o.id === targetId);
  assert.strictEqual(after.outcomeDescription, original);
});

test('Farklı yılın düzenlemeleri uygulanmaz', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const targetId = om.outcomes[3].id;
  const original = om.outcomes[3].outcomeDescription;

  storage.store[OM.OVERRIDES_KEY] =
    JSON.stringify({ [targetId]: { outcomeDescription: 'ESKİ YIL' } });
  storage.store[OM.YEAR_KEY] = '1999-2000';

  const om2 = new OM();
  const item = om2.outcomes.find((o) => o.id === targetId);
  assert.strictEqual(item.outcomeDescription, original);
});

console.log('\nOutcomesManager - veri bütünlüğü');

test('Paket dizisi doğrudan değiştirilmez', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  om.outcomes[0].outcomeDescription = 'MUTASYON';
  const presets = global.window.CurriculumPresets.getAllOfficialPresets();
  assert.notStrictEqual(presets[0].outcomeDescription, 'MUTASYON',
    'paket verisi kopyalanmadan kullanılıyor');
});

test('HTML kaçışı tablo bozulmasını önler', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  assert.strictEqual(OM.escapeHtml('<b>"x"</b>'), '&lt;b&gt;&quot;x&quot;&lt;/b&gt;');
  assert.strictEqual(OM.escapeHtml(null), '');
});

console.log('\nOutcomesManager - tablo yuku');

/** Tabloyu ve satır sayacını yakalayan sahte DOM. */
function makeDom() {
  const state = { html: '', info: '' };
  global.document = {
    getElementById: (id) => id === 'outcomes-row-info'
      ? {
          set textContent(v) { state.info = v; },
          get textContent() { return state.info; },
        }
      : {
          get innerHTML() { return state.html; },
          set innerHTML(v) { state.html = v; },
        },
  };
  return state;
}

test('Seçim yapılmadan tüm veri basılmaz', () => {
  // ASIL SORUN: 9000+ kaydı DOM'a basmak 27 MB HTML üretiyor ve
  // paneli kilitliyordu.
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const dom = makeDom();

  om.renderTable('ALL', 'ALL', 'ALL', 'ALL', 'ALL', '');
  assert.ok(dom.html.length < 5000,
    `secim yokken ${dom.html.length} bayt basildi`);
  assert.ok(dom.html.includes('bir sınıf veya ders seçin'),
    'yonlendirme mesaji yok');
});

test('Sınıf seçilince liste gelir ama üst sınır uygulanır', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const dom = makeDom();

  om.renderTable('ALL', 5, 'ALL', 'ALL', 'ALL', '');
  const rows = (dom.html.match(/<tr/g) || []).length;
  assert.ok(rows > 0, 'satir basilmadi');
  assert.ok(rows <= OM.MAX_ROWS, `${rows} satir basildi, sinir ${OM.MAX_ROWS}`);
  assert.ok(dom.info.includes('gösteriliyor'), 'sayac bilgisi yok');
});

test('Ders seçilince tüm haftalar tek sayfada görünür', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const dom = makeDom();

  om.renderTable('ALL', 5, 'MAT', 'ALL', 'ALL', '');
  const rows = (dom.html.match(/<tr/g) || []).length;
  assert.strictEqual(rows, 39, `39 hafta bekleniyordu, ${rows} geldi`);
  assert.ok(!dom.info.includes('gösteriliyor'), 'gereksiz kirpma uyarisi var');
});

test('Kısa arama listeyi açmaz, 3+ harf açar', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  assert.strictEqual(OM.isNarrowEnough('ALL', 'ALL', 'fo'), false);
  assert.strictEqual(OM.isNarrowEnough('ALL', 'ALL', 'fotosentez'), true);
  assert.strictEqual(OM.isNarrowEnough(5, 'ALL', ''), true);
  assert.strictEqual(OM.isNarrowEnough('ALL', 'MAT', ''), true);
});

test('Ders listesi kategori bilgisi taşır (gruplama için)', () => {
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const subjects = om.getAvailableSubjectsForGrade(5, 'MIDDLE');
  assert.ok(subjects.length > 0, 'ders bulunamadi');
  assert.ok(subjects.every((s) => s.category), 'kategori alani eksik');
  assert.ok(new Set(subjects.map((s) => s.category)).size > 1,
    'tek kategori var, gruplama anlamsiz');
});

test('KRITIK: temel dersler ustte siralanir', () => {
  // Kullanici istegi: "normal okullarda okutulan temel dersler ustte,
  // secmeliler ve cydem gibi dersler altta listelenmeli."
  //
  // Once Map ekleme sirasinda donuyordu — veri dosyasindaki siraya
  // bagliydi ve ongorulemezdi.
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  const subjects = om.getAvailableSubjectsForGrade(5, 'MIDDLE');
  const oncelik = (k) => {
    const c = (k || 'core').toLowerCase();
    return c === 'core' ? 0 : c === 'iho' ? 1 : 2;
  };
  for (let i = 1; i < subjects.length; i++) {
    assert.ok(
      oncelik(subjects[i - 1].category) <= oncelik(subjects[i].category),
      `siralama bozuk: ${subjects[i - 1].name} sonra ${subjects[i].name}`
    );
  }
});

test('KRITIK: Maarif rozeti metin aramasiyla basilmaz', () => {
  // Once publisher'da "Maarif"/"TYMM" geciyor mu diye bakiliyordu.
  // Olcum: 89 ders rozet almasi gerekirken almiyor, 2 ders yanlis
  // aliyordu. Veri artik gercek kaynagi tasiyor.
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  om.outcomes = [{
    docId: 'x', gradeLevel: 5, subjectCode: 'TURKCE', subjectName: 'Turkce',
    // Yaniltici metin: publisher'da "Maarif" geciyor AMA veri eski
    // programa ait diyor.
    publisher: 'TYMM (Maarif Modeli)',
    isMaarif: false, sourceProgram: 'legacy',
    weekNumber: 1, unitTitle: 'Okuma', topicTitle: 'Okuma',
    outcomeDescription: 'Metni anlayabilme', academicYear: '2026-2027',
  }];
  const dom = makeDom();
  om.renderTable('ALL', 5, 'TURKCE', 'ALL', 'ALL', '');
  assert.ok(!dom.html.includes('Maarif Modeli') || !dom.html.includes('• Maarif'),
    'metinde "Maarif" gectigi icin rozet basilmis');
});

test('KRITIK: OTP haftasi hafta numarasindan tahmin edilmez', () => {
  // 8, 17, 29 sabitleri varsayiliyordu. Bu haftalar MEB'in her yil
  // tebligle belirledigi takvime gore DEGISIYOR; sabit numara
  // varsaymak yanlis haftayi isaretler.
  const storage = makeStorage();
  const OM = loadManager(storage);
  const om = new OM();
  om.outcomes = [{
    docId: 'y', gradeLevel: 5, subjectCode: 'MAT', subjectName: 'Matematik',
    weekNumber: 8, isOtpWeek: false, isSocialEventWeek: false,
    unitTitle: 'Sayilar', topicTitle: 'Sayilar',
    outcomeDescription: 'Dogal sayilar', academicYear: '2026-2027',
  }];
  const dom = makeDom();
  om.renderTable('ALL', 5, 'MAT', 'ALL', 'ALL', '');
  assert.ok(!dom.html.includes('OTP'), '8. hafta oldugu icin OTP sanilmis');
});

console.log(`\n${passed} basarili, ${failed} basarisiz\n`);
process.exit(failed === 0 ? 0 : 1);

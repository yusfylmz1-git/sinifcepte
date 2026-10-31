/**
 * SınıfCepte Admin Paneli - Sınav listesi canlıyla eşitleme testleri
 *
 *   node admin_portal/js/test_exams_manager.js
 *
 * 31 Ekim 2026: yayın canlı listeyi bu tarayıcının listesiyle değiştiriyor
 * ama panel açılışta canlıyı okumuyordu. Başka yerden eklenen sınavlar
 * bir sonraki panel yayınında silinecekti.
 */

const assert = require('assert');
const fs = require('fs');
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

function yeniDepo() {
  const store = {};
  return {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
  };
}

global.window = {};
const kaynak = fs.readFileSync(path.join(__dirname, 'exams_manager.js'), 'utf8');
// eslint-disable-next-line no-new-func
const ExamsManager = new Function(`${kaynak}; return ExamsManager;`)();

const sinav = (id) => ({ doc_id: id, title: id, institution: 'MEB', examDate: '2027-01-01T00:00:00.000' });
const canli = JSON.stringify([sinav('a'), sinav('b'), sinav('c')]);

console.log('Canlıyla eşitleme');

test('KRITIK: yeni tarayıcı tohum listesiyle kalmaz, canlı liste yüklenir', () => {
  global.localStorage = yeniDepo();
  const m = new ExamsManager();
  assert.ok(m.getAllExams().length > 3, 'tohum listesi');
  assert.strictEqual(m.canliylaEsitle('5', canli), 'yenilendi');
  assert.deepStrictEqual(m.getAllExams().map((x) => x.doc_id), ['a', 'b', 'c']);
  assert.strictEqual(m.kaynakSurum(), '5');
});

test('KRITIK: eski yayından türeyen liste canlıyla değişir (eklenen sınav silinmez)', () => {
  global.localStorage = yeniDepo();
  const m = new ExamsManager();
  m.canliylaEsitle('4', JSON.stringify([sinav('a')]));
  assert.strictEqual(m.canliylaEsitle('5', canli), 'yenilendi');
  assert.strictEqual(m.getAllExams().length, 3);
});

test('aynı sürümden türeyen listedeki yayınlanmamış düzenleme korunur', () => {
  global.localStorage = yeniDepo();
  const m = new ExamsManager();
  m.canliylaEsitle('5', canli);
  m.addExam(sinav('d'));
  assert.strictEqual(m.canliylaEsitle('5', canli), 'ayni');
  assert.ok(m.getAllExams().some((x) => x.doc_id === 'd'));
});

test('kaynak sürüm tarayıcıda kalıcı', () => {
  global.localStorage = yeniDepo();
  new ExamsManager().canliylaEsitle('7', canli);
  assert.strictEqual(new ExamsManager().kaynakSurum(), '7');
});

test('canlı boş ya da bozuksa yerel listeye dokunulmaz', () => {
  global.localStorage = yeniDepo();
  const m = new ExamsManager();
  const once = m.getAllExams().length;
  assert.strictEqual(m.canliylaEsitle('5', ''), 'canli-bos');
  assert.strictEqual(m.canliylaEsitle('5', '[]'), 'canli-bos');
  assert.strictEqual(m.canliylaEsitle('5', '{bozuk'), 'canli-bos');
  assert.strictEqual(m.getAllExams().length, once);
});

console.log(`\n${passed} geçti, ${failed} kaldı`);
process.exit(failed > 0 ? 1 : 0);

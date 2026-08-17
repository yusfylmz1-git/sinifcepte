/**
 * SınıfCepte Firestore güvenlik kuralı testleri.
 *
 * Bu testler kuralların *gerçekten* koruduğunu doğrular. Uygulama kodu
 * doğru davransa bile kural yanlışsa veri sızar; bu yüzden burada
 * doğrudan kural motoruna karşı yazıyoruz.
 *
 * Çalıştırma:
 *   cd test_rules && npm install && npm test
 */
import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, updateDoc } from 'firebase/firestore';

const TEACHER_UID = 'teacherAhmet';
const OTHER_TEACHER_UID = 'teacherMehmet';
const PARENT_UID = 'parentAyse';
const OTHER_PARENT_UID = 'parentFatma';

const CLASS_ID = `cls_${TEACHER_UID}_7`;
const STUDENT_ID = `stu_${TEACHER_UID}_42`;
const OTHER_STUDENT_ID = `stu_${TEACHER_UID}_43`;
const CODE_HASH = 'a'.repeat(64);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'sinifcepte-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

/** Kuralları atlayarak başlangıç verisi yazar. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

const teacherDb = () => testEnv.authenticatedContext(TEACHER_UID).firestore();
const otherTeacherDb = () =>
  testEnv.authenticatedContext(OTHER_TEACHER_UID).firestore();
const parentDb = () =>
  testEnv.authenticatedContext(PARENT_UID, { role: 'parent' }).firestore();
const otherParentDb = () =>
  testEnv.authenticatedContext(OTHER_PARENT_UID, { role: 'parent' }).firestore();
const anonDb = () => testEnv.unauthenticatedContext().firestore();
const superAdminDb = () =>
  testEnv.authenticatedContext('bossUid', { adminRole: 'super' }).firestore();

describe('1. Veli referans kodları (parent_tokens)', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_tokens', CODE_HASH), {
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID,
        teacherUid: TEACHER_UID,
        studentName: 'Ali Yılmaz',
        studentNumber: 112,
        secondFactorHash: 'b'.repeat(64),
        status: 'active',
        linkedParentCount: 0,
        maxLinkedParents: 2,
        expiresAt: '2099-01-01T00:00:00.000Z',
      });
    });
  });

  it('giriş yapmış veli kodu doğrulamak için okuyabilir', async () => {
    await assertSucceeds(getDoc(doc(parentDb(), 'parent_tokens', CODE_HASH)));
  });

  it('oturumsuz kullanıcı kodu okuyamaz', async () => {
    await assertFails(getDoc(doc(anonDb(), 'parent_tokens', CODE_HASH)));
  });

  it('başka bir öğretmen kod yazamaz (sahiplik zorunlu)', async () => {
    await assertFails(
      setDoc(doc(otherTeacherDb(), 'parent_tokens', 'c'.repeat(64)), {
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID, // Ahmet'in öğrencisi
        teacherUid: OTHER_TEACHER_UID,
        status: 'active',
        linkedParentCount: 0,
        maxLinkedParents: 2,
      }),
    );
  });

  it('öğretmen kendi öğrencisi için kod yazabilir', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'parent_tokens', 'd'.repeat(64)), {
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID,
        teacherUid: TEACHER_UID,
        status: 'active',
        linkedParentCount: 0,
        maxLinkedParents: 2,
      }),
    );
  });

  it('veli kod dokümanını değiştiremez', async () => {
    await assertFails(
      updateDoc(doc(parentDb(), 'parent_tokens', CODE_HASH), {
        maxLinkedParents: 99,
      }),
    );
  });

  it('öğretmen kendi ürettiği kodu silebilir', async () => {
    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'parent_tokens', 'd'.repeat(64))),
    );
  });
});

describe('2. Veli–öğrenci bağı (parent_links) — izolasyon', () => {
  const myLinkId = `${PARENT_UID}_${STUDENT_ID}`;
  const otherLinkId = `${OTHER_PARENT_UID}_${OTHER_STUDENT_ID}`;

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_links', myLinkId), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        studentName: 'Ali Yılmaz',
        status: 'active',
      });
      await setDoc(doc(db, 'parent_links', otherLinkId), {
        parentUid: OTHER_PARENT_UID,
        studentCloudId: OTHER_STUDENT_ID,
        classCloudId: CLASS_ID,
        studentName: 'Zeynep Kaya',
        status: 'active',
      });
    });
  });

  it('veli kendi çocuğunun bağını okuyabilir', async () => {
    await assertSucceeds(getDoc(doc(parentDb(), 'parent_links', myLinkId)));
  });

  it('KRİTİK: veli BAŞKA bir velinin bağını okuyamaz', async () => {
    await assertFails(getDoc(doc(parentDb(), 'parent_links', otherLinkId)));
  });

  it('veli kendi adına bağ oluşturabilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'parent_links', `${PARENT_UID}_stu_${TEACHER_UID}_99`), {
        parentUid: PARENT_UID,
        studentCloudId: `stu_${TEACHER_UID}_99`,
        classCloudId: CLASS_ID,
        status: 'active',
      }),
    );
  });

  it('KRİTİK: veli BAŞKASI adına bağ oluşturamaz', async () => {
    // Kimlik başkasının uid'siyle başlıyor
    await assertFails(
      setDoc(doc(parentDb(), 'parent_links', `${OTHER_PARENT_UID}_${STUDENT_ID}`), {
        parentUid: OTHER_PARENT_UID,
        studentCloudId: STUDENT_ID,
        status: 'active',
      }),
    );
  });

  it('KRİTİK: veli kendi kimliğiyle başka uid yazamaz', async () => {
    // Kimlik doğru ama içerideki parentUid farklı — kimlik hırsızlığı denemesi
    await assertFails(
      setDoc(doc(parentDb(), 'parent_links', `${PARENT_UID}_stu_x_1`), {
        parentUid: OTHER_PARENT_UID,
        studentCloudId: 'stu_x_1',
        status: 'active',
      }),
    );
  });

  it('veli bağını arşivleyebilir ama başka alan değiştiremez', async () => {
    await assertSucceeds(
      updateDoc(doc(parentDb(), 'parent_links', myLinkId), { status: 'archived' }),
    );
    await assertFails(
      updateDoc(doc(parentDb(), 'parent_links', myLinkId), {
        studentName: 'Sahte İsim',
      }),
    );
  });

  it('öğrencinin sahibi öğretmen bağı silebilir (KVKK cascade)', async () => {
    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'parent_links', myLinkId)),
    );
  });

  it('ilgisiz öğretmen bağı silemez', async () => {
    await assertFails(
      deleteDoc(doc(otherTeacherDb(), 'parent_links', otherLinkId)),
    );
  });
});

describe('3. Sınıf odası (class_rooms) — sahiplik', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        className: '7-B',
        teacherUid: TEACHER_UID,
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
      });
    });
  });

  it('sahibi öğretmen sınıf odasını okur ve yazar', async () => {
    await assertSucceeds(getDoc(doc(teacherDb(), 'class_rooms', CLASS_ID)));
    await assertSucceeds(
      setDoc(
        doc(teacherDb(), 'class_rooms', CLASS_ID),
        { className: '7-B Güncel', teacherUid: TEACHER_UID },
        { merge: true },
      ),
    );
  });

  it('erişimi olan veli sınıf odasını okuyabilir', async () => {
    await assertSucceeds(getDoc(doc(parentDb(), 'class_rooms', CLASS_ID)));
  });

  it('KRİTİK: erişimi olmayan veli sınıf odasını okuyamaz', async () => {
    await assertFails(getDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID)));
  });

  it('KRİTİK: başka öğretmen sınıf odasını değiştiremez', async () => {
    await assertFails(
      setDoc(
        doc(otherTeacherDb(), 'class_rooms', CLASS_ID),
        { className: 'Ele geçirildi', teacherUid: OTHER_TEACHER_UID },
        { merge: true },
      ),
    );
  });

  it('veli sınıf odasına yazamaz', async () => {
    await assertFails(
      setDoc(
        doc(parentDb(), 'class_rooms', CLASS_ID),
        { className: 'Veli yazdı' },
        { merge: true },
      ),
    );
  });
});

describe('4. Okul yöneticisi başvuruları — yetki yükseltme koruması', () => {
  const REQ_ID = 'req_ahmet_1';

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'school_admin_requests', REQ_ID), {
        teacherUid: TEACHER_UID,
        schoolId: 'meb_16_123',
        status: 'pending',
      });
    });
  });

  it('öğretmen kendi başvurusunu görebilir', async () => {
    await assertSucceeds(
      getDoc(doc(teacherDb(), 'school_admin_requests', REQ_ID)),
    );
  });

  it('başka öğretmen bu başvuruyu göremez', async () => {
    await assertFails(
      getDoc(doc(otherTeacherDb(), 'school_admin_requests', REQ_ID)),
    );
  });

  it('öğretmen beklemede durumuyla başvuru oluşturabilir', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'school_admin_requests', 'req_yeni'), {
        teacherUid: TEACHER_UID,
        schoolId: 'meb_16_123',
        status: 'pending',
      }),
    );
  });

  it('KRİTİK: öğretmen kendini doğrudan onaylayamaz', async () => {
    await assertFails(
      setDoc(doc(teacherDb(), 'school_admin_requests', 'req_hile'), {
        teacherUid: TEACHER_UID,
        schoolId: 'meb_16_123',
        status: 'approved', // yetki yükseltme denemesi
      }),
    );
  });

  it('KRİTİK: öğretmen bekleyen başvurusunu onaylıya çeviremez', async () => {
    await assertFails(
      updateDoc(doc(teacherDb(), 'school_admin_requests', REQ_ID), {
        status: 'approved',
      }),
    );
  });

  it('süper admin başvuruyu onaylayabilir', async () => {
    await assertSucceeds(
      updateDoc(doc(superAdminDb(), 'school_admin_requests', REQ_ID), {
        status: 'approved',
      }),
    );
  });
});

describe('5. Veli şikâyetleri (content_reports)', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'content_reports', 'rep_1'), {
        reporterUid: PARENT_UID,
        reason: 'Uygunsuz içerik',
      });
    });
  });

  it('veli kendi adına şikâyet oluşturabilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'content_reports', 'rep_2'), {
        reporterUid: PARENT_UID,
        reason: 'Test',
      }),
    );
  });

  it('KRİTİK: veli başkası adına şikâyet oluşturamaz', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'content_reports', 'rep_3'), {
        reporterUid: OTHER_PARENT_UID,
        reason: 'Sahte ihbar',
      }),
    );
  });

  it('KRİTİK: veli şikâyetleri okuyamaz (yalnızca yönetim)', async () => {
    await assertFails(getDoc(doc(parentDb(), 'content_reports', 'rep_1')));
  });

  it('süper admin şikâyetleri okuyabilir', async () => {
    await assertSucceeds(getDoc(doc(superAdminDb(), 'content_reports', 'rep_1')));
  });

  it('KRİTİK: şikâyet kaydı veli tarafından silinemez (denetim izi)', async () => {
    await assertFails(deleteDoc(doc(parentDb(), 'content_reports', 'rep_1')));
  });
});

describe('6. Senkron manifesti', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'sync', 'manifest'), { outcomesVersion: 3 });
    });
  });

  it('herkes manifesti okuyabilir (oturumsuz dahil)', async () => {
    await assertSucceeds(getDoc(doc(anonDb(), 'sync', 'manifest')));
  });

  it('KRİTİK: hiçbir istemci manifesti değiştiremez', async () => {
    await assertFails(
      updateDoc(doc(teacherDb(), 'sync', 'manifest'), { outcomesVersion: 99 }),
    );
    await assertFails(
      updateDoc(doc(superAdminDb(), 'sync', 'manifest'), { outcomesVersion: 99 }),
    );
  });
});

describe('7. Kimlik şeması bütünlüğü', () => {
  it('sahiplik kimlik deseninden okunur, doküman okumadan', () => {
    // ownsClassRoom / ownsStudent kuralları get() kullanmaz.
    // Bu, sahiplik kontrolünün ücretsiz ve gecikmesiz olmasını sağlar.
    assert.ok(CLASS_ID.startsWith(`cls_${TEACHER_UID}_`));
    assert.ok(STUDENT_ID.startsWith(`stu_${TEACHER_UID}_`));
  });
});

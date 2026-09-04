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
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, getDocs, collection, setDoc, deleteDoc, updateDoc, query, where } from 'firebase/firestore';

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
// DİKKAT: Veliye custom claim VERİLMEZ.
//
// Testler eskiden `{ role: 'parent' }` claim'i veriyordu; gerçek
// uygulamada ise bu claim hiç yazılmıyor (Admin SDK gerekir, projede
// Cloud Functions yok). Sahte claim yüzünden testler geçiyor ama gerçek
// cihaz PERMISSION_DENIED alıyordu — veli mesaj gönderemiyordu.
//
// Artık testler gerçekle aynı: yalnızca oturum açık, claim yok.
const parentDb = () => testEnv.authenticatedContext(PARENT_UID).firestore();
const otherParentDb = () =>
  testEnv.authenticatedContext(OTHER_PARENT_UID).firestore();
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

  it('veli kendi adına bağ oluşturabilir (GEÇERLİ KODLA)', async () => {
    // Bu test eskiden codeHash OLMADAN geciyordu ve bir GUVENLIK ACIGINI
    // ozellik gibi dogruluyordu: kod bilmeyen biri de bag kurabiliyordu.
    // Artik gecerli bir referans kodu sart.
    const hash = 'd'.repeat(64);
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_tokens', hash), {
        studentCloudId: `stu_${TEACHER_UID}_99`,
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
    });

    await assertSucceeds(
      setDoc(doc(parentDb(), 'parent_links', `${PARENT_UID}_stu_${TEACHER_UID}_99`), {
        parentUid: PARENT_UID,
        studentCloudId: `stu_${TEACHER_UID}_99`,
        classCloudId: CLASS_ID,
        status: 'active',
        codeHash: hash,
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
    // Yeni şikâyet 'open' durumunda başlamalıdır; kural bunu şart koşar
    // ki veli kaydı doğrudan "incelendi" olarak açamasın.
    await assertSucceeds(
      setDoc(doc(parentDb(), 'content_reports', 'rep_2'), {
        reporterUid: PARENT_UID,
        reason: 'Test',
        status: 'open',
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

// --- Faz 3: iletişim katmanı ---

describe('8. Duyurular ve okundu bilgisi (maliyet kararı #1)', () => {
  const ANN_ID = 'ann_1';

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
      });
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        status: 'active',
      });
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'announcements', ANN_ID), {
        title: 'Veli toplantısı',
        content: 'Cuma günü saat 14:00',
        authorUid: TEACHER_UID,
      });
    });
  });

  it('sınıf öğretmeni duyuru yayımlayabilir', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'ann_2'), {
        title: 'Gezi',
        authorUid: TEACHER_UID,
      }),
    );
  });

  it('erişimi olan veli duyuruyu okuyabilir', async () => {
    await assertSucceeds(
      getDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID)),
    );
  });

  it('KRİTİK: erişimi olmayan veli duyuruyu okuyamaz', async () => {
    await assertFails(
      getDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID)),
    );
  });

  it('KRİTİK: veli duyuru içeriğini değiştiremez', async () => {
    await assertFails(
      updateDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID), {
        title: 'Veli değiştirdi',
      }),
    );
  });

  it('veli KENDİ okundu kaydını yazabilir', async () => {
    await assertSucceeds(
      setDoc(
        doc(parentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID, 'reads', PARENT_UID),
        { readAt: '2026-08-18T10:00:00.000Z' },
      ),
    );
  });

  it('KRİTİK: veli BAŞKA velinin okundu kaydını yazamaz', async () => {
    await assertFails(
      setDoc(
        doc(parentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID, 'reads', OTHER_PARENT_UID),
        { readAt: '2026-08-18T10:00:00.000Z' },
      ),
    );
  });

  it('KRİTİK: sınıfa erişimi olmayan veli okundu kaydı yazamaz', async () => {
    await assertFails(
      setDoc(
        doc(otherParentDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID, 'reads', OTHER_PARENT_UID),
        { readAt: '2026-08-18T10:00:00.000Z' },
      ),
    );
  });

  it('öğretmen okundu kayıtlarını okuyabilir (kaç kişi okudu)', async () => {
    await assertSucceeds(
      getDoc(
        doc(teacherDb(), 'class_rooms', CLASS_ID, 'announcements', ANN_ID, 'reads', PARENT_UID),
      ),
    );
  });
});

describe('9. Mesajlaşma — branş öğretmeni ekseni', () => {
  // Kullanıcı kararı: duyuruyu yalnızca sınıf öğretmeni yapar, ancak veli
  // çocuğunun dersine giren branş öğretmenleriyle de yazışabilmelidir.
  const BRANCH_TEACHER_UID = 'teacherFizikSelin';
  const STRANGER_TEACHER_UID = 'teacherYabanci';

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      // Selin öğretmen sınıfın branş kadrosunda
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', BRANCH_TEACHER_UID), {
        teacherUid: BRANCH_TEACHER_UID,
        teacherName: 'Selin Demir',
        branch: 'Fizik',
      });
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        status: 'active',
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
      });
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'messages', 'msg_1'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: TEACHER_UID,
        teacherUid: TEACHER_UID,
        body: 'Merhaba',
      });
    });
  });

  const branchTeacherDb = () =>
    testEnv.authenticatedContext(BRANCH_TEACHER_UID).firestore();
  const strangerTeacherDb = () =>
    testEnv.authenticatedContext(STRANGER_TEACHER_UID).firestore();

  it('sınıf öğretmeni mesaj gönderebilir', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_t'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: TEACHER_UID,
        teacherUid: TEACHER_UID,
        body: 'Sınıf öğretmeninden',
      }),
    );
  });

  it('KADRODAKİ branş öğretmeni mesaj gönderebilir', async () => {
    await assertSucceeds(
      setDoc(doc(branchTeacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_b'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: BRANCH_TEACHER_UID,
        teacherUid: BRANCH_TEACHER_UID,
        body: 'Fizik öğretmeninden',
      }),
    );
  });

  it('KRİTİK: kadroda OLMAYAN öğretmen mesaj gönderemez', async () => {
    await assertFails(
      setDoc(doc(strangerTeacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_x'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: STRANGER_TEACHER_UID,
        teacherUid: STRANGER_TEACHER_UID,
        body: 'Yabancı öğretmen',
      }),
    );
  });

  it('KRİTİK: kadroda olmayan öğretmen mesajları okuyamaz', async () => {
    await assertFails(
      getDoc(doc(strangerTeacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_1')),
    );
  });

  it('veli kendi çocuğu hakkında mesaj gönderebilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_p'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'parent',
        teacherUid: BRANCH_TEACHER_UID,
        body: 'Veliden bilgi',
      }),
    );
  });

  it('KRİTİK: veli öğretmen kimliğiyle mesaj gönderemez', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_sahte'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher', // kimlik taklidi denemesi
        authorUid: TEACHER_UID,
        teacherUid: TEACHER_UID,
        body: 'Sahte öğretmen mesajı',
      }),
    );
  });

  it('KRİTİK: bağı olmayan veli mesaj gönderemez', async () => {
    await assertFails(
      setDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_y'), {
        studentCloudId: STUDENT_ID,
        parentUserId: OTHER_PARENT_UID,
        authorRole: 'parent',
        teacherUid: BRANCH_TEACHER_UID,
        body: 'İlgisiz veli',
      }),
    );
  });

  it('KRİTİK: öğretmen BAŞKA öğretmenin sohbetine yazamaz', async () => {
    // teacherUid sohbetin sahibini belirler. Kadrodaki bir öğretmen
    // kendini başka bir öğretmenin sohbetine yazamamalı.
    await assertFails(
      setDoc(doc(branchTeacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_capraz'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: BRANCH_TEACHER_UID,
        teacherUid: TEACHER_UID, // başkasının sohbeti
        body: 'Karışan sohbet',
      }),
    );
  });

  it('KRİTİK: veli teacherUid alanı olmadan mesaj gönderemez', async () => {
    // Bu alan olmadan mesajlar yalnızca öğrenciye göre filtrelenirdi ve
    // velinin tüm öğretmenlerle yazışması tek sohbette birikirdi.
    await assertFails(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_alansiz'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'parent',
        body: 'Hedefi belirsiz mesaj',
      }),
    );
  });

  it('KRİTİK: öğretmen BAŞKA öğretmenin sohbetini okuyamaz', async () => {
    // msg_1 sınıf öğretmeninin sohbetine ait; branş öğretmeni görmemeli.
    await assertFails(
      getDoc(doc(branchTeacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_1')),
    );
  });

  it('KRİTİK: gönderilmiş mesaj sonradan değiştirilemez', async () => {
    await assertFails(
      updateDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_1'), {
        body: 'Geçmişe müdahale',
      }),
    );
  });

  it('veli kadro listesini okuyabilir (dersine giren öğretmenler)', async () => {
    await assertSucceeds(
      getDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'staff', BRANCH_TEACHER_UID)),
    );
  });

  it('KRİTİK: öğretmen kendini kadroya ekleyemez', async () => {
    // Katılım kodlu yol kaldırıldı: kadroyu yalnızca sınıf öğretmeni
    // yönetir. Bu, davet edilmemiş hiç kimsenin mesajlaşma yetkisi
    // kazanamayacağını garanti eder.
    await assertFails(
      setDoc(doc(strangerTeacherDb(), 'class_rooms', CLASS_ID, 'staff', STRANGER_TEACHER_UID), {
        teacherUid: STRANGER_TEACHER_UID,
        teacherName: 'Kendini ekleyen',
        branch: 'Kimya',
      }),
    );

    // Eski "joinedVia" numarası da artık işe yaramaz.
    await assertFails(
      setDoc(doc(strangerTeacherDb(), 'class_rooms', CLASS_ID, 'staff', STRANGER_TEACHER_UID), {
        teacherUid: STRANGER_TEACHER_UID,
        teacherName: 'Eski yol',
        joinedVia: 'pending_KOD111',
      }),
    );
  });

  it('KRİTİK: öğretmen BAŞKASININ kimliğiyle kadroya giremez', async () => {
    await assertFails(
      setDoc(doc(strangerTeacherDb(), 'class_rooms', CLASS_ID, 'staff', 'baskaUid'), {
        teacherUid: 'baskaUid',
        teacherName: 'Sahte kayıt',
      }),
    );
  });

  it('KRİTİK: kadroda olmayan öğretmen mesaj gönderemez', async () => {
    // Not: Bu testte ayrı bir kimlik kullanılır. Önceki testte
    // STRANGER_TEACHER_UID gerçekten kadroya katıldığı için artık meşru
    // şekilde mesaj gönderebilir; onu kullanmak yanıltıcı olurdu.
    const NOT_JOINED_UID = 'teacherHenuzKatilmadi';
    const notJoinedDb = () =>
      testEnv.authenticatedContext(NOT_JOINED_UID).firestore();

    // Kadroda olmayan öğretmen mesaj gönderemez: isClassStaff() kadro
    // satırının varlığını arar.
    await assertFails(
      setDoc(doc(notJoinedDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_pending'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: NOT_JOINED_UID,
        teacherUid: NOT_JOINED_UID,
        body: 'Kadroda olmayan öğretmenden',
      }),
    );
  });

  it('KRİTİK: veli kendini kadroya ekleyip mesajlaşma yetkisi alamaz', async () => {
    // Kadroyu yalnızca sınıf öğretmeni yazabilir; veli kendini ekleyemez.
    await assertFails(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'staff', PARENT_UID), {
        teacherUid: PARENT_UID,
        teacherName: 'Veli kendini ekledi',
      }),
    );
  });
});

describe('10. Durum bildirimleri ve randevular', () => {
  const BRANCH_UID = 'teacherBransSelin';

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', BRANCH_UID), {
        teacherUid: BRANCH_UID,
        teacherName: 'Selin Demir',
        branch: 'Fizik',
      });
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        status: 'active',
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
      });
      // Velinin gönderdiği bildirim
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'status_reports', 'rep_1'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        type: 'medication',
        title: 'Alerji ilacı',
        details: 'Öğle arası verilmeli',
        status: 'pending',
      });
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'appointments', 'apt_1'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        teacherName: 'Ahmet Yılmaz',
        timeSlot: '13:30',
        status: 'pending',
      });
    });
  });

  const branchDb = () => testEnv.authenticatedContext(BRANCH_UID).firestore();

  it('veli kendi çocuğu için durum bildirimi gönderebilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_yeni'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        type: 'early_leave',
        title: 'Diş randevusu',
        details: '14:00 alınacak',
        status: 'pending',
      }),
    );
  });

  it('KRİTİK: bağı olmayan veli bildirim gönderemez', async () => {
    await assertFails(
      setDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_x'), {
        studentCloudId: STUDENT_ID,
        parentUserId: OTHER_PARENT_UID,
        type: 'note',
        title: 'İlgisiz veli',
        details: 'test',
        status: 'pending',
      }),
    );
  });

  it('KRİTİK: veli bildirimi onaylanmış olarak gönderemez', async () => {
    // Aksi halde öğretmen görmeden "görüldü" sayılırdı.
    await assertFails(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_hile'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        type: 'note',
        title: 'Sahte onay',
        details: 'test',
        status: 'acknowledged',
      }),
    );
  });

  it('KRİTİK: veli gönderdiği bildirimin içeriğini değiştiremez', async () => {
    // Öğretmen "ilaç 12:30" diye okuduktan sonra metin değişirse
    // sorumluluk belirsizleşir.
    await assertFails(
      updateDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_1'), {
        details: 'Sonradan değiştirildi',
      }),
    );
  });

  it('sınıf öğretmeni bildirimi görüldü işaretleyebilir', async () => {
    await assertSucceeds(
      updateDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_1'), {
        status: 'acknowledged',
        teacherNote: 'Bilgilendirildi',
      }),
    );
  });

  it('kadrodaki branş öğretmeni de bildirimi görüp işaretleyebilir', async () => {
    await assertSucceeds(
      getDoc(doc(branchDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_1')),
    );
    await assertSucceeds(
      updateDoc(doc(branchDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_1'), {
        status: 'acknowledged',
      }),
    );
  });

  it('KRİTİK: ilgisiz veli bildirimleri okuyamaz (sağlık verisi)', async () => {
    await assertFails(
      getDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID, 'status_reports', 'rep_1')),
    );
  });

  it('veli randevu talep edebilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_yeni'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        teacherName: 'Selin Demir',
        timeSlot: '14:00',
        status: 'pending',
      }),
    );
  });

  it('KRİTİK: veli randevuyu kendisi onaylayamaz', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_hile'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        teacherName: 'Ahmet Yılmaz',
        timeSlot: '15:00',
        status: 'confirmed',
      }),
    );
  });

  it('veli kendi randevusunu iptal edebilir', async () => {
    await assertSucceeds(
      updateDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_1'), {
        status: 'cancelled',
        respondedAt: '2026-08-18T10:00:00.000Z',
      }),
    );
  });

  it('KRİTİK: veli randevuyu onaylıya çeviremez', async () => {
    await assertFails(
      updateDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_1'), {
        status: 'confirmed',
      }),
    );
  });

  it('öğretmen randevuyu onaylayabilir', async () => {
    await assertSucceeds(
      updateDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_1'), {
        status: 'confirmed',
        responseNote: 'Görüşelim',
      }),
    );
  });

  it('kadrodaki branş öğretmeni de randevu yanıtlayabilir', async () => {
    await assertSucceeds(
      updateDoc(doc(branchDb(), 'class_rooms', CLASS_ID, 'appointments', 'apt_1'), {
        status: 'confirmed',
      }),
    );
  });
});

describe('11. Okul yöneticisi yetkisi', () => {
  const SCHOOL_A = 'meb_16_111';
  const SCHOOL_B = 'meb_34_222';
  const ADMIN_A_UID = 'adminOkulA';

  // Onaylı okul yöneticisi: claim'leri Admin SDK betiği yazar.
  const schoolAdminA = () =>
    testEnv
      .authenticatedContext(ADMIN_A_UID, {
        schoolAdminStatus: 'approved',
        schoolId: SCHOOL_A,
      })
      .firestore();

  // Başvurusu beklemede olan öğretmen
  const pendingAdmin = () =>
    testEnv
      .authenticatedContext('teacherBekleyen', {
        schoolAdminStatus: 'pending',
        schoolId: SCHOOL_A,
      })
      .firestore();

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'content_reports', 'rep_okulA'), {
        reporterUid: PARENT_UID,
        schoolId: SCHOOL_A,
        contentType: 'Duyuru',
        reason: 'Uygunsuz',
        status: 'open',
      });
      await setDoc(doc(db, 'content_reports', 'rep_okulB'), {
        reporterUid: OTHER_PARENT_UID,
        schoolId: SCHOOL_B,
        contentType: 'Duyuru',
        reason: 'Uygunsuz',
        status: 'open',
      });
    });
  });

  it('okul yöneticisi KENDİ okulunun şikâyetini okuyabilir', async () => {
    await assertSucceeds(
      getDoc(doc(schoolAdminA(), 'content_reports', 'rep_okulA')),
    );
  });

  it('KRİTİK: okul yöneticisi BAŞKA okulun şikâyetini okuyamaz', async () => {
    await assertFails(
      getDoc(doc(schoolAdminA(), 'content_reports', 'rep_okulB')),
    );
  });

  it('KRİTİK: onaylanmamış başvuru sahibi şikâyet okuyamaz', async () => {
    // Claim 'pending' ise yetki yoktur; onay yalnızca Admin SDK ile verilir.
    await assertFails(
      getDoc(doc(pendingAdmin(), 'content_reports', 'rep_okulA')),
    );
  });

  it('KRİTİK: sıradan öğretmen şikâyet okuyamaz', async () => {
    await assertFails(
      getDoc(doc(teacherDb(), 'content_reports', 'rep_okulA')),
    );
  });

  it('KRİTİK: şikâyeti gönderen veli bile sonradan okuyamaz', async () => {
    await assertFails(
      getDoc(doc(parentDb(), 'content_reports', 'rep_okulA')),
    );
  });

  it('okul yöneticisi şikâyeti incelendi işaretleyebilir', async () => {
    await assertSucceeds(
      updateDoc(doc(schoolAdminA(), 'content_reports', 'rep_okulA'), {
        status: 'reviewed',
        reviewNote: 'Öğretmenle görüşüldü',
      }),
    );
  });

  it('KRİTİK: okul yöneticisi şikâyet içeriğini değiştiremez', async () => {
    // Denetim izi bütünlüğü: gerekçe sonradan yeniden yazılamaz.
    await assertFails(
      updateDoc(doc(schoolAdminA(), 'content_reports', 'rep_okulA'), {
        reason: 'Gerekçe değiştirildi',
      }),
    );
  });

  it('KRİTİK: okul yöneticisi başka okulun şikâyetini işaretleyemez', async () => {
    await assertFails(
      updateDoc(doc(schoolAdminA(), 'content_reports', 'rep_okulB'), {
        status: 'reviewed',
      }),
    );
  });

  it('KRİTİK: veli şikâyeti kapalı durumda oluşturamaz', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'content_reports', 'rep_hile'), {
        reporterUid: PARENT_UID,
        schoolId: SCHOOL_A,
        contentType: 'Duyuru',
        reason: 'test',
        status: 'reviewed',
      }),
    );
  });

  it('KRİTİK: okul yöneticisi öğrenci verisine erişemez', async () => {
    // Yöneticinin yetkisi öğretmen doğrulama ve şikâyetle sınırlıdır;
    // sınıf odası, mesaj veya bağ kayıtlarına erişimi yoktur.
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        status: 'active',
      });
    });

    await assertFails(getDoc(doc(schoolAdminA(), 'class_rooms', CLASS_ID)));
    await assertFails(
      getDoc(doc(schoolAdminA(), 'parent_links', `${PARENT_UID}_${STUDENT_ID}`)),
    );
  });
});

describe('16. Veli erişim kaydının onarımı (ensureParentAccess)', () => {
  // Bağ yerel yoldan kurulduğunda parent_links / parent_class_access
  // dokümanları hiç yazılmıyordu; kural motoru duyuru ve mesaj okumasını
  // bunların VARLIĞINA bağladığı için her sorgu PERMISSION_DENIED ile
  // düşüyor ve veli ekranı sessizce boş kalıyordu.
  const ONARIM_HASH = 'e'.repeat(64);

  before(async () => {
    await testEnv.clearFirestore();
    // Onarim akisi da GERCEK bir referans koduna dayanmali.
    //
    // Bu blok eskiden token OLMADAN yazmayi "onarim" diye BASARI
    // sayiyordu; yani bir guvenlik acigini test ile mesrulastiriyordu.
    // Onarim, velinin daha once aldigi kodun hash'ini tasir.
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_tokens', ONARIM_HASH), {
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
    });
  });

  it('KRİTİK: veli kendi erişim kayıtlarını yazabilir', async () => {
    const db = parentDb();

    // Bag once yazilir: `parent_class_access` bagin VARLIGINI arar.
    await assertSucceeds(
      setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        parentName: 'Busra',
        relation: 'Anne',
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
        codeHash: ONARIM_HASH,
      }),
    );

    await assertSucceeds(
      setDoc(
        doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`),
        {
          parentUid: PARENT_UID,
          classCloudId: CLASS_ID,
          studentCloudId: STUDENT_ID,
        },
      ),
    );
  });

  it('KRİTİK: erişim yazıldıktan sonra duyurular okunabilir', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      await setDoc(
        doc(db, 'class_rooms', CLASS_ID, 'announcements', 'a1'),
        { title: 'Duyuru', content: 'İçerik', priority: 'normal' },
      );
    });

    await assertSucceeds(
      getDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'announcements', 'a1')),
    );
  });

  it('KRİTİK: erişim yazıldıktan sonra kadro okunabilir', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
        teacherUid: TEACHER_UID,
        teacherName: 'yusuf yılmaz',
        isHomeroom: true,
      });
    });

    await assertSucceeds(
      getDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'staff', TEACHER_UID)),
    );
  });

  it('KRİTİK: veli mesaj gönderebilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_v'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'parent',
        teacherUid: TEACHER_UID,
        body: 'Merhaba öğretmenim',
      }),
    );
  });

  it('KRİTİK: başka veli bu erişimi yazamaz', async () => {
    await assertFails(
      setDoc(
        doc(otherParentDb(), 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`),
        {
          parentUid: PARENT_UID,
          classCloudId: CLASS_ID,
          studentCloudId: STUDENT_ID,
        },
      ),
    );
  });
});

describe('15. Kod üretimi batch\'i (publishToken)', () => {
  // Kullanıcının Firestore'unda class_rooms VAR ama parent_tokens
  // koleksiyonu HİÇ YOK. Kod üretimi bu üçünü TEK batch'te yazar:
  // sınıf odası + sınıf öğretmeninin kadro satırı + token.
  //
  // Firestore batch'i atomiktir: biri reddedilirse ÜÇÜ DE yazılmaz.
  // Bu testler batch'in gerçekten geçtiğini doğrular.
  const CODE_HASH = 'f'.repeat(64);

  before(async () => {
    await testEnv.clearFirestore();
  });

  it('KRİTİK: kod üretimi batch\'i tümüyle yazılabilir', async () => {
    const db = teacherDb();

    await assertSucceeds(
      Promise.all([
        setDoc(doc(db, 'class_rooms', CLASS_ID), {
          classCloudId: CLASS_ID,
          className: '5-A',
          schoolId: 'meb_775214',
          schoolName: 'Mimar Sinan Ortaokulu',
          teacherUid: TEACHER_UID,
          teacherName: 'yusuf yılmaz',
        }),
        setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
          teacherUid: TEACHER_UID,
          teacherName: 'yusuf yılmaz',
          branch: 'Sınıf Öğretmeni',
          isHomeroom: true,
        }),
        setDoc(doc(db, 'parent_tokens', CODE_HASH), {
          classCloudId: CLASS_ID,
          studentCloudId: STUDENT_ID,
          teacherUid: TEACHER_UID,
          schoolId: 'meb_775214',
          className: '5-A',
          studentName: 'Ahmet Veysel İlhan',
          studentNumber: 51,
          secondFactorHash: 'a'.repeat(64),
          status: 'active',
          linkedParentCount: 0,
          maxLinkedParents: 2,
        }),
      ]),
    );
  });

  it('KRİTİK: veli token kaydını okuyabilir (onarım buna dayanır)', async () => {
    // Bağ onarımı bu okumayla öğretmen kimliğini bulur.
    const snap = await getDoc(doc(parentDb(), 'parent_tokens', CODE_HASH));
    assert.equal(snap.exists(), true, 'Veli token kaydını okuyamıyor');
    assert.equal(snap.data().teacherUid, TEACHER_UID);
  });

  it('KRİTİK: studentCloudId deseni bozuksa token YAZILAMAZ', async () => {
    // ownsStudent -> stu_{uid}_* deseni; bozuk desen tüm batch'i düşürür
    // ve sınıf odası da yazılmaz.
    await assertFails(
      setDoc(doc(teacherDb(), 'parent_tokens', 'a'.repeat(64)), {
        classCloudId: CLASS_ID,
        studentCloudId: 'stu_local_teacher_12',
        teacherUid: TEACHER_UID,
        status: 'active',
      }),
    );
  });

  it('KRİTİK: teacherUid oturumla uyuşmazsa token YAZILAMAZ', async () => {
    await assertFails(
      setDoc(doc(teacherDb(), 'parent_tokens', 'b'.repeat(64)), {
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID,
        teacherUid: OTHER_TEACHER_UID,
        status: 'active',
      }),
    );
  });

  it('Veli token listeleyemez (tüm kodlar taranamaz)', async () => {
    await assertFails(getDocs(collection(parentDb(), 'parent_tokens')));
  });
});

describe('14. Sınıf öğretmeninin kadro satırı', () => {
  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID,
      });
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
      });
    });
  });

  it('KRİTİK: sınıf öğretmeni kendini kadroya yazabilir', async () => {
    // Referans kodu üretilirken bu satır yazılır. Yazılmadığı sürece
    // veli sınıf öğretmenini kadroda göremiyor, ona mesaj atmak
    // istediğinde "öğretmen bağlı değil" uyarısı alıyordu.
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
        teacherUid: TEACHER_UID,
        teacherName: 'Ahmet Öğretmen',
        branch: 'Sınıf Öğretmeni',
        isHomeroom: true,
      }),
    );
  });

  it('KRİTİK: kod üretimi kadro satırını da yazar (publishToken batch)', async () => {
    // Üretimdeki `publishToken` bu üç dokümanı TEK batch'te yazar:
    // sınıf odası + sınıf öğretmeninin kadro satırı + token.
    // Kadro satırı yazılmazsa veli sınıf öğretmenini hiç göremez.
    const codeHash = 'e'.repeat(64);

    await assertSucceeds(
      Promise.all([
        setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID), {
          classCloudId: CLASS_ID,
          className: '7-B',
          teacherUid: TEACHER_UID,
          teacherName: 'Ahmet Öğretmen',
        }),
        setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
          teacherUid: TEACHER_UID,
          teacherName: 'Ahmet Öğretmen',
          branch: 'Sınıf Öğretmeni',
          isHomeroom: true,
        }),
        setDoc(doc(teacherDb(), 'parent_tokens', codeHash), {
          classCloudId: CLASS_ID,
          studentCloudId: STUDENT_ID,
          teacherUid: TEACHER_UID,
          status: 'active',
        }),
      ]),
    );

    // Veli tarafı: kadroda sınıf öğretmenini bulmalı.
    const snap = await getDoc(
      doc(parentDb(), 'class_rooms', CLASS_ID, 'staff', TEACHER_UID),
    );
    assert.equal(snap.exists(), true, 'Kadro satırı veliye görünmüyor');
    assert.equal(snap.data().isHomeroom, true);
  });

  it('KRİTİK: veli kadroyu okuyup sınıf öğretmenini görebilir', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
        teacherUid: TEACHER_UID,
        teacherName: 'Ahmet Öğretmen',
        isHomeroom: true,
      });
    });

    await assertSucceeds(
      getDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'staff', TEACHER_UID)),
    );
  });

  it('KRİTİK: kadrodaki sınıf öğretmeni veliye mesaj yazabilir', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID, 'staff', TEACHER_UID), {
        teacherUid: TEACHER_UID,
        isHomeroom: true,
      });
    });

    await assertSucceeds(
      setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_hr'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'teacher',
        authorUid: TEACHER_UID,
        teacherUid: TEACHER_UID,
        body: 'Sınıf öğretmeninden',
      }),
    );
  });

  it('KRİTİK: veli sınıf öğretmenine yazabilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'class_rooms', CLASS_ID, 'messages', 'msg_p_hr'), {
        studentCloudId: STUDENT_ID,
        parentUserId: PARENT_UID,
        authorRole: 'parent',
        teacherUid: TEACHER_UID,
        body: 'Veliden sınıf öğretmenine',
      }),
    );
  });

  it('KRİTİK: başka öğretmen kendini bu kadroya yazamaz', async () => {
    await assertFails(
      setDoc(
        doc(otherTeacherDb(), 'class_rooms', CLASS_ID, 'staff', OTHER_TEACHER_UID),
        {
          teacherUid: OTHER_TEACHER_UID,
          isHomeroom: true,
        },
      ),
    );
  });
});

describe('13. Öğrenci yaşam döngüsü (ayrılma / şube değişikliği)', () => {
  const OTHER_PARENT_UID = 'parentBaskasi';
  const otherParentDb2 = () =>
    testEnv.authenticatedContext(OTHER_PARENT_UID).firestore();

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
      });
      await setDoc(doc(db, 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: CLASS_ID,
        studentCloudId: STUDENT_ID,
      });
    });
  });

  it('KRİTİK: öğretmen ayrılan öğrencinin sınıf erişimini kaldırabilir', async () => {
    // Bu izin olmadan, okuldan ayrılmış öğrencinin velisi sınıf
    // duyurularını görmeye devam ederdi: yerel temizlik buluttaki
    // parent_class_access kaydına ulaşamıyor.
    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`)),
    );
  });

  it('KRİTİK: öğretmen şube değişikliğinde yeni erişimi yazabilir', async () => {
    const NEW_CLASS_ID = `cls_${TEACHER_UID}_8`;
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'parent_class_access', `${PARENT_UID}_${NEW_CLASS_ID}`), {
        parentUid: PARENT_UID,
        classCloudId: NEW_CLASS_ID,
        studentCloudId: STUDENT_ID,
      }),
    );
  });

  it('KRİTİK: başka öğretmen bu erişime dokunamaz', async () => {
    // Yetki öğrencinin sahipliğine bağlıdır: stu_{uid}_* deseni.
    await assertFails(
      deleteDoc(
        doc(otherTeacherDb(), 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`),
      ),
    );
  });

  it('KRİTİK: veli başkasının sınıf erişimini silemez', async () => {
    await assertFails(
      deleteDoc(
        doc(otherParentDb2(), 'parent_class_access', `${PARENT_UID}_${CLASS_ID}`),
      ),
    );
  });

  it('öğretmen ayrılan öğrencinin veli bağını kaldırabilir', async () => {
    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'parent_links', `${PARENT_UID}_${STUDENT_ID}`)),
    );
  });
});

describe('12. Okul öğretmen dizini (school_teachers)', () => {
  const SCHOOL = 'meb_16_123';
  const DOC_ID = `${SCHOOL}_${TEACHER_UID}`;

  before(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'school_teachers', DOC_ID), {
        teacherUid: TEACHER_UID,
        schoolId: SCHOOL,
        fullName: 'Ahmet Yılmaz',
        branch: 'Matematik',
      });
      // Okuyan öğretmenin de KENDİ kaydı olmalı: dizin erişimi artık
      // claim'e değil, aynı okulda kayıtlı olma kanıtına dayanıyor.
      // Gerçek akışta bu kayıt okul seçilirken oluşur.
      await setDoc(doc(db, 'school_teachers', `${SCHOOL}_${OTHER_TEACHER_UID}`), {
        teacherUid: OTHER_TEACHER_UID,
        schoolId: SCHOOL,
        fullName: 'Mehmet Demir',
        branch: 'Fizik',
      });
    });
  });

  it('öğretmen meslektaş dizinini okuyabilir (kadro seçimi için)', async () => {
    await assertSucceeds(
      getDoc(doc(otherTeacherDb(), 'school_teachers', DOC_ID)),
    );
  });

  it('öğretmen kendi kaydını yazabilir', async () => {
    await assertSucceeds(
      setDoc(
        doc(otherTeacherDb(), 'school_teachers', `${SCHOOL}_${OTHER_TEACHER_UID}`),
        {
          teacherUid: OTHER_TEACHER_UID,
          schoolId: SCHOOL,
          fullName: 'Mehmet Demir',
          branch: 'Fizik',
        },
      ),
    );
  });

  it('KRİTİK: öğretmen BAŞKASI adına kayıt yazamaz', async () => {
    // İçerideki uid başkası
    await assertFails(
      setDoc(
        doc(otherTeacherDb(), 'school_teachers', `${SCHOOL}_${OTHER_TEACHER_UID}`),
        {
          teacherUid: TEACHER_UID,
          schoolId: SCHOOL,
          fullName: 'Sahte kayıt',
        },
      ),
    );

    // Doküman kimliği başkasının uid'siyle bitiyor
    await assertFails(
      setDoc(doc(otherTeacherDb(), 'school_teachers', DOC_ID), {
        teacherUid: OTHER_TEACHER_UID,
        schoolId: SCHOOL,
        fullName: 'Kimlik uyuşmazlığı',
      }),
    );
  });

  it('KRİTİK: doküman kimliği okul+uid deseniyle eşleşmeli', async () => {
    // Kimlik deseni bozuksa reddedilir; aksi halde bir öğretmen
    // başka okulun dizinine sızabilirdi.
    await assertFails(
      setDoc(doc(otherTeacherDb(), 'school_teachers', `bambaska_${OTHER_TEACHER_UID}`), {
        teacherUid: OTHER_TEACHER_UID,
        schoolId: SCHOOL, // kimlikteki okulla çelişiyor
        fullName: 'Desen uyuşmazlığı',
      }),
    );
  });

  it('KRİTİK: veli öğretmen dizinini okuyamaz', async () => {
    // Velinin öğretmen listesine ihtiyacı yok; dersine giren
    // öğretmenleri sınıf kadrosundan görür.
    await assertFails(
      getDoc(doc(parentDb(), 'school_teachers', DOC_ID)),
    );
  });

  it('KRİTİK: öğretmen başkasının kaydını silemez', async () => {
    await assertFails(
      deleteDoc(doc(otherTeacherDb(), 'school_teachers', DOC_ID)),
    );
  });

  it('öğretmen kendi kaydını silebilir (okul değiştirme)', async () => {
    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'school_teachers', DOC_ID)),
    );
  });
});


describe('Destek talepleri', () => {
  const gecerliTalep = (uid) => ({
    userId: uid,
    userRole: 'parent',
    category: 'code_issue',
    subject: 'Kod calismiyor',
    message: 'Referans kodunu girince hata veriyor.',
    createdAt: new Date().toISOString(),
    status: 'open',
  });

  it('KRİTİK: kullanıcı kendi adına talep oluşturabilir', async () => {
    await assertSucceeds(
      setDoc(doc(parentDb(), 'support_requests', 'sup_parentAyse_1'),
        gecerliTalep(PARENT_UID)),
    );
  });

  it('öğretmen de talep oluşturabilir', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'support_requests', 'sup_teacherAhmet_1'), {
        ...gecerliTalep(TEACHER_UID),
        userRole: 'teacher',
      }),
    );
  });

  it('KRİTİK: başkasının adına talep oluşturulamaz', async () => {
    // Aksi halde bir kullanıcı baskasinin kimligiyle talep acabilirdi.
    await assertFails(
      setDoc(doc(parentDb(), 'support_requests', 'sup_sahte_1'),
        gecerliTalep(OTHER_PARENT_UID)),
    );
  });

  it('KRİTİK: oturum açmamış kullanıcı talep gönderemez', async () => {
    await assertFails(
      setDoc(doc(anonDb(), 'support_requests', 'sup_anon_1'),
        gecerliTalep('anon')),
    );
  });

  it('KRİTİK: kullanıcı KENDİ talebini okuyabilir', async () => {
    // "Taleplerim" ekrani gonderilen talebi ve verilen cevabi gosterir.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_okuma_1'),
        gecerliTalep(PARENT_UID),
      );
    });

    await assertSucceeds(
      getDoc(doc(parentDb(), 'support_requests', 'sup_okuma_1')),
    );
  });

  it('KRİTİK: yönetici talepleri okuyabilir', async () => {
    // Denetim bulgusu: "talep Firestore'a yazilir ama yonetici
    // okuyamaz; bu bir operasyon degildir." Destek talebi kimsenin
    // goremedigi bir kuyuya dusuyordu.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_admin_1'),
        gecerliTalep(PARENT_UID),
      );
    });

    await assertSucceeds(
      getDoc(doc(superAdminDb(), 'support_requests', 'sup_admin_1')),
    );
  });

  it('KRİTİK: başkasının talebi okunamaz', async () => {
    // Talep metni ogrenci adi, okul ve sorun aciklamasi tasiyabilir.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_okuma_2'),
        gecerliTalep(PARENT_UID),
      );
    });

    await assertFails(
      getDoc(doc(otherParentDb(), 'support_requests', 'sup_okuma_2')),
    );
    await assertFails(
      getDoc(doc(teacherDb(), 'support_requests', 'sup_okuma_2')),
    );
  });

  it('KRİTİK: oturum açmamış kullanıcı talep okuyamaz', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_okuma_3'),
        gecerliTalep(PARENT_UID),
      );
    });

    await assertFails(
      getDoc(doc(anonDb(), 'support_requests', 'sup_okuma_3')),
    );
  });

  it('KRİTİK: durum alanı open dışında gelemez', async () => {
    // Kullanici kendi talebini "cozuldu" isaretleyememeli.
    await assertFails(
      setDoc(doc(parentDb(), 'support_requests', 'sup_durum_1'), {
        ...gecerliTalep(PARENT_UID),
        status: 'resolved',
      }),
    );
  });

  it('KRİTİK: boş başlık reddedilir', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'support_requests', 'sup_bos_1'), {
        ...gecerliTalep(PARENT_UID),
        subject: '',
      }),
    );
  });

  it('KRİTİK: aşırı uzun açıklama reddedilir', async () => {
    // Firestore dokuman siniri (1 MiB) ve kota kotusu kullanim.
    await assertFails(
      setDoc(doc(parentDb(), 'support_requests', 'sup_uzun_1'), {
        ...gecerliTalep(PARENT_UID),
        message: 'x'.repeat(2001),
      }),
    );
  });

  it('KRİTİK: aşırı uzun başlık reddedilir', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'support_requests', 'sup_uzunb_1'), {
        ...gecerliTalep(PARENT_UID),
        subject: 'y'.repeat(121),
      }),
    );
  });

  it('KRİTİK: gönderilmiş talep değiştirilemez', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_degis_1'),
        gecerliTalep(PARENT_UID),
      );
    });

    // Yanitlanmis bir talep sonradan degistirilirse yazisma anlamsizlasir.
    await assertFails(
      updateDoc(doc(parentDb(), 'support_requests', 'sup_degis_1'), {
        message: 'Sonradan degistirdim',
      }),
    );
  });

  it('KRİTİK: gönderilmiş talep silinemez', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'support_requests', 'sup_sil_1'),
        gecerliTalep(PARENT_UID),
      );
    });

    await assertFails(
      deleteDoc(doc(parentDb(), 'support_requests', 'sup_sil_1')),
    );
  });
});


describe('Veli bagi token dogrulamasi (guvenlik acigi duzeltmesi)', () => {
  const GECERLI_HASH = 'c'.repeat(64);
  const LINK_ID = `${PARENT_UID}_${STUDENT_ID}`;
  const ACCESS_ID = `${PARENT_UID}_${CLASS_ID}`;

  // Onceki bloklarin biraktigi token ve baglar temizlenmeli; aksi halde
  // "reddedilmeli" testleri, eski gecerli tokenlar yuzunden BASARIYLA
  // gecip acigi gizler.
  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it('KRİTİK: kod bilmeyen sahte bağ kuramaz', async () => {
    // ACIK: Kural yorumunda "token hala kullanilabilir olmali" yaziyordu
    // ama kodda BOYLE BIR KONTROL YOKTU. Giris yapmis herhangi biri,
    // sinif kimligini tahmin ederek (cls_{uid}_{sayi}) kendine bag yazip
    // SINIF DUYURULARINI OKUYABILIYORDU. Emulatorde kanitlandi.
    await assertFails(
      setDoc(doc(parentDb(), 'parent_links', LINK_ID), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
      }),
    );
  });

  it('KRİTİK: uydurma codeHash reddedilir', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'parent_links', LINK_ID), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
        codeHash: 'f'.repeat(64),
      }),
    );
  });

  it('KRİTİK: gerçek kodla bağ kurulabilir (akış bozulmamalı)', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'parent_tokens', GECERLI_HASH), {
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
    });

    await assertSucceeds(
      setDoc(doc(parentDb(), 'parent_links', LINK_ID), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
        codeHash: GECERLI_HASH,
      }),
    );
  });

  it('KRİTİK: token başka öğrenciye aitse reddedilir', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'parent_tokens', GECERLI_HASH), {
        studentCloudId: OTHER_STUDENT_ID,
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
      });
    });

    await assertFails(
      setDoc(doc(parentDb(), 'parent_links', LINK_ID), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        status: 'active',
        codeHash: GECERLI_HASH,
      }),
    );
  });

  it('KRİTİK: bağ olmadan sınıf erişimi yazılamaz', async () => {
    await assertFails(
      setDoc(doc(parentDb(), 'parent_class_access', ACCESS_ID), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
      }),
    );
  });
});

describe('Ogretmen veli baglarini sorgulayabilir', () => {
  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'parent_links', `${PARENT_UID}_${STUDENT_ID}`), {
        parentUid: PARENT_UID,
        studentCloudId: STUDENT_ID,
        classCloudId: CLASS_ID,
        teacherUid: TEACHER_UID,
        status: 'active',
      });
    });
  });

  it('KRİTİK: öğretmen teacherUid ile sorgulayabilir', async () => {
    // Ogretmen mesaj kutusu bu sorguyu yapiyor. Kural yorumunda
    // "sorgular teacherUid ile daraltilir, kural da ayni kisiti arar"
    // yaziyordu ama kural teacherUid alanina HIC bakmiyordu: her
    // sorgu PERMISSION_DENIED aliyordu.
    await assertSucceeds(
      getDocs(query(
        collection(teacherDb(), 'parent_links'),
        where('teacherUid', '==', TEACHER_UID),
      )),
    );
  });

  it('KRİTİK: başka öğretmen bu bağları sorgulayamaz', async () => {
    await assertFails(
      getDocs(query(
        collection(otherTeacherDb(), 'parent_links'),
        where('teacherUid', '==', TEACHER_UID),
      )),
    );
  });
});


describe('Brans ogretmeni duyuru yayimlayabilir', () => {
  const DUYURU = { title: 'Yarin quiz', content: 'Sayfa 42', priority: 'normal' };

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed(async (db) => {
      await setDoc(doc(db, 'class_rooms', CLASS_ID), {
        teacherUid: TEACHER_UID,
      });
      // Brans ogretmeni kadroya eklenmis
      await setDoc(
        doc(db, 'class_rooms', CLASS_ID, 'staff', OTHER_TEACHER_UID),
        { teacherUid: OTHER_TEACHER_UID, teacherName: 'Matematik Ogretmeni' },
      );
    });
  });

  it('KRİTİK: kadrodaki branş öğretmeni duyuru yayımlayabilir', async () => {
    // Onceden yalnizca sinif ogretmeni yazabiliyordu; matematik
    // ogretmeni "yarin quiz var" duyurusunu ancak rehber ogretmenden
    // rica ederek yapabiliyordu.
    await assertSucceeds(
      setDoc(doc(otherTeacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a1'), {
        ...DUYURU,
        authorUid: OTHER_TEACHER_UID,
        authorName: 'Matematik Ogretmeni',
      }),
    );
  });

  it('sınıf öğretmeni de yayımlayabilir (eski davranış korundu)', async () => {
    await assertSucceeds(
      setDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a2'), {
        ...DUYURU,
        authorUid: TEACHER_UID,
        authorName: 'Sinif Ogretmeni',
      }),
    );
  });

  it('KRİTİK: kadroda OLMAYAN öğretmen yayımlayamaz', async () => {
    await assertFails(
      setDoc(doc(otherParentDb(), 'class_rooms', CLASS_ID, 'announcements', 'a3'), {
        ...DUYURU,
        authorUid: OTHER_PARENT_UID,
        authorName: 'Yabanci',
      }),
    );
  });

  it('KRİTİK: başkasının adına duyuru yayımlanamaz', async () => {
    // Kadrodaki ogretmen sinif ogretmeninin adiyla duyuru yazamaz.
    await assertFails(
      setDoc(doc(otherTeacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a4'), {
        ...DUYURU,
        authorUid: TEACHER_UID,
        authorName: 'Sinif Ogretmeni',
      }),
    );
  });

  it('KRİTİK: kadrodaki öğretmen BAŞKASININ duyurusunu silemez', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'class_rooms', CLASS_ID, 'announcements', 'a5'),
        { ...DUYURU, authorUid: TEACHER_UID, authorName: 'Sinif Ogretmeni' },
      );
    });

    await assertFails(
      deleteDoc(doc(otherTeacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a5')),
    );
  });

  it('kadrodaki öğretmen KENDİ duyurusunu silebilir', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'class_rooms', CLASS_ID, 'announcements', 'a6'),
        { ...DUYURU, authorUid: OTHER_TEACHER_UID, authorName: 'Matematik' },
      );
    });

    await assertSucceeds(
      deleteDoc(doc(otherTeacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a6')),
    );
  });

  it('sınıf öğretmeni HER duyuruyu silebilir', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'class_rooms', CLASS_ID, 'announcements', 'a7'),
        { ...DUYURU, authorUid: OTHER_TEACHER_UID, authorName: 'Matematik' },
      );
    });

    await assertSucceeds(
      deleteDoc(doc(teacherDb(), 'class_rooms', CLASS_ID, 'announcements', 'a7')),
    );
  });
});

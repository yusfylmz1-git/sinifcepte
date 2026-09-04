import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/parent_portal/data/models/parent_token_model.dart';
import 'package:sinifcepte/features/parent_portal/data/services/student_lifecycle_policy.dart';

/// Veli referans kodu yasam dongusu testleri.
///
/// Kararlar (kullanici, 30 Agustos 2026):
///  - Kodun gun bazli suresi yoktur; olayla kapanir (mezuniyet, baska
///    okula nakil, ogrenci silme, elle iptal).
///  - Sube degisikliginde bag KORUNUR, yalnizca sinif erisimi guncellenir.
///  - Ogrenci silinince tam temizlik yapilir (yerel + bulut).
///  - Ikinci veli kodu istege baglidir (ayri aileler icin).
void main() {
  ParentTokenModel token({
    int studentId = 1,
    int classId = 10,
    String status = 'active',
    String parentLabel = '',
    DateTime? expiresAt,
  }) {
    return ParentTokenModel(
      id: 'tok_$studentId',
      schoolId: 'okul1',
      schoolName: 'Test Okulu',
      classId: classId,
      className: '7-A',
      studentId: studentId,
      studentName: 'Ali Veli',
      studentNumber: 101,
      code: 'SC-7A-1234',
      codeHash: 'hash',
      secondFactorHash: 'hash2',
      createdAt: DateTime(2026, 9, 1),
      expiresAt: expiresAt ?? ParentTokenModel.noExpiry,
      status: status,
      parentLabel: parentLabel,
      qrPayload: '{}',
    );
  }

  group('Kod gecerliligi olaya baglidir', () {
    test('KRITIK: kod gun gectikce kendiliginden olmez', () {
      // Eskiden kodun gun bazli suresi vardi; veli her donem yeniden kod
      // istemek zorunda kaliyordu. Artik ogrenci okulda oldugu surece
      // gecerli.
      final t = token();
      expect(t.isExpired, isFalse);
      expect(t.isValid, isTrue);
    });

    test('Elle iptal edilen kod gecersizdir', () {
      expect(token(status: 'revoked').isValid, isFalse);
    });

    test('Mezun olan ogrencinin kodu gecersizdir', () {
      expect(token(status: 'graduated').isValid, isFalse);
    });

    test('Baska okula nakil olan ogrencinin kodu gecersizdir', () {
      expect(token(status: 'transferred').isValid, isFalse);
    });

    test('Eski surumden gelen tarihli kod hala saygi gorur', () {
      // Geriye donuk uyumluluk: daha once uretilmis, suresi dolmus
      // kodlar gecersiz kalmalidir.
      final gecmis = token(expiresAt: DateTime(2020, 1, 1));
      expect(gecmis.isExpired, isTrue);
      expect(gecmis.isValid, isFalse);
    });
  });

  group('Ogrenci ayrilma senaryolari', () {
    test('KRITIK: baska okula nakil butun erisimi kapatir', () {
      final karar = StudentLifecyclePolicy.forDeparture(
        DepartureReason.transferredToAnotherSchool,
      );

      expect(karar.revokeTokens, isTrue);
      expect(karar.endParentLinks, isTrue,
          reason: 'Baska okula giden ogrencinin velisi erisemez');
      expect(karar.removeClassAccess, isTrue);
      expect(karar.tokenStatus, 'transferred');
    });

    test('KRITIK: mezuniyet erisimi kapatir', () {
      final karar =
          StudentLifecyclePolicy.forDeparture(DepartureReason.graduated);

      expect(karar.revokeTokens, isTrue);
      expect(karar.endParentLinks, isTrue);
      expect(karar.tokenStatus, 'graduated');
    });

    test('KRITIK: ogrenci silinince tam temizlik yapilir', () {
      final karar =
          StudentLifecyclePolicy.forDeparture(DepartureReason.deleted);

      expect(karar.revokeTokens, isTrue);
      expect(karar.endParentLinks, isTrue);
      expect(karar.removeClassAccess, isTrue);
      expect(karar.purgeLocalData, isTrue,
          reason: 'KVKK unutulma hakki: cihazdaki veri de silinmeli');
    });
  });

  group('Sube degisikligi (ayni okul)', () {
    test('KRITIK: bag korunur, veli yeniden kod almaz', () {
      final karar = StudentLifecyclePolicy.forClassChange(
        oldClassId: 10,
        newClassId: 11,
      );

      expect(karar.endParentLinks, isFalse,
          reason: 'Ayni cocuk, ayni okul: bagin kopmasi icin sebep yok');
      expect(karar.revokeTokens, isFalse);
    });

    test('KRITIK: eski sinif erisimi kapanir, yenisi acilir', () {
      final karar = StudentLifecyclePolicy.forClassChange(
        oldClassId: 10,
        newClassId: 11,
      );

      expect(karar.removeClassAccess, isTrue,
          reason: 'Veli eski sinifin duyurularini gormeye devam edemez');
      expect(karar.grantNewClassAccess, isTrue);
    });

    test('Ayni sinifa tasima islem gerektirmez', () {
      final karar = StudentLifecyclePolicy.forClassChange(
        oldClassId: 10,
        newClassId: 10,
      );

      expect(karar.isNoOp, isTrue);
      expect(karar.removeClassAccess, isFalse);
    });
  });

  group('Ikinci veli kodu', () {
    test('Varsayilan kodun veli etiketi bostur', () {
      expect(token().parentLabel, isEmpty);
      expect(token().isSecondParentCode, isFalse);
    });

    test('KRITIK: ikinci veli kodu ayirt edilir', () {
      // Ayri yasayan ailelerde kritik: babadan kodu geri almak
      // annenin erisimini etkilememeli.
      final anne = token(parentLabel: 'Anne');
      final baba = token(parentLabel: 'Baba');

      expect(anne.isSecondParentCode, isTrue);
      expect(baba.isSecondParentCode, isTrue);
      expect(anne.parentLabel, isNot(baba.parentLabel));
    });

    test('Etiketli kod ekranda ayirt edici baslik gosterir', () {
      expect(token(parentLabel: 'Anne').displayLabel, contains('Anne'));
      // Etiketsiz kodda ogrenci adi yeterlidir.
      expect(token().displayLabel, isNot(contains('—')));
    });
  });

  group('Bir kodla iki veli baglanabilir', () {
    test('Tek kod anne ve babayi birlikte tasir', () {
      // Varsayilan akis: ogretmen tek kod verir, anne de baba da girer.
      final t = token();
      expect(t.maxLinkedParents, 2);
      expect(t.isValid, isTrue);
    });

    test('Kontenjan dolunca kod yeni baglanti kabul etmez', () {
      final dolu = token().copyWith(linkedParentCount: 2);
      expect(dolu.isValid, isFalse);
    });
  });
}

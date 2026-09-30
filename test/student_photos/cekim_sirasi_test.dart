import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sinifcepte/core/config/app_config.dart';
import 'package:sinifcepte/core/database/database_helper.dart';
import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/data/repositories/class_repository.dart';
import 'package:sinifcepte/data/repositories/student_repository.dart';
import 'package:sinifcepte/features/student_photos/data/cekim_oturumu_deposu.dart';
import 'package:sinifcepte/features/student_photos/domain/cekim_sirasi.dart';

/// Faz 3: seri çekim sırası ve kalıcı oturum.
/// Çıkış ölçütü: 40 kişilik oturum kesintiden sonra doğru öğrenciden sürer.
void main() {
  group('sıra', () {
    final hepsi = {1, 2, 3, 4, 5};

    test('sırayla ilerliyor, kaydedilen ve atlanan tekrar gelmiyor', () {
      var s = const CekimSirasi(sira: [1, 2, 3, 4, 5]);
      expect(s.siradaki(hepsi), 1);
      s = s.kaydedildi(1);
      expect(s.siradaki(hepsi), 2);
      s = s.atlandi(2);
      expect(s.siradaki(hepsi), 3);
      s = s.kaydedildi(3).kaydedildi(4).kaydedildi(5);
      expect(s.siradaki(hepsi), isNull, reason: 'yalnızca atlanan kaldı');
      expect(s.sayim(hepsi), (toplam: 5, tamam: 4, atlanan: 1, kalan: 0));
      s = s.atlananlarSiraya();
      expect(s.siradaki(hepsi), 2);
    });

    test('KRITIK: oturum sürerken silinen ya da taşınan öğrenci sırada görünmüyor', () {
      final s = const CekimSirasi(sira: [1, 2, 3]).kaydedildi(1);
      expect(s.siradaki({1, 3}), 3, reason: '2 artık sınıfta değil');
      expect(s.sayim({1, 3}).toplam, 2);
    });

    test('KRITIK: son çekimi geri al → aynı öğrenci yeniden sıradaki', () {
      final s = const CekimSirasi(sira: [1, 2, 3]).kaydedildi(1).kaydedildi(2);
      expect(s.siradaki(hepsi), 3);
      final g = s.geriAlindi(2);
      expect(g.siradaki(hepsi), 2);
      expect(g.tamamlanan, {1});
    });

    test('öğrenci değiştirme: sıra dışından kaydedilen öğrenci sonra atlanır', () {
      // Öğretmen 1'deyken 4'ü çekti (öğrenciyi değiştir).
      final s = const CekimSirasi(sira: [1, 2, 3, 4]).kaydedildi(4);
      expect(s.siradaki(hepsi), 1, reason: 'başa sarar, 1 hâlâ çekilmedi');
      final t = s.kaydedildi(1).kaydedildi(2).kaydedildi(3);
      expect(t.siradaki(hepsi), isNull, reason: '4 ikinci kez sorulmaz');
    });

    test('satır gidiş-dönüşü ve bozuk kayıt', () {
      final s = const CekimSirasi(sira: [5, 3, 9]).kaydedildi(5).atlandi(3);
      final m = {
        'student_order': s.siraJson,
        'completed': s.tamamlananJson,
        'skipped': s.atlananJson,
        'position': s.konum,
      };
      final d = CekimSirasi.satirdan(m);
      // Kayıt eşitliği içteki liste/kümeyi kimlikle karşılaştırır; ayrı ayrı.
      expect(d.sira, [5, 3, 9]);
      expect(d.tamamlanan, {5});
      expect(d.atlanan, {3});
      expect(d.konum, 2);
      final bozuk = CekimSirasi.satirdan({'student_order': '{bozuk', 'position': 1});
      expect(bozuk.sira, isEmpty);
      expect(bozuk.siradaki({1}), isNull);
    });
  });

  group('kalıcı oturum', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppConfig.testDbNameOverride = 'cekim_oturumu_test.db';
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late int sinifId;
    late List<int> idler;
    Future<Database> db() => DatabaseHelper.instance.database;

    setUp(() async {
      await DatabaseHelper.instance.resetForTests();
      sinifId = await ClassRepository().insertClass(const ClassModel(
        name: '5-A',
        subject: 'Türkçe',
        academicYear: '2026-2027',
      ));
      idler = [];
      for (var i = 1; i <= 40; i++) {
        idler.add(await StudentRepository().insertStudent(
            StudentModel(classId: sinifId, schoolNumber: i, firstName: 'Ö$i', lastName: 'S')));
      }
    });

    test('KRITIK: 40 kişilik oturum kesintiden sonra doğru öğrenciden sürüyor', () async {
      final depo = CekimOturumuDeposu(db);
      var (id, s) = await depo.baslat(sinifId, idler);
      for (var i = 0; i < 17; i++) {
        s = s.kaydedildi(s.siradaki(idler.toSet())!);
        await depo.yaz(id, s);
      }
      s = s.atlandi(s.siradaki(idler.toSet())!); // 18. atlandı
      await depo.yaz(id, s);

      // Uygulama kapandı: bağlantı kapanır, oturum veritabanından okunur.
      await DatabaseHelper.instance.closeConnection();
      final geri = await CekimOturumuDeposu(db).aktif(sinifId);
      expect(geri, isNotNull);
      expect(geri!.$1, id);
      expect(geri.$2.siradaki(idler.toSet()), idler[18], reason: '19. öğrenciden sürmeli');
      expect(geri.$2.sayim(idler.toSet()), (toplam: 40, tamam: 17, atlanan: 1, kalan: 22));
    });

    test('sınıf başına tek süren oturum; bitirilince aktif yok', () async {
      final depo = CekimOturumuDeposu(db);
      final (ilk, _) = await depo.baslat(sinifId, idler);
      final (ikinci, _) = await depo.baslat(sinifId, idler.sublist(0, 5));
      expect(ilk == ikinci, isFalse);
      expect((await depo.aktif(sinifId))!.$1, ikinci);
      final d = await db();
      final suren = await d.query('photo_capture_sessions', where: "status = 'suruyor'");
      expect(suren.length, 1);
      await depo.bitir(ikinci);
      expect(await depo.aktif(sinifId), isNull);
    });

    test('sınıf silinince oturumu da gidiyor', () async {
      final depo = CekimOturumuDeposu(db);
      await depo.baslat(sinifId, idler);
      await ClassRepository().deleteClass(sinifId);
      final d = await db();
      expect(await d.query('photo_capture_sessions'), isEmpty);
    });

    test('veritabanı dosyası adı ayrı (paralel testler)', () async {
      expect(p.basename((await db()).path), 'cekim_oturumu_test.db');
    });
  });
}

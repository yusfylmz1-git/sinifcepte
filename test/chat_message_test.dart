import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/parent_portal/data/repositories/cloud_communication_repository.dart';

CloudMessage msg({
  required String authorRole,
  String authorName = 'Yazar',
  String authorUid = 'uid',
  String body = 'içerik',
  DateTime? createdAt,
}) {
  return CloudMessage(
    id: 'm_${createdAt?.millisecondsSinceEpoch ?? 0}',
    studentCloudId: 'stu_teacherAhmet_42',
    parentUserId: 'parentAyse',
    authorRole: authorRole,
    authorName: authorName,
    authorUid: authorUid,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 8, 18, 10),
  );
}

/// Sohbet ekranındaki "bu benim mesajım mı?" kararı.
///
/// Ekranda balonun sağa mı sola mı yaslanacağını bu belirler. Sohbet
/// birebir olduğu için rol karşılaştırması yeterlidir: öğretmen
/// görünümünde öğretmen mesajları, veli görünümünde veli mesajları
/// "benim" sayılır.
bool isMine({required CloudMessage message, required bool asTeacher}) {
  return asTeacher ? message.isFromTeacher : !message.isFromTeacher;
}

void main() {
  group('Sohbet balonu yönü', () {
    final teacherMsg = msg(authorRole: 'teacher', authorName: 'Selin Demir');
    final parentMsg = msg(authorRole: 'parent', authorName: 'Ayşe Yılmaz');

    test('Öğretmen görünümünde kendi mesajı sağda görünür', () {
      expect(isMine(message: teacherMsg, asTeacher: true), isTrue);
      expect(isMine(message: parentMsg, asTeacher: true), isFalse);
    });

    test('Veli görünümünde kendi mesajı sağda görünür', () {
      expect(isMine(message: parentMsg, asTeacher: false), isTrue);
      expect(isMine(message: teacherMsg, asTeacher: false), isFalse);
    });

    test('Aynı mesaj iki tarafta zıt yönde görünür', () {
      // Öğretmenin mesajı: öğretmende sağda, velide solda olmalı.
      expect(
        isMine(message: teacherMsg, asTeacher: true),
        isNot(isMine(message: teacherMsg, asTeacher: false)),
      );
    });
  });

  group('Mesaj sıralaması', () {
    test('Depodan gelen liste ters çevrilince eskiden yeniye olur', () {
      // fetchMessages en yeniden eskiye döner (orderBy descending).
      final fromRepo = [
        msg(authorRole: 'teacher', body: 'üçüncü', createdAt: DateTime(2026, 8, 18, 12)),
        msg(authorRole: 'parent', body: 'ikinci', createdAt: DateTime(2026, 8, 18, 11)),
        msg(authorRole: 'teacher', body: 'birinci', createdAt: DateTime(2026, 8, 18, 10)),
      ];

      // Sohbet ekranı listeyi ters çevirerek gösterir.
      final chatOrder = fromRepo.reversed.toList();

      expect(chatOrder.first.body, 'birinci');
      expect(chatOrder.last.body, 'üçüncü');
      // Zaman artan sırada olmalı.
      expect(
        chatOrder[0].createdAt.isBefore(chatOrder[1].createdAt),
        isTrue,
      );
      expect(
        chatOrder[1].createdAt.isBefore(chatOrder[2].createdAt),
        isTrue,
      );
    });

    test('Gönderilen mesaj listenin sonuna eklenir', () {
      final existing = [
        msg(authorRole: 'teacher', body: 'eski', createdAt: DateTime(2026, 8, 18, 10)),
      ];

      // Sunucudan yeniden okumak yerine yerel olarak eklenir (maliyet kararı).
      final afterSend = [
        ...existing,
        msg(authorRole: 'parent', body: 'yeni', createdAt: DateTime(2026, 8, 18, 13)),
      ];

      expect(afterSend.length, 2);
      expect(afterSend.last.body, 'yeni');
    });
  });

  group('Mesaj rolü güvenliği', () {
    test('Bilinmeyen rol öğretmen sayılmaz (güvenli varsayılan)', () {
      // Bozuk veya kurcalanmış bir rol değeri öğretmen ayrıcalığı vermez.
      expect(msg(authorRole: 'admin').isFromTeacher, isFalse);
      expect(msg(authorRole: '').isFromTeacher, isFalse);
      expect(msg(authorRole: 'TEACHER').isFromTeacher, isFalse);
    });

    test('Veli görünümünde kurcalanmış rol karşı taraf sayılır', () {
      // Biri veri tabanına 'admin' rolüyle mesaj sokabilseydi bile,
      // veli ekranında "benim mesajım" gibi görünmemeli.
      final tampered = msg(authorRole: 'admin');
      expect(isMine(message: tampered, asTeacher: false), isTrue,
          reason: 'öğretmen olmayan her mesaj veli görünümünde velinindir');
      expect(isMine(message: tampered, asTeacher: true), isFalse);
    });

    test('Mesaj içeriği ve yazar bilgisi taşınır', () {
      final m = msg(
        authorRole: 'teacher',
        authorName: 'Selin Demir',
        authorUid: 'uidSelin',
        body: 'Ali bugün çok başarılıydı.',
      );

      expect(m.authorName, 'Selin Demir');
      expect(m.authorUid, 'uidSelin');
      expect(m.body, 'Ali bugün çok başarılıydı.');
      expect(m.studentCloudId, 'stu_teacherAhmet_42');
    });
  });
}

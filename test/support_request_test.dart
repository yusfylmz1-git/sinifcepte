import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/support/support_repository.dart';
import 'package:sinifcepte/core/support/support_request.dart';

/// Destek talebi (Faz 1.2).
///
/// `HelpSupportModal` "Destek Talebini Gonder" diyor ve ardindan
/// "en gec 24 saat icinde yanitlanir" vaat ediyordu. Gercekte talep
/// YALNIZCA cihazdaki yerel denetim gunlugune yaziliyordu — kimse
/// gormuyordu. Kullanici yardim istedigini saniyor, karsiliginda
/// hicbir sey olmuyordu.
void main() {
  SupportRequest talep({
    String userId = 'uid123',
    String subject = 'Kod calismiyor',
    String message = 'Referans kodunu girince hata veriyor.',
    SupportCategory kategori = SupportCategory.codeIssue,
  }) {
    return SupportRequest.create(
      userId: userId,
      userRole: 'parent',
      category: kategori,
      subject: subject,
      message: message,
    );
  }

  group('Kimlik uretimi', () {
    test('KRITIK: ayni anda gonderilen iki talep birbirini ezmez', () {
      final zaman = DateTime(2026, 9, 1, 10, 30);
      final a = SupportRequest.create(
        userId: 'uid123',
        userRole: 'parent',
        category: SupportCategory.other,
        subject: 'A',
        message: 'A',
        now: zaman,
      );
      final b = SupportRequest.create(
        userId: 'uid123',
        userRole: 'parent',
        category: SupportCategory.other,
        subject: 'B',
        message: 'B',
        now: zaman,
      );

      expect(a.id, isNot(b.id),
          reason: 'zaman damgasi tek basina yetmez, rastgele sonek gerekir');
    });

    test('kimlik sup_ onekiyle baslar', () {
      expect(talep().id, startsWith('sup_'));
    });

    test('Firestore dokuman adinda yasakli karakter yok', () {
      final t = talep(userId: 'google.com:abc/def');
      expect(t.id, isNot(contains('/')),
          reason: 'Firestore dokuman adinda / yasak');
      expect(t.id, isNot(contains(':')));
    });
  });

  group('Uzunluk sinirlari', () {
    test('KRITIK: asiri uzun baslik kirpilir', () {
      final t = talep(subject: 'A' * 500);
      expect(t.subject.length, SupportRequest.maxSubjectLength);
    });

    test('KRITIK: asiri uzun aciklama kirpilir', () {
      final t = talep(message: 'B' * 10000);
      expect(t.message.length, SupportRequest.maxMessageLength);
    });

    test('normal uzunluktaki metin bozulmaz', () {
      const metin = 'Kisa bir aciklama.';
      expect(talep(message: metin).message, metin);
    });

    test('bastaki ve sondaki bosluk atilir', () {
      expect(talep(subject: '  Baslik  ').subject, 'Baslik');
    });
  });

  group('Dogrulama', () {
    test('KRITIK: bos baslik gecersiz', () {
      expect(talep(subject: '').isValid, isFalse);
      expect(talep(subject: '   ').isValid, isFalse);
    });

    test('KRITIK: bos aciklama gecersiz', () {
      expect(talep(message: '').isValid, isFalse);
    });

    test('dolu talep gecerli', () {
      expect(talep().isValid, isTrue);
    });
  });

  group('Bulut kaydi', () {
    test('KRITIK: durum her zaman open olarak yazilir', () {
      // Kullanici kendi talebini "cozuldu" isaretleyememeli.
      expect(talep().toMap()['status'], 'open');
    });

    test('kullanici kimligi kayda giriyor', () {
      expect(talep(userId: 'uid999').toMap()['userId'], 'uid999');
    });

    test('kategori kimligi yaziliyor', () {
      final m = talep(kategori: SupportCategory.bugReport).toMap();
      expect(m['category'], 'bug_report');
    });

    test('bos platform alani kayda eklenmiyor', () {
      expect(talep().toMap().containsKey('platform'), isFalse,
          reason: 'null alan Firestore dokumanini sisirmemeli');
    });

    test('gidis-donus bilgi kaybetmiyor', () {
      final t = talep();
      final geri = SupportRequest.fromMap(t.id, t.toMap());

      expect(geri.subject, t.subject);
      expect(geri.message, t.message);
      expect(geri.category, t.category);
      expect(geri.userId, t.userId);
    });
  });

  group('Kategori esleme', () {
    test('bilinmeyen kategori other olur', () {
      expect(SupportCategory.fromId('uydurma'), SupportCategory.other);
    });

    test('tum kategorilerin etiketi var', () {
      for (final k in SupportCategory.values) {
        expect(k.label, isNotEmpty);
        expect(k.id, isNotEmpty);
      }
    });
  });

  group('E-posta yedek yolu', () {
    test('KRITIK: destek adresi tanimli', () {
      expect(SupportRepository.supportEmail, 'sinifcepte@gmail.com');
    });

    test('mailto baglantisi dogru adrese gidiyor', () {
      final uri = SupportRepository.mailtoUri(talep());
      expect(uri.scheme, 'mailto');
      expect(uri.path, SupportRepository.supportEmail);
    });

    test('KRITIK: konu ve aciklama on doldurulmus geliyor', () {
      final uri = SupportRepository.mailtoUri(
        talep(subject: 'Test konu', message: 'Test mesaj'),
      );

      expect(uri.queryParameters['subject'], contains('Test konu'));
      expect(uri.queryParameters['subject'], contains('SınıfCepte'));
      expect(uri.queryParameters['body'], contains('Test mesaj'));
    });

    test('kategori ve rol e-postaya ekleniyor', () {
      final uri = SupportRepository.mailtoUri(
        talep(kategori: SupportCategory.bugReport),
      );
      final body = uri.queryParameters['body']!;

      expect(body, contains('Kategori:'));
      expect(body, contains('Rol:'));
    });
  });
}

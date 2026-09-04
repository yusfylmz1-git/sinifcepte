import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/core/moderation/content_guard.dart';

/// Mesaj icerik denetimi.
///
/// Mesajlarda HICBIR denetim yoktu: ne argo filtresi ne hiz siniri.
/// Ogretmen-veli iletisiminde hakaret ya da spam bombardimani hicbir
/// engele takilmiyordu.
///
/// En kritik risk YANLIS ALARM: masum bir mesaji uygunsuz sayip
/// ogretmeni ya da veliyi utandirmak, filtrenin hic olmamasindan
/// daha kotu olurdu.
void main() {
  final guard = ContentGuard.instance;

  setUp(guard.reset);
  tearDown(guard.reset);

  group('Argo yakalama', () {
    test('KRITIK: acik hakaret yakalanir', () {
      expect(ContentGuard.findOffensive('seni gerizekalı'), isNotNull);
      expect(ContentGuard.findOffensive('orospu çocuğu'), isNotNull);
      expect(ContentGuard.findOffensive('siktir git'), isNotNull);
    });

    test('KRITIK: Turkce karaktersiz yazim da yakalanir', () {
      // Kullanici klavyeden Turkce karakter yazmadan da hakaret edebilir.
      expect(ContentGuard.findOffensive('serefsiz'), isNotNull);
      expect(ContentGuard.findOffensive('yavsak'), isNotNull);
      expect(ContentGuard.findOffensive('gerizekali'), isNotNull);
    });

    test('buyuk harf farketmez', () {
      expect(ContentGuard.findOffensive('SALAK'), isNotNull);
      expect(ContentGuard.findOffensive('Aptal'), isNotNull);
    });

    test('cumle icinde gecen hakaret yakalanir', () {
      expect(
        ContentGuard.findOffensive('bu ne biçim iş salak mısınız'),
        isNotNull,
      );
    });
  });

  group('YANLIS ALARM olmamali', () {
    test('KRITIK: normal veli mesaji temiz gecer', () {
      const mesajlar = [
        'Merhaba hocam, Ahmet bugün rahatsızdı okula gelemedi.',
        'Yarınki sınav hangi konulardan olacak?',
        'Toplantı saat kaçta hocam?',
        'İlginiz için çok teşekkür ederim.',
        'Veli toplantısına katılamayacağım, kusura bakmayın.',
      ];
      for (final m in mesajlar) {
        expect(ContentGuard.findOffensive(m), isNull,
            reason: 'masum mesaj engellenmemeli: $m');
      }
    });

    test('KRITIK: "top" beden egitimi mesajinda yanlis alarm vermez', () {
      // Bu test filtreyi yazarken YANLIS ALARM yakaladi: "top" listede
      // oldugu icin masum bir beden dersi mesaji uyariliyordu. Kelime
      // listeden cikarildi.
      expect(ContentGuard.findOffensive('Beden dersine top getirsin mi?'),
          isNull);
      expect(ContentGuard.findOffensive('toplantı ne zaman'), isNull);
      expect(ContentGuard.findOffensive('Toplam kaç öğrenci var?'), isNull);
    });

    test('KRITIK: "anan" kelime icinde yanlis alarm vermez', () {
      expect(ContentGuard.findOffensive('anlaşılan yarın gelecek'), isNull);
      expect(ContentGuard.findOffensive('Ananas getirebilir miyim?'), isNull);
    });

    test('KRITIK: "mal" kelimesi masum baglamda gecer', () {
      expect(ContentGuard.findOffensive('malzeme listesi lazım'), isNull);
      expect(ContentGuard.findOffensive('Malatya gezisi'), isNull);
    });

    test('ogretmen adi yanlis alarm uretmez', () {
      expect(ContentGuard.findOffensive('Sayın Topaloğlu hocam'), isNull);
    });
  });

  group('Hiz siniri', () {
    test('KRITIK: dakikada 5 mesajdan sonrasi engellenir', () {
      final t = DateTime(2026, 9, 1, 10, 0);

      for (var i = 0; i < ContentGuard.maxPerMinute; i++) {
        final r = guard.check(
          userId: 'u1',
          body: 'mesaj $i',
          now: t.add(Duration(seconds: i)),
        );
        expect(r.isClean, isTrue, reason: '$i. mesaj gecmeliydi');
        guard.recordSent(
          userId: 'u1',
          body: 'mesaj $i',
          now: t.add(Duration(seconds: i)),
        );
      }

      final asan = guard.check(
        userId: 'u1',
        body: 'altinci mesaj',
        now: t.add(const Duration(seconds: 30)),
      );
      expect(asan.verdict, ContentVerdict.tooFast);
      expect(asan.blocks, isTrue);
    });

    test('bir dakika sonra tekrar gonderilebilir', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      for (var i = 0; i < ContentGuard.maxPerMinute; i++) {
        guard.recordSent(
          userId: 'u1',
          body: 'm$i',
          now: t.add(Duration(seconds: i)),
        );
      }

      final sonra = guard.check(
        userId: 'u1',
        body: 'yeni mesaj',
        now: t.add(const Duration(minutes: 2)),
      );
      expect(sonra.isClean, isTrue);
    });

    test('KRITIK: bir kullanicinin siniri digerini etkilemez', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      for (var i = 0; i < ContentGuard.maxPerMinute; i++) {
        guard.recordSent(userId: 'u1', body: 'm$i', now: t);
      }

      final digeri = guard.check(userId: 'u2', body: 'merhaba', now: t);
      expect(digeri.isClean, isTrue,
          reason: 'sayaclar kullanici bazinda tutulmali');
    });

    test('eski kayitlar temizleniyor (bellek sismesin)', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      for (var i = 0; i < 50; i++) {
        guard.recordSent(
          userId: 'u1',
          body: 'm$i',
          now: t.add(Duration(minutes: i * 5)),
        );
      }
      // Iki saat sonra gonderim serbest olmali
      final sonra = guard.check(
        userId: 'u1',
        body: 'yeni',
        now: t.add(const Duration(hours: 6)),
      );
      expect(sonra.isClean, isTrue);
    });
  });

  group('Tekrar kontrolu', () {
    test('KRITIK: ayni mesaj art arda gonderilemez', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      guard.recordSent(userId: 'u1', body: 'Merhaba hocam', now: t);

      final tekrar = guard.check(
        userId: 'u1',
        body: 'Merhaba hocam',
        now: t.add(const Duration(seconds: 5)),
      );
      expect(tekrar.verdict, ContentVerdict.repeated);
      expect(tekrar.blocks, isTrue);
    });

    test('farkli mesaj gecer', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      guard.recordSent(userId: 'u1', body: 'Merhaba hocam', now: t);

      final farkli = guard.check(
        userId: 'u1',
        body: 'Bir sorum olacaktı',
        now: t.add(const Duration(seconds: 5)),
      );
      expect(farkli.isClean, isTrue);
    });
  });

  group('Engelleme davranisi', () {
    test('KRITIK: argo ENGELLEMEZ, yalnizca uyarir', () {
      // Turkce baglamda yanlis alarm kacinilmaz; kullaniciyi
      // kilitlemek filtrenin hic olmamasindan kotu olurdu.
      final r = guard.check(userId: 'u1', body: 'salak herif');
      expect(r.verdict, ContentVerdict.offensive);
      expect(r.blocks, isFalse, reason: 'uyarir ama gondermeyi engellemez');
      expect(r.message, isNotNull);
    });

    test('hiz siniri ENGELLER', () {
      final t = DateTime(2026, 9, 1, 10, 0);
      for (var i = 0; i < ContentGuard.maxPerMinute; i++) {
        guard.recordSent(userId: 'u1', body: 'm$i', now: t);
      }
      expect(guard.check(userId: 'u1', body: 'yeni', now: t).blocks, isTrue);
    });

    test('bos mesaj ENGELLER', () {
      final r = guard.check(userId: 'u1', body: '   ');
      expect(r.verdict, ContentVerdict.empty);
      expect(r.blocks, isTrue);
    });
  });

  group('Sayac yalnizca gonderilince ilerler', () {
    test('KRITIK: uyariyi gorup vazgecen mesaj sayaca yazilmaz', () {
      final t = DateTime(2026, 9, 1, 10, 0);

      // Bes kez denetimden gecir ama HIC gonderme
      for (var i = 0; i < 5; i++) {
        guard.check(userId: 'u1', body: 'deneme $i', now: t);
      }

      final r = guard.check(userId: 'u1', body: 'gercek mesaj', now: t);
      expect(r.isClean, isTrue,
          reason: 'gonderilmeyen mesaj hiz sinirini doldurmamali');
    });
  });
}

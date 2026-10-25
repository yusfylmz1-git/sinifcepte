import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ana sayfa duzeni ve Akis bolumu.
///
/// Kullanici geri bildirimi:
/// > "gunun ders ozeti ve yaklasan sinav yer degiselim. cok fazla yer
/// > kapliyor ikiside iyice daraltalim. ayrica altta akis diye bir
/// > bolum olabilir orayada veliden gelen mesajlar veya bildirimler
/// > gosterilebilir. ayrica admin tarafindan gelen bir bildirim varsa
/// > orada gorunebilir."
void main() {
  String ekran() => File(
        'lib/features/dashboard/screens/dashboard_screen.dart',
      ).readAsStringSync();

  String saglayici() => File(
        'lib/features/dashboard/providers/activity_feed_provider.dart',
      ).readAsStringSync();

  group('Bolum sirasi degisti', () {
    test('KRITIK: ders programi sinavlardan ONCE geliyor', () {
      final kod = ekran();

      // Cagri sirasi onemli (tanim sirasi degil).
      final dersCagri = kod.indexOf('// 3. GÜNÜN DERS PROGRAMI');
      final sinavCagri = kod.indexOf('// 4. YAKLAŞAN SINAVLAR');

      expect(dersCagri, isNot(-1), reason: 'ders programi bolumu bulunamadi');
      expect(sinavCagri, isNot(-1), reason: 'sinav bolumu bulunamadi');
      expect(dersCagri, lessThan(sinavCagri),
          reason: 'ogretmen once "bugun hangi derse girecegim" gorur');
    });
  });

  group('Bolumler daraltildi', () {
    test('KRITIK: sinav ve ders kartlarinin dolgusu 12', () {
      final kod = ekran();
      // Ikisi de "cok fazla yer kapliyor" geri bildirimi aldi.
      expect(kod, contains('padding: const EdgeInsets.all(12)'));
    });

    test('bolumler arasi bosluk kisaldi', () {
      final kod = ekran();
      // 16'lik bosluklar 12'ye indi.
      expect(kod, contains('const SizedBox(height: 12),'));
    });
  });

  group('Akis bolumu', () {
    test('KRITIK: akis widgeti ana sayfada', () {
      final kod = ekran();
      expect(kod, contains('_buildActivityFeed'));
      expect(kod, contains("'Akış'"));
    });

    // 18 Ekim 2026: velilerden gelenler akista DEGIL, veli gelen
    // kutusunda. Akis onlari her acilista "yeni" sayan eski bildirim
    // hesabindan aliyordu (ogretmen tarafinda okunma takibi yoktu).
    // 26 Ekim 2026: gelen kutusu Ozet'te kart degil, ust cubukta zilin
    // yaninda (kullanici karari).
    test('KRITIK: veliden gelenler gelen kutusunda, akista degil', () {
      final kod = saglayici();
      expect(kod.contains('teacherNotificationsProvider'), isFalse);
      final ekr = ekran();
      expect(ekr.contains('GelenKutusuKarti'), isFalse, reason: 'Ozette kart yok');
      expect(ekr, contains('ref.invalidate(gelenKutusuProvider)'),
          reason: 'asagi cekince gelen kutusu da tazelenir');
      final ana = File('lib/features/navigation/screens/main_navigation_screen.dart').readAsStringSync();
      expect(ana, contains('GelenKutusuEkrani.ac(context)'));
    });

    test('KRITIK: yonetici duyurusu destekleniyor', () {
      final kod = saglayici();
      expect(kod, contains('adminNotice'));
      expect(kod, contains('FeedKind.admin'));
    });

    test('KRITIK: yonetici duyurusu en ustte', () {
      final kod = saglayici();
      expect(kod, contains('if (a.kind == FeedKind.admin) return -1'));
    });

    test('KRITIK: duyuru kapatilabiliyor ve tekrar gosterilmiyor', () {
      final kodS = saglayici();
      expect(kodS, contains('dismissAdminNotice'));
      expect(kodS, contains('_kDismissedNoticeKey'),
          reason: 'ayni duyuru her acilista cikmamali');

      final kodE = ekran();
      expect(kodE, contains('dismissAdminNotice'));
    });

    test('akis kisa tutuluyor', () {
      final kod = saglayici();
      expect(kod, contains('.take(6)'),
          reason: 'ana sayfa akisi ozet olmali, tamami bildirim merkezinde');
    });

    test('KRITIK: bos akis yer kaplamiyor', () {
      final kod = ekran();
      expect(kod, contains('if (items.isEmpty) return const SizedBox.shrink()'),
          reason: 'bos kart ana sayfada bosluk birakmamali');
    });
  });

  group('Yonetici duyurusu altyapisi', () {
    test('KRITIK: Remote Config alanlari tanimli', () {
      final kod = File(
        'lib/core/cloud/remote_manifest_service.dart',
      ).readAsStringSync();

      expect(kod, contains("'admin_notice'"));
      expect(kod, contains("'admin_notice_id'"));
      expect(kod, contains('final String adminNotice'));
    });

    test('duyuru kimligi ayri tutuluyor', () {
      // Yeni duyuru yayimlarken kimlik degistirilmeli ki daha once
      // kapatmis kullanicilar da yeniyi gorsun.
      final kod = File(
        'lib/core/cloud/remote_manifest_service.dart',
      ).readAsStringSync();
      expect(kod, contains('adminNoticeId'));
    });
  });
}

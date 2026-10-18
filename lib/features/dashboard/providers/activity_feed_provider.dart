import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/remote_manifest_service.dart';
import '../../../core/storage/prefs_service.dart';
import 'package:flutter/foundation.dart';

import '../../documents/data/special_days_repository.dart';

/// Ana sayfadaki "Akış" bölümünün öğesi.
///
/// Kaynakları:
///   * Yöneticiden gelen genel duyuru (Remote Config)
///   * Yaklaşan belirli gün ve haftalar
///
/// Velilerden gelenler 18 Ekim 2026'dan beri burada DEĞİL, Bugün'deki
/// "Veli gelen kutusu" kartında: akış onları her açılışta "yeni" sayan
/// eski bildirim hesabından alıyordu (öğretmen tarafında okunma takibi
/// yoktu).
class FeedItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime at;
  final FeedKind kind;

  const FeedItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.kind,
  });
}

enum FeedKind {
  /// Yöneticiden gelen genel duyuru.
  admin,

  /// Yaklaşan belirli gün veya hafta (MEB çizelgesi).
  specialDay,
}

/// Yöneticinin kapatılmış duyurusunu hatırlar.
///
/// Aynı duyuruyu her açılışta göstermek rahatsız edici olurdu.
const String _kDismissedNoticeKey = 'dismissed_admin_notice_id';

/// Ana sayfa akışı: yönetici duyurusu + yaklaşan belirli günler.
///
/// Firestore okuması yapmaz: duyuru Remote Config'den, belirli günler
/// paketteki çizelgeden gelir.
final dashboardFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final items = <FeedItem>[];

  // 1. Yönetici duyurusu (Remote Config — ücretsiz, kotasız).
  final manifest = RemoteManifestService.instance.manifest;
  final notice = manifest.adminNotice.trim();
  if (notice.isNotEmpty) {
    final dismissed = await _dismissedNoticeId();
    if (dismissed != manifest.adminNoticeId) {
      items.add(FeedItem(
        id: 'admin_${manifest.adminNoticeId}',
        title: 'SınıfCepte',
        subtitle: notice,
        at: DateTime.now(),
        kind: FeedKind.admin,
      ));
    }
  }

  // 2. Yaklaşan belirli gün / hafta.
  //
  // Öğretmen "önümüzdeki hafta ne var" diye ayrı ekrana bakmak
  // yerine ana sayfada görsün. Yalnızca 7 GÜN içindekiler ve EN FAZLA
  // İKİ tanesi alınır: akış velilerden gelen mesajlar için var, takvim
  // onu bastırmamalı.
  try {
    final gunler = await SpecialDaysRepository().upcoming(gunSayisi: 7);
    for (final g in gunler.take(2)) {
      items.add(FeedItem(
        id: 'ozel_${g.madde.ad}_${g.tarih.toIso8601String()}',
        title: g.madde.ad,
        subtitle: g.madde.tarihMetni,
        at: g.tarih,
        kind: FeedKind.specialDay,
      ));
    }
  } catch (e) {
    debugPrint('Akış: belirli günler okunamadı ($e)');
  }

  // Yönetici duyurusu her zaman en üstte; kalanlar yeniden eskiye.
  items.sort((a, b) {
    if (a.kind == FeedKind.admin) return -1;
    if (b.kind == FeedKind.admin) return 1;
    return b.at.compareTo(a.at);
  });

  // Ana sayfa akışı kısa tutulur; tamamı bildirim merkezinde.
  return items.take(6).toList();
});

Future<String> _dismissedNoticeId() async {
  try {
    final prefs = await PrefsService.instance();
    return prefs?.getString(_kDismissedNoticeKey) ?? '';
  } catch (_) {
    return '';
  }
}

/// Yönetici duyurusunu kapatır; aynı duyuru bir daha gösterilmez.
Future<void> dismissAdminNotice(String noticeId) async {
  try {
    final prefs = await PrefsService.instance();
    await prefs?.setString(_kDismissedNoticeKey, noticeId);
  } catch (_) {
    // Yazılamazsa duyuru bir sonraki açılışta yine görünür; zarar yok.
  }
}

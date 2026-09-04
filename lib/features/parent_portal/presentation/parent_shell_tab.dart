import 'package:flutter/material.dart';

/// Veli ekranının alt bar sekmeleri.
///
/// Sekme sırası bilinçlidir: veli uygulamayı en çok "çocuğum ne durumda?"
/// sorusuyla açar, o yüzden Özet ilk sıradadır. Mesajlar ikinci sırada
/// çünkü en sık dönülen ekrandır.
enum ParentShellTab {
  summary(
    label: 'Özet',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
  ),
  messages(
    label: 'Mesajlar',
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum_rounded,
  ),
  calendar(
    label: 'Takvim',
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note_rounded,
  ),
  profile(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  );

  const ParentShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Rozette gösterilecek metin; sayı yoksa null.
  ///
  /// Üç haneli sayılar rozeti yatay olarak taşırdığı için 99'da kesilir.
  static String? badgeText(int count) {
    if (count <= 0) return null;
    return count > 99 ? '99+' : '$count';
  }
}

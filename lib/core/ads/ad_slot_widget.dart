import 'package:flutter/material.dart';
import 'ad_gate.dart';

/// Reklam yer tutucusu.
///
/// Reklam kapalıyken [SizedBox.shrink] döner — yani hiç yer kaplamaz ve
/// mevcut ekran düzenini bozmaz. Bu sayede yer tutucular Faz 1'de
/// yerleştirilip Faz 7'ye kadar görünmez kalabilir.
///
/// Kullanım:
/// ```dart
/// const AdSlotWidget(
///   slot: AdSlot.parentDashboardBanner,
///   showsStudentData: false,
/// )
/// ```
///
/// [showsStudentData] çağıran ekranın dürüstçe bildirmesi gereken bir
/// bayraktır: ekranda öğrenci adı, notu, katılımı veya fotoğrafı görünüyorsa
/// `true` verilmelidir. Bu durumda reklam hiçbir koşulda gösterilmez.
class AdSlotWidget extends StatelessWidget {
  final AdSlot slot;

  /// Bu ekranda öğrenciye ait kişisel veri görünüyor mu?
  final bool showsStudentData;

  const AdSlotWidget({
    super.key,
    required this.slot,
    required this.showsStudentData,
  });

  @override
  Widget build(BuildContext context) {
    if (!AdGate.instance.isAllowedSlot(slot, showsStudentData: showsStudentData)) {
      return const SizedBox.shrink();
    }

    // Faz 7: burada gerçek banner/native reklam widget'ı döndürülecek.
    // Şimdilik açıkken bile boş kalır; SDK eklenene kadar yer kaplamaz.
    return const SizedBox.shrink();
  }
}

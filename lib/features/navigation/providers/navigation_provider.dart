import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt Bar Menü seçili sekme indeksi sağlayıcısı (0: Özet, 1: Sınıf, 2: Ders Programı, 3: Profil)
final navigationIndexProvider = StateProvider<int>((ref) => 0);

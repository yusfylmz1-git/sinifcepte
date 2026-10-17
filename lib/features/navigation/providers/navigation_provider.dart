import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt çubuktaki sekmelerin sırası. Sekme numarası YALNIZ buradan okunur.
///
/// Eskiden numaralar ana ekranda, ana sayfada ve Cepte'de ayrı ayrı elle
/// yazılıydı (`state = 3` gibi); sekmeler değişince biri eskide kalırdı
/// (17 Ekim 2026: Ders Programı sekmesi kalktı, yerine Evraklar geldi).
abstract final class AnaSekme {
  static const int bugun = 0;
  static const int siniflar = 1;
  static const int kazanimlar = 2;
  static const int evraklar = 3;
  static const int ben = 4;
}

/// Alt çubukta seçili sekme ([AnaSekme]).
final navigationIndexProvider = StateProvider<int>((ref) => AnaSekme.bugun);

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt çubuktaki sekmelerin sırası. Sekme numarası YALNIZ buradan okunur.
///
/// Eskiden numaralar ana ekranda, ana sayfada ve Cepte'de ayrı ayrı elle
/// yazılıydı (`state = 3` gibi); sekmeler değişince biri eskide kalırdı.
///
/// Kullanıcı kararı (26 Ekim 2026): Özet · Ders Programı · Sınıfım ·
/// Profil. Kazanımlar, Sınıflar, Evraklar, Rehberlik ve Sınav İşlemleri
/// Özet'teki düğmelerden sayfa olarak açılır.
abstract final class AnaSekme {
  static const int ozet = 0;
  static const int dersProgrami = 1;
  static const int sinifim = 2;
  static const int profil = 3;
}

/// Alt çubukta seçili sekme ([AnaSekme]).
final navigationIndexProvider = StateProvider<int>((ref) => AnaSekme.ozet);

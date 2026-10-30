/// Uygulamanın sürümü — ekranda gösterilen ve güncelleme denetiminde
/// kullanılan TEK değer.
///
/// ## Neden sabit ve neden test
/// Sürüm beş yerde ayrı ayrı elle yazılıydı ("1.0.0") ve uygulama 1.2.0'a
/// geldiğinde hepsi eskide kalmıştı (17 Ekim 2026). Paket okuyan bir
/// eklenti eklemek yerine tek sabit tutuluyor; `uygulama_surumu_test.dart`
/// bu değeri `pubspec.yaml`'daki sürümle karşılaştırır. Sürüm artırılıp
/// burası unutulursa test kırılır.
const String uygulamaSurumu = '1.3.1';

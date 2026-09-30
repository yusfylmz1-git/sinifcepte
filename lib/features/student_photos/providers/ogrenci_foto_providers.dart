import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/storage/prefs_service.dart';
import '../data/cekim_oturumu_deposu.dart';
import '../data/foto_alici.dart';
import '../data/foto_depolama.dart';
import '../data/ogrenci_foto_deposu.dart';
import '../domain/ogrenci_foto.dart';

/// Fotoğraf kaydedilince/silinince artar; bağlı listeler ve avatarlar
/// yeniden okunur. Tek tek sağlayıcı geçersiz kılmayı unutmaya karşı.
final fotoSurumuProvider = StateProvider<int>((ref) => 0);

final fotoDepolamaProvider = FutureProvider<FotoDepolama>((ref) => FotoDepolama.uygulamaIcin());

/// Veritabanı her çağrıda `DatabaseHelper`'dan istenir: hesap değişince
/// yeni hesabın dosyası ve fotoğraf alanı kullanılır.
final ogrenciFotoDeposuProvider = FutureProvider<OgrenciFotoDeposu>((ref) async {
  final depolama = await ref.watch(fotoDepolamaProvider.future);
  return OgrenciFotoDeposu(
    veritabani: () => DatabaseHelper.instance.database,
    depolama: depolama,
  );
});

/// Sınıfın güncel fotoğrafları, öğrenci kimliğine göre. TEK sorgu.
final sinifFotolariProvider =
    FutureProvider.family<Map<int, OgrenciFoto>, int>((ref, sinifId) async {
  ref.watch(fotoSurumuProvider);
  final depo = await ref.watch(ogrenciFotoDeposuProvider.future);
  return depo.sinifFotolari(sinifId);
});

final sinifFotoOzetleriProvider = FutureProvider<Map<int, SinifFotoOzeti>>((ref) async {
  ref.watch(fotoSurumuProvider);
  final depo = await ref.watch(ogrenciFotoDeposuProvider.future);
  return depo.sinifOzetleri();
});

/// Öğrenci fotoğrafları katılım kartı, rastgele seçici ve öğrenci
/// listesinde görünsün mü? (plan §4.9: öğretmen ders sırasında
/// kapatabilmeli). Cihaz tercihi; varsayılan açık.
///
/// Değer açılışta ısıtılmış önbellekten EŞZAMANLI okunur (`main.dart`
/// `PrefsService.warmUp()` bekliyor). Eşzamansız yükleme 3 sn'lik zaman
/// aşımı sayacı kuruyor ve katılım kartını çizen her widget testinde
/// "bekleyen zamanlayıcı" hatası veriyordu.
class FotolariGosterNotifier extends StateNotifier<bool> {
  FotolariGosterNotifier([bool? baslangic])
      : super(baslangic ?? PrefsService.cached?.getBool(anahtar) ?? true);

  static const String anahtar = 'eokul_foto_goster';

  void ayarla(bool v) {
    state = v;
    final c = PrefsService.cached;
    if (c != null) {
      c.setBool(anahtar, v);
    } else {
      PrefsService.instance().then((p) async {
        await p?.setBool(anahtar, v);
      });
    }
  }
}

final fotolariGosterProvider =
    StateNotifierProvider<FotolariGosterNotifier, bool>((ref) => FotolariGosterNotifier());

/// Galeri/kamera erişimi (testte sahtesi verilir).
final fotoAliciProvider = Provider<FotoAlici>((ref) => const FotoAlici());

final cekimOturumuDeposuProvider =
    Provider<CekimOturumuDeposu>((ref) => CekimOturumuDeposu(() => DatabaseHelper.instance.database));

/// Kaydetme/silme/aktarma sonrası çağrılır.
void fotolarDegisti(WidgetRef ref) => ref.read(fotoSurumuProvider.notifier).state++;

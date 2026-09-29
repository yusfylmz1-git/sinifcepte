import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_helper.dart';
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

/// Kaydetme/silme/aktarma sonrası çağrılır.
void fotolarDegisti(WidgetRef ref) => ref.read(fotoSurumuProvider.notifier).state++;

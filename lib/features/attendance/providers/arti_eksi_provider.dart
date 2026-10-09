import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/arti_eksi_model.dart';
import '../data/repositories/arti_eksi_repository.dart';

final artiEksiRepoProvider = Provider<ArtiEksiRepository>((ref) => ArtiEksiRepository());

/// Hangi sınıfın hangi aralıktaki kayıtları.
class ArtiEksiSorgu {
  final int classId;
  final ArtiEksiAraligi aralik;

  const ArtiEksiSorgu(this.classId, this.aralik);

  @override
  bool operator ==(Object other) =>
      other is ArtiEksiSorgu && other.classId == classId && other.aralik == aralik;

  @override
  int get hashCode => Object.hash(classId, aralik);
}

/// Sınıfın aralıktaki kayıtları, eklenme sırasıyla. Ekleme ve silmeden
/// sonra `invalidate` edilir; liste ve geçmiş penceresi birlikte yenilenir.
final artiEksiKayitlariProvider =
    FutureProvider.autoDispose.family<List<ArtiEksiKaydi>, ArtiEksiSorgu>((ref, s) {
  return ref.watch(artiEksiRepoProvider).kayitlar(classId: s.classId, aralik: s.aralik);
});

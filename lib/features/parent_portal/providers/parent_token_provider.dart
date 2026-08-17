import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/parent_link_model.dart';
import '../data/models/parent_token_model.dart';
import '../data/repositories/cloud_token_repository.dart';
import '../data/repositories/parent_token_repository.dart';
import '../data/services/parent_auth_service.dart';
import '../data/services/parent_link_bridge.dart';

/// ParentTokenRepository Sağlayıcısı (yerel depo — öğretmen tarafı)
final parentTokenRepositoryProvider = Provider<ParentTokenRepository>((ref) {
  return ParentTokenRepository();
});

/// Bulut token deposu (öğretmen ↔ veli köprüsünün alt katmanı)
final cloudTokenRepositoryProvider = Provider<CloudTokenRepository>((ref) {
  return CloudTokenRepository();
});

/// Token köprüsü: kodu buluta yayımlar ve veli tarafında doğrular.
final parentLinkBridgeProvider = Provider<ParentLinkBridge>((ref) {
  return ParentLinkBridge(cloudRepo: ref.watch(cloudTokenRepositoryProvider));
});

/// Veli kimlik doğrulama servisi (yalnızca Google).
final parentAuthServiceProvider = Provider<ParentAuthService>((ref) {
  return ParentAuthService();
});

/// Belirli Bir Öğrencinin Aktif Veli Referans Kodu Provider'ı
final studentActiveTokenProvider = FutureProvider.family<ParentTokenModel?, int>((ref, studentId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getActiveTokenForStudent(studentId);
});

/// Belirli Bir Öğrenciye Bağlı Velilerin Listesi Provider'ı (Öğretmen Görünümü)
final studentLinkedParentsProvider = FutureProvider.family<List<ParentLinkModel>, int>((ref, studentId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getLinkedParentsForStudent(studentId);
});

/// Belirli Bir Veliye Bağlı Çocukların Listesi Provider'ı (Veli Görünümü)
final parentConnectedChildrenProvider = FutureProvider.family<List<ParentLinkModel>, String>((ref, parentUserId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getParentLinksForParent(parentUserId);
});

/// Bu Cihazdaki Velinin Bağlı Tüm Çocukları Provider'ı
final myConnectedChildrenProvider = FutureProvider<List<ParentLinkModel>>((ref) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getMyConnectedChildren();
});

/// Aktif Seçili Çocuk İndeksi Provider'ı
final selectedChildIndexProvider = StateProvider<int>((ref) => 0);

/// Aktif Seçili Çocuk Modeli Provider'ı
final activeSelectedChildProvider = Provider<ParentLinkModel?>((ref) {
  final childrenAsync = ref.watch(myConnectedChildrenProvider);
  final selectedIndex = ref.watch(selectedChildIndexProvider);

  return childrenAsync.when(
    data: (list) {
      if (list.isEmpty) return null;
      if (selectedIndex >= list.length) return list.first;
      return list[selectedIndex];
    },
    loading: () => null,
    error: (e, stack) => null,
  );
});

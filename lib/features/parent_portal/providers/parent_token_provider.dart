import '../../auth_profile/data/services/teacher_identity.dart';
import '../../../core/cloud/cloud_ids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/class_model.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../classes/providers/student_provider.dart';
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
  final r = await repo.getActiveTokenForStudent(studentId);
  return r;
});

/// Bir Sınıfa Ait Tüm Öğrencilerin Aktif Veli Referans Kodları Haritası (studentId -> ParentTokenModel)
final classActiveTokensProvider = FutureProvider.family<Map<int, ParentTokenModel>, int>((ref, classId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getActiveTokensForClass(classId);
});

/// Bir Sınıfa Ait Veli Referans Kodlarını Otomatik Tamamlayan Provider
final classTokensProvider = FutureProvider.family<Map<int, ParentTokenModel>, ClassModel>((ref, classModel) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  final studentsAsync = ref.watch(studentListProvider(classModel.id ?? 0));
  final students = studentsAsync.valueOrNull ?? [];
  final teacher = ref.watch(teacherProfileProvider);

  final tokens = await repo.getOrGenerateTokensForClass(
    classModel: classModel,
    students: students,
    teacher: teacher,
  );

  // Üretilen kodları buluta yayımla.
  //
  // Bu yol eksikti: ekran açıldığında kodlar burada otomatik üretiliyor
  // ama YALNIZCA cihazda kalıyordu. Veli o kodu girdiğinde buluttaki
  // karşılığı olmadığı için bağ eksik kuruluyor ve veli ne duyuru ne
  // öğretmen görüyordu. (Firestore'da `parent_tokens` koleksiyonu hiç
  // oluşmamıştı — kanıt buydu.)
  //
  // Yalnızca bulutta bulunmayanlar yayımlanır; her ekran açılışında
  // tüm sınıfı yeniden yazmak bütçeyi tüketirdi.
  final uid = TeacherIdentity.resolve(teacher);
  if (CloudIds.isValidUid(uid) && tokens.isNotEmpty) {
    final bridge = ref.read(parentLinkBridgeProvider);
    for (final token in tokens.values) {
      if (token.status != 'active') continue;
      try {
        await bridge
            .publishTokenToCloud(
              token: token,
              teacherUid: uid,
              teacherName: teacher.fullName,
            )
            .timeout(const Duration(seconds: 10), onTimeout: () => false);
      } catch (e, stackTrace) {
        debugPrint('Kod buluta yayımlanamadı (${token.code}): $e\n$stackTrace');
      }
    }
  }

  return tokens;
});

/// Belirli Bir Öğrenciye Bağlı Velilerin Listesi Provider'ı (Öğretmen Görünümü)
/// Bir sınıftaki tüm bağlı veliler (öğretmenin mesaj kutusu).
///
/// Öncelik BULUTTADIR: yerel `parent_links` deposu yalnızca velinin kendi
/// cihazında doludur, öğretmen kimin bağlandığını oradan göremez. Bulut
/// erişilemezse yerel liste kullanılır (aynı cihazda test, çevrimdışı).
final classLinkedParentsProvider =
    FutureProvider.family<List<ParentLinkModel>, ClassModel>(
        (ref, classModel) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  final teacher = ref.watch(teacherProfileProvider);
  final uid = TeacherIdentity.resolve(teacher);

  if (CloudIds.isValidUid(uid)) {
    final cloud = ref.watch(cloudTokenRepositoryProvider);
    final fromCloud = await cloud.fetchClassParentLinks(
      classCloudId: CloudIds.classId(
        teacherUid: uid,
        localClassId: classModel.id ?? 0,
      ),
      teacherUid: uid,
    );
    if (fromCloud.isNotEmpty) return fromCloud;
  }

  return repo.getLinkedParentsForClass(classModel.id ?? 0);
});

final studentLinkedParentsProvider = FutureProvider.family<List<ParentLinkModel>, int>((ref, studentId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  final r = await repo.getLinkedParentsForStudent(studentId);
  return r;
});

/// Belirli Bir Veliye Bağlı Çocukların Listesi Provider'ı (Veli Görünümü)
final parentConnectedChildrenProvider = FutureProvider.family<List<ParentLinkModel>, String>((ref, parentUserId) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  return repo.getParentLinksForParent(parentUserId);
});

/// Bu Cihazdaki Velinin Bağlı Tüm Çocukları Provider'ı.
///
/// Google girişi yapılmışsa Firebase UID kullanılır; böylece veli cihaz
/// değiştirdiğinde de aynı çocuklara ulaşır.
final myConnectedChildrenProvider = FutureProvider<List<ParentLinkModel>>((ref) async {
  final repo = ref.watch(parentTokenRepositoryProvider);
  final uid = ref.watch(parentAuthServiceProvider).currentIdentity?.uid;
  return repo.getMyConnectedChildren(parentUid: uid);
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

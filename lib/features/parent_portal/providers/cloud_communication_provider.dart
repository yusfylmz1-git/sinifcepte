import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/cloud/delta_sync_tracker.dart';
import '../data/models/parent_link_model.dart';
import '../data/repositories/cloud_communication_repository.dart';

/// Bulut iletişim deposu (duyuru, mesaj, öğretmen kadrosu).
final cloudCommunicationRepositoryProvider =
    Provider<CloudCommunicationRepository>((ref) {
  return CloudCommunicationRepository();
});

/// Veli ekranı için duyuru akışı.
///
/// Delta senkron uygular (maliyet kararı #2): yalnızca son okumadan sonra
/// güncellenen duyurular çekilir. Sınıfta günde ortalama 0,2 duyuru
/// yayımlandığından açılışların çoğu **sıfır doküman** okur.
///
/// Bağın bulut kimliği yoksa (Faz 2 öncesi kayıt) boş liste döner ve
/// arayüz velinin yeniden bağlanması gerektiğini bildirir.
final cloudAnnouncementsProvider =
    FutureProvider.family<List<CloudAnnouncement>, ParentLinkModel>(
        (ref, link) async {
  if (!link.hasCloudBinding) return const [];

  final repo = ref.watch(cloudCommunicationRepositoryProvider);
  final stream = DeltaSyncTracker.announcementsStream(link.classCloudId);
  final since = await DeltaSyncTracker.instance.lastSyncOf(stream);

  final list = await repo.fetchAnnouncements(
    classCloudId: link.classCloudId,
    parentUid: link.parentUserId,
    since: since,
  );

  // Damga yalnızca istek başarıyla tamamlandığında ilerletilir; aksi halde
  // bir sonraki açılışta atlanan duyurular kalıcı olarak kaybolurdu.
  await DeltaSyncTracker.instance.markSynced(stream);

  // Okundu durumunu işaretle. Her duyuru için tek küçük doküman okuması
  // yapılır; duyuru sayısı listede zaten sınırlı (varsayılan 20).
  return Future.wait(
    list.map((a) async {
      final read = await repo.hasRead(
        classCloudId: link.classCloudId,
        announcementId: a.id,
        parentUid: link.parentUserId,
      );
      return a.copyWith(readByMe: read);
    }),
  );
});

/// Veli duyuruyu okuduğunu işaretler ve listeyi tazeler.
///
/// Delta damgası duyuruların yeniden çekilmesini engellediği için okundu
/// durumu ayrı bir provider üzerinden yenilenir.
final markAnnouncementReadProvider = Provider<
    Future<bool> Function({
  required ParentLinkModel link,
  required String announcementId,
})>((ref) {
  return ({required link, required announcementId}) async {
    final repo = ref.read(cloudCommunicationRepositoryProvider);
    final ok = await repo.markAnnouncementRead(
      classCloudId: link.classCloudId,
      announcementId: announcementId,
      parentUid: link.parentUserId,
    );
    if (ok) {
      // Duyuru içeriği değişmedi; yalnızca okundu durumu tazelensin diye
      // delta damgası geri alınır.
      await DeltaSyncTracker.instance
          .reset(DeltaSyncTracker.announcementsStream(link.classCloudId));
      ref.invalidate(cloudAnnouncementsProvider(link));
    }
    return ok;
  };
});

/// Belirli bir çocuğa ait mesaj akışı.
final cloudMessagesProvider =
    FutureProvider.family<List<CloudMessage>, ParentLinkModel>((ref, link) async {
  if (!link.hasCloudBinding) return const [];

  final repo = ref.watch(cloudCommunicationRepositoryProvider);
  final stream = DeltaSyncTracker.messagesStream(link.studentCloudId);
  final since = await DeltaSyncTracker.instance.lastSyncOf(stream);

  final list = await repo.fetchMessages(
    classCloudId: link.classCloudId,
    studentCloudId: link.studentCloudId,
    since: since,
  );

  await DeltaSyncTracker.instance.markSynced(stream);

  return list;
});

/// Çocuğun dersine giren öğretmenler kadrosu.
///
/// Veli bu listeden hangi branş öğretmeniyle yazışabileceğini görür.
/// Kadro nadiren değiştiği için delta uygulanmaz; liste zaten küçüktür.
final cloudClassStaffProvider =
    FutureProvider.family<List<CloudStaffMember>, ParentLinkModel>(
        (ref, link) async {
  if (!link.hasCloudBinding) return const [];

  final repo = ref.watch(cloudCommunicationRepositoryProvider);
  return repo.fetchStaff(link.classCloudId);
});

/// Öğretmen görünümü: bir duyuruyu kaç velinin okuduğu.
///
/// `count()` toplama sorgusu kullanır — 1000 dokümana kadar tek okuma
/// olarak ücretlendirilir (maliyet kararı #1).
final announcementReadCountProvider =
    FutureProvider.family<int, ({String classCloudId, String announcementId})>(
        (ref, args) async {
  final repo = ref.watch(cloudCommunicationRepositoryProvider);
  return repo.countReads(
    classCloudId: args.classCloudId,
    announcementId: args.announcementId,
  );
});

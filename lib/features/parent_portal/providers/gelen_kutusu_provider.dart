import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_ids.dart';
import '../../auth_profile/data/services/teacher_identity.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../data/gelen_kutusu.dart';
import '../data/repositories/cloud_communication_repository.dart';
import 'cloud_communication_provider.dart';
import 'parent_token_provider.dart';

/// Gelen kutusundaki bir sınıf: rehberlik sınıfım ya da kadrosunda
/// olduğum (başka öğretmenin) sınıfı.
class GelenKutusuSinifi {
  final String classCloudId;
  final String ad;
  final bool kendi;
  final String aciklama;

  const GelenKutusuSinifi({
    required this.classCloudId,
    required this.ad,
    required this.kendi,
    required this.aciklama,
  });
}

/// Bir sınıftaki bekleyen randevu (yanıtlamak için sınıf kimliği gerekir).
typedef SinifRandevusu = ({String classCloudId, CloudAppointment randevu});

/// Bir sınıftaki "görüldü" denmemiş veli bildirimi.
typedef SinifBildirimi = ({String classCloudId, CloudStatusReport bildirim});

class GelenKutusuDurumu {
  final bool bulutVar;
  final List<GelenKutusuSinifi> siniflar;
  final List<SohbetOzeti> sohbetler;
  final List<SinifRandevusu> randevular;
  final List<SinifBildirimi> bildirimler;

  /// En az bir sınıf okunamadı (internet yok vb.).
  final bool eksik;

  const GelenKutusuDurumu({
    required this.bulutVar,
    required this.siniflar,
    required this.sohbetler,
    required this.randevular,
    required this.bildirimler,
    required this.eksik,
  });

  static const bulutsuz = GelenKutusuDurumu(
    bulutVar: false,
    siniflar: [],
    sohbetler: [],
    randevular: [],
    bildirimler: [],
    eksik: false,
  );

  int get okunmamisMesaj => sohbetler.fold(0, (t, s) => t + s.okunmamis);
  int get rozet => okunmamisMesaj + randevular.length + bildirimler.length;

  String sinifAdi(String classCloudId) =>
      siniflar.where((s) => s.classCloudId == classCloudId).firstOrNull?.ad ?? '';
}

/// Randevu bu öğretmene mi istenmiş?
///
/// Yeni taleplerde `teacherUid` var; eski taleplerde yalnız öğretmen adı.
/// Adı da boş eski bir talep sınıf öğretmeninindir.
bool randevuBanaMi(CloudAppointment a, {required String uid, required String ad, required bool kendiSinifim}) {
  if (a.teacherUid.isNotEmpty) return a.teacherUid == uid;
  if (a.teacherName.isNotEmpty) return a.teacherName == ad;
  return kendiSinifim;
}

/// Öğretmenin veli gelen kutusu: rehberlik sınıfı + kadrosunda olduğu
/// sınıflar (18 Ekim 2026). Ekran açılınca ya da tazelenince delta okur.
final gelenKutusuProvider = FutureProvider<GelenKutusuDurumu>((ref) async {
  final teacher = ref.watch(teacherProfileProvider);
  final uid = TeacherIdentity.resolve(teacher);
  if (!CloudIds.isValidUid(uid)) return GelenKutusuDurumu.bulutsuz;

  final bulut = ref.watch(cloudCommunicationRepositoryProvider);
  final depo = GelenKutusuDeposu(uid);
  await depo.yukle();
  var eksik = false;

  final siniflar = <GelenKutusuSinifi>[];
  final rehberlik = ref.watch(homeroomClassProvider);
  String? rehberlikCls;
  if (rehberlik?.id != null) {
    rehberlikCls = CloudIds.classId(teacherUid: uid, localClassId: rehberlik!.id!);
    siniflar.add(GelenKutusuSinifi(
      classCloudId: rehberlikCls,
      ad: rehberlik.name,
      kendi: true,
      aciklama: 'Rehberlik sınıfım',
    ));
  }

  // Kadrosunda olduğum sınıflar: collection group sorgusu her açılışta
  // değil, en çok 6 saatte bir (kadro nadiren değişir).
  final simdi = DateTime.now();
  final kadroEski = depo.kadroZamani == null ||
      simdi.difference(depo.kadroZamani!) > const Duration(hours: 6);
  if (kadroEski) {
    try {
      depo.kadroSiniflari = await bulut.fetchMyStaffClasses(uid);
      depo.kadroZamani = simdi;
    } catch (e) {
      eksik = true;
      debugPrint('Kadro sınıfları okunamadı ($e)');
    }
  }
  for (final k in depo.kadroSiniflari) {
    if (k.classCloudId == rehberlikCls) continue;
    siniflar.add(GelenKutusuSinifi(
      classCloudId: k.classCloudId,
      ad: k.className.isEmpty ? 'Sınıf' : k.className,
      kendi: false,
      aciklama: [
        if (k.branch.isNotEmpty) k.branch,
        if (k.homeroomTeacherName.isNotEmpty) 'sınıf öğretmeni ${k.homeroomTeacherName}',
      ].join(' · '),
    ));
  }

  if (await gelenKutusunuEsitle(
    depo: depo,
    bulut: bulut,
    siniflar: [for (final s in siniflar) s.classCloudId],
  )) {
    eksik = true;
  }

  // Rehberlik sınıfında adlar veli bağından tamamlanır (eski mesajlarda
  // öğrenci adı yok).
  if (rehberlik != null) {
    try {
      final baglar = await ref.watch(classLinkedParentsProvider(rehberlik).future);
      for (final b in baglar) {
        if (!b.hasCloudBinding) continue;
        final anahtar = sohbetAnahtari(b.classCloudId, b.studentCloudId, b.parentUserId);
        final o = depo.sohbetler[anahtar];
        if (o == null) continue;
        depo.sohbetler[anahtar] = o.copyWith(
          studentName: o.studentName.isEmpty ? b.studentName : null,
          parentName: o.parentName.isEmpty ? '${b.relation}: ${b.parentName}' : null,
        );
      }
    } catch (e) {
      debugPrint('Veli bağları okunamadı ($e)');
    }
  }

  final randevular = <SinifRandevusu>[];
  final bildirimler = <SinifBildirimi>[];
  for (final s in siniflar) {
    try {
      // Rehberlik sınıfında süresi dolanlar da temizlenir (sağlayıcı);
      // kadro sınıfında temizlik sınıf öğretmeninin işi. Kadro sınıfında
      // kural yalnız bana istenenlerin sorgusunu açar.
      final liste = s.kendi
          ? await ref.watch(classAppointmentsCloudProvider(s.classCloudId).future)
          : await bulut.fetchAppointments(classCloudId: s.classCloudId, teacherUid: uid);
      for (final a in liste) {
        if (a.isPending && randevuBanaMi(a, uid: uid, ad: teacher.fullName, kendiSinifim: s.kendi)) {
          randevular.add((classCloudId: s.classCloudId, randevu: a));
        }
      }
      // Durum bildirimleri (geç gelme, erken çıkış) sınıf öğretmeninin işi.
      if (s.kendi) {
        final raporlar = await ref.watch(classStatusReportsCloudProvider(s.classCloudId).future);
        for (final r in raporlar) {
          if (!r.isAcknowledged) bildirimler.add((classCloudId: s.classCloudId, bildirim: r));
        }
      }
    } catch (e) {
      eksik = true;
      debugPrint('Gelen kutusu: ${s.classCloudId} randevu/bildirim okunamadı ($e)');
    }
  }

  final sohbetler = depo.sohbetler.values.toList()
    ..sort((a, b) => b.sonZaman.compareTo(a.sonZaman));

  return GelenKutusuDurumu(
    bulutVar: true,
    siniflar: siniflar,
    sohbetler: sohbetler,
    randevular: randevular,
    bildirimler: bildirimler,
    eksik: eksik,
  );
});

/// Gelen kutusunu yeniden okur. [kadroDahil]: kadro sınıfları da hemen
/// tazelenir (aşağı çekip yenileme).
Future<void> gelenKutusunuTazele(WidgetRef ref, {bool kadroDahil = false}) async {
  if (kadroDahil) {
    final uid = TeacherIdentity.resolve(ref.read(teacherProfileProvider));
    if (CloudIds.isValidUid(uid)) {
      final depo = GelenKutusuDeposu(uid);
      await depo.yukle();
      depo.kadroZamani = null;
      await depo.kaydet();
    }
  }
  ref.invalidate(gelenKutusuProvider);
}

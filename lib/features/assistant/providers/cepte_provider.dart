import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/class_model.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../clubs/data/repositories/club_repository.dart';
import '../../documents/data/special_days_repository.dart';
import '../../outcomes/data/repositories/curriculum_outcome_repository.dart';
import '../data/cepte_arama.dart';
import '../data/cepte_katalog.dart';

/// "5-A", "11/B" → 5, 11.
int? cepteSinifSeviyesi(String sinifAdi) {
  final m = RegExp(r'^\s*(\d{1,2})').firstMatch(sinifAdi);
  final n = int.tryParse(m?.group(1) ?? '');
  return n != null && n >= 1 && n <= 12 ? n : null;
}

/// Cepte'nin aradığı her şey: ekranlar + öğretmenin kendi verisi.
///
/// Her kaynak ayrı denenir: biri okunamazsa (ör. kulüp kataloğu) arama
/// geri kalanıyla çalışmaya devam eder.
final cepteKatalogProvider = FutureProvider.autoDispose<List<CepteHedef>>((ref) async {
  final katalog = <CepteHedef>[...cepteEkranHedefleri()];

  Future<void> ekle(String ad, Future<List<CepteHedef>> Function() kur) async {
    try {
      katalog.addAll(await kur());
    } catch (e, st) {
      debugPrint('Cepte katalog ($ad) okunamadı: $e\n$st');
    }
  }

  var siniflar = <ClassModel>[];
  try {
    siniflar = await ClassRepository().getAllClasses();
  } catch (e) {
    debugPrint('Cepte katalog (sınıflar) okunamadı: $e');
  }

  await ekle('sınıflar', () async => cepteSinifHedefleri([
        for (final s in siniflar)
          if (s.id != null) (id: s.id!, ad: s.name, ders: s.subject),
      ]));

  await ekle('öğrenciler', () async {
    final repo = StudentRepository();
    final liste = <({int id, int classId, String ad, int no, String sinifAdi})>[];
    for (final s in siniflar) {
      if (s.id == null) continue;
      for (final o in await repo.getStudentsByClassId(s.id!)) {
        if (o.id == null) continue;
        liste.add((
          id: o.id!,
          classId: s.id!,
          ad: '${o.firstName} ${o.lastName}'.trim(),
          no: o.schoolNumber,
          sinifAdi: s.name,
        ));
      }
    }
    return cepteOgrenciHedefleri(liste);
  });

  await ekle('belirli günler', () async {
    final gunler = await SpecialDaysRepository().all();
    return cepteBelirliGunHedefleri([
      for (final g in gunler) (ad: g.ad, tarihMetni: g.tarihMetni, etkinlikli: g.etkinlikli),
    ]);
  });

  await ekle('kulüpler', () async {
    final repo = ClubRepository();
    final kurulu = await repo.kulupler();
    final adlar = {for (final k in kurulu) k.ad};
    final katalogKulupleri = await repo.katalog();
    return cepteKulupHedefleri([
      for (final k in kurulu) (id: k.id, ad: k.ad),
      for (final k in katalogKulupleri)
        if (!adlar.contains(k.ad)) (id: null, ad: k.ad),
    ]);
  });

  await ekle('kazanımlar', () async {
    final repo = CurriculumOutcomeRepository();
    final seviyeler = {
      for (final s in siniflar) ?cepteSinifSeviyesi(s.name),
    }.toList()
      ..sort();
    final dersler = <({int sinif, String kod, String ad, String yayinci})>[];
    for (final seviye in seviyeler) {
      for (final d in await repo.getAvailableSubjects(seviye)) {
        dersler.add((
          sinif: seviye,
          kod: '${d['subject_code']}',
          ad: '${d['subject_name']}',
          yayinci: '${d['publisher'] ?? ''}'.trim(),
        ));
      }
    }
    return cepteKazanimHedefleri(dersler);
  });

  return katalog;
});

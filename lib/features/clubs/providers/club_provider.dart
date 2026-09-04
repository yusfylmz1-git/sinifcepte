import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatter.dart';
import '../data/models/club_model.dart';
import '../data/repositories/club_repository.dart';
import '../utils/club_activity_suggester.dart';

/// Sosyal kulüp modülünün durum yönetimi.
///
/// Kulüp listesi, üye ve faaliyet kayıtları ayrı sağlayıcılarda tutulur:
/// üye listesi 40 satıra çıkabiliyor ve kulüp adı değişince yeniden
/// okunmasına gerek yok.
final clubRepositoryProvider = Provider<ClubRepository>((ref) {
  return ClubRepository();
});

/// EK-4 çizelgesindeki 52 kulüp. Varlıktan bir kez okunur.
final clubCatalogProvider = FutureProvider<List<ClubCatalogItem>>((ref) async {
  return ref.read(clubRepositoryProvider).katalog();
});

/// Yürürlükteki öğretim yılı. Ağustos'tan itibaren yeni yıl sayılır.
///
/// Üyelik yılla sınırlı (MADDE 8/7); kulüpler bu etikete göre süzülür.
final currentAcademicYearProvider = Provider<String>((ref) {
  return AppDateFormatter.academicYearLabel();
});

/// Bu öğretim yılında kurulmuş kulüpler.
final clubListProvider =
    StateNotifierProvider<ClubListNotifier, AsyncValue<List<ClubModel>>>((ref) {
  return ClubListNotifier(
    ref.read(clubRepositoryProvider),
    ref.read(currentAcademicYearProvider),
  );
});

class ClubListNotifier extends StateNotifier<AsyncValue<List<ClubModel>>> {
  ClubListNotifier(this._repo, this._ogretimYili)
      : super(const AsyncValue.loading()) {
    yukle();
  }

  final ClubRepository _repo;
  final String _ogretimYili;

  Future<void> yukle() async {
    state = const AsyncValue.loading();
    try {
      final liste = await _repo.kulupler(ogretimYili: _ogretimYili);
      state = AsyncValue.data(liste);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  /// Katalogdan kulüp kurar. Aynı kulüp bu yıl zaten varsa kurmaz ve
  /// mevcut kaydın id'sini döner.
  Future<int> katalogdanKur(ClubCatalogItem item) async {
    final mevcut = state.value?.where((k) => k.catalogCode == item.kod);
    if (mevcut != null && mevcut.isNotEmpty) return mevcut.first.id ?? 0;

    final id = await _repo.kulupEkle(ClubModel(
      catalogCode: item.kod,
      ad: item.ad,
      tema: item.tema,
      ogretimYili: _ogretimYili,
      olusturmaTarihi: DateTime.now(),
    ));

    // Faaliyet raporu baştan hazır gelsin: öğretmen kulübü kurar kurmaz
    // üç PDF'i de indirebilmeli. Metinler taslak; istediği ayı açıp
    // kendi yaptığına göre düzeltir.
    await _repo.faaliyetleriTohumla(
      id,
      item.plan,
      ClubActivitySuggester.oner,
    );

    await yukle();
    return id;
  }

  /// Çizelge dışı kulüp kurar (MADDE 8/1).
  Future<int> ozelKulupKur(String ad, {String tema = 'toplum'}) async {
    final id = await _repo.kulupEkle(ClubModel(
      ad: ad.trim(),
      tema: tema,
      ogretimYili: _ogretimYili,
      olusturmaTarihi: DateTime.now(),
    ));

    // Çizelge dışı kulüpte hazır plan yok; on ay boş satır olarak
    // açılır ki rapor ekranı ve PDF yine de on ayı göstersin.
    await _repo.faaliyetleriTohumla(id, const [], (_) => '');

    await yukle();
    return id;
  }

  Future<void> guncelle(ClubModel kulup) async {
    await _repo.kulupGuncelle(kulup);
    await yukle();
  }

  Future<void> sil(int id) async {
    await _repo.kulupSil(id);
    await yukle();
  }
}

/// Hiçbir kulübe üye olmayan öğrenciler (MADDE 8/4 denetimi).
final clubUnassignedStudentsProvider =
    FutureProvider<List<Map<String, Object?>>>((ref) async {
  // Kulüp listesi değişince yeniden hesaplanmalı: üye eklenince bu
  // sayı düşer.
  ref.watch(clubListProvider);
  return ref
      .watch(clubRepositoryProvider)
      .kulupsuzOgrenciler(ref.watch(currentAcademicYearProvider));
});

/// Bir kulübün üyeleri.
final clubMembersProvider =
    FutureProvider.family<List<ClubMember>, int>((ref, clubId) async {
  return ref.watch(clubRepositoryProvider).uyeler(clubId);
});

/// Bir kulübün yürürlükteki planı (katalog + öğretmen düzenlemeleri).
final clubPlanProvider =
    FutureProvider.family<List<ClubPlanRow>, ClubModel>((ref, kulup) async {
  return ref.watch(clubRepositoryProvider).plan(kulup);
});

/// Bir kulübün ay ay faaliyet kayıtları.
final clubActivityProvider =
    FutureProvider.family<List<ClubActivityLog>, int>((ref, clubId) async {
  return ref.watch(clubRepositoryProvider).faaliyetler(clubId);
});

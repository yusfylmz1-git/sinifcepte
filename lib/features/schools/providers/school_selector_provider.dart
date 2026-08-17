import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../data/models/school_model.dart';
import '../data/repositories/school_repository.dart';

/// Okul Veri Deposu Provider
final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository();
});

/// 81 İl ve İlçe Listesi Provider
final provincesListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(schoolRepositoryProvider);
  return repo.getProvinces();
});

/// Seçili İl (Varsayılan olarak öğretmenin profilindeki il veya 'Bursa')
final selectedSchoolCityProvider = StateProvider<String>((ref) {
  final profile = ref.watch(teacherProfileProvider);
  if (profile.city != null && profile.city!.isNotEmpty) {
    return profile.city!;
  }
  return '';
});

/// Seçili İlçe (null ise Tüm İlçeler)
final selectedSchoolDistrictProvider = StateProvider<String?>((ref) {
  final profile = ref.watch(teacherProfileProvider);
  return profile.district;
});

/// Seçili Okul Türü Filtresi ('Tümü', 'İlkokul', 'Ortaokul', 'Anadolu Lisesi', 'Fen Lisesi', vb.)
final selectedSchoolTypeProvider = StateProvider<String>((ref) => 'Tümü');

/// Arama Metni
final schoolSearchQueryProvider = StateProvider<String>((ref) => '');

/// Seçili İle Ait İlçeler Listesi
final districtsForSelectedCityProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(schoolRepositoryProvider);
  final city = ref.watch(selectedSchoolCityProvider);
  if (city.isEmpty) return [];
  return repo.getDistricts(city);
});

/// Filtrelenmiş Okul Listesi Provider (İl, İlçe, Tür ve Arama Metnine Göre)
final filteredSchoolsListProvider = FutureProvider<List<SchoolModel>>((ref) async {
  final repo = ref.watch(schoolRepositoryProvider);
  final city = ref.watch(selectedSchoolCityProvider);
  final district = ref.watch(selectedSchoolDistrictProvider);
  final query = ref.watch(schoolSearchQueryProvider);
  final schoolType = ref.watch(selectedSchoolTypeProvider);

  if (city.isEmpty) return [];

  return repo.searchSchools(
    city: city,
    district: district,
    query: query,
    schoolType: schoolType,
  );
});

/// Kullanıcıların Manuel Eklediği Okullar Listesi Provider
final customSchoolsListProvider = FutureProvider<List<SchoolModel>>((ref) async {
  final repo = ref.watch(schoolRepositoryProvider);
  return repo.getCustomSchools();
});

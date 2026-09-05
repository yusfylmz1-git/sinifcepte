import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/exam_operations/data/models/exam_model.dart';
import 'package:sinifcepte/features/exam_operations/providers/exam_tracking_provider.dart';

/// Sınav listesinin sırası ve geçmiş penceresi.
///
/// ## Neden bu test var
/// Cihazda görüldü: liste hiç sıralanmıyordu, veritabanı sırasıyla
/// geliyordu. Öğretmen ekranı açtığında aylar önce bitmiş sınavları
/// görüyor, yaklaşanı bulmak için kaydırmak zorunda kalıyordu. Ayrıca
/// her sınav sonsuza dek listede kalıyor, ekran "Tamamlandı" rozetiyle
/// doluyordu.
///
/// Doğru davranış:
///   1. Yaklaşanlar başta, en yakın tarih önce
///   2. Yakın geçmiş sonda, en yeni biten önce
///   3. Bir aydan eski sınavlar hiç görünmez
void main() {
  ExamModel sinav(String id, DateTime tarih, {bool favori = false}) =>
      ExamModel(
        id: id,
        title: id,
        institution: 'ÖSYM',
        category: 'ÖSYM',
        examDate: tarih,
        isFavorite: favori,
      );

  final simdi = DateTime.now();

  group('Sinav listesi sirasi', () {
    test('KRITIK: yaklasanlar basta, en yakin once', () {
      final state = ExamTrackingState(exams: [
        sinav('uzak', simdi.add(const Duration(days: 60))),
        sinav('yakin', simdi.add(const Duration(days: 3))),
        sinav('orta', simdi.add(const Duration(days: 20))),
      ]);

      final sirali = state.officialExams.map((e) => e.id).toList();
      expect(sirali, ['yakin', 'orta', 'uzak']);
    });

    test('KRITIK: gecmis sinavlar yaklasanlardan SONRA', () {
      // Cihazda görülen hata buydu: geçmişler en başta duruyordu.
      final state = ExamTrackingState(exams: [
        sinav('gecmis', simdi.subtract(const Duration(days: 5))),
        sinav('gelecek', simdi.add(const Duration(days: 5))),
      ]);

      final sirali = state.officialExams.map((e) => e.id).toList();
      expect(sirali, ['gelecek', 'gecmis'],
          reason: 'geçmiş sınav yaklaşanın önüne geçmiş');
    });

    test('KRITIK: bir aydan eski sinav gizleniyor', () {
      final state = ExamTrackingState(exams: [
        sinav('cok_eski', simdi.subtract(const Duration(days: 200))),
        sinav('yeni_gecmis', simdi.subtract(const Duration(days: 10))),
        sinav('gelecek', simdi.add(const Duration(days: 10))),
      ]);

      final sirali = state.officialExams.map((e) => e.id).toList();
      expect(sirali, ['gelecek', 'yeni_gecmis'],
          reason: '200 gün önceki sınav hâlâ listede');
    });

    test('yakin gecmis tersten: en yeni biten once', () {
      final state = ExamTrackingState(exams: [
        sinav('yirmi_gun', simdi.subtract(const Duration(days: 20))),
        sinav('uc_gun', simdi.subtract(const Duration(days: 3))),
      ]);

      final sirali = state.officialExams.map((e) => e.id).toList();
      expect(sirali, ['uc_gun', 'yirmi_gun']);
    });

    test('favoriler de ayni sirayi izliyor', () {
      final state = ExamTrackingState(exams: [
        sinav('eski_fav', simdi.subtract(const Duration(days: 8)), favori: true),
        sinav('yeni_fav', simdi.add(const Duration(days: 8)), favori: true),
        sinav('favori_degil', simdi.add(const Duration(days: 1))),
      ]);

      final sirali = state.favoriteExams.map((e) => e.id).toList();
      expect(sirali, ['yeni_fav', 'eski_fav']);
    });

    test('bos liste cokmeye yol acmiyor', () {
      const state = ExamTrackingState(exams: []);
      expect(state.officialExams, isEmpty);
      expect(state.favoriteExams, isEmpty);
      expect(state.schoolExams, isEmpty);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/participation_badge_model.dart';

/// SınıfCepte - Ders İçi Katılım & Davranış Durum Yöneticisi (Yoklama Değildir)
final participationListProvider = StateNotifierProvider<
    ParticipationNotifier, List<ParticipationBadgeModel>>((ref) {
  return ParticipationNotifier();
});

class ParticipationNotifier
    extends StateNotifier<List<ParticipationBadgeModel>> {
  ParticipationNotifier() : super([]) {
    _loadSampleStudents();
  }

  void _loadSampleStudents() {
    try {
      state = const [
        ParticipationBadgeModel(
            studentId: 'st_1', studentName: 'Ahmet Yılmaz', studentNumber: 101),
        ParticipationBadgeModel(
            studentId: 'st_2', studentName: 'Ayşe Kaya', studentNumber: 102),
        ParticipationBadgeModel(
            studentId: 'st_3', studentName: 'Mehmet Demir', studentNumber: 103),
        ParticipationBadgeModel(
            studentId: 'st_4', studentName: 'Zeynep Çelik', studentNumber: 104),
        ParticipationBadgeModel(
            studentId: 'st_5', studentName: 'Can Öztürk', studentNumber: 105),
      ];
    } catch (e, stackTrace) {
      debugPrint('Participation yükleme hatası: $e\n$stackTrace');
    }
  }

  /// 1 Tık = Olumlu, 2 Tık = Geliştirilmeli, 3. Tık = Nötr
  void cycleStatus(String studentId) {
    try {
      state = state.map((item) {
        if (item.studentId == studentId) {
          switch (item.status) {
            case ParticipationStatus.neutral:
              return item.copyWith(status: ParticipationStatus.positive);
            case ParticipationStatus.positive:
              return item.copyWith(status: ParticipationStatus.needsImprovement);
            case ParticipationStatus.needsImprovement:
              return item.copyWith(status: ParticipationStatus.neutral);
          }
        }
        return item;
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Participation tık hatası: $e\n$stackTrace');
    }
  }

  /// Tek Tıkla "Tüm Sınıf Katıldı / Olumlu" Butonu
  void markAllPositive() {
    try {
      state = state.map((item) {
        return item.copyWith(status: ParticipationStatus.positive);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Tüm sınıf olumlu işaretleme hatası: $e\n$stackTrace');
    }
  }

  /// Uzun Basma: Özel Rozet / Etiket Ekleme (Örn: Ödev Eksik, Defter Var)
  void toggleCustomBadge(String studentId, String badgeName) {
    try {
      state = state.map((item) {
        if (item.studentId == studentId) {
          final updatedBadges = List<String>.from(item.customBadges);
          if (updatedBadges.contains(badgeName)) {
            updatedBadges.remove(badgeName);
          } else {
            updatedBadges.add(badgeName);
          }
          return item.copyWith(customBadges: updatedBadges);
        }
        return item;
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Özel rozet ekleme hatası: $e\n$stackTrace');
    }
  }
}

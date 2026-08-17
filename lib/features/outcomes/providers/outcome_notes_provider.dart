import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import 'outcomes_provider.dart';

/// Haftalık Kazanım Öğretmen Özel Notları Durum Yöneticisi
class OutcomeNotesNotifier extends StateNotifier<Map<int, String>> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  OutcomeNotesNotifier() : super({});

  /// Seçili dersin tüm haftalık notlarını yükler
  Future<void> loadNotesForSubject({
    required int grade,
    required String subjectCode,
    required String publisher,
  }) async {
    try {
      final notes = await _dbHelper.getAllOutcomeNotesForSubject(
        grade: grade,
        subjectCode: subjectCode,
        publisher: publisher,
      );
      state = notes;
    } catch (e, stackTrace) {
      debugPrint('OutcomeNotesNotifier.loadNotesForSubject error: $e\n$stackTrace');
      state = {};
    }
  }

  /// Belirli bir haftaya not kaydeder veya günceller
  Future<void> saveNote({
    required int grade,
    required String subjectCode,
    required String publisher,
    required int weekNumber,
    required String noteText,
  }) async {
    try {
      await _dbHelper.saveOutcomeNote(
        grade: grade,
        subjectCode: subjectCode,
        publisher: publisher,
        weekNumber: weekNumber,
        noteText: noteText,
      );

      final updated = Map<int, String>.from(state);
      if (noteText.trim().isEmpty) {
        updated.remove(weekNumber);
      } else {
        updated[weekNumber] = noteText.trim();
      }
      state = updated;
    } catch (e, stackTrace) {
      debugPrint('OutcomeNotesNotifier.saveNote error: $e\n$stackTrace');
    }
  }

  /// Belirli bir haftanın notunu siler
  Future<void> deleteNote({
    required int grade,
    required String subjectCode,
    required String publisher,
    required int weekNumber,
  }) async {
    try {
      await _dbHelper.deleteOutcomeNote(
        grade: grade,
        subjectCode: subjectCode,
        publisher: publisher,
        weekNumber: weekNumber,
      );

      final updated = Map<int, String>.from(state);
      updated.remove(weekNumber);
      state = updated;
    } catch (e, stackTrace) {
      debugPrint('OutcomeNotesNotifier.deleteNote error: $e\n$stackTrace');
    }
  }
}

/// Aktif seçili dersin haftalık notları haritası (Hafta No -> Not Metni)
final outcomeNotesProvider =
    StateNotifierProvider<OutcomeNotesNotifier, Map<int, String>>((ref) {
  final notifier = OutcomeNotesNotifier();

  // Seçili sınıf ve ders değiştikçe notları otomatik yükle
  final selectedGrade = ref.watch(selectedGradeProvider);
  final selectedSubject = ref.watch(selectedSubjectProvider);

  if (selectedGrade != null && selectedSubject != null) {
    final subjectCode = selectedSubject['subject_code'] as String? ?? '';
    final publisher = selectedSubject['publisher'] as String? ?? 'MEB Yayınları';
    notifier.loadNotesForSubject(
      grade: selectedGrade,
      subjectCode: subjectCode,
      publisher: publisher,
    );
  }

  return notifier;
});

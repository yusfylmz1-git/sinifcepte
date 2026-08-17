import '../../../../core/utils/input_sanitizer.dart';

/// SınıfCepte - Sınav Analizi Modeli (Soru Bazlı & Klasik)
class ExamAnalysisModel {
  final String id;
  final String className;
  final String subjectName;
  final String examTitle;
  final List<double> questionMaxScores; // Örn: [10, 10, 15, 15, 25, 25] -> Toplam 100
  final Map<String, List<double>> studentQuestionScores; // studentId -> Scores

  const ExamAnalysisModel({
    required this.id,
    required this.className,
    required this.subjectName,
    required this.examTitle,
    required this.questionMaxScores,
    required this.studentQuestionScores,
  });

  bool get isValidTotalHundred {
    return InputSanitizer.validateTotalHundred(questionMaxScores);
  }

  double calculateStudentTotal(String studentId) {
    final scores = studentQuestionScores[studentId];
    if (scores == null || scores.isEmpty) return 0.0;
    return scores.fold(0.0, (sum, score) => sum + score);
  }

  double calculateClassAverage() {
    if (studentQuestionScores.isEmpty) return 0.0;
    final totals = studentQuestionScores.keys
        .map((studentId) => calculateStudentTotal(studentId));
    final sum = totals.fold(0.0, (acc, val) => acc + val);
    return sum / studentQuestionScores.length;
  }
}

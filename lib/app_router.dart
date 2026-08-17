import 'package:flutter/material.dart';
import 'features/analytics/presentation/views/analytics_dashboard_view.dart';
import 'features/attendance/presentation/views/classroom_participation_view.dart';
import 'features/auth_profile/presentation/views/school_bind_gate.dart';
import 'features/exam_operations/presentation/views/exam_operations_menu_view.dart';

/// SınıfCepte - Uygulama Yönlendirmeleri ve Auth Guard Sabitleri
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String teacherProfileSetup = '/profile-setup';
  static const String outcomes = '/outcomes';
  static const String classes = '/classes';
  static const String schedule = '/schedule';
  static const String attendance = '/attendance'; // Ders İçi Katılım & Davranış (Yoklama Değildir)
  static const String examOperations = '/exam-operations';
  static const String documents = '/documents';
  static const String analytics = '/analytics';
  static const String parentPortal = '/parent-portal';

  /// Rota Oluşturucu (Route Generator)
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const SchoolBindGate(),
        );

      case attendance:
        return MaterialPageRoute(
          builder: (_) => const ClassroomParticipationView(),
        );

      case analytics:
        return MaterialPageRoute(
          builder: (_) => const AnalyticsDashboardView(),
        );

      case examOperations:
        return MaterialPageRoute(
          builder: (_) => const ExamOperationsMenuView(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const SchoolBindGate(),
        );
    }
  }
}

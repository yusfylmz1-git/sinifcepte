import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Yoklama Durumu Enum (AttendanceStatus)
enum AttendanceStatus {
  present('present', 'Geldi', AppColors.success, Icons.check_circle_rounded),
  absent('absent', 'Gelmedi', AppColors.danger, Icons.cancel_rounded),
  late('late', 'Geç', AppColors.warning, Icons.access_time_filled_rounded),
  excused('excused', 'İzinli', AppColors.info, Icons.info_rounded);

  final String code;
  final String label;
  final Color color;
  final IconData icon;

  const AttendanceStatus(this.code, this.label, this.color, this.icon);

  static AttendanceStatus fromCode(String code) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => AttendanceStatus.present,
    );
  }
}

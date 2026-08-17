import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/exam_operations/data/models/exam_model.dart';
import '../../features/exam_operations/presentation/views/exam_tracking_view.dart';

/// SınıfCepte - Yerel Bildirim ve Sınav Hatırlatma Servisi (Offline-First)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isInitialized = false;

  /// Bildirim Servisini Başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Timezone Başlatması
      tz.initializeTimeZones();

      // 2. Platform Özel Ayarları
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Masaüstü platformlarda (Windows/Linux) plugin yoksa güvenle atla
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await _notificationsPlugin.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse response) {
            handleNotificationPayload(response.payload);
          },
        );

        // Android 13+ Bildirim İzni İsteme
        if (Platform.isAndroid) {
          final androidPlugin = _notificationsPlugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          await androidPlugin?.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService: Bildirim motoru başarıyla başlatıldı.');
    } catch (e, stackTrace) {
      debugPrint('NotificationService.initialize error: $e\n$stackTrace');
    }
  }

  /// Bildirime Dokunulduğunda İlgili Sayfayı Aç
  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      if (payload.startsWith('exam_')) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ExamTrackingView()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('NotificationService.handleNotificationPayload error: $e\n$stackTrace');
    }
  }

  /// Favori Sınav İçin "Son 24 Saat Kala" Zamanlanmış Bildirimleri Kur
  /// Hem "Son Başvuru Tarihine 24 Saat Kala" hem de "Sınav Gününe 24 Saat Kala" hatırlatma yapar.
  Future<void> scheduleExamReminder24h(ExamModel exam) async {
    try {
      final now = DateTime.now();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sinifcepte_exams_channel',
        'Sınav & Başvuru Hatırlatıcıları',
        channelDescription: 'Favoriye eklenen MEB, ÖSYM ve Okul sınavları için son başvuru ve sınav günü 24 saat kala bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 1. SON BAŞVURU TARİHİNE 24 SAAT KALA BİLDİRİMİ
      if (exam.applicationDeadline != null) {
        final deadlineScheduleDate = exam.applicationDeadline!.subtract(const Duration(hours: 24));
        if (deadlineScheduleDate.isAfter(now)) {
          final deadlineNotificationId = '${exam.id}_deadline'.hashCode & 0x7fffffff;
          final tzDeadlineDate = tz.TZDateTime.from(deadlineScheduleDate, tz.local);

          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
            await _notificationsPlugin.zonedSchedule(
              deadlineNotificationId,
              '⚠️ Son Başvuruya 24 Saat!',
              '📝 "${exam.title}" resmî başvuruları yarın sona eriyor. Başvurunuzu tamamlamayı unutmayın!',
              tzDeadlineDate,
              platformDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: 'exam_${exam.id}',
            );
            debugPrint('NotificationService: "${exam.title}" için son başvuruya 24 saat kala bildirim kuruldu ($deadlineScheduleDate).');
          }
        }
      }

      // 2. SINAV GÜNÜNE 24 SAAT KALA BİLDİRİMİ
      final examScheduleDate = exam.examDate.subtract(const Duration(hours: 24));
      if (examScheduleDate.isAfter(now)) {
        final examNotificationId = '${exam.id}_exam'.hashCode & 0x7fffffff;
        final tzExamDate = tz.TZDateTime.from(examScheduleDate, tz.local);

        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
          await _notificationsPlugin.zonedSchedule(
            examNotificationId,
            '⏳ Sınava Son 24 Saat!',
            '⭐ "${exam.title}" sınavına 24 saat kaldı. Başarılar dileriz! 🎯',
            tzExamDate,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'exam_${exam.id}',
          );
          debugPrint('NotificationService: "${exam.title}" için sınav gününe 24 saat kala bildirim kuruldu ($examScheduleDate).');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('NotificationService.scheduleExamReminder24h error: $e\n$stackTrace');
    }
  }

  /// Favoriden Çıkarıldığında Kurulu Hatırlatmaları İptal Et
  Future<void> cancelExamReminder(ExamModel exam) async {
    try {
      final deadlineId = '${exam.id}_deadline'.hashCode & 0x7fffffff;
      final examId = '${exam.id}_exam'.hashCode & 0x7fffffff;
      final oldId = exam.id.hashCode & 0x7fffffff;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await _notificationsPlugin.cancel(deadlineId);
        await _notificationsPlugin.cancel(examId);
        await _notificationsPlugin.cancel(oldId);
        debugPrint('NotificationService: "${exam.title}" tüm hatırlatıcıları iptal edildi.');
      }
    } catch (e, stackTrace) {
      debugPrint('NotificationService.cancelExamReminder error: $e\n$stackTrace');
    }
  }


  /// Tüm Favori Sınavlar İçin Hatırlatıcıları Senkronize Et
  Future<void> syncAllFavoriteExamReminders(List<ExamModel> favoriteExams) async {
    for (final exam in favoriteExams) {
      if (!exam.isPast) {
        await scheduleExamReminder24h(exam);
      }
    }
  }
}

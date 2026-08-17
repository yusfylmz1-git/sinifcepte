sinifcepte/
│
├── android/
├── ios/
├── web/
│
└── lib/
    ├── main.dart                          # Uygulama Başlangıç Noktası (App Initializer)
    ├── app_router.dart                    # Sayfa Yönlendirmeleri ve Auth Guards
    │
    ├── core/                              # ORTAK VE ÇEKİRDEK YAPILAR
    │   ├── constants/                     # Sabitler
    │   │   ├── app_colors.dart            # Renk Paleti (Mavi, Pembe, Yeşil vb.)
    │   │   ├── app_text_styles.dart       # Tipografi ve Yazı Stilleri
    │   │   └── app_assets.dart            # Görseller, İkonlar ve Lottie Animasyonları
    │   │
    │   ├── utils/                         # Yardımcı Araçlar & Sanitizers
    │   │   ├── input_sanitizer.dart       # Sınıf Adı Clean Formatter ("5a" -> "5-A")
    │   │   ├── date_formatter.dart        # 37 Haftalık Takvim ve Tarih Ayarlayıcı
    │   │   ├── excel_parser.dart          # .xlsx Dosya Okuyucu
    │   │   └── pdf_parser.dart            # e-Okul PDF Ayrıştırıcı
    │   │
    │   ├── network/                       # Ağ & Veri İletişimi
    │   │   ├── api_client.dart            # HTTP / Firebase Bağlantı Yapısı
    │   │   └── error_handler.dart         # Global Hata Yakalama (Crash Logs)
    │   │
    │   ├── services/                      # Servisler
    │   │   ├── notification_service.dart  # Zil/Sınav Anlık Bildirim Servisi
    │   │   ├── pdf_generator_service.dart # Tutanak, Rubric ve ŞÖK PDF Üretici
    │   │   └── whatsapp_share_service.dart# Akıllı Metin Oluşturucu & WhatsApp Entegrasyonu
    │   │
    │   └── widgets/                       # Yeniden Kullanılabilir Ortak Widget'lar
    │       ├── custom_button.dart
    │       ├── custom_text_field.dart     # Keyboard-Responsive Inputlar
    │       ├── empty_state_widget.dart    # "Sınıf/Öğrenci Yok" Karşılama Kartları
    │       └── responsive_bottom_sheet.dart # Klavyeye Duyarlı Açılır Pencereler
    │
    └── features/                          # MODÜLER İŞ MANTIĞI (FEATURE-BASED)
        │
        ├── auth_profile/                  # 1. ÖĞRETMEN PROFİLİ & MESLEKİ BİLGİLER
        │   ├── data/                      # Profil Model ve Repository
        │   ├── providers/                 # Profil Durum Yönetimi
        │   └── presentation/
        │       ├── views/                 # TeacherProfileSetupView
        │       └── widgets/               # MandatoryFieldsForm
        │
        ├── outcomes/                      # 2. KAZANIMLAR MODÜLÜ
        │   ├── data/                      # Grade, Subject, Outcome Modelleri
        │   ├── providers/                 # ActiveWeekProvider, FavoriteProvider
        │   └── presentation/
        │       ├── views/                 # GradesView, SubjectsView, WeeklyOutcomesView
        │       └── widgets/               # OutcomeCarouselCard, HolidayCard
        │
        ├── classes_students/              # 3. SINIFLAR & ÖĞRENCİLER MODÜLÜ
        │   ├── data/                      # ClassModel, StudentModel
        │   ├── providers/                 # StudentProvider, ImportProvider
        │   └── presentation/
        │       ├── views/                 # ClassesView, StudentListView
        │       └── widgets/               # AddClassModal, AddStudentModal, ImportPreviewSheet
        │
        ├── schedule/                      # 4. DERS PROGRAMI & CANLI AKIŞ MODÜLÜ
        │   ├── data/                      # LessonModel, ScheduleSettingsModel
        │   ├── providers/                 # LiveScheduleProvider (Teneffüs/Ders Sayacı)
        │   └── presentation/
        │       ├── views/                 # ScheduleView, ScheduleSettingsSheet
        │       └── widgets/               # LiveStatusDashboardCard, AddEditLessonSheet
        │
        ├── attendance/                    # 5. DERS İÇİ KATILIM & DAVRANIŞ MODÜLÜ
        │   ├── data/                      # AttendanceModel, BehaviorBadgeModel
        │   ├── providers/                 # AttendanceProvider, SmartTextEngineProvider
        │   └── presentation/
        │       ├── views/                 # QuickAttendanceView
        │       └── widgets/               # StudentGridCard, SmartWhatsAppPreviewModal
        │
        ├── exam_operations/               # 6. SINAV İŞLEMLERİ MODÜLÜ (4 SAYFA)
        │   ├── data/                      # ExamModel, QuizSheetModel, RubricModel, ExamAnalysisModel
        │   ├── providers/                 # ExamTrackingProvider, AnalysisProvider
        │   └── presentation/
        │       ├── views/
        │       │   ├── exam_operations_menu_view.dart
        │       │   ├── exam_tracking_view.dart      # 1/4: MEB/ÖSYM Takip
        │       │   ├── quiz_list_view.dart          # 2/4: Quiz & Sözlü Tablosu
        │       │   ├── project_tracking_view.dart   # 3/4: Rubric Proje Takip
        │       │   └── exam_analysis_view.dart      # 4/4: Kırılmaz Sınav Analizi
        │       └── widgets/
        │           ├── add_custom_exam_sheet.dart
        │           ├── sticky_quiz_table.dart
        │           ├── rubric_criteria_editor.dart
        │           └── space_separated_quick_entry_modal.dart # "⚡ Hızlı Giriş" Modal'ı
        │
        ├── documents/                     # 7. EVRAKLARIM MODÜLÜ
        │   ├── data/                      # DocumentTemplateModel
        │   ├── providers/                 # DocumentGeneratorProvider
        │   └── presentation/
        │       ├── views/                 # DocumentsHubView, DocumentGeneratorView
        │       └── widgets/               # PdfPreviewWidget, DocumentCategoryCard
        │
        ├── analytics/                     # 8. ANALİZ & RAPOR MODÜLÜ
        │   ├── data/                      # ReportCardCommentModel, StudentReportModel
        │   ├── providers/                 # SmartCommentGeneratorProvider
        │   └── presentation/
        │       ├── views/                 # AnalyticsDashboardView, SmartReportCardCommentsView
        │       └── widgets/               # PerformanceChartWidget, StudentProgressPdfCard
        │
        ├── parent_portal/                 # 9. VELİ PORTALI (YENİ)
        │   ├── data/                      # ParentConnectionModel, StudentFeedModel
        │   ├── providers/                 # ParentAuthProvider, StudentFeedProvider
        │   └── presentation/
        │       ├── views/                 # ParentLoginView, ParentDashboardView
        │       └── widgets/               # ChildActivityTimelineCard, AnnouncementCard
        │
        └── admin_panel/                   # 10. SÜPER-ADMIN PANELSİ (WEB / DESKTOP)
            ├── data/                      # AdminAnalyticsModel, HelpdeskTicketModel
            ├── providers/                 # AdminDashboardProvider, SystemSettingsProvider
            └── presentation/
                ├── views/                 # AdminDashboardView, UsersView, SystemSettingsView
                └── widgets/               # TurkeyHeatMapWidget, CrashLogViewer, PushNotificationSender
import 'package:intl/intl.dart';

/// SınıfCepte - MEB Akademik Takvim ve 39+1 Haftalık Tarih Yöneticisi
class AppDateFormatter {
  AppDateFormatter._();

  static const List<String> _turkishMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  static const List<String> _turkishDays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
  ];

  /// Türkçe tarih biçimlendirmesi — `intl` yerel yükleyicisine bağlı değil.
  ///
  /// ## Neden elle yazılıyor
  /// `DateFormat('d MMMM yyyy', 'tr_TR')` çağrısı, Türkçe yerel verisinin
  /// çalışma zamanında yüklenmiş olmasını şart koşar. Yüklenmemişse çağrı
  /// ana iş parçacığında bloke oluyor: istisna atmadığı için `try/catch`
  /// yakalayamıyor, ekran hiç boyanmıyor ve dokunma olayları işlenmiyor.
  ///
  /// Kullanıcı bunu "öğrenciye basınca donuyor" olarak bildirdi. Sebep
  /// ikili bölme yöntemiyle bulundu: kart yalnızca kod ÜRETİLDİKTEN sonra
  /// bu satırı çalıştırıyor; bu yüzden ilk açılış sorunsuzdu.
  ///
  /// Ay ve gün adları on iki ve yedi tanedir, hiç değişmez. Bir paketin
  /// çalışma zamanı yükleyicisine bağlamak gereksiz risk taşıyordu.

  /// `18 Ağustos 2026`
  static String gunAyYil(DateTime d) =>
      '${d.day} ${_turkishMonths[d.month - 1]} ${d.year}';

  /// `18 Ağustos`
  static String gunAy(DateTime d) =>
      '${d.day} ${_turkishMonths[d.month - 1]}';

  /// `18 Ağustos 2026, Salı`
  static String gunAyYilGun(DateTime d) =>
      '${gunAyYil(d)}, ${_turkishDays[d.weekday - 1]}';

  /// `18 Ağustos 2026, 14:30`
  static String gunAyYilSaat(DateTime d) {
    final saat = d.hour.toString().padLeft(2, '0');
    final dakika = d.minute.toString().padLeft(2, '0');
    return '${gunAyYil(d)}, $saat:$dakika';
  }

  /// Verilen veya aktif tarihe göre MEB Eğitim-Öğretim Yılı Başlangıcı (Eylül Pazartesi)
  static DateTime getAcademicYearStartDate([DateTime? targetDate]) {
    final now = targetDate ?? DateTime.now();
    // Eğer ay Ağustos veya sonrası ise (>= 8) o yılın Eylül'ü, değilse önceki yılın Eylül'ü
    final year = (now.month >= 8) ? now.year : now.year - 1;

    // MEB Standart Başlangıcı: Eylül'ün 2. Pazartesisi (8 - 14 Eylül aralığı)
    final sep1 = DateTime(year, 9, 1);
    final daysToMonday = (DateTime.monday - sep1.weekday + 7) % 7;
    final firstMonday = sep1.add(Duration(days: daysToMonday));
    return firstMonday.day <= 7 ? firstMonday.add(const Duration(days: 7)) : firstMonday;
  }

  /// Sabit varsayılan referans başlangıç
  static DateTime get academicYearStartDate => getAcademicYearStartDate();

  /// Öğretim yılı etiketi. Ağustos'tan itibaren yeni yıl.
  static String academicYearLabel([DateTime? now]) {
    final d = now ?? DateTime.now();
    final start = d.month >= 8 ? d.year : d.year - 1;
    return '$start-${start + 1}';
  }

  /// Bugün hangi akademik haftada? (1 - 39: Ders/Ara Tatil Haftaları, 40: Yaz Tatili)
  static int getCurrentAcademicWeek({DateTime? targetDate}) {
    final now = targetDate ?? DateTime.now();
    final startDate = getAcademicYearStartDate(now);
    final endDate = startDate.add(const Duration(days: 39 * 7 - 3)); // 39. Hafta Cuma günü

    // 1. Yeni eğitim öğretim yılına hazırlık dönemi (Ağustos ve Eylül ayı açılış öncesi):
    // Öğretmenlerin planlama yapabilmesi için doğrudan 1. Haftaya (14 - 18 Eylül) odaklan
    if (now.month >= 8 && now.isBefore(startDate)) {
      return 1;
    }

    // 2. Eğitim-öğretim dönemi içindeyse aktif haftayı hesapla (1 - 39)
    if (!now.isBefore(startDate) && !now.isAfter(endDate)) {
      final differenceInDays = now.difference(startDate).inDays;
      final weekNumber = (differenceInDays / 7).floor() + 1;
      return weekNumber.clamp(1, 39);
    }

    // 3. Yaz tatili dönemi (Haziran sonu ve Temmuz)
    if (now.isAfter(endDate) || now.month == 7 || now.month == 6) {
      return 40; // Yaz Tatili Kartı
    }

    return 1;
  }

  /// Verilen akademik hafta nosuna göre (1-39 ve 40: Yaz Tatili) başlangıç ve bitiş tarih aralığı metni
  static String getWeekDateRangeText(int weekNumber, {DateTime? targetDate}) {
    final startDate = getAcademicYearStartDate(targetDate);

    // 40. Hafta: Yaz Tatili Aralığı
    if (weekNumber >= 40) {
      final endDate = startDate.add(const Duration(days: 39 * 7 - 3));
      final nextStart = startDate.add(const Duration(days: 365));
      try {
        final startStr = gunAy(endDate.add(const Duration(days: 1)));
        final endStr = gunAyYil(nextStart.subtract(const Duration(days: 1)));
        return '$startStr - $endStr';
      } catch (_) {
        return '20 Haziran - 7 Eylül ${endDate.year}';
      }
    }

    final weekStart = startDate.add(Duration(days: (weekNumber - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 4)); // Pazartesi - Cuma

    try {
      final startStr = gunAy(weekStart);
      final endStr = gunAyYil(weekEnd);
      return '$startStr - $endStr';
    } catch (_) {
      final startMonth = _turkishMonths[weekStart.month - 1];
      final endMonth = _turkishMonths[weekEnd.month - 1];
      return '${weekStart.day} $startMonth - ${weekEnd.day} $endMonth ${weekEnd.year}';
    }
  }

  /// Tarih gösterim formatı (Örn: 12 Ağustos 2026, Çarşamba)
  static String formatFullDate(DateTime date) {
    try {
      return gunAyYilGun(date);
    } catch (_) {
      final month = _turkishMonths[date.month - 1];
      final dayName = _turkishDays[date.weekday - 1];
      return '${date.day} $month ${date.year}, $dayName';
    }
  }

  /// Kısa Türkçe tarih gösterim formatı (Örn: 12 Ağustos 2026)
  static String formatTurkishDate(DateTime date) {
    try {
      return gunAyYil(date);
    } catch (_) {
      final month = _turkishMonths[date.month - 1];
      return '${date.day} $month ${date.year}';
    }
  }

  /// Saat gösterim formatı (Örn: 08:30)
  static String formatTime(DateTime time) {
    try {
      return DateFormat('HH:mm').format(time);
    } catch (_) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }
}

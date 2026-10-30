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

  /// MEB'in tebliğle duyurduğu öğretim yılları: açılış pazartesisi ve
  /// karne cuması. Anahtar açılış yılı.
  ///
  /// ## Neden tablo (30 Ekim 2026)
  /// Yılın sonu kuraldan çıkmaz. Burada sabit "39 hafta" vardı; 2026-2027
  /// ise 41 hafta (karne 25 Haziran 2027), 2025-2026 42 hafta sürdü. 39
  /// varsayımıyla 14-25 Haziran "yaz tatili" görünüyor, kazanım paketi de
  /// resmî planların son iki haftasını atıyordu.
  ///
  /// Kazanım boru hattının takvimiyle (`scripts/maarif/overrides/<yıl>.json`)
  /// aynı olmalı; `test/akademik_takvim_test.dart` karşılaştırır. Tabloda
  /// olmayan yıl kuralla ve [varsayilanHaftaSayisi] ile hesaplanır.
  static final Map<int, ({DateTime acilis, DateTime kapanis})> _resmiYillar = {
    // Geçen yıldan devreden BEP planları bu bitişi basar.
    2025: (acilis: DateTime(2025, 9, 8), kapanis: DateTime(2026, 6, 26)),
    2026: (acilis: DateTime(2026, 9, 14), kapanis: DateTime(2027, 6, 25)),
  };

  /// Test ve boru hattı karşılaştırması için tablonun salt okunur hâli.
  static Map<int, ({DateTime acilis, DateTime kapanis})> get resmiYillar =>
      Map.unmodifiable(_resmiYillar);

  /// Tabloda olmayan yılın takvim haftası sayısı (son yıllar 41-42).
  static const int varsayilanHaftaSayisi = 41;

  /// Gün farkı yaz saatinden etkilenmesin diye UTC gün.
  static DateTime _gun(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Verilen veya aktif tarihe göre MEB Eğitim-Öğretim Yılı Başlangıcı (Eylül Pazartesi)
  static DateTime getAcademicYearStartDate([DateTime? targetDate]) {
    final now = targetDate ?? DateTime.now();
    // Eğer ay Ağustos veya sonrası ise (>= 8) o yılın Eylül'ü, değilse önceki yılın Eylül'ü
    final year = (now.month >= 8) ? now.year : now.year - 1;

    final resmi = _resmiYillar[year];
    if (resmi != null) return resmi.acilis;

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

  /// Öğretim yılının son günü (karne cuması).
  static DateTime dersYiliSonu([DateTime? targetDate]) {
    final acilis = getAcademicYearStartDate(targetDate);
    final resmi = _resmiYillar[acilis.year];
    if (resmi != null) return resmi.kapanis;
    return DateTime(acilis.year, acilis.month, acilis.day + varsayilanHaftaSayisi * 7 - 3);
  }

  /// Öğretim yılının takvim haftası sayısı (ara tatil ve yarıyıl dahil).
  static int toplamHafta([DateTime? targetDate]) {
    final acilis = getAcademicYearStartDate(targetDate);
    return _gun(dersYiliSonu(targetDate)).difference(_gun(acilis)).inDays ~/ 7 + 1;
  }

  /// Yaz tatili kartının hafta numarası: yılın son haftasının bir fazlası.
  static int yazTatiliHaftasi([DateTime? targetDate]) => toplamHafta(targetDate) + 1;

  /// Bugün hangi akademik haftada? (1 - [toplamHafta]: ders ve ara tatil
  /// haftaları, [yazTatiliHaftasi]: yaz tatili)
  static int getCurrentAcademicWeek({DateTime? targetDate}) {
    final now = targetDate ?? DateTime.now();
    final startDate = getAcademicYearStartDate(now);
    final toplam = toplamHafta(now);
    final bugun = _gun(now);
    final sonGun = _gun(dersYiliSonu(now));

    // 1. Yeni eğitim öğretim yılına hazırlık dönemi (Ağustos ve Eylül ayı açılış öncesi):
    // Öğretmenlerin planlama yapabilmesi için doğrudan 1. Haftaya (14 - 18 Eylül) odaklan
    if (now.month >= 8 && now.isBefore(startDate)) {
      return 1;
    }

    // 2. Eğitim-öğretim dönemi içindeyse aktif haftayı hesapla. Gün
    // olarak karşılaştırılır: karne cuması öğleden sonra da ders yılıdır
    // (eski hesap saat 00.00'ı sınır alıyor, cumayı tatile atıyordu).
    if (!now.isBefore(startDate) && !bugun.isAfter(sonGun)) {
      final differenceInDays = bugun.difference(_gun(startDate)).inDays;
      final weekNumber = differenceInDays ~/ 7 + 1;
      return weekNumber.clamp(1, toplam);
    }

    // 3. Yaz tatili dönemi (karneden sonra ve Temmuz)
    if (bugun.isAfter(sonGun) || now.month == 7 || now.month == 6) {
      return toplam + 1; // Yaz Tatili Kartı
    }

    return 1;
  }

  /// Verilen akademik hafta nosuna göre (1-[toplamHafta] ve yaz tatili)
  /// başlangıç ve bitiş tarih aralığı metni
  static String getWeekDateRangeText(int weekNumber, {DateTime? targetDate}) {
    final startDate = getAcademicYearStartDate(targetDate);

    // Son haftadan sonrası: Yaz Tatili Aralığı (karneden sonraki gün ->
    // yeni yılın açılışından önceki gün)
    if (weekNumber > toplamHafta(targetDate)) {
      final endDate = dersYiliSonu(targetDate);
      final nextStart = getAcademicYearStartDate(DateTime(startDate.year + 1, 8, 15));
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

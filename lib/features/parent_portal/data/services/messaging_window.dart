/// Veli–öğretmen mesajlaşmasının ne zaman açık olduğunu belirler.
///
/// Kısıt bilinçli olarak YALNIZCA istemcide uygulanır. Güvenlik kuralında
/// saat kontrolü yapmak, kuralın kadro dokümanını `get()` ile okumasını
/// gerektirirdi; Firestore'da kural içindeki her `get()` faturalanan bir
/// okumadır — yani gönderilen her mesaj +1 okuma demektir.
///
/// Buradaki risk "veli yanlış saatte mesaj attı"dır; bir güvenlik açığı
/// değil, nezaket kuralıdır. Gerçek bir tehdide karşı değil, bir görgü
/// kuralına karşı her mesajda ödeme yapmak yanlış takas olurdu.
///
/// Kadro satırı zaten ekran açılırken okunuyor; `meetingDay`/`meetingTime`
/// o satırdan geldiği için bu kontrolün ek maliyeti sıfırdır.
class MessagingWindow {
  const MessagingWindow._();

  /// Gece mesajlarına karşı sabit üst sınır (saat, 24'lük).
  ///
  /// Öğretmenin akşamını korur. Öğretmen bazında kapatılabilir olmalıdır;
  /// bazı öğretmenler geç saatte cevaplamayı tercih eder.
  ///
  /// **19:00 iken 22:00'ye çekildi.** İkili öğretim yapan okullarda ders
  /// akşam 19:00'da bitiyor; veli okul çıkışında öğretmene yazamıyordu.
  /// 22:00 hem o veliye zaman bırakıyor hem de gece mesajını engelliyor.
  static const int quietHourStart = 22;

  /// Sessiz saatin bittiği saat (ertesi sabah).
  static const int quietHourEnd = 7;

  static const List<String> _weekdayNames = <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  /// [when] tarihinin Türkçe gün adı.
  static String weekdayName(DateTime when) =>
      _weekdayNames[when.weekday - 1];

  /// "13:30 - 14:15" biçimindeki aralığı dakikaya çevirir.
  ///
  /// Biçim tanınmazsa null döner; bu durumda kısıt uygulanmaz (kadro
  /// verisi eksik diye öğretmene ulaşımı kapatmak yanlış olurdu).
  static (int, int)? parseRange(String raw) {
    final matches =
        RegExp(r'(\d{1,2})[:.](\d{2})').allMatches(raw).toList();
    if (matches.length < 2) return null;

    int toMinutes(RegExpMatch m) {
      final h = int.tryParse(m.group(1)!) ?? -1;
      final min = int.tryParse(m.group(2)!) ?? -1;
      if (h < 0 || h > 23 || min < 0 || min > 59) return -1;
      return h * 60 + min;
    }

    final start = toMinutes(matches[0]);
    final end = toMinutes(matches[1]);
    if (start < 0 || end < 0 || end <= start) return null;
    return (start, end);
  }

  /// Sessiz saatte mi? (19:00–07:00)
  static bool isQuietHour(DateTime when) {
    final hour = when.hour;
    return hour >= quietHourStart || hour < quietHourEnd;
  }

  /// Bu öğretmene şu an mesaj gönderilebilir mi?
  ///
  /// [meetingDay] ve [meetingTime] boşsa kısıt yoktur: sınıf öğretmeni
  /// görüşme saati belirlememiştir, mesajlaşma serbesttir.
  ///
  /// [enforceQuietHours] öğretmen tercihine bağlıdır.
  static bool isOpen({
    required String meetingDay,
    required String meetingTime,
    required DateTime now,
    bool enforceQuietHours = true,
  }) {
    if (enforceQuietHours && isQuietHour(now)) return false;

    // Görüşme saati tanımlanmamışsa yalnızca sessiz saat geçerlidir.
    if (meetingDay.trim().isEmpty && meetingTime.trim().isEmpty) return true;

    if (meetingDay.trim().isNotEmpty &&
        meetingDay.trim() != weekdayName(now)) {
      return false;
    }

    final range = parseRange(meetingTime);
    if (range == null) return true; // biçim tanınmadı: kısıtlama yok

    final minutes = now.hour * 60 + now.minute;
    return minutes >= range.$1 && minutes < range.$2;
  }

  /// Kapalıyken veliye gösterilecek açıklama.
  static String closedReason({
    required String meetingDay,
    required String meetingTime,
    required DateTime now,
    bool enforceQuietHours = true,
  }) {
    if (enforceQuietHours && isQuietHour(now)) {
      return 'Öğretmenlerin dinlenme saati ($quietHourStart:00–'
          '0$quietHourEnd:00). Mesajınızı sabah gönderebilirsiniz.';
    }

    final day = meetingDay.trim();
    final time = meetingTime.trim();
    if (day.isNotEmpty && time.isNotEmpty) {
      return 'Bu öğretmenle $day günü $time saatleri arasında '
          'yazışabilirsiniz.';
    }
    if (day.isNotEmpty) {
      return 'Bu öğretmenle $day günü yazışabilirsiniz.';
    }
    return 'Bu öğretmenle $time saatleri arasında yazışabilirsiniz.';
  }
}

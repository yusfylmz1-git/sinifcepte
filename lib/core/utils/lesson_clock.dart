/// Ders saatinin "hangi dakika diliminde" olduğumuzu veren yardımcı.
///
/// Ders programından o anki aktif dersi bulan sağlayıcı bir `FutureProvider`
/// idi ve **hiçbir zaman tazelenmiyordu**. Ana sayfa `IndexedStack` içinde
/// oturum boyunca ekranda kaldığı için sonuç sabah açılışta hesaplanıp
/// akşama kadar öyle kalıyordu:
///
///   * 08:30'da açan öğretmen "1. ders 5-A" kartını görüyor
///   * 11:00'de başka sınıftayken kart **hâlâ 5-A / 1. ders** diyor
///   * Karttaki "tüm sınıfa tam puan" düğmesi o eski sınıfa yazıyor
///
/// Çözüm: sağlayıcıyı saat dilimine bağlamak. [currentBucket] aynı dilim
/// içinde aynı değeri döndürür, dilim değişince değer değişir ve sağlayıcı
/// kendiliğinden yeniden hesaplanır.
library;

/// Aktif ders tespitinin yenilenme sıklığı.
///
/// Ders başlangıcı 5 dakikalık teneffüs payıyla tespit ediliyor; bundan
/// daha sık yenilemek gereksiz veritabanı okuması, daha seyrek yenilemek
/// ise yanlış dersin gösterildiği bir pencere bırakır.
const Duration kLessonClockInterval = Duration(minutes: 5);

/// [at] anının hangi dilime düştüğünü verir.
///
/// Gün başından itibaren geçen dakikanın dilim boyuna bölümü. Aynı dilim
/// içindeki her an aynı sayıyı verir; bu sayı sağlayıcının anahtarı olur.
int currentBucket({DateTime? at, Duration interval = kLessonClockInterval}) {
  final now = at ?? DateTime.now();
  final dayMinutes = now.hour * 60 + now.minute;
  final bucketInDay = dayMinutes ~/ interval.inMinutes;

  // Gün de anahtara katılmalı: yoksa ertesi günün aynı saati aynı dilim
  // sayılır ve gece yarısını geçen oturumda dünkü ders gösterilmeye devam
  // eder.
  final epochDay =
      DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;

  return epochDay * (1440 ~/ interval.inMinutes) + bucketInDay;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/utils/date_formatter.dart';

/// Türkçe tarih biçimlendirmesi — donmanın ASIL SEBEBİ.
///
/// ## Bağlam
/// Kullanıcı "öğrenciye basınca donuyor" diye bildirdi. Sebep sekiz turluk
/// tahminden sonra ikili bölme yöntemiyle bulundu:
///
///   Adım 1 (yalın metin)                → açıldı
///   Adım 2 (+ provider okumaları)        → açıldı
///   Adım 3 (+ isScrollControlled)        → açıldı
///   Adım 4 (+ DateFormat 'tr_TR')        → DONDU
///
/// `DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR')` çağrısı Türkçe yerel
/// verisinin yüklenmiş olmasını şart koşuyor. Yüklenmemişse çağrı ana iş
/// parçacığında bloke oluyor — istisna atmadığı için `try/catch` bile
/// yakalayamıyordu.
///
/// Kart bu satırı yalnızca kod ÜRETİLDİKTEN sonra çalıştırıyordu; bu
/// yüzden ilk açılış sorunsuzdu, kod üretince bozuluyordu. Kullanıcının
/// "ilk girdiğimde açılmıştı, ref kodu sonradan bu hale geldi" ifadesi
/// tam olarak bunu tarif ediyordu.
///
/// Bu testler yerel yükleyiciye bağımlılığın geri gelmemesini garanti eder.
/// KRİTİK: `initializeDateFormatting` ÇAĞRILMADAN çalışırlar — gerçek
/// cihazdaki bozuk durumu birebir taklit ederler.
void main() {
  group('Yerel yükleyiciye bağlı olmayan Türkçe tarih', () {
    test('KRİTİK: yerel veri yüklenmemişken de çalışır', () {
      // initializeDateFormatting BİLEREK çağrılmıyor.
      final d = DateTime(2026, 8, 18, 14, 30);

      expect(AppDateFormatter.gunAyYil(d), '18 Ağustos 2026');
      expect(AppDateFormatter.gunAy(d), '18 Ağustos');
      expect(AppDateFormatter.gunAyYilSaat(d), '18 Ağustos 2026, 14:30');
      expect(AppDateFormatter.gunAyYilGun(d), '18 Ağustos 2026, Salı');
    });

    test('On iki ayın adı da doğru', () {
      const beklenen = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
      ];

      for (var ay = 1; ay <= 12; ay++) {
        expect(
          AppDateFormatter.gunAy(DateTime(2026, ay, 1)),
          '1 ${beklenen[ay - 1]}',
        );
      }
    });

    test('Yedi günün adı da doğru', () {
      // 2026-08-17 Pazartesi.
      const beklenen = [
        'Pazartesi', 'Salı', 'Çarşamba',
        'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
      ];

      for (var i = 0; i < 7; i++) {
        final d = DateTime(2026, 8, 17).add(Duration(days: i));
        expect(AppDateFormatter.gunAyYilGun(d), endsWith(beklenen[i]));
      }
    });

    test('Saat ve dakika iki hane olarak doldurulur', () {
      expect(
        AppDateFormatter.gunAyYilSaat(DateTime(2026, 1, 5, 9, 7)),
        '5 Ocak 2026, 09:07',
      );
      expect(
        AppDateFormatter.gunAyYilSaat(DateTime(2026, 1, 5, 0, 0)),
        '5 Ocak 2026, 00:00',
      );
    });

    test('Yıl sınırları doğru biçimlenir', () {
      expect(
        AppDateFormatter.gunAyYilSaat(DateTime(2026, 12, 31, 23, 59)),
        '31 Aralık 2026, 23:59',
      );
      expect(AppDateFormatter.gunAyYil(DateTime(2027, 1, 1)), '1 Ocak 2027');
    });
  });
}

/// `FirestoreClient`'in hazırlık sözleşmesi.
///
/// ## Neden bu dosya var
///
/// `getDoc`/`setDoc` bir dönem doğrudan `isReady`'ye bakıyordu ve
/// `ensureConfigured()` yalnızca sorgu (`where`) kullanan metotlara
/// eklenmişti. Sebep: orada `db` null olunca kod **çöküyordu**, yani
/// eksiklik hemen görünüyordu. `getDoc`/`setDoc` ise sessizce
/// `null`/`false` dönüyordu.
///
/// Sahada görülen hâli: okul yöneticiliği başvurusu hiç
/// gönderilemiyordu ve öğretmen "İnternet bağlantınızı kontrol edin"
/// mesajı görüyordu — interneti çalışırken. Mevcut başvuru da
/// okunamadığı için ekran sürekli boş form gösteriyordu.
///
/// ## Neden gerçek Firestore'a bağlanmıyor
///
/// Platform kanalı gerektiriyor; testte Firebase hiç başlatılamaz.
/// **Ama tam olarak bu, sınanmak istenen durum:** bulut hazır
/// değilken metotlar ne yapıyor? Beklenen davranış sessiz başarısızlık
/// (uygulama yerel veriyle devam eder), **çökme değil**.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/cloud/firestore_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final istemci = FirestoreClient.instance;

  group('Bulut hazır değilken sessiz başarısızlık', () {
    test('KRİTİK: getDoc çökmez, null döner', () async {
      // Testte Firebase başlatılamıyor; `_hazirla()` denemesini
      // yapıp başarısız olacak ve null dönecek.
      expect(await istemci.getDoc('deneme/kayit'), isNull);
    });

    test('KRİTİK: setDoc çökmez, false döner', () async {
      expect(
        await istemci.setDoc('deneme/kayit', {'a': 1}),
        isFalse,
      );
    });

    test('KRİTİK: deleteDoc çökmez, false döner', () async {
      expect(await istemci.deleteDoc('deneme/kayit'), isFalse);
    });

    test('commitBatch çökmez, false döner', () async {
      expect(
        await istemci.commitBatch({
          'deneme/a': {'x': 1},
        }),
        isFalse,
      );
    });

    test('boş batch hiç denenmez', () async {
      expect(await istemci.commitBatch(const {}), isFalse);
    });
  });

  group('Hazırlık denemesi yapılıyor mu', () {
    /// `debugPrint` çıktısını toplar.
    ///
    /// ## Neden çıktıya bakılıyor
    ///
    /// Bu testin ilk hâli yalnızca "çökmüyor, false dönüyor" diyordu
    /// ve **eski koda da geçiyordu** — çünkü testte Firebase hiçbir
    /// şekilde başlatılamıyor, yani hazırlık denense de denenmese de
    /// sonuç `false`. Sonucu sınamak kusuru ayırt etmiyor.
    ///
    /// Ayırt eden şey **hazırlığın denenmiş olması**: `ensureConfigured`
    /// çağrıldığında Firebase başlatma hatası `catch` bloğuna düşüyor
    /// ve oradaki günlük satırı basılıyor. O satırın varlığı, eski
    /// `if (!isReady) return false` erken çıkışının kalktığının
    /// kanıtı.
    test('KRİTİK: setDoc hazırlığı DENİYOR, erken çıkmıyor', () async {
      final satirlar = <String>[];
      final eski = debugPrint;
      debugPrint = (String? mesaj, {int? wrapWidth}) {
        if (mesaj != null) satirlar.add(mesaj);
      };

      try {
        await istemci.setDoc('deneme/kayit', {'a': 1});
      } finally {
        debugPrint = eski;
      }

      // `ensureConfigured` çağrıldıysa Firebase başlatma denemesi
      // yapılmış ve hata günlüğe düşmüş olmalı. Eski kod hiç
      // denemediği için bu satır HİÇ basılmıyordu.
      expect(
        satirlar.any((s) =>
            s.contains('ensureConfigured') ||
            s.contains('Firebase başlatılamadı') ||
            s.contains('bulut hazır değil')),
        isTrue,
        reason: 'setDoc hazırlığı denemedi — erken çıkış geri gelmiş '
            'olabilir. Toplanan günlük: $satirlar',
      );
    });

    test('KRİTİK: getDoc hazırlığı DENİYOR', () async {
      final satirlar = <String>[];
      final eski = debugPrint;
      debugPrint = (String? mesaj, {int? wrapWidth}) {
        if (mesaj != null) satirlar.add(mesaj);
      };

      try {
        await istemci.getDoc('deneme/kayit');
      } finally {
        debugPrint = eski;
      }

      expect(
        satirlar.any((s) =>
            s.contains('ensureConfigured') ||
            s.contains('Firebase başlatılamadı') ||
            s.contains('bulut hazır değil')),
        isTrue,
        reason: 'getDoc hazırlığı denemedi. Toplanan günlük: $satirlar',
      );
    });

    test('başarısız hazırlık istemciyi bozmuyor', () async {
      // İkinci ve üçüncü çağrı da aynı şekilde davranmalı; başarısız
      // hazırlık istemciyi kullanılamaz hâle sokmamalı.
      expect(await istemci.setDoc('deneme/kayit', {'a': 1}), isFalse);
      expect(await istemci.setDoc('deneme/kayit', {'a': 2}), isFalse);
      expect(await istemci.getDoc('deneme/kayit'), isNull);
    });

    test('ensureConfigured doğrudan çağrılabilir ve çökmez', () async {
      await istemci.ensureConfigured();
      // Firebase yok, yani hazır olmamalı — ama istisna da atmamalı.
      expect(istemci.isReady, isFalse);
      expect(istemci.db, isNull);
    });
  });
}

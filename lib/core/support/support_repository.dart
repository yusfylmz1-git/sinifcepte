import 'package:flutter/foundation.dart';

import '../cloud/firestore_client.dart';
import 'support_request.dart';

/// Destek taleplerinin buluta yazılması.
///
/// ## Neden gerekli
/// `HelpSupportModal` "Destek Talebini Gönder" diyor, ardından
/// "Talepleriniz en geç 24 saat içinde incelenir ve yanıtlanır" vaat
/// ediyordu. Gerçekte talep yalnızca **cihazdaki yerel denetim
/// günlüğüne** yazılıyordu; hiç kimse görmüyordu.
///
/// Kullanıcı yardım istediğini sanıyor, hiçbir karşılık alamıyordu.
/// Türkiye geneli bir uygulamada bu, güveni en hızlı yitiren şeydir.
class SupportRepository {
  SupportRepository._();

  static final SupportRepository instance = SupportRepository._();

  /// Firestore koleksiyonu.
  static const String collection = 'support_requests';

  /// Destek e-posta adresi.
  ///
  /// Bulut yazımı başarısız olursa (ağ yok, bütçe freni, kural reddi)
  /// kullanıcıya bu adres gösterilir — "gönderildi" deyip sessizce
  /// kaybetmektense doğrudan ulaşabileceği bir yol vermek gerekir.
  static const String supportEmail = 'sinifcepte@gmail.com';

  /// Talebi buluta yazar.
  ///
  /// `false` dönerse çağıran **başarılı demiş gibi davranmamalıdır**;
  /// kullanıcıya e-posta adresi gösterilmelidir.
  Future<bool> submit(SupportRequest request) async {
    if (!request.isValid) return false;

    try {
      await FirestoreClient.instance.ensureConfigured();
      final ok = await FirestoreClient.instance.setDoc(
        '$collection/${request.id}',
        request.toMap(),
        merge: false,
      );

      if (!ok) {
        debugPrint(
          'SupportRepository: talep buluta yazılamadı (${request.id}). '
          'Kullanıcıya e-posta adresi gösterilmeli.',
        );
      }
      return ok;
    } catch (e, stackTrace) {
      debugPrint('SupportRepository.submit hatası: $e\n$stackTrace');
      return false;
    }
  }

  /// Kullanicinin kendi taleplerini getirir ("Taleplerim" ekrani).
  ///
  /// Guvenlik kurali yalnizca kendi talebini okumaya izin verir; baska
  /// bir kullanicinin talebi sorgulansa bile kural reddeder.
  ///
  /// Sonuc sayisi sinirli: talep listesi zamanla buyur ve sinirsiz
  /// sorgu her acilista okuma maliyeti yazar.
  Future<List<SupportRequest>> myRequests(String userId,
      {int limit = 30}) async {
    if (userId.isEmpty) return const [];

    try {
      await FirestoreClient.instance.ensureConfigured();
      final db = FirestoreClient.instance.db;
      if (db == null) return const [];

      final snap = await db
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 5));

      await FirestoreClient.instance.recordQueryReads(snap.docs.length);

      return snap.docs
          .map((d) => SupportRequest.fromMap(d.id, d.data()))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('SupportRepository.myRequests hatasi: $e\n$stackTrace');
      return const [];
    }
  }

  /// Kullanıcının e-posta uygulamasında ön doldurulmuş bir taslak açacak
  /// `mailto:` bağlantısı üretir.
  ///
  /// Bulut yazımı başarısız olduğunda yedek yol budur.
  static Uri mailtoUri(SupportRequest request) {
    final buffer = StringBuffer()
      ..writeln(request.message)
      ..writeln()
      ..writeln('---')
      ..writeln('Kategori: ${request.category.label}')
      ..writeln('Rol: ${request.userRole}');

    // Surum ve platform hatayi tekrar uretmek icin gerekli; yoksa
    // "uygulama kapaniyor" bildirimini aramak kor bir is olur.
    if (request.appVersion != null) {
      buffer.writeln('Surum: ${request.appVersion}');
    }
    if (request.platform != null) {
      buffer.writeln('Platform: ${request.platform}');
    }

    return Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': '[SınıfCepte] ${request.subject}',
        'body': buffer.toString(),
      },
    );
  }
}

import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';
import '../../../core/support/support_repository.dart';
import '../../../core/support/support_request.dart';
import 'services/communication_ids.dart';

/// Bildir ve engelle (Google Play kullanıcı içeriği kuralı, 18 Ekim 2026).
///
/// ## Neden
/// Veli–öğretmen mesajları ve duyurular "kullanıcı içeriği" sayılır.
/// Play, uygulama içinden içeriği bildirme ve kişiyi engelleme yolu ister.
/// Eski şikâyet yolu hiç bağlanmamıştı (gönderen yoktu) ve okul
/// yöneticiliğiyle birlikte kalktı.
///
/// ## Nereye gider
/// Bildirim `support_requests` koleksiyonuna `content_report`
/// kategorisiyle yazılır ve yönetici panelinin "Bildirimler" sekmesinde
/// görünür. Kural, bildirilen metnin ve kişinin buluttaki asıl içerikle
/// aynı olduğunu doğrular: uydurma bir metinle birini karalamak mümkün
/// olmaz. Bu yüzden metin kırpılmadan gönderilir.
///
/// ## Engel
/// `user_blocks/{engelleyen}_{engellenen}` belgesi. Kural, engellenen
/// kişinin engelleyene mesaj yazmasını reddeder. Randevu talebi ve durum
/// bildirimi (erken çıkış vb.) öğrencinin güvenliği için açık kalır.
enum BildirimNedeni {
  hakaret('hakaret', 'Hakaret veya taciz'),
  uygunsuz('uygunsuz', 'Uygunsuz içerik'),
  spam('spam', 'Dolandırıcılık veya istenmeyen mesaj'),
  diger('diger', 'Diğer');

  const BildirimNedeni(this.id, this.ad);

  final String id;
  final String ad;
}

/// Bildirilen içeriğin türü.
enum BildirilenIcerik {
  mesaj('message'),
  duyuru('announcement');

  const BildirilenIcerik(this.id);

  final String id;
}

class IcerikBildirimi {
  final String bildirenUid;

  /// 'teacher' | 'parent'
  final String bildirenRol;
  final BildirilenIcerik tur;
  final String icerikId;
  final String classCloudId;
  final String studentCloudId;
  final String bildirilenUid;
  final String bildirilenAd;

  /// Bildirilen metin: buluttaki gövdeyle birebir aynı olmalı (kural).
  final String metin;

  /// Duyuru başlığı; mesajda boş.
  final String baslik;
  final BildirimNedeni neden;
  final String not;
  final DateTime zaman;

  const IcerikBildirimi({
    required this.bildirenUid,
    required this.bildirenRol,
    required this.tur,
    required this.icerikId,
    required this.classCloudId,
    this.studentCloudId = '',
    required this.bildirilenUid,
    required this.bildirilenAd,
    required this.metin,
    this.baslik = '',
    required this.neden,
    this.not = '',
    required this.zaman,
  });

  String get kimlik => CommunicationIds.supportRequest(authorUid: bildirenUid, now: zaman);

  Map<String, dynamic> toMap() {
    final ekNot = not.trim();
    return {
      'userId': bildirenUid,
      'userRole': bildirenRol,
      'category': SupportCategory.contentReport.id,
      'subject': 'İçerik bildirimi: ${neden.ad}',
      // Kural boş açıklamayı kabul etmez.
      'message': ekNot.isEmpty
          ? 'Ek not yok.'
          : (ekNot.length > SupportRequest.maxMessageLength
              ? ekNot.substring(0, SupportRequest.maxMessageLength)
              : ekNot),
      'status': 'open',
      'createdAt': zaman.toIso8601String(),
      'contentType': tur.id,
      'contentId': icerikId,
      'classCloudId': classCloudId,
      if (studentCloudId.isNotEmpty) 'studentCloudId': studentCloudId,
      'reportedUid': bildirilenUid,
      'reportedName': bildirilenAd,
      'excerpt': metin,
      if (tur == BildirilenIcerik.duyuru) 'contentTitle': baslik,
      'reason': neden.id,
    };
  }
}

/// İki yöndeki engel: ben onu engelledim mi, o beni engelledi mi?
class EngelDurumu {
  final bool benEngelledim;
  final bool beniEngelledi;

  const EngelDurumu({required this.benEngelledim, required this.beniEngelledi});

  static const yok = EngelDurumu(benEngelledim: false, beniEngelledi: false);
}

class ModerasyonDeposu {
  ModerasyonDeposu({FirestoreClient? client}) : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const engelKoleksiyonu = 'user_blocks';

  static String engelKimligi(String engelleyen, String engellenen) => '${engelleyen}_$engellenen';

  /// Bildirimi buluta yazar. false dönerse çağıran "gönderildi" demez,
  /// destek e-postasını gösterir.
  Future<bool> bildir(IcerikBildirimi b) async {
    try {
      return await _client.setDoc(
        '${SupportRepository.collection}/${b.kimlik}',
        b.toMap(),
        merge: false,
      );
    } catch (e) {
      debugPrint('İçerik bildirimi yazılamadı ($e)');
      return false;
    }
  }

  /// Sohbet açılınca iki okuma. Okunamazsa "engel yok" sayılır: asıl
  /// engel kuraldadır, ekran yalnızca bilgilendirir.
  Future<EngelDurumu> engelDurumu({required String ben, required String karsi}) async {
    if (ben.isEmpty || karsi.isEmpty) return EngelDurumu.yok;
    final sonuclar = await Future.wait([
      _client.getDoc('$engelKoleksiyonu/${engelKimligi(ben, karsi)}'),
      _client.getDoc('$engelKoleksiyonu/${engelKimligi(karsi, ben)}'),
    ]);
    return EngelDurumu(benEngelledim: sonuclar[0] != null, beniEngelledi: sonuclar[1] != null);
  }

  Future<bool> engelle({required String ben, required String karsi}) => _client.setDoc(
        '$engelKoleksiyonu/${engelKimligi(ben, karsi)}',
        {
          'blockerUid': ben,
          'blockedUid': karsi,
          'createdAt': DateTime.now().toIso8601String(),
        },
        merge: false,
      );

  Future<bool> engeliKaldir({required String ben, required String karsi}) =>
      _client.deleteDoc('$engelKoleksiyonu/${engelKimligi(ben, karsi)}');
}

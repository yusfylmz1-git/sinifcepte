import 'package:flutter/foundation.dart';

import '../../../core/cloud/firestore_client.dart';
import '../models/okul_config_model.dart';

/// Tahta açma yetkisinin bulut kaydı — öğretmen ister, yönetici onaylar.
///
/// ## Neden bu katman var
///
/// Önceki akışta idareci her öğretmeni tek tek ekliyor, QR üretiyor,
/// öğretmen o QR'ı **yüz yüze** okutuyordu. 40 öğretmenli bir okulda
/// bu saatler sürüyor ve tek seferlik de değil: telefon değiştiren,
/// uygulamayı silen, yeni gelen öğretmen için tekrar gerekiyor.
///
/// Kullanıcı tespiti (18 Eylül 2026): *"her öğretmen müdürün yanına
/// gelecek ve telefonunu kayıt edecek, bu uzun bir iş."*
///
/// ## Yol
///
/// ```text
/// school_boards/{schoolId}/teachers/{teacherUid}
/// ```
///
/// Doküman kimliği **öğretmenin uid'si**: her öğretmenin tek kaydı
/// olur, sorgu yerine tek `get()` yeter (maliyet kararlarıyla
/// tutarlı) ve aynı kişi kuyruğu birden fazla kayıtla dolduramaz.
///
/// Okul kimliği yolda olduğu için aynı öğretmen **iki okulda** ayrı
/// kayıt taşıyabiliyor — ikinci okulda görevlendirme yaygın.
///
/// ## Secret'ı kim üretiyor
///
/// **Öğretmenin telefonu.** Üretim zaten cihazda (`TahtaTotp`), ve
/// istek gönderilirken üretmek ek tur gerektirmiyor. Yönetici
/// onayladığında secret zaten orada.
///
/// Alternatif (yönetici onaylayınca üretsin) reddedildi: onay anında
/// ikinci bir yazma turu gerekirdi ve yöneticinin telefonu çevrimdışıysa
/// onay askıda kalırdı.
///
/// ## Mevcut elle ekleme yolu kalıyor
///
/// `TahtaOgretmenDeposu` (cihaz içi liste) silinmiyor: telefonu
/// olmayan öğretmen, yöneticisi olmayan okul ve çevrimdışı kurulum
/// için o yol çalışmaya devam ediyor. Bu katman **ek bir yol**.
///
/// ## KVKK
///
/// Secret bulutta duruyor. Bu, öğretmen (personel) verisi — hafızadaki
/// "öğrenci verisi cihazda kalır" kararı öğrenci verisi içindi.
/// `school_teachers` koleksiyonunda öğretmenin adı, e-postası ve okulu
/// zaten bulutta; secret onlardan daha az kişisel (rastgele dize).
/// Aydınlatma metnine bir satır eklenecek.
///
/// **Buluta çıkmayan:** "kim hangi tahtayı ne zaman açtı" günlüğü. O,
/// Fiziksel Mekan Güvenliği kapsamında ve MEB ile sözleşme gerektirir;
/// tahtada kalmaya devam ediyor.
class TahtaYetkiDeposu {
  TahtaYetkiDeposu({FirestoreClient? client})
      : _client = client ?? FirestoreClient.instance;

  final FirestoreClient _client;

  static const String _kok = 'school_boards';

  /// Bir öğretmenin yetki kaydı yolu.
  static String yetkiPath(String schoolId, String teacherUid) =>
      '$_kok/$schoolId/teachers/$teacherUid';

  /// Öğretmen tahta yetkisi ister.
  ///
  /// Kayıt `bekliyor` durumuyla oluşur; kural başka bir değeri
  /// reddediyor (yetki yükseltme koruması). Secret bu çağrıda
  /// üretilmiş olarak geliyor — depo üretmiyor ki test edilebilir
  /// kalsın.
  ///
  /// Zaten kayıt varsa **üzerine yazmıyor**: mevcut secret değişirse
  /// öğretmenin telefonundaki kayıt geçersiz olur ve öğretmen sebebini
  /// anlamaz. Bu hata sınıfı cihaz tarafında da ayrıca engellendi.
  Future<YetkiIstekSonucu> istekGonder({
    required String schoolId,
    required String teacherUid,
    required String ad,
    required String kod,
    required String totpSecret,
  }) async {
    if (schoolId.isEmpty || teacherUid.isEmpty) {
      return const YetkiIstekSonucu(hata: 'Okul veya kullanıcı bilgisi yok.');
    }
    if (ad.trim().isEmpty) {
      return const YetkiIstekSonucu(hata: 'Öğretmen adı boş olamaz.');
    }
    if (totpSecret.length < 16) {
      // Kural da reddediyor; önden kesmek kullanıcıya boş bir
      // reddedilme yaşatmamak için.
      return const YetkiIstekSonucu(hata: 'Üretilen kod geçersiz.');
    }

    final mevcut = await kendiKaydiniOku(
      schoolId: schoolId,
      teacherUid: teacherUid,
    );
    if (mevcut != null) {
      return YetkiIstekSonucu(
        kayit: mevcut,
        hata: mevcut.durum == YetkiDurumu.onayli
            ? 'Yetkiniz zaten onaylı.'
            : 'İsteğiniz zaten gönderilmiş, onay bekleniyor.',
      );
    }

    final basarili = await _client.setDoc(
      yetkiPath(schoolId, teacherUid),
      {
        'teacherUid': teacherUid,
        'ad': ad.trim(),
        'kod': kod.trim().toUpperCase(),
        'totpSecret': totpSecret,
        'durum': 'bekliyor',
        'istekZamani': DateTime.now().toIso8601String(),
        'onayZamani': '',
        'onaylayanUid': '',
      },
      merge: false,
    );

    if (!basarili) {
      return const YetkiIstekSonucu(
        hata: 'İstek gönderilemedi. Bağlantınızı kontrol edip '
            'tekrar deneyin.',
      );
    }

    return YetkiIstekSonucu(
      kayit: TahtaYetkiKaydi(
        teacherUid: teacherUid,
        ad: ad.trim(),
        kod: kod.trim().toUpperCase(),
        totpSecret: totpSecret,
        durum: YetkiDurumu.bekliyor,
      ),
    );
  }

  /// Öğretmenin kendi kaydını okur; yoksa `null`.
  ///
  /// Kural gereği öğretmen yalnızca kendi kaydını okuyabiliyor, yani
  /// bu çağrı başka birinin kaydını getirmiyor.
  Future<TahtaYetkiKaydi?> kendiKaydiniOku({
    required String schoolId,
    required String teacherUid,
  }) async {
    if (schoolId.isEmpty || teacherUid.isEmpty) return null;

    final veri = await _client.getDoc(yetkiPath(schoolId, teacherUid));
    if (veri == null) return null;
    return TahtaYetkiKaydi.haritadan(veri);
  }

  /// Okulun tüm yetki kayıtlarını okur (yönetici).
  ///
  /// Yönetici okumak **zorunda**: tahtaya götürülecek `okul_config`
  /// dosyasını bu secret'larla üretiyor.
  ///
  /// Koleksiyonun tamamı okunuyor, sorgu yazılmıyor: bir okulda en
  /// fazla öğretmen sayısı kadar doküman var ve `durum` süzgeci
  /// istemcide uygulanıyor — indeks gerektirmiyor.
  Future<List<TahtaYetkiKaydi>> okulunKayitlari({
    required String schoolId,
    int limit = 200,
  }) async {
    if (schoolId.isEmpty) return const [];

    await _client.ensureConfigured();
    final db = _client.db;
    if (db == null) return const [];

    try {
      final snap = await db
          .collection(_kok)
          .doc(schoolId)
          .collection('teachers')
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 8));

      await _client.recordQueryReads(snap.docs.length);

      return snap.docs
          .map((d) => TahtaYetkiKaydi.haritadan(d.data()))
          .where((k) => k.teacherUid.isNotEmpty)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('okulunKayitlari hatası: $e\n$stackTrace');
      return const [];
    }
  }

  /// Yönetici isteği onaylar.
  ///
  /// `merge: true`: secret ve ad korunuyor, yalnızca karar alanları
  /// yazılıyor. `merge: false` olsaydı secret silinir ve öğretmen
  /// onaylandığı hâlde tahtayı açamazdı.
  Future<bool> onayla({
    required String schoolId,
    required String teacherUid,
    required String onaylayanUid,
  }) async {
    if (schoolId.isEmpty || teacherUid.isEmpty) return false;

    return _client.setDoc(
      yetkiPath(schoolId, teacherUid),
      {
        'durum': 'onayli',
        'onayZamani': DateTime.now().toIso8601String(),
        'onaylayanUid': onaylayanUid,
      },
      merge: true,
    );
  }

  /// Yönetici isteği reddeder.
  ///
  /// Kayıt **silinmiyor**: yönetici aynı kişiyi tekrar tekrar
  /// değerlendirmesin diye "reddedildi" durumu görünür kalıyor.
  Future<bool> reddet({
    required String schoolId,
    required String teacherUid,
    required String onaylayanUid,
  }) async {
    if (schoolId.isEmpty || teacherUid.isEmpty) return false;

    return _client.setDoc(
      yetkiPath(schoolId, teacherUid),
      {
        'durum': 'reddedildi',
        'onayZamani': DateTime.now().toIso8601String(),
        'onaylayanUid': onaylayanUid,
      },
      merge: true,
    );
  }

  /// Yönetici öğretmeni listeden çıkarır (tayin, ayrılma).
  ///
  /// ## Kabul edilmiş risk
  ///
  /// Bu çağrı öğretmenin **telefonunu** keser: uygulama internete
  /// bağlanınca kaydı bulamaz ve kod üretmez.
  ///
  /// Ama **tahtadaki dosya** onu tanımaya devam eder. Tahta ağa
  /// çıkmıyor (temel mimari karar), yani silme anında tahtaya
  /// ulaşamıyoruz. Yetki ancak yeni `okul_config` flash bellekle
  /// götürülünce tamamen kapanır.
  ///
  /// Kullanıcı bu riski bilerek kabul etti (18 Eylül 2026). Çağıran
  /// arayüz bunu **gizlemeden** söylemek zorunda.
  Future<bool> cikar({
    required String schoolId,
    required String teacherUid,
  }) async {
    if (schoolId.isEmpty || teacherUid.isEmpty) return false;
    return _client.deleteDoc(yetkiPath(schoolId, teacherUid));
  }
}

/// Yetki kaydının durumu.
enum YetkiDurumu {
  bekliyor,
  onayli,
  reddedildi;

  static YetkiDurumu cozumle(String? ham) {
    switch (ham) {
      case 'onayli':
        return YetkiDurumu.onayli;
      case 'reddedildi':
        return YetkiDurumu.reddedildi;
      default:
        // Tanınmayan değer `bekliyor` sayılıyor: yetki VERMEYEN
        // taraf güvenli olan. Bozuk bir kayıt yüzünden kimse
        // kendiliğinden yetkilenmemeli.
        return YetkiDurumu.bekliyor;
    }
  }

  String get depoDegeri => name;
}

/// Bir öğretmenin tahta yetkisi kaydı.
class TahtaYetkiKaydi {
  const TahtaYetkiKaydi({
    required this.teacherUid,
    required this.ad,
    required this.kod,
    required this.totpSecret,
    required this.durum,
    this.istekZamani = '',
    this.onayZamani = '',
    this.onaylayanUid = '',
  });

  final String teacherUid;
  final String ad;

  /// Tahtada elle girilen kısa kod (`YYILMAZ`).
  final String kod;

  /// TOTP secret'ı (base32).
  final String totpSecret;

  final YetkiDurumu durum;
  final String istekZamani;
  final String onayZamani;
  final String onaylayanUid;

  bool get onayli => durum == YetkiDurumu.onayli;
  bool get bekliyor => durum == YetkiDurumu.bekliyor;

  factory TahtaYetkiKaydi.haritadan(Map<String, dynamic> m) {
    return TahtaYetkiKaydi(
      teacherUid: (m['teacherUid'] as String?) ?? '',
      ad: (m['ad'] as String?) ?? '',
      kod: (m['kod'] as String?) ?? '',
      totpSecret: (m['totpSecret'] as String?) ?? '',
      durum: YetkiDurumu.cozumle(m['durum'] as String?),
      istekZamani: (m['istekZamani'] as String?) ?? '',
      onayZamani: (m['onayZamani'] as String?) ?? '',
      onaylayanUid: (m['onaylayanUid'] as String?) ?? '',
    );
  }

  /// `okul_config` dosyasına yazılacak biçim.
  ///
  /// Yalnızca **onaylı** kayıtlar dosyaya girmeli; süzgeç çağıranda.
  PanoOgretmeni panoOgretmeni() => PanoOgretmeni(
        kod: kod,
        ad: ad,
        totpSecret: totpSecret,
      );
}

/// İstek gönderme sonucu.
class YetkiIstekSonucu {
  const YetkiIstekSonucu({this.kayit, this.hata});

  final TahtaYetkiKaydi? kayit;

  /// Kullanıcıya gösterilecek sebep. Başarılıysa null.
  ///
  /// Tek sebep gösteren mesaj yazmıyoruz: "internet bağlantınızı
  /// kontrol edin" bir dönem bu projede yanlış teşhise yol açtı
  /// (gerçek sebep bulut istemcisinin hazır olmamasıydı).
  final String? hata;

  bool get basarili => kayit != null && hata == null;
}

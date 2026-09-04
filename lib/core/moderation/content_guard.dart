/// Mesaj içeriği denetimi.
///
/// ## Neden gerekli
/// Mesajlarda **hiçbir denetim yoktu**: ne argo filtresi, ne hız sınırı.
/// Öğretmen–veli iletişiminde hakaret ya da spam bombardımanı hiçbir
/// engele takılmıyordu.
///
/// ## Neden cihazda çalışıyor
/// Denetim sunucuda yapılsaydı her mesaj için ek okuma/yazma maliyeti
/// çıkardı. Cihazda çalışan bir kontrol **sıfır bulut maliyeti** ile
/// aynı işi görür. Kararlı bir saldırgan istemciyi atlatabilir; bu
/// yüzden şikayet mekanizması ikinci katman olarak durur.
///
/// ## Neden engellemek yerine uyarıyor
/// Türkçede bağlama göre masum kelimeler var ("sikinti" yazarken düşen
/// harf, "piç" içeren yer adları). Mesajı doğrudan reddetmek yanlış
/// alarmda kullanıcıyı kilitlerdi. Doğru davranış: uyar, kullanıcı
/// yine de göndermek isterse göndersin — ama şikayet edilebilir olsun.
library;

import '../utils/turkish_text.dart';

/// İçerik denetimi sonucu.
enum ContentVerdict {
  /// Sorun yok.
  clean,

  /// Uygunsuz ifade bulundu; kullanıcı uyarılmalı.
  offensive,

  /// Çok hızlı mesaj gönderiliyor (spam şüphesi).
  tooFast,

  /// Aynı mesaj art arda tekrarlanıyor.
  repeated,

  /// Mesaj boş.
  empty,
}

/// Denetim sonucu ve kullanıcıya gösterilecek açıklama.
class ContentCheck {
  final ContentVerdict verdict;

  /// Bulunan uygunsuz ifade (uyarıda gösterilmez, günlüğe yazılır).
  final String? matched;

  const ContentCheck(this.verdict, {this.matched});

  bool get isClean => verdict == ContentVerdict.clean;

  /// Gönderim tamamen engellensin mi?
  ///
  /// Argo yalnızca **uyarır**; hız sınırı ve boş mesaj engeller.
  bool get blocks =>
      verdict == ContentVerdict.tooFast ||
      verdict == ContentVerdict.repeated ||
      verdict == ContentVerdict.empty;

  String? get message {
    switch (verdict) {
      case ContentVerdict.clean:
        return null;
      case ContentVerdict.offensive:
        return 'Mesajınız uygunsuz olabilecek bir ifade içeriyor. '
            'Öğretmen–veli iletişiminde saygılı bir dil kullanmanızı '
            'rica ederiz.';
      case ContentVerdict.tooFast:
        return 'Çok hızlı mesaj gönderiyorsunuz. Lütfen biraz bekleyin.';
      case ContentVerdict.repeated:
        return 'Aynı mesajı az önce gönderdiniz.';
      case ContentVerdict.empty:
        return 'Boş mesaj gönderilemez.';
    }
  }
}

/// Mesaj denetleyici.
class ContentGuard {
  ContentGuard._();

  static final ContentGuard instance = ContentGuard._();

  /// Dakikada gönderilebilecek en fazla mesaj.
  static const int maxPerMinute = 5;

  /// Saatte gönderilebilecek en fazla mesaj.
  static const int maxPerHour = 30;

  /// Argo / hakaret kök listesi.
  ///
  /// Kök hâlleri tutulur; Türkçe ekler (-in, -im, -sin...) sonuna
  /// geldiğinde de yakalanır. Liste bilinçli olarak **kısa** tutuldu:
  /// uzun listeler yanlış alarm üretiyor ve masum mesajları engelliyor.
  static const List<String> _offensiveRoots = [
    'amk', 'aq', 'oc',
    'siktir', 'sikeyim', 'sikik',
    'orospu', 'kahpe',
    'piç', 'pezevenk',
    'yavşak', 'şerefsiz', 'gerizekalı', 'salak', 'aptal',
    'mal herif', 'geri zekalı',
    'ananı', 'anan', 'babanı',
    // 'top' listeden CIKARILDI: okul baglaminda cok yaygin
    // ("beden dersine top getirsin mi?"). Yakalamaya calismak
    // masum mesajlari uyariyor; kazanci zararindan az.
    'ibne', 'gavat',

    'lanet olsun', 'defol',
  ];

  /// Tek başına geçtiğinde masum olan, yanlış alarm üreten kelimeler.
  ///
  /// "top" kelimesi beden eğitimi mesajında geçebilir; "anan" ise
  /// "anlaşılan" gibi kelimelerin içinde kalabilir. Bunlar yalnızca
  /// **kelime sınırıyla** eşleşirse sayılır.
  static const List<String> _wholeWordOnly = ['anan', 'oc', 'aq', 'mal'];

  /// Son gönderim zamanları (kullanıcı bazında).
  final Map<String, List<DateTime>> _history = {};

  /// Son gönderilen mesaj metni (tekrar kontrolü için).
  final Map<String, String> _lastBody = {};

  /// Mesajı denetler. Gönderimden **önce** çağrılır.
  ///
  /// [userId] hız sınırının kime uygulanacağını belirler.
  ContentCheck check({
    required String userId,
    required String body,
    DateTime? now,
  }) {
    final text = body.trim();
    if (text.isEmpty) {
      return const ContentCheck(ContentVerdict.empty);
    }

    final ts = now ?? DateTime.now();

    // 1. Aynı mesaj tekrarı
    if (_lastBody[userId] == text) {
      return const ContentCheck(ContentVerdict.repeated);
    }

    // 2. Hız sınırı
    final gecmis = _history[userId] ?? const <DateTime>[];
    final sonDakika =
        gecmis.where((t) => ts.difference(t) < const Duration(minutes: 1)).length;
    final sonSaat =
        gecmis.where((t) => ts.difference(t) < const Duration(hours: 1)).length;

    if (sonDakika >= maxPerMinute || sonSaat >= maxPerHour) {
      return const ContentCheck(ContentVerdict.tooFast);
    }

    // 3. Argo taraması
    final bulunan = findOffensive(text);
    if (bulunan != null) {
      return ContentCheck(ContentVerdict.offensive, matched: bulunan);
    }

    return const ContentCheck(ContentVerdict.clean);
  }

  /// Mesaj gönderildikten sonra çağrılır; sayaçları ilerletir.
  ///
  /// Denetimden ayrı tutuldu: kullanıcı uyarıyı görüp vazgeçerse o
  /// mesaj sayaca yazılmamalı.
  void recordSent({
    required String userId,
    required String body,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final liste = _history.putIfAbsent(userId, () => <DateTime>[]);
    liste.add(ts);

    // Bir saatten eski kayıtlar atılır; liste sınırsız büyümemeli.
    liste.removeWhere((t) => ts.difference(t) > const Duration(hours: 1));

    _lastBody[userId] = body.trim();
  }

  /// Metinde uygunsuz ifade var mı? Varsa bulunan kökü döner.
  ///
  /// Türkçe karakter duyarsız çalışır: "şerefsiz" ve "serefsiz" aynı
  /// şekilde yakalanır (`trFold` kullanır).
  static String? findOffensive(String text) {
    final katlanmis = trFold(text);

    for (final kok in _offensiveRoots) {
      final katlanmisKok = trFold(kok);

      if (_wholeWordOnly.contains(kok)) {
        // Kelime sınırıyla ara: "top" kelimesi "toplantı" içinde
        // eşleşmemeli.
        final desen = RegExp(
          '(^|[^a-z0-9])${RegExp.escape(katlanmisKok)}([^a-z0-9]|\$)',
        );
        if (desen.hasMatch(katlanmis)) return kok;
      } else if (katlanmis.contains(katlanmisKok)) {
        return kok;
      }
    }
    return null;
  }

  /// Test ve oturum kapanışında sayaçları temizler.
  void reset() {
    _history.clear();
    _lastBody.clear();
  }
}

/// Quiz / sözlü not girişinin çözümlenmesi.
///
/// Not girişi eskiden doğrudan `int.tryParse` ile okunuyordu ve üç ayrı
/// durum tek sonuca indirgeniyordu:
///
///   * `"abc"`  -> null -> notu **sessizce siliyordu**
///   * `""`     -> null -> notu siliyordu (bu doğru davranış)
///   * `"955"`  -> 955 -> sağlayıcı 100'e kırpıyordu, öğretmene haber yok
///
/// En tehlikelisi birincisi: öğretmen 85'lik notu düzeltmek için açıp
/// yanlış tuşa basınca not gidiyordu ve hiçbir uyarı çıkmıyordu.
/// İkincisi de sessiz: 95 yazmak isterken 955 yazan öğretmen 100
/// verdiğini fark etmiyordu.
///
/// Bu tür bir ayrım kullanıcı arayüzünde `if` yığınıyla değil, tek yerde
/// çözülmeli ki hem quiz hem ileride eklenecek diğer not ekranları aynı
/// davranışı paylaşsın.
library;

/// Not girişinin çözümlenme sonucu.
enum ScoreParseStatus {
  /// Alan boş: öğretmen notu bilerek siliyor.
  cleared,

  /// Geçerli, 0-100 aralığında bir not.
  valid,

  /// Sayı ama aralık dışında (negatif ya da 100 üstü).
  outOfRange,

  /// Hiç sayı değil ("abc", "9a", "1,5").
  notANumber,
}

/// Not girişinin çözümlenmiş hâli.
class ScoreParseResult {
  final ScoreParseStatus status;

  /// Yalnızca [ScoreParseStatus.valid] durumunda doludur.
  final int? score;

  /// Aralık dışı girişte kullanıcının yazdığı ham sayı (mesajda gösterilir).
  final int? rawValue;

  const ScoreParseResult._(this.status, {this.score, this.rawValue});

  bool get isValid => status == ScoreParseStatus.valid;
  bool get isCleared => status == ScoreParseStatus.cleared;

  /// Veritabanına yazılabilir mi? Yalnızca geçerli not ya da bilinçli silme.
  bool get canSave => isValid || isCleared;

  /// Kullanıcıya gösterilecek hata; sorun yoksa null.
  String? get errorMessage {
    switch (status) {
      case ScoreParseStatus.valid:
      case ScoreParseStatus.cleared:
        return null;
      case ScoreParseStatus.outOfRange:
        return 'Not 0 ile 100 arasında olmalı. Girilen: $rawValue';
      case ScoreParseStatus.notANumber:
        return 'Geçerli bir sayı girin. Notu silmek için "Notu Sil" düğmesini kullanın.';
    }
  }
}

/// Not alanının metnini çözümler.
///
/// Kırpma (`clamp`) bilerek yapılmaz: 955 yazan öğretmene sessizce 100
/// vermek, yanlış notu doğruymuş gibi kaydetmek demektir. Bunun yerine
/// aralık dışı giriş reddedilir ve öğretmen ne yazdığını görür.
ScoreParseResult parseScoreInput(String raw) {
  final text = raw.trim();

  if (text.isEmpty) {
    return const ScoreParseResult._(ScoreParseStatus.cleared);
  }

  final value = int.tryParse(text);
  if (value == null) {
    return const ScoreParseResult._(ScoreParseStatus.notANumber);
  }

  if (value < 0 || value > 100) {
    return ScoreParseResult._(ScoreParseStatus.outOfRange, rawValue: value);
  }

  return ScoreParseResult._(ScoreParseStatus.valid, score: value);
}

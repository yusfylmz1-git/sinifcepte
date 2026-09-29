/// Kaydın durumu. Veritabanında metin olarak durur.
abstract final class FotoDurumu {
  static const hazir = 'hazir';

  /// Kalite uyarısı var, öğretmen yine de onayladı; listede işaretlenir.
  static const inceleme = 'inceleme';

  /// Kayıt var ama dosya diskte yok (yedekten dönen veritabanı, silinmiş
  /// uygulama verisi). "Hazır" sayılmaz; yeniden çekim istenir.
  static const dosyaYok = 'dosya_yok';
}

abstract final class FotoKaynagi {
  static const kamera = 'kamera';
  static const dosya = 'dosya';
}

/// `student_photos` satırı.
class OgrenciFoto {
  const OgrenciFoto({
    required this.id,
    required this.studentId,
    required this.revision,
    required this.status,
    required this.standardPath,
    required this.width,
    required this.height,
    required this.byteSize,
    required this.checksum,
    required this.sourceType,
    required this.capturedSchoolNumber,
    required this.capturedFullName,
    required this.identityConfirmedAt,
    required this.capturedAt,
    required this.approvedAt,
    required this.updatedAt,
    this.qualityFlags = const [],
    this.manualQualityOverride = false,
    this.backgroundMode = 'ozgun',
  });

  final String id;
  final int studentId;
  final int revision;
  final String status;
  final String standardPath;
  final int width;
  final int height;
  final int byteSize;
  final String checksum;
  final String sourceType;

  /// Çekim anında öğretmenin doğruladığı kimlik — DENETİM KOPYASI.
  /// Güncel ad/numara her zaman `students` tablosundan okunur; bu ikisi
  /// yanlış eşleşmeyi ve sonradan değişen bilgiyi yakalamak için.
  final int capturedSchoolNumber;
  final String capturedFullName;
  final DateTime identityConfirmedAt;

  final DateTime capturedAt;
  final DateTime approvedAt;
  final DateTime updatedAt;

  /// Kişisel veri içermeyen kontrol sonuçları (ör. `bulanik`, `karanlik`).
  final List<String> qualityFlags;
  final bool manualQualityOverride;
  final String backgroundMode;

  bool get hazirMi => status == FotoDurumu.hazir || status == FotoDurumu.inceleme;

  /// Öğrencinin güncel kaydı çekimdeki kimlikten farklı mı?
  ///
  /// Dışa aktarma bunu sessizce geçmez; öğretmenden yeniden onay ister
  /// (plan §8.1). Ad karşılaştırması büyük/küçük harf ve boşluk
  /// farkını yok sayar — "Ali  YILMAZ" ile "Ali Yılmaz" aynı kişi.
  bool kimlikFarkli({required int okulNo, required String adSoyad}) {
    if (okulNo != capturedSchoolNumber) return true;
    return _katla(adSoyad) != _katla(capturedFullName);
  }

  static String _katla(String s) {
    // Türkçe İ/I: lower()'dan ÖNCE katlanmalı ('İ'.toLowerCase() iki
    // kod noktası veriyor).
    final b = s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return b;
  }

  factory OgrenciFoto.fromMap(Map<String, Object?> m) => OgrenciFoto(
        id: m['id']! as String,
        studentId: m['student_id']! as int,
        revision: m['revision']! as int,
        status: m['status']! as String,
        standardPath: m['standard_relative_path']! as String,
        width: m['width']! as int,
        height: m['height']! as int,
        byteSize: m['byte_size']! as int,
        checksum: m['checksum']! as String,
        sourceType: m['source_type']! as String,
        capturedSchoolNumber: m['captured_school_number']! as int,
        capturedFullName: m['captured_full_name']! as String,
        identityConfirmedAt: DateTime.parse(m['identity_confirmed_at']! as String),
        capturedAt: DateTime.parse(m['captured_at']! as String),
        approvedAt: DateTime.parse(m['approved_at']! as String),
        updatedAt: DateTime.parse(m['updated_at']! as String),
        qualityFlags: _bayraklar(m['quality_flags'] as String?),
        manualQualityOverride: (m['manual_quality_override'] as int? ?? 0) == 1,
        backgroundMode: (m['background_mode'] as String?) ?? 'ozgun',
      );

  static List<String> _bayraklar(String? s) =>
      (s == null || s.isEmpty) ? const [] : s.split(',');
}

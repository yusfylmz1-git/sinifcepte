import 'dart:convert';

/// Seri çekim sırası (plan §4.4) — saf hesap, disk/veritabanı yok.
///
/// Sıra öğrenci kimliklerinden oluşur. Öğretmen sırayla çeker, isterse
/// atlar; uygulama kapanırsa kaldığı yerden sürer. Sıradaki öğrenci her
/// seferinde GÜNCEL sınıf listesiyle süzülür: oturum sürerken silinen ya
/// da başka sınıfa taşınan öğrenci sırada görünmez.
class CekimSirasi {
  const CekimSirasi({
    required this.sira,
    this.tamamlanan = const {},
    this.atlanan = const {},
    this.konum = 0,
  });

  final List<int> sira;
  final Set<int> tamamlanan;
  final Set<int> atlanan;

  /// Aramanın başladığı yer (son işlenen öğrencinin ardı).
  final int konum;

  /// Sıradaki öğrenci: [konum]'dan başlayıp başa sararak, [gecerli]
  /// içinde olan, tamamlanmamış ve atlanmamış ilk öğrenci. Yoksa `null`.
  int? siradaki(Set<int> gecerli) {
    if (sira.isEmpty) return null;
    for (var i = 0; i < sira.length; i++) {
      final id = sira[(konum + i) % sira.length];
      if (gecerli.contains(id) && !tamamlanan.contains(id) && !atlanan.contains(id)) return id;
    }
    return null;
  }

  int _sonrasi(int id) {
    final i = sira.indexOf(id);
    return i < 0 ? konum : i + 1;
  }

  CekimSirasi kaydedildi(int id) => CekimSirasi(
        sira: sira,
        tamamlanan: {...tamamlanan, id},
        atlanan: {...atlanan}..remove(id),
        konum: _sonrasi(id),
      );

  CekimSirasi atlandi(int id) => CekimSirasi(
        sira: sira,
        tamamlanan: tamamlanan,
        atlanan: {...atlanan, id},
        konum: _sonrasi(id),
      );

  /// Son çekimi geri al: öğrenci yeniden sıradaki olur.
  CekimSirasi geriAlindi(int id) {
    final i = sira.indexOf(id);
    return CekimSirasi(
      sira: sira,
      tamamlanan: {...tamamlanan}..remove(id),
      atlanan: atlanan,
      konum: i < 0 ? konum : i,
    );
  }

  /// Atlananlar yeniden sıraya (baştan).
  CekimSirasi atlananlarSiraya() => CekimSirasi(sira: sira, tamamlanan: tamamlanan, konum: 0);

  /// Geçerli öğrenciler arasında sayımlar.
  ({int toplam, int tamam, int atlanan, int kalan}) sayim(Set<int> gecerli) {
    final g = sira.where(gecerli.contains).toList();
    final t = g.where(tamamlanan.contains).length;
    final a = g.where((id) => atlanan.contains(id) && !tamamlanan.contains(id)).length;
    return (toplam: g.length, tamam: t, atlanan: a, kalan: g.length - t - a);
  }

  // Veritabanı sütunları (photo_capture_sessions).
  String get siraJson => jsonEncode(sira);
  String get tamamlananJson => jsonEncode(tamamlanan.toList()..sort());
  String get atlananJson => jsonEncode(atlanan.toList()..sort());

  static List<int> _liste(Object? s) {
    if (s is! String || s.isEmpty) return const [];
    try {
      return (jsonDecode(s) as List).map((e) => e as int).toList();
    } catch (_) {
      return const []; // bozuk kayıt: boş sıra, oturum yeniden başlatılır
    }
  }

  factory CekimSirasi.satirdan(Map<String, Object?> m) => CekimSirasi(
        sira: _liste(m['student_order']),
        tamamlanan: _liste(m['completed']).toSet(),
        atlanan: _liste(m['skipped']).toSet(),
        konum: (m['position'] as int?) ?? 0,
      );
}

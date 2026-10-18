import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories/cloud_communication_repository.dart';

/// Öğretmenin veli gelen kutusu: bütün sınıflardan, kadrodaki sınıflar
/// dahil, kendisine yazılan mesajların sohbet özetleri (18 Ekim 2026).
///
/// ## Neden cihazda özet
/// Maliyet kararları: canlı dinleyici yok (#4), okumalar delta (#2).
/// Sınıf başına yalnız son senkrondan sonraki mesajlar çekilir; yeni mesaj
/// yoksa sıfır doküman. Sohbetin son mesajı ve okunmamış sayısı cihazda
/// tutulur. Eski düzende öğretmen tarafında okunma takibi hiç yoktu: her
/// veli mesajı her açılışta "yeni" sayılıyordu.
///
/// ## Okunmamış ne demek
/// Sohbet en son açıldığı andan sonra veliden gelen mesaj sayısı. Sohbet
/// açılınca [GelenKutusuDeposu.gorulduIsaretle] sıfırlar. Cihaza özeldir
/// (aynı öğretmen iki telefonda kullanırsa her biri kendi sayısını tutar).
class SohbetOzeti {
  final String classCloudId;
  final String studentCloudId;
  final String parentUserId;
  final String studentName;
  final String parentName;
  final String sonMesaj;
  final DateTime sonZaman;
  final bool sonYazanVeli;
  final int okunmamis;

  const SohbetOzeti({
    required this.classCloudId,
    required this.studentCloudId,
    required this.parentUserId,
    required this.studentName,
    required this.parentName,
    required this.sonMesaj,
    required this.sonZaman,
    required this.sonYazanVeli,
    required this.okunmamis,
  });

  String get anahtar => sohbetAnahtari(classCloudId, studentCloudId, parentUserId);

  SohbetOzeti copyWith({
    String? studentName,
    String? parentName,
    String? sonMesaj,
    DateTime? sonZaman,
    bool? sonYazanVeli,
    int? okunmamis,
  }) =>
      SohbetOzeti(
        classCloudId: classCloudId,
        studentCloudId: studentCloudId,
        parentUserId: parentUserId,
        studentName: studentName ?? this.studentName,
        parentName: parentName ?? this.parentName,
        sonMesaj: sonMesaj ?? this.sonMesaj,
        sonZaman: sonZaman ?? this.sonZaman,
        sonYazanVeli: sonYazanVeli ?? this.sonYazanVeli,
        okunmamis: okunmamis ?? this.okunmamis,
      );

  Map<String, dynamic> toMap() => {
        'c': classCloudId,
        's': studentCloudId,
        'p': parentUserId,
        'sa': studentName,
        'pa': parentName,
        'm': sonMesaj,
        't': sonZaman.toIso8601String(),
        'v': sonYazanVeli,
        'o': okunmamis,
      };

  static SohbetOzeti? fromMap(Map<String, dynamic> m) {
    final t = DateTime.tryParse(m['t'] as String? ?? '');
    final c = m['c'] as String? ?? '';
    final s = m['s'] as String? ?? '';
    if (t == null || c.isEmpty || s.isEmpty) return null;
    return SohbetOzeti(
      classCloudId: c,
      studentCloudId: s,
      parentUserId: m['p'] as String? ?? '',
      studentName: m['sa'] as String? ?? '',
      parentName: m['pa'] as String? ?? '',
      sonMesaj: m['m'] as String? ?? '',
      sonZaman: t,
      sonYazanVeli: m['v'] as bool? ?? false,
      okunmamis: (m['o'] as num?)?.toInt() ?? 0,
    );
  }
}

String sohbetAnahtari(String classCloudId, String studentCloudId, String parentUserId) =>
    '$classCloudId|$studentCloudId|$parentUserId';

/// Yeni mesajları sohbet özetlerine işler (saf hesap, test edilir).
///
/// [yeniMesajlar] bir sınıfın daha önce işlenmemiş mesajlarıdır (yeniden
/// gelenleri [gelenKutusunuEsitle] ayıklar). Veliden gelen ve sohbetin en
/// son görüldüğü andan sonra yazılmış mesaj okunmamış sayılır. Öğretmenin
/// kendi mesajı sayacı sıfırlar: yanıt yazdıysa öncesini okumuştur (yanıtı
/// başka bir cihazdan ya da "Bir veliye yaz" listesinden yazmış olabilir).
Map<String, SohbetOzeti> mesajlariIsle({
  required Map<String, SohbetOzeti> mevcut,
  required String classCloudId,
  required List<CloudMessage> yeniMesajlar,
  required Map<String, DateTime> sonGorulen,
}) {
  final sonuc = Map<String, SohbetOzeti>.of(mevcut);
  final sirali = [...yeniMesajlar]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  for (final m in sirali) {
    if (m.studentCloudId.isEmpty) continue;
    final anahtar = sohbetAnahtari(classCloudId, m.studentCloudId, m.parentUserId);
    final veliden = !m.isFromTeacher;
    final eski = sonuc[anahtar];
    final gorulen = sonGorulen[anahtar];

    var ozet = eski ??
        SohbetOzeti(
          classCloudId: classCloudId,
          studentCloudId: m.studentCloudId,
          parentUserId: m.parentUserId,
          studentName: '',
          parentName: '',
          sonMesaj: '',
          sonZaman: DateTime.fromMillisecondsSinceEpoch(0),
          sonYazanVeli: false,
          okunmamis: 0,
        );
    if (m.studentName.isNotEmpty) ozet = ozet.copyWith(studentName: m.studentName);
    if (veliden && m.authorName.isNotEmpty) ozet = ozet.copyWith(parentName: m.authorName);
    if (!m.createdAt.isBefore(ozet.sonZaman)) {
      ozet = ozet.copyWith(sonMesaj: m.body, sonZaman: m.createdAt, sonYazanVeli: veliden);
    }
    if (!veliden) {
      ozet = ozet.copyWith(okunmamis: 0);
    } else if (gorulen == null || m.createdAt.isAfter(gorulen)) {
      ozet = ozet.copyWith(okunmamis: ozet.okunmamis + 1);
    }
    sonuc[anahtar] = ozet;
  }
  return sonuc;
}

/// Gelen kutusunun cihazdaki kaydı (öğretmen hesabı başına ayrı).
///
/// Hesap başına TEK nesne: senkron ağdan dönmeyi beklerken öğretmen bir
/// sohbeti açıp kapatabilir. İki ayrı kopya olsaydı sonra kaydeden,
/// öbürünün "görüldü" işaretini ezer ve okunmamış sayısı geri gelirdi.
/// Kayıt diskten yalnız ilk kullanımda okunur.
class GelenKutusuDeposu {
  factory GelenKutusuDeposu(String uid) => _hesaplar.putIfAbsent(uid, () => GelenKutusuDeposu._(uid));

  GelenKutusuDeposu._(this.uid);

  static final _hesaplar = <String, GelenKutusuDeposu>{};

  /// Testler için: bir sonraki kullanımda kayıt diskten yeniden okunur.
  @visibleForTesting
  static void bellegiBosalt() => _hesaplar.clear();

  final String uid;

  String get _anahtar => 'gelen_kutusu_v1_$uid';

  Future<void>? _yukleme;

  Map<String, SohbetOzeti> sohbetler = {};

  /// Sınıf başına okuma imleci: bundan sonraki mesajlar okunur.
  Map<String, DateTime> senkron = {};
  Map<String, DateTime> gorulen = {};

  /// İmleçten sonraki, işlenmiş mesajlar (sınıf → mesaj kimliği → zamanı).
  /// Bir sonraki okumada yeniden gelirler; ikinci kez sayılmasınlar diye.
  Map<String, Map<String, DateTime>> islenen = {};
  List<KadroSinifi> kadroSiniflari = [];
  DateTime? kadroZamani;

  static Map<String, DateTime> _zamanlar(dynamic ham) {
    final sonuc = <String, DateTime>{};
    if (ham is Map) {
      ham.forEach((k, v) {
        final t = DateTime.tryParse('$v');
        if (t != null) sonuc['$k'] = t;
      });
    }
    return sonuc;
  }

  /// Kayıt diskten bir kez okunur; sonraki çağrılar aynı belleği kullanır.
  Future<void> yukle() => _yukleme ??= _oku();

  Future<void> _oku() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString(_anahtar);
      if (ham == null) return;
      final d = jsonDecode(ham) as Map<String, dynamic>;
      sohbetler = {};
      for (final m in (d['sohbetler'] as List? ?? const [])) {
        if (m is! Map<String, dynamic>) continue;
        final o = SohbetOzeti.fromMap(m);
        if (o != null) sohbetler[o.anahtar] = o;
      }
      senkron = _zamanlar(d['senkron']);
      gorulen = _zamanlar(d['gorulen']);
      islenen = {};
      final islenenHam = d['islenen'];
      if (islenenHam is Map) {
        islenenHam.forEach((c, m) => islenen['$c'] = _zamanlar(m));
      }
      kadroSiniflari = [
        for (final k in (d['kadro'] as List? ?? const []))
          if (k is Map)
            KadroSinifi(
              classCloudId: '${k['c'] ?? ''}',
              className: '${k['a'] ?? ''}',
              homeroomTeacherName: '${k['o'] ?? ''}',
              branch: '${k['b'] ?? ''}',
            ),
      ];
      kadroZamani = DateTime.tryParse('${d['kadroZamani'] ?? ''}');
    } catch (e) {
      // Bozuk kayıt: sıfırdan başlanır, bir sonraki senkron yeniden doldurur.
      debugPrint('Gelen kutusu kaydı okunamadı ($e)');
    }
  }

  Future<void> kaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _anahtar,
        jsonEncode({
          'sohbetler': [for (final o in sohbetler.values) o.toMap()],
          'senkron': senkron.map((k, v) => MapEntry(k, v.toIso8601String())),
          'gorulen': gorulen.map((k, v) => MapEntry(k, v.toIso8601String())),
          'islenen': islenen.map(
            (c, m) => MapEntry(c, m.map((id, t) => MapEntry(id, t.toIso8601String()))),
          ),
          'kadro': [
            for (final k in kadroSiniflari)
              {'c': k.classCloudId, 'a': k.className, 'o': k.homeroomTeacherName, 'b': k.branch},
          ],
          'kadroZamani': kadroZamani?.toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Gelen kutusu kaydedilemedi ($e)');
    }
  }

  /// Sohbet açıldı: okunmamış sıfırlanır.
  Future<void> gorulduIsaretle(String anahtar, {DateTime? an}) async {
    await yukle();
    gorulen[anahtar] = an ?? DateTime.now();
    final o = sohbetler[anahtar];
    if (o != null) sohbetler[anahtar] = o.copyWith(okunmamis: 0);
    await kaydet();
  }
}

/// Saat kayması payı.
///
/// Mesajın zamanı gönderen telefonun saatidir. Velinin saati biraz geride
/// olsa, öğretmenin son okumasından SONRA yazdığı mesajın zamanı öncesine
/// düşer ve "imleçten yeniler" sorgusu onu hiç getirmezdi. İmleç bu yüzden
/// okuma anından bu kadar geride tutulur; paydaki mesajlar bir sonraki
/// okumada yeniden gelir ve kimlikleriyle ayıklanır.
const gelenKutusuSaatPayi = Duration(minutes: 10);

/// Sınıf başına delta senkron. Hata alan sınıf atlanır, diğerleri sürer.
///
/// Döndürdüğü değer: en az bir sınıf okunamadıysa true (ekranda "bazı
/// sınıflar güncellenemedi" denir). [simdi] testler içindir.
Future<bool> gelenKutusunuEsitle({
  required GelenKutusuDeposu depo,
  required CloudCommunicationRepository bulut,
  required List<String> siniflar,
  DateTime? simdi,
}) async {
  final pay = (simdi ?? DateTime.now()).subtract(gelenKutusuSaatPayi);
  var eksik = false;
  for (final cls in siniflar) {
    try {
      final gelen = await bulut.fetchTeacherInbox(
        classCloudId: cls,
        teacherUid: depo.uid,
        since: depo.senkron[cls],
      );
      if (gelen.isEmpty) continue;
      final islenen = depo.islenen[cls] ?? const <String, DateTime>{};
      final yeni = [for (final m in gelen) if (!islenen.containsKey(m.id)) m];
      if (yeni.isNotEmpty) {
        depo.sohbetler = mesajlariIsle(
          mevcut: depo.sohbetler,
          classCloudId: cls,
          yeniMesajlar: yeni,
          sonGorulen: depo.gorulen,
        );
      }

      // İmleç: okunanların en yenisi, ama okuma anından en az pay kadar
      // geride. Saati ileride bir telefonun mesajı imleci ileri atıp
      // aradaki mesajları gizleyemez.
      final enYeni = gelen.map((m) => m.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      var imlec = enYeni.isBefore(pay) ? enYeni : pay;
      final eski = depo.senkron[cls];
      if (eski != null && eski.isAfter(imlec)) imlec = eski;
      depo.senkron[cls] = imlec;
      depo.islenen[cls] = {
        for (final e in islenen.entries)
          if (e.value.isAfter(imlec)) e.key: e.value,
        for (final m in gelen)
          if (m.createdAt.isAfter(imlec)) m.id: m.createdAt,
      };
    } catch (e) {
      eksik = true;
      debugPrint('Gelen kutusu: $cls okunamadı ($e)');
    }
  }
  await depo.kaydet();
  return eksik;
}

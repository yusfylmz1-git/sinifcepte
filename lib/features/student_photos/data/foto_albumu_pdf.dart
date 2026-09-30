import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/pdf/pdf_tr_fonts.dart';
import '../../../core/utils/turkish_text.dart';
import '../domain/disa_aktarim_plani.dart';

enum AlbumOlcegi { kucuk, normal, buyuk }

enum AlbumSirasi { numaraArtan, numaraAzalan, adSoyad, sinifListesi, cekimSirasi }

extension AlbumSirasiMetni on AlbumSirasi {
  String get metin => switch (this) {
        AlbumSirasi.numaraArtan => 'Okul numarası (artan)',
        AlbumSirasi.numaraAzalan => 'Okul numarası (azalan)',
        AlbumSirasi.adSoyad => 'Ad-soyad (alfabetik)',
        AlbumSirasi.sinifListesi => 'Sınıf listesindeki sıra',
        AlbumSirasi.cekimSirasi => 'Fotoğraf çekim sırası',
      };
}

/// Albüm seçenekleri (plan §12.1). Her bilgi alanı bağımsız.
class AlbumAyarlari {
  const AlbumAyarlari({
    this.sutun = 3,
    this.olcek = AlbumOlcegi.normal,
    this.sira = AlbumSirasi.numaraArtan,
    this.adSoyad = true,
    this.siraNo = false,
    this.okulNo = true,
    this.sinif = false,
    this.cekimTarihi = false,
    this.fotografsizlar = true,
    this.yatay = false,
  });

  final int sutun;
  final AlbumOlcegi olcek;
  final AlbumSirasi sira;
  final bool adSoyad;

  /// Albümdeki konum (1, 2, 3…) — okul numarası DEĞİL (plan §12.2).
  final bool siraNo;
  final bool okulNo;
  final bool sinif;
  final bool cekimTarihi;

  /// Fotoğrafı olmayan öğrenci "Fotoğraf yok" kartıyla gösterilsin mi?
  final bool fotografsizlar;
  final bool yatay;

  /// Hiç kimlik alanı yoksa belge yalnızca görsel albümdür; kontrol
  /// listesi ya da eşleştirme belgesi yerine geçmez.
  bool get kimliksiz => !adSoyad && !okulNo && !siraNo;

  int get _satirSayisi =>
      (adSoyad ? 2 : 0) + ((siraNo || okulNo) ? 1 : 0) + (sinif ? 1 : 0) + (cekimTarihi ? 1 : 0);

  AlbumAyarlari kopya({
    int? sutun,
    AlbumOlcegi? olcek,
    AlbumSirasi? sira,
    bool? adSoyad,
    bool? siraNo,
    bool? okulNo,
    bool? sinif,
    bool? cekimTarihi,
    bool? fotografsizlar,
    bool? yatay,
  }) =>
      AlbumAyarlari(
        sutun: sutun ?? this.sutun,
        olcek: olcek ?? this.olcek,
        sira: sira ?? this.sira,
        adSoyad: adSoyad ?? this.adSoyad,
        siraNo: siraNo ?? this.siraNo,
        okulNo: okulNo ?? this.okulNo,
        sinif: sinif ?? this.sinif,
        cekimTarihi: cekimTarihi ?? this.cekimTarihi,
        fotografsizlar: fotografsizlar ?? this.fotografsizlar,
        yatay: yatay ?? this.yatay,
      );
}

/// Sayfa yerleşimi — saf hesap; ayar ekranı özet satırını da bundan
/// yazar ("3 sütun · sayfada 12 öğrenci").
class AlbumYerlesimi {
  const AlbumYerlesimi({
    required this.kartGenislik,
    required this.fotoGenislik,
    required this.fotoYukseklik,
    required this.kartYukseklik,
    required this.sayfadaSatir,
    required this.olcek,
    required this.olcekDusuruldu,
  });

  final double kartGenislik;
  final double fotoGenislik;
  final double fotoYukseklik;
  final double kartYukseklik;
  final int sayfadaSatir;

  /// Gerçekte kullanılan ölçek.
  final AlbumOlcegi olcek;

  /// İstenen ölçek sayfaya sığmadı, güvenli ölçeğe inildi (plan §12.1:
  /// geçersiz kombinasyon sessizce taşmaz).
  final bool olcekDusuruldu;

  static const double kenar = 28;
  static const double aralik = 8;
  static const double baslik = 46;
  static const double altBilgi = 18;
  static const double satirYuksekligi = 11;

  static double _oran(AlbumOlcegi o) => switch (o) {
        AlbumOlcegi.kucuk => 0.55,
        AlbumOlcegi.normal => 0.75,
        AlbumOlcegi.buyuk => 0.95,
      };

  factory AlbumYerlesimi.hesapla(AlbumAyarlari a) {
    final sayfa = a.yatay ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final icG = sayfa.width - 2 * kenar;
    final icY = sayfa.height - 2 * kenar - baslik - altBilgi;
    final kartG = (icG - (a.sutun - 1) * aralik) / a.sutun;
    final yazi = a._satirSayisi * satirYuksekligi + 8;

    AlbumYerlesimi dene(AlbumOlcegi o) {
      final fg = kartG * _oran(o);
      final fy = fg * 171 / 133;
      final ky = fy + yazi + 8;
      return AlbumYerlesimi(
        kartGenislik: kartG,
        fotoGenislik: fg,
        fotoYukseklik: fy,
        kartYukseklik: ky,
        sayfadaSatir: ((icY + aralik) / (ky + aralik)).floor(),
        olcek: o,
        olcekDusuruldu: o != a.olcek,
      );
    }

    var y = dene(a.olcek);
    var i = a.olcek.index;
    while (y.sayfadaSatir < 1 && i > 0) {
      i--;
      y = dene(AlbumOlcegi.values[i]);
    }
    return y;
  }

  int sayfadaOgrenci(int sutun) => sayfadaSatir * sutun;
}

/// Albüm sırasına göre dizer. Sıra numarası bu sıradan üretilir.
List<AktarimKalemi> albumSirasi(List<AktarimKalemi> kalemler, AlbumSirasi s) {
  final l = [...kalemler];
  switch (s) {
    case AlbumSirasi.numaraArtan:
      l.sort((a, b) => a.ogrenci.schoolNumber.compareTo(b.ogrenci.schoolNumber));
    case AlbumSirasi.numaraAzalan:
      l.sort((a, b) => b.ogrenci.schoolNumber.compareTo(a.ogrenci.schoolNumber));
    case AlbumSirasi.adSoyad:
      l.sort((a, b) {
        final c = trKarsilastir(a.ogrenci.firstName, b.ogrenci.firstName);
        return c != 0 ? c : trKarsilastir(a.ogrenci.lastName, b.ogrenci.lastName);
      });
    case AlbumSirasi.sinifListesi:
      l.sort((a, b) => (a.ogrenci.id ?? 0).compareTo(b.ogrenci.id ?? 0));
    case AlbumSirasi.cekimSirasi:
      // Fotoğrafsızlar sonda, kendi aralarında numara sırasıyla.
      l.sort((a, b) {
        final fa = a.foto?.capturedAt, fb = b.foto?.capturedAt;
        if (fa == null && fb == null) {
          return a.ogrenci.schoolNumber.compareTo(b.ogrenci.schoolNumber);
        }
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fa.compareTo(fb);
      });
  }
  return l;
}

/// Sınıflara göre gruplar; plandaki sınıf sırası korunur.
List<(String sinif, String yil, List<AktarimKalemi>)> _siniflara(List<AktarimKalemi> kalemler) {
  final sira = <int>[];
  final grup = <int, List<AktarimKalemi>>{};
  for (final k in kalemler) {
    final id = k.sinif.id ?? 0;
    if (!grup.containsKey(id)) sira.add(id);
    grup.putIfAbsent(id, () => []).add(k);
  }
  return [
    for (final id in sira) (grup[id]!.first.sinif.name, grup[id]!.first.sinif.academicYear, grup[id]!),
  ];
}

/// Fotoğraf albümü PDF'i (plan §12). [fotoBaytlari] foto kimliğine göre
/// 133×171 JPEG'ler; çağıran okur ve özetini doğrular.
Future<Uint8List> albumPdfUret({
  required DisaAktarimPlani plan,
  required Map<String, Uint8List> fotoBaytlari,
  required AlbumAyarlari ayarlar,
  String? okulAdi,
}) async {
  final pdf = await PdfTrFonts.document();
  final yer = AlbumYerlesimi.hesapla(ayarlar);
  final sayfa = ayarlar.yatay ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
  final tarih = DateFormat('dd.MM.yyyy');

  final uygun = plan.kalemler.where((k) {
    final fotoVar = k.durum == AktarimDurumu.tamam && fotoBaytlari.containsKey(k.foto?.id);
    return fotoVar || ayarlar.fotografsizlar;
  }).toList();

  for (final (sinifAdi, yil, kalemler) in _siniflara(uygun)) {
    final sirali = albumSirasi(kalemler, ayarlar.sira);
    final kartlar = <pw.Widget>[];
    for (var i = 0; i < sirali.length; i++) {
      final k = sirali[i];
      final bayt = k.durum == AktarimDurumu.tamam ? fotoBaytlari[k.foto?.id] : null;
      final satirlar = <pw.Widget>[
        if (ayarlar.siraNo || ayarlar.okulNo)
          pw.Text(
            [if (ayarlar.siraNo) '${i + 1}.', if (ayarlar.okulNo) 'No: ${k.ogrenci.schoolNumber}'].join('  '),
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        if (ayarlar.adSoyad)
          pw.Text(k.adSoyad, maxLines: 2, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
        if (ayarlar.sinif) pw.Text(sinifAdi, style: const pw.TextStyle(fontSize: 7.5)),
        if (ayarlar.cekimTarihi && k.foto != null)
          pw.Text(tarih.format(k.foto!.capturedAt.toLocal()), style: const pw.TextStyle(fontSize: 7.5)),
      ];
      kartlar.add(pw.Container(
        width: yer.kartGenislik,
        height: yer.kartYukseklik,
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
        child: pw.Column(
          children: [
            pw.Container(
              width: yer.fotoGenislik,
              height: yer.fotoYukseklik,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
              child: bayt != null
                  // Oran korunur; ad fotoğrafın ÜSTÜNE yazılmaz.
                  ? pw.Image(pw.MemoryImage(bayt), fit: pw.BoxFit.contain)
                  : pw.Center(
                      child: pw.Text('Fotoğraf yok', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ),
            ),
            pw.SizedBox(height: 4),
            ...satirlar,
          ],
        ),
      ));
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: sayfa,
      margin: const pw.EdgeInsets.all(AlbumYerlesimi.kenar),
      header: (ctx) => pw.Container(
        height: AlbumYerlesimi.baslik,
        alignment: pw.Alignment.topLeft,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (okulAdi != null && okulAdi.trim().isNotEmpty)
              pw.Text(okulAdi, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('$sinifAdi · Fotoğraf albümü${yil.trim().isEmpty ? '' : ' · $yil'}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (ayarlar.kimliksiz)
              pw.Text('Yalnız görsel albüm — kimlik eşleştirme belgesi değildir.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700)),
          ],
        ),
      ),
      footer: (ctx) => pw.Container(
        height: AlbumYerlesimi.altBilgi,
        alignment: pw.Alignment.bottomRight,
        child: pw.Text('$sinifAdi · Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        pw.Wrap(spacing: AlbumYerlesimi.aralik, runSpacing: AlbumYerlesimi.aralik, children: kartlar),
      ],
    ));
  }
  if (uygun.isEmpty) {
    pdf.addPage(pw.Page(
      pageFormat: sayfa,
      build: (_) => pw.Center(child: pw.Text('Albüme girecek öğrenci yok.')),
    ));
  }
  return PdfTrFonts.kaydet(pdf);
}

/// Fotoğraflı eşleştirme kontrol listesi (plan §10.1): fotoğraf + sınıf
/// + okul numarası + ad-soyad + üretilecek dosya adı + durum. Pakete
/// girmeyen öğrenciler de durumlarıyla listede.
Future<Uint8List> kontrolListesiPdfUret({
  required DisaAktarimPlani plan,
  required Map<String, Uint8List> fotoBaytlari,
  required DateTime zaman,
}) async {
  final pdf = await PdfTrFonts.document();
  const fotoG = 30.0;
  const fotoY = fotoG * 171 / 133;
  final baslikStil = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
  const hucreStil = pw.TextStyle(fontSize: 8);

  pw.Widget hucre(String s, {pw.TextStyle stil = hucreStil}) =>
      pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(s, style: stil));

  for (final (sinifAdi, _, kalemler) in _siniflara(plan.kalemler)) {
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('e-Okul fotoğraf eşleştirme kontrol listesi · $sinifAdi',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${DateFormat('dd.MM.yyyy HH:mm').format(zaman)} · '
              '${kalemler.where((k) => k.durum == AktarimDurumu.tamam).length}/${kalemler.length} fotoğraf pakette',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.bottomRight,
        child: pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(fotoG + 6),
            1: pw.FixedColumnWidth(38),
            2: pw.FlexColumnWidth(3),
            3: pw.FlexColumnWidth(4),
            4: pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                hucre('Foto', stil: baslikStil),
                hucre('No', stil: baslikStil),
                hucre('Ad Soyad', stil: baslikStil),
                hucre('Dosya adı', stil: baslikStil),
                hucre('Durum', stil: baslikStil),
              ],
            ),
            for (final k in kalemler)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.SizedBox(
                      width: fotoG,
                      height: fotoY,
                      child: fotoBaytlari[k.foto?.id] != null
                          ? pw.Image(pw.MemoryImage(fotoBaytlari[k.foto!.id]!), fit: pw.BoxFit.contain)
                          : pw.Center(child: pw.Text('—', style: hucreStil)),
                    ),
                  ),
                  hucre('${k.ogrenci.schoolNumber}'),
                  hucre(k.adSoyad),
                  hucre(k.durum == AktarimDurumu.tamam ? k.paketYolu : '—'),
                  hucre(k.durum.metin,
                      stil: k.durum == AktarimDurumu.tamam
                          ? hucreStil
                          : pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                ],
              ),
          ],
        ),
      ],
    ));
  }
  return PdfTrFonts.kaydet(pdf);
}

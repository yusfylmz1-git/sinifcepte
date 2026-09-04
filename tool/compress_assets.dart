// Varlık sıkıştırma aracı.
//
// Flutter, `assets/` altındaki dosyaları APK'ya **sıkıştırmadan** koyar.
// Müfredat ve okul verisi saf JSON olduğu için çok iyi sıkışıyor:
//
//   official_maarif_kazanimlar.json : 23.9 MB -> 1.6 MB
//   assets/data/schools/*           : 10.6 MB -> 1.0 MB
//
// Yayın APK'sı 83.8 MB idi; mobil veriyle indirecek öğretmen için bu
// gerçek bir engel.
//
// Kullanım (derlemeden önce):
//   dart run tool/compress_assets.dart
//
// Üretilen `.gz` dosyaları `GzipAsset.loadString` tarafından okunur;
// bulunamazsa düz dosyaya geri düşülür.

import 'dart:convert';
import 'dart:io';

/// Sıkıştırılacak dosyalar. Küçük dosyalar listeye alınmadı: gzip
/// başlığı yüzünden birkaç yüz baytlık dosyalar büyüyebilir.
const List<String> _hedefler = [
  'assets/data/official_maarif_kazanimlar.json',
];

/// Bu klasördeki tüm `.json` dosyaları sıkıştırılır.
const List<String> _klasorler = [
  'assets/data/schools',
];

Future<void> main() async {
  var toplamHam = 0;
  var toplamGz = 0;

  final dosyalar = <File>[
    ..._hedefler.map(File.new).where((f) => f.existsSync()),
    for (final klasor in _klasorler)
      if (Directory(klasor).existsSync())
        ...Directory(klasor)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json')),
  ];

  if (dosyalar.isEmpty) {
    stdout.writeln('Sıkıştırılacak dosya bulunamadı.');
    return;
  }

  for (final dosya in dosyalar) {
    final ham = dosya.readAsBytesSync();

    // Önce JSON'u en aza indir (girinti ve boşluklar atılır), sonra
    // sıkıştır. Yalnızca sıkıştırmaya göre birkaç yüz KB daha kazandırır.
    List<int> icerik;
    try {
      final decoded = jsonDecode(utf8.decode(ham));
      icerik = utf8.encode(jsonEncode(decoded));
    } catch (_) {
      // Geçerli JSON değilse olduğu gibi sıkıştır.
      icerik = ham;
    }

    final gz = GZipCodec(level: 9).encode(icerik);
    File('${dosya.path}.gz').writeAsBytesSync(gz);

    toplamHam += ham.length;
    toplamGz += gz.length;

    stdout.writeln(
      '${dosya.path.padRight(52)} '
      '${_mb(ham.length)} -> ${_mb(gz.length)}',
    );
  }

  stdout.writeln('');
  stdout.writeln('TOPLAM: ${_mb(toplamHam)} -> ${_mb(toplamGz)} '
      '(kazanç ${_mb(toplamHam - toplamGz)})');
}

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

import '../../../core/utils/turkish_text.dart';

/// Ders programındaki ders adını kazanım veritabanındaki derse çevirir.
///
/// ## Neden gerekli
/// Ana sayfadaki "Günün dersleri"nde derse dokununca kazanımlar açılıyordu
/// ama ders KODU yerine ders ADI gönderiliyordu (`TURKCE` yerine `Türkçe`).
/// Sorgu kodla tam eşleşme aradığı için hiçbir kazanım gelmiyor, listede
/// yalnızca her derse eklenen "40. hafta: Yaz Tatili" kartı kalıyor ve o
/// açılıyordu (kullanıcı bildirimi, 9 Ekim 2026).
///
/// Sıra:
/// 1. Ad ya da kod birebir (Türkçe harf duyarsız).
/// 2. Biri ötekiyle başlıyor: "Fen" → "Fen Bilimleri", "Bilişim
///    Teknolojileri" → "Bilişim Teknolojileri ve Yazılım".
///
/// Aynı adda birden çok kayıt varsa (lise türüne göre yayınevi alanı dolu
/// olanlar) genel olan (yayınevi boş) seçilir; o da yoksa listedeki ilki
/// (liste temel dersler önce sıralı geliyor). Bulunamazsa `null`: çağıran
/// taraf ders seçimini öğretmene bırakır, boş bir liste açmaz.
Map<String, dynamic>? kazanimDersiBul(
  List<Map<String, dynamic>> dersler,
  String dersAdi,
) {
  final aranan = trFold(dersAdi).trim();
  if (aranan.isEmpty) return null;

  String ad(Map<String, dynamic> m) => trFold('${m['subject_name'] ?? ''}').trim();
  String kod(Map<String, dynamic> m) => trFold('${m['subject_code'] ?? ''}').trim();
  bool genel(Map<String, dynamic> m) => '${m['publisher'] ?? ''}'.trim().isEmpty;

  Map<String, dynamic>? enIyi(List<Map<String, dynamic>> adaylar) {
    if (adaylar.isEmpty) return null;
    return adaylar.firstWhere(genel, orElse: () => adaylar.first);
  }

  final birebir = dersler.where((m) => ad(m) == aranan || kod(m) == aranan).toList();
  if (birebir.isNotEmpty) return enIyi(birebir);

  final kismi = dersler.where((m) {
    final a = ad(m);
    return a.isNotEmpty && (a.startsWith(aranan) || aranan.startsWith(a));
  }).toList();
  if (kismi.isEmpty) return null;
  // En yakın ad: uzunluk farkı en az olan ("Matematik" ararken
  // "Matematik Uygulamaları" değil "Matematik").
  final enYakin = kismi
      .map((m) => (ad(m).length - aranan.length).abs())
      .reduce((a, b) => a < b ? a : b);
  return enIyi(kismi.where((m) => (ad(m).length - aranan.length).abs() == enYakin).toList());
}

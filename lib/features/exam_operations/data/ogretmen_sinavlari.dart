/// Sınav öğretmeni ilgilendiriyor mu?
///
/// ## Neden telefonda da süzülüyor (DEG-11, 29 Ekim 2026)
/// Buluttaki sınav listesi bir dönem ÖSYM takviminin TAMAMIYLA yayımlandı:
/// 87 sınav; TUS, DUS, EUS, Sayıştay, HMGS, GUY… Kullanıcı: "Sınavlarda hâlâ
/// diş, Sayıştay, eczacılık, tıp gibi sınavlar var; yalnız öğretmenleri
/// ilgilendiren sınavlar olmalı." Sunucudaki ayrıştırıcı
/// (`functions/osym_parser.js`) bugün süzüyor, ama telefonda kalan eski
/// kayıtlar ve ileride yine süzülmeden yayımlanabilecek bir liste için
/// telefon da aynı süzgeci uygular.
///
/// Liste sunucudakiyle AYNI olmalı (`OGRETMEN_SINAVLARI`):
///   1. Öğretmenin girdiği    — AGS, EKYS, ALES, YDS, e-YDS, YÖKDİL
///   2. Öğrencisinin girdiği  — YKS, MSÜ, TR-YÖS, DGS
///   3. Görev aldığı          — KPSS, EKPSS
///
/// Yalnız ÖSYM sınavları süzülür. MEB sınavları (ortak yazılı, LGS, BİLSEM,
/// MTSK, AÖF görevleri) elle seçilmiş listedir.
library;

/// Sınav adının BAŞINDA aranan kısaltma. Arkasından harf gelmemeli:
/// "YDS" eşleşir, "YDUS" ve "e-YDTS" eşleşmez. Adın başındaki "MEB-" ya da
/// "MEB " atlanır ("MEB-AGS", "MEB EKYS").
final RegExp _ogretmenSinavi = RegExp(
  r'^(?:MEB[-\s]+)?(?:e-YDS|EKPSS|KPSS|ALES|YDS|YÖKDİL|YKS|MSÜ|TR-YÖS|DGS|AGS|EKYS)(?![\p{L}\p{N}])',
  unicode: true,
);

bool ogretmeniIlgilendirir({required String ad, required String kurum}) {
  // denetim: turkce-buyuk — ASCII 'OSYM' yazımı aranıyor
  final osym = kurum.contains('ÖSYM') || kurum.toUpperCase().contains('OSYM');
  if (!osym) return true;
  return _ogretmenSinavi.hasMatch(ad.trim());
}

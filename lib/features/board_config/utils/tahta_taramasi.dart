import '../data/ogretmen_tahta_deposu.dart';
import 'tahta_totp.dart';

/// "Tahtadaki QR'ı Okut" ile okunan karekod ne?
///
/// ## Neden var
///
/// Öğretmen Ana Program'ın gösterdiği TANIMLAMA karekodunu bu düğmeyle
/// okutunca "Bu QR bir SınıfCepte tahtasına ait değil" görüyordu (1 Ekim
/// 2026, cihazda). Mesaj doğruydu ama yol göstermiyordu. `SCT1` öneki
/// tam bu ayrımı yapabilmek için tahtanın `SC1`'inden farklı seçilmişti;
/// ekran onu kullanmıyordu.
enum TahtaTaramasi {
  /// Tahtanın kilit ekranındaki karekod (`SC1` / `SC2`).
  tahta,

  /// Telefonda kaydı olmayan bir okulun tanımlama karekodu: eklenir.
  kurulumEkle,

  /// Kayıtlı bir okulun FARKLI tanımı (secret yenilendi, öğretmen
  /// yeniden eklendi): o okulun kaydının yerine geçmesi sorulur.
  kurulumYenile,

  /// Telefonda zaten kayıtlı tanımın karekodu.
  kurulumAyni,

  /// İkisi de değil.
  tanimsiz,
}

TahtaTaramasi tahtaTaramasiniYorumla(
  String ham,
  List<OgretmenTahtaKaydi> kayitlar,
) {
  if (TahtaTotp.qrAyristir(ham) != null) return TahtaTaramasi.tahta;

  final kurulum = OgretmenTahtaDeposu.qrAyristir(ham);
  if (kurulum == null) return TahtaTaramasi.tanimsiz;

  final mevcut = okulKaydi(kayitlar, kurulum.okulId);
  if (mevcut == null) return TahtaTaramasi.kurulumEkle;

  // Aynılık secret'la birlikte: aynı kodla YENİDEN üretilmiş bir tanım
  // (idare secret'ı yeniledi) farklı sayılmalı, yoksa telefon eski
  // secret'la kod üretmeye devam ederdi.
  if (kurulum.kod == mevcut.kod && kurulum.totpSecret == mevcut.totpSecret) {
    return TahtaTaramasi.kurulumAyni;
  }
  return TahtaTaramasi.kurulumYenile;
}

/// Kayıtlar arasında [okulId]'nin kaydı; yoksa `null`.
OgretmenTahtaKaydi? okulKaydi(List<OgretmenTahtaKaydi> kayitlar, String okulId) {
  for (final k in kayitlar) {
    if (k.okulId == okulId) return k;
  }
  return null;
}

/// Tahtanın karekodunu okutunca kullanılacak kayıt: tahtanın okuluna ait
/// olan. Okullar karekoddaki kimlikle ayrılıyor; öğretmen seçmiyor.
OgretmenTahtaKaydi? tahtaIcinKayit(
  TahtaQrYuku yuk,
  List<OgretmenTahtaKaydi> kayitlar,
) {
  for (final k in kayitlar) {
    if (yuk.ayniOkul(k.okulId)) return k;
  }
  return null;
}

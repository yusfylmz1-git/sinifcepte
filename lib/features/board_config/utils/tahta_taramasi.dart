import '../data/ogretmen_tahta_deposu.dart';
import 'tahta_totp.dart';

/// "Tahtadaki QR'ı Okut" ile okunan karekod ne?
///
/// ## Neden var
///
/// Öğretmen Ana Program'ın gösterdiği TANIMLAMA karekodunu bu düğmeyle
/// okutunca "Bu QR bir SınıfCepte tahtasına ait değil" görüyordu (1 Ekim
/// 2026, cihazda). Mesaj doğruydu ama yol göstermiyordu: telefon zaten
/// tanımlıyken tanımlama düğmesi ekranda hiç yok. `SCT1` öneki tam bu
/// ayrımı yapabilmek için tahtanın `SC1`'inden farklı seçilmişti; ekran
/// onu kullanmıyordu.
enum TahtaTaramasi {
  /// Tahtanın kilit ekranındaki karekod (`SC1` / `SC2`).
  tahta,

  /// Telefondakinden farklı bir tanımlama karekodu (`SCT1`).
  kurulumYeni,

  /// Telefonda zaten kayıtlı tanımın karekodu.
  kurulumAyni,

  /// İkisi de değil.
  tanimsiz,
}

TahtaTaramasi tahtaTaramasiniYorumla(String ham, OgretmenTahtaKaydi? mevcut) {
  if (TahtaTotp.qrAyristir(ham) != null) return TahtaTaramasi.tahta;

  final kurulum = OgretmenTahtaDeposu.qrAyristir(ham);
  if (kurulum == null) return TahtaTaramasi.tanimsiz;

  // Aynılık secret'la birlikte: aynı kodla YENİDEN üretilmiş bir tanım
  // (idare secret'ı yeniledi) farklı sayılmalı, yoksa telefon eski
  // secret'la kod üretmeye devam ederdi.
  if (mevcut != null &&
      kurulum.okulId == mevcut.okulId &&
      kurulum.kod == mevcut.kod &&
      kurulum.totpSecret == mevcut.totpSecret) {
    return TahtaTaramasi.kurulumAyni;
  }
  return TahtaTaramasi.kurulumYeni;
}

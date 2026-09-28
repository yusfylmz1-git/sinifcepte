/// Tahta kilidi özelliklerinin açık/kapalı ayarları.
library;

/// Telefondan tahta YÖNETİMİ — şimdilik KAPALI (28 Eylül 2026, kullanıcı
/// kararı).
///
/// Kapsadığı üç şey:
/// - Okul yöneticisinin "Tahta Yönetimi" ekranı (öğretmen ekleme,
///   yapılandırma üretme, nöbet/duyuru)
/// - Öğretmenin "Tahta yetkisi iste" düğmesi (yöneticinin telefondan
///   onaylamasına dayanıyor)
/// - Tahta Kilidi ekranının açılışta buluttaki yetki kaydıyla eşitlemesi
///
/// ## Neden
///
/// Okulun tek yayıncısı artık SınıfCepte Ana Program (masaüstü). Telefon
/// ile Ana Program AYRI öğretmen listeleri tutuyordu; tahta en son hangisi
/// yayımladıysa onun listesini kullanıyordu. Okul ikisini birden
/// kullanırsa bir taraftan eklenen öğretmen diğer taraf yayımlayınca
/// tahtadan düşüyordu.
///
/// Eşitleme de bu yüzden kapalı: açık kalsaydı, daha önce telefondan
/// istek göndermiş bir öğretmenin Ana Program'dan aldığı anahtarı ekran
/// her açılışta silinir (istek beklemede/reddedildi) ya da buluttakiyle
/// değiştirilirdi (istek onaylı) — öğretmen tahtayı açamazdı.
///
/// Öğretmen tarafı çalışmaya devam ediyor: "Kurulum QR'ını Okut" (Ana
/// Program'ın karekodu) ve "Tahtadaki QR'ı Okut" (kilit açma).
///
/// Kod silinmedi; `true` yapmak telefon yönetimini geri açar.
const bool telefonTahtaYonetimiAktif = false;

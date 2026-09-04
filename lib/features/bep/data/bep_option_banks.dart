/// BEP tablosunun seçimle doldurulan sütunları.
///
/// ## Neden banka
/// Resmî BEP tablosunda "Yöntem ve Teknik", "Kullanılacak Materyaller"
/// ve "Ölçme-Değerlendirme" sütunları virgülle ayrılmış üç-dört ifade
/// taşır. Bu alanlar serbest metin bırakılırsa:
///   * telefon klavyesinde her satır için yazmak angarya olur,
///   * her öğretmen farklı yazar, belge kurumsal görünmez,
///   * imla hataları resmî belgeye girer.
///
/// Öğretmen listeden işaretler; listede yoksa kendi ifadesini yazar.
///
/// ## Neden sabit metin yetmezdi
/// Bu üç sütun PDF'te vardı ama veri modelinde alan yoktu: her satıra
/// aynı sabit metin basılıyordu. Bilişim dersi için yazılmış "Akıllı
/// Tahta, Projeksiyon" listesi öz bakım BEP'inde de aynen çıkıyordu.
library;

/// MEB öğretim yöntem ve teknikleri.
///
/// Özel eğitimde sık kullanılan yöntemler (eşzamanlı ipucu, sabit
/// bekleme süreli öğretim, basamaklandırma) listede ayrıca yer alır;
/// genel ders yöntemleri BEP'te tek başına yetmez.
const List<String> bepYontemBankasi = [
  'Anlatım Yöntemi',
  'Soru-Cevap Tekniği',
  'Gösterip Yaptırma',
  'Doğrudan Öğretim Yöntemi',
  'Basamaklandırılmış Öğretim',
  'Eşzamanlı İpucuyla Öğretim',
  'Sabit Bekleme Süreli Öğretim',
  'Video ile Model Olma',
  'Akran Desteğiyle Öğretim',
  'Bilgisayar Destekli Öğretim',
  'Görsel Destekli Öğretim',
  'Oyunla Öğretim',
  'Drama / Rol Yapma',
  'Örnek Olay Yöntemi',
  'Problem Çözme Yöntemi',
  'İşbirlikli Öğrenme',
  'Bireysel Çalışma',
  'Uygulama ve Alıştırma',
];

/// Sınıfta fiilen bulunan araç gereç.
const List<String> bepMateryalBankasi = [
  'Akıllı Tahta',
  'Bilgisayar',
  'Projeksiyon',
  'Tablet',
  'Ders Kitabı',
  'Çalışma Yaprağı',
  'Etkinlik Kartları',
  'Görsel / Resimli Kartlar',
  'Video ve Animasyon',
  'Ses Kaydı',
  'Somut Nesneler',
  'Sayma Çubukları / Sayı Boncuğu',
  'Kesir Takımı',
  'Geometrik Cisimler',
  'Harf ve Hece Kartları',
  'Hikâye Kitabı',
  'Kavram Haritası',
  'Pekiştireç Tablosu',
  'Yazılım ve Uygulama Dosyaları',
];

/// Ölçme-değerlendirme araçları.
///
/// "Ölçüt Bağımlı Ölçü Aracı" BEP'in asıl ölçme aracıdır; klasik
/// sınav türleri kaynaştırma öğrencisinde tek başına yetersiz kalır.
const List<String> bepOlcmeBankasi = [
  'Ölçüt Bağımlı Ölçü Aracı',
  'Gözlem Formu',
  'Kontrol Listesi',
  'Dereceli Puanlama Anahtarı (Rubrik)',
  'Kısa Cevaplı Sınav',
  'Çoktan Seçmeli Sınav',
  'Doğru-Yanlış Testi',
  'Eşleştirme Testi',
  'Boşluk Doldurma',
  'Sözlü Sınav',
  'Uygulamalı Sınav',
  'Performans Görevi',
  'Proje Görevi',
  'Portfolyo / Ürün Dosyası',
  'Öz Değerlendirme Formu',
];

/// Ölçüt seçenekleri.
///
/// Kısa dönemli amacın ölçülebilir olması için ölçüt şart; serbest
/// metinde öğretmenler bu parçayı en çok unutan alan olarak bırakıyor.
const List<String> bepOlcutBankasi = [
  '4/5 (%80)',
  '3/4 (%75)',
  '5/5 (%100)',
  '2/3 (%67)',
  '7/10 (%70)',
  '8/10 (%80)',
  '9/10 (%90)',
  'Bağımsız olarak',
  'Sözel yönergeyle',
  'Model olunarak',
  'Fiziksel yardımla',
];

/// Eğitim ortamı düzenlemeleri — planın alt bloğu.
const List<String> bepFizikselBankasi = [
  'Öğretmene yakın oturtma',
  'Ön sırada oturtma',
  'Dikkat dağıtıcı uyaranların azaltılması',
  'Işık ve ses düzeninin ayarlanması',
  'Bireysel çalışma köşesi',
  'Uygun yükseklikte sıra ve masa',
  'Sınıf içi dolaşım alanının genişletilmesi',
  'Sınavda ek süre tanınması',
];

const List<String> bepSosyalBankasi = [
  'Akran desteği eşleştirmesi',
  'Küçük grupla çalışma',
  'Olumlu davranış pekiştirme',
  'Sınıf içi görev verme',
  'Sosyal beceri modellemesi',
  'Yönergelerin sadeleştirilmesi',
  'Sık ve anında geri bildirim',
];

const List<String> bepDijitalBankasi = [
  'Etkileşimli tahta uygulamaları',
  'EBA içerikleri',
  'Eğitim yazılımları',
  'Video destekli anlatım',
  'Sesli kitap / metin okuyucu',
  'Yazı büyütme ve büyüteç',
  'Konuşma sentezleyici',
];

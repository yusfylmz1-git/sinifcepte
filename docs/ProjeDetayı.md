PROJE İSMİ: SınıfCepte - Öğretmen Asistanı, Veli Portalı & Yönetim Sistemi

GENEL MİMARİ VE KURALLAR:
Proje Flutter/Dart diliyle Clean Architecture ve Provider/Riverpod durum yönetimi mimarisine uygun olarak geliştirilecektir. Bütün ekranlarda keyboard overflow problemlerini engelleyen responsive (isScrollControlled, viewInsets padding) yapılar kullanılacaktır. Tüm input alanlarında kullanıcı hatalarını önleyen InputSanitizer ve Regex doğrulayıcılar aktif olacaktır.

MODÜLLER VE DETAYLI İŞLEVLERİ:

1. KAZANIMLAR MODÜLÜ:
- 1-12 arası sınıflar ve ilişkili branşlar listelenir.
- 37 haftalık Carousel/PageView kart yapısı bulunur.
- Admin panelinde tanımlanan Eğitim-Öğretim yılı takvimine göre kartların altında otomatik tarihler görünür.
- Uygulama açıldığında o günkü tarihe denk gelen aktif haftanın kartına otomatik odaklanır.
- Tatil/Bayram günleri için özel tasarlanmış Tatil Kartları görüntülenir. Sınıf ve ders bazlı favorileme sistemi bulunur.

2. SINIFLAR & ÖĞRENCİLER MODÜLÜ:
- Sınıflar kademelerine göre gruplanır (5. Sınıflar, 6. Sınıflar vb.).
- Sınıf ekleme modalında "5a", "beşa" gibi hatalı girdiler otomatik temizlenerek "5-A" formatına sanitization uygulanır.
- Öğrenci ekleme: Elle ekleme, Excel (.xlsx) import ve e-Okul PDF parser seçenekleri sunulur.
- Yüklenen veriler için kayıt öncesi "Veri Önizleme ve Düzenleme Tablosu" açılır.
- Öğrenci profil fotoğrafları olmadığında cinsiyete göre pembe (kız) veya mavi (erkek) varsayılan avatarlar gösterilir.
- Mükerrer okul numarası kontrolü yapılır.
- Arama çubuğu, Numaraya/İsme göre sıralama toggle'ı ve Toplu Taşıma/Silme (Çoklu Seçim) modu içerir.

3. DERS PROGRAMI MODÜLÜ:
- Günlük ders saatleri, ilk ders saati, teneffüs süresi ve öğle arası tanımlanabilen dinamik program ayarları ekranı bulunur.
- Teneffüs ve ders saatleri çakışmasız otomatik hesaplanır.
- Günlük akışta boş kalan ders saatleri için transparan "+ Ders Ekle" kartları gösterilir.
- Aynı gün ve saate iki farklı sınıf atanmasını engelleyen "Anlık Çakışma Uyarısı" vardır.
- Ana sayfada o anki aktif dersi yeşil etiketle, teneffüs ise son dakikalar sayacıyla gösteren Canlı Durum Kartı yer alır.
- Ders başlamadan 5 dakika önce Anlık Zille Hatırlatma Bildirimi gönderir.

4. DERS İÇİ KATILIM & DAVRANIŞ MODÜLÜ:
- Ders programı entegrasyonu sayesinde girildiğinde o anki aktif sınıfı varsayılan olarak açar.
- Varsayılan olarak tüm öğrenciler "İyi/Nötr" başlar; sadece durumu farklı olanlara 1 tık (Olumlu), 2 tık (Geliştirilmeli) veya uzun basma (Ödev, Defter vb. etiketler) uygulanır.
- Tek tıkla "Tüm Sınıf Katıldı" onay butonu bulunur.
- Otomatik Akıllı WhatsApp Şablon Motoru: Dersteki verilere göre 3 farklı senaryoda (Tüm sınıf başarılıysa övgü, 1-4 kişi öne çıktıysa isimleri, 5+ kişi öne çıktıysa sayısal özet) otomatik WhatsApp özet metni üretir ve kopyalatır/paylaştırır.

5. SINAV İŞLEMLERİ MODÜLÜ (4 SAYFA):
A) MEB/ÖSYM Sınav Takibi: Admin panelinden beslenen resmî sınavlar listelenir. Favoriye alınan sınavların son başvuru tarihinden önce bildirim atılır ve ana sayfada son 24 saat uyarısı çıkarılır. Öğretmen "📌 Okulum" etiketiyle kendi yazılılarını ekleyebilir.
B) Quiz & Sözlü Takip: Sınıf ve ders seçilerek Excel benzeri dinamik tablo üretilir. Sabit sol öğrenci sütunu, eklenebilir Quiz/Sözlü/Dinleme sütunları ve en altta canlı Sınıf Ortalaması satırı yer alır.
C) Proje & Ödev Takip: MEB uyumlu Rubric (Ölçekli) değerlendirme yapısı. Hazır MEB 100 puanlık şablonu yükleme seçeneği, kriter bazlı puanlama, hızlı max puanlama butonu ve tüm sınıf için Toplu PDF Ölçek Çıktısı.
D) Sınav Analizi: Klasik ve Soru Bazlı analiz seçenekleri. Soru bazlı modda soru puanları toplamı 100 olmak zorundadır. "⚡ Hızlı Giriş Modal'ı" ile notlar arasına BOŞLUK (Space) bırakılarak soru puanları sırayla dağıtılır. Kırmızı hataları önleyici input kısıtlamaları ve Millî Eğitim Formatında Otomatik PDF Sınav Analiz Raporu çıktısı sunar.

6. EVRAKLARIM MODÜLÜ:
- Öğretmenin kendi profiline bir kez girdiği Ad-Soyad, Branş, Okul Adı, Okul Müdürü Adı bilgileri tüm resmi evraklara otomatik basılır.
- Maarif Evrakları, Planlar ve Resmî Tutanaklar kategorize edilmiştir.
- Sınıf seçildiğinde resmi formattaki Zümre, Veli Toplantısı veya BEP planı şablonları otomatik dolar, canlı PDF önizlemesi ve çıktısı alınabilir.
- Geçmiş evraklar kopyalanıp yeni tarihlerle 5 saniyede yenilenebilir.

7. ANALİZ & RAPOR MODÜLÜ:
- Akıllı e-Okul Karne Görüşü Oluşturucu: Öğrencinin katılım ve sınav verilerini analiz ederek kişiselleştirilmiş karne görüşü metni üretir ve tek tıkla kopyalatır.
- Ders içi katılım grafikleri, sınav karşılaştırma analizleri, zorlanılan kazanımların tespiti.
- Resmi ŞÖK Raporu PDF'i ve Bireysel Öğrenci Gelişim Karnesi PDF çıktısı.

8. SINIF REHBER ÖĞRETMENLİĞİ & VELİ PORTALI (YENİ):
- Öğretmen sorumlu olduğu sınıf için benzersiz "Öğrenci Referans Kodları" üretir. Toplu davet mektubu çıkarabilir.
- Veli Uygulaması (`SınıfCepte Veli`): Veli bu kodla giriş yaparak öğrencisini bağlar.
- Veli Ekranı: Çocuğunun günlük ders programını, canlı dersteki katılım/yıldız durumunu, quiz/sınav notlarını, proje detaylarını ve sınıf duyurularını anlık takip eder.
- İletişim Güvenliği: Öğretmenin rahatsız edilmesini engellemek için tek yönlü duyuru ve randevulu veli görüşme sistemi esastır.

9. SÜPER-ADMIN PANELİ (WEB / DESKTOP):
- İl/İlçe bazlı öğretmen katılım ısı haritası, kayıtlı okullar ve aktif kullanıcı istatistikleri.
- MEB resmî sınav tarihlerini ve Eğitim-Öğretim yılı takvimini canlı yönetme.
- Kullanıcı yetkilendirme, engelleme ve detay inceleme.
- Destek & Yardım talepleri (Ticket) yönetimi ve yanıtlanması.
- Segmentasyonlu Toplu Push Notification gönderici.
- Bakım Modı (Maintenance Mode) ve Zorunlu Versiyon Güncelleme (Force Update) kontrolü.
- Hata & Çökme Logları (Crash Report Viewer) ve Sistem Audit Kayıtları.
# SınıfCepte — Codex/Astra Kod İnceleme Raporu

**İnceleme tarihi:** 17 Eylül 2026  
**Kapsam:** Flutter/Dart istemci, Firebase/Firestore kuralları, Cloud Functions, yönetim paneli, Android/iOS yapılandırması ve testler  
**Yöntem:** Salt okunur statik inceleme, hedefli veri/yetki akışı analizi ve dosya yazmayan testler  
**Değişiklik durumu:** İnceleme sırasında kaynak kod değiştirilmedi; çalışma ağacı temiz kaldı.

## Yönetici özeti

Mevcut haliyle özellikle veli portalı ve Firestore kuralları üretime hazır görünmüyor. İki kritik yetki açığı, meşru veli bağlantısını engelleyen sözleşme uyuşmazlıkları ve birden fazla P1 işlev hatası tespit edildi.

En önemli riskler:

- Başka bir öğrencinin özel iletişim ve durum verilerine erişim kazanılabilmesi.
- Başka bir sınıfın duyurularına sahte erişim kaydıyla ulaşılabilmesi.
- Meşru veli–öğrenci bağlantısının mevcut Firestore kurallarıyla tamamlanamaması.
- Düşük entropili referans kodlarının taranabilmesi ve öğrenci numarasının token yanıtından öğrenilebilmesi.
- Öğrenci silme, mezuniyet veya nakil sonrasında veli erişiminin bulutta açık kalabilmesi.
- Yönetim panelinin canlı Remote Config sürümlerini ve diğer sistem ayarlarını geriye çekebilmesi.
- Yönetim panelinde kalıcı XSS riski.
- Android bildirimleri ve iOS kamera akışında eksik native yapılandırma.

## Kritik bulgular

### 1. Başka öğrencinin özel verilerine erişim kazanılabiliyor

**Kaynaklar:**

- `firestore.rules:68-71`
- `firestore.rules:240-246`
- `firestore.rules:392, 424, 476`

`parent_links` oluşturulurken belge kimliğinin içerideki `studentCloudId` ile kanonik olarak eşleşmesi zorunlu tutulmuyor. Belge kimliği yalnız çağıranın UID önekiyle denetleniyor. `parentHasStudent` ise bağlantı belgesinin içeriğini değil, yalnız beklenen yolda bir belgenin varlığını kontrol ediyor.

Bu nedenle oturum açmış kötü niyetli bir kullanıcı, hedef öğrenci kimliğini belge yolunda; kendi kontrolündeki öğrenci ve token bilgilerini belge içeriğinde kullanarak sahte bir bağlantı oluşturabilir. Sonraki yetki kontrolleri belge varlığına baktığı için hedef öğrencinin mesajları, randevuları ve sağlık/durum bildirimleri okunabilir; sahte içerik de gönderilebilir.

**Etki:** Öğrenci ve veli mahremiyetinin ihlali, sahte mesaj/randevu/durum kaydı oluşturulması.

**Öneri:**

- Belge kimliğini `parentUid + '_' + studentCloudId` biçimiyle kesin olarak eşleştirin.
- Token içindeki öğrenci, sınıf ve öğretmen alanlarını bağlantı belgesiyle karşılaştırın.
- Yetki kontrolünde bağlantının içeriğini, aktif durumunu ve sınıf ilişkisini doğrulayın.
- Bu işlemi istemci batch’i yerine sunucu tarafında transaction olarak yürütün.

### 2. Başka bir sınıfın duyurularına sahte erişim kaydıyla ulaşılabiliyor

**Kaynaklar:**

- `firestore.rules:63-66`
- `firestore.rules:266-271`
- `firestore.rules:342`

`parent_class_access` oluşturma kuralındaki öğretmen kolu, gerçek öğrenci/token/sınıf ilişkisini doğrulamıyor. Oturum açmış biri kendi UID’sini taşıyan hayalî bir öğrenci kimliğiyle istediği hedef sınıf için erişim belgesi oluşturabiliyor.

`parentHasClass` yalnız bu belgenin varlığına baktığı için hedef sınıfın duyuruları erişilebilir hale geliyor. Veli kolunda da bağlantılı öğrencinin gerçekten hedef sınıfa ait olduğu doğrulanmıyor.

**Etki:** Sınıf duyurularının yetkisiz okunması ve sınıf meta verisinin açığa çıkması.

**Öneri:** Öğretmen kolunda hedef sınıf sahipliğini; veli kolunda kanonik belge kimliği ile gerçek öğrenci–sınıf ilişkisini doğrulayın.

## Yüksek öncelikli işlev ve mantık hataları

### 3. Meşru veli–öğrenci bağlantısı Firestore kurallarıyla uyumsuz

**Kaynaklar:**

- `lib/features/parent_portal/data/repositories/cloud_token_repository.dart:208-267`
- `lib/features/parent_portal/data/services/parent_link_bridge.dart:192-195`
- `firestore.rules:205-207`
- `firestore.rules:243-245`
- `firestore.rules:268-270`

Üç bağımsız uyuşmazlık bulunuyor:

1. `commitParentLink`, kuralların zorunlu tuttuğu `codeHash` alanını bağlantı belgesine yazmıyor.
2. Veli aynı batch içinde yalnız öğrencinin sahibi öğretmenin güncelleyebildiği token sayacını değiştirmeye veya tokenı silmeye çalışıyor.
3. `parent_class_access` kuralındaki `exists()`, aynı batch içinde ilk kez oluşturulan bağlantıyı görmüyor; işlem sonu durumunun denetlenmesi gerekiyor.

Bu nedenlerden herhangi biri batch’in tamamını reddetmeye yeterli. Hata kullanıcıya gerçek neden yerine “İnternet bağlantınızı kontrol edin” şeklinde gösteriliyor.

`ensureParentAccess` yolu da aynı batch/`exists()` sorununu taşıyor. Var olan bağlantıyı tekrar yazarken `linkedAt` alanını değiştirdiği için yalnız `status` değişikliğine izin veren update kuralına da takılabilir.

**Öneri:** Bağlantı doğrulama, token tüketimi, sayaç artışı ve erişim oluşturmayı sunucu tarafı transaction’ına taşıyın. Gerçek veli kimliğiyle uçtan uca Firestore emulator testi ekleyin.

### 4. Referans kodları taranabilir; ikinci faktör koruma sağlamıyor

**Kaynaklar:**

- `lib/features/parent_portal/data/repositories/parent_token_repository.dart:54-58`
- `lib/features/parent_portal/data/repositories/parent_token_repository.dart:249-258`
- `lib/features/parent_portal/data/models/parent_token_model.dart:155-158`
- `lib/features/parent_portal/data/repositories/cloud_token_repository.dart:141-157`
- `firestore.rules:197-207`

Kod biçimi `SC-<sınıf etiketi>-<4 hane>` ve sınıf etiketi başına yalnız 9.000 olasılık var. Hash salt’ı sabit ve istemci kaynak kodunda açık. Her oturum hash üzerinden doğrudan token okuyabiliyor.

Token yanıtında öğrenci adı, okul/sınıf bilgisi ve açık öğrenci numarası bulunuyor. Böylece öğrenci numarasına dayanan ikinci faktör de aynı doğrulama isteğinin cevabından öğrenilebiliyor.

Global belge yolu yalnız kod hash’ine dayandığı, tekillik sadece yerel cihazda kontrol edildiği ve update kuralı eski token sahibini doğrulamadığı için aynı kodu üreten ikinci öğretmen ilk öğretmenin tokenını da ezebilir.

**Öneri:**

- Kriptografik olarak güvenli, yüksek entropili davet kodu kullanın.
- Token doğrulamasını hız sınırlı bir sunucu endpoint’ine taşıyın.
- Token tüketilmeden öğrenci adı/numarası gibi verileri döndürmeyin.
- Token sahipliğini immutable yapın ve yalnız oluşturma işlemine izin verin.

### 5. “Kodu yenile” eski bulut kodunu iptal etmiyor

**Kaynaklar:**

- `lib/features/parent_portal/data/repositories/parent_token_repository.dart:232-234`
- `lib/features/parent_portal/presentation/widgets/class_reference_codes_modal.dart:278-318`
- `lib/features/parent_portal/data/models/parent_token_model.dart:75`

Yenileme sırasında eski token yalnız yerel listeden çıkarılıyor ve yeni token buluta yayımlanıyor. Eski hash için bulut silme veya iptal çağrısı yapılmıyor. Eski token bulutta 2099’a kadar geçerli kalabiliyor ve yerel listeden silindiği için sonraki mezuniyet/silme temizliği tarafından da bulunamıyor.

**Kullanıcı etkisi:** Öğretmen kodu yenileyerek eski kodun geçersiz olduğunu düşünür; eski kodu bilen kişi bağlantı kurmaya devam edebilir.

**Öneri:** Eski tokenın iptali ve yeni tokenın oluşturulmasını sunucuda atomik gerçekleştirin. Öğrenciye ait aktif davetlerin sunucudan sorgulanabilmesini sağlayın.

### 6. Öğrenci silme, mezuniyet veya nakil veli erişimini kapatmayabilir

**Kaynaklar:**

- `lib/features/parent_portal/data/services/student_lifecycle_coordinator.dart:81-107`
- `lib/features/parent_portal/data/repositories/parent_token_repository.dart:116-133`
- `lib/features/parent_portal/data/repositories/parent_token_repository.dart:882-884`
- `lib/features/parent_portal/providers/parent_token_provider.dart:108-115`

Yaşam döngüsü temizliği, bağlı velileri öğretmen cihazındaki yerel preferences listesinden alıyor. Bağlantılar esas olarak veli cihazında ve bulutta bulunduğu için öğretmen tarafındaki liste normal iki cihaz kullanımında boş kalabilir.

Sonuç olarak hiçbir `unlinkParent` çağrısı yapılmaz; token silinse bile `parentHasStudent` ve `parentHasClass` tokenın varlığına bakmadığı için eski erişim devam eder.

**Öneri:** Ayrılma ve yetki iptalini sunucudaki öğrenci bağlantıları üzerinden yürütün. Ağ hatasında kalıcı yeniden deneme kuyruğu oluşturun.

### 7. Şube taşıma işlemi kurallar nedeniyle reddediliyor

**Kaynaklar:**

- `lib/features/parent_portal/data/repositories/cloud_token_repository.dart:494-507`
- `lib/features/parent_portal/data/services/student_lifecycle_coordinator.dart:204-209`
- `firestore.rules:248-250`

İstemci, öğretmen adına bağlantı belgesindeki `classCloudId` ve `className` alanlarını değiştirmeye çalışıyor. Firestore kuralı ise update işlemini yalnız veliye ve yalnız `status` alanı için açıyor.

Batch reddedilirken yerel taşıma devam edebildiği için yerel ve bulut durumu ayrışabilir.

**Öneri:** Öğrenci sahibi öğretmene sadece sınıf alanlarını değiştirecek sınırlı yetki tanımlayın veya taşıma işlemini güvenilir sunucu koduna aktarın.

### 8. Token güvenlik sınırları yalnız istemcide uygulanıyor

**Kaynaklar:**

- `firestore.rules:90-96`
- `firestore.rules:240-246`
- `lib/features/parent_portal/data/services/parent_link_bridge.dart:136-154`
- `lib/features/parent_portal/data/repositories/cloud_token_repository.dart:232-233`

Sunucudaki `tokenGecerli` fonksiyonu yalnız belgenin varlığını ve öğrenci kimliğini kontrol ediyor. Tokenın aktifliği, süresi, ikinci faktörü ve azami bağlı veli sayısı kurallarda uygulanmıyor.

Özel bir istemci bu kontrolleri atlayabilir. Mevcut istemci de sayacı transaction yerine eski okunan değer üzerine `+1` hesapladığı için eşzamanlı kullanımlarda kayıp güncelleme oluşabilir.

**Öneri:** Token doğrulama ve tüketimini sunucu transaction’ında gerçekleştirin; kullanıcı başına idempotency ve aktif bağlantı denetimi ekleyin.

### 9. Yeni tarayıcıdan sınav yayınlamak sürümü geriye alabiliyor

**Kaynaklar:**

- `admin_portal/js/admin_app.js:1327-1332`
- `admin_portal/js/manifest_manager.js:87`
- `functions/index.js:75-79`
- `lib/features/sync/services/sync_service.dart:207`

Yönetim paneli yerel manifest sürümünü artırıp gönderiyor. Sunucu mevcut Remote Config sürümüyle karşılaştırma yapmadan kabul ediyor.

Örnek: Bir yönetici v5 yayınladıktan sonra yeni tarayıcıyla giriş yapan başka bir yönetici yerel varsayılan sürümden v2 yayınlayabilir. Daha önce v5 görmüş cihazlar `uzakSurum <= yerelSurum` koşulu nedeniyle yeni içeriği yok sayar.

**Öneri:** İçerik sürümünü sunucuda mevcut Remote Config değerinden monoton artırın. Yayından önce optimistic concurrency veya sürüm uyuşmazlığı kontrolü yapın.

### 10. Sınav yayınlama diğer canlı sistem ayarlarını da ezebiliyor

**Kaynaklar:**

- `admin_portal/js/admin_app.js:1331-1333`
- `admin_portal/js/manifest_manager.js:103-112`
- `functions/index.js:75-79`

Yeni tarayıcıdan yalnız sınav yayını yapıldığında `maintenance_mode:false`, `min_app_version:'1.0.0'` ve diğer modül sürümleri gibi yerel varsayılanlar da gönderiliyor.

**Etki:** Canlı bakım modu yanlışlıkla kapatılabilir, zorunlu minimum sürüm düşürülebilir ve diğer modüllerin sürümleri geriye alınabilir.

**Öneri:** Sınav yayını yalnız `exams_payload` ile sunucunun yönettiği `exams_version` alanını değiştirmeli. Diğer ayarlar ayrı yayın işlemleri olmalı.

### 11. Yönetim panelinde kalıcı XSS riski var

**Kaynaklar:**

- `admin_portal/js/admin_app.js:1168-1170`
- `admin_portal/js/admin_app.js:1180-1183`
- `admin_portal/js/admin_app.js:1801-1809`

Dışarıdan içe aktarılan sınav JSON’undaki `title`, `description`, `applicationUrl` ve `doc_id` değerleri doğrulanmadan localStorage’a yazılıyor ve ardından `innerHTML`/inline `onclick` içine kaçışsız yerleştiriliyor.

Hazırlanmış bir JSON, giriş yapmış süper yönetici oturumunda JavaScript çalıştırabilir ve panelin Remote Config yayın fonksiyonuna ulaşabilir.

**Öneri:**

- Metinleri `textContent` ile üretin.
- Olayları inline `onclick` yerine `addEventListener` ile bağlayın.
- URL protokolünü yalnız `https`/`http` ile sınırlayın.
- İçe aktarılan JSON’u katı bir şemayla doğrulayın.
- Uygun bir Content Security Policy ekleyin.

### 12. Excel ile eklenen kazanımlar yenilemeden sonra kayboluyor

**Kaynaklar:**

- `admin_portal/js/outcomes_manager.js:75-82`
- `admin_portal/js/outcomes_manager.js:110-129`
- `admin_portal/js/admin_app.js:985`
- `admin_portal/js/admin_app.js:1004-1008`
- `admin_portal/js/admin_app.js:1045`
- `admin_portal/js/admin_app.js:1065-1066`

`save()` paket içinde olmayan yeni kayıtların tamamını overrides’a yazıyor. Buna karşılık `applySavedOverrides()` yalnız paket verisinde zaten bulunan ID’lere yama uyguluyor; yeni ID’leri listeye eklemiyor.

Sayfa yenilendiğinde içe aktarılan kazanımlar kayboluyor. İçe aktarım sırasında kaldırılan paket kayıtları da yeniden geliyor.

**Doğrulama sonucu:** Kayıt storage’a yazılıyor; yeniden yüklemeden sonra yeni kayıt bulunmuyor ve kaldırılmış orijinal kayıt geri geliyor.

**Öneri:** Ekleme, değiştirme ve silme farklarını ayrı saklayın. Açılışta yeni kayıtları listeye ekleyin ve silinmiş paket kayıtlarını geri getirmeyin.

### 13. Android sınav hatırlatmalarının native yapılandırması eksik

**Kaynaklar:**

- `android/app/src/main/AndroidManifest.xml:1-69`
- `lib/core/services/notification_service.dart:116-125`
- `lib/core/services/notification_service.dart:139-154`

Servis `AndroidScheduleMode.exactAllowWhileIdle` kullanıyor. Manifestte exact-alarm izni, `ScheduledNotificationReceiver`, yeniden başlatma receiver’ı ve `RECEIVE_BOOT_COMPLETED` izni bulunmuyor. Exact alarm yetkisi isteyen bir kullanıcı akışı da yok.

**Etki:** Favoriye eklenen sınavın bildirimi kurulamıyor veya cihaz yeniden başladıktan sonra teslim edilmiyor. Hata yalnız debug çıktısına yazıldığı için kullanıcı bildirimin başarıyla kurulduğunu düşünebilir.

**Öneri:** Gerekli receiver ve izinleri ekleyin; exact alarm izin akışını uygulayın veya izin gerektirmeyen zamanlama modunu seçin. Başarısızlığı kullanıcıya bildirin.

### 14. iOS QR taramasında kamera kullanım açıklaması eksik

**Kaynaklar:**

- `ios/Runner/Info.plist:4-88`
- `lib/features/board_config/presentation/tahta_kilidi_screen.dart:327-330`
- `lib/features/board_config/presentation/tahta_kilidi_screen.dart:526`

QR taraması `MobileScanner` kullanıyor; ancak Info.plist içinde `NSCameraUsageDescription` bulunmuyor.

**Etki:** Kullanıcı QR tarama düğmesine bastığında iOS uygulamayı native seviyede sonlandırabilir. Flutter `errorBuilder` bu eksikliği güvenli şekilde yakalayamaz.

**Öneri:** Kamera erişim açıklamasını ekleyin; ilk izin, ret, kalıcı ret ve ayarlardan izin verme akışlarını gerçek iPhone/iPad üzerinde doğrulayın.

## Kullanıcı hatalarıyla tetiklenebilen sorunlar

### Yanlış referans kodunda bağlantı önizlemesi gösterilmiyor

**Kaynaklar:**

- `lib/features/parent_portal/data/services/parent_link_bridge.dart:160-180`
- `lib/features/parent_portal/presentation/screens/parent_student_connect_screen.dart:167-173`

Bağlantı servisi yanlış öğrenciye bağlanmayı önlemek için bir `confirm` callback’i destekliyor; fakat bağlantı ekranı bu callback’i vermiyor.

Kullanıcı yanlış fakat geçerli bir kod ve aynı öğrenci numarasını girerse hangi öğrenciye bağlandığını onaylamadan işlem tamamlanabilir. Okul numaraları okullar arasında tekrar edebildiği için bu senaryo tamamen teorik değildir.

### Randevu günü öğretmenin görüşme gününü dikkate almıyor

**Kaynak:** `lib/features/parent_portal/presentation/screens/parent_child_detail_screen.dart:477`

Randevu tarihi, öğretmenin `meetingDay` bilgisi yerine daima `DateTime.now() + 2 gün` olarak oluşturuluyor. Kullanıcı tarih veya saat seçemiyor; ekranda gösterilen görüşme günü ile kaydedilen tarih farklı olabilir.

### Randevu çakışma kontrolü fiilen çalışmıyor

**Kaynaklar:**

- `lib/features/parent_portal/data/repositories/cloud_communication_repository.dart:1019-1036`
- `firestore.rules:390-392`

Çakışma sorgusu `appointmentDate` için tam ISO zaman eşitliği arıyor. Birkaç saniye arayla gönderilen aynı gün/saat talepleri farklı değerler taşıdığı için eşleşmiyor.

Ayrıca veli sorgusu sınıftaki tüm randevuları öğretmen/zaman/tarih üzerinden arıyor; Firestore kuralı velinin yalnız kendi öğrencisinin randevularını okumasına izin veriyor. Sorgu reddedildiğinde catch bloğu `false` döndürüp “çakışma yok” davranışı üretiyor.

### Bulut hataları yanlışlıkla internet sorunu olarak gösteriliyor

Yetki, şema veya kural uyuşmazlıkları kullanıcıya çoğunlukla bağlantı sorunu olarak gösteriliyor. Kullanıcı tekrar tekrar denese bile düzelmeyecek sorunlarda yanlış yönlendiriliyor.

### “Tüm Veriyi İndir” eksik yedek oluşturuyor

**Kaynaklar:**

- `admin_portal/index.html:108-110`
- `admin_portal/js/cloud_exporter.js:45-56`
- `admin_portal/js/calendar_manager.js:44-47`

Buton `examsManager` argümanını göndermediği için `official_exams` daima boş dizi oluyor. `calendarManager.getEvents()` ise varsayılan olarak yalnız seçili akademik yılı döndürüyor.

**Etki:** Yönetici “tüm veri” yedeği aldığını düşünür; sınavlar ve diğer akademik yıllar yedekte bulunmaz.

### Android release çıktısı debug anahtarıyla imzalanıyor

**Kaynak:** `android/app/build.gradle.kts:42`

Release yapılandırması debug signing config kullanıyor. Farklı makinede anahtar değişmesi mevcut kurulumların güncellenmesini engelleyebilir ve mağaza dağıtım sürecine uygun değildir.

## Diğer güvenlik ve maliyet bulguları

### Okul öğretmen dizini üyeliği güvenilir biçimde doğrulanmıyor

**Kaynak:** `firestore.rules:179-187`

Okuma yetkisi kullanıcının ilgili okul için kendi `school_teachers` belgesinin varlığına dayanıyor; fakat herhangi bir oturum istediği okul için kendi belgesini oluşturabiliyor. Veli hesabı öğretmen dizinine girerek ad, branş ve e-posta bilgilerini okuyabilir veya sahte öğretmen olarak seçim listesine girebilir.

### Aktif tokenlar gereksiz yere tekrar yayımlanıyor

**Kaynak:** `lib/features/parent_portal/providers/parent_token_provider.dart:74-83`

Provider yüklenirken bütün aktif tokenlar yeniden yayımlanıyor. Token başına sınıf, kadro ve token belgesi yazıldığı için gereksiz Firestore maliyeti doğuyor. Yerel sayaç eskiyse buluttaki kullanım sayısı da geriye çekilebilir.

## Test durumu

- Cloud Functions testleri: **49/49 geçti**.
- Yönetim paneli testleri: **32/32 geçti** (`test_calendar.js` 16/16, `test_outcomes.js` 16/16).
- Firestore emulator testleri salt-okunur koşulu nedeniyle çalıştırılmadı.
- Android/iOS cihaz testi yapılmadı.
- Flutter istemcinin tamamı satır satır eksiksiz denetlenmiş sayılmamalı; hedefli statik tarama ve kritik akış incelemesi yapıldı.

Mevcut testlerin geçmesi üretim akışlarının doğru olduğunu göstermiyor. Testler gerçek kullanıcı kimliğiyle uçtan uca Firestore batch’ini, iki cihazlı veli yaşam döngüsünü, eşzamanlı Remote Config yayınını ve native platform izinlerini kapsamıyor.

### Belirlenen test boşlukları

- Gerçek öğretmen ve veli kimliğiyle referans kodu oluşturma → doğrulama → tüketme → bağlantı kurma testi yok.
- Sahte belge kimliği/içerik uyuşmazlıklarını reddeden negatif Firestore kural testleri yok.
- Aynı tokenın iki hesap tarafından eşzamanlı tüketilmesi test edilmiyor.
- Öğretmen ve veli olmak üzere iki cihazlı silme, mezuniyet, nakil ve şube taşıma akışları test edilmiyor.
- İki bağımsız yönetici oturumuyla monoton Remote Config sürümü test edilmiyor.
- Sınav yayınının yalnız hedef parametreleri değiştirdiği test edilmiyor.
- Admin dış JSON/XSS, tam yedek ve Excel import → reload senaryoları test edilmiyor.
- Android exact alarm, cihaz yeniden başlatma ve izin reddi akışları test edilmiyor.
- iOS `NSCameraUsageDescription` ve QR izin akışı test edilmiyor.
- Bazı hesap izolasyonu testleri üretim akışını kullanmak yerine test içinde yeniden oluşturulan küçük şema/anahtar üreticisini sınadığı için gerçek provider/auth/database davranışını kanıtlamıyor.

## Olumlu bulgular

- Cloud Functions içindeki callable fonksiyonlar gerçek `adminRole == 'super'` claim’ini sunucuda denetliyor; incelenen iki callable’da doğrudan yönetici yetkisi atlama bulunmadı.
- Storage kuralları yalnız okul veri paketlerini herkese okunur tutuyor ve istemci yazmalarını kapatıyor.
- İncelenen birleşik Firestore sorgularının gerekli indeksleri mevcut. Randevu problemi indeks eksikliğinden değil, sorgu/kural uyumsuzluğundan kaynaklanıyor.
- Yönetim panelindeki Firebase web yapılandırmasının görünür olması tek başına gizli anahtar sızıntısı değildir; asıl güvenlik sınırı Auth, Firestore kuralları ve sunucu claim kontrolleridir.

## Önerilen düzeltme sırası

### Aşama 1 — Yayın engelleyici güvenlik düzeltmeleri

1. Veli bağlantı özelliğini geçici olarak kapatın veya erişimi yalnız güvenilir sunucu işlevine yönlendirin.
2. `parent_links` ve `parent_class_access` belge kimliği–içerik eşleşmesini zorunlu yapın.
3. Token oluşturma, doğrulama, tüketme ve sayaç güncellemesini sunucu transaction’ına taşıyın.
4. Yüksek entropili yeni token şeması oluşturun ve eski tokenları iptal edin.
5. Firestore emulator üzerinde saldırı senaryoları için negatif kural testleri yazın.

### Aşama 2 — Veri yaşam döngüsü

1. Silme, mezuniyet, nakil ve şube taşıma işlemlerini bulut bağlantıları üzerinden yürütün.
2. Ağ kesintilerinde kalıcı yeniden deneme mekanizması ekleyin.
3. Eski veli ve sınıf erişim belgeleri için bir defalık temizlik/migration planı hazırlayın.

### Aşama 3 — Yönetim paneli ve Remote Config

1. Remote Config sürümlerini sunucuda monoton yönetin.
2. Her yayın işlemini yalnız hedef parametrelerle sınırlandırın.
3. XSS noktalarını `textContent`, güvenli DOM API’leri ve şema doğrulamasıyla kapatın.
4. Kazanım ekleme/değiştirme/silme kalıcılığını düzeltin.
5. “Tüm Veriyi İndir” akışını gerçekten tam yedek verecek şekilde test edin.

### Aşama 4 — Platform ve kullanıcı deneyimi

1. Android bildirim izinleri ve receiver yapılandırmasını tamamlayın.
2. iOS kamera kullanım açıklamasını ekleyin.
3. Üretim signing yapılandırmasını oluşturun.
4. Yanlış kod için öğrenci önizleme/onay adımını zorunlu hale getirin.
5. Randevu günü/saat seçimini ve çakışma modelini yeniden tasarlayın.
6. Yetki ve veri sözleşmesi hatalarını “internet sorunu” olarak göstermeyin.

## Sonuç

Kod tabanında çok sayıda koruyucu yorum, doğrulama niyeti ve geniş test paketi bulunuyor. Ancak en kritik sorunlar, istemci kodu ile Firestore kurallarının ayrı ayrı doğru görünmesine rağmen birlikte çalışırken farklı veri/yetki sözleşmeleri kullanmasından kaynaklanıyor.

Üretim öncesindeki temel hedef, veli portalındaki güven kararlarını istemciden alıp tek bir sunucu tarafı transaction ve açık veri modeli etrafında toplamak olmalıdır. Bunun ardından Remote Config yayın güvenliği, yönetim paneli veri kalıcılığı ve native platform yapılandırmaları ele alınmalıdır.

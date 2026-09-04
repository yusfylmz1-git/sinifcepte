# SınıfCepte — Sert Denetim Raporu

**Tarih:** 31 Ağustos 2026  
**Denetçi:** Grok (bağımsız, dört rol)  
**Kapsam:** Repodaki güncel kod, güvenlik kuralları, hukuki metinler, maliyet modeli, yayın altyapısı. Tahmin yok; her iddia dosya yoluna bağlı.  
**Bu rapor ne değildir:** `eksikler.md` özeti değildir. O belge dünün envanteridir ve bir kısmı “düzeltilmiş” görünüp yeni yalan üretmiştir. Bu metin ürün kararını sorar.

---

## Karar: kullanır mıydım?

| Rol | Kullanır mıydım? | Tek cümle |
|---|---|---|
| **Proje yöneticisi** | **Hayır.** Türkiye geneli yayın kararı veremem. | Bu bir ürün değil; niyet, yama ve yorum yığını. |
| **Öğretmen** | **Hayır — gerçek sınıf verisiyle.** | Yedekleme yalan söylüyor; telefon giderse yıl gider. |
| **Veli** | **Hayır.** | WhatsApp grubundan daha az işe yarar, daha çok risk taşır. |
| **MEB koordinatörü** | **Kesinlikle hayır.** | Okullara tavsiye edilemez; resmî görünümlü gayriresmî paralel sistem. |

Aşağıdaki her bölüm, bu tabloyu savunur.

---

## 0. İddianame — yayın öncesi durdurulması gerekenler

Bu uygulama “öğretmen asistanı + veli köprüsü” iddiasındadır. Kodun büyük kısmı **öğretmenin telefonunda** çalışır; bu doğru bir mimari içgüdüdür. Asıl felaket, iddianın gerçeği aşmasıdır:

1. **Kullanıcıya yalan söyleyen düğmeler vardır.** Yedek alındı denir, dosya yazılmaz. Evrak PDF’i üretildi denir, PDF yoktur. Senkron “başarıyla güncellendi” der, yalnızca yerel sürüm sayacını artırır.
2. **Güvenlik kuralları, veli bağını kanıtlamaz.** Herhangi bir giriş yapmış kullanıcı, kendi UID’siyle `parent_links` ve `parent_class_access` yazabilir; ardından duyuru okur, kadro görür, mesaj atar. Bunu kural testleri “onarım” diye **başarı** saymaktadır.
3. **KVKK metni hâlâ yanlış beyan içerir.** “Öğrenci numaraları telefondan çıkmaz” yazar; `parent_tokens` ve `parent_links` içinde `studentNumber` buluttadır.
4. **Destek hattı sahipsizdir.** Talep Firestore’a yazılır; güvenlik kuralı talebi yalnızca gönderene açar. Yönetici okuyamaz. `sinifcepte@gmail.com` bir operasyon değildir.
5. **Yayın altyapısı yok hükmündedir.** Release, **debug anahtarıyla** imzalanır. Play Store’a bu hâliyle çıkılırsa sonraki güncelleme imza çatışmasına düşer. `Cloud Functions` yok, App Check yok, FCM yok, zorunlu güncelleme kapısı yok.
6. **Veli ürünü, veli ihtiyacını karşılamaz.** Not yok, devamsızlık yok, ödev yok, gerçek push yok. Veli Google hesabı + kod + okul numarası verir; karşılığında duyuru ve mesaj alır. Bu, okul WhatsApp grubunun daha sürtünmeli hâlidir.
7. **MEB ile bağ yok diye hukuk metninde yazılır; arayüz “resmî”, “e-Okul uyumlu”, “MEB takvimi” der.** Bu, yanıltıcı ticari uygulamadır.

Bunların hiçbiri “sonra bakarız” maddesi değildir. 1, 2, 3 ve 5 kapanmadan **tek bir öğretmen bile davet edilmemelidir.**

---

# 1. Rol: Proje yöneticisi

Görevim: kapsamı kilitlemek, yayına çıkmak, maliyet ve itibar riskini taşımak. Bu kod tabanı o görevi yerine getirmeme izin vermiyor.

## 1.1 Ürün tanımı çökmüş durumda

Üç ayrı “gerçek” yaşıyor:

| Kaynak | Ne diyor | Gerçek |
|---|---|---|
| `docs/01-PRD.md` | Yoklama ana modül, e-Okul’a aktarım, biyometrik kilit “gelecek sürüm”, Excel/PDF rapor | PRD fosildir. Faz 2 hâlâ açık kutucuk. |
| `docs/02-ARCHITECTURE.md` | `performance/` klasörü, yoklama ER diyagramı | Klasör yok. Şema yalan. |
| `.agents/AGENTS.md` | Clean Architecture, 4 katmanlı doğrulama, sıfır taşma, “şifrelenebilir” yerel veri | Hiçbiri teslim edilmemiş standart. |
| `README.md` | “A new Flutter project.” | İşe alım ve devretme belgesi yok. |
| Kod + `walkthrough.md` | Yoklama **yasak**; katılım var | Doğru ürün kararı, ölü dokümanlarla çelişiyor. |

Bir proje yöneticisi için bu, tek başına red sebebidir. Ekip (veya ajan) hangi gerçeğe uyacağını bilemez. “Yoklama yok” kuralı hukukî olarak doğru olabilir; o zaman PRD’nin birinci sayfasında duramaz. Duruyorsa ya ürün yalan söylüyor ya dokümantasyon. İkisi de yayın kalitesi değildir.

AGENTS.md’deki “şifrelenebilir” kelimesi özellikle kabul edilemez. Ya şifrelidir ya değildir. SQLite **düz metindir.** SQLCipher yok. `encrypt` paketi yok. “-ebilir” eki, denetimde kaçıştır.

## 1.2 Teslimat yalanları — sahte tamamlandı işaretleri

Üç yerde kullanıcıya **başarı geri bildirimi** veriliyor, iş yapılmıyor. Bu, kalite değil; ürün sahtekârlığıdır.

### Yedekleme (öğretmenin en kritik ihtiyacı)

`lib/shared/widgets/app_drawer.dart` içinde “Veri Yedekleme & Aktarma” menüsü:

- Metin: “Ücretsiz yerel dosya yedekleme”, “%100 Gizlilik ve Güvenlik”.
- Düğme `Yedek Al` basılınca **hiçbir dosya yazılmaz.**
- `SnackBar`: “Yedekleme dosyası hazırlandı! (SQLite Backup)”.

Gizlilik politikası aynı anda şunu der (`legal_document_screen.dart`): telefon kaybolursa notlar, katılım, devamsızlık **geri gelmez**; yedek kullanıcıya aittir. Yani ürün hem “yedek sizin sorumluluğunuz” der, hem yedek düğmesini tiyatroya çevirir. Öğretmen dava açsa, bu ekran görüntüsü delildir.

### Evraklarım

`documents_hub_view.dart` dört “resmî şablon” listeler (zümre tutanağı, veli toplantısı, BEP, gelişim raporu). Yazdır ikonuna basılınca:

> “5 Saniyede Yenilenmiş PDF Oluşturuldu!”

PDF üretilmez. Şablon dosyası yoktur. BEP’i sahte snackbar ile “ürettim” demek, özel eğitim evrakında şaka değildir.

### Senkron

`sync_service.dart` Remote Config’den sürüm okur, ardından **veri indirmez.** Yerel `syncMetadataVersionGuncelle` çağrılır, mesaj:

> “MEB Akademik Takvimi, Müfredat Kazanımları başarıyla güncellendi 🚀”

Takvim/kazanım baytı değişmemiştir. Admin panelindeki “+1 Artır (Yayınla)” artık Remote Config’e bağlıdır diye yorumlarda övülür; mobil taraf hâlâ “sayaç eşitledim = güncelledim” der. Kullanıcı yeni tatili görmez, sistem “güncelsin” der.

Bu üçü tesadüf değil, bir kültür: **ekranı bitirmek, işi bitirmek sanılıyor.**

## 1.3 Operasyon yok, ölçek hikâyesi var

`maliyet.md` 1000 okul / 30.000 öğretmen / 750.000 veli için aylık ~240 dolar Firestore + reklamdan 23.000 dolar anlatır. Sayıların bir kısmı kod ölçümüne dayanır; **operasyon kapasitesi sıfırdır.**

Eksikler:

| Olması gereken | Durum |
|---|---|
| Cloud Functions | Klasör yok. Claim yazımı `scripts/admin/*.mjs` ile elde. |
| App Check | Paket yok, enforcement yok. API anahtarı istemcide. |
| FCM | Yok. Yorumlar “ileride” diyor. |
| Destek masası | `sinifcepte@gmail.com`. Firestore `support_requests` yöneticisine **kapalı.** |
| On-call / SLA | Yok. Eski 24 saat vaadi kaldırılmış; yerine “ekibimize iletilir” — ekip tanımlı değil. |
| VERBIS / veri sorumlusu kimliği | Gizlilik metninde yok. |
| Play imzası | Release = **debug signing.** `android/app/build.gradle.kts`. |
| Zorunlu güncelleme | `minAppVersion` var; kapı yalnızca akademik takvim ekranında snackbar. Kökte uygulama açılmaz. |
| Bakım modu | Aynı şekilde kökte engellemez. |
| Çökme triyajı | Crashlytics bağlandı; iyi. Açılış Firebase’i arka planda; tampon 20 hata. Yeterli değil ama en azından var. |
| iOS mağaza | `CFBundleDisplayName = Sinifcepte` (Türkçe karakter yok, marka yok). Kullanım açıklamaları (kamera, fotoğraf, bildirim) zayıf/eksik. |
| Android vitrin | `android:label="sinifcepte"`. Küçük harf, marka değil. `POST_NOTIFICATIONS` yok. |
| Reklam | `AdGate` kapalı, AdMob paketi yok. 23.000 dolarlık tablo bir Excel hayalidir. |

250 öğretmene kadar “ücretsiz katman yeter” demek, 250 öğretmenin destek talebini Gmail’de taşıyabileceğiniz anlamına gelmez. İlk 50 öğretmen, referans kodu + “mesajım gitmiyor” + “yedek çalışmıyor” ile bu kutuyu doldurur.

Okul yöneticisi onayı custom claim ister. Claim’i yazan sunucu işi yoktur. Her başvuru için birinin Node script çalıştırması gerekir. Bu, “Türkiye geneli” değil, “tanıdık üç okul” modelidir.

## 1.4 Mimari: doğru içgüdü, teslim edilmemiş disiplin

Olumlu ve korunması gereken kararlar (bunları inkâr etmek dürüst olmaz):

- Öğrenci notu, katılım, telefon, program **bilinçli olarak** cihazda.
- Snapshot listener yasağı (`firestore_client.dart`) fatura için doğrudur.
- Delta senkron, batch yazma, token hash’inin doküman kimliği olması düşünülmüş işlerdir.
- Bütçe freni vardır (1500 yazma/gün/cihaz).
- Not girişinde sessiz silme/kırpma düzeltilmiş (`score_input.dart`).
- Kazanım veri seti ve okul dizini gzip ile APK’yı şişirmemiş.

Bunlar bir **çekirdek** eder. Ürün çekirdeğin etrafına 1600–1800 satırlık ekranlar, ölü PRD, sahte düğmeler ve “UI-UX-MAX / glassmorphism” mitolojisi yığmıştır.

Clean Architecture iddiası sahte. `features/*/screens` doğrudan repository ve SharedPreferences karıştırır. Veli bağları SQLite değil JSON string listesidir (`parent_links` Prefs). Domain katmanı yok. 4 katmanlı doğrulama, çoğu yerde yalnızca `TextFormField.validator`’dır.

God-file envanteri (bakım ve çökme riski, dünün sayımı hâlâ geçerli mertebede):

- `classroom_documents_pdf_generator.dart`
- `database_helper.dart`
- `dashboard_screen.dart`
- `my_class_hub_screen.dart`
- `participation_cumulative_reports_modal.dart`
- `outcome_carousel_card.dart`
- `weekly_outcomes_view.dart`
- `class_list_screen.dart` / `student_list_screen.dart` / `parent_contacts_screen.dart`

Bir ekran 1100+ satırsa, “taşma koruması standarttır” iddiası test edilemez. `Semantics` kullanımı **sıfırdır.** TalkBack’li bir öğretmen bu uygulamayı kullanamaz. 1517 `Text` içinde taşma koruması seyrek; bu konu `eksikler.md`’de duruyor ve kapanmış değil.

## 1.5 Test tiyatrosu

Çok test var. Güven vermiyor.

- Kural testleri geçmişte veliye **sahte custom claim** veriyordu; gerçek cihaz `PERMISSION_DENIED` alıyordu. Bu olay belgelenmiş. Ders çıkarılmış gibi duruyor: claim kaldırıldı, `isParent()` artık `request.auth != null`. Yani “test yalan söyledi” sorununu, **veli tanımını her giriş yapmış kullanıcı yapmakla** çözmüşler. Test artık geçer; yetki modeli zayıftır.
- `legal_documents_test.dart` ve `search_debounce_test.dart` **kaynak metin arar.** “Dosyada şu string var” testi, davranış testi değildir. Metni doğru yazıp kuralı yanlış bırakmak mümkündür — tam da olan şey.
- Widget testi: `widget_test.dart` smoke. Uçtan uca test yok.
- `deleteParentSelfAccount` yalnızca testte çağrılır; arayüzde düğme yoktur.
- Release imzası, sahte yedek, sahte evrak, senkron no-op: **hiçbiri kırmızı test üretmez.** Çünkü test, kullanıcının gördüğü yalanı ölçmez.

449 test + 108 kural testi, “çalışıyor” demek değildir. “Yazdığımız iddiayı kendi kendimize tekrar ettik” demektir.

## 1.6 Maliyet — ucuz olabilir, kontrolünüz yok

Maliyet modelinin dürüst tarafı: öğrenci verisini buluta çıkarmamak faturayı gerçekten bastırır. Snapshot yasağı doğrudur.

Kontrolünüz olmayan taraf:

- Fren **istemcidedir.** Kötü niyetli istemci veya sızdırılmış API anahtarı `allowWrite`’ı tanımaz.
- Google Cloud bütçe alarmı dokümanda “sizin yapmanız gereken” olarak durur; kurulduğu kanıtı yok.
- `docs/BUDGET.md` hâlâ günlük yazma tavanını **500** yazar; kod **1500**. Doküman drift’i operasyon hatasıdır.
- `cost_model.dart` duyuru + mesaj + token + tazeleme sayar. Durum bildirimi, randevu, kadro, okul dizini yenileme, destek talebi, saklama süresi temizliği (önce oku sonra sil) yok. “Tipik gün” iyimserdir.
- Okuma engellenmez. Kaçak okuma faturayı şişirir, kullanıcı uygulamanın yavaşladığını sanır.
- `CACHE_SIZE_UNLIMITED` cihazı doldurabilir; maliyet değil ama saha şikâyeti.
- Reklam geliri, paket yokken projeksiyon olamaz. PM olarak bu slaytı yatırımcıya koyamam.

**PM kararı:** özel beta (≤20 tanıdık öğretmen), sahte düğmeler sökülmeden, kural deliği kapanmadan, release imzası ve hesap silme olmadan **Play Store yok.** “Türkiye geneli” cümlesi şimdilik pazarlama zararlısıdır.

---

# 2. Rol: Öğretmen

Ben sınıf öğretmeniyim. Sabah 8’de derse gireceğim. Telefonum 4–5 yaşında, depolama dolu, okul Wi-Fi düşüyor. Benden beklenen: yoklamayı e-Okul’a işlemek, not girmek, veliyi bilgilendirmek, evrak basmak. Bu uygulama bunlardan hangisini gerçekten bitiriyor?

## 2.1 Bana vaat edilen

- Sınıf ve öğrenci listesi, e-Okul PDF/Excel içe aktarma
- Oturma planı, veli rehberi, WhatsApp
- Ders programı, haftalık kazanımlar
- Ders içi katılım (yoklama değil — yıldız, ödev, defter)
- Sınav / quiz / proje takibi, analiz PDF
- Veli kodu, duyuru, mesaj
- “Resmî” evrak ve yedek

Kâğıt üzerinde sınıf öğretmeninin günlük çantası. Sahada:

## 2.2 Verim ölebilir, uygulama “başarılı” der

**Telefonumu kaybedersem yıl biter.** Notlar, katılım, program, oturma planı, veli telefonları cihazda. Bu, KVKK için savunulan karar. Öğretmen için kabul edilemez — **ta ki yedek gerçek olana kadar.** Yedek düğmesi yalan. Google hesabı değiştirince boş veritabanı açılır (`openForUid`); bu bilinçli, ama çoklu cihaz / yeni telefon akışı yok. “Ayarlar’dan dışa aktar” yok.

Bu tek madde, gerçek sınıfımı buraya taşımamam için yeter.

## 2.3 İçe aktarma ve Türkçe

e-Okul PDF’i okunuyor diye test var. Aynı testler gömülü fontun `"Kız" → "Kz"` kırdığını belgeler. Sahada e-Okul PDF’leri düzgün font gömmez. Excel yolu daha umutlu; yine de “e-Okul’dan bir tık” vaadi, öğretmenin kırık karakterleri elle düzeltmesi demektir.

Sınıf adı yazarken `InputSanitizer.cleanClassName` her tuşta metni yeniden yazar (`class_list_screen.dart`). İmleç sona zıplar. “5-A” istiyorsam tamam; “LAB-1”, “HAZIRLIK”, “Uyum Sınıfı” yazmak kavga. İki ayrı “sınıf ekle” yüzeyi vardır (`add_class_dialog.dart` sınırlı, liste ekranındaki form sınırsız açıklama). Aynı iş, iki standart.

Okul numarası 5 hane, `1–99999`. MEB okul no pratikte 1–4 hane; 5 hane kabul, 0 red. Bu idare edilir. Boş ad/soyad UI’da durdurulur. İyi.

## 2.4 Katılım modülü — ekstra iş, hukuken gri, velinin görmediği defter

Yoklama yasağı doğru olabilir (resmî yoklama e-Okul’dadır). O zaman bu modül **pedagojik not defteri**dir. Benim gerçeğim:

- Her ders 25–35 öğrenciye ödev / defter / yıldız / not işlemek, kâğıttan yavaş olabilir.
- Çıktı: “resmî A4 PDF” ve **sınıf WhatsApp grubuna** tüm listenin dökümü (`participation_whatsapp_helper.dart`). Ödev yapmayan çocukların adını gruba yazmak, veli linçine davetiyedir. KVKK’da “ilgili kişinin açık rızası olmadan üçüncü kişilere” öğrenci değerlendirmesi. Grupta 30 veli üçüncü kişidir.
- Tekil veliye WhatsApp “tebrik”i daha az zararlıdır; yine de uygulama bunu teşvik eder, rıza kaydı tutmaz.
- Veli uygulamasında bu veriyi **görmez.** Yani ben işi yaparım, veli hâlâ sorar: “ödevini yaptı mı?” WhatsApp’a dökmezsem veri bende kalır; dökersem hukuken risk alırım.

Kullanır mıydım? Deneme sınıfında, çıktıyı **grup yerine** kendi arşivim için. Gerçek velilere bu listeleri göndermezdim.

## 2.5 Veli köprüsü bana iş çıkarır

Kod üret, paylaş, ikinci faktör olarak okul no, kadroya branş öğretmeni ekle, mesaj penceresi, randevu onayla. Bu, okulun zaten yaptığı WhatsApp + yüz yüze görüşmenin üzerine **yeni bir bürokrasidir.**

Karşılığında:

- Veli notu görmez; “neden not yok?” bana gelir.
- Push yok; veli uygulamayı açmaz, “duyuru gelmedi” der. Ben suçlanırım.
- Kod 4 hanelidir (`1000–9999`). Sınıf etiketi tahmin edilebilir (`SC-8A-9402`). Tuz kaynakta: `sinifcepte_salt_2026`. Ben velilere “bu kodu kimseyle paylaşmayın” demek zorundayım; sistem zayıfken öğretmen suçlu ilan edilir.
- Branş meslektaşım uygulamada değilse kadroya giremez. “Neden matematikçi yazışmıyor?” — çünkü o Google ile girmemiş.

Öğretmen olarak veli modülünü **açmam.** Sınıf listesi + oturma + kazanım + sınav takibi yeterdi. Veli köprüsü, olgunlaşmadan yük.

## 2.6 Kazanımlar ve program — asıl değer burada, gömülüyor

Haftalık Maarif kazanımları, bu uygulamada gerçekten nadir bir veri varlığıdır. Öğretmenin “bu hafta ne işleyeceğim?” sorusuna cevap, e-Okul’un vermediği şeydir. Ders programı + canlı ders algılama (katılım ekranını açma) kulağa işe yarar.

Ama `outcome_carousel_card.dart` / `weekly_outcomes_view.dart` dev dosyalar. Kazanım notları yerel; telefon değişince gider (yine yedek yalanı). Arama yok. 9087 kayıt telefonda gzip’ten açılır; ilk açılış eski cihazlarda donabilir (`FreezeDetector` bunun için var, yalnızca debug).

Sınav takibi ve 0–100 doğrulaması düzgünleşmiş. Sessiz 100’e kırpma yok. Bu, öğretmenin güvenebileceği az sayıdaki ayrıntıdan.

Karne görüşü üreticisi (`smart_comment_generator_provider.dart`) “e-Okul uyumlu pedagojik görüş” der. Şablon cümle + seed. İdare “neden hepsi birbirine benziyor” der. e-Okul’a yapıştırılırsa sorumluluk bendedir, uygulamada değil.

## 2.7 Günlük sürtünme

- “Veli Moduna Geç” düğmesi kaldırılmış görünüyor. İyi.
- Yardım bağlanmış. İyi. Yanıt gelmeyecek (bkz. destek kuralı). Kötü.
- Hesap silme yok. Okul değişince verinin ne olacağı belirsiz.
- Küçük ekran / yatay / büyük yazı tipi test edilmemiş. 5 sekmeli alt bar 320 dp’de sıkışır.
- Koyu temada sabit `Color(0xFF...)` yerleri var.
- Masaüstünde `local_desktop` ile yerel mod; yorumlarda `local_teacher`. İsim bile tek değil.
- Uygulama adı evde “sinifcepte”. Öğrenci velisine ekran gösterirken utanç.

**Öğretmen kararı:** Kazanım + oturma + liste için **boş bir deneme profiliyle** bakarım. Gerçek 8-A’yı, gerçek veli telefonlarını, gerçek notları **asla** bu sürüme yazmam. Yedek yalan söylediği sürece bu bir defter değil, bir tuzaktır.

---

# 3. Rol: Veli

Çocuğum 4. sınıfta. Öğretmen WhatsApp grubuna “uygulamadan bağlanın” yazdı. Google hesabı istiyor. Kod istiyor. Okul numarası istiyor. Telefon istiyor. KVKK kutusu istiyor.

Bana ne verecek?

## 3.1 İstediğim şeyler

1. Bugün okulda var mıydı?
2. Ödevi yaptı mı, sınavı kaçtı mı?
3. Öğretmen bana özel bir şey mi söylemek istiyor?
4. Toplantı / gezi / tatil ne zaman?
5. Gece 23:00’te rahatsız edilmeyeceğim, sabah 07:00’de “daha bakmadınız” sucu yenmeyeceğim.

Uygulama 4’ün bir kısmını (duyuru, takvim iddiası) ve 3’ün bir kısmını (mesaj, randevu) verir. **1 ve 2 yok.** Gizlilik metni bunu “bilinçli” diye açıklar: not ve devamsızlık öğretmen telefonunda. Benim açımdan ürün eksiktir, bilinçli değildir. “Sınıf uygulaması” deyip karneyi gizleyen şey, veliye yarı yüzdür.

Bağlanırken kabul ettiğim metin (`parent_student_connect_screen.dart` madde 3):

> “her veli yalnızca kendi çocuğunun **gelişim raporlarına** ve sınıf duyurularına erişebilir”

Gelişim raporu yoktur. Aydınlatma metni, olmayan bir özelliği vaat eder. Bu, rızayı sakatlar.

## 3.2 Sürtünme, ödüle göre fazla

- Google girişi. Her veli Google istemez. Okul “zorunlu uygulama” diyemez (MEB resmi değil) ama öğretmen baskısı olur.
- Kod + okul no. Okul no’yu bilmeyen veli (ayrı yaşayan, velayet karmaşası) dışarıda kalır. Bu bir güvenlik katmanı; aynı zamanda dışlama.
- Onboarding artık var. Geç kalmış, ama var. “Mesaj gece kalır” anlatılıyor. Push olmadığı anlatılmıyor yeterince.
- Telefon numarası toplanır, veli kaydına yazılır, **öğretmen rehberine otomatik düşmez.** Neden istendiği belirsiz. Gereksiz kişisel veri.
- Bildirim: uygulama içi merkez. Telefon kapalıyken, arka plandayken **sessizlik.** “Duyuru gelmedi” kavgası kaçınılmaz. FCM yok çünkü Functions yok çünkü Spark zihniyeti.
- Mesaj kuyruğu yok. Ağ kopunca mesaj gider. Ben “gönderdim” sanırım.
- Aynı çocuğa ikinci bağ (anne + baba) tasarlanmış. İyi niyet. Kod tükendiğinde token silinir (maliyet kararı). Üçüncü veli (büyükanne, velayet) kapıda kalır; `maxLinkedParents = 2`.

## 3.3 Güven — neden güvenmem

Öğretmenin telefonunda çocuğumun adı, numaram, davranış yıldızı duruyor. Şifresiz SQLite. Telefon PIN’i yoksa (uygulama kendi kilidini **asla** sormaz; biyometrik “gelecek sürüm” PRD’sinde kalmış) evdeki kardeş not defterini açar.

Bulutta adım, çocuğumun adı, okul numarası, sınıfı, mesajlarım. Gizlilik politikası numaranın çıkmadığını söyler — **söyler, çıkar.** Bu yalanı bir veli derneği görürse, okulun “biz önermiştik” cümlesi yetmez.

Referans kodu 4 hane + açık tuz. Ben kodu fotoğraflayıp aile grubuna atarım; herkes atar. Kod süresizdir (2099). Öğrenci mezun olana, öğretmen iptal edene, silene kadar yaşar. Öğretmen unutursa eski veli (boşanma, uzaklaştırma) teoride bağını koruyabilir; yaşam döngüsü **öğretmen cihazındadır.** Öğretmen uygulamayı açmazsa, ben hâlâ duyuru okurum.

Hesabımı silmek: profilde “Bağlantıyı Kaldır” var. Firebase hesabı silinmez. `deleteParentSelfAccount` kodda vardır, ekranda yoktur, bulut bağını silmez. KVKK md. 7: “e-posta yazın, 30 gün.” Bir tüketici uygulamasında hesap silme **uygulamanın içindedir**, Gmail’de değil. Play Store de bunu ister.

Destek: form doldururum, “ekibimize iletilir” + Gmail adresi. Ekip, kural gereği talebimi **okuyamaz.** Beni kimse aramaz.

## 3.4 Çocuğumun verisi WhatsApp’ta

Öğretmen “ders günlüğü”nü gruba yapıştırırsa, çocuğumun ödev yapmadığı 30 aileye gider. Uygulama bunu kolaylaştırır. Ben bu uygulamayı bu yüzden de istemem: öğretmeni kötü pratikte hızlandırır.

**Veli kararı:** Bağlanmam. Öğretmen ısrar ederse, “resmî e-Okul ve okul WhatsApp’ı yeter, üçüncü parti Google’a çocuğumun adını vermem” derim. Bu cümle haklıdır.

---

# 4. Rol: Millî Eğitim Bakanlığı resmî koordinatörü

Görevim: okullarda hangi aracın durabileceğine, hangisinin e-Okul / MEBBİS / KVKK / çocuk koruma çerçevesinde **tavsiye bile edilemeyeceğine** karar vermek. SınıfCepte’nin hukuk metni “MEB’in resmî ürünü değildir” der. Doğru. Arayüz aksi yönde konuşur. Bu, koordinatör olarak en ağır red gerekçemdir.

## 4.1 Yanıltıcı resmîlik

- Menü: “**MEB** Çalışma Takvimi”
- Katılım PDF: “**resmî** A4”
- Karne motoru: “**e-Okul uyumlu**”
- Evrak: zümre tutanağı, BEP, veli toplantısı tutanağı — **üretilmiyor**, ama isimleri resmî evrak adları
- Müfredat: “resmî Maarif kazanımları”
- Kullanım koşulları: “Millî Eğitim Bakanlığı’nın resmî bir ürünü değildir”

Öğretmen odasında kimse kullanım koşullarını okumaz. İkonu, “MEB” yazısını, “e-Okul” kelimesini okur. Bu, 6502 ve reklam mevzuatı açısından **yanıltıcı ticari uygulama** riskidir; bakanlık açısından “okulda resmî sandılar” krizidir.

Koordinatör tavsiyesi: **isim, ikon, evrak başlığı ve PDF antetinden MEB / e-Okul / “resmî” kelimeleri çıkmadıkça** hiçbir okul genelgesine giremez. Kazanım veri setinin kaynak lisansı da sorulur: TYMM / DÖGM tabloları işlenmiş kopya mı, izinli mi?

## 4.2 e-Okul’un yanına paralel sistem

Bakanlığın duruşu (fiilî): yoklama, not, devamsızlık, resmî evrak **e-Okul’dadır.** Üçüncü parti, öğretmenin işini kolaylaştırabilir; e-Okul’un yerine geçemez, e-Okul verisini izinsiz çekemez, “e-Okul’a aktarım” vaat edemez.

Bu uygulama:

- Yoklama almaz (doğru; kural yazılmış).
- Katılım ve “performans puanı” üretir; WhatsApp ve PDF ile okul dışına çıkarır. Bu, **kayıt dışı değerlendirme arşividir.** Rehberlik, disiplin, veli şikâyeti, dava dosyasında bu PDF’ler ortaya çıkarsa, okul “bizim sistemimiz değil” demek zorunda kalır — ama öğretmen okul saatinde, okul telefonunda üretmiştir.
- e-Okul listesini PDF/Excel’den okur. Bu, öğretmenin indirdiği dosyadır; API ihlali değildir. Yine de öğrenci listesinin üçüncü parti SQLite’a yerleşmesi, okul müdürünün KVKK envanterine girmelidir. Girmiyordur, çünkü müdür bu uygulamayı tanımaz.
- “e-Okul uyumlu karne görüşü” cümlesi, öğretmeni e-Okul’a yapay metin yapıştırmaya teşvik eder. Pedagojik denetim dışıdır.

Paralel veli kanalı (duyuru, mesaj, randevu) e-Okul veli bildirimi / okul SMS’i ile rekabet eder. Bakanlık “tek resmi kanal” ister. Okul müdürü iki kanalı birden yönetemez; veli “hangisi resmî?” diye sorar.

## 4.3 Çocuk verisi, özel nitelikli veri, işleme şartı

Öğrenciler küçüktür. KVKK + çocuklara yönelik hizmetler:

- **Veri sorumlusu kim?** Uygulama sahibi mi, öğretmen mi, okul mu? Gizlilik metni “öğrenci verisinin büyük bölümü öğretmendedir, uygulama sahibi sorumlusu olmaz” çizgisine yatar (`database_helper.dart` yorumu). Bu, hukuken iddialı ve muhtemelen **yanlış**tır. Uygulama, veli bağını, adı, numarayı, mesajı Firebase’de (Google) tutuyorsa işleyen taraftır. Aydınlatma, açık rıza, VERBIS, yurt dışı aktarım (Google / ABD veya başka bölge) belgelenmeden **okul bahçesine giremez.**
- Öğrenci numarası buluttadır; politika aksini söyler. Yanlış aydınlatma, rızayı geçersiz kılar.
- Katılım / davranış yıldızı: kişilik değerlendirmesi. Veli uygulamasına gitmese bile öğretmen cihazında ve WhatsApp’ta dolaşır.
- Durum bildirimi: ilaç türü kaldırılmış (doğru; sağlık verisi özel nitelikli). Erken çıkış / geç kalma duruyor. Saklama 30 gün, **istemci temizlik.** Öğretmen uygulamayı açmazsa süre işlemez. KVKK “süre bitince silinir” iddiası teknik olarak teslim edilmemiştir.
- Mesaj/duyuru 365 gün: yine istemci. Sunucu TTL yok. Functions yok.
- Rıza kaydı `KvkkConsentService` ile cihazda. Kullanıcı kendi rıza geçmişini göremez. Denetimde “rıza var” denemez; telefonda JSON vardır.

Okul yöneticisi paneli: custom claim + aynı okul. Öğretmen okulunu **listeden seçer**, istihdam kanıtı yoktur. Sahte okul seçen biri, o okulun öğretmen dizinini okur (ad, branş, e-posta). Bu, MEB okul dizininin gayriresmî kopyası + öğretmen PII sızıntısıdır.

## 4.4 Güvenlik — okula önerilemez seviye

Koordinatör olarak “öğretmenler kullansın” demem, şu saldırı yüzeyini kabul etmem demektir:

1. **Veli kimliği = Google oturumu.** `isParent()` yorumu açık: claim yazılamadığı için her giriş yapmış kullanıcı “veli” sayılır. Asıl koruma bağ kaydı olmalıydı. Bağ kaydı **kanıtsız yazılır.**
2. Kural testleri, token olmadan `parent_links` + `parent_class_access` yazmayı **başarı** kabul eder (`test_rules/rules.test.mjs` bölüm 16). Ardından duyuru, kadro, mesaj. Bu, “onarım” diye açılmış bir kapıdır. Kapı hâlâ açıktır.
3. `parent_class_access` oluşturma: doküman kimliği `{uid}_{classCloudId}`. `classCloudId = cls_{öğretmenUid}_{1..n}`. Öğretmen UID’si okul dizininden. Sınıf odası tahmin edilebilir. Duyuru okuma yetkisi **kod çalmadan** alınabilir.
4. `parent_tokens` `get` her giriş yapmış kullanıcıya açık. Kod uzayı ~9000/sınıf. Tuz kaynakta. Hash önceden hesaplanır. Rate limit yok. App Check yok.
5. Kadro `allow read: if request.auth != null`. Tahmin edilen sınıf yolunda **tüm giriş yapmış kullanıcılar** kadroyu okur.
6. Admin portal: `auth_gate.js` rolü `localStorage`’da tutar, varsayılan **süper admin.** `file://` ile açılır. README bunu “sıfır kurulum” diye satar. Müfredat/takvim üretim verisine giden yol, tarayıcı hafızası ve isteğe bağlı hosting’dir. Kimlik doğrulama yok.
7. Cihaz: şifresiz SQLite, uygulama kilidi yok, yedek yok. Öğretmen telefonu kaybı = tüm sınıf listesi + veli telefonları kaybı **ve** olası sızıntı.
8. Release debug-imzalı. Herkes aynı debug anahtarıyla “resmî” APK üretebilir.

Bakanlık siber güvenlik birimi bu listeyi görürse, “kullanmayın” genelgesi çıkar. Ben o genelgeyi beklemem; şimdi derim.

## 4.5 Ölçek ve eşitlik

Türkiye’de öğretmen cihaz çeşitliliği: eski Android, küçük ekran, veri paketi kısıtlı, Google hesabı olmayan veli, Doğu’da zayıf şebeke. Offline-first bu yüzden doğrudur. Ama veli köprüsü **çevrimiçi Google** ister. Google’sız veli = dışarıda. Bu, “her çocuk” ilkesiyle çelişir.

iOS adı “Sinifcepte”, Android “sinifcepte”. Mağaza vitrini amatör. Okul genelgesine girecek araç böyle durmaz.

Kazanım seti ve takvim, bakanlığın kendi yayınladığı verinin kopyasıdır. Güncelleme yolu senkron tiyatrosudur. Yanlış/eski kazanım öğretmeni yanlış müfredata götürür; “uygulama MEB’den geldi sandım” der. Sorumluluk kimin?

**Koordinatör kararı:** Tavsiye yok. Pilot yok. “Öğretmen kendi inisiyatifiyle indirsin” bile, okul idaresine “öğrenci listesini üçüncü partiye yüklemeyin, veli grubuna katılım dökümü atmayın, MEB logosu/e-Okul ibaresi kullanmayın” denir. İsim benzerliği ve “resmî” dili düzeltilemeden, KVKK dosyası ve güvenlik deliği kapanmadan, **hiçbir il/ilçe MEM yazısı çıkarılamaz.**

---

# 5. Kanıt dosyası

## 5.1 Bug’lar ve yalanlar (öncelik sırası)

| # | Bulgu | Kanıt | Etki |
|---|---|---|---|
| B1 | Yedek düğmesi dosya yazmaz, başarı gösterir | `app_drawer.dart` `_showBackupDialog` | Veri kaybı + hukuki |
| B2 | Evrak PDF’i yok, snackbar var | `documents_hub_view.dart` | Güven kaybı, BEP adı istismarı |
| B3 | Senkron veri indirmez, “güncellendi” der | `sync_service.dart` | Yanlış müfredat/takvim |
| B4 | Zorunlu güncelleme uygulamayı kilitlemez | `academic_calendar_screen.dart` snackbar | Kırık sürüm sahada kalır |
| B5 | Destek talebini admin okuyamaz | `firestore.rules` `support_requests` | Destek ölü |
| B6 | Veli hesap silme UI’da yok; servis bulutu silmez | `parent_lifecycle_service.dart` vs profil | KVKK md. 7 ihlali |
| B7 | Öğretmen hesap silme yok | profil / auth | Play + KVKK |
| B8 | Gizlilik: “öğrenci no cihazda” — yalan | `legal_document_screen.dart` vs `cloud_token_repository.dart` | Yanlış beyan |
| B9 | Bağlanma KVKK metni “gelişim raporu” vaat eder | `parent_student_connect_screen.dart` | Sakat rıza |
| B10 | Token `statusText` süresiz kodda “X gün kaldı” | `parent_token_model.dart` (`noExpiry` = 2099) | Öğretmeni yanıltır |
| B11 | Release debug keystore | `android/app/build.gradle.kts` | Mağaza + sahte APK |
| B12 | Android görünür ad `sinifcepte`; iOS `Sinifcepte` | manifest / Info.plist | Marka |
| B13 | `POST_NOTIFICATIONS` yok | Android manifest | Android 13+ bildirim ölür |
| B14 | Sınıf ekleme çift UI, birinde uzunluk sınırı yok | `class_list_screen` vs `add_class_dialog` | Tutarsız doğrulama |
| B15 | Sınıf adı her tuşta rewrite | `class_list_screen.dart` | UX bug |
| B16 | Veli telefonu toplanır, öğretmen rehberine bağlanmaz | connect + `parentPhone` | Gereksiz PII |
| B17 | `deleteParentSelfAccount` yalnızca testte | grep | Ölü kod |
| B18 | Mesaj çevrimdışı kuyruğu yok | iletişim deposu | Kayıp mesaj |
| B19 | Saklama süresi istemci temizlik, limit 50 | `cloud_communication_repository.dart` | TTL yalanı |
| B20 | `local_desktop` / `local_teacher` isim sapması | welcome vs CloudIds | Masaüstü kırılgan |
| B21 | README varsayılan Flutter şablonu | `README.md` | Devretilemez proje |
| B22 | PRD hâlâ yoklama satar | `docs/01-PRD.md` | Kapsam kaos |

## 5.2 Güvenlik

| # | Bulgu | Neden ağır |
|---|---|---|
| S1 | `parent_links` / `parent_class_access` create: token kanıtı yok | IDOR. Test 16 bunu yeşil sayar. |
| S2 | `isParent() = auth != null` | Rol yok, oturum var. |
| S3 | `parent_tokens` get herkese; 4 hane + tuz kaynakta; rate limit yok | Kaba kuvvet. |
| S4 | Token `Random()` (kriptografik değil) + 9000’lik uzay | Entropi şaka. |
| S5 | Kadro: `request.auth != null` okuma | Sınıf yolu tahmininde PII. |
| S6 | Okul dizini: istihdam kanıtı yok | Sahte öğretmen, meslektaş e-postası. |
| S7 | App Check yok | Anahtar + emülatör + script. |
| S8 | Functions yok | Sunucu doğrulaması, TTL, FCM, claim, hız sınırı yok. |
| S9 | Admin portal `localStorage` rol, varsayılan super | Müfredat/takvim üretim hattı. |
| S10 | SQLite şifresiz, uygulama PIN’i yok | Fiziksel erişim = tüm sınıf. |
| S11 | İstemci içerik filtresi ve mesaj saati | Atlatılır; kuralda yok. |
| S12 | Bütçe freni istemci | Fatura koruması değil, iyi niyet. |
| S13 | `staff` okuma kuralı `auth \|\| parentHasClass` | `\|\|` gereksiz geniş. |
| S14 | OAuth client id Info.plist’te | Beklenen, ama reverse engineering yüzeyi. |
| S15 | WhatsApp sınıf dökümü | Teknik açık değil; tasarlanmış sızıntı. |

**S1’in düzeltilmesi:** `parent_links` create, geçerli ve tükenmemiş `parent_tokens/{hash}` varlığına + ikinci faktör hash’ine bağlanmalı. `parent_class_access` yalnızca mevcut `parent_links` ile ve o bağın `classCloudId`’si ile yazılabilmeli. Token `get` hız sınırlı olmalı (Functions). 4 hane bırakılmamalı.

Bu kapanmadan “veli portalı güvenli” cümlesi kurulamaz.

## 5.3 Maliyet ve fatura

Korunanlar: offline-first, no listener, delta, batch, token-after-use silme, Remote Config manifest.

Delikler:

- İstemci freni ≠ sunucu tavanı. Blaze varsayılan durdurmaz.
- Projeksiyon dar. Gerçek yazma: dizin yenileme her açılış, kadro, randevu, durum, destek, purge okuma+silme.
- 1000 okul senaryosu operasyonel olarak fantezi; dolar cinsinden ucuz olsa da Gmail destek ve elle claim ile taşınmaz.
- Reklam geliri slaytı, AdMob yokken zararlı iyimserlik.
- `BUDGET.md` (500) ile kod (1500) çelişkisi: hangi rakam alarmı?
- Ücretsiz katman ~250 öğretmen (modelin kendi iddiası). “Türkiye geneli” ilk ayda Blaze + kredi kartı demektir. Kart bağlı, App Check yok, 4 haneli token kaba kuvveti: fatura saldırısı mümkün.

Katılım verisini veliye açmak, `maliyet.md`’nin kendi hesabıyla yazmaları katlar. Ürün olgun değilken açılmamalı — bu noktada maliyet belgesi haklı. Asıl sebep KVKK ve UX.

## 5.4 Validation (4 katman iddiası vs gerçek)

AGENTS.md 4 katman ister: UI, provider, repository, SQLite.

| Alan | UI | Provider | Repo | DB | Not |
|---|---|---|---|---|---|
| Öğrenci ad/soyad | sınır + boş kontrol (dialog) | zayıf | zayıf | TEXT | İçe aktarma bu dialog’dan geçmez |
| Okul no | 5 hane, >0, sınıf içi tekil | kısmen | tekil iddia | kısıt? | Excel yolu ayrı |
| Sınıf adı | bir UI’da 50, diğerinde yok | sanitizer | — | — | Canlı rewrite zararlı |
| Telefon | veli bağında maske; rehberde 11 hane | PhoneFormatter WhatsApp’ta | “abc” elle? | TEXT | Tutarsız |
| Not 0–100 | quiz yolu düzelmiş | parseScoreInput | — | — | Diğer ekranlar aynı servisi kullanmalı |
| Mesaj 4000 | sayaç var | ContentGuard istemci | kuralda size yok | — | Sunucu boyutsuz |
| Duyuru 100/2000 | var | — | kuralda yok | — | |
| Destek 120/2000 | var | — | **kuralda var** | — | Nadir doğru örnek |
| Token | format normalize | hash | kural get açık | — | Entropi yok |
| KVKK kutusu | bağlanmada zorunlu | log Prefs | — | — | Kullanıcı göremez |

Firestore kuralları mesaj gövdesi uzunluğunu, duyuru boyutunu, `parent_links` alan şemasını **neredeyse doğrulamaz.** İstemci iyi davranırsa sorun yok; kötü istemci 1 MiB doküman basar.

Türkçe arama: `trFold` yazılmış, okul aramasında kullanılıyor. Öğrenci listesi debouncer’a bağlanmış (test kaynak arıyor). Tüm `toLowerCase` tuzaklarının kapandığı **kanıtlı değil.**

Tarih: sınav geçmişe alınabilir. İdare raporu bozar, engel yok.

## 5.5 Erişilebilirlik, yayın, marka

- `Semantics`: 0.
- Yatay / 320 dp / font scale: sistematik test yok.
- Widget/E2E: yok.
- Play: debug imza, küçük harf uygulama adı, gizlilik formu (öğrenci adı + numara bulutta beyan edilmeli — numara hâlâ “yok” deniyor).
- Apple: isim, gizlilik etiketleri, hesap silme (Guideline 5.1.1).
- Çocuk: öğretmen uygulaması olsa da veli tarafı çocuk verisi işler. Families policy.
- `applicationId` üzerinde Flutter TODO yorumu duruyor. Bu, “yayına hazırız” diyen bir repoda olamaz.

---

# 6. Dört rolün ortak red listesi — kapanmadan yayın yok

Bunlar “backlog” değil, **kapı**dır.

1. Sahte yedek, sahte evrak, sahte senkron **sökülecek veya gerçekten yapılacak.** Yalan snackbar kabul edilemez.
2. `parent_links` / `parent_class_access` create, geçerli token kanıtına bağlanacak. Test 16’nın yeşil saydığı saldırı kırmızı olacak.
3. Gizlilik + bağlanma KVKK metni kodla birebir: öğrenci no buluttaysa yazılacak; gelişim raporu yoksa vaat edilmeyecek. Veri sorumlusu, yurt dışı aktarım, saklama (sunucu TTL), hesap silme yolu.
4. Uygulama içi hesap silme (öğretmen ve veli): Auth + Firestore + yerel DB.
5. Release imzası, mağaza adı, `POST_NOTIFICATIONS`, gerçek zorunlu güncelleme kapısı.
6. Destek: ya admin okuma kuralı + gerçek nöbet, ya yalnızca `mailto` ve “yanıt garantisi yok”. Firestore’a ölü kuyruk bırakmak yasak.
7. MEB / e-Okul / “resmî” dili antet, PDF, menü ve karne motorundan çıkacak.
8. Sınıf WhatsApp dökümü varsayılan kapanacak; açık rıza ve “yalnızca kendi çocuğu” yolu olmadan grup listesi üretilmeyecek.
9. Token: kriptografik rastgele, uzunluk, rate limit, App Check.
10. PRD / mimari / README ölü dokümanları silinecek veya gerçeğe çekilecek. “Yoklama yok” tek kaynak olacak.
11. Yedek **gerçek** olmadan öğretmenlere “sınıfını yükle” denmeyecek.

---

# 7. Ne işe yarıyor? (inkâr etmeyeyim)

Sertlik, her şeyin çöp olduğunu gerektirmez. Aşağıdakiler çekirdek olarak durabilir:

- Offline-first ve “not buluta çıkmasın” kararı, Türkiye okul gerçeğine uygundur.
- Kazanım veri seti + sıkıştırma, öğretmen asistanının **asıl** ürünüdür.
- Oturma planı, sınıf listesi, e-Okul dosyasından içe aktarma niyeti doğrudur (PDF Türkçe kırılması ayrı).
- Not 0–100 ayrımı, bütçe freni fikri, token’ı düz yazmama, Crashlytics tamponu, veli onboarding’i, destek formunun en azından bağlanması — önceki denetimden kalan yamalar.
- Maliyeti dinleyiciyle patlatmama kararı olgundur.

Bunlar bir **MVP öğretmen defteri** eder: liste, program, kazanım, sınav, oturma, **çalışan yedek.** Veli köprüsü, evrak fabrikası, “Türkiye geneli”, reklam P&L, MEB dili — şişmedir.

Şişme, çekirdeği öldürür. Sahte düğme, doğru mimariden daha çok zarar verir.

---

# 8. Son söz — dört imza

**Proje yöneticisi:** Bu repoyu “baseline” diye dondurmam. Baseline, yalan geri bildirim ve açık kural deliği üzerine kurulmaz. Kapsamı kes: öğretmen defteri + gerçek yedek. Veliyi ikinci ürüne bırak. Play’e debug imzayla çıkma. 1000 okul slaytını çek.

**Öğretmen:** Gerçek sınıfımı yüklemem. Yükleyen meslektaşıma da yüklememesini söylerim — telefonunu düşürene kadar değil, yedek düğmesine **ilk** bastığı anda pişman olur.

**Veli:** Google’a çocuğumun adını, bu kadar az karşılık için vermem. Öğretmen “uygulamadan bakın” derse e-Okul ve yüz yüze isterim.

**MEB koordinatörü:** Okul genelgesine, zümre kararına, “öğretmenler indirsin” cümlesine giremez. Resmî görünümlü gayriresmî arşiv + çocuk verisi + açık bağ kuralı. Tavsiye: kullanılmasın.

— Grok, 31 Ağustos 2026

# SınıfCepte — Mantık ve Çıktı Denetimi

**Dosya:** `grok_inceleme2.md`  
**Tarih:** 19 Eylül 2026  
**Denetçi:** Grok (salt okunur; koda dokunulmadı)  
**Kapsam:** Dışarıya giden her PDF/çıktı + her iş modülünün çalışma mantığı  
**Bu rapor ne değildir:** Güvenlik, maliyet, pazar. Onlar `grok_inceleme.md`. Burada soru şudur: *öğretmenin işini doğru yapıyor mu, yoksa kâğıda yalan mı basıyor?*

Yöntem: üretici metotlar, çağrı noktaları ve veri kaynakları satır satır. Tahmin yok. “İşe yarar” notu, öğretmenin o PDF’i **idareye, veliye veya teftişe** verdiğinde yaşanacak şeye göredir.

---

## Karar (tek sayfa)

Uygulama bir **evrak fabrikasıdır**. Fabrika çalışıyor: bayt üretir, Türkçe font basar, A4 çıkar. Sorun miktar değil, **ne basıldığı**.

Üç sınıf çıktı var:

| Sınıf | Ne | Öğretmen basınca |
|---|---|---|
| **A — Gerçek veri** | Sınıf listesi, oturma planı, veli telefonu (varsa), katılım günlük tutanak, BEP (modüldeki plan), kulüp üye listesi, yıllık/günlük plan (paket veri), sınav analizi, rehberlik takip çizelgesi | Kullanılır. Taslak / arşiv olduğu söylenmeli. |
| **B — Boş şablon** | Değerlendirme çizelgesi, tanıma fişi, görüşme formları, gezi izni, öğretmen dosyasının çoğu, pano | Kalemle doldurulursa işe yarar. “Otomatik dolduruldu” sanılırsa zarar. |
| **C — Uydurma dolu** | Veli toplantı **kararları**, zümre gündeminin hazır “karar verildi” cümleleri, kulüp dağılımında boş kulüp + “Üye”, BEP takip formundaki sahte RAM tanısı (ölü kod), karne görüşünde oturum yokken 100 puan, **kaydedilen katılımda gelene varsayılan 3 yıldız / ödev yaptı** | İdareye verilirse sahte evrak. En tehlikeli sınıf. |

Görünür menüde **yaklaşık 40 ayrı PDF**, öğretmen dosyası 13 belge sayılırsa **50’ye yakın üretim noktası**. Kullanıcının “32–33” tahmini, dosya içindeki 13’ü tek kart sayınca tutar. Sayı şişmiş; **birbiriyle konuşmayan çiftler** asıl sorundur.

---

# 1. PDF envanteri

Her satır: öğretmenin gördüğü ad → üretici → veri → işe yararlık.

Ölçek:

- **Evet** — bas, kullan (çekince varsa notta).
- **Kısmen** — şablon veya yarım veri; kalem şart.
- **Hayır** — basma; yanıltır veya başka modülle çelişir.
- **Ölü** — kod var, UI çağırmaz.

Uydurma belge kodları (`MEB.ÖĞR.01`, `MEB.ÖD.09` …) **hiçbir MEB matbu kodu değildir.** Antette durmaları, çıktıyı “resmî form” gibi gösterir. Bu, envanterin tamamına yayılan bir mantık hatasıdır; her satırda tekrar etmiyorum.

---

## 1.1 Sınıf evrakları (`classroom_documents_pdf_generator.dart`)

| # | Çıktı | Metot / giriş | Veri | İşe yarar mı? | Mantık |
|---|---|---|---|---|---|
| 1 | Sınıf öğrenci listesi | `generateStudentListPdfBytes` · Sınıfım | Öğrenci adı, no, cinsiyet. İmza sütunu boş. | **Evet** | Okul no sıralı. Yıl sınıf kaydından. En temiz “liste bas” işi. |
| 2 | Ders içi değerlendirme çizelgesi | `generateEvaluationSheetPdfBytes` | Yalnız ad/no. 10 etkinlik + ödev + proje + sözlü + katılım + dönem notu **boş**. | **Hayır (dolu rapor olarak)** / şablon olarak kısmen | Quiz, proje, katılım modüllerinde veri var; çizelge **hiçbirini okumaz**. Öğretmen “notlar buraya aktarıldı” sanır. |
| 3 | Haftalık nöbet çizelgesi | `DutyScheduleEditorModal` → `generateCustomDutySchedulePdfBytes` | Okul no sırasına göre otomatik dağıtım. Kaydedilmez. | **Kısmen** | Aynı çocuklar sınıfta az kişi varsa haftanın her gününe döner. Dağıtım kalıcı değil; yarın tekrar basınca başka sıra yok, aynı algoritma. Sınıf nöbeti ≠ öğretmen dosyasındaki nöbet (öğretmen nöbeti boş şablon). |
| 4 | Veli davetiyesi (8’li kupon) | `ParentInvitationEditorModal` | Tarih/saat/yer öğretmen girer. | **Evet** | Kesme kuponu pratik. Öğrenci adı kuponlarda yok — “velisi bulunduğum …” genel metin. Yanlış eve gitme riski düşük; kişiselleştirme yok. |
| 5 | Sınıf kuralları afişi | `ClassroomRulesEditorModal` | Varsayılan 10 kural veya düzenleme. | **Evet** | Pano işi. “MEB kuralı” iddiası abartı; okul içi afiş olarak yeter. |
| 6 | Veli toplantı tutanağı | `ParentMeetingEditorModal` → `generateParentMeetingMinutesPdfBytes` | Gündem + **hazır karar metinleri** varsayılan dolu. İmza listesi öğrencilerden. | **Hayır — C sınıfı** | Toplantı yapılmadan “ödev takibi günlük yapılsın”, “SMS atılsın”, “kitap bağışı” **karar verilmiş** basılır. Editör bu metinleri açılışta doldurur (`parent_meeting_editor_modal.dart:52-66`). Öğretmen “yazdır”a basarsa sahte tutanak çıkar. |
| 7 | Veli görüşme formu | Rehberlik modalı | Öğrenci seçilirse ad/no; görüşme özeti boş. | **Kısmen** | Doldurulacak form. Veli adı uygulamadaki `parentPhone` kaydından **çekilmez**. |
| 8 | Öğrenci görüşme tutanağı | Aynı modal | Aynı. | **Kısmen** | Rehberlik arşivi için şablon. Kaydetmez; her seferinde boş. |
| 9 | Öğrenci tanıma fişi | Aynı modal | Ad/no/sınıf/telefon. `notes` alanı **sağlık satırına** basılır (not her zaman hastalık değildir). Anne/baba/meslek boş. | **Kısmen** | Yanlış sütun: “çok konuşkan” sağlık gibi durur. |
| 10 | Gezi veli izin belgesi | Aynı modal, 2 kupon/A4 | Varsayılan **«Anıtkabir ve Müze Gezisi» / Ankara**. Öğretmen değiştirmezse yanlış gezi basılır. Öğrenci adı boş (`........... isimli öğrenci`). «UYGUNDUR - Okul Müdürü» metni imzadan önce durur. | **Kısmen** | 2 kupon; 30 öğrenci için 15 sayfa. Varsayılan gezi C sınıfına kayar. |
| 11 | Sosyal kulüp dağılımı | `generateClubDistributionPdfBytes` | Ad/no dolu. **Kulüp sütunu boş.** Görev sütunu herkese `"Üye"`. | **Hayır** | Kulüp modülü `club_members` tutar (okul düzeyi, yönetmelik madde 8/4). Bu PDF o tabloya **bakmaz**. Dağılım çizelgesi dağıtım değildir. |
| 12 | Acil durum & veli iletişim | `generateEmergencyContactListPdfBytes` | Telefon varsa basar. | **Evet / kısmen** | Telefonsuz satır boş. Ayrı `ParentContactsPdfGenerator` neredeyse aynı iş (çift). |
| 13 | Devamsız öğrenci takip | `generateAbsenceFollowupPdfBytes` | `absence_followup` kayıtları; boşsa boş çizelge. | **Evet** | Katılımın “geç/izinli” alanından **bağımsız**. İki gerçek: ders içi geliş + e-Okul devamsızlık takibi. Karışıklık kasıtlı (yoklama yasağı) ama öğretmen “yoklama PDF’i” sanır. |
| 14 | BEP dönemlik gelişim formu | `generateBepTrackingFormPdfBytes` | Varsayılan hedefler + **`ramDecision ?? 'Hafif Düzey / Kaynaştırma Eğitimi'`** | **Ölü + tehlikeli** | UI artık `BepListView` açıyor (`counseling_interview_modal.dart:323-334`). Metot duruyor. Çağrılırsa tanı uydurur. Özel eğitim evrakında şaka değildir. |

`generateDutySchedulePdf` ve `generateParentMeetingMinutesPdf` sarmalayıcıları da duruyor; hub editör kullanıyor. Ölü yol, eski otomatik dağıtımı (ilk 10 öğrenci, 2/gün) hâlâ içerir.

---

## 1.2 Oturma ve veli rehberi

| # | Çıktı | Veri | İşe yarar mı? | Mantık |
|---|---|---|---|---|
| 15 | Oturma planı | Gerçek sıra/koltuk. Cinsiyete göre pembe/mavi. | **Evet** | Tarih satırı `202...` (`seating_plan_pdf_generator.dart:318`). Katılım ekranındaki “oturma ızgarası” **ayrı** görünümdür; iki plan sapabilir. |
| 16 | Veli iletişim çizelgesi | `parentPhone` biçimli. | **Evet** | #12 ile çift. Biri “acil durum + sağlık”, biri rehber. Sağlık alanı çoğu öğrencide boşsa ikisi de telefon listesidir. |

---

## 1.3 Ders içi katılım raporları

| # | Çıktı | Veri | İşe yarar mı? | Mantık |
|---|---|---|---|---|
| 17 | Günlük katılım tutanağı | O oturumun yıldız, ödev, defter, geliş, not. | **Evet** | İşaretlenmemiş alan `-`. Eski “hepsi yaptı” varsayılanı burada düzelmiş. Antet yine “T.C. / MEB”. İdare yoklama sanır. |
| 18 | Dönem sonu idare çizelgesi | Kümülatif oranlar. | **Kısmen** | Depo oranı doğru hesaplıyor (işaretlenen ders payda, veri yoksa **0**). PDF üreticisi anahtar yoksa **`?? 100.0`** (`participation_cumulative_pdf_generator.dart:76, 192, 334, 407`). Depo dolu giderse 100’e düşülmez; başka çağrı boş map verirse sınıf “mükemmel” basılır. |
| 19 | Veli toplantısı kılavuzu | Aynı kümülatif. | **Kısmen** | Veri yoksa modal uyarıyor (iyi). Veri varken “resmî gelişim” dili, e-Okul karne değildir. |
| 20 | Bireysel öğrenci kartı | Tek öğrenci özeti + şablon cümle. | **Kısmen** | `_generateSmartFeedback` öğretmen notu yoksa istatistikten cümle uydurur. Pedagojik şablon; o çocuğun gerçek cümlesi değil. |

---

## 1.4 Planlar (TYMM)

| # | Çıktı | Veri | İşe yarar mı? | Mantık |
|---|---|---|---|---|
| 21 | Ünitelendirilmiş yıllık plan | APK’daki kazanım paketi, öğretmen/okul künyesi. | **Evet (taslak)** | Ekran “zümre onayı gerekir” diyor. PDF zümre imzası boş. Yayınevi seçimi öğretmenin **gerçek kitabından** bağımsız olabilir. Hafta üretimi `PlanWeekBuilder` ile günlükle hizalanmış (eski sapma kapanmış). |
| 22 | Günlük / ders işleniş planı (hafta) | Aynı paket, tek hafta. | **Evet (taslak)** | TYMM işleniş iskeleti. Öğretmenin o hafta gerçekten işlediği kazanım notu (`outcome_notes`) PDF’e **girmez**. |
| 23 | 36 haftalık günlük plan kitapçığı | Tüm yıl. | **Kısmen** | Ağır PDF. Cepte sohbet de bunu basar. Yıl başında bir kez “dosyaya koydum” işi; güncellenmez. |

Yıllık ve günlük plan **öğretmenin sınıf listesine bağlı değil.** Kademe/sınıf/branş/yayınevi ayrı seçilir. 8/A okutan, 7. sınıf MEB kitabının planını basabilir.

Yıl fallback’leri **birbirini yalanlar:** yıllık plan `academicYear` yoksa `'2026-2027'` (`annual_plan_pdf_generator.dart:53`); günlük plan `'2024-2025'` (`daily_plan_pdf_generator.dart:55, 156, 447`). UI yıl verirse sorun yok; Cepte veya başka yol yıl vermezse iki belgede iki öğretim yılı.

Mantık hatası: “benim sınıfımın planı” değil, “seçtiğim müfredatın planı.”

---

## 1.5 Kurul tutanakları (zümre / ŞÖK) — derin kesit

Bu, kullanıcının örneklediği çıktı. Ayrıntı hak ediyor.

**Giriş:** Diğer Evraklar → Kurul Tutanakları → Zümre veya ŞÖK.  
**Kod:** `council_minutes.dart`, `council_minutes_pdf_generator.dart`, `council_minutes_editor_modal.dart`.

### Ne doğru

- Yönerge: ŞÖK ilkokul / okul öncesinde kurulmaz. Kod keser (`sokPermitted`).
- Gündem maddeleri yönergedeki olağan üç toplantıya göre üretilir (sene başı / 2. dönem / yıl sonu).
- Karar dili ipucu: “görüşüldü, temenni edildi” yasak.
- ŞÖK’e ikinci sayfa öğrenci ızgarası: kişilik/sağlık/ekonomi **boş** — elle doldurulacak diye yazıyor.
- Taslak olduğu altta: “Arşiv kopyasıdır. Gündem ve kararlar e-Kurul ve Zümre Modülüne işlenir.”

### Ne yanlış

**1. “Karar verildi” toplantıdan önce basılıyor.**

`buildAgenda` her maddeye hazır karar cümlesi koyar:

> “Yıllık ve ders planlarının yürürlükteki programa göre hazırlanmasına karar verildi.”

Öğretmen maddeyi düzenleyebilir. Varsayılan, **toplantı yapılmış gibi** dolu tutanaktır. Yazdır = imzalanmamış ama kararlı evrak.

**2. Zümre üyeleri yanlış evrenden geliyor.**

`resolveAttendees` zümre için `staff` listesini branşa göre süzüyor. `staff` nereden? **O şubenin bulut kadrosu** (`class_rooms/{cls_...}/staff`), 2 saniye timeout.

Zümre, yönergede **aynı dersi okutan öğretmenlerdir** (okuldaki tüm 8. sınıf matematikçiler). Kadro, **o şubeye giren branş öğretmenleridir** (8/A’nın matematik, fen, Türkçe’si).

Sonuç:

- Matematikçi zümre tutanağı basarsa listede fençi de durur (aynı şube kadrosu, branş süzülmezse — süzülür ama kadro boşsa).
- Kadro boş veya timeout: listede **yalnız kendisi, başkan**. Okuldaki diğer matematikçiler yok.
- Branş öğretmeninin “zümresi” asla okul zümre defterindeki isimler değildir; uygulama okul zümresini **bilmez**.

**3. Başkan otomatik “ben”.**

Kadro `isHomeroom` olanı başkan yapar; yoksa profil adı. Zümre başkanı çoğu okulda kıdemli öğretmendir, uygulamayı açan kişi değil.

**4. ŞÖK, sınıf öğretmeninin kadrosuna bağlı.**

ŞÖK için kadro doluysa şube öğretmenleri gelir — bu, zümreden **daha doğru** model. Kadro doldurulmamışsa yine tek imza. Branş öğretmenleri uygulamada “kadroma ekle” demediyse ŞÖK imza sirküsü yalan.

**5. Hub yanlış sınıf seçer.**

`DocumentsHubView` zümre için ilk rehber sınıfı (yoksa ilk sınıf) verir. Zümre sınıf belgesi değildir. 8/A seçiliyken “8. sınıflar zümresi” başlığı sınıf adından türeir (`gradeFromClassName`) — 5/B seçiliyse 5. sınıflar zümresi basılır. Branş öğretmeninin birden fazla kademesi varsa sessizce yanlış kademe.

**6. Toplantı no = dönem (1/2/3).**

Olağanüstü toplantı yok. İkinci sene başı toplantısı yine “1” olur.

**7. Sekreter boş.**

Yazman alanı boş metin. Zorunlu değil; imza sirküsünde yazman yoksa tutanak eksiktir.

**8. “MEB ürünü değil” ibaresi bilinçli silindi.**

Yorum: idarenin gözünde belgeyi geçersiz gösteriyordu. Yerine e-Kurul cümlesi. Dürüstlük, evrakın kabul görmesi için kısılmış. Öğretmen bunu e-Kurul yerine dosyaya koyarsa yönerge ihlali uygulamadan değil öğretmenden görünür; uygulama kolaylaştırmıştır.

**9. Öğretmen dosyasındaki zümre tutanağı ayrı ve boş.**

`TeacherFileDoc.zumreTutanagi` (`MEB.ÖD.09`): tarih/saat/gündem boş satırlar. Kurul editöründeki yönerge gündemi **yok**. Teftiş dosyasında iki zümre evrakı: biri boş şablon, biri dolu uydurma kararlı taslak. Öğretmen hangisini koyacağını bilemez.

**ŞÖK ızgarası:** e-Okul EK-5 değildir (cümle kaldırılmış). Boş sütunlar doğru. Başlık “ŞÖK ÖĞRENCİ DEĞERLENDİRME IZGARASI” idarede EK-5 sanılır. Kişilik/sağlık sütunu basılı evrakta durması, doldurulursa özel nitelikli veri kâğıda iner — KVKK `grok_inceleme.md`’de; burada mantık: uygulama veri tutmaz, kâğıt tutar.

**İşe yararlık:** **Kısmen, tehlikeli.** Gündem iskeleti yönergeye yakın. Üye listesi ve karar metni yanlış evrenden. e-Kurul’a işlenmeden dosyaya konmamalı. Öğretmen “zümreyi hallettim” sanır.

---

## 1.6 Öğretmen dosyası (13 belge, `teacher_file_pdf_generator.dart`)

Teftiş klasörü vaadi. Künye (okul, ad, yıl) gerçek. Gövde çoğu **boş çizelge**.

| # | Belge | Veri | İşe yarar mı? |
|---|---|---|---|
| 26 | Dosya kapağı | Ad, branş, okul, yıl | **Evet** |
| 27 | Atatürk köşesi | Vektörel silüet + hitap metni | **Kısmen** | Fotoğraf yok (telif kararı). Teftişte “portre” bekleyen müdür silüeti beğenmez. |
| 28 | İstiklâl Marşı | 10 kıta, ayrı test edilebilir metin | **Evet** | Bu, dosyanın en sağlam sayfası. |
| 29 | Gençliğe Hitabe | Tam metin | **Evet** |
| 30 | Kişisel bilgiler | Sicil, TC, mezuniyet — öğretmen doldurursa | **Evet** | Boşsa noktalı satır. TC kâğıtta; cihazdan çıkmama kararı PDF’de bozulur (öğretmen basınca). |
| 31 | Haftalık ders programı (dosya içi) | `dersler` tablosu | **Evet** | Schedule PDF (#50) ile çift. |
| 32 | Sınıf listeleri | Sınıf adı + **öğrenci sayısı**, isim yok | **Kısmen** | Teftiş “mevcut” ister; imzalı liste #1 ayrı. Burada isim yok. |
| 33 | Öğretmen nöbet çizelgesi | Gün adları, yer/saat **boş** | **Hayır (dolu olarak)** | Tahta nöbetçisi ve sınıf öğrenci nöbeti **üçüncü** gerçek. Öğretmen nöbet yeri uygulamada tutulmuyor. |
| 34 | Zümre tutanağı (dosya) | Boş şablon | **Hayır** | #24 ile çelişir. |
| 35 | Veli görüşme kayıt çizelgesi | Boş satırlar | **Kısmen** | #7 tek görüşme formu; bu defter. İkisi yazılmaz, ikisi de kaydetmez. |
| 36 | Yıllık plan kapağı | Ders/sınıf/onay bloğu, planın kendisi yok | **Kısmen** | Asıl plan #21. Kapak ayrı, içeriğe bağlı değil. |
| 37 | Gelişim ve kanaat formu | Boş | **Hayır (dolu olarak)** | Karne görüşü motoru (# analiz) ve katılım kartı (#20) ayrı. Bu form onları çekmez. |
| 38 | Ödev takip çizelgesi | Boş | **Hayır (dolu olarak)** | Katılım ödev durumu duruyor; bu çizelge kör. |

“13 resmî evrak” kartı, 5 gerçek + 8 boş/çift demektir. Toplu basım teftiş çantasını doldurur; müdür açınca yarısı çizgidir.

---

## 1.7 Belirli gün, pano, kulüp, BEP, rehberlik, program, sınav

| # | Çıktı | Veri | İşe yarar mı? | Mantık |
|---|---|---|---|---|
| 39 | Tören / etkinlik planı | Paket metin (sunucu, şiir). | **Evet** | Kürsü kâğıdı. Sınıf etkinliği bu PDF’de yok (yorum kasıtlı). |
| 40 | Kutlama / çalışma raporu | Öğretmen doldurur. | **Kısmen** | Müdüre verilecek özet. Boş basılırsa boş rapor. |
| 41 | Pano çalışması | Başlık + öğrenci alanı. | **Evet** | Pano kâğıdı. |
| 42 | Pano kurgu | Yerleşim motoru. | **Kısmen** | Tasarım çıktısı; okul yazıcısı A4/A3 sapması **ölçülmedi**. |
| 43 | Kulüp yıllık plan | Katalog 10 ay + düzenleme. | **Evet** | Yönetmelik evrakı. Okul kendi kulübünde katalog 0. |
| 44 | Kulüp üye listesi | `club_members` gerçek. | **Evet** | #11’in konuşması gereken yer burası. |
| 45 | Kulüp faaliyet raporu | Plan + öğretmenin ay log’u. | **Evet / kısmen** | Log boşsa “planlanan var, gerçekleşen yok” — dürüst. Yıl sonu evrakı ancak log tutulursa. |
| 46 | Kulüp dosya (bundle) | Üçü bir PDF. | **Evet** | Danışmanın yılı. |
| 47 | BEP gelişim raporu | Gerçek plan, hedefler, öğrenci. | **Evet (taslak)** | Eski “herkese aynı metin” varsayılanı yedek; seçim yoksa doldurur. RAM kararı öğretmenden. e-Okul BEP modülü yerine geçmez. |
| 48 | BEP kaba değerlendirme | Seçilen öğrenci + banka. | **Evet (taslak)** | Kaba değerlendirme formu. |
| 49 | Sınıf rehberlik planı takip | 36 hafta + öğretmen işaretleri. | **Evet** | “Dolaba konan Excel” yerine uygulama kaydı — doğru ürün kararı. Yalnız `isHomeroom` sınıfta. Branş öğretmeni göremez (bilinçli). |
| 50 | Haftalık ders programı | Gerçek dersler + zil. | **Evet** | Cumartesi/pazar yok. İkili öğretim / nöbet saatleri programda yoksa PDF’de de yok. |
| 51 | Sınav analiz raporu | Girilen soru puanları, dağılım. | **Evet** | Quiz/proje tablosundan **bağımsız**. Analiz ayrı model. Öğretmen quiz’e yazıp analizde tekrar girer. `PdfPreviewScreen` değil dosya+share; önizleme farklı. |

**Yok (modül var, PDF yok):**

- Quiz & sözlü çizelgesi — ekranda tablo, basılamaz.
- Proje/rubrik — “toplu PDF ölçek” `ProjeDetayı.md`’de var, kodda üretici yok.
- Kazanım carousel — notlar PDF değil.
- Veli mesaj / duyuru arşivi.

Bu boşluklar rastgele değil: evrak şişmiş, **not defteri** basılmamış. Öğretmenin idareye en çok verdiği şey (sözlü/quiz listesi) kâğıtsız.

---

## 1.8 Çapraz hastalıklar (tüm PDF’ler)

1. **Sahte MEB kodu.** `MEB.ÖĞR.01`, `MEB.DEĞ.02`, `MEB.TOP.04`, `MEB.KUL.09`, `MEB.ÖZG.07`, `MEB.ÖD.01–13`. Matbu numara gibi durur. Denetimde “hangi genelgenin eki?” sorusu.
2. **T.C. / Millî Eğitim Bakanlığı anteti.** Hukuk metni “MEB ürünü değil.” Kâğıt aksi konuşur. `grok_inceleme.md` pazar; burada mantık: öğretmen dosyaya koyunca okul evrakı olur.
3. **Modüller birbirinin PDF’ini doldurmaz.** Quiz→değerlendirme çizelgesi, kulüp üyesi→dağılım, katılım ödevi→öğretmen dosyası ödev, BEP planı→eski BEP takip PDF, zümre editörü→öğretmen dosyası zümre, program→öğretmen dosyası program (bu tek gerçek çift; diğerleri kopuk).
4. **Kayıt yok.** Görüşme, tanıma, toplantı kararı, nöbet dağıtımı PDF üretilir, SQLite’a yazılmaz. Yarın aynı form boş. Arşiv = öğretmenin kâğıdı.
5. **“Boş şablon” ile “dolu taslak” karışık.** Boş olan dürüsttür. Dolu varsayılan (veli kararları, zümre kararları, BEP RAM, kulüp “Üye”) yalandır.
6. **Önizleme iki yol.** Çoğu `PdfPreviewScreen` (45 sn). Sınav analizi ve veli rehberi `path_provider` + share. Öğretmen “neden bu farklı?” der; mantık yok, tarihçe.

---

# 2. Modüller — çalışma mantığı

Her bölüm: ne gerekir → kod ne yapar → mantık hataları → not.

---

## 2.1 Kazanım

**Gerek:** “Bu hafta bu derste ne işleyeceğim?” Paket + takvim + **benim sınıfım/kitabım**.

**Kod:** 1–12 seç, ders seç, 39 haftalık carousel. Tatil kartı. Favori. Arama. Not (`outcome_notes`) ayrı.

**Hatalar**

1. **Sınıfa bağlı değil.** 8/A kaydı varken kazanım ekranı kademe sorar.
2. **Kart tarihi formül, plan tarihi paket.** Carousel `getWeekDateRangeText(weekNumber)` (Eylül 2. Pazartesi’den). `PlanWeekBuilder` satırdaki `date_range_str`’i tercih eder. Aynı ders, ekranda 8–12 Aralık, PDF’de 1–5 Aralık.
3. **Aktif hafta da formül.** Resmî takvime bakmaz. Ağustos = 1. hafta. MEB açılışı kayınca “bu hafta” kayar.
4. **Dashboard branş kodunu uydurur.** Ders adı `"Matematik"` `subject_code` yazılır, yayınevi sabit `'MEB Yayınları'`. Paket kodu `MAT`, yayınevi okul türü. Kart boş veya yanlış.
5. **Yayınevi = paketteki etiket.** Eldeki kitap başka basım olabilir.
6. **Kazanım notu planda yok.**
7. **Admin Excel F5’te uçar.** Mobil APK tohumu.

**Not:** **Yarım.** Veri ve plan üreticisi toparlanmış; ekranın kendi takvimi hâlâ uydurma. Teftiş PDF’i ile carousel uyuşmayabilir.

---

## 2.2 Ders içi katılım

**Gerek:** Derste hızlı işaret, sonra veliye/idareye dürüst özet. Yoklama değil.

**Kod:** Yıldız 0–3, ödev/defter/geliş enum. **Devamsız** öğrenci `unknown` / 0 yıldız. **Gelen** öğrenci varsayılan **ödev yaptı + materyal tam + zamanında + 3 yıldız** (`classroom_participation_repository.dart:177-206`). Rozet, not, rastgele öğrenci, WhatsApp, kümülatif. Canlı ders: program + saat dilimi (`lessonClockProvider`).

**Hatalar**

1. **“İstisnayı işaretle” modeli karnesini şişirir.** Eski “unknown = yaptı” kapatıldı **yalnız devamsız için.** Öğretmen 30 kişiyi kaydeder, kimseye dokunmazsa rapor: ödev %100, yıldız 3.0. Kümülatif payda “işaretlenen oturum” olduğu için bu oturum da mükemmel sayılır. Veli toplantısı kılavuzu yalan öğer.
2. **Karne puanı oturum yokken 100.** `totalSessions <= 0 return 100.0`. Depo aynı veride 0 der. **Aynı üründe iki sözleşme.**
3. **PDF `?? 100.0`.** Depo 0 gönderirse sorun yok; anahtar koparsa sınıf yine mükemmel.
4. **Oturum anahtarında ders yok.** `class_id + date + lesson_hour`. Aynı saatte matematik yazılmışsa fen üzerine biner.
5. **Canlı ders eşlemesi `name = ?`.** Program `"5/A"`, sınıf `"5-A"` → eşleşmez, kart ölür. Eşleşirse `is_live` ilk derse erken saatte de true kalabilir.
6. **Yıllık `absence_followups` her derse taşınır.** “Bu yıl riskli” çocuk o gün geldiyse bile soluk + 0 yıldız (öğretmen düzeltmezse).
7. **`autoFillAcademicYearBaseline` ölü mayın.** Sabit 2025-09-08…2026-06-19 her iş gününe 1. saat tam puan basan metot duruyor; UI çağırmaz. Bir gün bağlanırsa sahte dönem.
8. **Geliş sütunu yoklamaya benzer.** Yasağa rağmen kâğıtta “zamanında / geç” durur.
9. **Kura `isAbsent` süzmez.** Yok öğrenci tahtaya kalkabilir.
10. **WhatsApp panoya kopya.** “Gönderildi” değil.

**Not:** **Yarım.** İşaretleme UX’i hızlı; varsayılan mükemmellik, kümülatif ve karne cümlesini zehirler. “Dürüstleşti” iddiası yalnız devamsız kolunda doğru.

---

## 2.3 Rehberlik

**Gerek:** Sınıf rehber öğretmeninin haftalık programı, görüşme arşivi, BEP’e geçiş, özel eğitim kaynağı.

**Kod:** Hub 4 sekme: BEP, sınıf rehberlik planı (yalnız homeroom), özel eğitim katalog, formlar (görüşme/tanıma/gezi).

**Hatalar**

1. **Üç BEP kapısı:** Rehberlik sekmesi, Sınıfım evrakları, özel eğitim sekmesi. Öğretmen “asıl BEP nerede?”
2. **Görüşme kaydı yok.** Form PDF, defter değil. Teftiş “görüşme defteri” ister; elinde boş PDF veya kâğıt yığını olur.
3. **Özel eğitim sekmesi öğrenciye bağlı değil.** ORGM program listesi. BEP öğrenci planından ayrı dünya. Kaynaştırma öğretmeni iki yeri gezmeden bir çocuğu bağlayamaz.
4. **Branş öğretmenine rehberlik planı kilitli** — doğru. Formlar (tanıma fişi) branşta da açılıyor; tanıma fişi rehber işidir.
5. **Gezi izni 2 kupon** — 30 kişilik sınıf için yetersiz üretim.

**Not:** **Yarım.** Plan takip çizelgesi iyi ürün. Görüşme/tanıma arşiv değil. BEP dağılmış.

---

## 2.4 Sınıf

**Gerek:** Şube + liste + oturma + nöbet + veli + evrak. Tek gerçek.

**Kod:** Sınıf modeli (ad, ders, rehber mi, yıl). Excel/PDF içe aktarma + önizleme. Oturma servisi. Nöbet editörü. Hub’da evrak listesi.

**Hatalar**

1. **Sınıfın tek `subject` alanı.** Rehber 8/A “Sınıf Öğretmeni”; branş “8/A Matematik” ayrı sınıf kaydı. Aynı çocuk iki sınıfta iki id ile durabilir. Katılım, quiz, BEP hangisine yazılır? Öğretmen kopya liste tutar.
2. **İçe aktarma e-Okul PDF’si.** Çalışırsa büyük kazanç. Parse hata satırı sessiz atlanırsa mevcut şaşar; imza listesi eksik basılır.
3. **Nöbet kalıcı değil.**
4. **Kulüp dağılım PDF’i kulüp modülünü yok sayar.**
5. **Hub, öğrenci yoksa çoğu evrakı kilitler** — doğru. Rehberlik özel eğitim kilidi açmış; sınıf hub’ı açmamış. Tutarsız.
6. **`generateDutySchedulePdf` ölü yol** hâlâ ilk öğrencileri nöbetçi yazar.

**Not:** **Sağlam liste, yarım yaşam.** Öğrenci CRUD ve import asıl değer. Evrak listesi şişirilmiş, veri bağları kopuk.

---

## 2.5 BEP

**Gerek:** Kaynaştırma öğrencisi için uzun/kısa hedef, kaba değerlendirme, dönem raporu. e-Okul BEP’in **taslağı**, yerine geçen değil.

**Kod:** Öğrenci özeti, kademe, müfredat bankası veya gelişim bankası, PDF. Counseling’den gerçek ekrana yönlendirme (eski sahte PDF’den kaçış — doğru).

**Hatalar**

1. **Ölü sahte form** hâlâ repoda, varsayılan tanı “Hafif Düzey”.
2. **Varsayılan yöntem/materyal/ölçme** yedek sabitler. Seçilmezse her planda aynı cümle (yorum bunu biliyor).
3. **Yıl devri** ayrı test var; öğretmen “geçen yılın hedefi bu yıl”ı fark etmezse eski BEP basar.
4. **e-Okul’a aktarım yok.** Taslak kâğıt. Öğretmen iki kez yazar.

**Not:** **Yarım, yönü doğru.** Sahte formun UI’dan çıkarılması ciddiye alındığını gösteriyor. Ölü kod kalması, bir ajanın tekrar bağlama riski.

---

## 2.6 Kulüpler

**Gerek:** Okul kulübü, karışık şubeler, üç evrak (plan, üye, faaliyet).

**Kod:** Katalog 52, üyelik ayrı tablo, PDF’ler üyeyi okur. Sınıfa bağlı olmaması yönetmeliğe uygun.

**Hatalar**

1. **Sınıf evraklarındaki “kulüp dağılımı” bu dünyayı görmüyor.** Öğretmen sınıf hub’ından basarsa boş; kulüp hub’ından basarsa dolu. Aynı isimli iki iş.
2. **Faaliyet log tutulmazsa yıl sonu raporu boş gerçekleşen sütunu.** Uyarı yok, “rapor hazır” durur.
3. **“Her öğrenci en az bir kulüpte” zorunluluğu kontrol edilmez.** Dağılım PDF’i bunu denetleyecek yerdi; boş sütun.

**Not:** **Sağlam (kendi hub’ında).** Sınıf hub’ı sabotaj.

---

## 2.7 Sınav işlemleri

**Gerek:** Quiz/sözlü defteri, proje rubriği, resmî sınav tarihi, analiz.

**Kod:** Dört alt ekran. Quiz dinamik kolon. Proje 10 kriter. Resmî sınav Remote Config + okul yazılısı. Analiz ayrı kayıt.

**Hatalar**

1. **Quiz ve proje PDF yok.** Ekran “çizelge”; idare kâğıt ister. Değerlendirme çizelgesi (#2) boş ve bu tabloları okumaz.
2. **Analiz ayrı model.** Notlar quiz’den gelmez; yeniden giriş. İki gerçek not.
3. **Quiz ders listesi sabit dizi** (Matematik, Türkçe, …). Profil branşı / sınıf `subject` ile zorunlu eşleşme yok. 8/A fizik quiz’i “Genel”de durabilir.
4. **Varsayılan ilk sınıf.** `classes.first` — yanlış şubeye yazma.
5. **Resmî sınav favori bildirimi** native tarafta kırık (`grok_inceleme.md`); mantık: öğretmen “kuruldu” sanır.

**Not:** **Yarım.** Giriş işi var, çıkış (kâğıt + e-Okul) yok. Analiz tek başına işe yarar.

---

## 2.8 Analiz / karne görüşü

**Gerek:** e-Okul’a yapıştırılacak kanaat. İsteğe bağlı; sorumluluk öğretmende.

**Kod:** Katılımdan puan (40/40/20), kalıp cümle havuzu, seed ile çeşit.

**Hatalar**

1. **Oturum 0 → 100 puan → “örnek performans”.** En ağır mantık hatası bu modülde.
2. **“e-Okul uyumlu”** yasal/pazar; mantık: e-Okul kutusu serbest metin. Uyum = Türkçe cümle. Pedagojik denetim yok.
3. **Kanaat formu PDF (#37) bu motoru kullanmaz.**

**Not:** **Yanıltıcı.** Dolu katılımla cümle çeşitliliği eğlenceli. Boş veriyle zararlı.

---

## 2.9 Ders programı

**Gerek:** Haftalık grid, çakışma, canlı ders, zil.

**Kod:** Gün + saat index, ayarlar (ilk ders, teneffüs). Çakışma uyarısı. PDF landscape. Dashboard bugünkü dersler.

**Hatalar**

1. **Canlı ders düzeltmesi doğru**; katılım hâlâ seçili sınıf state’ine de bağlı — algı ile kayıt sapabilir.
2. **Öğle arası / ikili öğretim** zayıf. Nöbet saati program değil.
3. **Cumartesi yok.** İmam hatip / meslek okulu sapması.
4. **İki PDF** (modül + öğretmen dosyası).

**Not:** **Sağlam.** Öğretmen asistanının omurgası.

---

## 2.10 Akademik takvim

**Gerek:** MEB çalışma takvimi, tatil, kazanım haftasıyla hizalama.

**Kod:** APK + senkron “uygulamayı güncelleyin.” Sınav ayrı (iner).

**Hatalar**

1. Takvim baytı APK’da. Yanlış tatil → yanlış “aktif hafta” → yanlış kazanım kartı → yanlış plan PDF tarihi.
2. `force` senkron sayacı (`grok_inceleme.md`) “gördüm” deyip içeriği değiştirmez.
3. Admin sihirbazı 2029+ dini bayram uydurur — o veri APK’ya girerse burayı zehirler.

**Not:** **Yarım.** Okumak için yeterli; “canlı MEB takvimi” değil.

---

## 2.11 Evraklar (öğretmen dosyası, belirli gün, pano, kurul)

Yukarıdaki PDF kesiti. Modül mantığı: **iş değil, çıktı türü.** `other_documents_view` yorumu bunu kabul ediyor; sonra yine 13 belge + kurul + plan + kulüp yığıyor.

Çift zümre, çift nöbet, çift ödev, çift program, çift veli görüşme — bu ekranın hastalık listesi.

**Not:** **Şişmiş.** İstiklâl Marşı ve plan PDF’i değerli; geri kalanı kopya şablon.

---

## 2.12 Veli portalı (ürün mantığı)

Güvenlik `grok_inceleme.md`. Burada iş mantığı:

1. Bağ kurulamayabilir (kural–istemci). Öğretmen kod basar, veli giremez → “veli bakmıyor.”
2. Randevu tarihi `now+2 gün`, öğretmenin görüşme günü yok sayılır. Ekranda “Salı 14:00” yazar, kayıt Perşembe olur.
3. Çakışma sorgusu fail olunca “çakışma yok.”
4. Onaysız bağ (yanlış kod, aynı numara).
5. Veli katılım/not görmez (kasıt). Öğretmen WhatsApp PDF’i atar — portalın varlık sebebi bypass.
6. Push yok: duyuru kâğıt/WhatsApp kadar “anlık” değil.

**Not:** **Ölü veya zararlı** (güvenlik kapanmadan). Mantık olarak WhatsApp’ın sürtünmeli kopyası.

---

## 2.13 Cepte asistan

**Gerek:** “Yıllık plan bas” kısayolu.

**Kod:** Kural tabanlı niyet, LLM yok. Plan PDF’lerini `PdfPreviewScreen` ile açar.

**Hatalar**

1. `yoklama` → devamsızlık ekranı. Yasağı kelimeyle deler.
2. Sınıf bağlamı sohbetten zayıf; yanlış kademe planı basılabilir (plan ekranıyla aynı seçim sapması).
3. “Belge hazırlarım” = paket basma, öğretmenin o günkü notu değil.

**Not:** **Kısmen.** Dürüstçe model değil. Kısayol olarak işe yarar; asistan değil.

---

## 2.14 Dashboard / navigasyon

Bugün dersler, canlı kart, sınav geri sayım, kazanım haftası, Cepte, rehberlik.

Eski canlı ders yapışması düzelmiş. Yaz tatili hafta ≥40. Resmî tatil kartı takvime bağlı (takvim bayatsa kart yanlış).

“Tüm sınıfa tam puan” canlı karttan **yanlış sınıfa** yazma riski, saat dilimiyle azaltılmış; seçili katılım sınıfı hâlâ ayrı state.

**Not:** **Sağlam.**

---

## 2.15 Okul bağlama / profil

Künye PDF’lerin antetini doldurur. Müdür adı boşsa PDF’de “Okul Müdürü” veya nokta. Branş zümre başlığını belirler. Okul türü ŞÖK yasağını belirler — profil yanlış “ortaokul” ise ilkokulda ŞÖK açılır.

**Not:** Künye boşken tüm “resmî” PDF’ler sahte okul müdürlüğüdür. Onboarding kapısı bunu kesmeye çalışır; masaüstü atlar.

---

## 2.16 Tahta kilidi (yalnız mantık)

Nöbetçi/duyuru Firestore’a yazılır, USB’ye girmez → tahta boş. “Çıkardım” telefonu kesmez. İki gerçek: bulut pano ve flash dosya. Müdür “kaydettim, tahtada yok.”

**Not:** `grok_inceleme.md` K6/K7/Y8. Mantık olarak pano vaadi teslim edilmiyor.

---

# 3. Çift gerçekler — öğretmen hangi dünyada?

Aynı işin iki kaydı, PDF’nin yanlışını basması.

| İş | Dünya A | Dünya B | Basılan |
|---|---|---|---|
| Zümre | Kurul editörü (yönerge + kadro) | Öğretmen dosyası boş şablon | İkisi de, farklı |
| Nöbet | Sınıf öğrenci nöbeti (otomatik) | Öğretmen nöbeti boş | İkisi de |
| Kulüp | `club_members` | Sınıf dağılım PDF boş | Hub’a göre değişir |
| Ödev | Katılım oturumu | Öğretmen dosyası boş çizelge | Boş olan “dosya” |
| BEP | `BepRepository` plan | Ölü `generateBepTrackingForm` sahte tanı | UI A; kod B duruyor |
| Not | Quiz tablosu | Sınav analizi modeli | Analiz PDF B |
| Program | `scheduleProvider` | Öğretmen dosyası aynı tablodan (nadir hizalı çift) | İkisi de |
| Veli telefon | `parentPhone` | Acil listesi / veli rehberi / görüşme formu veli adı | Form veli adını çekmez |
| Karne cümlesi | Smart comment | Kanaat formu boş | A ekran, B kâğıt |
| Devamsızlık | Katılım geliş | `absence_followup` | İki PDF |

Bu tablo, “32 PDF var” şikayetinin asıl karşılığıdır. 32 iş yoktur; **12 iş, 32 kâğıt** vardır.

---

# 4. Öğretmen günü — üç sahne

**Sahne 1 — Zümre (kullanıcı örneği).**  
Matematikçi “zümre tutanağı” basar. Gündem yönergeden, kararlar hazır “karar verildi.” İmza sirküsünde yalnız kendisi (kadro timeout). Başlık “MATEMATİK ZÜMRE …”. Müdüre verir. Müdür “diğer matematikçiler nerede, e-Kurul?” der. Öğretmen dosyasında bir boş zümre daha vardır; onu da basıp çantaya koyar.

**Sahne 2 — Veli toplantısı.**  
Editörü açar, tarih yazar, yazdırır. Karar 1: veliler her gün ödev bakacak. Toplantı yarın. İmza listesi 30 boş satır. Toplantıda gündem değişir; PDF değişmez. İmzalatır. Arşiv sahte.

**Sahne 3 — Dönem sonu.**  
Katılım raporunda gerçek oranlar (işaretlediyse). Karne görüşünde boş öğrenci 100. Quiz kâğıda dökülemez; boş değerlendirme çizelgesi basar, kalemle doldurur. BEP’i doğru modülden basar. Kulüp dağılımını sınıf hub’ından basar, üye sütunu boş; asıl üye listesi kulüp hub’ında. Teftiş çantası kalın, içi çelişkili.

---

# 5. Öncelik (kod yazılmadan)

Yapılmayacaklar bu oturumda yapılmadı. Sıra, zararın türüne göre.

### Hemen bırakın (C sınıfı)

1. Veli toplantı **varsayılan kararlarını** boşaltın. Gündem iskeleti kalsın, karar satırı boş.
2. Zümre/ŞÖK **varsayılan karar cümlelerini** boşaltın. Gündem maddesi kalsın.
3. Ölü BEP takip PDF’sini UI’ya tekrar bağlamayın; varsayılan RAM tanısını silin.
4. Karne motorunda `totalSessions <= 0 → 100` kalksın; 0 veya “veri yok.”
5. Kümülatif PDF `?? 100.0` → `?? 0.0` (depo ile aynı sözleşme).
6. Gelen öğrenci varsayılanı `unknown` / 0 yıldız olsun; “istisnayı işaretle” ancak öğretmen **bilinçli tam puan** seçerse.

### Bağlayın (modüller konuşsun)

7. Kulüp dağılım PDF’i `club_members` okusun veya menüden kalksın.
8. Değerlendirme çizelgesi quiz/proje/katılımı çeksin veya “boş şablon” diye adlansın.
9. Öğretmen dosyası zümre/ödev/nöbet/kanaat **ya gerçek modülü açsın ya durmasın.**
10. Quiz/proje **bir** PDF alsın. 51. çıktıdan değerli.

### Dürüst adlandırın

11. Antetten `MEB.*` kodlarını ve “T.C. Millî Eğitim Bakanlığı” iddiasını düşürün veya “taslak / arşiv kopyası” başa alın.
12. Kurul çıktısında e-Kurul cümlesi **ilk sayfa, büyük.** Şu an footer civarı.
13. “13 resmî evrak” → “5 dolu, 8 şablon.”

### Arşiv

14. Görüşme/tanıma/toplantı PDF’i üretmek yetmez; kayıt yoksa teftiş defteri yoktur. Ya SQLite defteri ya “bu kâğıt tek seferlik.”

---

# 6. Not özeti (modül)

| Modül | Not | Tek cümle |
|---|---|---|
| Kazanım | Yarım | Katalog iyi, benim sınıfım değil. |
| Katılım | Yarım | Devamsız dürüst; gelen varsayılan kahraman. |
| Rehberlik | Yarım | Plan takip iyi; görüşme arşiv değil. |
| Sınıf | Sağlam liste | Evrak kopuk. |
| BEP | Yarım, yön doğru | Sahte form UI’dan çıkmış, kodda duruyor. |
| Kulüp | Sağlam hub | Sınıf PDF’i ihanet. |
| Sınav | Yarım | Giriş var, kâğıt yok, analiz ayrı. |
| Karne görüşü | Yanıltıcı | Boş = 100. |
| Program | Sağlam | Omurga. |
| Takvim | Yarım | APK gerçeği. |
| Evraklar | Şişmiş | 12 iş, 32 kâğıt. |
| Veli | Ölü/zararlı | Güvenlik + randevu mantığı. |
| Cepte | Kısmen | Kısayol, asistan değil. |
| Dashboard | Sağlam | Canlı ders düzelmiş. |
| Tahta | Vaadi boş | Pano USB’ye inmiyor. |

---

# 7. İkinci tarama — ek mantık delikleri

PDF envanterinden sonra modül koduna ikinci tur. Birinci geçişte “katılım dürüstleşti” cümlesi **eksikti:** unknown yalnız devamsızda. Gelen öğrenci hâlâ mükemmel başlar.

| # | Bulgu | Kanıt | Öğretmeni nasıl yanıltır |
|---|---|---|---|
| E1 | Gelen öğrenci varsayılan 3 yıldız / ödev yaptı | `classroom_participation_repository.dart:177-206` | Kaydet-çık = sınıf kahramanı raporu |
| E2 | Karne 0 oturum = 100; kümülatif aynı veride 0 | `smart_comment_generator_provider.dart:21` vs depo | e-Okul’a yapıştırılan övgü |
| E3 | Kazanım kartı formül tarih; plan `date_range_str` | `outcome_carousel_card.dart` vs `PlanWeekBuilder` | Ekran ve teftiş PDF’i ayrı hafta |
| E4 | Yıllık plan yıl `2026-2027`, günlük `2024-2025` | iki üretici fallback | Cepte yıl vermezse iki belgede iki yıl |
| E5 | Quiz varsayılan ders Matematik, proje Fen | provider başlangıç | Türkçe öğretmeni yanlış çizelge |
| E6 | Quiz notu analiz tablosuna gitmez | iki model / iki repo | “Notlar silindi” sanısı |
| E7 | Program `5/A` ≠ sınıf `5-A` | `name = ?` | Canlı ders kartı yok veya yanlış |
| E8 | Veli paneli her zaman ilk rehber sınıf | `my_class_hub_screen.dart` | Branş 7-B seçili, mesaj 5-A’ya |
| E9 | Excel `contains('ad')` başlık | `excel_student_parser.dart` | “Kadın/adres” başlık; sessiz kayıp satır |
| E10 | Cinsiyet yoksa Erkek | aynı parser | Oturma rengi, kura, metin sapar |
| E11 | Gezi varsayılan Anıtkabir | modal + PDF | Yanlış muvafakatname |
| E12 | Kulüp faaliyet tohumu “yapıldı” gibi | `club_provider` taslak log | Yıl sonu raporu uydurma faaliyet |
| E13 | Dönem sonu katılım tarihi `DateTime.now().year` | kümülatif modal | Ocak’ta 1. dönem gelecek Eylül’e kayabilir |
| E14 | Öğretmen dosyası nöbeti boş; sınıf nöbeti dolu; tahta nöbeti üçüncü | üç üretici | “Nöbet çizelgesi” üç kâğıt, üç dünya |

Bunlar güvenlik değil. Öğretmenin **yanlış evrakı doğru sanması**. C sınıfı PDF’lerle aynı aile: varsayılan dolu.

---

## Kapanış

Birinci rapor delikleri soruyordu. Bu rapor **kâğıdı** soruyor.

SınıfCepte, öğretmenin dosya çantasını doldurmakta agresif, çantadaki kâğıtların **aynı gerçeği anlatmasında** tembeldir. Zümre tutanağı bunun örneğidir: yönerge gündemi ciddiye alınmış, üye listesi yanlış evrenden, kararlar toplantıdan önce yazılmış, ikinci bir boş zümre dosyada bekliyor.

Ölçek küçültülmeden (çift PDF’ler, C sınıfı dolu taslaklar) yeni evrak eklemek, teftişte “uygulama uyduruyor” cümlesini kolaylaştırır. Öğretmen asistanı olarak değer, listedeki A sınıfındadır: liste, oturma, plan taslağı, gerçek BEP, kulüp üyesi, katılım tutanağı, program. Gerisi ya kalemli şablon olmalı ya durmalıdır.

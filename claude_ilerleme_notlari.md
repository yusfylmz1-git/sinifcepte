# Günlük / Yıllık Plan Modülü — Düzeltme Raporu

**Tarih:** 12 Eylül 2026
**Dal:** `feat/full-project-baseline`
**Durum:** Kod tamam, 1250 test yeşil, `flutter analyze` temiz. Cihazda denenmedi.

---

## Ne yapıldı

Antigravity/Gemini'nin eklediği günlük + yıllık plan modülünü kod ve veri
üzerinden inceledim. Grok'un raporundaki iddiaları tek tek veriye karşı
doğruladım; bir kısmı doğru çıktı, bir kısmı yanlıştı. Doğrulananları
düzelttim.

### Yeni dosya

`lib/features/documents/utils/plan_week_builder.dart` — iki ekranın ortak
hafta üretim mantığı. Daha önce bu mantık iki ekrana kopyalanmıştı
(~1400 satır × 2) ve kopyalar zaten sapmıştı: günlük plan tarihi satırdaki
`dateRangeStr`'den, yıllık plan yeniden numaralanmış hafta sırasından
hesaplıyordu. Aynı ders iki ekranda iki farklı tarih gösteriyordu.

`test/plan_week_builder_test.dart` — 14 test, hepsi içerik doğruluğunu
kilitliyor. (Mevcut PDF testleri yalnızca `%PDF-` sihirli baytına
bakıyordu; içerik yanlış olsa da yeşil kalıyorlardı.)

---

## Düzeltilen altı kusur

### 1. Tatil süzgeci gerçek dersleri siliyordu

Eski kod `is_holiday_week` yanında ünite/konu metninde "tatil" kelimesi
arıyordu. Bu metin araması **77 gerçek ders satırını** siliyordu.

Veri incelemesi kesin sonuç verdi: `teaching_week_number` ile
`is_holiday_week` **tam örtüşüyor** — 1036 tatil satırının hepsinde alan
null, 9065 ders satırının hepsinde dolu. Süzgeç artık tek ölçüt olarak bu
alanı kullanıyor, metin araması kaldırıldı.

| Ders | Eskiden | Şimdi |
|---|---|---|
| 10. sınıf Arapça | 28 hafta | 36 hafta |
| 1. sınıf Beden Eğitimi | 33 hafta | 36 hafta |
| 5. sınıf Türkçe | 35 hafta | 36 hafta |

Not: Grok "7 haftalık gerçek Arapça müfredatı siliniyor" derken haklıydı
(ünite adı "Tatile Hazırlanıyorum"), ama silinen satırların bir kısmının
gerçekten tatil olduğu iddiası yanlıştı — 77'sinin de `teaching_week_number`
dolu, yani hepsi gerçek ders.

### 2. Yıllık planda tarihler kayıyordu

Tatiller atıldıktan sonra satırlar `i + 1` ile yeniden numaralanıyor, tarih
bu numaradan hesaplanıyordu. Sonuç: 10. ders haftası, takvimdeki 10.
haftanın (ara tatil) tarihini alıyordu.

Artık hafta numarası veriden (`teaching_week_number`) okunuyor, tarih ise
**takvim haftasından** (`week_number`) hesaplanıyor. Doğrulama: 5. sınıf
Türkçe'de 10. ders haftası = takvim 11. hafta = 23-27 Kasım 2026. Eski kod
buraya ara tatil tarihini basıyordu.

### 3. Lise dropdown çökmesi

`DropdownButton`'ın value'su yalnızca `subject_code` idi. **30 (sınıf, ders)
çiftinde** birden çok yayıncı var — 9-12. sınıfta Fizik, Kimya, Matematik,
Edebiyat, Tarih, Coğrafya; her biri Anadolu / Fen / Sosyal Bilimler Lisesi
olarak üç kez geliyor. Flutter aynı value'dan iki tane görünce assertion ile
düşer: **lise öğretmeni ekranı hiç açamıyordu.**

Artık anahtar `subject_code|publisher`. Her iki ekranda da düzeltildi.

### 4. Her ders PDF'te "2 saat" yazıyordu

Müfredat paketinde (10.101 kayıt, 39 alan) haftalık ders saati alanı **hiç
yok**. Kod `m['lesson_hours'] ?? '2'` yazdığı için Türkçe (6 saat),
Matematik (5), Beden (5) hepsi "2 saat" görünüyordu. Teftişte ilk bakılan
kolon budur.

MEB haftalık ders çizelgelerinden bir harita yazdım (`haftalikDersSaati`).
205 (sınıf, ders) çiftinin 172'sini kapsıyor. Kalan 33'ü çoğunlukla İmam
Hatip meslek dersleri ve 11-12. sınıf seçmelileri; onlarda **sayı
uydurulmuyor**, kolona `—` basılıyor ki öğretmen elle doldursun.

### 5. Her boş haftada "öğrencilerle tanışılır"

Resmî etkinlik alanı ders haftalarının **%56'sında** (9065'in 5043'ünde)
boş. Eski kod boş olan **her** haftaya "Öğretim yılının ilk dersi olduğu
için öğrencilerle tanışılır" cümlesini basıyordu — mart ayındaki 22. haftada
bile. 5. sınıf Türkçe'de bu alan 35 haftanın hepsinde boş, yani öğretmen 35
kez "ilk ders" yazan bir plan indiriyordu.

Artık tanışma metni yalnızca 1. haftada. Diğer haftalarda dersin kendi
Maarif özeti (`maarif_summary`, veride %100 dolu) kaynak alınıyor.

### 6. Sahte plan üretimi ve "Resmî" iddiası

Veri bulunamayınca **36 haftalık tamamen uydurma plan** sessizce
üretiliyordu (`_varsayilanHaftaPlani`). Öğretmen boş bir dersin planını
"hazır" sanıp teftişe götürebilirdi. Bu fonksiyon iki ekrandan da silindi;
artık ekran nedenini yazıyor.

Yöntem/araç/ölçme alanlarının bir kısmı sabit şablon olduğu için:
- Ekrandaki "Resmî Onay & İmza" rozeti → **"Taslak — Zümre Onayı Gerekir"**
- Her iki PDF'e kırmızı **"TASLAK — Zümre öğretmenler kurulunca gözden
  geçirilmesi gerekir"** ibaresi eklendi
- "36 Hafta Tam Akış" / "36 Haftalık Müfredat Dağılımı" → gerçek hafta sayısı

### 7. Cihazda yakalanan ikinci regresyon — bileşik anahtar ders kodu sanıldı

Tohumlama düzeldikten sonra Bilişim çalışıyor, **Türkçe çalışmıyordu**:
dropdown "Bilişim" gösterirken gerekçe metni "Türkçe" diyordu ve liste boştu.

Sebep, günlük plan ekranının dropdown `onChanged` gövdesindeydi:

```dart
_seciliDersKodu = v;   // v = "TURKCE|" — bileşik ANAHTAR, ders kodu değil
```

Lise çökmesini çözmek için dropdown value'sunu `subject_code|publisher`
yapmıştım; `onChanged` ise bu anahtarı doğrudan ders kodu olarak atıyordu.
Sonuç: `kazanimlariGetir(subjectCode: "TURKCE|")` → SQL'de
`subject_code = 'TURKCE|'` → hiçbir satır dönmüyor. Dropdown etiketinin de
güncellenmemesi aynı kökten: `_seciliAnahtar` bu kez `"TURKCE||"` üretip
hiçbir öğeyle eşleşmiyordu.

**Çözüm:** `_seciliDersKodu = bulunan['subject_code']`. Yıllık ekranda aynı
hata yoktu (orada zaten `ders['subject_code']` yazıyordu). 3 test eklendi.

### 8. Diğer Evraklar kart alt yazıları

Giriş kartlarında hâlâ "36 haftalık A4 yatay PDF çıktısı" ve "resmî PDF
çıktısı" yazıyordu. Taslak kararıyla çelişiyordu; ikisi de "taslak · zümre
onayı gerekir" olarak güncellendi.

### 8. Depo şişmesi

`cikti_json/` (61 MB, 7.586 dosya) ve `scratch/` `.gitignore`'a eklendi.
Uygulama bu klasörleri okumuyor; yanlışlıkla commit edilse repo kalıcı
şişerdi.

---

### 8. Cihazda yakalanan regresyon — `teaching_week_number` boş kalıyordu

İlk kurulumda ekran **"plan bulunamadı"** dedi; üstelik dropdown'da Bilişim
seçiliyken gerekçe metni Türkçe diyordu. Kök neden:

`teaching_week_number` sütunu tabloya **sürüm 7'de ALTER TABLE ile** eklenmiş,
ama sürüm 12'deki toplu `delete('curriculum_outcomes')` temizliğine dahil
edilmemiş. ALTER ile eklenen sütun **mevcut satırlarda NULL kalır** ve
tohumlama `count >= 1000 && !paketEski` ise atlanıyor. Sonuç: güncelleme alan
cihazda sütun boştu. Yeni tatil süzgeci tek ölçüt olarak bu sütuna baktığı
için **her satır elendi**.

Testler bunu yakalayamadı çünkü test ortamı temiz DB kuruyor — hata yalnızca
gerçek cihazda görünür.

**Çözüm:** `kazanimPaketSurumu` 5 → 6 (yeniden tohumlamayı tetikler) + süzgece
geri düşüş (sütun hiç dolu değilse eski `is_holiday_week` ölçütüne düşer, boş
ekran göstermez) + bu senaryoyu kilitleyen 3 test.

**Cihaz kanıtı:**
```
I flutter : DatabaseHelper: 10101 resmî kazanım assets üzerinden
            SQLite veritabanına başarıyla yüklendi 🚀
```
Ardından 36 hafta listelendi, tarihler doğru (1. hafta 14-18 Eylül,
3. hafta 28 Eylül-2 Ekim), gerçek BTY kazanım kodları göründü.

### 9. Kırpma dil derslerinde veri kaybıydı (müfredat yeniden üretildi)

Öğretmenin TYMM sitesinden indirdiği Türkçe planıyla karşılaştırınca çıktı:
MEB, Türkçe/Arapça planlarında **dört ayrı beceri sütunu** kullanıyor
(Dinleme/İzleme, Okuma, Konuşma, Yazma). Boru hattı bunları tek metinde
birleştiriyor → 5973 karakter. `MAX_DESCRIPTION = 700` bunu 681'de kesince
kesme noktası dinlemenin ortasına düşüyor ve **okuma, konuşma, yazma
tamamen siliniyordu**.

Kanıt (ham Excel → eski kırpma):
```
HAM    5973 karakter  alanlar=['D','K','O','Y']
KIRPIK  681 karakter  alanlar=['D']          ← üç beceri yok oldu
```

**Üç düzeltme:**
1. `trim_description` artık beceri bloklarını ayrı ayrı kısaltıyor; her
   alandan kazanım başlığı korunuyor. Beceri etiketi taşımayan metinde
   (Bilişim, Matematik, Fen) davranış birebir eskisi gibi — o dersler
   sağlamdı, riske atılmadı.
2. `outcomeParts` artık **kırpılmamış** metinden üretiliyor. Kırpma
   yalnızca gösterim içindir; yapı tam kalmalı.
3. `_CODE` deseni beceri harfli kodları (`T.D.5.3`, `T.O.5.15`) tanımıyordu
   — önekten sonra rakam bekliyordu. Türkçe kazanımlarının hiçbiri
   görülmüyor, `outcomeParts` tek bloğa düşüyordu. Desene tek harfli
   önek dalı eklendi; bu dal hem yeni Maarif kodlarını (`T.D.5.3`) hem
   eski biçimi (`T.4.3.1`) kapsıyor. Sekiz kod biçiminin tamamı
   regresyon testinden geçti: `T.D.5.3`, `T.4.3.1`, `MAT.11.1.1`,
   `BTY.5.1.1`, `MARP11.1.1`, `T.K.5.1`, `5.1.2`, `TDE2.1.1`.

**Sonuç (paket yeniden üretildi, 10.101 kayıt):**

| Ölçüm | Önce | Sonra |
|---|---|---|
| Türkçe'de yalnızca dinleme kalan kayıt | 105 | **0** |
| Beceri etiketli kırpıkta 4 alan korunan | 0 | **105** |
| Etiketsiz kırpık (Bilişim/Mat — bozulmamalı) | 2529 | 2527 ✓ |
| 5. sınıf Türkçe 1. hafta `outcomeParts` | 1 | **24** |
| Türkçe 4/5/7'de `parts<=1` kalan hafta | hepsi | **0** |

5. sınıf Türkçe 1. haftanın kazanım kodları artık eksiksiz:
`T.D.5.3, T.D.5.4, T.D.5.5, T.D.5.13, T.D.5.17, T.O.5.2 … T.Y.5.16`
(24 kod, dört beceri alanı). Öğretmenin TYMM sitesinde gördüğü tabloyla
birebir örtüşüyor.

Yan bulgular: 8 kayıtta `Okuma:` etiketi iki kez geçiyor — **kaynak
Excel'de öyle**, bizim ürettiğimiz değil, dokunulmadı. 4 ve 8. sınıf
Türkçe eski müfredat kodu (`T.4.3.1`) kullanıyor; onlarda da etiketler
yerinde.

`kazanimPaketSurumu` 6 → 7 (yeni paketin cihazlara gitmesi için).

### 10. Yıllık plan tablosunda taşma riski (müfredat düzeltmesinin yan etkisi)

Kırpma düzeltilince bir hafta artık dört beceri alanının kazanımlarını
birden taşıyor — bu istenen sonuçtu, ama yıllık planda yeni bir risk
doğurdu: **566 kayıtta 15'ten çok kazanım var**, 6. sınıf Türkçe'de bir
hafta **33 kazanım**.

Yıllık plan A4 **yatay** tabloda her haftayı tek satıra basıyor ve
kazanım listesini sınırsız yazıyordu (`ciktilar.map('• $c').join('\n')`).
33 madde o satırı taşırır, sayfa okunmaz olurdu.

**Çözüm:** yıllık planda hücre listesi 8 maddeyle sınırlandı, kesilen
kazanımlar `(… ve 25 kazanım daha — ayrıntı günlük planda)` diye
**sayıyla** bildiriliyor; sessizce kaybolmuyor. Günlük planda sınır
**yok** ve olmamalı — orada her hafta ayrı sayfa, kazanımların tamamı
yazılıyor.

Ayrıca `AnnualPlanPdfGenerator` için **hiç test yoktu** (günlük planınki
vardı). `test/annual_plan_pdf_test.dart` eklendi: 33 kazanımlı hafta hem
metin sınırı hem PDF üretimi olarak doğrulanıyor.

### 11. Yıllık PDF'te fontta olmayan emoji

Yıllık plan testi yazılınca üretim uyarısı görünür oldu:
`Unable to find a font to draw "⭐" (U+2b50)`.

"Açıklamalar" hücresinde `📅` ve `⭐` basılıyordu; PDF yazı tipinde ikisinin
de karşılığı yok, yani **teftişe giden evrakta boş kare** çıkıyordu. Düz
metne çevrildi (`Belirli Gün/Hafta:`, `Değerler:`). Projede aynı tuzak pano
tarafında daha önce yaşanmış ve aynı yolla çözülmüş (`_makas = 'KES'`).

### 12. MEB yanlış dosyayı "İnsan Hakları" adıyla yayımlamış (140 kayıt yanlış derste)

Kazanım denetimi sırasında çıktı: `INSAN_HAKLARI_YURTTASLIK` kodlu 1-4.
sınıf kayıtlarının içeriği baştan sona **Beden Eğitimi ve Oyun** —
kazanımlar `BEO.1.1.1…`, temalar "HAREKET EDİYORUM", ders saati 5.

Kaynağa indim: `insan-haklarivatandaslik-ve-demokrasi-dersi.zip` içindeki
Excel'in **adı** "İNSAN HAKLARI, VATANDAŞLIK VE DEMOKRASİ (4. SINIF)" ama
**sayfaları** `1. Sınıf`–`4.Sınıf` ve içeriği tamamen beden eğitimi. Hata
MEB'in yayımladığı dosyada; boru hattı dosya adına güvenip 140 kaydı
ikinci kez yazmış.

Ölçüm: `BEDEN_OYUN` ve `INSAN_HAKLARI_YURTTASLIK` gruplarındaki 140 kaydın
**%100'ü birebir aynı**. Öğretmen "İnsan Hakları" seçince beden eğitimi
planı alıyordu.

**Çözüm:** slug gerçek içeriğine eşlendi. `merge_sources` ders ADINA göre
tekilleştirdiği için 140 kayıt `BEDEN_OYUN` ile birleşiyor; sahte ders
pakette görünmüyor. MEB gerçek planı yayımlarsa satır geri alınır. İçerik
**uydurulmaz**: plan yoksa ders listelenmez.

**Neden üç yeniden üretimde silinmedi — geri besleme döngüsü:**
`merge_sources.py` mevcut YAYIN PAKETİNİ de girdi olarak okuyor ("MEB'in
resmî planı olmayan dersler ders listesinde kalsın" kuralı). Süzgeç
yalnızca ders ADINA bakıyordu. Dosya gerçek içeriğine eşlenince resmî
kaynakta artık "İnsan Hakları" adı kalmadı; süzgeç bu dersi "resmî planı
yok" sanıp **eski paketten geri taşıdı**. Kendi çıktımız girdiye dönüştü.
Süzgece kazanım kodu öneki kontrolü eklendi: önek resmî kaynakta varsa
(BEO → Beden Eğitimi ve Oyun) içerik zaten doğru derste durur, taşınmaz.

**İkinci halka — tatil kartı ders yaratıyordu:** Önek süzgeci beden
eğitimi içeriğini eledikten sonra o dersin tatil/OTP kayıtları geride
kaldı (kod taşımadıkları için süzgeçten geçtiler).
`build_curriculum` onları grup sayıp `_fill_missing_weeks` ile 39 haftaya
tamamladı: içi "Zümre öğretmenler kurulu kararları doğrultusunda…" dolgu
metniyle dolu **sahte bir ders** (156 kayıt, %83'ü placeholder). Süzgece
üçüncü koşul eklendi: bir ders grubu ancak **gerçek kazanım taşıyan**
kaydı varsa taşınır.

**Denetime kural eklendi:** `audit_data.py` artık ders adı ile kazanım
kodu önekini karşılaştırıyor ve uyuşmazlığı `AD/İÇERİK UYUŞMAZ` diye
bildiriyor. Kısaltma farkları (GORSEL→GS, HAYAT→HB, MUZIK→MÜZ) normal
sayılır; yalnızca ilk harf ayrışması işaretlenir. Bu hatayı hiçbir
denetim görmüyordu.

### 13. Kod deseni dört biçimi daha tanımıyordu (249 kayıt)

Kodsuz görünen 1238 kaydın 261'inde kod aslında vardı:

| Biçim | Ders | Kayıt |
|---|---|---|
| `Mü.3.A.4.` (küçük harfli önek) | Müzik | 140 |
| `1.1.` (iki segment, öneksiz) | İnkılap Tarihi | 99 |
| `ENG5.7.L1.` (önek+sınıf bitişik, sonda harf) | İngilizce | 22 |
| `TDE2.2.` (iki segment) | Edebiyat | — |

Desene üç dal eklendi. On kod biçiminin tamamı regresyon testinden
geçiyor; madde harfleri (`a)`, `b)`) kod sanılmıyor. **249 kayıt** kazanım
kodunu geri kazandı.

### 14. Cepte — konuşarak kullanılan menü

Rakip bir uygulamada asistan görülünce eklendi. Ekran görüntülerine
bakınca o asistanın büyük ihtimalle **dil modeli değil**, niyet eşlemesi
olduğu anlaşıldı: sabit özellik listesi + sohbet kutusu. Yaptığı şey yeni
özellik üretmek değil, **var olanı bulunur kılmak**.

Uygulamada 32 ekran var ve öğretmen "ne nerede bulmak gerçekten zor"
diyordu. Asıl kayıp görünürlüktü.

**Neden model değil kural:** Cihazda çalışan küçük model APK'yı 89 MB'dan
400-650 MB'a çıkarır, düşük telefonda 3-10 sn yanıt verir ve Türkçe
eğitim jargonunda **kazanım uydurabilir**. Bu uygulamanın çıktısı teftişe
gidiyor. Kural tabanlı eşleme ya doğru anlar ya "anlamadım" der.

| Yazılan | Olan |
|---|---|
| `5. sınıf türkçe yıllık plan` | 36 haftalık plan → PDF önizleme |
| `oturma planı` | Sınıfım ekranına götürür |
| `5. sınıf türkçe 3. hafta` | O haftanın kazanımlarını yazar |
| `yıllık plan hazırla` | "hangi sınıf ve hangi ders?" |
| `bugün hava güzel` | "anlayamadım" + örnekler |

**Üç katman:** niyet çözümleyici (22 test) → belge servisi (10 test) →
sohbet ekranı (9 sözleşme testi). İlk ikisi saf Dart, UI'dan bağımsız;
veritabanı çağrıları dışarıdan enjekte edildiği için testler sqflite
kurmuyor.

**Tahmin etmeme kuralı üç yerde:** eksik bilgide üretim yok; lisede üç
okul türü varsa seçilmez, sorulur; veri yoksa gerekçe yazılır.

Bunun ön koşulu olarak plan üretimi ekran durumundan koparıldı
(bkz. `685c75e`) — o refactor 572 satır kopya kodu da temizledi.

## Doğrulama

```
flutter analyze lib/features/documents/ test/plan_week_builder_test.dart
  -> No issues found!

flutter test
  -> All tests passed! (1317 test; oturum başında 1236)
     +24 müfredat/plan düzeltmeleri
     +2  menü düzeni
     +14 plan üretiminin ekrandan koparılması
     +41 Cepte (22 niyet + 10 servis + 9 sözleşme)

python scripts/maarif/test_pipeline.py
  -> 85 test, 2 hata (İKİSİ DE ÖNCEDEN BOZUK:
     takvim tablosu elle güncellenmiş ama test eski tabloya bakıyor;
     OTP testi otpWeeks=[] olduğu için kayıt bulamıyor)

python scripts/maarif/audit_data.py --full
  -> 259 ders grubu: temiz 227 | uyarı 32 | HATA 0
     (uyarılar: MEB'in kendi tekrar eden haftaları — veri kaybı değil)

Kazanım kodu kurtarma: 249 kayıt (Mü.*, 1.1., E4.1.L1, ENG5.7.L1)
```

---

## Açık kalan işler

1. **Cihazda denenmedi.** VS Code F5 ile PDF önizleme donuyor (bilinen
   tuzak — `adb install` veya release ile denenmeli).
2. **Ders saati haritası 33 derste boş.** İmam Hatip meslek dersleri ve
   bazı lise seçmelileri `—` alıyor. MEB çizelgesinden tamamlanabilir.
3. **Okul türü eşlemesi yok.** Dropdown artık çökmüyor ama Fen Lisesi
   öğretmeni listeden Anadolu Lisesi planını seçebiliyor; profildeki okul
   türüyle otomatik eşleme yapılmadı.
4. **Branş eşleme tuzağı sürüyor.** `"Felsefe".contains("fen")` true
   döndüğü için Fen öğretmeni Felsefe'ye düşebilir (eski kod, dokunmadım).
5. **Şablon içerik hâlâ şablon.** Taslak ibaresiyle dürüstlük sağlandı ama
   yöntem/araç/ölçme sütunları hâlâ sabit metin. Gerçek içerik istenirse
   veri tarafında çözülmeli.
6. **Commit edilmedi.** Değişiklikler çalışma ağacında duruyor.

---

## Değişen dosyalar

```
YENİ  lib/features/documents/utils/plan_week_builder.dart
YENİ  test/plan_week_builder_test.dart
      lib/features/documents/presentation/views/annual_plans_view.dart
      lib/features/documents/presentation/views/daily_plans_view.dart
      lib/features/documents/utils/annual_plan_pdf_generator.dart
      lib/features/documents/utils/daily_plan_pdf_generator.dart
      .gitignore
```

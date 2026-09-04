# Pano içeriği yazım kuralları

Bu kurallar `build_pano_dataset.py` ve `pano_toren_metinleri.py` içindeki
metinler için bağlayıcıdır. Amaç tek cümlede: **aynı çıktıyı Türkiye'deki
her öğretmen indirip kullanabilmeli.**

Bir içerik "bir öğretmenin planı" gibi okunuyorsa yanlış yazılmıştır;
"herkesin seçebileceği malzeme" gibi okunmalıdır.

---

## 1. Künye: neyin nereye basılacağı

|                      | Etkinlik planı | Çalışma raporu | **Pano** |
|----------------------|:--------------:|:--------------:|:--------:|
| Okul adı             | var            | var            | **var**  |
| Öğretim yılı         | var            | var            | **var**  |
| Şube (4-A)           | var            | var            | **YOK**  |
| Öğretmen adı         | var            | var            | **YOK**  |
| Öğrenci adı          | —              | —              | **boş satır** |

Gerekçe: plan ve rapor resmî evraktır, imzalanır, dosyalanır — şube ve
hazırlayan adı oraya girer. Pano ise koridorda duran görsel çalışmadır.
Üzerinde "4-A Sınıfı" yazarsa o pano tek şubenin malı olur; aynı okuldaki
başka öğretmen aynı çıktıyı asamaz. Okul adı ise panoyu okula ait kılar
ve kimseyi dışarıda bırakmaz.

Öğrenci adı panoya **basılmaz**, boş satır olarak bırakılır — öğrenci
kendi el yazısıyla doldurur (bkz. `_ogrenciAlani`).

## 2. Metinde kaçınılacaklar

**Şube adı yazma.** "4-A", "2/B" gibi ifadeler hiçbir metinde geçmez.
Gerekirse "sınıfımız" denir.

**Yıl sabitleme.** "2026-2027 öğretim yılında" yazma. İçerik her yıl
yeniden kullanılır; yıl künyeden gelir. Tarihî yıllar (1920, 1923, 1868)
elbette yazılır — yasak olan *içinde bulunulan* yılı sabitlemek.

**Tek okula özgü ayrıntı.** "Okulumuzun bahçesindeki çınar ağacı",
"spor salonumuzda" gibi ifadeler her okulda karşılığı olmayabilir.
"Bahçede", "salonda veya sınıfta" gibi seçenekli yaz.

**Zorunlu malzeme varsayma.** Projeksiyon, akıllı tahta, renkli yazıcı,
fotokopi bütçesi her okulda yok. Etkinlik bunlara bağlıysa `hazirlik`
etiketiyle işaretle ve malzemesiz bir alternatif de havuza koy.

**Tek düzeye yazma.** Bir gün için yalnızca 4. sınıfa uygun metin yazma;
`duzey` etiketiyle 1-2 / 3-4 / 5-8 arasında dağıt. Her düzeye uyan metin
`duzey: 'hepsi'` alır.

`duzey` taşıyan alanlar: `ogrenciKonusmalari`, `siirler`.

**Tek ses tonu.** Müdür konuşması üç tonda yazılır (resmî, samimi, kısa).
Öğretmen okuluna uyanı seçer. Tonlar `mudurKonusmalari` listesinde
`ton` etiketiyle durur; tekil `mudurKonusmasi` alanı eski kayıtlar için
korunur ve ton havuzu yoksa o kullanılır.

**Havuzun tamamını plana basma.** Tören planı bir *senaryodur*, seçenek
listesi değil. Plan havuzdan bir metin seçer ('3-4' düzeyi, 'resmî' ton)
ve altına kaç seçenek daha olduğunu not düşer. Hepsini basmak planı
okunmaz hâle getiriyordu.

## 3. Metinde aranan

- **Seçenek sunmak.** "Şunu yapın" değil, "şu, şu veya şu yapılabilir".
- **Ölçülebilir süre.** Her etkinlikte `sure` etiketi bulunur.
- **Malzemesiz alternatif.** Her gün için en az bir etkinlik `hazirlik: yok`.
- **Kaynak dürüstlüğü.** `kaynak` alanı `meb` ise gerçekten MEB
  yayınından gelmeli. Uydurulmuş metni "MEB kaynaklı" göstermek
  öğretmeni resmî evrakta yanlış bilgiye sürükler. Emin değilsen `genel`.

## 3.1 Alanlar

Her gün şu alanları taşımalı (denetim henüz zorunlu tutmuyor ama
eksikse o kurgu öğretmene gösterilmez):

| Alan              | En az | Ne işe yarar                        |
|-------------------|:-----:|-------------------------------------|
| `panoParagraflar` |   3   | Günün anlamı, düz metin             |
| `sozluk`          |   4   | Kavram + tanım; Kavram Sözlüğü kurgusu |
| `oncesiSonrasi`   |   2   | Önce/Sonra kurgusu                  |
| `kronoloji`       |   3   | Tarih Şeridi kurgusu                |
| `soruCevap`       |   4   | Soru–Cevap Kapakçığı kurgusu        |
| `panoDortlukler`  |   3   | Şiir Duvarı kurgusu                 |
| `biliyorMuydunuz` |   3   | Biliyor muydunuz? kurgusu           |
| `sozler`          |   1   | Söz Panosu kurgusu                  |

**Sözlük ile soru–cevabı karıştırma.** Sözlükte *tanım* vardır
("darbe nedir"), soru–cevapta *muhakeme* ("darbe ile seçimin farkı
nedir"). Aynı içeriği iki yere yazmak panoyu tekrara düşürür.

## 4. Telif

Alıntı şiir, hazır kompozisyon, telifli konuşma metni **kopyalanmaz**.
Tüm metinler bu proje için yazılır.

İstisna: kamuya mal olmuş sözler (Atatürk vecizeleri) ve tarihî olgular.
Bunlar kaynağıyla birlikte verilir (`vecizeKaynak`).

## 5. Renk

Renk seçimi `pano_paletleri.py` içindedir ve elle değiştirilmez.
Her palet gri merdivene oturur (koyu 42-62, orta 92-118, açık 200-228);
öğretmenlerin çoğu siyah-beyaz yazıcı kullandığı için ölçüt budur.
Değişiklik sonrası `python tool/pano_paletleri.py` ile doğrula.

---

## Denetim

`build_pano_dataset.py` üretim sırasında şunları denetler ve ihlalde durur:

- şube kalıbı (`4-A`, `2/B`) hiçbir metinde geçmemeli
- içinde bulunulan yıl aralığı (`2026-2027`) sabitlenmemeli
- her günde en az bir `hazirlik: yok` etkinlik bulunmalı
- her palet gri merdiven ölçütlerini geçmeli

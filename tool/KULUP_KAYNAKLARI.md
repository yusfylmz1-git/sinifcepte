# Sosyal kulüp verisi — kaynaklar ve kararlar

`tool/kulup_icerikleri.py` + `tool/build_kulup_dataset.py` →
`assets/data/kulup_planlari.json.gz` (29 KB sıkıştırılmış / 150 KB açık).

## Neden hazır plan indirmedik

İnternette 2025-2026 kulüp planları hazır PDF olarak dolaşıyor
(egitimhane, sorubak, sosyalciniz, sinifogretmeniyiz). İndirip
paketlemek en hızlı yoldu ama **yapmadık**: o metinler başkasının
emeği ve telif durumu belirsiz. Uygulama bunları dağıtırsa hem hukuken
hem ilke olarak yanlış olurdu.

Bunun yerine ayrım şu:

| Katman | Kaynak | Telif |
|---|---|---|
| Kulüp adları (52) | MEB EK-4 çizelgesi | Mevzuat — serbest |
| Belge düzeni, imza blokları | Yönetmelik + resmî matbu form | Mevzuat — serbest |
| Ay/amaç/etkinlik metinleri (520 blok) | **Bu projede yazıldı** | Bize ait |

## Resmî kaynaklar

**Öğrenci Kulüpleri Çizelgesi (EK-4)** — Değişik: RG-18/1/2023-32077.
52 kulüp. Afet Hazırlık'tan Zekâ Oyunları'na sıralı.
`data_sources/sosyal_kulup/EK-4_ogrenci_kulupleri_cizelgesi.pdf`

**MEB Eğitim Kurumları Sosyal Etkinlikler Yönetmeliği** —
RG 08.06.2017 / 30090.
`data_sources/sosyal_kulup/` altında tam metin.

Modülü doğrudan ilgilendiren maddeler:

- **MADDE 6** — Sosyal Etkinlikler Kurulu: müdür yardımcısı başkanlığında
  3 öğretmen, 2 kulüp temsilcisi öğrenci ve 1 veli. Belgelerdeki
  "Sosyal Etkinlikler Kurulu Başkanı" imzası buradan.
- **MADDE 8/1** — Kulüpler EK-4'ten kurulur; çevrenin özellikleri ve
  imkânlar ölçüsünde **öğretmenler kurulu kararıyla farklı kulüp de
  kurulabilir**. Uygulamadaki "çizelge dışı kulüp kur" seçeneği bu
  maddeye dayanıyor.
- **MADDE 8/2** — Planlama ve yürütme danışman öğretmenin gözetiminde.
- **MADDE 8/4** — **Her öğrencinin en az bir kulübe üyeliği zorunlu.**
- **MADDE 8/5** — Çalışmalar e-Okul Sosyal Etkinlik Modülüne işlenir.
  (Uygulama e-Okul'a yazmıyor; öğretmen elle girer.)
- **MADDE 8/6** — Giderler okul-aile birliği ve bağışla karşılanabilir —
  yani **garanti değil**. İçerik yazımında bütçe gerektiren etkinlik
  dayatılmamasının gerekçesi.
- **MADDE 8/7** — Üyelik seçildiği öğretim yılıyla sınırlı. Kulüpler
  `ogretim_yili` ile süzülüyor, her yıl yeniden kurulur.
- **MADDE 10** — Geziler için Veli İzin Belgesi (EK-5) ve görevlendirme
  şart. Plan metinlerinde gezi "düzenlenebilir" diye geçer, kesin
  taahhüt olarak değil.

> `data_sources/` `.gitignore`'da — ham kaynaklar repoya girmiyor.
> Kaynak PDF'leri yeniden indirmek gerekirse yukarıdaki künyelerle
> MEB sitelerinden bulunur.

## İçerik yazım kuralları

`PANO_ICERIK_KURALLARI.md` burada da bağlayıcı: yıl sabitlenmez, şube
adı geçmez, tek okula özgü ayrıntı yazılmaz, zorunlu malzeme
varsayılmaz. Kulübe özgü üç ek kural:

1. **Bütçe gerektiren etkinlik dayatılmaz** (MADDE 8/6). "Kermes
   düzenlenir" değil, "okulun imkânları ölçüsünde" denir.
2. **Gezi hafife alınmaz** (MADDE 10). İzin ve görevlendirme şartı
   metinde anılır.
3. **Malzemesiz alternatif verilir.** Fotoğrafçılık'ta makine yoksa
   kâğıt çerçeveyle, Bilişim'de bilgisayar yoksa kâğıt üzerinde
   algoritmayla çalışılır. Her okulda projeksiyon, fotokopi bütçesi
   veya çalgı yok.

## Ay iskeleti

Öğretim yılı Eylül-Haziran, 10 ay. Üçü her kulüpte aynı işlevi taşır ve
`kulup_icerikleri.py` içinde ortak fonksiyondan üretilir:

- **Eylül** — kuruluş, üye ve görev dağılımı, kulüp temsilcisi seçimi
- **Ocak** — birinci dönem değerlendirmesi, ikinci dönem planlaması
- **Haziran** — yıl sonu değerlendirme ve faaliyet raporu

Kalan yedi ay kulübün kendi konusu. Bu yüzden `kulup()` çağrısı 7 ay
alır, 10 ay üretir.

## Üretim

    python tool/build_kulup_dataset.py

Script yazmadan önce doğrular: 52 numaranın tamamı var mı, kodlar
benzersiz mi, her kulüpte 10 ay ve dolu alan var mı. Bozuksa paket
yazılmaz.

`test/club_module_test.dart` aynı denetimleri paket üzerinde tekrar
yapar ve ekranların iki temayı da ele aldığını doğrular.

## Açık işler

- **PDF çıktıları cihazda gözden geçirilmedi.** Pano işinde yapıldığı
  gibi (`PANO_YAPILACAKLAR.md` madde 1) 52 kulübün planı taşma ve boş
  sayfa açısından taranmalı. Özellikle uzun kulüp adları — "Kültür ve
  Tabiat Varlıklarını Koruma ve Okul Müzesi Kulübü" 58 karakter —
  künyede satır taşırabilir.
- **e-Okul Sosyal Etkinlik Modülü ile bağ yok.** MADDE 8/5 kayıtların
  oraya işlenmesini istiyor; uygulama yalnızca evrak üretir, öğretmen
  e-Okul'a elle girer. Bu bilinçli: e-Okul'un açık API'si yok.
- ~~Kulüpsüz öğrenci uyarısı~~ **Yapıldı.** `kulupsuzOgrenciler` tek
  SQL sorgusuyla açıkta kalanları buluyor; ana ekranda sarı kart olarak
  görünür, dokununca sınıf sınıf listelenir. Herkes bir kulübe yazılıysa
  kart hiç çıkmaz.

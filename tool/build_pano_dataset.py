# -*- coding: utf-8 -*-
"""Belirli gün pano/etkinlik içerik paketini üretir.

Çıktı: `assets/data/pano_icerikleri.json.gz`

## İçerik nereden geliyor — DÜRÜST AYRIM
Her maddede `kaynak` alanı var:

  * "meb"   — MEB Temel Eğitim Genel Müdürlüğü etkinlik rehberinden
              alınan etkinlikler (23 Nisan rehberi:
              tegm.meb.gov.tr/dosya/23nisan/).
  * "genel" — Tarihsel gerçekler ve yaygın okul uygulamasına dayanan,
              bu proje için yazılmış içerik. Resmî bir MEB yayını
              DEĞİLDİR; öğretmen kendi süzgecinden geçirmeli.

Hazır pano görseli, boyama şablonu, telifli şiir veya indirme
paketindeki konuşma kopyalanmaz. Dış kaynak yalnızca fikir verir.

Bu ayrım ekranda da gösterilir. Uydurulmuş bir metni "MEB kaynaklı"
göstermek, öğretmeni resmî evrakta yanlış bilgiye sürükler.

## Her madde ne içerir
  baslik      — pano başlığı
  ozet        — 2-3 cümlelik bilgi metni (panoya yazılabilir)
  sloganlar   — pano için kısa ifadeler
  etkinlikler — sınıf içi çalışma: ad + malzeme + adımlar
  program, konuşma, şiir — tören taslağı (pano_toren_metinleri.py)
"""
import os, json, gzip
from pano_toren_metinleri import TOREN
from pano_kurgu_icerikleri import KURGU
from pano_denetim import denetle
from pano_paletleri import dogrula as palet_dogrula

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)

# ---------------------------------------------------------------------
# İçerik. `ad` alanı belirli_gun_hafta.json içindeki adla BİREBİR aynı
# olmalı; yoksa eşleşme kurulmaz (test bunu doğrular).
# ---------------------------------------------------------------------
ICERIK = [
    {
        'ad': 'Ulusal Egemenlik ve Çocuk Bayramı',
        'kaynak': 'meb',
        'ozet': '23 Nisan 1920’de Türkiye Büyük Millet Meclisi açıldı ve '
                'egemenlik millete geçti. Mustafa Kemal Atatürk bu günü '
                'dünya çocuklarına armağan etti; bayram hem ulusal '
                'egemenliği hem çocukları kutlar.',
        'sloganlar': [
            'Egemenlik kayıtsız şartsız milletindir',
            'Egemenlik verilmez, alınır',
            '23 Nisan 1920 — Türkiye Büyük Millet Meclisi açıldı',
            'Dünyanın çocuklara armağan edilen tek bayramı',
        ],
        'etkinlikler': [
            {
                'ad': 'Sınıflarımızı Süsleyelim',
                'malzeme': ['Kırmızı ve beyaz A4 kâğıt', 'Yapıştırıcı',
                            'İp veya kurdele', 'Makas'],
                'adimlar': [
                    'Kâğıtları uzun kenarından yelpaze şeklinde katlayın.',
                    'Katlanan kâğıdı tam ortasından bastırıp yapıştırın.',
                    'Bir kırmızı ve bir beyaz parçayı birleştirip daire '
                    'elde edin.',
                    'Üst kısma ip geçirip sınıfın köşelerine asın.',
                ],
            },
            {
                'ad': 'Mustafa Kemal Atatürk’e Mektubum',
                'malzeme': ['Mektup kâğıdı', 'Kalem', 'Pano'],
                'adimlar': [
                    'Her öğrenci Atatürk’e hitaben bir mektup yazar.',
                    'Mektuplar sesli okunur, gönüllü öğrenciler paylaşır.',
                    'Mektuplar sınıf panosunda sergilenir.',
                ],
            },
            {
                'ad': 'Bugün Başkan Benim',
                'malzeme': ['Görev kartları'],
                'adimlar': [
                    'Sınıf içinde temsilî bir meclis kurulur.',
                    'Öğrenciler sınıfa dair bir konuyu tartışıp oylar.',
                    'Alınan karar tutanağa yazılıp panoya asılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Cumhuriyet Bayramı',
        'kaynak': 'genel',
        'ozet': '29 Ekim 1923’te Türkiye Büyük Millet Meclisi cumhuriyeti '
                'ilan etti ve Mustafa Kemal Atatürk ilk cumhurbaşkanı '
                'seçildi. Cumhuriyet, yönetimin halkın seçtiği '
                'temsilcilere dayandığı yönetim biçimidir.',
        'sloganlar': [
            'Ne mutlu Türk’üm diyene',
            '29 Ekim 1923 — Cumhuriyet ilan edildi',
            'Cumhuriyet, milletin kendi kendini yönetmesidir',
        ],
        'etkinlikler': [
            {
                'ad': 'Cumhuriyet Zaman Şeridi',
                'malzeme': ['Uzun fon kartonu', 'Renkli kalem',
                            'Görsel çıktılar'],
                'adimlar': [
                    '1919-1923 arası olaylar tarih sırasıyla yazılır.',
                    'Her öğrenci bir olayı araştırıp kısa metin hazırlar.',
                    'Şerit panoya asılır, olaylar sınıfça okunur.',
                ],
            },
            {
                'ad': 'Cumhuriyet Bize Ne Kazandırdı',
                'malzeme': ['Yapışkanlı not kâğıdı', 'Tahta'],
                'adimlar': [
                    'Tahtaya "Cumhuriyetle gelen haklar" başlığı yazılır.',
                    'Öğrenciler birer madde yazıp tahtaya yapıştırır.',
                    'Maddeler gruplanır: eğitim, seçme-seçilme, eşitlik.',
                ],
            },
        ],
    },
    {
        'ad': 'Atatürk Haftası',
        'kaynak': 'genel',
        'ozet': '10 Kasım 1938’de Mustafa Kemal Atatürk vefat etti. '
                '10-16 Kasım Atatürk Haftası’dır. Hafta boyunca hayatı, '
                'inkılapları ve eserleri anılır; 10 Kasım’da saat 09.05’te '
                'ülke çapında saygı duruşu yapılır.',
        'sloganlar': [
            '10 Kasım 1938 — Başöğretmeni saygıyla anıyoruz',
            'Hayatta en hakiki mürşit ilimdir',
            'Yurtta sulh, cihanda sulh',
        ],
        'etkinlikler': [
            {
                'ad': 'Atatürk Zaman Şeridi',
                'malzeme': ['Uzun fon kartonu', 'Renkli kalem',
                            'Atatürk görselleri'],
                'adimlar': [
                    '1881–1938 arası dönüm noktaları sıra ile yazılır: '
                    'doğum, Samsun, TBMM, Cumhuriyet, harf inkılabı.',
                    'Her öğrenci bir olayı kısaca araştırıp kartona yazar.',
                    'Şerit panoya asılır, olaylar sınıfça okunur.',
                ],
            },
            {
                'ad': 'Gençliğe Hitabe Panosu',
                'malzeme': ['Fon kartonu', 'Kalem', 'Atatürk görseli'],
                'adimlar': [
                    'Gençliğe Hitabe kısa bölümlere ayrılıp öğrencilere '
                    'dağıtılır.',
                    'Her öğrenci kendi bölümünü el yazısıyla yazar.',
                    'Bölümler birleştirilip anma panosuna asılır.',
                ],
            },
            {
                'ad': 'Anma Köşesi',
                'malzeme': ['Siyah kurdele', 'Çerçeve', 'Alıntı kartları'],
                'adimlar': [
                    'Sınıfın bir köşesi sade ve saygılı biçimde düzenlenir.',
                    'Atatürk’ün bilim ve barış üzerine sözleri kartlara '
                    'yazılır.',
                    '10 Kasım’da köşe başında kısa bir anma yapılır.',
                ],
            },
        ],
    },
    {
        'ad': "Atatürk'ü Anma ve Gençlik ve Spor Bayramı",
        'kaynak': 'genel',
        'ozet': '19 Mayıs 1919’da Mustafa Kemal Atatürk Samsun’a çıktı ve '
                'Kurtuluş Savaşı başladı. Atatürk bu günü Türk gençliğine '
                'armağan etmiştir.',
        'sloganlar': [
            '19 Mayıs 1919 — Kurtuluş Savaşı’nın başlangıcı',
            'Gençlik, geleceğin teminatıdır',
            'Ey Türk gençliği! Birinci vazifen…',
        ],
        'etkinlikler': [
            {
                'ad': 'Gençliğe Hitabe Panosu',
                'malzeme': ['Fon kartonu', 'Atatürk görseli', 'Kalem'],
                'adimlar': [
                    'Gençliğe Hitabe bölümlere ayrılıp öğrencilere '
                    'dağıtılır.',
                    'Her öğrenci kendi bölümünü kendi el yazısıyla yazar.',
                    'Bölümler birleştirilip pano oluşturulur.',
                ],
            },
            {
                'ad': 'Sınıf İçi Spor Şenliği',
                'malzeme': ['Ip', 'Top', 'Kronometre'],
                'adimlar': [
                    'Sınıf takımlara ayrılır.',
                    'Bayrak yarışı ve ip atlama gibi kısa oyunlar yapılır.',
                    'Sportmenlik üzerine kısa bir değerlendirme yapılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Şehitler Günü',
        'kaynak': 'genel',
        'ozet': '18 Mart 1915’te Çanakkale Deniz Zaferi kazanıldı. Bu gün '
                'Çanakkale Zaferi’nin yıl dönümü ve şehitleri anma '
                'günüdür.',
        'sloganlar': [
            'Çanakkale geçilmez',
            '18 Mart 1915 — Çanakkale Deniz Zaferi',
            'Şehitlerimizi saygıyla anıyoruz',
        ],
        'etkinlikler': [
            {
                'ad': 'Çanakkale Şiir Dinletisi',
                'malzeme': ['Şiir metinleri', 'Ses düzeni'],
                'adimlar': [
                    'Çanakkale konulu şiirler seçilir.',
                    'Öğrenciler gruplar hâlinde şiirleri okur.',
                    'Dinleti sonunda saygı duruşunda bulunulur.',
                ],
            },
        ],
    },
    {
        'ad': '15 Temmuz Demokrasi ve Millî Birlik Günü',
        'kaynak': 'genel',
        'ozet': '15 Temmuz 2016 gecesi milletin seçtiği düzene karşı '
                'silahlı bir darbe girişimi yapıldı. Millet sokaklara '
                'çıktı; girişim engellendi. 251 şehit verildi. Okullarda '
                'anma, ders yılının ikinci haftasında yapılır. Amaç korku '
                'değil; millî iradenin, birliğin ve demokrasinin değerini '
                'anlatmaktır.',
        'sloganlar': [
            'Millî irade her şeyin üstündedir',
            'Demokrasi, milletin sözüdür',
            'Birlikte durmak, vatanı korumaktır',
            '15 Temmuz — Demokrasi ve Millî Birlik Günü',
        ],
        'etkinlikler': [
            {
                'ad': 'Demokrasi panosu',
                'malzeme': ['Fon kartonu', 'Kalem', 'Renkli kâğıt'],
                'adimlar': [
                    'Sınıfça demokrasi bir cümleyle tanımlanır: milletin '
                    'sözünün üstün olması.',
                    'Her öğrenci “Demokrasi olmasaydı …” cümlesini bir '
                    'karta yazar.',
                    'Kartlar panoya asılır; birkaç tanesi sesli okunur.',
                ],
            },
            {
                'ad': 'Birlik halkası',
                'malzeme': ['Kâğıt şeritler', 'Zımba veya bant', 'Kalem'],
                'adimlar': [
                    'Her öğrenci şeride bir değer yazar: dinlemek, '
                    'doğruyu söylemek, arkadaşını ezmemek.',
                    'Şeritler birleştirilip bir halka yapılır.',
                    'Halka panoya asılır; bir halka koparsa zincirin '
                    'zayıfladığı konuşulur.',
                ],
            },
            {
                'ad': 'Saygı köşesi',
                'malzeme': ['Sade fon', 'Bayrak görseli (okulun elindeki)',
                            'Kalem'],
                'adimlar': [
                    'Köşeye “251 şehit — minnetle” ve “Gazilerimize '
                    'şükran” yazılır.',
                    'Öğrenciler kısa bir teşekkür cümlesi yazar.',
                    'Cümleler köşede durur; isim listesi ve hazır görsel '
                    'kopyalanmaz.',
                ],
            },
        ],
    },
    {
        'ad': "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü",
        'kaynak': 'genel',
        'ozet': 'İstiklâl Marşı 12 Mart 1921’de Türkiye Büyük Millet '
                'Meclisi tarafından millî marş olarak kabul edildi. '
                'Şairi Mehmet Akif Ersoy, marşı için ödül almayı '
                'reddetmiştir.',
        'sloganlar': [
            '12 Mart 1921 — İstiklâl Marşı kabul edildi',
            'Korkma, sönmez bu şafaklarda yüzen al sancak',
        ],
        'etkinlikler': [
            {
                'ad': 'On Kıta On Grup',
                'malzeme': ['İstiklâl Marşı metni', 'Fon kartonu'],
                'adimlar': [
                    'Marşın kıtaları gruplara dağıtılır.',
                    'Her grup kıtasındaki kelimelerin anlamını araştırır.',
                    'Anlamlar panoda kıtalarla birlikte sergilenir.',
                ],
            },
        ],
    },
    {
        'ad': 'Öğretmenler Günü',
        'kaynak': 'genel',
        'ozet': '24 Kasım 1928’de Mustafa Kemal Atatürk’e Başöğretmenlik '
                'unvanı verildi. Bu gün öğretmenlik mesleğini onurlandırır.',
        'sloganlar': [
            'Başöğretmen Mustafa Kemal Atatürk',
            'Öğretmenler, yeni nesil sizin eseriniz olacaktır',
        ],
        'etkinlikler': [
            {
                'ad': 'Öğretmenime Teşekkür Ağacı',
                'malzeme': ['Kâğıt yapraklar', 'Fon kartonu', 'Kalem'],
                'adimlar': [
                    'Panoya gövdesi çizilmiş bir ağaç asılır.',
                    'Öğrenciler yapraklara teşekkür cümlesi yazar.',
                    'Yapraklar ağaca yapıştırılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Tutum, Yatırım ve Türk Malları Haftası',
        'kaynak': 'genel',
        'ozet': 'Yerli malı haftası olarak da bilinir. Tutumlu olmayı, '
                'birikim yapmayı ve yerli üretimi desteklemeyi anlatır.',
        'sloganlar': [
            'Yerli malı, yurdun malı',
            'Tutumlu ol, geleceğine yatırım yap',
        ],
        'etkinlikler': [
            {
                'ad': 'Yerli Malı Şöleni',
                'malzeme': ['Kuru yemiş ve yerli ürünler', 'Peçete'],
                'adimlar': [
                    'Öğrenciler yerli üretim kuru gıda getirir.',
                    'Ürünlerin nerede yetiştiği harita üzerinde gösterilir.',
                    'Sınıfça paylaşılır, israf üzerine konuşulur.',
                ],
            },
        ],
    },
    {
        'ad': 'Enerji Tasarrufu Haftası',
        'kaynak': 'genel',
        'ozet': 'Enerjinin bilinçli kullanılması hem aile bütçesini hem '
                'doğal kaynakları korur. Hafta boyunca okulda tasarruf '
                'çalışmaları yapılır.',
        'sloganlar': [
            'Kullanmadığın ışığı söndür',
            'Enerjini boşa harcama, geleceğe sakla',
        ],
        'etkinlikler': [
            {
                'ad': 'Sınıf Enerji Denetçisi',
                'malzeme': ['Kontrol listesi', 'Yaka kartı'],
                'adimlar': [
                    'Her gün bir öğrenci enerji denetçisi seçilir.',
                    'Boşa yanan ışık ve açık kalan cihazlar kaydedilir.',
                    'Hafta sonunda tasarruf raporu panoya asılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Yeşilay Haftası',
        'kaynak': 'genel',
        'ozet': 'Yeşilay 1920’de kuruldu; bağımlılıkla mücadele eder. '
                'Hafta boyunca sağlıklı yaşam ve bağımlılıktan korunma '
                'anlatılır.',
        'sloganlar': [
            'Sağlıklı nesil, sağlıklı gelecek',
            'Bağımlılığa hayır',
        ],
        'etkinlikler': [
            {
                'ad': 'Sağlıklı Alışkanlıklar Panosu',
                'malzeme': ['Fon kartonu', 'Görseller'],
                'adimlar': [
                    'Sınıf iki gruba ayrılır: sağlıklı ve zararlı '
                    'alışkanlıklar.',
                    'Her grup kendi listesini hazırlar.',
                    'Listeler karşılaştırmalı olarak panoya asılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Bilim ve Teknoloji Haftası',
        'kaynak': 'genel',
        'ozet': 'Bilimin günlük hayattaki yerini ve Türk bilim '
                'insanlarının çalışmalarını tanıtır.',
        'sloganlar': [
            'Hayatta en hakiki mürşit ilimdir',
            'Merak et, sor, araştır',
        ],
        'etkinlikler': [
            {
                'ad': 'Basit Deney Şenliği',
                'malzeme': ['Karbonat', 'Sirke', 'Balon', 'Şişe'],
                'adimlar': [
                    'Gruplar basit bir deney seçer.',
                    'Deney sınıfta uygulanır, gözlem kaydedilir.',
                    'Sonuçlar deney raporu olarak panoya asılır.',
                ],
            },
            {
                'ad': 'Türk Bilim İnsanları',
                'malzeme': ['Araştırma kâğıdı', 'Görsel'],
                'adimlar': [
                    'Her öğrenciye bir bilim insanı verilir.',
                    'Kısa biyografi ve çalışma alanı araştırılır.',
                    'Kartlar panoda sergilenir.',
                ],
            },
        ],
    },
    {
        'ad': 'Kızılay Haftası',
        'kaynak': 'genel',
        'ozet': 'Türkiye Kızılay Derneği 1868’de kuruldu. Depremde, selde, '
                'yangında ve savaşta ayrım gözetmeden yardım ulaştırır; '
                'kan bağışı toplar, aşevi ve barınma hizmeti verir. Hafta '
                'boyunca yardımlaşma, dayanışma ve gönüllülük işlenir.',
        'sloganlar': [
            'İyilik yapan iyilik bulur',
            'Bir damla kan, bir hayat',
            'Kızılay 1868’den beri iyiliğin adresi',
            'Yardım için felaketi bekleme',
            'Kırmızı hilal, umudun işareti',
            'Paylaşmak azaltmaz, çoğaltır',
        ],
        'etkinlikler': [
            {
                'ad': 'Afet Çantamda Ne Var?',
                'duzey': '3-4', 'sure': '40dk', 'mekan': 'sinif',
                'hazirlik': 'yok', 'tip': 'sinif-ici',
                'malzeme': ['Tahta veya kâğıt', 'Kalem'],
                'adimlar': [
                    'Tahtaya “Afet Çantası” başlığı yazılır.',
                    'Öğrenciler dört kişilik gruplara ayrılır.',
                    'Her grup çantaya konacak on eşya belirler.',
                    'Gruplar listelerini okur; ortak çıkanlar işaretlenir.',
                    'Sınıfça öncelik sırası tartışılır: su, ilaç, düdük.',
                    'Son liste panoya asılır.',
                ],
            },
            {
                'ad': 'İyilik Kutusu',
                'duzey': '1-2', 'sure': '20dk', 'mekan': 'sinif',
                'hazirlik': 'basit', 'tip': 'sinif-ici',
                'malzeme': ['Karton kutu', 'Renkli kâğıt', 'Kalem'],
                'adimlar': [
                    'Sınıfa bir kutu konur, üzerine “İyilik Kutusu” yazılır.',
                    'Her öğrenci gün içinde yaptığı bir iyiliği kâğıda yazar.',
                    'Kâğıtlar isimsiz olarak kutuya atılır.',
                    'Hafta sonunda notlar sesli okunur.',
                ],
            },
            {
                'ad': 'Kırmızı Hilal Rozeti',
                'duzey': '1-2', 'sure': '20dk', 'mekan': 'sinif',
                'hazirlik': 'basit', 'tip': 'sinif-ici',
                'malzeme': ['Beyaz fon kartonu', 'Kırmızı boya', 'Makas'],
                'adimlar': [
                    'Beyaz kartondan daireler kesilir.',
                    'Üzerine kırmızı hilal yapıştırılır veya boyanır.',
                    'Arkasına öğrencinin adı yazılır.',
                    'Rozetler hafta boyunca yakaya takılır.',
                ],
            },
            {
                'ad': 'Bir Bağışın Yolculuğu',
                'duzey': '5-8', 'sure': '40dk', 'mekan': 'sinif',
                'hazirlik': 'onceden', 'tip': 'sinif-ici',
                'malzeme': ['Rol kartları (bağışçı, gönüllü, şoför, '
                            'depo görevlisi, afetzede)'],
                'adimlar': [
                    'Beş rol kartı dağıtılır, sınıf gruplara ayrılır.',
                    'Her grup kendi rolünün görevini iki cümleyle yazar.',
                    'Bağıştan teslimata kadar sıra canlandırılır.',
                    'Zincirin bir halkası çıkarılır: ne olur, tartışılır.',
                ],
            },
            {
                'ad': 'Veli Katılımlı İyilik Defteri',
                'duzey': 'hepsi', 'sure': 'hafta', 'mekan': 'sinif',
                'hazirlik': 'basit', 'tip': 'veli-katilimli',
                'malzeme': ['Bir defter', 'Poşet dosya'],
                'adimlar': [
                    'Defter sırayla her öğrencinin evine gider.',
                    'Aile o gün yaptığı bir iyiliği bir cümleyle yazar.',
                    'Ertesi gün defter sınıfta okunur.',
                ],
            },
        ],
        'panoBaslik': 'KIZILAY HAFTASI',
        'vecize': 'Yurtta sulh, cihanda sulh.',
        'vecizeKaynak': 'Mustafa Kemal Atatürk',
        'panoParagraflar': [
            'Türkiye Kızılay Derneği 1868’de kuruldu. Savaş yaralılarına '
            'bakmak için başlayan çalışma bugün deprem, sel, yangın ve göç '
            'gibi her afeti kapsar. Kızılay bir devlet kurumu değil, '
            'gönüllülerle ayakta duran bir yardım kuruluşudur.',

            'Kızılay yardım ederken ayrım gözetmez. Din, dil, köken veya '
            'görüş sormaz; yalnızca ihtiyaca bakar. Tarafsızlık ilkesi, '
            'yardımın herkese eşit ulaşmasını sağlar.',

            'Kan bağışı Kızılay’ın en bilinen işidir. Kan üretilemez, '
            'yalnızca insandan insana bağışlanır.',
        ],
        'panoKartlar': [
            {'baslik': 'Günün anlamı',
             'metin': 'Kızılay Haftası yardımlaşmayı ve gönüllülüğü '
                      'anlatır. Kızılay afette ayrım gözetmeden yardım '
                      'ulaştırır.'},
            {'baslik': '1868 — Kuruluş',
             'metin': 'Savaş yaralılarına bakmak için kurulan dernek, '
                      'bugün tüm afetleri kapsayan bir yardım ağıdır.'},
            {'baslik': 'Kan bağışı',
             'metin': 'Kan üretilemez, yalnızca bağışlanır. Bir ünite kan '
                      'birden çok hastaya yardım edebilir.'},
            {'baslik': 'Afet çantası',
             'metin': 'Su, bisküvi, fener, düdük, ilaç ve battaniye. '
                      'Afetten önce hazırlanmak en iyi yardımdır.'},
        ],
        'kronoloji': [
            {'yil': '1868',
             'olay': 'Türkiye Kızılay Derneği kuruldu; savaş yaralılarına '
                     'bakmak için çalıştı.'},
            {'yil': '1877',
             'olay': 'Kızılay adı ve kırmızı hilal işareti kullanılmaya '
                     'başlandı.'},
            {'yil': 'Cumhuriyet dönemi',
             'olay': 'Afet yardımı, aşevi ve kan hizmetleri '
                     'kurumsallaştı.'},
            {'yil': 'Bugün',
             'olay': 'Kan bağışı, afet lojistiği, barınma ve göç yardımı '
                     'yürütülür.'},
        ],
        'sozluk': [
            {'kavram': 'Kızılay',
             'tanim': '1868’de kurulan, afet ve ihtiyaç anında yardım '
                      'ulaştıran insani yardım kuruluşu.'},
            {'kavram': 'Afet',
             'tanim': 'Deprem, sel, yangın gibi büyük zarar veren olay.'},
            {'kavram': 'Bağış',
             'tanim': 'Karşılık beklemeden yapılan yardım.'},
            {'kavram': 'Gönüllü',
             'tanim': 'Bir işi ücret almadan, isteyerek yapan kişi.'},
            {'kavram': 'Kan bağışı',
             'tanim': 'Sağlıklı kişinin ihtiyacı olan hastalar için kan '
                      'vermesi.'},
            {'kavram': 'Dayanışma',
             'tanim': 'Zor durumdakine birlikte destek olma.'},
        ],
        'oncesiSonrasi': [
            {'baslik': 'Afete hazırlık',
             'oncesi': 'Afet olduktan sonra yardım aranır. Kimin nereye '
                       'gideceği, neyin nerede olduğu belli değildir.',
             'sonrasi': 'Afet çantası önceden hazırlanır, toplanma alanı '
                        'bilinir, tatbikat yapılır. Hazırlık zaman '
                        'kazandırır.'},
            {'baslik': 'Kan ihtiyacı',
             'oncesi': 'Hasta yakını hastane hastane kan arar; uygun kan '
                       'bulmak saatler alır.',
             'sonrasi': 'Düzenli bağışla kan stoklarda hazır bekler. '
                        'İhtiyaç anında dakikalar içinde ulaştırılır.'},
            {'baslik': 'Yardımın ulaşması',
             'oncesi': 'Yardımlar dağınık toplanır; bir bölgeye çok, '
                       'diğerine hiç ulaşmaz.',
             'sonrasi': 'Depo ve lojistik ağıyla yardım ihtiyaca göre '
                        'dağıtılır; hiçbir bölge atlanmaz.'},
        ],
        'soruCevap': [
            {'soru': 'Kızılay ne zaman kuruldu?',
             'cevap': '1868’de kuruldu. Osmanlı döneminde savaş '
                      'yaralılarına bakmak için başladı; bugün tüm '
                      'afetlerde görev yapar.'},
            {'soru': 'Kan neden üretilemiyor?',
             'cevap': 'Kan canlı bir dokudur; laboratuvarda yapılamaz. '
                      'Hastanedeki kanın tamamı bağışlanan kandır.'},
            {'soru': 'Afet çantasında neden düdük bulunur?',
             'cevap': 'Enkaz altında bağırmak insanı çabuk yorar. Düdük '
                      'ise az nefesle uzağa duyulan ses çıkarır.'},
            {'soru': 'Kızılay kime yardım eder?',
             'cevap': 'İhtiyacı olan herkese. Din, dil, köken veya görüş '
                      'sormaz. Tarafsızlık temel ilkesidir.'},
            {'soru': 'Kırmızı hilal ne anlama gelir?',
             'cevap': 'Koruyucu bir işarettir. Savaşta bu işareti taşıyan '
                      'araca ve görevliye saldırılması yasaktır.'},
            {'soru': 'Çocuklar nasıl yardım edebilir?',
             'cevap': 'Kan veremeyiz ama anlatabiliriz. Ailemize hatırlatmak, '
                      'afet çantası hazırlamak ve paylaşmak da yardımdır.'},
        ],
        'sozler': [
            'Bu hafta yapacağım iyilik:',
            'Ailemle konuşacağım konu:',
            'Sınıfımda yardım edeceğim kişi:',
        ],
        'ogrenciGorevi': {
            'baslik': 'Bu Hafta Yaptığım İyilik',
            'yonerge': 'Bu hafta yaptığın bir iyiliği yaz.',
        },
        'panoDortlukler': [
            {'baslik': 'Hilal',
             'metin': 'Beyaz zemin üstünde,\nKırmızı bir hilal var.\n'
                      'Nerede bir dert varsa,\nOraya koşan o var.'},
            {'baslik': 'Damla',
             'metin': 'Bir damla su çölde ırmak,\nBir damla kan hasta '
                      'için.\nVermekle azalmaz hiçbiri,\nÇoğalır '
                      'paylaşan için.'},
            {'baslik': 'Küçük el',
             'metin': 'Elim küçük ama sıcak,\nTutarım düşen arkadaşı.\n'
                      'Kalemim ikiye bölünür,\nPaylaşırım son yarısını.'},
            {'baslik': 'Hazırlık',
             'metin': 'Deprem haber vermez, sel izin beklemez,\n'
                      'Bir çanta köşede, düdük boyunda.\n'
                      'Korku değil bu, aklın duruşu,\n'
                      'Hazırlık da yardımdır sonunda.'},
        ],
        'biliyorMuydunuz': [
            'Kızılay 1868’de kuruldu; Türkiye’nin en eski yardım '
            'kuruluşlarından biridir.',
            'Kan üretilemez. Hastanedeki kanın tamamı bağışlanan kandır.',
            'Bir ünite kan, ayrıştırıldığında birden çok hastaya yardım '
            'edebilir.',
            'Kırmızı hilal koruyucu bir işarettir; savaşta bu işareti '
            'taşıyan araca saldırılması yasaktır.',
            'Afet çantasında düdük bulunması önerilir; bağırmak yorar, '
            'düdük yormadan ses çıkarır.',
            'Kızılay bir devlet kurumu değildir; büyük ölçüde gönüllü ve '
            'bağışlarla çalışır.',
        ],
    },
    {
        'ad': 'Orman Haftası',
        'kaynak': 'genel',
        'ozet': 'Ormanlar havayı temizler, erozyonu önler ve canlılara '
                'yaşam alanı sağlar. Hafta boyunca ağaç ve doğa bilinci '
                'işlenir.',
        'sloganlar': [
            'Bir fidan da sen dik',
            'Orman yanarsa gelecek yanar',
        ],
        'etkinlikler': [
            {
                'ad': 'Sınıf Fidanı',
                'malzeme': ['Saksı', 'Toprak', 'Fidan veya tohum'],
                'adimlar': [
                    'Sınıfa bir fidan dikilir.',
                    'Bakım için nöbet çizelgesi hazırlanır.',
                    'Büyüme günlüğü tutulup panoya asılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Engelliler Haftası',
        'kaynak': 'genel',
        'ozet': 'Engellilik bir eksiklik değil, farklılıktır. Hafta '
                'boyunca erişilebilirlik ve empati çalışmaları yapılır.',
        'sloganlar': [
            'Engel değil, farklılık',
            'Erişilebilir okul, herkesin hakkı',
        ],
        'etkinlikler': [
            {
                'ad': 'Empati Parkuru',
                'malzeme': ['Göz bandı', 'Sandalye', 'Ip'],
                'adimlar': [
                    'Öğrenciler gözü kapalı olarak sınıfta yol bulur.',
                    'Bir arkadaşı sözlü yönlendirme yapar.',
                    'Sonrasında hissedilenler sınıfça konuşulur.',
                ],
            },
        ],
    },
    {
        'ad': 'Trafik ve İlkyardım Haftası',
        'kaynak': 'genel',
        'ozet': 'Trafik kuralları ve temel ilk yardım bilgisi hayat '
                'kurtarır. Hafta boyunca güvenli davranışlar öğretilir.',
        'sloganlar': [
            'Kurallara uy, hayat kurtar',
            'Trafikte önce yaya',
        ],
        'etkinlikler': [
            {
                'ad': 'Sınıf İçi Trafik Pisti',
                'malzeme': ['Renkli bant', 'Karton levhalar'],
                'adimlar': [
                    'Yer bandıyla yol ve yaya geçidi oluşturulur.',
                    'Trafik işaretleri kartona çizilip yerleştirilir.',
                    'Öğrenciler sırayla yaya ve sürücü olur.',
                ],
            },
        ],
    },
    {
        'ad': 'Çevre Koruma Haftası',
        'kaynak': 'genel',
        'ozet': 'Doğal kaynakların korunması ve atıkların azaltılması '
                'işlenir. Geri dönüşüm alışkanlığı kazandırılır.',
        'sloganlar': [
            'Dünya bir tane, sahip çık',
            'Çöpü yere değil, kutuya',
        ],
        'etkinlikler': [
            {
                'ad': 'Atıktan Sanata',
                'malzeme': ['Temiz atık malzeme', 'Yapıştırıcı', 'Boya'],
                'adimlar': [
                    'Öğrenciler evden temiz atık getirir.',
                    'Gruplar atıklardan bir ürün tasarlar.',
                    'Ürünler sergilenip nasıl yapıldığı anlatılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Dünya Çocuk Hakları Günü',
        'kaynak': 'genel',
        'ozet': '20 Kasım 1989’da Çocuk Haklarına Dair Sözleşme kabul '
                'edildi. Her çocuğun eğitim, sağlık, korunma ve oyun '
                'hakkı vardır.',
        'sloganlar': [
            'Her çocuğun hakkı vardır',
            'Oyun oynamak bir haktır',
        ],
        'etkinlikler': [
            {
                'ad': 'Haklarım Panosu',
                'malzeme': ['Fon kartonu', 'Renkli kalem'],
                'adimlar': [
                    'Çocuk hakları maddeleri sadeleştirilerek okunur.',
                    'Her öğrenci bir hakkı resimle anlatır.',
                    'Resimler panoda sergilenir.',
                ],
            },
        ],
    },
    {
        'ad': 'İlköğretim Haftası',
        'kaynak': 'genel',
        'ozet': 'İlköğretim Haftası, Eylül ayının üçüncü haftasında, '
                'öğretim yılının açılışıyla birlikte anılır. Okul; harf, '
                'sayı ve dersin yanı sıra sormayı, dinlemeyi ve birlikte '
                'iş yapmayı öğrettiği için yılın ilk işi sınıfı kurmak '
                've okula güvenle gelmeyi alışkanlık haline getirmektir.',
        'sloganlar': [
            'Okul, geleceğin başladığı yer',
            'Sormak serbest, öğrenmek işimiz',
            'Birlikte öğreniyoruz',
            'Her çocuk bu sınıfta yerini bulur',
        ],
        'etkinlikler': [
            {
                'ad': 'Sınıf Sözleşmemiz',
                'malzeme': ['Büyük kâğıt', 'Kalem', 'Istampa veya parmak boyası'],
                'adimlar': [
                    'Sınıfça uyulacak kurallar birlikte belirlenir '
                    '(dinlemek, sırasını beklemek, yardım etmek).',
                    'Kurallar büyük bir kâğıda yazılır.',
                    'Her öğrenci parmak izi veya imzasıyla onaylar; '
                    'sözleşme panoya asılır.',
                ],
            },
            {
                'ad': 'Bu yılın sözüm',
                'malzeme': ['Renkli karton', 'Kalem', 'Fon kartonu'],
                'adimlar': [
                    'Her öğrenci “Bu yıl … öğreneceğim” veya '
                    '“Bu yıl … olacağım” cümlesini bir karta yazar.',
                    'Kartlar sınıfta sesli okunur.',
                    'Kartlar panoya asılır; hafta sonunda bir kez daha '
                    'okunup yıl boyu durur.',
                ],
            },
            {
                'ad': 'Okulumuzu tanıyalım',
                'malzeme': ['Kâğıt', 'Kalem', 'Fon kartonu'],
                'adimlar': [
                    'Gruplar okulun bir yerini seçer: sınıf, bahçe, '
                    'kütüphane, kantin, müdürlük.',
                    'Her grup o yeri kısaca çizer ve ne işe yaradığını '
                    'bir cümleyle yazar.',
                    'Çizimler birleştirilip “Okulumuz” haritası olarak '
                    'panoya asılır.',
                ],
            },
        ],
    },
    {
        'ad': 'Zafer Bayramı',
        'kaynak': 'genel',
        'ozet': '30 Ağustos 1922’de Büyük Taarruz zaferle sonuçlandı. '
                'Bu gün bağımsızlığın simgesidir; okullarda anma ve '
                'kutlama programı yapılır.',
        'sloganlar': [
            '30 Ağustos 1922 — Zafer Bayramı',
            'Emek ve birlik kazandırır',
        ],
        'etkinlikler': [
            {
                'ad': 'Zafer Zaman Çizelgesi',
                'malzeme': ['Fon kartonu', 'Kalem'],
                'adimlar': [
                    '26-30 Ağustos olayları sıra ile yazılır.',
                    'Her öğrenci bir günü kısaca anlatır.',
                    'Çizelge panoya asılır.',
                ],
            },
        ],
    },
]


def main():
    for x in ICERIK:
        extra = TOREN.get(x['ad'])
        if extra:
            x.update(extra)
        # Pano kurgularını besleyen güne özel alanlar. Ana kayıtta zaten
        # varsa üzerine yazılmaz — orada elle girilmiş içerik kazanır.
        for anahtar, deger in KURGU.get(x['ad'], {}).items():
            if not x.get(anahtar):
                x[anahtar] = deger
        x.setdefault('panoBaslik', x['ad'])
        x.setdefault('program', [])
        x.setdefault('mudurKonusmasi', '')
        x.setdefault('ogrenciKonusmalari', [])
        x.setdefault('siirler', [])
        x.setdefault('panoKartlar', [])
        x.setdefault('oyunlar', [])
        x.setdefault('vecize', '')
        x.setdefault('vecizeKaynak', '')
        x.setdefault('panoParagraflar', [])
        x.setdefault('kronoloji', [])
        x.setdefault('ogrenciGorevi', {'baslik': '', 'yonerge': ''})
        x.setdefault('panoDortlukler', [])
        x.setdefault('biliyorMuydunuz', [])
        # Kurgu alanları — boş kalırsa o kurgu öğretmene gösterilmez.
        x.setdefault('sozluk', [])
        x.setdefault('oncesiSonrasi', [])
        x.setdefault('soruCevap', [])
        x.setdefault('sozler', [])

    # Yayın öncesi denetim — kurallar PANO_ICERIK_KURALLARI.md içinde.
    # Şube adı veya sabitlenmiş öğretim yılı taşıyan bir metin panoyu tek
    # sınıfa kilitler; bozuk palet s/b baskıda okunmaz hâle gelir. İkisi de
    # ancak baskıya çıkınca fark edilir, o yüzden burada durdururuz.
    ihlaller = denetle(ICERIK) + [
        'palet: ' + s for s in palet_dogrula()
    ]
    if ihlaller:
        print('DENETİM BAŞARISIZ — %d ihlal:' % len(ihlaller))
        for x in ihlaller:
            print('  -', x)
        raise SystemExit(1)

    paket = {'surum': 2, 'icerikler': ICERIK}
    veri = json.dumps(paket, ensure_ascii=False,
                      separators=(',', ':')).encode('utf-8')
    hedef = os.path.join(PROJE, 'assets', 'data', 'pano_icerikleri.json.gz')
    with gzip.open(hedef, 'wb', compresslevel=9) as f:
        f.write(veri)

    meb = sum(1 for x in ICERIK if x['kaynak'] == 'meb')
    etk = sum(len(x['etkinlikler']) for x in ICERIK)
    print(f'gun: {len(ICERIK)}  (MEB kaynakli: {meb})  etkinlik: {etk}')
    print(f'ham {len(veri)} B -> gzip {os.path.getsize(hedef)} B')
    print(hedef)


if __name__ == '__main__':
    main()

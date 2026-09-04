# -*- coding: utf-8 -*-
"""Belirli gün tören taslakları — konuşma, şiir, program.

Bu metinler resmî MEB belgesi DEĞİLDİR. Okul törenlerinde kullanılan
yaygın akışa göre yazılmış örnektir; öğretmen kendi okuluna uyarlar.
Şiirler kısa sınıf dinletisi içindir. Hazır konuşma, telifli şiir veya
pano görseli kopyalanmaz; yalnızca fikir alınır, metin burada yazılır.
"""

def _konusma(baslik, metin, duzey=None, ton=None):
    """Öğrenci/müdür konuşması.

    `duzey` ve `ton` verilirse öğretmen sınıfına ve okuluna uyanı seçer;
    verilmezse alan yazılmaz (eski kayıtlar aynen çalışır).
    """
    k = {'baslik': baslik, 'metin': metin}
    if duzey:
        k['duzey'] = duzey
    if ton:
        k['ton'] = ton
    return k


def _siir(baslik, metin, duzey=None):
    k = {'baslik': baslik, 'metin': metin}
    if duzey:
        k['duzey'] = duzey
    return k


def _kart(baslik, metin):
    return {'baslik': baslik, 'metin': metin}


def _oyun(ad, sunucu, yonerge, malzeme=''):
    return {
        'ad': ad,
        'sunucu': sunucu,
        'yonerge': yonerge,
        'malzeme': malzeme,
    }


TOREN = {
    'Ulusal Egemenlik ve Çocuk Bayramı': {
        'panoBaslik': '23 NİSAN ULUSAL EGEMENLİK VE ÇOCUK BAYRAMI',
        'program': [
            'Saygı duruşu ve İstiklâl Marşı',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması: Egemenlik millete aittir',
            'Şiir dinletisi',
            'Sınıf meclisi kararının okunması',
            'Sandalye kapmaca',
            'Çuval yarışı',
            'Yumurta taşıma',
            'Bayrak yarışı',
            'Müzik dinletisi ve serbest etkinlik',
            'Kapanış',
        ],
        'oyunlar': [
            _oyun(
                'Sandalye kapmaca',
                'Sandalye kapmaca için yarışmacıları davet ediyorum.',
                'Sandalyeler, oyuncu sayısından bir eksik daireye dizilir. '
                'Müzik çalar; durunca herkes boş sandalye arar. Ayakta kalan '
                'çıkar. İtmek yok. Son kalan kazanır.',
                'Sandalye, müzik',
            ),
            _oyun(
                'Çuval yarışı',
                'Çuval yarışı için iki takımı çizgiye davet ediyorum.',
                'Her yarışçı çuvala girer, belirlenen çizgiye zıplayarak '
                'gider ve döner. Çuvaldan çıkmak veya düşmek turu bozar. '
                'Takım arkadaşı ancak dönüşte başlar.',
                'Çuval (öğrenci başına bir veya nöbetleşe)',
            ),
            _oyun(
                'Yumurta taşıma',
                'Yumurta taşıma için yarışmacıları çizgiye davet ediyorum.',
                'Kaşığın üzerinde haşlanmış yumurta veya top ile çizgiye '
                'gidilir, dönülür. Düşürene kadar devam. Elle tutmak yok. '
                'İlk bitiren kazanır.',
                'Kaşık, haşlanmış yumurta veya küçük top',
            ),
            _oyun(
                'Bayrak yarışı',
                'Bayrak yarışı için takımları yerlerine davet ediyorum.',
                'İki veya üç takım. Bayrak elden ele teslim edilir; '
                'teslim almadan koşulmaz. Son koşucu çizgiyi ilk geçen '
                'takım kazanır.',
                'Küçük bayrak veya eşarp',
            ),
            _oyun(
                'Müzik dinletisi ve serbest etkinlik',
                'Müzik dinletisi ve serbest etkinlik için alanı açıyoruz.',
                'Sınıf korosu veya bir 23 Nisan şarkısı dinletilir. Kalan '
                'süre bahçede serbest oyuna bırakılır. Düdükle toplanılır, '
                'kapanışa geçilir.',
                'Müzik çalar veya koro',
            ),
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler, kıymetli veliler; '
            '23 Nisan 1920, milletimizin kendi iradesini Mecliste topladığı gündür. '
            'O gün Ankara’da Türkiye Büyük Millet Meclisi açıldı. Savaş yıllarında, '
            'yurdun dört bir yanından gelen temsilciler tek bir kararla milletin '
            'sözünün üstün olduğunu gösterdi. “Egemenlik kayıtsız şartsız '
            'milletindir” ilkesi, o günden beri devletimizin temelidir.\n\n'
            'Mustafa Kemal Atatürk bu günü dünya çocuklarına armağan etti. '
            'Çünkü bağımsız bir ülkenin geleceği, çocukların güvenle büyümesi, '
            'öğrenmesi ve söz hakkı bulmasıyla ayakta durur. Bugün okulumuzda '
            'sizin sesiniz duyulsun diye toplandık. Sınıf meclisinde konuşmak, '
            'arkadaşını dinlemek, bir karara varmak — bunlar küçük yaşta '
            'öğrenilen büyük işlerdir.\n\n'
            'Sizden beklediğimiz, bu bayramı yalnızca kutlamak değil; '
            'her gün dersinizde, bahçede ve evinizde aynı sorumlulukla '
            'davranmaktır. Hepinizi saygı ve sevgiyle selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Egemenlik millete aittir',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım '
                've velilerimiz. Bugün 23 Nisan. Yüz yılı aşkın süre önce, '
                '23 Nisan 1920’de Türkiye Büyük Millet Meclisi açıldı. '
                'O Meclis, milletin kendi kararını kendisinin vereceğini '
                'bütün dünyaya duyurdu.\n\n'
                'Egemenlik, bir milletin “ben varım, söz benimdir” demesidir. '
                'Atatürk bu günü bize, çocuklara armağan etti. Demek ki '
                'biz de bu ülkenin bir parçasıyız. Sınıfta söz almak, '
                'arkadaşımızı dinlemek, oy vermek ve verilen karara uymak '
                'egemenliği küçük yaşta yaşamaktır.\n\n'
                'Bugün şiir okuyacağız, pano asacağız, belki sınıf başkanı '
                'seçeceğiz. Bunlar oyuncak değil; birlikte iş yapmayı '
                'öğrenmektir. Büyüdüğümüzde de aynı sorumlulukla çalışacağız. '
                'Beni dinlediğiniz için teşekkür ederim. 23 Nisanımız kutlu olsun.',
            ),
        ],
        'siirler': [
            _siir(
                '23 Nisan (sınıf dinletisi örneği)',
                'Yirmi üç Nisan, kapı açıldı,\n'
                'Milletin sözü Mecliste yazıldı.\n'
                'Ankara’da umut bir çiçek gibi,\n'
                'Yurdun dört yanına ışık saçıldı.\n\n'
                'Çocuklara armağan bu güzel gün,\n'
                'Bayrak dalgalanır, gönüller durgun.\n'
                'Biz de sözümüzü yüksek söyleyelim,\n'
                'Çalışarak büyüsün bu kutlu yurdun.',
            ),
            _siir(
                'Çocukların günü (sınıf dinletisi örneği)',
                'Bu gün bizim, bu söz bizim,\n'
                'Mecliste açıldı yol bizim.\n'
                'Oyna, öğren, sözünü söyle,\n'
                'Arkadaşını dinle, el ele.\n\n'
                'Ata armağan etti bu günü,\n'
                'Büyütün emeği, koruyun yünü.\n'
                'Egemenlik milletin, işimiz açık,\n'
                'Yarın bu sınıftan yürür aydınlık.',
            ),
            _siir(
                'Meclis açıldı (sınıf dinletisi örneği)',
                'Yirmi üç Nisan, Ankara’da bir çatı,\n'
                'Milletin kararı orada yattı.\n'
                'Çocuklara kaldı bu kutlu iş,\n'
                'Söz almak, oy vermek, birlikte gülüş.\n\n'
                'Bayrak gökte, sıra yerde,\n'
                'Oyun da var, emek de.\n'
                'Bu gün eğlenir, yarın çalışırız,\n'
                'Vatanı büyütmek için yarışırız.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '23 Nisan, ulusal egemenliğin ve çocukların bayramıdır. '
                'Milletin kendi kendini yönetmesi bu günde Meclisle görünür oldu.',
            ),
            _kart(
                '23 Nisan 1920',
                'Türkiye Büyük Millet Meclisi Ankara’da açıldı. '
                'Yurdun dört yanından gelen milletvekilleri milletin sözünü '
                'tek çatı altında topladı.',
            ),
            _kart(
                'Atatürk’ün armağanı',
                'Mustafa Kemal Atatürk bu günü dünya çocuklarına armağan etti. '
                'Bağımsız bir ülkenin geleceği çocukların güvenle büyümesine bağlıdır.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Sınıf meclisi kurar, şiir okur, sandalye kapmaca, çuval '
                've yumurta taşıma oynarız. Kapanışta müzik dinleriz.',
            ),
        ],
        'vecize':
            'Küçük hanımlar, küçük beyler! Sizler hepiniz geleceğin bir '
            'gülü, bir yıldızısınız. Memleketi asıl aydınlığa boğacak '
            'olan sizsiniz.',
        'vecizeKaynak': 'Mustafa Kemal Atatürk',
        'panoParagraflar': [
            '23 Nisan 1920’de Ankara’da Türkiye Büyük Millet Meclisi '
            'açıldı. Milletin sözü tek çatı altında toplandı; egemenlik '
            'kayıtsız şartsız millete ait oldu.',
            'Mustafa Kemal Atatürk bu günü dünya çocuklarına armağan '
            'etti. Bayram hem ulusal egemenliği hem çocukların söz '
            'hakkını kutlar.',
            'Sınıfta söz almak, dinlemek ve birlikte karar vermek, '
            'egemenliği küçük yaşta yaşamaktır. Bu pano o sözün asıldığı '
            'yerdir.',
        ],
        'kronoloji': [
            {'yil': '23 Nisan 1920',
             'olay': 'TBMM Ankara’da açıldı. Egemenlik millete geçti.'},
            {'yil': 'Çocuklara armağan',
             'olay': 'Atatürk bu günü dünya çocuklarına armağan etti.'},
            {'yil': 'Bugün sınıfta',
             'olay': 'Meclis, şiir, oyun ve dilek kartı: söz bizimdir.'},
        ],
        'ogrenciGorevi': {
            'baslik': '23 Nisan Dileğim',
            'yonerge': 'Kartı kes. Adını ve sınıfını yaz. Bu yılki dileğini '
                       'doldur. Panoya as.',
        },
        'panoDortlukler': [
            _siir(
                'Meclis',
                'Yirmi üç Nisan, kapı açıldı,\n'
                'Milletin sözü Mecliste yazıldı.\n'
                'Ankara’da umut bir çiçek gibi,\n'
                'Yurdun dört yanına ışık saçıldı.',
            ),
            _siir(
                'Armağan',
                'Ata armağan etti bu günü,\n'
                'Çocuklara kaldı bu kutlu iş.\n'
                'Söz almak, oy vermek, el ele gülüş,\n'
                'Yarın bu sınıftan yürür aydınlık.',
            ),
            _siir(
                'Bayrak',
                'Bayrak gökte, sıra yerde,\n'
                'Oyun da var, emek de.\n'
                'Bu gün eğlenir, yarın çalışırız,\n'
                'Vatanı büyütmek için yarışırız.',
            ),
            _siir(
                'Sözümüz',
                'Bu gün bizim, bu söz bizim,\n'
                'Mecliste açıldı yol bizim.\n'
                'Oyna, öğren, sözünü söyle,\n'
                'Arkadaşını dinle, el ele.',
            ),
        ],
        'biliyorMuydunuz': [
            '23 Nisan, Atatürk’ün dünya çocuklarına armağan ettiği gündür.',
            'TBMM 23 Nisan 1920’de Ankara’da açıldı; egemenlik millete geçti.',
            '“Egemenlik kayıtsız şartsız milletindir” bu günün temel sözüdür.',
        ],
    },
    'Cumhuriyet Bayramı': {
        'panoBaslik': '29 EKİM CUMHURİYET BAYRAMI',
        'program': [
            'İstiklâl Marşı',
            'Saygı duruşu',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması: Cumhuriyet nedir?',
            'Şiir dinletisi',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler ve veliler; '
            '29 Ekim 1923, Türkiye Cumhuriyeti’nin ilan edildiği gündür. '
            'O gün Meclis, milletin seçtiği temsilciler eliyle yönetilen '
            'bir devlet kurduğunu bütün dünyaya duyurdu. Cumhuriyet; '
            'padişahın değil, milletin sözünün geçtiği düzendir.\n\n'
            'Cumhuriyet bize okul, seçme-seçilme, kanun önünde eşitlik '
            'gibi haklar bıraktı. Bu haklar kendiliğinden durmaz; her kuşak '
            'onları öğrenerek ve çalışarak yaşatır. Bugün okulumuzda '
            'tarihi hatırlıyor, bayrağımızı selamlıyor ve öğrencilerin '
            'emeğini sergiliyoruz.\n\n'
            'Sizden ricam, bu günü yalnızca bir tören olarak değil, '
            'sorumluluk günü olarak görmenizdir. Dersinize sahip çıkmak, '
            'arkadaşınıza saygı duymak, yalan söylememek — cumhuriyet '
            'bunlarla ayakta durur. Hepinizi saygıyla selamlarım.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Cumhuriyet nedir?',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım. '
                'Cumhuriyet, halkın kendi kendini yönetmesidir. 29 Ekim 1923’te '
                'bu yönetim biçimi kabul edildi ve Mustafa Kemal Atatürk '
                'ilk cumhurbaşkanı seçildi.\n\n'
                'Cumhuriyet olmasaydı belki okula gidemezdik, belki '
                'kız-erkek aynı sınıfta olamazdık. Bugün ders çalışmak, '
                'soru sormak ve birbirimizi dinlemek bize emanet edilen '
                'hakları kullanmaktır.\n\n'
                'Bayrağımızı seviyoruz. Daha önemlisi, onun altında '
                'dürüst ve çalışan olmak istiyoruz. Cumhuriyet Bayramımız '
                'kutlu olsun. Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                'Cumhuriyet (sınıf dinletisi örneği)',
                'Yirmi dokuz Ekim, kutlu bir akşam,\n'
                'Millet sözünü verdi o akşam.\n'
                'Mecliste yankılandı tek bir karar:\n'
                'Yönetim milletin, umut sonsuz olsun.\n\n'
                'Bayrak göklerde, emek yerde,\n'
                'Okulda büyür yarının izi.\n'
                'Cumhuriyet yaşar yüreklerde,\n'
                'Çalışırsak durur bu güzel dizi.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '29 Ekim, cumhuriyetin ilan edildiği gündür. '
                'Yönetim milletin seçtiği temsilcilerdedir.',
            ),
            _kart(
                '29 Ekim 1923',
                'Türkiye Büyük Millet Meclisi cumhuriyeti ilan etti. '
                'Mustafa Kemal Atatürk ilk cumhurbaşkanı seçildi.',
            ),
            _kart(
                'Bize ne kazandırdı?',
                'Eğitim hakkı, kanun önünde eşitlik, seçme ve seçilme. '
                'Bu haklar her kuşağın emeğiyle yaşar.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Zaman şeridi, pano, şiir ve “cumhuriyet bize ne kazandırdı” '
                'konuşması hazırlarız.',
            ),
        ],
    },
    'Atatürk Haftası': {
        'panoBaslik': '10-16 KASIM ATATÜRK HAFTASI',
        'program': [
            'İstiklâl Marşı',
            'Saat 09.05’te saygı duruşu',
            'Okul müdürünün anma konuşması',
            'Öğrenci konuşması: Emaneti yaşatmak',
            'Gençliğe Hitabe’den seçme bölüm',
            'Şiir dinletisi',
            'Anma panosunun açılışı',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler; 10 Kasım 1938, '
            'Mustafa Kemal Atatürk’ün vefat ettiği gündür. Bugün ve bu '
            'hafta boyunca onu anıyoruz. Anmak, yalnızca durup susmak '
            'değildir. Anmak; onun bıraktığı emanetleri — bağımsızlığı, '
            'cumhuriyeti, okulu, bilimi — ciddiye almaktır.\n\n'
            'Atatürk, milletin kendi iradesiyle ayakta durabileceğini '
            'gösterdi. Samsun’dan Meclise, harf inkılabından öğretmenliğe '
            'kadar yaptığı işlerin ortak yanı şudur: bu ülke çalışarak, '
            'öğrenerek ve birlikte hareket ederek yükselir. “Hayatta en '
            'hakiki mürşit ilimdir” sözü, meraka ve doğruya çağrıdır.\n\n'
            '10 Kasım’da saat 09.05’te yurt çapında saygı duruşu yapılır. '
            'O bir dakikalık sessizlik, gürültüyü kesmek içindir; sonra '
            'sınıfa, kitaba ve emeğe dönmek gerekir. Sizden beklediğim, '
            'bu haftayı bir tören olarak geçiştirmek değil; her derste '
            'öğrenmeye sahip çıkmaktır. Başöğretmenimizi minnetle anıyor, '
            'hepinizi saygıyla selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Emaneti yaşatmak',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım. '
                '10 Kasım 1938’de Mustafa Kemal Atatürk vefat etti. '
                'Bu hafta onu anıyoruz. Anmak, yalnızca ismini söylemek '
                'değildir. Anmak; onun bize bıraktığı okulu, bağımsızlığı '
                've çalışma azmini yaşatmaktır.\n\n'
                'Atatürk gençliğe bir emanet verdi: cumhuriyeti ve '
                'istiklâli korumak. Biz çocuklar silah tutmayız. Bizim '
                'görevimiz öğrenmek, doğru söylemek, arkadaşımızı ezmemek '
                've bu ülkeyi çalışarak büyütmektir. Bugün şiir okuyacağız, '
                'pano asacağız, Gençliğe Hitabe’den bölüm okuyacağız. '
                'Bunları gürültüyle değil, saygıyla yapacağız.\n\n'
                'Başöğretmenimizi minnetle anıyorum. Ruhu şad olsun. '
                'Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                '10 Kasım (sınıf dinletisi örneği)',
                'On Kasım sabahı, saat dokuzu beş,\n'
                'Yürekler durur, bayrak yarıya iner.\n'
                'Bir milletin önderi sessizce anılır,\n'
                'Emek, bilim ve vatan omuzlarda durur.\n\n'
                'Anmak yalnızca durmak değildir,\n'
                'Çalışmak, doğruyu söylemek, öğrenmektir.\n'
                'Emanet duruyor sıralarımızda,\n'
                'Bilgiyle büyür yarınlarımızda.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Haftanın anlamı',
                '10-16 Kasım Atatürk Haftası’dır. Mustafa Kemal Atatürk’ün '
                'hayatı, eserleri ve inkılapları bu hafta anılır.',
            ),
            _kart(
                '10 Kasım 1938',
                'Mustafa Kemal Atatürk İstanbul’da vefat etti. Saat 09.05’te '
                'ülke çapında saygı duruşu yapılır.',
            ),
            _kart(
                'Emanet',
                'Gençliğe Hitabe, bağımsızlığı ve cumhuriyeti korumayı '
                'gençliğe emanet eder. Emanet, çalışarak taşınır.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Zaman şeridi, Gençliğe Hitabe panosu, anma köşesi ve '
                'öğrenci konuşması hazırlarız.',
            ),
        ],
    },
    "Atatürk'ü Anma ve Gençlik ve Spor Bayramı": {
        'panoBaslik': "19 MAYIS ATATÜRK'Ü ANMA, GENÇLİK VE SPOR BAYRAMI",
        'program': [
            'İstiklâl Marşı',
            'Saygı duruşu',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması: Gençliğe emanet',
            'Gençliğe Hitabe’den seçme bölüm',
            'Sınıf içi spor etkinliği',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler, değerli öğretmenler; 19 Mayıs 1919, '
            'Mustafa Kemal Atatürk’ün Samsun’a çıktığı gündür. Bu çıkış, '
            'milletin bağımsızlık iradesinin görünür olduğu andır. '
            'Kurtuluş Savaşı’nın fiilî başlangıcı olarak anılır.\n\n'
            'Atatürk bu günü Türk gençliğine armağan etti. Çünkü bir ülkenin '
            'gücü, gençlerin sağlığı, bilgisi ve karakterindedir. Bugün '
            'okulumuzda hem anıyoruz hem de bedenimizi ve zihnimizi '
            'çalıştırıyoruz. Spor, yalnızca yarış değildir; birlikte hareket '
            'etmeyi, kurala uymayı ve yenilgiyi onurlu karşılamayı öğretir.\n\n'
            'Sizden beklediğimiz, Gençliğe Hitabe’deki emaneti ciddiye '
            'almaktır: çalışmak, doğruyu söylemek, vatanını düşünmek. '
            '19 Mayıs’ınız kutlu olsun. Saygılarımla.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Gençliğe emanet',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım. '
                '19 Mayıs 1919’da Atatürk Samsun’a çıktı. O gün umut yeşerdi. '
                'Bu bayram bize armağan edildi; çünkü gençlik, geleceğin '
                'teminatıdır.\n\n'
                'Emanet yalnızca törenle taşınmaz. Emanet; ders çalışmak, '
                'sağlıklı yaşamak, arkadaşını ezmemek ve yalan söylememektir. '
                'Bugün sporda da sınıfta da aynı kararlılığı göstereceğiz. '
                'Atatürk’ü anıyor, gençliğimize sahip çıkıyoruz. Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                '19 Mayıs (sınıf dinletisi örneği)',
                'On dokuz Mayıs, Samsun’da bir sabah,\n'
                'Karadeniz’den umut yükseldi.\n'
                'Bir milletin iradesi yürüdü,\n'
                'Bağımsızlık yolu açıldı.\n\n'
                'Gençlik omuzladı o kutlu yükü,\n'
                'Bilgi, sağlık, emekle büyüdü.\n'
                'Emanet duruyor yüreklerde,\n'
                'Çalışırsak yarın gülümser bize.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '19 Mayıs, Atatürk’ü anma ile gençlik ve spor bayramıdır. '
                'Bağımsızlık yolunun başlangıcı olarak anılır.',
            ),
            _kart(
                '19 Mayıs 1919',
                'Mustafa Kemal Atatürk Samsun’a çıktı. '
                'Kurtuluş Savaşı’nın fiilî başlangıcı kabul edilir.',
            ),
            _kart(
                'Gençliğe armağan',
                'Atatürk bu günü Türk gençliğine armağan etti. '
                'Sağlık, bilim ve karakter emanetin parçasıdır.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Gençliğe Hitabe panosu, kısa spor şenliği, '
                'öğrenci konuşması ve pano hazırlarız.',
            ),
        ],
    },
    'Şehitler Günü': {
        'panoBaslik': '18 MART ÇANAKKALE ZAFERİ VE ŞEHİTLERİ ANMA GÜNÜ',
        'program': [
            'İstiklâl Marşı',
            'Saygı duruşu',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması',
            'Şiir dinletisi',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler; 18 Mart 1915, '
            'Çanakkale Deniz Zaferi’nin yıl dönümüdür. O gün Çanakkale '
            'Boğazı’nı geçmek isteyen donanma, milletin direnişi karşısında '
            'geri çekildi. Bu zafer, yalnızca bir deniz savaşı değildir; '
            'vatan toprağına sahip çıkmanın adıdır.\n\n'
            'Bugün şehitlerimizi saygı duruşuyla anıyoruz. Anmak, yalnızca '
            'isim okumak değildir. Barış içinde yaşamak, okula gitmek, '
            'birbirimize zarar vermemek onların emanetine sahip çıkmaktır.\n\n'
            'Sizden beklediğim, bu programı ciddiyetle dinlemeniz ve '
            'günün anlamını sınıfınıza taşımanızdır. Şehitlerimizi '
            'minnetle anıyor, hepinizi saygıyla selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım. '
                '18 Mart 1915’te Çanakkale’de vatan için canını verenleri '
                'anıyoruz. Onlar geçit vermedi; çünkü bu topraklar emanetti.\n\n'
                'Biz çocuklar silah tutmayız. Bizim görevimiz öğrenmek, '
                'birlik olmak ve bu ülkeyi çalışarak büyütmektir. '
                'Bugün şiir okuyacağız, pano asacağız. Bunları gürültüyle '
                'değil, saygıyla yapacağız.\n\n'
                'Şehitlerimizi minnetle anıyorum. Ruhları şad olsun. '
                'Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                'Anma (sınıf dinletisi örneği)',
                'Çanakkale’de durdu düşman o gün,\n'
                'Geçit vermedi vatan toprağı.\n'
                'Dalga vurdu kayalara, milletin iradesi durdu,\n'
                'İsimleri kaldı yüreklerde.\n\n'
                'Biz de anarız sessizce,\n'
                'Dersimizde, sırada, bahçede.\n'
                'Emanet durur omuzlarda,\n'
                'Çalışmakla öderiz o borcu.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '18 Mart, Çanakkale Deniz Zaferi’nin yıl dönümü ve '
                'şehitleri anma günüdür.',
            ),
            _kart(
                '18 Mart 1915',
                'Çanakkale Boğazı’nı geçmek isteyen donanma geri çekildi. '
                'Bu direniş, vatan savunmasının simgelerindendir.',
            ),
            _kart(
                'Neden anıyoruz?',
                'Anmak, isim ezberlemek değil; barış içinde yaşamak ve '
                'emanete sahip çıkmaktır.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Saygı duruşu, şiir dinletisi ve Çanakkale konulu pano '
                'hazırlarız.',
            ),
        ],
    },
    '15 Temmuz Demokrasi ve Millî Birlik Günü': {
        'panoBaslik': '15 TEMMUZ DEMOKRASİ VE MİLLÎ BİRLİK GÜNÜ',
        'program': [
            'Saygı duruşu ve İstiklâl Marşı',
            'Günün anlam ve önemini belirten konuşma',
            'Öğrenci konuşması: Millî irade',
            'Şiir dinletisi',
            '“15 Temmuz Sözlüğü” — kavramların sınıfça okunması',
            'Sınıf meclisi uygulaması veya kavram eşleştirme oyunu',
            'Kapanış',
        ],
        # Üç ton: okul kendi törenine uyanı seçer. Uzun tören için
        # 'resmî', sınıf içi anma için 'samimi', kalabalık ve kısa
        # program için 'kısa'.
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler, kıymetli veliler;\n\n'
            '15 Temmuz 2016 gecesi, milletin seçtiği düzene karşı silahlı '
            'bir darbe girişimi yapıldı. Meclis, demokrasi ve millî irade '
            'hedef alındı. Millet sokaklara çıktı; polis, asker ve sivil '
            'birlikte durdu. Girişim engellendi. O gece 251 vatan evladı '
            'şehit oldu, iki binden fazla kişi gazi oldu.\n\n'
            'Bugün burada bir korku hikâyesi anlatmak için toplanmadık. '
            'Anlatmak istediğimiz şey çok daha sade: bir ülkede kararı '
            'kim verir? Cevabı millettir. Millet kararını sandıkta '
            'verir. Bu karara silahla, zorla, korkutmayla karşı çıkmak '
            'hukuka da vicdana da sığmaz. Demokrasi budur; süslü bir '
            'kelime değil, milletin sözünün üstün olmasıdır.\n\n'
            'Demokrasi yalnızca bir gece savunulan bir şey de değildir. '
            'Her sabah yeniden kurulur. Sınıfta söz sırası beklemek '
            'demokrasidir. Kendi görüşün azınlıkta kalınca sonucu kabul '
            'etmek demokrasidir. Farklı düşünen arkadaşını dinlemek, ona '
            'zarar vermemek demokrasidir. Bir milletin özgür kalması, '
            'çocuklarının bu alışkanlıkları edinmesine bağlıdır.\n\n'
            'Okullarda anma, ders yılının ikinci haftasında yapılır; '
            'çünkü 15 Temmuz yaz tatiline denk gelir. Bu anmayı her yıl '
            'tekrarlıyoruz, unutmamak için. Unutmamak, kin beslemek '
            'değildir. Unutmamak; aynı acıyı bir daha yaşamamak için '
            'gereken dersi hatırda tutmaktır.\n\n'
            'Bu vatan için canını verenleri minnetle anıyorum. '
            'Gazilerimize şükranlarımızı sunuyorum. Sizlere de huzur '
            'içinde, öğrenerek ve birbirinizi koruyarak büyüyeceğiniz '
            'bir gelecek diliyorum. Hepinizi saygıyla selamlıyorum.',
        'mudurKonusmalari': [
            _konusma(
                'Anma konuşması — resmî ton',
                'Değerli öğretmenler, sevgili öğrenciler, kıymetli '
                'veliler;\n\n'
                '15 Temmuz 2016 gecesi ülkemiz, anayasal düzene ve millî '
                'iradeye yönelik silahlı bir darbe girişimiyle karşılaştı. '
                'Türkiye Büyük Millet Meclisi, milletin seçtiği yönetim ve '
                'demokratik düzen hedef alındı. Milletimiz bu girişime '
                'karşı durdu; emniyet mensupları, askerler ve siviller '
                'birlikte hareket etti ve girişim sonuçsuz kaldı.\n\n'
                'O gece 251 vatandaşımız hayatını kaybetti, iki binden '
                'fazla vatandaşımız yaralanarak gazi oldu. Bugün onları '
                'saygı ve minnetle anıyoruz.\n\n'
                'Bu günün okullarda anılmasının amacı bellidir: millî '
                'iradenin, hukukun ve demokratik düzenin değerini genç '
                'kuşaklara aktarmak. Egemenlik kayıtsız şartsız '
                'milletindir. Bu ilke, bir cümleden ibaret değildir; '
                'devletin kuruluş esasıdır ve korunması hepimizin ortak '
                'sorumluluğudur.\n\n'
                'Şehitlerimizi rahmetle, gazilerimizi şükranla anıyor, '
                'hepinizi saygıyla selamlıyorum.',
                ton='resmî',
            ),
            _konusma(
                'Anma konuşması — samimi ton',
                'Sevgili çocuklar, değerli öğretmen arkadaşlarım;\n\n'
                'Bugün zor bir günü konuşacağız ama korkmanız için değil. '
                'Size bir soru sormak istiyorum: sınıfınızda bir karar '
                'alınacağı zaman ne yaparsınız? Konuşursunuz, tartışırsınız, '
                'sonra oylarsınız değil mi? Peki içinizden biri kalkıp '
                '“ben oylamayı tanımıyorum, karar benim dediğimdir” dese '
                'ne hissedersiniz?\n\n'
                'İşte 15 Temmuz 2016 gecesi olan buydu. Bir grup, milletin '
                'verdiği kararı tanımadı ve zorla yönetimi ele geçirmek '
                'istedi. Ama millet buna izin vermedi. O gece sokağa '
                'çıkanların çoğu asker değildi; öğretmendi, esnaftı, '
                'şofördü, öğrenciydi. 251 kişi hayatını kaybetti.\n\n'
                'Sizden bugün üzülmenizi değil, bir şeyi fark etmenizi '
                'istiyorum: demokrasi uzakta, büyüklerin dünyasında olan '
                'bir şey değil. Sıranızda başlıyor. Arkadaşınızın sözünü '
                'kesmediğinizde, seçimi kaybedince küsmediğinizde, '
                'kendinizden farklı düşünene kötü davranmadığınızda onu '
                'yaşatıyorsunuz.\n\n'
                'Hepinizi seviyorum. İyi ki varsınız.',
                ton='samimi',
            ),
            _konusma(
                'Anma konuşması — kısa',
                'Sevgili öğrenciler;\n\n'
                '15 Temmuz 2016 gecesi, milletin seçtiği düzene karşı bir '
                'darbe girişimi oldu. Millet buna karşı durdu ve girişim '
                'engellendi. O gece 251 kişi şehit oldu.\n\n'
                'Bugün onları anıyoruz. Anmak, bir ismi okumakla bitmez; '
                'o insanların uğrunda durduğu şeyi yaşatmakla olur. '
                'Bizim için bu; öğrenmek, birbirimizi dinlemek ve '
                'kimseye zarar vermemektir.\n\n'
                'Şehitlerimizi saygıyla anıyorum. Hepinize teşekkür '
                'ederim.',
                ton='kısa',
            ),
        ],
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — 1 ve 2. sınıf',
                'Sayın müdürüm, sevgili öğretmenlerim, sevgili '
                'arkadaşlarım;\n\n'
                'Bugün 15 Temmuz’u anıyoruz. Yıllar önce bir gece, bazı '
                'kişiler ülkemizi zorla yönetmek istedi. Ama halkımız '
                'buna izin vermedi.\n\n'
                'Ben küçüğüm. Elimden ne gelir diye düşünüyorum. '
                'Öğretmenim dedi ki: sıranı beklemek, arkadaşını '
                'dinlemek ve kimseyi üzmemek de vatanına sahip çıkmaktır. '
                'Ben bunu yapabilirim.\n\n'
                'Ülkemiz için canını verenlere teşekkür ediyorum. '
                'Beni dinlediğiniz için sağ olun.',
                duzey='1-2',
            ),
            _konusma(
                'Öğrenci konuşması — 3 ve 4. sınıf',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili '
                'arkadaşlarım;\n\n'
                '15 Temmuz 2016 gecesi ülkemizde bir darbe girişimi '
                'yaşandı. Darbe demek, milletin seçtiği yönetimi zorla '
                'devirmeye çalışmak demektir. O gece halkımız sokaklara '
                'çıktı ve buna izin vermedi. 251 kişi hayatını '
                'kaybetti.\n\n'
                'Demokrasi, kararı milletin vermesidir. Bunu okulda da '
                'yaşıyoruz: sınıf başkanını biz seçiyoruz. Seçimi '
                'kazanan da kaybeden de sonuca saygı gösteriyor. Bu '
                'küçük bir alışkanlık gibi görünür ama aslında '
                'demokrasinin ta kendisidir.\n\n'
                'Biz çocuklar silah tutmayız. Bizim görevimiz öğrenmek, '
                'doğruyu söylemek ve arkadaşımızı korumaktır.\n\n'
                'Şehitlerimizi saygıyla anıyorum. Teşekkür ederim.',
                duzey='3-4',
            ),
            _konusma(
                'Öğrenci konuşması — 5 ve üstü',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili '
                'arkadaşlarım;\n\n'
                'Bir devletin en kırılgan yanı ordusu ya da sınırları '
                'değildir; kararı kimin verdiği konusundaki '
                'mutabakattır. 15 Temmuz 2016 gecesi hedef alınan da tam '
                'olarak buydu. Silahlı bir grup, milletin sandıkta '
                'ortaya koyduğu iradeyi yok sayarak yönetimi ele '
                'geçirmeye kalkıştı.\n\n'
                'O gece olanlar, milletin bu iradeye sahip çıkmasıyla '
                'sonuçsuz kaldı. Meydanlara çıkanlar tek bir görüşün '
                'insanları değildi; farklı partilere oy vermiş, farklı '
                'düşünen insanlar aynı yerde durdu. Bu ayrıntı önemli, '
                'çünkü millî birlik aynı şeyi düşünmek demek değildir. '
                'Millî birlik, farklı düşünenlerin ortak kurallarda '
                'buluşabilmesidir.\n\n'
                'Bugün bize düşen görev nedir? Bence en başta, '
                'duyduğumuz her şeye inanmamak. O gece kullanılan en '
                'güçlü silahlardan biri yalan bilgiydi. Doğruyu '
                'araştırmak, kaynağını sormak, aklını kullanmak da bir '
                'vatandaşlık görevidir.\n\n'
                'Şehitlerimizi minnetle anıyor, gazilerimize şükranlarımı '
                'sunuyorum. Teşekkür ederim.',
                duzey='5-8',
            ),
        ],
        'siirler': [
            _siir(
                'Söz Milletin (1-2. sınıf dinletisi)',
                'Bir ülkede söz kimindir?\n'
                'Elbette ki milletindir.\n'
                'Küçüğüz ama biliriz,\n'
                'Bu vatan hepimizindir.\n\n'
                'Sıramızı bekleriz,\n'
                'Arkadaşı dinleriz.\n'
                'Büyüyünce biz de bir gün,\n'
                'Bu emaneti bekleriz.',
                duzey='1-2',
            ),
            _siir(
                'O Gece (3-4. sınıf dinletisi)',
                'O gece karanlık, millet ayaktaydı,\n'
                'Söz milletin olsun diye duruldu.\n'
                'Bayrak inmedi, Meclis susmadı,\n'
                'Birlik oldu, vatan tutuldu.\n\n'
                'Anmak yalnızca isim okumak değil,\n'
                'Barış içinde yaşamaktır asıl.\n'
                'Sırada doğruyu söylemek de birliktir,\n'
                'Yarın bu emaneti biz taşırız nasıl?',
                duzey='3-4',
            ),
            _siir(
                'Emanet (5 ve üstü dinletisi)',
                'Bir sandık kadar sade, bir o kadar ağır,\n'
                'İçinde bir milletin kararı saklıdır.\n'
                'Onu kimse alamaz, kimse değiştiremez,\n'
                'Çünkü orada herkesin bir hakkı vardır.\n\n'
                'Susmadı o gece meydanda duran ses,\n'
                'Ayrı düşünenler aynı yerde durdu.\n'
                'Birlik; aynı olmak değil, anlaşabilmektir,\n'
                'Bunu o gece bu millet yeniden kurdu.\n\n'
                'Şimdi sıra bizde, sırada, sınıfta,\n'
                'Dinlemekle başlar bu emanetin yolu.\n'
                'Bir ülke ancak öyle özgür kalır ki,\n'
                'Çocukları doğruyu söylemeyi bilir.',
                duzey='5-8',
            ),
            _siir(
                'Demokrasi Sınıfta Başlar (koro)',
                'Söz sırası bende değilse susarım,\n'
                'Sıra bana gelince konuşurum.\n'
                'Kaybedersem oylamayı küsmem,\n'
                'Kazanırsam kimseyi ezmem.\n\n'
                'İşte budur, büyük söylenen o şey,\n'
                'Adı demokrasidir, başlar burada.\n'
                'Bir ülke böyle büyür, böyle durur,\n'
                'Küçük küçük alışkanlıklarla.',
                duzey='hepsi',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '15 Temmuz 2016’da darbe girişimi milletin direnişiyle '
                'engellendi. Demokrasiye ve millî iradeye sahip çıkmanın '
                'günüdür.',
            ),
            _kart(
                'Ne zaman anılır?',
                'Okullarda anma, ders yılının ikinci haftasında yapılır. '
                '15 Temmuz yaz tatiline denk gelir.',
            ),
            _kart(
                'Emanet',
                '251 şehit minnetle anılır. Emanet; öğrenmek, birlik olmak '
                've birbirine zarar vermemektir.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Demokrasi panosu, birlik halkası ve sade bir saygı köşesi '
                'hazırlarız.',
            ),
            _kart(
                'Demokrasi nedir?',
                'Milletin kendi kendini yönetmesidir. Karar, milletin '
                'seçtiği temsilciler eliyle alınır.',
            ),
            _kart(
                'Millî irade nedir?',
                'Milletin ortak kararıdır. Sandıkta ortaya çıkar; hiçbir '
                'güç onun yerine geçemez.',
            ),
            _kart(
                'Birlik ne demek değildir?',
                'Herkesin aynı şeyi düşünmesi değildir. Farklı düşünenlerin '
                'ortak kurallarda buluşabilmesidir.',
            ),
            _kart(
                'Bize düşen',
                'Duyduğumuz her bilgiye inanmamak, kaynağını sormak ve '
                'doğruyu araştırmak da vatandaşlık görevidir.',
            ),
        ],
    },
    "İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü": {
        'panoBaslik': "12 MART İSTİKLÂL MARŞI'NIN KABULÜ",
        'program': [
            'İstiklâl Marşı (tamamı veya ilk kıta, sınıf düzeyine göre)',
            'Saygı duruşu',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması: Mehmet Âkif Ersoy',
            'Kıtaların anlamı üzerine kısa sunum',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler; İstiklâl Marşı 12 Mart 1921’de Türkiye Büyük '
            'Millet Meclisi tarafından millî marş olarak kabul edildi. '
            'Şairi Mehmet Âkif Ersoy’dur. Marş, bağımsızlığın ve birliğin '
            'sesidir.\n\n'
            'Her sabah marşı söylerken sözleri ezberlemek yetmez; anlamını '
            'da bilmek gerekir. Mehmet Âkif, marşı için verilen ödülü '
            'kabul etmemiştir. Bu, emeğin vatan için yapıldığını gösterir.\n\n'
            'Bugün kıtaları anlayarak okuyacağız. Saygılarımla.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Mehmet Âkif Ersoy',
                'Sayın müdürüm, değerli öğretmenlerim. 12 Mart 1921’de '
                'İstiklâl Marşı millî marş oldu. Yazan Mehmet Âkif Ersoy, '
                'ödül almayı kabul etmedi.\n\n'
                'Marş her sabah bize vatanı, emeği ve umudu hatırlatır. '
                'Sözlerini ezberlemek kadar anlamını da bilmek görevimizdir. '
                'Korkmamak, çalışmak ve birlik olmak — marşın bize söylediği '
                'budur. Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                'İstiklâl Marşı — 1. kıta (millî marş, okuma önerisi)',
                'Korkma, sönmez bu şafaklarda yüzen al sancak;\n'
                'Sönmeden yurdumun üstünde tüten en son ocak.\n'
                'O benim milletimin yıldızıdır, parlayacak;\n'
                'O benimdir, o benim milletimindir ancak.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '12 Mart, İstiklâl Marşı’nın millî marş olarak kabul '
                'edildiği gündür. Şairi Mehmet Âkif Ersoy’dur.',
            ),
            _kart(
                '12 Mart 1921',
                'Türkiye Büyük Millet Meclisi marşı kabul etti. '
                'Marş, bağımsızlığın sesidir.',
            ),
            _kart(
                'Mehmet Âkif',
                'Şair, marş için ödül almayı kabul etmedi. '
                'Emek vatan içindir.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Kıtaları gruplara böler, kelimelerin anlamını '
                'araştırır, panoda sergileriz.',
            ),
        ],
    },
    'Zafer Bayramı': {
        'panoBaslik': '30 AĞUSTOS ZAFER BAYRAMI',
        'program': [
            'İstiklâl Marşı',
            'Saygı duruşu',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler; 30 Ağustos 1922, '
            'Büyük Taarruz’un zaferle sonuçlandığı gündür. Dumlupınar’da '
            'kazanılan bu zafer, bağımsızlığın güvencesi oldu.\n\n'
            'Zafer, bir günde doğmaz. Hazırlık, emek ve birlik ister. '
            'Siz de derslerinizde aynı kararlılığı göstereceksiniz. '
            'Bugünü minnetle anıyor, hepinizi saygıyla selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması',
                'Sayın müdürüm, değerli öğretmenlerim. 30 Ağustos bize '
                'emeğin ve birliğin kazandırdığını anlatır. Zafer tesadüf '
                'değildir; çalışan kazanır.\n\n'
                'Biz de sırada, bahçede ve evde aynı kararlılıkla '
                'çalışacağız. Zafer Bayramımız kutlu olsun. Teşekkür ederim.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '30 Ağustos Zafer Bayramı’dır. Bağımsızlığın simgelerindendir.',
            ),
            _kart(
                '30 Ağustos 1922',
                'Büyük Taarruz zaferle sonuçlandı. Dumlupınar, bu zaferin '
                'adıyla anılır.',
            ),
            _kart(
                'Emek ve birlik',
                'Zafer bir günde doğmaz. Hazırlık, emek ve birlikte iş '
                'yapmak ister.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                '26-30 Ağustos olaylarını sıra ile yazar, panoya asarız.',
            ),
        ],
    },
    'Öğretmenler Günü': {
        'panoBaslik': '24 KASIM ÖĞRETMENLER GÜNÜ',
        'program': [
            'İstiklâl Marşı',
            'Okul müdürünün konuşması',
            'Öğrenci konuşması: Öğretmenime teşekkür',
            'Teşekkür ağacı / mektup okuma',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli meslektaşlarım, sevgili öğrenciler; 24 Kasım 1928’de '
            'Mustafa Kemal Atatürk’e Başöğretmen unvanı verildi. '
            'Öğretmenlik, yeni nesli yetiştirme işidir. Bir ülkenin '
            'geleceği sınıfta kurulur.\n\n'
            'Bugün emeğe teşekkür ediyoruz. Teşekkür, çiçekten çok '
            'çalışarak, saygı duyarak ve öğrenmeye devam ederek gösterilir. '
            'Hepinizi saygıyla selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Öğretmenime teşekkür',
                'Değerli öğretmenlerim. Bize okumayı, sormayı ve birlikte '
                'iş yapmayı siz öğrettiniz. Yanlış yaptığımızda düzelttiniz, '
                'doğru yaptığımızda yüreklendirdiniz.\n\n'
                '24 Kasım’da emeğiniz için teşekkür ederiz. Sözümüz: '
                'daha çok çalışmak. Öğretmenler Gününüz kutlu olsun.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart(
                'Günün anlamı',
                '24 Kasım Öğretmenler Günü’dür. Öğretmenlik, yeni nesli '
                'yetiştirme işidir.',
            ),
            _kart(
                '24 Kasım 1928',
                'Mustafa Kemal Atatürk’e Başöğretmen unvanı verildi.',
            ),
            _kart(
                'Teşekkür',
                'Teşekkür sözle başlar, çalışarak devam eder.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Teşekkür ağacı kurar, yapraklara cümle yazarız.',
            ),
        ],
    },
    'İlköğretim Haftası': {
        'panoBaslik': 'İLKÖĞRETİM HAFTASI',
        'program': [
            'Saygı duruşu ve İstiklâl Marşı',
            'Okul müdürünün açılış konuşması',
            'Öğrenci konuşması: Bu yılın sözüm',
            'Şiir dinletisi',
            'Sınıf sözleşmesi ve pano tanıtımı',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Değerli öğretmenler, sevgili öğrenciler, kıymetli veliler; '
            'yeni bir öğretim yılına başlıyoruz. İlköğretim Haftası, okulun '
            'kapısını birlikte açtığımız haftadır. Burada harf ve sayı '
            'öğrenilir; daha önemlisi sormak, dinlemek ve birlikte iş '
            'yapmak öğrenilir.\n\n'
            'Bir ülkenin gücü, çocuklarının okula güvenle gelmesiyle '
            'ölçülür. Sizden beklediğim bu yılı bir törenle geçiştirmek '
            'değil; her derste emeğe sahip çıkmaktır. Yeni gelen '
            'arkadaşlarınızı aranıza alın. Öğretmeninize ve birbirinize '
            'saygı gösterin. Yanlış yapmak ayıp değildir; düzeltmemek '
            'ayıptır.\n\n'
            'Yeni öğretim yılınız hayırlı olsun. İlköğretim Haftanız kutlu '
            'olsun. Hepinizi saygıyla selamlıyorum.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Bu yılın sözüm',
                'Sayın müdürüm, değerli öğretmenlerim, sevgili arkadaşlarım. '
                'Yaz bitti, sıralar doldu. Bugün okula geldiğimiz için '
                'mutluyuz. Okul yalnızca ders çözülen yer değildir; '
                'arkadaş edinilen, yanlış yapıp düzeltildiği, soru '
                'sorulabildiği yerdir.\n\n'
                'Bu yılın sözüm şudur: anlamadığımı soracağım, arkadaşımı '
                'ezmeyeceğim ve ödevimi savsaklamayacağım. Öğretmenlerimiz '
                'yol gösteriyor; biz de çalışarak cevap vereceğiz.\n\n'
                'Yeni öğretim yılımız hayırlı olsun. İlköğretim Haftamız '
                'kutlu olsun. Teşekkür ederim.',
            ),
        ],
        'siirler': [
            _siir(
                'Yeni yıl (sınıf dinletisi örneği)',
                'Yaz bitti, çantalar doldu yine,\n'
                'Sıralar bizi bekledi bir yıl daha.\n'
                'Kapı açıldı, sıralar ısındı,\n'
                'Kitap, kalem, arkadaş, öğretmen.\n\n'
                'Burada sormak serbest, yanılmak da,\n'
                'Öğrenmekle büyür yurdun umudu.\n'
                'Çalışırsak yolumuz aydınlık,\n'
                'Yeni yıl, yeni söz, yeni umut.',
            ),
        ],
        'panoKartlar': [
            _kart(
                'Haftanın anlamı',
                'Öğretim yılı bu hafta açılır. Okul; dersin yanı sıra '
                'sormayı, dinlemeyi ve birlikte iş yapmayı öğretir.',
            ),
            _kart(
                'Ne zaman?',
                'Eylül ayının üçüncü haftası. Çizelgede tarihi her yıl '
                'aynı güne denk gelmez; okul takvimine bakılır.',
            ),
            _kart(
                'Sınıfta kural',
                'Sözleşme birlikte yazılır. Yanlış yapmak ayıp değildir; '
                'düzeltmemek ayıptır.',
            ),
            _kart(
                'Sınıfta ne yaparız?',
                'Sınıf sözleşmesi yazar, yılın sözünü karta geçirir, '
                'okulun yerlerini haritada gösteririz.',
            ),
        ],
    },
    'Tutum, Yatırım ve Türk Malları Haftası': {
        'panoBaslik': 'YERLİ MALI HAFTASI',
        'program': [
            'Açılış ve günün anlamı',
            'Yerli ürün tanıtımı',
            'Tutum ve israf üzerine sınıf konuşması',
            'Pano çalışması',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler; Tutum, Yatırım ve Türk Malları Haftası, '
            'yerli malı haftası olarak da bilinir. Tutumlu olmak, israf '
            'etmemek ve emeğe saygı duymak bu haftanın özüdür.\n\n'
            'Yerli ürün, birinin alın teridir. Boşa harcamak o emeği '
            'küçümsemektir. Bu hafta sınıfta ne yediğimize, ne aldığımıza '
            've neyi savurduğumuza bakacağız.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Yerli malı',
                'Değerli öğretmenlerim. Yerli malı, yurdun malıdır. '
                'Tutumlu olmak cimrilik değildir; yarını düşünmektir. '
                'Bu hafta israf etmeden paylaşmayı öğreneceğiz. Teşekkür ederim.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart('Günün anlamı', 'Tutumlu olmak, birikim yapmak ve yerli üretimi desteklemek.'),
            _kart('Yerli malı', 'Yerli ürün birinin emeğidir. İsraf, o emeği boşa harcamaktır.'),
            _kart('Tutum', 'Gerektiği kadar kullan, fazlasını sakla, ihtiyacı paylaş.'),
            _kart('Sınıfta ne yaparız?', 'Yerli ürün tanıtımı ve tutum panosu hazırlarız.'),
        ],
    },
    'Enerji Tasarrufu Haftası': {
        'panoBaslik': 'ENERJİ TASARRUFU HAFTASI',
        'program': [
            'Açılış',
            'Sınıfta enerji denetimi görevi',
            'Tasarruf afişi',
            'Kapanış değerlendirmesi',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler; enerji tasarrufu küçük bir alışkanlıkla '
            'başlar: kullanmadığın ışığı söndürmek, musluğu kapatmak, '
            'prizde unutulan şarj aletini çekmek.\n\n'
            'Bu hem aile bütçesini hem doğal kaynakları korur. Bu hafta '
            'sınıfta denetçi seçeceğiz ve tasarrufu birlikte uygulayacağız.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Tasarruf',
                'Değerli öğretmenlerim. Enerji bitmez sandığımız bir şey '
                'değildir. Işığı kapatmak küçük görünür ama her gün '
                'tekrarlanırsa büyük iş olur. Bu hafta unutmayacağız. '
                'Teşekkür ederim.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart('Günün anlamı', 'Enerjiyi bilinçli kullanmak hem bütçeyi hem doğayı korur.'),
            _kart('Küçük alışkanlık', 'Işığı söndür, musluğu kapat, fişi çek.'),
            _kart('Neden önemli?', 'Boşa giden enerji, boşa giden emektir.'),
            _kart('Sınıfta ne yaparız?', 'Enerji denetçisi seçer, tasarruf afişi asarız.'),
        ],
    },
    'Yeşilay Haftası': {
        'panoBaslik': 'YEŞİLAY HAFTASI',
        'program': [
            'Açılış',
            'Sağlıklı alışkanlıklar konuşması',
            'Afiş ve pano çalışması',
            'Kapanış',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler; Yeşilay 1920’de kuruldu. Amacı, '
            'bağımlılıkla mücadele ve sağlıklı yaşamdır. Bu hafta '
            'zararlı alışkanlıklardan uzak durmayı, sporu ve doğru '
            'beslenmeyi konuşacağız.\n\n'
            'Görevimiz birbirimizi korumaktır. Arkadaşını yanlış yola '
            'çekmek değil, doğru alışkanlıkta tutmaktır.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Sağlıklı nesil',
                'Değerli öğretmenlerim. Sağlıklı nesil, sağlıklı gelecektir. '
                'Bağımlılık insanı yalnız bırakır. Biz oyun oynayarak, '
                'kitap okuyarak ve spor yaparak güçleniriz. Teşekkür ederim.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart('Günün anlamı', 'Yeşilay Haftası sağlıklı yaşamı ve bağımlılıktan korunmayı anlatır.'),
            _kart('1920', 'Yeşilay bu yılda kuruldu. Yardımlaşma ve koruma amacıyla çalışır.'),
            _kart('Sağlıklı alışkanlık', 'Oyun, spor, kitap ve doğru beslenme güç verir.'),
            _kart('Sınıfta ne yaparız?', 'Sağlıklı ve zararlı alışkanlıkları karşılaştırmalı panoya asarız.'),
        ],
    },
    'Bilim ve Teknoloji Haftası': {
        'panoBaslik': 'BİLİM VE TEKNOLOJİ HAFTASI',
        'program': [
            'Açılış',
            'Basit deney gösterisi',
            'Türk bilim insanları sunumu',
            'Pano sergisi',
        ],
        'mudurKonusmasi':
            'Sevgili öğrenciler; “Hayatta en hakiki mürşit ilimdir.” '
            'Atatürk’ün bu sözü, sormayı ve araştırmayı hayatın kılavuzu '
            'yapar. Bilim, laboratuvarla sınırlı değildir; sınıfta bir '
            'deney, bir gözlem, bir “neden” sorusu da bilimdir.\n\n'
            'Bu hafta deneyecek, yanılacak ve tekrar deneyeceğiz. '
            'Merak etmek serbesttir.',
        'ogrenciKonusmalari': [
            _konusma(
                'Öğrenci konuşması — Merak et, sor, araştır',
                'Değerli öğretmenlerim. Bilim, ezberlemek değil sormaktır. '
                'Neden kaynar, neden uçar, neden tutuşur? Bu hafta '
                'deney yapacak, bilim insanlarını tanıyacağız. '
                'Merak etmek ayıp değildir. Teşekkür ederim.',
            ),
        ],
        'siirler': [],
        'panoKartlar': [
            _kart('Günün anlamı', 'Bilimin günlük hayattaki yerini ve araştırmayı kutlarız.'),
            _kart('Kılavuz', 'Hayatta en hakiki mürşit ilimdir.'),
            _kart('Nasıl bilim yapılır?', 'Sor, dene, gözle, kaydet, tekrar dene.'),
            _kart('Sınıfta ne yaparız?', 'Basit deney ve Türk bilim insanları kartları hazırlarız.'),
        ],
    },
}

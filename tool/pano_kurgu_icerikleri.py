# -*- coding: utf-8 -*-
"""Pano kurgularını besleyen güne özel içerik.

`build_pano_dataset.py` bu sözlüğü ana içeriğe birleştirir. Ayrı dosyada
durmasının sebebi hacim: her gün için altı ayrı alan var ve hepsi ana
dosyaya sığdırılırsa orası okunamaz hâle gelir.

## Hangi alan hangi kurguyu besler

    kronoloji      -> Tarih Şeridi
    oncesiSonrasi  -> Önce ve Sonra
    soruCevap      -> Soru-Cevap Kapakçığı
    panoDortlukler -> Şiir Duvarı
    biliyorMuydunuz-> Biliyor muydunuz?
    sozler         -> Söz Panosu
    vecize         -> Merkez Vecize
    ogrenciGorevi  -> Öğrenci Ağacı

Bir alan boşsa o kurgu öğretmene GÖSTERİLMEZ (bkz. PanoKurgular.uygunOlanlar).
Uymayan kurguyu zorlamak yerine boş bırakmak doğrudur: Orman Haftası'nın
"öncesi/sonrası" yoktur.

## Yazım kuralları

`PANO_ICERIK_KURALLARI.md` bağlayıcıdır. Özetle: şube adı geçmez, içinde
bulunulan öğretim yılı sabitlenmez, alıntı şiir kopyalanmaz (Atatürk
vecizeleri ve tarihî olgular istisna), her gün en az bir hazırlıksız
etkinlik taşır.

Dörtlüklerde mısra uzunluğuna dikkat: pano kartı ~262 punto genişliğinde;
uzun mısra ortadan kırılıp okunmaz hâle geliyor. Mısra 42 karakteri
geçmemeli (`pano_denetim.py` bunu ölçer).
"""

KURGU = {}

# =====================================================================
# MİLLÎ GÜNLER
# =====================================================================

KURGU['Ulusal Egemenlik ve Çocuk Bayramı'] = {
    'oncesiSonrasi': [
        {'baslik': 'Kararı kim verir',
         'oncesi': 'Ülkeyi tek bir kişi ve ailesi yönetirdi. Halkın kanun '
                   'yapma veya hesap sorma hakkı yoktu.',
         'sonrasi': 'Egemenlik millete geçti. Milletin seçtiği vekiller '
                    'Mecliste toplanıp kararı birlikte veriyor.'},
        {'baslik': 'Çocuğun yeri',
         'oncesi': 'Çocuk, büyüklerin kararlarını bekleyen bir izleyiciydi. '
                   'Söz hakkı yoktu.',
         'sonrasi': 'Bayramın sahibi çocuklar oldu. Sınıf başkanı seçmek, '
                    'söz almak, oy vermek okulda başlıyor.'},
        {'baslik': 'Meclisin yeri',
         'oncesi': 'Kararlar sarayda, halktan uzakta alınırdı.',
         'sonrasi': 'Meclis Ankara’da, milletin ortasında açıldı. '
                    'Yurdun her yerinden vekil geldi.'},
    ],
    'soruCevap': [
        {'soru': 'TBMM ne zaman açıldı?',
         'cevap': '23 Nisan 1920’de Ankara’da açıldı. Kurtuluş Savaşı '
                  'sürerken, yurdun dört bir yanından gelen vekillerle.'},
        {'soru': '“Egemenlik milletindir” ne demek?',
         'cevap': 'Ülkeyi yönetme yetkisinin bir kişiye değil, milletin '
                  'kendisine ait olması demektir.'},
        {'soru': '23 Nisan neden çocuk bayramı?',
         'cevap': 'Mustafa Kemal Atatürk bu günü dünya çocuklarına armağan '
                  'etti. Bağımsız bir ülkenin geleceği çocuklardadır.'},
        {'soru': 'Dünyada başka çocuk bayramı var mı?',
         'cevap': 'Çocuk günleri var, ama bir ulusal egemenlik bayramını '
                  'çocuklara armağan eden başka ülke yok.'},
        {'soru': 'Sınıfta egemenlik nasıl yaşanır?',
         'cevap': 'Söz almak, arkadaşını dinlemek, oylamak ve çıkan karara '
                  'uymak. Meclis de tam olarak bunu yapar.'},
        {'soru': 'Meclis neden Ankara’da açıldı?',
         'cevap': 'İstanbul işgal altındaydı. Ankara yurdun ortasında ve '
                  'güvenliydi; her yerden ulaşmak kolaydı.'},
    ],
    'sozler': [
        'Sınıfımızda söz alırken vereceğim söz:',
        'Arkadaşımı dinlemek için yapacağım:',
        'Bu yıl öğrenmek istediğim:',
    ],
    'sozluk': [
      {
        'kavram': 'Egemenlik',
        'tanim': 'Bir devleti yönetme yetkisinin en üstün gücü; Türkiye’de bu yetki millete aittir.',
      },
      {
        'kavram': 'Meclis',
        'tanim': 'Üyeleri millet tarafından seçilen, millet adına kanun yapan organ.',
      },
      {
        'kavram': 'Milletvekili',
        'tanim': 'Halk tarafından seçilerek Meclis’te milleti temsil eden kişi.',
      },
      {
        'kavram': 'Ulusal',
        'tanim': 'Bir millete ait olan, milletin tamamını ilgilendiren.',
      },
      {
        'kavram': 'Bayram',
        'tanim': 'Toplumca kutlanan, anlamı olan özel gün.',
      },
      {
        'kavram': 'Çocuk hakkı',
        'tanim': 'Her çocuğun doğuştan sahip olduğu, elinden alınamayan haklar.',
      },
    ],
}

KURGU['Cumhuriyet Bayramı'] = {
    'vecize': 'Benim naçiz vücudum elbet bir gün toprak olacaktır; fakat '
              'Türkiye Cumhuriyeti ilelebet payidar kalacaktır.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Cumhuriyet Bana Ne Kazandırdı',
        'yonerge': 'Cumhuriyetin sana kazandırdığı bir hakkı yaz.',
    },
    'kronoloji': [
        {'yil': '19 Mayıs 1919',
         'olay': 'Mustafa Kemal Samsun’a çıktı; Kurtuluş Savaşı başladı.'},
        {'yil': '23 Nisan 1920',
         'olay': 'TBMM Ankara’da açıldı; egemenlik millete geçti.'},
        {'yil': '30 Ağustos 1922',
         'olay': 'Büyük Taarruz zaferle sonuçlandı.'},
        {'yil': '29 Ekim 1923',
         'olay': 'Cumhuriyet ilan edildi; Atatürk ilk cumhurbaşkanı seçildi.'},
    ],
    'oncesiSonrasi': [
        {'baslik': 'Yönetim biçimi',
         'oncesi': 'Devletin başına doğuştan gelinirdi. Halkın seçme hakkı '
                   'yoktu; yönetici hesap vermezdi.',
         'sonrasi': 'Cumhuriyette yöneticiyi halk seçer, süresi dolunca '
                    'değiştirir ve hesap sorar.'},
        {'baslik': 'Eğitim',
         'oncesi': 'Okuryazar oranı düşüktü. Farklı okullar birbirinden '
                   'kopuk çalışıyordu.',
         'sonrasi': 'Eğitim tek çatı altında birleşti, yeni harflerle '
                    'okuma seferberliği başladı.'},
        {'baslik': 'Kadının hakları',
         'oncesi': 'Kadınların seçme ve seçilme hakkı yoktu; eğitim ve '
                   'meslek hayatında eşit değillerdi.',
         'sonrasi': 'Kadınlar seçme ve seçilme hakkı kazandı; Medeni Kanun '
                    'eşitliği güvenceye aldı.'},
    ],
    'soruCevap': [
        {'soru': 'Cumhuriyet ne demek?',
         'cevap': 'Yönetme yetkisinin halkta olduğu, yöneticilerin seçimle '
                  'geldiği yönetim biçimidir.'},
        {'soru': 'Cumhuriyet ne zaman ilan edildi?',
         'cevap': '29 Ekim 1923 akşamı TBMM’de kabul edildi. Aynı gün '
                  'Atatürk ilk cumhurbaşkanı seçildi.'},
        {'soru': 'Cumhuriyetle ne değişti?',
         'cevap': 'Yönetici doğuştan değil seçimle gelmeye başladı. Halk '
                  'kendi kaderini kendi belirledi.'},
        {'soru': 'Başkent neden Ankara oldu?',
         'cevap': 'Ankara yurdun ortasında, savunması kolay ve Millî '
                  'Mücadele’nin merkeziydi.'},
        {'soru': 'Cumhuriyeti korumak ne demek?',
         'cevap': 'Öğrenmek, çalışmak, oy kullanmak ve hakkını bilerek '
                  'kullanmak. Koruma sözle değil işle olur.'},
        {'soru': 'Bayrağımızdaki ay yıldız ne anlatır?',
         'cevap': 'Bağımsızlığı ve bu uğurda verilen mücadeleyi anlatır; '
                  'kırmızı zemin şehitlerimizi simgeler.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Yirmi Dokuz Ekim',
         'metin': 'Bir akşam Meclis ayağa kalktı,\n'
                  'Karar bir tek sözde toplandı.\n'
                  'Yönetim artık milletindir,\n'
                  'Cumhuriyet böyle kuruldu.'},
        {'baslik': 'Emek',
         'metin': 'Kolay gelmedi bu güzel gün,\n'
                  'Yollar uzun, kışlar soğuktu.\n'
                  'Bir nesil kendi elleriyle,\n'
                  'Yeni bir ülke kurdu.'},
        {'baslik': 'Bizim İşimiz',
         'metin': 'Kurmak zordu, korumak da zor,\n'
                  'Bize düşen öğrenmek şimdi.\n'
                  'Okuyan çocuk, çalışan el,\n'
                  'Cumhuriyetin güvencesidir.'},
        {'baslik': 'Söz',
         'metin': 'Oy vermek bir hak, bir de görev,\n'
                  'Sormak, bilmek, hesap istemek.\n'
                  'Büyüyünce sıra bizde,\n'
                  'Şimdiden öğreniyoruz.'},
    ],
    'biliyorMuydunuz': [
        'Cumhuriyet 29 Ekim 1923 akşamı TBMM’de kabul edildi.',
        'Atatürk aynı gün oy birliğiyle ilk cumhurbaşkanı seçildi.',
        'Ankara 13 Ekim 1923’te başkent oldu; Cumhuriyet’ten on altı gün '
        'önce.',
        'Türk kadını seçme ve seçilme hakkını 1934’te kazandı; birçok '
        'Avrupa ülkesinden önce.',
        'Yeni Türk harfleri 1928’de kabul edildi, okuma seferberliği '
        'başladı.',
        '“Cumhuriyet” kelimesi, halkın ortak işi anlamına gelen bir '
        'kökten gelir.',
    ],
    'sozler': [
        'Cumhuriyeti korumak için yapacağım:',
        'Bu yıl öğrenmeye söz verdiğim:',
        'Ülkeme faydalı olmak için:',
    ],
    'panoParagraflar': [
      '29 Ekim 1923’te Türkiye Büyük Millet Meclisi Cumhuriyet’i ilan etti. Aynı gün Mustafa Kemal Atatürk ilk cumhurbaşkanı seçildi. Bu tarih, yeni Türk devletinin yönetim biçiminin adının konduğu gündür.',
      'Cumhuriyet, devlet başkanının ve yöneticilerin belirli süre için seçimle belirlendiği yönetim biçimidir. Yönetme yetkisi bir aileden ya da bir kişiden değil, milletten gelir. Bu, ondan önceki yönetim biçiminden temel farktır.',
      'Cumhuriyetin ilanı tek başına bir tören değildi. Yanında eğitim, hukuk, dil ve haklar alanında pek çok değişiklik geldi. Kadınların seçme ve seçilme hakkı da bu dönemde tanındı.',
      'Cumhuriyeti korumak, onu her yıl kutlamakla olmaz. Seçime katılmak, hukuka uymak, farklı düşünene tahammül etmek ve aklı kullanmak — cumhuriyeti asıl bunlar ayakta tutar.',
    ],
    'sozluk': [
      {
        'kavram': 'Cumhuriyet',
        'tanim': 'Devlet başkanının ve yöneticilerin belirli süre için seçimle belirlendiği yönetim biçimi.',
      },
      {
        'kavram': 'Cumhurbaşkanı',
        'tanim': 'Cumhuriyetle yönetilen bir devletin başkanı.',
      },
      {
        'kavram': 'Anayasa',
        'tanim': 'Devletin temel kurallarını belirleyen en üstün kanun.',
      },
      {
        'kavram': 'Seçme ve seçilme hakkı',
        'tanim': 'Vatandaşın oy verme ve aday olma hakkı.',
      },
      {
        'kavram': 'Laiklik',
        'tanim': 'Devlet işlerinin din kurallarına göre değil, hukuka göre yürütülmesi ilkesi.',
      },
      {
        'kavram': 'İnkılap',
        'tanim': 'Toplum düzeninde yapılan köklü değişiklik.',
      },
    ],
}

KURGU['Zafer Bayramı'] = {
    'vecize': 'Ordular! İlk hedefiniz Akdeniz’dir, ileri!',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Zaferin Bana Anlattığı',
        'yonerge': 'Zafer sence neyle kazanılır? Bir cümleyle yaz.',
    },
    'kronoloji': [
        {'yil': '26 Ağustos 1922',
         'olay': 'Büyük Taarruz başladı; Afyon cephesinde saldırıya geçildi.'},
        {'yil': '30 Ağustos 1922',
         'olay': 'Başkomutanlık Meydan Muharebesi kazanıldı.'},
        {'yil': '9 Eylül 1922',
         'olay': 'İzmir’e girildi; işgal sona erdi.'},
        {'yil': '11 Ekim 1922',
         'olay': 'Mudanya Ateşkesi imzalandı; savaş resmen bitti.'},
    ],
    'soruCevap': [
        {'soru': '30 Ağustos neyi anlatır?',
         'cevap': 'Başkomutanlık Meydan Muharebesi’nin kazanıldığı günü. '
                  'Kurtuluş Savaşı’nın dönüm noktasıdır.'},
        {'soru': 'Büyük Taarruz ne kadar sürdü?',
         'cevap': '26 Ağustos’ta başladı, 30 Ağustos’ta kesin sonuca ulaştı. '
                  'Beş gün içinde cephe değişti.'},
        {'soru': 'Zafer yalnızca askerlerin mi?',
         'cevap': 'Hayır. Cepheye mermi taşıyan kadınlar, üretim yapan '
                  'köylüler ve destek veren herkes pay sahibidir.'},
        {'soru': 'Hazırlık neden önemliydi?',
         'cevap': 'Taarruz aylarca gizlice hazırlandı. Plan, tedarik ve '
                  'eğitim tamamlanmadan saldırı yapılmadı.'},
        {'soru': 'Bugün zafer nasıl kazanılır?',
         'cevap': 'Çalışarak ve öğrenerek. Hazırlık yapan, sabreden ve '
                  'birlikte hareket eden kazanır.'},
        {'soru': '9 Eylül neyi anlatır?',
         'cevap': 'İzmir’in kurtuluşunu. Düşman İzmir’den çekildi, '
                  'işgal sona erdi.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Otuz Ağustos',
         'metin': 'Sabah oldu Afyon’da,\n'
                  'Bir millet ayaktaydı.\n'
                  'Yorgun ama kararlı,\n'
                  'Yolun sonu yakındı.'},
        {'baslik': 'Hazırlık',
         'metin': 'Zafer bir günde gelmedi,\n'
                  'Aylarca sessiz çalışıldı.\n'
                  'Plan, sabır ve emek,\n'
                  'Önce onlar kazanıldı.'},
        {'baslik': 'Herkesin Payı',
         'metin': 'Cepheye mermi taşıyan,\n'
                  'Tarlada ekmek yetiştiren.\n'
                  'Zafer yalnız askerin değil,\n'
                  'Bütün bir milletindir.'},
        {'baslik': 'Bugün',
         'metin': 'Bizim cephemiz sıralar,\n'
                  'Silahımız kalem, kitap.\n'
                  'Çalışan her çocuk bugün,\n'
                  'Yeni bir zafer kazanır.'},
    ],
    'biliyorMuydunuz': [
        'Büyük Taarruz 26 Ağustos 1922 sabahı başladı.',
        '30 Ağustos, Başkomutanlık Meydan Muharebesi’nin kazanıldığı gündür.',
        'Atatürk savaşı bizzat cephede yönetti; bu yüzden '
        '“Başkomutanlık Muharebesi” denir.',
        'Taarruz aylarca gizli hazırlandı; birlikler geceleri yer değiştirdi.',
        'İzmir’e 9 Eylül 1922’de girildi, işgal sona erdi.',
        'Mudanya Ateşkesi 11 Ekim 1922’de imzalandı ve savaş resmen bitti.',
    ],
    'sozler': [
        'Zorlukla karşılaşınca yapacağım:',
        'Bu yıl sonuna kadar götüreceğim iş:',
        'Arkadaşımla birlikte başaracağım:',
    ],
    'panoParagraflar': [
      '26 Ağustos 1922 sabahı Büyük Taarruz başladı. 30 Ağustos günü Başkomutanlık Meydan Muharebesi zaferle sonuçlandı ve düşman ordusu bozguna uğratıldı. Bu tarih, Kurtuluş Savaşı’nın dönüm noktasıdır.',
      'Zafer yalnızca cephede kazanılmadı. Cephane taşıyan kağnılarıyla Anadolu kadınları, malzemesini paylaşan köylüler, geri hizmette çalışan herkes bu sonucun parçasıdır. Bir savaşı orduların kazandığı söylenir; aslında bir milletin tamamı kazanır.',
      '30 Ağustos, 1924’ten bu yana Zafer Bayramı olarak kutlanıyor. Aynı zamanda Türk Silahlı Kuvvetleri Günü’dür. Okullarda anma programı yapılır, şehitler saygıyla anılır.',
      'Bu bayramın anlattığı şey yalnızca bir savaşın kazanılması değildir. Zor koşullarda bile vazgeçmemenin, birlikte hareket etmenin ve bir hedefe kilitlenmenin ne yapabildiğini gösterir.',
    ],
    'sozluk': [
      {
        'kavram': 'Büyük Taarruz',
        'tanim': '26 Ağustos 1922’de başlayan, Kurtuluş Savaşı’nı sonuca götüren büyük saldırı harekâtı.',
      },
      {
        'kavram': 'Başkomutan',
        'tanim': 'Bir ülkenin bütün silahlı kuvvetlerini yöneten en yetkili komutan.',
      },
      {
        'kavram': 'Meydan muharebesi',
        'tanim': 'Orduların açık alanda karşı karşıya geldiği büyük çarpışma.',
      },
      {
        'kavram': 'Kurtuluş Savaşı',
        'tanim': 'Türk milletinin bağımsızlığı için 1919-1922 arasında verdiği mücadele.',
      },
      {
        'kavram': 'Bağımsızlık',
        'tanim': 'Bir milletin kendi kaderini başka bir gücün etkisi olmadan belirlemesi.',
      },
      {
        'kavram': 'Cephe',
        'tanim': 'Savaşta orduların karşı karşıya geldiği bölge.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Taarruzdan önce ve sonra',
        'oncesi': 'Anadolu’nun büyük bölümü işgal altındaydı.',
        'sonrasi': '30 Ağustos zaferiyle işgal kırıldı ve bağımsızlık yolu açıldı.',
      },
      {
        'baslik': 'Zaferi kim kazandı?',
        'oncesi': 'Bir savaşı yalnızca orduların kazandığı sanılır.',
        'sonrasi': 'Cephe gerisinde çalışan herkesle birlikte bir milletin tamamı kazandı.',
      },
      {
        'baslik': 'Bugüne kalan',
        'oncesi': 'Zafer uzak bir tarih olarak görülebilir.',
        'sonrasi': 'Vazgeçmemenin ve birlikte hareket etmenin ne yaptığını bugün de anlatır.',
      },
    ],
}


# =====================================================================
# ANMA GÜNLERİ
# =====================================================================

KURGU['Atatürk Haftası'] = {
    'vecize': 'Hayatta en hakiki mürşit ilimdir.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Atatürk’ün Bana Bıraktığı',
        'yonerge': 'Atatürk’ün sözlerinden birini seç, neden seçtiğini yaz.',
    },
    'kronoloji': [
        {'yil': '1881', 'olay': 'Selanik’te doğdu.'},
        {'yil': '1919', 'olay': 'Samsun’a çıktı; Millî Mücadele başladı.'},
        {'yil': '1923',
         'olay': 'Cumhuriyet ilan edildi, ilk cumhurbaşkanı oldu.'},
        {'yil': '1928', 'olay': 'Yeni Türk harfleri kabul edildi.'},
        {'yil': '10 Kasım 1938',
         'olay': 'Dolmabahçe Sarayı’nda vefat etti.'},
    ],
    'soruCevap': [
        {'soru': '10 Kasım’da saat kaçta saygı duruşu yapılır?',
         'cevap': '09.05’te. Atatürk’ün vefat ettiği saattir; ülke çapında '
                  'sirenlerle anılır.'},
        {'soru': 'Atatürk’e neden Başöğretmen denir?',
         'cevap': 'Yeni harfleri kara tahta başında halka kendisi öğretti. '
                  'Bu unvan 1928’de verildi.'},
        {'soru': '“En hakiki mürşit ilimdir” ne demek?',
         'cevap': 'En doğru yol gösterici bilimdir demek. Kararların '
                  'bilgiye dayanması gerektiğini anlatır.'},
        {'soru': 'Atatürk kaç yaşında vefat etti?',
         'cevap': 'Elli yedi yaşındaydı. 1881’de doğdu, 1938’de vefat etti.'},
        {'soru': 'Atatürk’ü anmak ne demek?',
         'cevap': 'Yalnız üzülmek değil; öğrenmek, çalışmak ve bıraktığı '
                  'işleri sürdürmek demek.'},
        {'soru': 'Neden 10-16 Kasım haftası?',
         'cevap': 'Vefat günü olan 10 Kasım’la başlar. Hafta boyunca '
                  'hayatı ve eserleri incelenir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'On Kasım',
         'metin': 'Saat dokuzu beş geçe,\nBir ülke sessiz kaldı.\n'
                  'Ama bıraktığı işler,\nHâlâ ayakta duruyor.'},
        {'baslik': 'Başöğretmen',
         'metin': 'Kara tahtanın başına geçti,\nHarfleri kendi öğretti.\n'
                  'Önce okumayı sevdirdi,\nSonra bir ülke kurdu.'},
        {'baslik': 'Bilim',
         'metin': 'En doğru yol gösterici,\nBilim dedi, başka değil.\n'
                  'Sorduk, araştırdık, öğrendik,\nYolumuz hâlâ o yol.'},
        {'baslik': 'Anmak',
         'metin': 'Anmak yalnız üzülmek değil,\nÇalışmaktır asıl saygı.\n'
                  'Her öğrenen çocuk bugün,\nO işi sürdürüyor.'},
    ],
    'biliyorMuydunuz': [
        'Atatürk 1881’de Selanik’te doğdu.',
        '10 Kasım 1938’de Dolmabahçe Sarayı’nda vefat etti; saat 09.05’ti.',
        '“Başöğretmen” unvanı 1928’de, yeni harfleri halka öğretmesi '
        'üzerine verildi.',
        'Okuduğu kitapların çoğunun kenarına not almıştır.',
        '“Yurtta sulh, cihanda sulh” dış politikanın temel ilkesi oldu.',
        'Anıtkabir 1953’te tamamlandı; naaşı o yıl buraya nakledildi.',
    ],
    'sozler': [
        'Bu hafta okuyacağım kitap:',
        'Öğrenmek istediğim yeni şey:',
        'Atatürk’ün sözlerinden uygulayacağım:',
    ],
    'panoParagraflar': [
      'Mustafa Kemal Atatürk 10 Kasım 1938 sabahı saat dokuzu beş geçe Dolmabahçe Sarayı’nda hayatını kaybetti. O günden bu yana her yıl aynı saatte, ülkenin her yerinde saygı duruşunda bulunuluyor.',
      'Atatürk Haftası yalnızca bir yas haftası değildir. Atatürk’ün kurduğu Cumhuriyeti, yaptığı devrimleri ve gösterdiği çağdaş hedefi anlamak için ayrılmış bir haftadır. Anmak, üzülmekten ibaret olsaydı bir hafta sürmezdi.',
      'Atatürk’ün en çok üzerinde durduğu şeylerden biri eğitimdi. Yeni harflerin öğretilmesinde kendisi tahta başına geçti; öğretmenliği bir unvan olarak taşıdı. “Hayatta en hakiki mürşit ilimdir” sözü de bu bakışın özetidir.',
      'Onu anmanın en anlamlı yolu, gösterdiği yönde yürümektir: okumak, araştırmak, aklı kullanmak ve ülkesine faydalı olmak. Bu, çelenk koymaktan daha zor ama daha kalıcı bir saygıdır.',
    ],
    'sozluk': [
      {
        'kavram': 'Anıtkabir',
        'tanim': 'Atatürk’ün Ankara’daki anıt mezarı.',
      },
      {
        'kavram': 'Devrim',
        'tanim': 'Toplum düzeninde köklü ve hızlı değişiklik.',
      },
      {
        'kavram': 'Çağdaşlık',
        'tanim': 'Bilime ve akla dayalı, zamanın gereklerine uygun yaşayış.',
      },
      {
        'kavram': 'Mürşit',
        'tanim': 'Yol gösteren, doğruyu öğreten kişi veya şey.',
      },
      {
        'kavram': 'Ulu Önder',
        'tanim': 'Atatürk için kullanılan, büyük yol gösterici anlamındaki unvan.',
      },
      {
        'kavram': 'Saygı duruşu',
        'tanim': 'Anma töreninde sessizce ayakta durularak gösterilen saygı.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Anmanın anlamı',
        'oncesi': 'Anma yalnızca üzülmek sanılır.',
        'sonrasi': 'Anmak, gösterilen yönde yürümeyi sürdürmektir.',
      },
      {
        'baslik': 'Harflerin değişimi',
        'oncesi': 'Eski harflerle okuma yazma öğrenmek uzun sürüyordu.',
        'sonrasi': 'Yeni harflerle okuryazarlık hızla yaygınlaştı.',
      },
      {
        'baslik': 'Akla verilen yer',
        'oncesi': 'Kararlar çoğu zaman alışkanlıkla verilirdi.',
        'sonrasi': '“En hakiki mürşit ilimdir” ilkesiyle bilim öne alındı.',
      },
    ],
}

KURGU["Atatürk'ü Anma ve Gençlik ve Spor Bayramı"] = {
    'vecize': 'Ey Türk gençliği! Birinci vazifen, Türk istiklâlini, Türk '
              'Cumhuriyeti’ni ilelebet muhafaza ve müdafaa etmektir.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Gençliğe Düşen',
        'yonerge': 'Sence gençliğin en önemli görevi nedir? Yaz.',
    },
    'kronoloji': [
        {'yil': '16 Mayıs 1919',
         'olay': 'Bandırma Vapuru İstanbul’dan hareket etti.'},
        {'yil': '19 Mayıs 1919',
         'olay': 'Mustafa Kemal Samsun’a çıktı; Millî Mücadele başladı.'},
        {'yil': '1919 yazı',
         'olay': 'Amasya, Erzurum ve Sivas’ta kongreler toplandı.'},
        {'yil': '1938',
         'olay': 'Atatürk bu günü Türk gençliğine armağan etti.'},
    ],
    'soruCevap': [
        {'soru': '19 Mayıs neden önemli?',
         'cevap': 'Mustafa Kemal’in Samsun’a çıkıp Millî Mücadele’yi '
                  'başlattığı gündür.'},
        {'soru': 'Samsun’a neyle gitti?',
         'cevap': 'Bandırma Vapuru ile. 16 Mayıs’ta İstanbul’dan hareket '
                  'etti, 19 Mayıs sabahı Samsun’a vardı.'},
        {'soru': 'Bu gün neden gençliğe armağan?',
         'cevap': 'Atatürk geleceği gençlerin kuracağına inanıyordu. '
                  'Bağımsızlığı korumak onların görevi.'},
        {'soru': 'Spor neden bu bayramda?',
         'cevap': 'Sağlıklı beden ve disiplin gençliğin gücüdür. Spor '
                  'birlikte çalışmayı da öğretir.'},
        {'soru': 'Gençliğe Hitabe kime yazıldı?',
         'cevap': 'Gelecek nesillere. Atatürk 1927’de Nutuk’un sonunda '
                  'okudu; hâlâ okullarda okunur.'},
        {'soru': 'Bugün gençlik ne yapmalı?',
         'cevap': 'Öğrenmeli, üretmeli, sorgulamalı. Bağımsızlık bilgiyle '
                  've emekle korunur.'},
    ],
    'panoDortlukler': [
        {'baslik': 'On Dokuz Mayıs',
         'metin': 'Bir vapur, bir sabah, bir liman,\n'
                  'Samsun’da başladı her şey.\n'
                  'Umutsuz görünen bir yolda,\n'
                  'İlk adım atıldı o gün.'},
        {'baslik': 'Gençlik',
         'metin': 'Bize armağan edilen gün,\n'
                  'Aslında bir görev demek.\n'
                  'Koşmak, öğrenmek, üretmek,\n'
                  'Hepsi bu sözde saklı.'},
        {'baslik': 'Spor',
         'metin': 'Sağlam kafa sağlam bedende,\n'
                  'Koş, oyna, güçlen, dinlen.\n'
                  'Takımda öğrendiğin şey,\n'
                  'Hayatta da işine yarar.'},
        {'baslik': 'Yarın',
         'metin': 'Yarını kuracak eller,\n'
                  'Bugün sırada oturuyor.\n'
                  'Her öğrenilen yeni şey,\n'
                  'Yarını biraz yaklaştırır.'},
    ],
    'biliyorMuydunuz': [
        'Mustafa Kemal 19 Mayıs 1919 sabahı Samsun’a çıktı.',
        'Bandırma Vapuru İstanbul’dan 16 Mayıs’ta hareket etmişti.',
        'Atatürk doğum gününü bilmediği için 19 Mayıs’ı doğum günü olarak '
        'kabul etmiştir.',
        'Bu bayram 1938’de Türk gençliğine armağan edildi.',
        'Gençliğe Hitabe, Nutuk’un son bölümüdür; 1927’de okundu.',
        'Samsun’dan sonra Amasya, Erzurum ve Sivas kongreleri toplandı.',
    ],
    'sozler': [
        'Bu yıl deneyeceğim yeni spor:',
        'Sağlıklı yaşamak için yapacağım:',
        'Ülkeme faydalı olmak için öğreneceğim:',
    ],
    'panoParagraflar': [
      '19 Mayıs 1919’da Mustafa Kemal Samsun’a çıktı. Bu tarih Kurtuluş Savaşı’nın başlangıcı sayılır. Atatürk bu günü kendi doğum günü olarak kabul etmiş ve Türk gençliğine armağan etmiştir.',
      'Bayramın gençliğe armağan edilmesi rastlantı değildir. Atatürk, kurduğu Cumhuriyetin geleceğini gençlere emanet etmişti. Gençliğe Hitabe’de “Ey Türk gençliği! Birinci vazifen…” diye başlayan sözler bu emanetin ifadesidir.',
      'Bu gün aynı zamanda Spor Bayramı’dır. Spor yalnızca beden sağlığı değildir; kurala uymayı, takım hâlinde çalışmayı, kaybetmeyi ve kazanmayı öğretir. Sahada öğrenilen bu şeyler hayatın her alanında işe yarar.',
      'Gençlik yalnızca bir yaş aralığı da değildir. Merak eden, öğrenmekten vazgeçmeyen ve daha iyisini isteyen herkes bu ruhu taşır. Bayramın anlattığı şey budur.',
    ],
    'sozluk': [
      {
        'kavram': 'Gençliğe Hitabe',
        'tanim': 'Atatürk’ün Nutuk’un sonunda Türk gençliğine seslendiği metin.',
      },
      {
        'kavram': 'Emanet',
        'tanim': 'Korunmak ve sonraki kuşağa aktarılmak üzere bırakılan şey.',
      },
      {
        'kavram': 'Millî Mücadele',
        'tanim': 'Kurtuluş Savaşı yıllarında verilen bağımsızlık mücadelesi.',
      },
      {
        'kavram': 'Spor',
        'tanim': 'Kurallara bağlı, bedeni ve zihni geliştiren etkinlik.',
      },
      {
        'kavram': 'Takım ruhu',
        'tanim': 'Ortak hedef için birlikte, uyum içinde çalışma anlayışı.',
      },
      {
        'kavram': 'Fair play',
        'tanim': 'Sporda dürüstlük ve rakibe saygı ilkesi.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': '19 Mayıs 1919',
        'oncesi': 'Ülke işgal altındaydı ve dağınık bir direniş vardı.',
        'sonrasi': 'Samsun’a çıkışla örgütlü bir millî mücadele başladı.',
      },
      {
        'baslik': 'Sporun öğrettiği',
        'oncesi': 'Spor yalnızca beden gücü sanılır.',
        'sonrasi': 'Kurala uymayı, takım olmayı ve kaybetmeyi de öğretir.',
      },
      {
        'baslik': 'Gençlik nedir?',
        'oncesi': 'Gençlik yalnızca bir yaş aralığı sayılır.',
        'sonrasi': 'Merak eden ve öğrenmekten vazgeçmeyen herkes bu ruhu taşır.',
      },
    ],
}

KURGU['Şehitler Günü'] = {
    'vecize': 'Vatan için ölmek de var; fakat borç, yaşamaktır.',
    'vecizeKaynak': 'Namık Kemal',
    'ogrenciGorevi': {
        'baslik': 'Şehitlerimize Mektubum',
        'yonerge': 'Şehitlerimize bir teşekkür cümlesi yaz.',
    },
    'kronoloji': [
        {'yil': '18 Mart 1915',
         'olay': 'Çanakkale Deniz Zaferi kazanıldı.'},
        {'yil': '1915-1916',
         'olay': 'Çanakkale kara savaşları sürdü; büyük kayıplar verildi.'},
        {'yil': 'Bugün',
         'olay': '18 Mart, Şehitleri Anma Günü olarak anılır.'},
    ],
    'soruCevap': [
        {'soru': '18 Mart neyi anlatır?',
         'cevap': 'Çanakkale Deniz Zaferi’ni ve tüm şehitlerimizi anma '
                  'gününü.'},
        {'soru': 'Şehit ne demek?',
         'cevap': 'Vatanı korurken hayatını kaybeden kişi. Anısı saygıyla '
                  'yaşatılır.'},
        {'soru': 'Çanakkale neden önemli?',
         'cevap': 'Geçilmez denilen boğaz savunuldu. Bu direniş Millî '
                  'Mücadele’ye örnek oldu.'},
        {'soru': 'Anmak nasıl olur?',
         'cevap': 'Saygı duruşuyla, susarak ve hatırlayarak. Sonra da '
                  'onların bıraktığı ülkeye iyi bakarak.'},
        {'soru': 'Bugün bize düşen ne?',
         'cevap': 'Barış içinde yaşamak, öğrenmek ve birbirimizi korumak. '
                  'En iyi teşekkür budur.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Sessizlik',
         'metin': 'Bir dakika susarız,\nAma söz çok şey söyler.\n'
                  'O sessizlikte duyulan,\nBir teşekkürdür aslında.'},
        {'baslik': 'Toprak',
         'metin': 'Bu toprak kolay gelmedi,\nHer karışında bir emek.\n'
                  'Üstünde koşan çocuklar,\nOnların bıraktığı miras.'},
        {'baslik': 'Hatırlamak',
         'metin': 'Unutmamak bir görevdir,\nAnmak bir borç ödemek.\n'
                  'Adını bilmediğimiz nice,\nİnsana borçluyuz bugün.'},
        {'baslik': 'Barış',
         'metin': 'En güzel teşekkür şudur:\nBarış içinde yaşamak.\n'
                  'Kavga etmeden büyümek,\nBirbirimize iyi bakmak.'},
    ],
    'biliyorMuydunuz': [
        'Çanakkale Deniz Zaferi 18 Mart 1915’te kazanıldı.',
        '18 Mart, Şehitleri Anma Günü olarak anılır.',
        'Çanakkale’de birçok üniversite öğrencisi cepheye gitti.',
        'Zafer, düşman donanmasının boğazı geçememesiyle kazanıldı.',
        'Anma törenlerinde saygı duruşu ve İstiklâl Marşı yer alır.',
        'Çanakkale direnişi Millî Mücadele’ye örnek oldu.',
    ],
    'sozler': [
        'Barış için yapacağım:',
        'Arkadaşımla anlaşmazlıkta yapacağım:',
        'Ülkeme iyi bakmak için:',
    ],
    'panoParagraflar': [
      '18 Mart 1915’te Çanakkale Boğazı’nda düşman donanması ağır bir yenilgiye uğratıldı. Bu tarih hem Çanakkale Deniz Zaferi’nin yıl dönümü hem de Şehitleri Anma Günü olarak anılır.',
      'Çanakkale’de çok genç yaşta pek çok insan hayatını kaybetti. Aralarında okulunu yarıda bırakıp cepheye gidenler vardı. Bu yüzden Çanakkale, yalnızca bir zafer değil, aynı zamanda büyük bir kayıp olarak anılır.',
      'Şehit, vatanını savunurken hayatını kaybeden kişidir. Anma günleri bu insanları hatırlamak için vardır. Ama anmak, düşmanlık beslemek değildir; acıyı hatırlayıp barışın değerini bilmektir.',
      'Atatürk’ün Çanakkale’de hayatını kaybeden yabancı askerlerin aileleri için söylediği “Bu topraklarda canlarını veren evlatlarınız artık bizim evlatlarımızdır” sözü, bu bakışın en bilinen örneğidir.',
    ],
    'sozluk': [
      {
        'kavram': 'Şehit',
        'tanim': 'Vatanını savunurken hayatını kaybeden kişi.',
      },
      {
        'kavram': 'Gazi',
        'tanim': 'Vatanı savunurken yaralanan ve hayatta kalan kişi.',
      },
      {
        'kavram': 'Çanakkale Zaferi',
        'tanim': '18 Mart 1915’te Çanakkale Boğazı’nda kazanılan deniz zaferi.',
      },
      {
        'kavram': 'Boğaz',
        'tanim': 'İki denizi birbirine bağlayan dar su geçidi.',
      },
      {
        'kavram': 'Cephe',
        'tanim': 'Savaşta orduların karşı karşıya geldiği bölge.',
      },
      {
        'kavram': 'Anma',
        'tanim': 'Geçmişte yaşananları ve kaybedilenleri saygıyla hatırlama.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Zafer ve kayıp',
        'oncesi': 'Çanakkale yalnızca bir zafer olarak anlatılabilir.',
        'sonrasi': 'Aynı zamanda çok genç insanların kaybedildiği bir acıdır.',
      },
      {
        'baslik': 'Anmanın anlamı',
        'oncesi': 'Anmak düşmanlık beslemek sanılabilir.',
        'sonrasi': 'Acıyı hatırlayıp barışın değerini bilmektir.',
      },
      {
        'baslik': 'Savaştan sonra',
        'oncesi': 'Cephede karşı karşıya gelenler düşmandı.',
        'sonrasi': 'Yıllar sonra aynı topraklarda yatanlar birlikte anıldı.',
      },
    ],
}

KURGU['15 Temmuz Demokrasi ve Millî Birlik Günü'] = {
    'vecize': 'Egemenlik kayıtsız şartsız milletindir.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Demokrasi Bana Ne Anlatıyor',
        'yonerge': 'Demokrasi sence ne demek? Bir cümleyle yaz.',
    },
    # Pano 2. sayfa paragrafları — günün anlamını düz metin olarak
    # anlatır. Kısa kartlara sığmayan bağlam buraya girer.
    'panoParagraflar': [
        '15 Temmuz 2016 gecesi, Türkiye’de milletin seçtiği yönetime '
        'karşı silahlı bir darbe girişimi yaşandı. Darbe; bir ülkede '
        'yönetimi zorla, silah kullanarak ele geçirmeye çalışmaktır. '
        'Oysa demokratik bir düzende yönetimi kimin yürüteceğine millet '
        'karar verir ve bu kararını seçimle ortaya koyar.',
        'O gece milletimiz bu girişime karşı durdu. Meydanlara çıkanlar '
        'tek bir görüşün insanları değildi; farklı partilere oy vermiş, '
        'farklı düşünen insanlar aynı yerde buluştu. Emniyet mensupları, '
        'askerler ve siviller birlikte hareket etti. Girişim sonuçsuz '
        'kaldı. O gece 251 vatandaşımız hayatını kaybetti, iki binden '
        'fazla vatandaşımız gazi oldu.',
        'Bu günün okullarda anılmasının amacı korku aşılamak değildir. '
        'Amaç; millî iradenin, hukukun ve birlikte yaşama kültürünün '
        'değerini anlamaktır. Demokrasi yalnızca olağanüstü günlerde '
        'savunulan bir şey değildir; her gün, en küçük yerde yeniden '
        'kurulur. Sınıfta söz sırası beklemek, azınlıkta kalınca sonuca '
        'uymak ve farklı düşünene zarar vermemek de demokrasidir.',
        'Anmak, yalnızca bir tarihi tekrarlamak değildir. Anmak; o gün '
        'uğrunda durulan değeri bugün yaşatmaktır. Bizim için bu; '
        'öğrenmek, doğruyu araştırmak, duyduğumuz her bilgiye hemen '
        'inanmamak ve birbirimizi korumaktır.',
    ],
    # Sözlük — kavramlar netleşmeden günün anlamı kurulmuyor. Soru-cevap
    # kurgusundan ayrı tutuldu: burada tanım var, orada muhakeme.
    'sozluk': [
        {'kavram': 'Demokrasi',
         'tanim': 'Yönetme yetkisinin millete ait olduğu, kararların '
                  'milletin seçtiği temsilciler eliyle alındığı düzen.'},
        {'kavram': 'Millî irade',
         'tanim': 'Milletin ortak kararı. Seçimlerde, sandıkta ortaya '
                  'çıkar.'},
        {'kavram': 'Cumhuriyet',
         'tanim': 'Devlet başkanının ve yöneticilerin belirli süre için '
                  'seçimle belirlendiği yönetim biçimi.'},
        {'kavram': 'Meclis',
         'tanim': 'Üyeleri millet tarafından seçilen, millet adına kanun '
                  'yapan organ.'},
        {'kavram': 'Darbe',
         'tanim': 'Milletin seçtiği yönetimi silah ve güç kullanarak '
                  'devirmeye çalışma girişimi.'},
        {'kavram': 'Anayasal düzen',
         'tanim': 'Devletin temel kurallarının anayasada yazılı olduğu ve '
                  'herkesin bu kurallara uyduğu düzen.'},
        {'kavram': 'Gazi',
         'tanim': 'Vatanı savunurken yaralanan ve hayatta kalan kişi.'},
        {'kavram': 'Şehit',
         'tanim': 'Vatanı savunurken hayatını kaybeden kişi.'},
    ],
    'kronoloji': [
        {'yil': '1946',
         'olay': 'Türkiye’de ilk çok partili seçim yapıldı.'},
        {'yil': '15 Temmuz 2016',
         'olay': 'Darbe girişimi başladı; halk sokağa çıktı.'},
        {'yil': '16 Temmuz 2016',
         'olay': 'Girişim başarısız oldu; millî irade korundu.'},
        {'yil': '2016',
         'olay': '15 Temmuz, resmî anma günü olarak kabul edildi.'},
        {'yil': 'Bugün',
         'olay': '15 Temmuz, Demokrasi ve Millî Birlik Günü olarak anılır.'},
    ],
    # Önce/sonra — bu gün bir değişimi anlatır, kurgu burada anlamlı.
    'oncesiSonrasi': [
        {'baslik': 'Kararı kim verir?',
         'oncesi': 'Darbe girişiminde bulunanlar, kararı silah gücünün '
                   'vereceğini düşündü.',
         'sonrasi': 'Kararın millete ait olduğu, milletin kendi iradesine '
                    'sahip çıkmasıyla yeniden görüldü.'},
        {'baslik': 'Ayrılık ve birlik',
         'oncesi': 'Farklı görüşteki insanların ortak bir noktada '
                   'buluşamayacağı sanılıyordu.',
         'sonrasi': 'Farklı partilere oy vermiş insanlar aynı meydanda, '
                    'aynı değer için durdu.'},
        {'baslik': 'Bilgi ve doğruluk',
         'oncesi': 'O gece yayılan yanlış bilgiler insanları '
                   'yönlendirmeye çalıştı.',
         'sonrasi': 'Doğru kaynağa ulaşmanın ve bilgiyi sorgulamanın ne '
                    'kadar önemli olduğu anlaşıldı.'},
    ],
    'soruCevap': [
        {'soru': 'Demokrasi ne demek?',
         'cevap': 'Halkın kendi kendini yönetmesi. Kararı seçilmiş '
                  'temsilciler, halk adına verir.'},
        {'soru': 'Millî irade nedir?',
         'cevap': 'Milletin ortak kararı. Sandıkta oy vererek ortaya çıkar '
                  've ona kimse müdahale edemez.'},
        {'soru': '15 Temmuz neden anılıyor?',
         'cevap': 'Millî iradeye yönelik bir girişimin halkın kararlılığıyla '
                  'sonuçsuz kaldığı gündür.'},
        {'soru': 'Birlik neden önemli?',
         'cevap': 'Farklı düşünen insanlar ortak değerlerde birleşebilir. '
                  'Birlik, farklılığı yok saymak değildir.'},
        {'soru': 'Çocuklar demokrasiyi nasıl öğrenir?',
         'cevap': 'Sınıfta oy vererek, söz sırasını bekleyerek ve azınlıkta '
                  'kalınca da karara uyarak.'},
        {'soru': 'Darbe ile seçim arasındaki fark nedir?',
         'cevap': 'Seçimde karar sayılarak, herkesin oyuyla verilir. '
                  'Darbede karar zorla, silahla dayatılır.'},
        {'soru': 'Neden 15 Temmuz’da değil de eylülde anıyoruz?',
         'cevap': '15 Temmuz yaz tatiline denk gelir. Bu yüzden okullarda '
                  'anma, ders yılının ikinci haftasında yapılır.',},
        {'soru': 'Bir haberin doğru olduğunu nasıl anlarız?',
         'cevap': 'Kaynağına bakarız, başka güvenilir kaynaklarla '
                  'karşılaştırırız ve hemen paylaşmadan önce dururuz.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Söz Milletin',
         'metin': 'Karar sandıkta verilir,\nSöz milletin sözüdür.\n'
                  'Kimse onun yerine geçip,\nBaşka söz söyleyemez.'},
        {'baslik': 'Birlik',
         'metin': 'Ayrı düşünmek serbesttir,\nAma ortak bir çatı var.\n'
                  'O çatının altında,\nHepimize yer bulunur.'},
        {'baslik': 'Sandık',
         'metin': 'Küçük bir kutu ama,\nİçinde koca bir güç.\n'
                  'Herkesin bir oyu var,\nHiçbiri ötekinden büyük değil.'},
        {'baslik': 'Öğrenmek',
         'metin': 'Sınıfta başlar demokrasi,\nSöz sırası beklemekle.\n'
                  'Kaybedince kabullenmek,\nEn zor ama en gerekli.'},
        {'baslik': 'Dinlemek',
         'metin': 'Konuşmak kolay iştir,\nAsıl hüner dinlemek.\n'
                  'Anlamadan karşı çıkmak,\nHiç kimseye yakışmaz.'},
        {'baslik': 'Doğru Bilgi',
         'metin': 'Her duyduğuna inanma,\nÖnce sor: kim söylemiş?\n'
                  'Yanlış bilgi hızlı koşar,\nDoğru ise sabreder.'},
        {'baslik': 'Emanet',
         'metin': 'Bize kalan bir vatan,\nBir de sorumluluk var.\n'
                  'Büyüyünce anlarız,\nEmanet ne demekmiş.'},
    ],
    'biliyorMuydunuz': [
        '15 Temmuz, Demokrasi ve Millî Birlik Günü olarak anılır.',
        'Demokrasi kelimesi Yunanca “halk” ve “yönetim” sözcüklerinden '
        'gelir.',
        'Türkiye’de ilk çok partili seçim 1946’da yapıldı.',
        'Oy kullanma yaşı Türkiye’de on sekizdir.',
        'Millî iradenin temeli “Egemenlik kayıtsız şartsız milletindir” '
        'ilkesidir.',
        'Sınıf başkanı seçimi de bir demokrasi uygulamasıdır.',
        'Türkiye Büyük Millet Meclisi 23 Nisan 1920’de açıldı.',
        'Oy vermek hem bir hak hem de bir sorumluluktur.',
        'Bir ülkede farklı görüşlerin bulunması demokrasinin '
        'zayıflığı değil, doğal hâlidir.',
    ],
    'sozler': [
        'Sınıf kararına uymak için:',
        'Farklı düşünen arkadaşıma karşı:',
        'Söz sırası beklerken:',
        'Bir haberi paylaşmadan önce:',
        'Oylamayı kaybedince:',
        'Bana benzemeyen biriyle çalışırken:',
    ],
}

KURGU["İstiklâl Marşı'nın Kabulü ve Mehmet Akif Ersoy'u Anma Günü"] = {
    'vecize': 'Korkma! Sönmez bu şafaklarda yüzen al sancak.',
    'vecizeKaynak': 'Mehmet Âkif Ersoy, İstiklâl Marşı',
    'ogrenciGorevi': {
        'baslik': 'İstiklâl Marşı’ndan Bir Dize',
        'yonerge': 'En sevdiğin dizeyi yaz ve neden sevdiğini anlat.',
    },
    'kronoloji': [
        {'yil': '1920', 'olay': 'Millî marş için yarışma açıldı.'},
        {'yil': '12 Mart 1921',
         'olay': 'TBMM İstiklâl Marşı’nı kabul etti.'},
        {'yil': '1921',
         'olay': 'Mehmet Âkif ödülü almadı, yoksullara bağışladı.'},
        {'yil': '1936', 'olay': 'Mehmet Âkif Ersoy vefat etti.'},
    ],
    'soruCevap': [
        {'soru': 'İstiklâl Marşı ne zaman kabul edildi?',
         'cevap': '12 Mart 1921’de TBMM’de kabul edildi. Kurtuluş Savaşı '
                  'sürüyordu.'},
        {'soru': 'Marşı kim yazdı?',
         'cevap': 'Mehmet Âkif Ersoy. Şair ve milletvekiliydi.'},
        {'soru': 'Neden ödülü almadı?',
         'cevap': 'Marşı para için yazmadığını söyledi. Ödülü ihtiyaç '
                  'sahiplerine bağışladı.'},
        {'soru': 'Marş neden “Korkma” diye başlar?',
         'cevap': 'En zor günlerde yazıldı. İlk söz, umutsuzluğa düşen '
                  'bir millete verilen cesarettir.'},
        {'soru': 'Marş kaç kıtadır?',
         'cevap': 'On kıtadır. Törenlerde ilk iki kıtası okunur.'},
        {'soru': 'Marş okunurken ne yapılır?',
         'cevap': 'Ayakta, hazır ol duruşunda ve sessizce eşlik edilir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'İlk Söz',
         'metin': 'Bir marş “korkma” diye başlar,\n'
                  'En korkulu günlerde.\n'
                  'Cesaret böyle verilir,\n'
                  'Önce sözle, sonra işle.'},
        {'baslik': 'Şair',
         'metin': 'Ödülü almadı, geri çevirdi,\n'
                  'Bu marş satılık değil dedi.\n'
                  'Parayı yoksula bağışladı,\n'
                  'Sözünü ise millete.'},
        {'baslik': 'Ayakta',
         'metin': 'Marş okunurken kalkarız,\n'
                  'Susarız, dinler, eşlik ederiz.\n'
                  'O anda hepimiz aynı sözü,\n'
                  'Aynı anda söylüyoruz.'},
        {'baslik': 'Bayrak',
         'metin': 'Al sancak göğün altında,\n'
                  'Her sabah yeniden yükselir.\n'
                  'Sönmez dediği o şafak,\n'
                  'Hâlâ üstümüzde duruyor.'},
    ],
    'biliyorMuydunuz': [
        'İstiklâl Marşı 12 Mart 1921’de TBMM’de kabul edildi.',
        'Marş için açılan yarışmaya yedi yüzden fazla şiir katıldı.',
        'Mehmet Âkif önce yarışmaya katılmadı; ödül şartı kaldırılınca '
        'yazdı.',
        'Kazandığı ödülü almadı, ihtiyaç sahiplerine bağışladı.',
        'Marş on kıtadır; törenlerde ilk iki kıtası okunur.',
        'Bestesi Osman Zeki Üngör’e aittir.',
    ],
    'sozler': [
        'Marş okunurken göstereceğim saygı:',
        'Bu yıl ezberleyeceğim kıta:',
        'Bayrağımıza karşı sorumluluğum:',
    ],
    'panoParagraflar': [
      'İstiklâl Marşı, 12 Mart 1921’de Türkiye Büyük Millet Meclisi tarafından millî marş olarak kabul edildi. Şiiri Mehmet Âkif Ersoy yazdı. Marş, Kurtuluş Savaşı’nın en zor günlerinde, ülkenin geleceğinin belirsiz olduğu bir dönemde yazılmıştır.',
      'Marş için açılan yarışmaya yüzlerce şiir gönderildi ama hiçbiri yeterli bulunmadı. Mehmet Âkif, para ödülü olduğu için yarışmaya katılmak istemedi. Ödülün kaldırılacağı söylenince şiirini yazdı ve kazanan şiir için verilen ödülü de kabul etmeyip bağışladı.',
      'İstiklâl Marşı bir savaş şiiri değildir. Korkuyu değil güveni, düşmanlığı değil bağımsızlık isteğini anlatır. “Korkma!” diye başlaması bu yüzden anlamlıdır.',
      'Mehmet Âkif Ersoy 1936’da vefat etti. Sade bir hayat yaşadı; sözünün arkasında durmasıyla ve tok gözlülüğüyle anılır. Bu gün hem marşın kabulünü hem onun hatırasını anmak için ayrılmıştır.',
    ],
    'sozluk': [
      {
        'kavram': 'İstiklâl',
        'tanim': 'Bağımsızlık; başka bir gücün yönetimi altında olmama.',
      },
      {
        'kavram': 'Millî marş',
        'tanim': 'Bir milletin resmî törenlerde okunan, onu simgeleyen marşı.',
      },
      {
        'kavram': 'Kıta',
        'tanim': 'Şiirde belli sayıda dizeden oluşan bölüm.',
      },
      {
        'kavram': 'Sancak',
        'tanim': 'Bayrak; bir milletin simgesi olan kumaş.',
      },
      {
        'kavram': 'Hilâl',
        'tanim': 'Ay’ın ince biçimi; Türk bayrağındaki ay.',
      },
      {
        'kavram': 'Tok gözlülük',
        'tanim': 'Kendine yetme, hakkı olmayana göz dikmeme hâli.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Yarışma ve ödül',
        'oncesi': 'Mehmet Âkif, ödül olduğu için yarışmaya katılmak istemedi.',
        'sonrasi': 'Ödül kaldırılınca şiirini yazdı; kazandığı ödülü de bağışladı.',
      },
      {
        'baslik': 'Marşın tonu',
        'oncesi': 'Bir savaş döneminde yazıldığı için öfkeli sanılabilir.',
        'sonrasi': '“Korkma!” diye başlar; korkuyu değil güveni anlatır.',
      },
      {
        'baslik': 'Marşın yeri',
        'oncesi': 'Kabulden önce ortak bir millî marş yoktu.',
        'sonrasi': '12 Mart 1921’den beri aynı marş okunuyor.',
      },
    ],
}


# =====================================================================
# OKUL VE MESLEK HAFTALARI
# =====================================================================

KURGU['Öğretmenler Günü'] = {
    'vecize': 'Öğretmenler! Yeni nesil sizin eseriniz olacaktır.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Öğretmenime Teşekkür',
        'yonerge': 'Öğretmeninden öğrendiğin bir şeyi yaz.',
    },
    'kronoloji': [
        {'yil': '1928', 'olay': 'Yeni Türk harfleri kabul edildi.'},
        {'yil': '24 Kasım 1928',
         'olay': 'Atatürk’e Başöğretmenlik unvanı verildi.'},
        {'yil': '1981',
         'olay': '24 Kasım, Öğretmenler Günü olarak kutlanmaya başlandı.'},
    ],
    'soruCevap': [
        {'soru': 'Öğretmenler Günü neden 24 Kasım?',
         'cevap': 'Atatürk’e Başöğretmenlik unvanının verildiği gündür. '
                  '1981’den beri bu tarihte kutlanır.'},
        {'soru': 'Başöğretmen ne demek?',
         'cevap': 'Öğretmenlerin başı. Atatürk yeni harfleri halka kara '
                  'tahta başında kendisi öğretti.'},
        {'soru': 'Öğretmen sadece ders mi anlatır?',
         'cevap': 'Hayır. Dinlemeyi, paylaşmayı ve zorlukla baş etmeyi de '
                  'öğretir.'},
        {'soru': 'En iyi teşekkür nedir?',
         'cevap': 'Derse hazırlıklı gelmek, dinlemek ve öğrenmek. Hediyeden '
                  'çok bu değerlidir.'},
        {'soru': 'Öğretmen olmak için ne gerekir?',
         'cevap': 'Sabır, bilgi ve öğrenmeye devam etme isteği. Öğretmen '
                  'de hep öğrenir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Kara Tahta',
         'metin': 'Bir tahta, bir tebeşir,\nBir de sabırlı bir ses.\n'
                  'Bilmediğimiz ne varsa,\nOrada başladı hepsi.'},
        {'baslik': 'Sabır',
         'metin': 'Yüz kere sorsak da aynı şeyi,\nYine anlatır baştan.\n'
                  'Öğretmek sabır işidir,\nBunu ondan öğrendik.'},
        {'baslik': 'İz',
         'metin': 'Yıllar sonra unutulur,\nKaç soru doğru yaptığın.\n'
                  'Ama unutulmaz asla,\nSana inanan o ses.'},
        {'baslik': 'Teşekkür',
         'metin': 'En güzel hediye şudur:\nHazır gelmek derse.\n'
                  'Dinlemek, sormak, öğrenmek,\nGerisi süs sadece.'},
    ],
    'biliyorMuydunuz': [
        '24 Kasım, Atatürk’e Başöğretmenlik unvanının verildiği gündür.',
        'Öğretmenler Günü 1981’den beri kutlanıyor.',
        'Atatürk yeni harfleri Millet Mektepleri’nde halka kendisi '
        'öğretmiştir.',
        'Dünya Öğretmenler Günü ise 5 Ekim’de kutlanır.',
        'Köy Enstitüleri 1940’ta kurulmuş, öğretmen yetiştirmiştir.',
        'Öğretmenlik, insanlığın en eski mesleklerinden biridir.',
    ],
    'sozler': [
        'Derse hazır gelmek için yapacağım:',
        'Bu yıl öğretmenimden öğrenmek istediğim:',
        'Sınıfa katkım olsun diye:',
    ],
    'panoParagraflar': [
      '24 Kasım 1928’de Mustafa Kemal Atatürk’e Millet Mektepleri Başöğretmenliği unvanı verildi. Yeni harflerin öğretildiği o yıllarda Atatürk kara tahta başına geçmiş, kendisi de ders anlatmıştı. Bu tarih, 1981’den bu yana Öğretmenler Günü olarak kutlanıyor.',
      'Öğretmenlik yalnızca bilgi aktarmak değildir. Bir öğretmen çoğu zaman bilgiyi öğretirken bir şeyi daha öğretir: merak etmeyi, vazgeçmemeyi, yanlış yaptığında yeniden denemeyi. Yıllar sonra hatırlananlar da çoğunlukla bunlar olur.',
      'Bir öğretmenin işi ders saatiyle bitmez. Bir öğrencinin anlamadığı yeri fark etmek, sessiz kalanı konuşturmak, kırılan birine dokunmak da öğretmenliğin parçasıdır. Bu yüzden öğretmenlik bir meslek olduğu kadar bir sorumluluktur.',
      'Bu gün yalnızca hediye ve çiçek günü değildir. Öğretmene gösterilecek en büyük saygı, onun anlattığını öğrenmeye çalışmak ve öğrendiğini başkasıyla paylaşmaktır.',
    ],
    'sozluk': [
      {
        'kavram': 'Başöğretmen',
        'tanim': 'Atatürk’e 24 Kasım 1928’de verilen unvan; yeni harflerin öğretilmesine öncülük etmesini anlatır.',
      },
      {
        'kavram': 'Millet Mektepleri',
        'tanim': 'Yeni Türk harflerinin halka öğretilmesi için açılan okullar.',
      },
      {
        'kavram': 'Eğitim',
        'tanim': 'Bilgi, beceri ve değerlerin planlı biçimde kazandırılması süreci.',
      },
      {
        'kavram': 'Öğretmen',
        'tanim': 'Öğrenmeyi planlayan, yol gösteren ve rehberlik eden kişi.',
      },
      {
        'kavram': 'Rehberlik',
        'tanim': 'Öğrencinin kendini tanıması ve karar vermesi için verilen destek.',
      },
      {
        'kavram': 'Okuryazarlık',
        'tanim': 'Okuma ve yazma becerisine sahip olma durumu.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Harf devrimi',
        'oncesi': 'Eski harflerle okuryazar oranı çok düşüktü.',
        'sonrasi': 'Yeni harfler ve Millet Mektepleri ile okuryazarlık hızla yaygınlaştı.',
      },
      {
        'baslik': 'Öğretmenin işi',
        'oncesi': 'Öğretmenlik yalnızca bilgi aktarmak sanılır.',
        'sonrasi': 'Merak ettirmek, yeniden denetmek ve yol göstermek de işin parçasıdır.',
      },
      {
        'baslik': 'Bu güne yakışan',
        'oncesi': 'Gün yalnızca hediye ve çiçekle geçirilir.',
        'sonrasi': 'Öğrenmeye çalışmak ve öğrendiğini paylaşmak en büyük teşekkürdür.',
      },
    ],
}

KURGU['İlköğretim Haftası'] = {
    'vecize': 'Bir milletin geleceği, o milletin çocuklarına vereceği '
              'eğitime bağlıdır.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Bu Yıl Hedefim',
        'yonerge': 'Bu öğretim yılında başarmak istediğin bir şeyi yaz.',
    },
    'kronoloji': [
        {'yil': '1924',
         'olay': 'Tevhid-i Tedrisat ile eğitim tek çatı altında birleşti.'},
        {'yil': '1928', 'olay': 'Yeni harflerle okuma seferberliği başladı.'},
        {'yil': '1997', 'olay': 'Zorunlu eğitim sekiz yıla çıkarıldı.'},
        {'yil': '2012', 'olay': 'Zorunlu eğitim on iki yıl oldu.'},
    ],
    'soruCevap': [
        {'soru': 'İlköğretim Haftası ne zaman?',
         'cevap': 'Okulların açıldığı ilk hafta kutlanır. Yeni yıla '
                  'başlangıcı simgeler.'},
        {'soru': 'Zorunlu eğitim kaç yıl?',
         'cevap': 'On iki yıl. Dört yıl ilkokul, dört yıl ortaokul, '
                  'dört yıl lise.'},
        {'soru': 'Okul neden zorunlu?',
         'cevap': 'Okumak bir hak. Her çocuk bu haktan yararlansın diye '
                  'devlet güvenceye almıştır.'},
        {'soru': 'İyi bir öğrenci ne yapar?',
         'cevap': 'Merak eder, sorar, denemekten korkmaz. Not değil '
                  'öğrenmek asıldır.'},
        {'soru': 'Sınıf kuralları neden var?',
         'cevap': 'Herkesin rahat öğrenmesi için. Kurallar kısıtlamak '
                  'değil, hakkı korumak içindir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'İlk Gün',
         'metin': 'Yeni bir defter açılır,\nİlk sayfası bomboş.\n'
                  'Ne yazacağını sen seçersin,\nYıl daha yeni başlıyor.'},
        {'baslik': 'Merak',
         'metin': 'En iyi soru şudur:\n“Acaba neden böyle?”\n'
                  'Merak eden çocuk,\nCevabı mutlaka bulur.'},
        {'baslik': 'Sıra',
         'metin': 'Bu sırada oturan çocuk,\nYarın bir iş kuracak.\n'
                  'Bugün öğrendiği her şey,\nO işin temeli olacak.'},
        {'baslik': 'Birlikte',
         'metin': 'Yalnız öğrenmek zordur,\nBirlikte kolaylaşır.\n'
                  'Bilene sor, bilmeyene anlat,\nSınıf böyle sınıf olur.'},
    ],
    'biliyorMuydunuz': [
        'Türkiye’de zorunlu eğitim on iki yıldır.',
        'Tevhid-i Tedrisat Kanunu 1924’te eğitimi tek çatı altında '
        'birleştirdi.',
        'Yeni Türk harfleri 1928’de kabul edildi.',
        'Millet Mektepleri’nde yetişkinlere okuma yazma öğretildi.',
        'Eğitim hakkı Anayasa ile güvence altına alınmıştır.',
        'Dünyada okula gidemeyen milyonlarca çocuk hâlâ var.',
    ],
    'sozler': [
        'Bu yıl düzenli yapacağım:',
        'Zorlandığımda yapacağım:',
        'Arkadaşıma yardım etmek için:',
    ],
    'panoParagraflar': [
      'İlköğretim Haftası, ders yılının ilk haftasında kutlanır. Amacı okulu tanıtmak, yeni başlayan öğrencileri karşılamak ve eğitimin önemini hatırlatmaktır.',
      'Okulun ilk günü herkes için biraz heyecan vericidir. Özellikle birinci sınıfa başlayanlar için her şey yenidir: sıra, zil, teneffüs, yeni arkadaşlar. Üst sınıfların bu hafta onlara yol göstermesi güzel bir gelenektir.',
      'Eğitim bir hak olduğu kadar bir fırsattır. Okumak, yalnızca sınav geçmek için değil; anlamak, seçim yapabilmek ve kendi kararını verebilmek içindir. Okuryazar bir insan aldatılması zor bir insandır.',
      'Okul yalnızca ders yeri de değildir. Sıra beklemek, paylaşmak, tartışmak ve anlaşmazlığı konuşarak çözmek de burada öğrenilir. Bu yüzden okulun ilk haftası kuralları birlikte belirlemek için iyi bir fırsattır.',
    ],
    'sozluk': [
      {
        'kavram': 'İlköğretim',
        'tanim': 'Zorunlu eğitimin ilkokul ve ortaokulu kapsayan bölümü.',
      },
      {
        'kavram': 'Zorunlu eğitim',
        'tanim': 'Her çocuğun almak zorunda olduğu, devletin sağladığı eğitim.',
      },
      {
        'kavram': 'Okuryazarlık',
        'tanim': 'Okuma ve yazma becerisine sahip olma durumu.',
      },
      {
        'kavram': 'Ders yılı',
        'tanim': 'Eylülde başlayıp haziranda biten öğretim dönemi.',
      },
      {
        'kavram': 'Uyum',
        'tanim': 'Yeni bir ortama alışma süreci.',
      },
      {
        'kavram': 'Akran',
        'tanim': 'Yaşça ve durumca birbirine yakın olan kişi.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'İlk gün',
        'oncesi': 'Okulun ilk günü yeni başlayan için her şey yabancıdır.',
        'sonrasi': 'Üst sınıflar yol gösterince uyum hızlanır.',
      },
      {
        'baslik': 'Okumanın amacı',
        'oncesi': 'Okumak yalnızca sınav geçmek sanılır.',
        'sonrasi': 'Anlamak ve kendi kararını verebilmek içindir.',
      },
      {
        'baslik': 'Kuralların kaynağı',
        'oncesi': 'Kurallar hazır verilince benimsenmesi zor olur.',
        'sonrasi': 'Birlikte konuşarak belirlenen kurala uyulması kolaylaşır.',
      },
    ],
}

KURGU['Bilim ve Teknoloji Haftası'] = {
    'vecize': 'Hayatta en hakiki mürşit ilimdir.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Merak Ettiğim Soru',
        'yonerge': 'Bilime sormak istediğin bir soru yaz.',
    },
    'kronoloji': [
        {'yil': 'Gözlem',
         'olay': 'Bilim bir soruyla başlar: “Acaba neden böyle?”'},
        {'yil': 'Deney',
         'olay': 'Tahmin denenir; sonuç ölçülür ve kaydedilir.'},
        {'yil': 'Paylaşım',
         'olay': 'Sonuç yayımlanır, başkaları tekrarlar ve denetler.'},
        {'yil': 'Bilgi',
         'olay': 'Tekrarlanabilen sonuç bilgiye dönüşür.'},
    ],
    'soruCevap': [
        {'soru': 'Bilim nedir?',
         'cevap': 'Merak edilen şeyi gözlem ve deneyle araştırıp '
                  'kanıtlarla açıklama yoludur.'},
        {'soru': 'Hipotez ne demek?',
         'cevap': 'Sınanabilir tahmin. Deneyle doğrulanır veya çürütülür; '
                  'ikisi de değerlidir.'},
        {'soru': 'Yanlış çıkan deney işe yaramaz mı?',
         'cevap': 'Yarar. Neyin olmadığını bilmek de bilgidir; bilim '
                  'böyle ilerler.'},
        {'soru': 'Teknoloji ile bilim aynı mı?',
         'cevap': 'Değil. Bilim “neden” sorusunu sorar, teknoloji o bilgiyi '
                  'işe dönüştürür.'},
        {'soru': 'Çocuk bilim yapabilir mi?',
         'cevap': 'Elbette. Soru sormak, gözlemek ve denemek bilimin '
                  'kendisidir.'},
        {'soru': 'Kaynak neden önemli?',
         'cevap': 'Bilgi nereden geldiği bilinmeden güvenilmez. '
                  'Bilim kaynağını gösterir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Soru',
         'metin': 'Her şey bir soruyla başlar,\n“Acaba neden böyle?”\n'
                  'Cevabı arayan çocuk,\nBilim yapıyor demektir.'},
        {'baslik': 'Deney',
         'metin': 'Tahmin et, sonra dene,\nÖlç, yaz, tekrar bak.\n'
                  'Sonuç beklediğin değilse,\nÜzülme, bu da bilgidir.'},
        {'baslik': 'Sabır',
         'metin': 'Bir buluş bir günde olmaz,\nYüz deneme, doksan hata.\n'
                  'Vazgeçmeyen o kişi,\nSonunda cevabı bulur.'},
        {'baslik': 'Paylaşmak',
         'metin': 'Bulduğunu saklama,\nAnlat, yaz, göster.\n'
                  'Bilim paylaşılınca,\nHerkesin malı olur.'},
    ],
    'biliyorMuydunuz': [
        'Bilimsel yöntem gözlem, hipotez, deney ve sonuç adımlarından '
        'oluşur.',
        'Yanlışlanabilir olmayan bir iddia bilimsel sayılmaz.',
        'Bir deneyin geçerli olması için başkalarınca tekrarlanabilmesi '
        'gerekir.',
        'Penisilin, unutulan bir petri kabındaki küf sayesinde bulundu.',
        'Aşı, hastalık etkeninin zayıflatılmış hâliyle bağışıklık '
        'kazandırır.',
        'Ali Kuşçu, Uluğ Bey Gözlemevi’nde çalışmış Türk astronomudur.',
    ],
    'sozler': [
        'Bu hafta araştıracağım konu:',
        'Merak ettiğim ve soracağım soru:',
        'Deneyeceğim yeni şey:',
    ],
    'panoParagraflar': [
      'Bilim, merak edilen bir soruyu düzenli biçimde araştırıp yanıtlamaktır. Bir bilim insanı önce gözlem yapar, sonra bir tahminde bulunur, sonra bunu dener. Deney tahmini doğrulamazsa tahmin değişir — bu bir başarısızlık değil, yöntemin ta kendisidir.',
      'Teknoloji ise bilimin günlük hayatta işe dönüşmüş hâlidir. Aşı, buzdolabı, telefon, uydu… Hepsi önce bir sorunun cevabı olarak ortaya çıktı. Teknoloji tek başına iyi ya da kötü değildir; nasıl kullanıldığına bağlıdır.',
      'Bilim tek bir kişinin işi de değildir. Her buluş kendinden öncekilerin üzerine kurulur. Bugün kullandığımız en basit aletin arkasında bile yüzyıllar süren bir birikim vardır.',
      'Bilim insanı olmak için laboratuvar şart değildir. Soru sormak, gözlemlemek, not tutmak ve “acaba neden?” demek sınıfta da yapılabilir. Bilim, meraktan başlar.',
    ],
    'sozluk': [
      {
        'kavram': 'Bilim',
        'tanim': 'Doğayı ve olayları düzenli yöntemlerle inceleyip açıklama çabası.',
      },
      {
        'kavram': 'Teknoloji',
        'tanim': 'Bilimsel bilginin günlük hayatta işe dönüştürülmüş hâli.',
      },
      {
        'kavram': 'Hipotez',
        'tanim': 'Bir soruya verilen, denenerek sınanacak geçici cevap.',
      },
      {
        'kavram': 'Deney',
        'tanim': 'Bir tahmini sınamak için kurulan denetimli çalışma.',
      },
      {
        'kavram': 'Gözlem',
        'tanim': 'Bir olayı dikkatle izleyip kaydetme.',
      },
      {
        'kavram': 'Buluş',
        'tanim': 'Daha önce olmayan bir araç veya yöntemin ortaya konması.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Yanlış çıkan tahmin',
        'oncesi': 'Tahmin doğrulanmayınca çalışma başarısız sanılır.',
        'sonrasi': 'Yanlışlanan tahmin bilgiyi ilerletir; yöntem böyle işler.',
      },
      {
        'baslik': 'Buluşun sahibi',
        'oncesi': 'Her buluş tek bir kişiye mal edilir.',
        'sonrasi': 'Her buluş kendinden önceki birikimin üzerine kurulur.',
      },
      {
        'baslik': 'Teknolojinin yönü',
        'oncesi': 'Teknoloji tek başına iyi ya da kötü sayılır.',
        'sonrasi': 'Nasıl kullanıldığı onu yararlı ya da zararlı yapar.',
      },
    ],
}

# =====================================================================
# SAĞLIK, ÇEVRE VE TOPLUM HAFTALARI
# =====================================================================

KURGU['Yeşilay Haftası'] = {
    'vecize': 'Sağlam kafa sağlam vücutta bulunur.',
    'vecizeKaynak': 'Atasözü',
    'ogrenciGorevi': {
        'baslik': 'Sağlıklı Alışkanlığım',
        'yonerge': 'Bu hafta kazanmak istediğin sağlıklı alışkanlığı yaz.',
    },
    'kronoloji': [
        {'yil': '1920', 'olay': 'Yeşilay kuruldu.'},
        {'yil': 'Amaç',
         'olay': 'Bağımlılıkla mücadele ve sağlıklı yaşamı yaygınlaştırmak.'},
        {'yil': 'Bugün',
         'olay': 'Okullarda ve toplumda önleyici çalışmalar yürütülüyor.'},
    ],
    'soruCevap': [
        {'soru': 'Yeşilay ne zaman kuruldu?',
         'cevap': '1920’de kuruldu. Bağımlılıkla mücadele için çalışır.'},
        {'soru': 'Bağımlılık nedir?',
         'cevap': 'Bir şeyi bırakamama hâli. Kişi zarar gördüğünü bilse '
                  'bile devam eder.'},
        {'soru': 'Ekran bağımlılığı olur mu?',
         'cevap': 'Olur. Uyku, ders ve arkadaşlıktan çalıyorsa sınır '
                  'koymak gerekir.'},
        {'soru': 'En iyi korunma nedir?',
         'cevap': 'Hiç başlamamak. Merak da olsa denememek en güvenli '
                  'yoldur.'},
        {'soru': 'Arkadaşım ısrar ederse?',
         'cevap': '“Hayır” demek hakkın. Seni gerçekten seven arkadaş '
                  'zorlamaz.'},
        {'soru': 'Sağlıklı yaşam neyle başlar?',
         'cevap': 'Uykuyla, dengeli beslenmeyle ve hareketle. Küçük '
                  'alışkanlıklar büyük fark yaratır.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Hayır Demek',
         'metin': 'İki harflik küçük bir söz,\nAma en güçlü kalkan.\n'
                  '“Hayır” demeyi bilen çocuk,\nKendini korumayı bilir.'},
        {'baslik': 'Alışkanlık',
         'metin': 'Küçük başlar, büyür sonra,\nÖnce sen onu seçersin.\n'
                  'Sonra o seni seçer,\nBırakmak zorlaşır.'},
        {'baslik': 'Hareket',
         'metin': 'Koş, oyna, terle biraz,\nEkrandan kalk bir süre.\n'
                  'Beden hareket isterse,\nZihin de dinlenir.'},
        {'baslik': 'Arkadaş',
         'metin': 'Seni zorlayan arkadaş,\nSeni düşünmüyordur.\n'
                  'Gerçek dost yanında durur,\nYanlışa çekmez seni.'},
    ],
    'biliyorMuydunuz': [
        'Yeşilay 1920’de kuruldu.',
        'Bağımlılık bir alışkanlık değil, tedavi gerektiren bir durumdur.',
        'Ekran süresi uyku düzenini bozabilir; yatmadan önce ekran '
        'önerilmez.',
        'Düzenli uyku öğrenmeyi ve hatırlamayı kolaylaştırır.',
        'Yeşilay’ın danışma hattı ücretsizdir ve gizlilik esastır.',
        'Spor yapmak stresi azaltan doğal bir yoldur.',
    ],
    'sozler': [
        'Ekran süremi azaltmak için:',
        'Bu hafta yapacağım spor:',
        'Sağlıklı beslenmek için:',
    ],
    'panoParagraflar': [
      'Yeşilay 1920’de kuruldu. Amacı, insanları bağımlılıklardan korumak ve sağlıklı yaşamı yaygınlaştırmaktır. Bugün sigara, alkol ve madde bağımlılığının yanında teknoloji ve kumar bağımlılığıyla da ilgilenir.',
      'Bağımlılık, bir şeyi yapmayı bırakamamak demektir. Kişi zarar gördüğünü bilse bile duramaz. Bu bir irade zayıflığı değil, zamanla gelişen bir sorundur; bu yüzden en iyi yol hiç başlamamaktır.',
      'Teknoloji bağımlılığı çocukları en çok etkileyen türdür. Ekran başında geçen sürenin uzaması uykuyu, dersleri ve arkadaşlıkları etkiler. Sorun teknolojinin kendisi değil, ölçüsüz kullanımıdır.',
      'Sağlıklı yaşam yalnızca hastalanmamak değildir. Yeterince uyumak, dengeli beslenmek, hareket etmek ve kendini iyi hissetmek de bunun parçasıdır. Bu alışkanlıklar çocuklukta kurulur.',
    ],
    'sozluk': [
      {
        'kavram': 'Bağımlılık',
        'tanim': 'Zarar verdiğini bilmesine rağmen kişinin bir davranışı veya maddeyi bırakamaması.',
      },
      {
        'kavram': 'Yeşilay',
        'tanim': '1920’de kurulan, bağımlılıkla mücadele eden kurum.',
      },
      {
        'kavram': 'Sağlıklı yaşam',
        'tanim': 'Dengeli beslenme, düzenli uyku, hareket ve ruhsal iyilik hâlini kapsayan yaşam biçimi.',
      },
      {
        'kavram': 'Ekran süresi',
        'tanim': 'Gün içinde telefon, tablet ve bilgisayar başında geçirilen toplam zaman.',
      },
      {
        'kavram': 'Akran baskısı',
        'tanim': 'Arkadaş grubunun etkisiyle istemediği bir şeyi yapma hissi.',
      },
      {
        'kavram': 'Korunma',
        'tanim': 'Zararlı bir davranışla hiç karşılaşmadan önce alınan önlem.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Başlamak ve bırakmak',
        'oncesi': 'Bir kere denemenin zararı olmadığı düşünülür.',
        'sonrasi': 'Bırakmak, hiç başlamamaktan çok daha zordur.',
      },
      {
        'baslik': 'Ekran süresi',
        'oncesi': 'Ölçüsüz ekran uykuyu, dersi ve arkadaşlığı etkiler.',
        'sonrasi': 'Sınır konulunca teknoloji zararlı olmaktan çıkıp araç hâline gelir.',
      },
      {
        'baslik': 'Hayır diyebilmek',
        'oncesi': 'Arkadaş baskısıyla istemediği şeyi yapan kişi sonradan pişman olur.',
        'sonrasi': 'Kararını açıkça söyleyebilen kişi hem kendini hem arkadaşını korur.',
      },
    ],
}

KURGU['Orman Haftası'] = {
    'vecize': 'Bir milletin yaşlı ağaçları, o milletin tarihidir.',
    'vecizeKaynak': 'Atasözü',
    'ogrenciGorevi': {
        'baslik': 'Ağacıma Söz Veriyorum',
        'yonerge': 'Doğayı korumak için yapacağın bir şeyi yaz.',
    },
    'kronoloji': [
        {'yil': 'Tohum', 'olay': 'Toprağa düşer, su ve ışık bekler.'},
        {'yil': 'Fidan', 'olay': 'İlk yıllarda bakım ve koruma ister.'},
        {'yil': 'Ağaç', 'olay': 'Gölge verir, havayı temizler, toprağı tutar.'},
        {'yil': 'Orman', 'olay': 'Binlerce canlıya yuva olur.'},
    ],
    'soruCevap': [
        {'soru': 'Ormanlar ne işe yarar?',
         'cevap': 'Havayı temizler, erozyonu önler, canlılara yuva olur '
                  've suyu toprakta tutar.'},
        {'soru': 'Erozyon nedir?',
         'cevap': 'Toprağın su ve rüzgârla taşınması. Ağaç kökleri '
                  'toprağı tutarak bunu engeller.'},
        {'soru': 'Bir ağaç ne kadar oksijen verir?',
         'cevap': 'Yetişkin bir ağaç, birkaç kişinin günlük oksijen '
                  'ihtiyacını karşılayabilir.'},
        {'soru': 'Orman yangını neden çıkar?',
         'cevap': 'Çoğu insan kaynaklıdır: söndürülmeyen ateş, atılan '
                  'izmarit, cam parçası.'},
        {'soru': 'Fidan dikmek yeterli mi?',
         'cevap': 'Değil. Dikilen fidanın sulanması ve korunması gerekir; '
                  'bakımsız fidan tutmaz.'},
        {'soru': 'Kâğıt tasarrufu ormanı korur mu?',
         'cevap': 'Korur. Kâğıt ağaçtan yapılır; geri dönüşüm ve tasarruf '
                  'kesimi azaltır.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Tohum',
         'metin': 'Avucuna sığan bir tohum,\nİçinde koca bir ağaç.\n'
                  'Toprağa ver, suyunu ver,\nGerisini o bilir.'},
        {'baslik': 'Kök',
         'metin': 'Görünmez ama tutar,\nToprağı sıkıca kavrar.\n'
                  'Yağmur yağınca sel olmaz,\nKök oradaysa eğer.'},
        {'baslik': 'Gölge',
         'metin': 'Diktiğin ağacın gölgesinde,\nBelki sen oturmazsın.\n'
                  'Ama biri oturur bir gün,\nSana teşekkür eder.'},
        {'baslik': 'Ateş',
         'metin': 'Bir kıvılcım yeter bazen,\nYüz yıllık ormanı almaya.\n'
                  'Söndürmeden gitme sakın,\nDikkat en büyük bakımdır.'},
    ],
    'biliyorMuydunuz': [
        'Ağaçlar fotosentezle karbondioksit alıp oksijen verir.',
        'Ağaç kökleri toprağı tutarak erozyonu önler.',
        'Orman yangınlarının büyük bölümü insan kaynaklıdır.',
        'Kâğıt geri dönüşümü ağaç kesimini azaltır.',
        'Türkiye’nin yüzölçümünün önemli bir bölümü ormanlarla kaplıdır.',
        'Bir ormanın kendini yenilemesi onlarca yıl sürer.',
    ],
    'sozler': [
        'Kâğıt tasarrufu için yapacağım:',
        'Doğada gezerken dikkat edeceğim:',
        'Bu yıl bakacağım bitki:',
    ],
    'panoParagraflar': [
      'Orman, yalnızca yan yana dizilmiş ağaçlar değildir. Toprağı, suyu, böcekleri, kuşları ve memelileriyle birlikte çalışan bir bütündür. Bir ağacı kestiğimizde yalnızca o ağacı kaybetmeyiz; onun gölgesinde yaşayan canlıların yuvasını da kaybederiz.',
      'Ağaç kökleri toprağı bir ağ gibi tutar. Kökler olmayınca yağmur suyu toprağı sürükler; buna erozyon denir. Erozyona uğrayan toprak artık ürün vermez ve geri kazanılması yüzyıllar alır. Ormanı korumak, aslında toprağı korumaktır.',
      'Orman yangınlarının çoğu insan kaynaklıdır: söndürülmeyen bir ateş, yere atılan bir izmarit, güneşi odaklayan bir cam parçası. Yanan bir orman birkaç saatte yok olur ama yerine gelmesi onlarca yıl sürer.',
      'Fidan dikmek güzel bir başlangıçtır, ama tek başına yetmez. Dikilen fidanın sulanması ve korunması gerekir. Bakımsız bir fidan tutmaz. Bu yüzden orman haftasında yalnızca dikmeyi değil, bakmayı da konuşuruz.',
    ],
    'sozluk': [
      {
        'kavram': 'Orman',
        'tanim': 'Ağaçların ve onlarla birlikte yaşayan canlıların oluşturduğu doğal yaşam alanı.',
      },
      {
        'kavram': 'Erozyon',
        'tanim': 'Toprağın su ve rüzgârla aşınıp taşınması.',
      },
      {
        'kavram': 'Fidan',
        'tanim': 'Yeni dikilmiş, henüz büyümemiş genç ağaç.',
      },
      {
        'kavram': 'Oksijen',
        'tanim': 'Canlıların solunumda kullandığı, bitkilerin ürettiği gaz.',
      },
      {
        'kavram': 'Geri dönüşüm',
        'tanim': 'Kullanılmış malzemenin yeniden hammadde olarak değerlendirilmesi.',
      },
      {
        'kavram': 'Ekosistem',
        'tanim': 'Canlıların ve yaşadıkları çevrenin birbirine bağlı olduğu bütün.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Kökü olan ve olmayan toprak',
        'oncesi': 'Ağaç kökleri toprağı tutar; yağmur toprağa işler.',
        'sonrasi': 'Ağaçlar kesilince yağmur toprağı sürükler, sel ve erozyon başlar.',
      },
      {
        'baslik': 'Dikmek ve bakmak',
        'oncesi': 'Yalnızca dikilen fidanların çoğu ilk yılda kurur.',
        'sonrasi': 'Sulanan ve korunan fidan tutar, yıllar içinde ağaç olur.',
      },
      {
        'baslik': 'Yangının hızı',
        'oncesi': 'Bir orman yüzyıllarda oluşur.',
        'sonrasi': 'Aynı orman birkaç saatte yanıp yok olabilir.',
      },
    ],
    'panoKartlar': [
      {
        'baslik': 'Orman nedir?',
        'metin': 'Ağaçların, toprağın, suyun ve canlıların birlikte çalıştığı bir bütündür.',
      },
      {
        'baslik': 'Neden önemli?',
        'metin': 'Havayı temizler, toprağı tutar, suyu saklar ve binlerce canlıya yuva olur.',
      },
      {
        'baslik': 'En büyük tehlike',
        'metin': 'Orman yangınlarının çoğu insan kaynaklıdır. Dikkat, en ucuz korumadır.',
      },
      {
        'baslik': 'Sınıfta ne yaparız?',
        'metin': 'Fidan bakım takvimi tutar, kâğıt tasarrufu için sınıf kuralı belirleriz.',
      },
      {
        'baslik': 'Dikmek yetmez',
        'metin': 'Fidan sulanmazsa tutmaz. Asıl iş dikimden sonra başlar.',
      },
      {
        'baslik': 'Kâğıt da ağaçtır',
        'metin': 'Bir yüzü boş kâğıdı atmamak da ormanı korumaktır.',
      },
    ],
}

KURGU['Çevre Koruma Haftası'] = {
    'vecize': 'Yurdumuzu dünyanın en mamur ve medeni memleketleri '
              'seviyesine çıkaracağız.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Çevreme Katkım',
        'yonerge': 'Çevreni korumak için yapacağın bir şeyi yaz.',
    },
    'kronoloji': [
        {'yil': 'Azalt', 'olay': 'En iyi atık, hiç üretilmeyendir.'},
        {'yil': 'Yeniden kullan',
         'olay': 'Kullanılabilir eşya çöpe atılmaz.'},
        {'yil': 'Dönüştür',
         'olay': 'Ayrıştırılan atık yeni ürüne dönüşür.'},
        {'yil': 'Kalan', 'olay': 'Geriye kalan en aza iner.'},
    ],
    'soruCevap': [
        {'soru': 'Geri dönüşüm nedir?',
         'cevap': 'Kullanılmış malzemenin işlenip yeniden ürüne '
                  'dönüştürülmesi.'},
        {'soru': 'Atık nasıl ayrıştırılır?',
         'cevap': 'Kâğıt, cam, plastik ve metal ayrı kutulara atılır. '
                  'Karışan atık dönüştürülemez.'},
        {'soru': 'Plastik doğada ne kadar kalır?',
         'cevap': 'Yüzlerce yıl. Küçük parçalara ayrılır ama yok olmaz.'},
        {'soru': 'Su tasarrufu neden önemli?',
         'cevap': 'Temiz su sınırlıdır. Dişini fırçalarken musluğu kapatmak '
                  'bile fark yaratır.'},
        {'soru': 'Tek kişi ne değiştirebilir?',
         'cevap': 'Çok şey. Bir sınıf, bir okul, bir mahalle hep tek '
                  'kişilerden oluşur.'},
        {'soru': 'Pil neden ayrı atılır?',
         'cevap': 'İçindeki ağır metaller toprağa ve suya karışıp zarar '
                  'verir. Pil kutusuna atılmalıdır.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Musluk',
         'metin': 'Açık kalan bir musluk,\nSessizce boşa akar.\n'
                  'Kapatmak bir saniye,\nKazandırdığı çok şey.'},
        {'baslik': 'Ayrıştır',
         'metin': 'Kâğıt ayrı, cam ayrı,\nPlastik ve metal ayrı.\n'
                  'Karışırsa hepsi çöp,\nAyrılırsa hepsi yeni.'},
        {'baslik': 'Poşet',
         'metin': 'Bir kere kullanıp attığın,\nYüzyıllarca kalır burada.\n'
                  'Bez bir çanta al yanına,\nHem kolay hem doğru.'},
        {'baslik': 'Küçük Adım',
         'metin': 'Tek başına ne değişir,\nDeme sakın böyle.\n'
                  'Bir okul, bir mahalle,\nHep tek kişiden oluşur.'},
    ],
    'biliyorMuydunuz': [
        'Plastik doğada yüzlerce yıl çözünmeden kalabilir.',
        'Bir ton kâğıt geri dönüştürüldüğünde onlarca ağaç korunur.',
        'Cam sonsuz kere geri dönüştürülebilir, kalitesi düşmez.',
        'Atık piller ağır metal içerir; ayrı toplanması gerekir.',
        'Dünya Çevre Günü 5 Haziran’da kutlanır.',
        'Musluğu açık bırakmak dakikada litrelerce su kaybettirir.',
    ],
    'sozler': [
        'Su tasarrufu için yapacağım:',
        'Atıklarımı ayrıştırmak için:',
        'Bu hafta azaltacağım kullanım:',
    ],
    'panoParagraflar': [
      'Çevre, içinde yaşadığımız her şeydir: soluduğumuz hava, içtiğimiz su, bastığımız toprak ve birlikte yaşadığımız canlılar. Çevreyi korumak uzak bir ülkenin sorunu değildir; sınıfın penceresinden görünen sokakta başlar.',
      'Atık, kullanıldıktan sonra atılan maddedir. Ama her atık çöp değildir. Kâğıt, cam, plastik ve metal ayrı toplanırsa yeniden hammadde olur. Buna geri dönüşüm denir. Ayrıştırılmadan atılan bir şişe çöp olur; ayrı atılan aynı şişe yeni bir ürüne dönüşür.',
      'En etkili yöntem geri dönüşüm bile değildir: en iyisi hiç atık üretmemektir. Gerekmedikçe almamak, tek kullanımlık yerine yeniden kullanılabilir olanı tercih etmek, bir yüzü boş kâğıdı atmamak… Bunların hepsi geri dönüşümden önce gelir.',
      'Küçük alışkanlıklar çoğaldığında büyük fark yaratır. Bir sınıf bir yılda yüzlerce kâğıt tasarruf edebilir. Suyu akarken kapatmak, ışığı çıkarken söndürmek, çöpü yerine atmak — hiçbiri zor değildir, hepsi öğrenilebilir.',
    ],
    'sozluk': [
      {
        'kavram': 'Çevre',
        'tanim': 'Canlıların içinde yaşadığı hava, su, toprak ve diğer canlılardan oluşan ortam.',
      },
      {
        'kavram': 'Atık',
        'tanim': 'Kullanıldıktan sonra atılan madde.',
      },
      {
        'kavram': 'Geri dönüşüm',
        'tanim': 'Atığın yeniden hammadde olarak değerlendirilmesi.',
      },
      {
        'kavram': 'Kirlilik',
        'tanim': 'Hava, su veya toprağın canlılara zarar verecek ölçüde bozulması.',
      },
      {
        'kavram': 'Doğal kaynak',
        'tanim': 'Doğadan elde edilen ve sınırlı olan su, toprak, orman gibi varlıklar.',
      },
      {
        'kavram': 'Ayrıştırma',
        'tanim': 'Atıkların türüne göre ayrı kutulara atılması.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Şişenin yolu',
        'oncesi': 'Karışık atılan bir şişe çöp sahasına gider.',
        'sonrasi': 'Ayrı atılan aynı şişe yeni bir ürüne dönüşür.',
      },
      {
        'baslik': 'Akan su',
        'oncesi': 'Dişler fırçalanırken açık bırakılan musluk litrelerce suyu boşa akıtır.',
        'sonrasi': 'Musluğu kapatmak aynı işi çok daha az suyla yaptırır.',
      },
      {
        'baslik': 'Kâğıdın iki yüzü',
        'oncesi': 'Tek yüzü kullanılıp atılan kâğıdın yarısı boşa gider.',
        'sonrasi': 'Arka yüzü müsvedde olarak kullanılan kâğıt iki kat iş görür.',
      },
    ],
    'panoKartlar': [
      {
        'baslik': 'Çevre nedir?',
        'metin': 'Hava, su, toprak ve birlikte yaşadığımız canlıların tümüdür.',
      },
      {
        'baslik': 'Her atık çöp değil',
        'metin': 'Kâğıt, cam, plastik ve metal ayrı toplanırsa yeniden hammadde olur.',
      },
      {
        'baslik': 'En iyisi',
        'metin': 'Geri dönüştürmekten de iyisi, hiç atık üretmemektir.',
      },
      {
        'baslik': 'Sınıfta ne yaparız?',
        'metin': 'Ayrı toplama kutuları kurar, bir haftalık atık günlüğü tutarız.',
      },
      {
        'baslik': 'Küçük alışkanlık',
        'metin': 'Suyu kapatmak, ışığı söndürmek, çöpü yerine atmak.',
      },
      {
        'baslik': 'Nereden başlar?',
        'metin': 'Uzak ülkelerden değil, sınıfın penceresinden görünen sokaktan.',
      },
    ],
}

KURGU['Trafik ve İlkyardım Haftası'] = {
    'vecize': 'Tedbir, kazadan sonra değil önce alınır.',
    'vecizeKaynak': 'Atasözü',
    'ogrenciGorevi': {
        'baslik': 'Trafikte Sözüm',
        'yonerge': 'Trafikte uyacağın bir kuralı yaz.',
    },
    'kronoloji': [
        {'yil': 'Dur', 'olay': 'Kaldırımda dur, adım atma.'},
        {'yil': 'Bak', 'olay': 'Önce sola, sonra sağa, tekrar sola bak.'},
        {'yil': 'Dinle', 'olay': 'Araç sesi var mı, kulak ver.'},
        {'yil': 'Geç', 'olay': 'Yol boşsa yürüyerek geç, koşma.'},
    ],
    'soruCevap': [
        {'soru': 'Yaya geçidinde ne yapılır?',
         'cevap': 'Önce durulur, sola-sağa-sola bakılır, araç yoksa '
                  'yürüyerek geçilir.'},
        {'soru': 'Emniyet kemeri arkada da gerekli mi?',
         'cevap': 'Gereklidir. Arka koltukta da kaza anında koruma '
                  'sağlar ve zorunludur.'},
        {'soru': 'İlk yardımda ilk adım nedir?',
         'cevap': 'Kendi güvenliğini sağlamak. Sonra 112 aranır.'},
        {'soru': 'Kazazede oynatılır mı?',
         'cevap': 'Hayır. Hayati tehlike yoksa yerinden oynatılmaz; '
                  'yardım beklenir.'},
        {'soru': 'Acil çağrı numarası kaç?',
         'cevap': '112. Sakin konuşulur, yer ve durum net söylenir.'},
        {'soru': 'Bisiklette kask şart mı?',
         'cevap': 'Şarttır. Kafa yaralanmalarının çoğunu kask önler.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Dur Bak Geç',
         'metin': 'Önce dur, sonra bak,\nSola, sağa, sola tekrar.\n'
                  'Yol boşsa yürüyerek,\nKoşarak değil asla.'},
        {'baslik': 'Kemer',
         'metin': 'Bir tık sesi yeterli,\nİki saniye sürer.\n'
                  'Ama o iki saniye,\nBir hayat kurtarabilir.'},
        {'baslik': 'Yüz On İki',
         'metin': 'Bir kaza gördüğünde,\nÖnce kendini koru.\n'
                  'Sonra ara yüz on iki,\nSakin ve net anlat.'},
        {'baslik': 'Acele',
         'metin': 'Acele giden yetişmez,\nÇoğu zaman gecikir.\n'
                  'Bir dakika beklemek,\nBir ömre bedeldir.'},
    ],
    'biliyorMuydunuz': [
        'Acil çağrı numarası 112’dir ve ücretsizdir.',
        'Emniyet kemeri arka koltukta da zorunludur.',
        'Kask, bisiklet kazalarında kafa yaralanmalarını büyük ölçüde '
        'azaltır.',
        'Yaya geçidinde yayanın geçiş üstünlüğü vardır.',
        'İlk yardımda ilk kural kendi güvenliğini sağlamaktır.',
        'Kazazede, hayati tehlike yoksa yerinden oynatılmaz.',
    ],
    'sozler': [
        'Yolda karşıya geçerken:',
        'Araçta oturduğumda:',
        'Bisiklete binerken:',
    ],
    'panoParagraflar': [
      'Trafik yalnızca araçlarla ilgili değildir. Yayalar, bisikletliler ve sürücüler aynı alanı paylaşır. Kuralların amacı kimseyi kısıtlamak değil, herkesin güvenle geçmesini sağlamaktır. Bir kural ihlali çoğu zaman yalnızca ihlali yapanı değil, çevredeki herkesi tehlikeye atar.',
      'Yaya geçidi, üst geçit ve trafik ışığı yayanın güvenliği için vardır. Karşıya geçerken önce durmak, sonra sola-sağa-sola bakmak ve araçların durduğundan emin olmak gerekir. Kırmızı ışıkta bekleyen bir yaya, kendisiyle birlikte arkasındaki küçük çocuğa da örnek olur.',
      'İlk yardım, sağlık ekibi gelene kadar yapılan ilk ve basit müdahaledir. Amacı iyileştirmek değil, durumun kötüleşmesini önlemektir. En önemli üç adım: kendi güvenliğini sağlamak, 112’yi aramak ve yaralıyı gereksiz yere hareket ettirmemek.',
      'Bir kaza gördüğümüzde panik yapmak yerine ne söyleyeceğimizi bilmek işe yarar: nerede olduğumuzu, kaç kişinin yaralandığını ve ne olduğunu net anlatmak. Doğru bilgi, ekibin daha hızlı ulaşmasını sağlar.',
    ],
    'sozluk': [
      {
        'kavram': 'Yaya',
        'tanim': 'Trafikte araç kullanmadan, yürüyerek yer alan kişi.',
      },
      {
        'kavram': 'Yaya geçidi',
        'tanim': 'Yayaların karşıya geçmesi için ayrılmış, çizgilerle belirtilmiş alan.',
      },
      {
        'kavram': 'İlk yardım',
        'tanim': 'Sağlık ekibi gelene kadar yapılan ilk, basit ve hayat kurtarıcı müdahale.',
      },
      {
        'kavram': '112',
        'tanim': 'Türkiye’de acil sağlık, itfaiye ve güvenlik için aranan ortak acil çağrı numarası.',
      },
      {
        'kavram': 'Emniyet kemeri',
        'tanim': 'Araçta ani duruş ve çarpışmada kişiyi koltuğunda tutan güvenlik donanımı.',
      },
      {
        'kavram': 'Kask',
        'tanim': 'Bisiklet ve motosiklette başı koruyan sert başlık.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Karşıya geçmek',
        'oncesi': 'Koşarak ve bakmadan geçmek, sürücüye tepki verecek zaman bırakmaz.',
        'sonrasi': 'Durup sola-sağa-sola bakmak ve aracın durduğundan emin olmak güvenli geçişi sağlar.',
      },
      {
        'baslik': 'Kaza anında',
        'oncesi': 'Panikle yaralıyı çekiştirmek yaralanmayı ağırlaştırabilir.',
        'sonrasi': '112’yi arayıp yaralıyı hareket ettirmeden beklemek doğru olandır.',
      },
      {
        'baslik': 'Kask ve kemer',
        'oncesi': 'Kısa yol bahanesiyle takılmayan kemer, ani duruşta işe yaramaz.',
        'sonrasi': 'Her yolculukta takılan kemer ve kask ciddi yaralanmaları önler.',
      },
    ],
    'panoKartlar': [
      {
        'baslik': 'Trafik kimindir?',
        'metin': 'Yayaların, bisikletlilerin ve sürücülerin ortak alanıdır.',
      },
      {
        'baslik': 'Karşıya geçerken',
        'metin': 'Önce dur, sonra sola-sağa-sola bak. Aracın durduğundan emin ol.',
      },
      {
        'baslik': 'İlk yardım nedir?',
        'metin': 'Sağlık ekibi gelene kadar durumun kötüleşmesini önleyen ilk müdahaledir.',
      },
      {
        'baslik': 'Acil numara',
        'metin': '112 aranır. Yer, kişi sayısı ve olay net anlatılır.',
      },
      {
        'baslik': 'Sınıfta ne yaparız?',
        'metin': 'Okul çevresinin trafik haritasını çıkarır, riskli noktaları işaretleriz.',
      },
      {
        'baslik': 'En küçük kural',
        'metin': 'Kemer ve kask, en kısa yolda bile takılır.',
      },
    ],
}

KURGU['Engelliler Haftası'] = {
    'vecize': 'Engel, insanın kendisinde değil, önündeki basamaktadır.',
    'vecizeKaynak': 'Yaygın söz',
    'ogrenciGorevi': {
        'baslik': 'Engeli Kaldırmak',
        'yonerge': 'Okulunda kaldırılmasını istediğin bir engeli yaz.',
    },
    'kronoloji': [
        {'yil': 'Rampa', 'olay': 'Merdiven engeli tekerlekli sandalyeyle aşılır.'},
        {'yil': 'Braille', 'olay': 'Kabartma yazı görmeyenlerin okumasını sağlar.'},
        {'yil': 'İşaret dili',
         'olay': 'Duymayanlarla iletişimin kendi dilidir.'},
        {'yil': 'Farkındalık',
         'olay': 'Asıl engel, çevrenin ve bakışın engellemesidir.'},
    ],
    'soruCevap': [
        {'soru': 'Engelli birine nasıl davranılır?',
         'cevap': 'Herkese davranıldığı gibi. Acımadan, ayrı tutmadan, '
                  'doğrudan kendisine konuşarak.'},
        {'soru': 'Yardım etmeli miyim?',
         'cevap': 'Önce sor: “Yardım edebilir miyim?” İstemiyorsa ısrar '
                  'etme; bu da saygıdır.'},
        {'soru': 'Braille alfabesi nedir?',
         'cevap': 'Kabartma noktalarla yazılan alfabe. Parmakla '
                  'dokunularak okunur.'},
        {'soru': 'İşaret dili tek mi?',
         'cevap': 'Hayır, her ülkenin kendi işaret dili var. Türkiye’de '
                  'Türk İşaret Dili kullanılır.'},
        {'soru': 'Rampa neden önemli?',
         'cevap': 'Tekerlekli sandalye merdiven çıkamaz. Rampa varsa engel '
                  'ortadan kalkar.'},
        {'soru': 'Asıl engel nedir?',
         'cevap': 'Çoğu zaman çevredeki eksiklik: rampasız bina, dar kapı, '
                  'anlayışsız bakış.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Rampa',
         'metin': 'Üç basamak vardı orada,\nGeçemeyen biri kaldı.\n'
                  'Bir rampa yapıldı sonra,\nEngel ortadan kalktı.'},
        {'baslik': 'Parmak Uçları',
         'metin': 'Gözle değil parmakla,\nOkunur bazı kitaplar.\n'
                  'Kabartma noktalar altında,\nAynı hikâyeler saklı.'},
        {'baslik': 'Eller',
         'metin': 'Bazı sözler sesle değil,\nEllerle söylenir.\n'
                  'Öğrensek biraz hepimiz,\nKimse yalnız kalmaz.'},
        {'baslik': 'Sor Önce',
         'metin': 'Yardım etmeden önce sor,\n“Yardım edebilir miyim?”\n'
                  'İstemezse ısrar etme,\nSaygı da bir yardımdır.'},
    ],
    'biliyorMuydunuz': [
        'Braille alfabesi kabartma noktalarla yazılır, parmakla okunur.',
        'Türkiye’de Türk İşaret Dili kullanılır; her ülkenin dili farklıdır.',
        'Rampa, asansör ve geniş kapı erişilebilirliğin temel '
        'unsurlarındandır.',
        'Sarı renkli kabartma yol çizgileri görme engelliler içindir.',
        'Rehber köpeklerin toplu taşımaya binme hakkı vardır.',
        'Paralimpik Oyunları 1960’tan beri düzenleniyor.',
    ],
    'sozler': [
        'Arkadaşımı dışlamamak için:',
        'Okulumda kaldırmak istediğim engel:',
        'Öğrenmek istediğim işaret:',
    ],
    'panoParagraflar': [
      'Engellilik bir hastalık değildir. Görme, işitme, hareket ya da öğrenme alanında bir farklılıktır. Asıl engel çoğu zaman kişinin kendisinde değil, çevrenin düzenlenme biçimindedir. Rampası olmayan bir kapı, tekerlekli sandalye kullanan biri için aşılmaz bir duvara dönüşür.',
      'Erişilebilirlik, bir yerin herkes tarafından kullanılabilmesi demektir. Rampa, asansör, geniş kapı, sesli uyarı, kabartma yazı… Bunlar özel bir iyilik değil, bir haktır. Erişilebilir bir okul yalnızca engelli öğrenciye değil, ayağı kırılan bir arkadaşımıza da yarar.',
      'Yardım etmek isterken de bir incelik gerekir: önce sormak. “Yardım edeyim mi?” demeden birinin koluna girmek, iyi niyetli olsa bile rahatsız edicidir. Herkes kendi işini kendi yapmak ister; bu, engelli biri için de böyledir.',
      'Empati, kendini bir başkasının yerine koyabilmektir. Ama empatinin gözü kapalı yürüme oyunuyla bittiği sanılmamalı. Asıl empati, birlikte oynamak, birlikte çalışmak ve kimseyi dışarıda bırakmamaktır.',
    ],
    'sozluk': [
      {
        'kavram': 'Engellilik',
        'tanim': 'Görme, işitme, hareket veya öğrenme alanında süreklilik gösteren farklılık.',
      },
      {
        'kavram': 'Erişilebilirlik',
        'tanim': 'Bir yerin veya hizmetin herkes tarafından kullanılabilmesi.',
      },
      {
        'kavram': 'Rampa',
        'tanim': 'Basamak yerine eğimli yüzey; tekerlekli sandalyenin geçmesini sağlar.',
      },
      {
        'kavram': 'Braille (kabartma yazı)',
        'tanim': 'Görme engelli kişilerin parmak ucuyla okuduğu kabartmalı yazı sistemi.',
      },
      {
        'kavram': 'İşaret dili',
        'tanim': 'El, yüz ve beden hareketleriyle kurulan görsel dil.',
      },
      {
        'kavram': 'Empati',
        'tanim': 'Kendini bir başkasının yerine koyup onun hissettiğini anlamaya çalışmak.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Basamak ve rampa',
        'oncesi': 'Yalnızca basamağı olan bir giriş, tekerlekli sandalye kullanan biri için kapalıdır.',
        'sonrasi': 'Rampa eklendiğinde aynı giriş herkes için açılır.',
      },
      {
        'baslik': 'Yardım etmek',
        'oncesi': 'Sormadan koluna girmek, iyi niyetli olsa da rahatsız eder.',
        'sonrasi': '“Yardım edeyim mi?” diye sormak, kişinin kararını ona bırakır.',
      },
      {
        'baslik': 'Dışarıda kalmak',
        'oncesi': 'Oyun kuralları tek bir beceriye dayanınca bazı arkadaşlar hep dışarıda kalır.',
        'sonrasi': 'Kural birlikte değiştirilince herkes oyuna girer.',
      },
    ],
    'panoKartlar': [
      {
        'baslik': 'Engel nerede?',
        'metin': 'Çoğu zaman kişide değil, çevrenin düzenlenme biçimindedir.',
      },
      {
        'baslik': 'Erişilebilirlik',
        'metin': 'Rampa, asansör, geniş kapı ve sesli uyarı bir iyilik değil, bir haktır.',
      },
      {
        'baslik': 'Önce sor',
        'metin': '“Yardım edeyim mi?” demek, karşındakinin kararına saygı göstermektir.',
      },
      {
        'baslik': 'Sınıfta ne yaparız?',
        'metin': 'Okulun erişilebilirliğini gözlemler, kaldırılabilecek engelleri listeleriz.',
      },
      {
        'baslik': 'Farklılık',
        'metin': 'Engellilik bir eksiklik değil, bir farklılıktır.',
      },
      {
        'baslik': 'Herkese yarar',
        'metin': 'Erişilebilir okul, ayağı kırılan arkadaşımıza da yarar.',
      },
    ],
}

KURGU['Dünya Çocuk Hakları Günü'] = {
    'vecize': 'Küçük hanımlar, küçük beyler! Sizler hepiniz geleceğin bir '
              'gülü, bir yıldızısınız.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Benim Hakkım',
        'yonerge': 'Senin için en önemli çocuk hakkını yaz.',
    },
    'kronoloji': [
        {'yil': '1959', 'olay': 'Çocuk Hakları Bildirisi kabul edildi.'},
        {'yil': '20 Kasım 1989',
         'olay': 'Çocuk Haklarına Dair Sözleşme kabul edildi.'},
        {'yil': '1995',
         'olay': 'Türkiye sözleşmeyi onayladı.'},
        {'yil': 'Bugün',
         'olay': '20 Kasım, Dünya Çocuk Hakları Günü olarak anılır.'},
    ],
    'soruCevap': [
        {'soru': 'Çocuk hakları nedir?',
         'cevap': 'Her çocuğun doğuştan sahip olduğu haklar: yaşama, '
                  'eğitim, sağlık, korunma ve oynama.'},
        {'soru': 'Oyun bir hak mı?',
         'cevap': 'Evet. Sözleşmede açıkça yer alır; oyun çocuğun '
                  'gelişimi için gereklidir.'},
        {'soru': 'Çocuğun görüşü alınır mı?',
         'cevap': 'Alınmalıdır. Kendini ilgilendiren konularda görüşünü '
                  'söyleme hakkı vardır.'},
        {'soru': 'Kaç yaşına kadar çocuk sayılırız?',
         'cevap': 'Sözleşmeye göre on sekiz yaşına kadar herkes çocuktur.'},
        {'soru': 'Hakkım ihlal edilirse?',
         'cevap': 'Güvendiğin bir yetişkine söyle: öğretmenine, '
                  'rehber öğretmenine veya ailene.'},
        {'soru': 'Hak ile istek aynı mı?',
         'cevap': 'Değil. Hak herkese aittir ve korunur; istek kişiseldir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Doğuştan',
         'metin': 'Kimse vermedi bu hakkı,\nDoğduğun gün senindi.\n'
                  'Kimse de alamaz elinden,\nÇünkü hak öyle bir şey.'},
        {'baslik': 'Oyun',
         'metin': 'Oyun bir lüks değil,\nBir haktır, yazılıdır.\n'
                  'Öğrenmek de oyunla başlar,\nKoşarken büyür çocuk.'},
        {'baslik': 'Söz Hakkı',
         'metin': 'Seni ilgilendiren şeyde,\nSenin de bir sözün var.\n'
                  'Küçüksün diye susma,\nSöyle, dinlemek zorundalar.'},
        {'baslik': 'Eşit',
         'metin': 'Dili, rengi, yeri farklı,\nAma hakkı hep aynı.\n'
                  'Her çocuk eşit doğar,\nBu böyle yazılmıştır.'},
    ],
    'biliyorMuydunuz': [
        'Çocuk Haklarına Dair Sözleşme 20 Kasım 1989’da kabul edildi.',
        'Türkiye sözleşmeyi 1995’te onayladı.',
        'Sözleşmeye göre on sekiz yaşına kadar herkes çocuk sayılır.',
        'Oyun oynamak sözleşmede yer alan bir haktır.',
        'Çocuğun kendini ilgilendiren konularda görüş bildirme hakkı '
        'vardır.',
        'Sözleşme dünyada en çok ülke tarafından onaylanan insan hakları '
        'belgesidir.',
    ],
    'sozler': [
        'Arkadaşımın hakkına saygı için:',
        'Kendi hakkımı korumak için:',
        'Sınıfımızda düzeltmek istediğim:',
    ],
    'panoParagraflar': [
      'Hak, bir insanın sırf insan olduğu için sahip olduğu şeydir. Kazanılması ya da hak edilmesi gerekmez; doğduğu anda vardır. Çocuk hakları da böyledir: bir çocuk uslu durduğu için değil, çocuk olduğu için bu haklara sahiptir.',
      'Çocuk Hakları Sözleşmesi, dünyada en çok ülkenin kabul ettiği insan hakları belgesidir. Yaşama, eğitim, sağlık, korunma, oyun ve düşüncesini söyleme hakkı bu sözleşmede yer alır. Türkiye de bu sözleşmeye taraftır.',
      'Bu hakların içinde en çok unutulanı, çocuğun kendini ifade etme hakkıdır. Çocuğu ilgilendiren bir karar alınırken onun görüşünün sorulması gerekir. Bu, her istediğinin yapılacağı anlamına gelmez; söz hakkının verilmesi anlamına gelir.',
      'Oyun da bir haktır. Boş zaman doldurulacak bir aralık değil, çocuğun gelişiminin bir parçasıdır. Oynayarak öğrenmek, paylaşmayı ve kural koymayı da öğrenmektir.',
    ],
    'sozluk': [
      {
        'kavram': 'Hak',
        'tanim': 'İnsanın sırf insan olduğu için sahip olduğu, elinden alınamayan şey.',
      },
      {
        'kavram': 'Sorumluluk',
        'tanim': 'Bir hakkın karşılığında üstlenilen görev.',
      },
      {
        'kavram': 'Sözleşme',
        'tanim': 'Ülkelerin bir konuda uymayı kabul ettiği yazılı anlaşma.',
      },
      {
        'kavram': 'Eşitlik',
        'tanim': 'Herkesin aynı haklara sahip olması.',
      },
      {
        'kavram': 'Ayrımcılık',
        'tanim': 'Bir kişiye dili, dini, cinsiyeti veya durumu yüzünden farklı davranmak.',
      },
      {
        'kavram': 'Korunma hakkı',
        'tanim': 'Çocuğun her türlü ihmal, istismar ve şiddetten korunma hakkı.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Söz hakkı',
        'oncesi': 'Çocuğu ilgilendiren karar, ona sorulmadan alınır.',
        'sonrasi': 'Görüşü sorulan çocuk kararın bir parçası olur.',
      },
      {
        'baslik': 'Oyun',
        'oncesi': 'Oyun, boş zamanı dolduran bir ara sayılır.',
        'sonrasi': 'Oyun bir hak ve gelişimin parçası olarak görülür.',
      },
      {
        'baslik': 'Hak ve uysallık',
        'oncesi': 'Hakların uslu duran çocuğa verildiği sanılır.',
        'sonrasi': 'Haklar doğuştan vardır; davranışa bağlı değildir.',
      },
    ],
    'panoKartlar': [
      {
        'baslik': 'Hak nedir?',
        'metin': 'İnsanın sırf insan olduğu için sahip olduğu, elinden alınamayan şeydir.',
      },
      {
        'baslik': 'Kazanılmaz',
        'metin': 'Çocuk hakları uslu durmakla kazanılmaz; doğuştan vardır.',
      },
      {
        'baslik': 'Söz hakkı',
        'metin': 'Çocuğu ilgilendiren kararda onun görüşü sorulur.',
      },
      {
        'baslik': 'Oyun da haktır',
        'metin': 'Oyun boş zaman değil, gelişimin bir parçasıdır.',
      },
      {
        'baslik': 'Sınıfta ne yaparız?',
        'metin': 'Sınıf haklar panosu hazırlar, hak-sorumluluk eşleşmesi yaparız.',
      },
      {
        'baslik': 'Hakkın karşılığı',
        'metin': 'Her hakkın yanında bir sorumluluk durur.',
      },
    ],
}

# =====================================================================
# EKONOMİ VE TASARRUF HAFTALARI
# =====================================================================

KURGU['Tutum, Yatırım ve Türk Malları Haftası'] = {
    'vecize': 'Ekonomisi zayıf bir millet, fakirlik ve sefaletten '
              'kurtulamaz.',
    'vecizeKaynak': 'Mustafa Kemal Atatürk',
    'ogrenciGorevi': {
        'baslik': 'Tasarruf Sözüm',
        'yonerge': 'Bu ay biriktirmek veya tasarruf etmek istediğini yaz.',
    },
    'kronoloji': [
        {'yil': 'Kazanç', 'olay': 'Emekle veya harçlıkla para elde edilir.'},
        {'yil': 'Ayırma', 'olay': 'Bir kısmı harcanmadan kenara konur.'},
        {'yil': 'Birikim', 'olay': 'Küçük miktarlar zamanla çoğalır.'},
        {'yil': 'Hedef', 'olay': 'Biriken parayla planlanan alınır.'},
    ],
    'soruCevap': [
        {'soru': 'Tutum ne demek?',
         'cevap': 'Elindekini ölçülü kullanmak. Cimrilik değil, bilinçli '
                  'harcamaktır.'},
        {'soru': 'İhtiyaç ile istek farkı ne?',
         'cevap': 'İhtiyaç olmadan yaşanmaz; istek olmasa da olur. Önce '
                  'ihtiyaç karşılanır.'},
        {'soru': 'Yerli malı neden önemli?',
         'cevap': 'Ülke içinde üretim, istihdam ve gelir yaratır. Para '
                  'ülkede kalır.'},
        {'soru': 'Küçük birikim işe yarar mı?',
         'cevap': 'Yarar. Düzenli ayrılan küçük miktarlar zamanla anlamlı '
                  'bir tutara ulaşır.'},
        {'soru': 'Bütçe nedir?',
         'cevap': 'Gelir ve giderin planı. Ne kadar geldiğini ve nereye '
                  'gittiğini gösterir.'},
        {'soru': 'İsraf sadece para mıdır?',
         'cevap': 'Hayır. Ekmek, su, elektrik ve zaman da israf edilir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Kumbara',
         'metin': 'Her gün bir madeni para,\nKüçük gelir tek başına.\n'
                  'Ama bir yıl sonra bak,\nNe olmuş kumbaranda.'},
        {'baslik': 'İhtiyaç mı İstek mi',
         'metin': 'Almadan önce bir sor:\n“Gerçekten gerekli mi?”\n'
                  'Cevap “hayır” ise eğer,\nCebinde kalsın o para.'},
        {'baslik': 'Ekmek',
         'metin': 'Bir dilim ekmek atılır,\nSanki hiçbir şey değil.\n'
                  'Ama arkasında bir tarla,\nBir emek, bir alın teri.'},
        {'baslik': 'Yerli',
         'metin': 'Burada üretilen mal,\nBurada iş demektir.\n'
                  'Alırken bir düşün,\nParan nereye gidiyor.'},
    ],
    'biliyorMuydunuz': [
        'Tutum, elindekini ölçülü kullanmaktır; cimrilik değildir.',
        'Bütçe, gelir ve giderin yazılı planıdır.',
        'İhtiyaç olmadan yaşanamaz, istek ertelenebilir.',
        'Yerli üretim ülke içinde istihdam yaratır.',
        'Ekmek israfı Türkiye’de önemli bir sorundur.',
        'Elektrik ve su tasarrufu hem bütçeyi hem çevreyi korur.',
    ],
    'sozler': [
        'Bu ay biriktirmek istediğim:',
        'Azaltacağım gereksiz harcama:',
        'İsraf etmemek için yapacağım:',
    ],
    'panoParagraflar': [
      'Tutum, elindekini bilerek ve ölçülü kullanmaktır. Cimrilikle karıştırılmamalıdır: cimri harcamaz, tutumlu ise gerektiği yerde harcar ama israf etmez. İsraf, ihtiyaç olmadığı hâlde harcamak demektir.',
      'Birikim, bugün harcamayıp ileride kullanmak üzere ayırmaktır. Küçük ama düzenli birikim, büyük ve düzensiz birikimden daha çok iş görür. Bu yüzden kumbara alışkanlığı erken yaşta kazandırılır.',
      'Yerli malı kullanmak, ülkedeki üretimi ve çalışan insanı desteklemektir. Bir ürün ülkede üretildiğinde o işten pek çok aile geçinir. Bu hafta, üretmenin ve emeğin değerini konuşmak için de bir fırsattır.',
      'İhtiyaç ile istek farklıdır. İhtiyaç, olmadığında zorlandığımız şeydir; istek ise olsa iyi olur dediğimiz. Alışveriş yapmadan önce bu ayrımı yapmak, tutumlu olmanın ilk adımıdır.',
    ],
    'sozluk': [
      {
        'kavram': 'Tutum',
        'tanim': 'Elindekini ölçülü ve bilinçli kullanma davranışı.',
      },
      {
        'kavram': 'İsraf',
        'tanim': 'İhtiyaç olmadığı hâlde gereksiz yere harcamak.',
      },
      {
        'kavram': 'Birikim',
        'tanim': 'Bugün harcanmayıp ileride kullanılmak üzere ayrılan pay.',
      },
      {
        'kavram': 'Yatırım',
        'tanim': 'Birikimin gelir getirecek bir işe yöneltilmesi.',
      },
      {
        'kavram': 'Yerli malı',
        'tanim': 'Kendi ülkemizde üretilen ürün.',
      },
      {
        'kavram': 'İhtiyaç ve istek',
        'tanim': 'İhtiyaç olmadan zorlanılan, istek ise olsa iyi olacak şeydir.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Cimrilik ve tutum',
        'oncesi': 'Cimri, gerektiğinde bile harcamaz.',
        'sonrasi': 'Tutumlu kişi gerektiğinde harcar ama israf etmez.',
      },
      {
        'baslik': 'Birikimin biçimi',
        'oncesi': 'Ara sıra yapılan büyük birikim düzensiz kalır.',
        'sonrasi': 'Küçük ama düzenli birikim daha çok iş görür.',
      },
      {
        'baslik': 'Almadan önce',
        'oncesi': 'İhtiyaç ile istek ayrılmadan alışveriş yapılır.',
        'sonrasi': 'Ayrımı yapan kişi gereksiz harcamadan kaçınır.',
      },
    ],
}

KURGU['Enerji Tasarrufu Haftası'] = {
    'vecize': 'En ucuz enerji, tasarruf edilen enerjidir.',
    'vecizeKaynak': 'Yaygın söz',
    'ogrenciGorevi': {
        'baslik': 'Enerji Sözüm',
        'yonerge': 'Enerji tasarrufu için yapacağın bir şeyi yaz.',
    },
    'kronoloji': [
        {'yil': 'Üretim',
         'olay': 'Enerji santralde üretilir; çoğu kaynak sınırlıdır.'},
        {'yil': 'İletim', 'olay': 'Hatlarla taşınırken bir kısmı kaybolur.'},
        {'yil': 'Kullanım', 'olay': 'Evde ve okulda tüketilir.'},
        {'yil': 'Tasarruf',
         'olay': 'Kullanılmayan enerji hiç üretilmek zorunda kalmaz.'},
    ],
    'soruCevap': [
        {'soru': 'Enerji tasarrufu nedir?',
         'cevap': 'Aynı işi daha az enerjiyle yapmak veya gereksiz '
                  'tüketimi kesmek.'},
        {'soru': 'Yenilenebilir enerji nedir?',
         'cevap': 'Güneş, rüzgâr ve su gibi tükenmeyen kaynaklardan '
                  'elde edilen enerji.'},
        {'soru': 'Bekleme ışığı enerji harcar mı?',
         'cevap': 'Harcar. Fişte duran cihaz kapalı görünse de akım '
                  'çeker.'},
        {'soru': 'Ampul seçimi fark eder mi?',
         'cevap': 'Eder. LED ampuller aynı ışığı çok daha az enerjiyle '
                  'verir.'},
        {'soru': 'Perde ile enerji ilgisi ne?',
         'cevap': 'Gündüz perdeyi açmak lambaya gerek bırakmaz; kışın '
                  'akşam kapatmak ısıyı tutar.'},
        {'soru': 'Enerji tasarrufu çevreyi korur mu?',
         'cevap': 'Korur. Daha az enerji, daha az yakıt ve daha az '
                  'kirlilik demektir.'},
    ],
    'panoDortlukler': [
        {'baslik': 'Işık',
         'metin': 'Odadan çıkarken bir el,\nDüğmeye uzanıversin.\n'
                  'Bir saniyelik hareket,\nSaatlerce enerji.'},
        {'baslik': 'Fiş',
         'metin': 'Kapalı sanırsın ama,\nFişte duran cihaz.\n'
                  'Sessizce çeker durur,\nÇek fişi, bitsin iş.'},
        {'baslik': 'Güneş',
         'metin': 'Perdeyi aç sabahleyin,\nBedava ışık gelsin.\n'
                  'En temiz enerji odur,\nHer sabah kapıda bekler.'},
        {'baslik': 'Alışkanlık',
         'metin': 'Bir kere yapmak kolay,\nHer gün yapmak alışkanlık.\n'
                  'Asıl tasarruf orada,\nSüreklilikte saklı.'},
    ],
    'biliyorMuydunuz': [
        'Fişte duran cihazlar kapalıyken bile enerji çeker.',
        'LED ampuller akkor ampullere göre çok daha az enerji tüketir.',
        'Güneş, rüzgâr ve su yenilenebilir enerji kaynaklarıdır.',
        'Buzdolabı kapağını uzun süre açık tutmak tüketimi artırır.',
        'Enerji tasarrufu hem faturayı hem çevreyi korur.',
        'Türkiye’de rüzgâr ve güneş enerjisi kurulu gücü her yıl artıyor.',
    ],
    'sozler': [
        'Odadan çıkarken yapacağım:',
        'Bu hafta azaltacağım kullanım:',
        'Ailemle konuşacağım tasarruf konusu:',
    ],
    'panoParagraflar': [
      'Enerji, iş yapabilme gücüdür. Işığı yakmak, suyu ısıtmak, otobüsü hareket ettirmek — hepsi enerji ister. Kullandığımız enerjinin büyük bölümü kömür, doğal gaz ve petrol gibi tükenebilir kaynaklardan gelir.',
      'Tükenebilir kaynaklar bir gün biter ve yenilenmesi milyonlarca yıl alır. Güneş, rüzgâr ve su ise yenilenebilir kaynaklardır. Bu yüzden hem yenilenebilir kaynaklara yönelmek hem de kullandığımızı azaltmak gerekir.',
      'En ucuz ve en temiz enerji, hiç harcanmayan enerjidir. Boş odada yanan bir lamba, açık kalan bir şarj aleti, gereksiz ısınan bir oda — bunların hepsi kaynağın boşa gitmesidir.',
      'Tasarruf, kısıtlanmak değildir. Aynı işi daha az kaynakla yapmaktır. Sınıfta ışığı gerektiğinde yakmak, çıkarken söndürmek ve pencereden gelen gün ışığını kullanmak bunun en basit örnekleridir.',
    ],
    'sozluk': [
      {
        'kavram': 'Enerji',
        'tanim': 'İş yapabilme gücü; ısı, ışık ve hareket olarak kendini gösterir.',
      },
      {
        'kavram': 'Tasarruf',
        'tanim': 'Aynı işi daha az kaynak kullanarak yapmak.',
      },
      {
        'kavram': 'Yenilenebilir enerji',
        'tanim': 'Güneş, rüzgâr ve su gibi tükenmeyen kaynaklardan elde edilen enerji.',
      },
      {
        'kavram': 'Tükenebilir kaynak',
        'tanim': 'Kömür, petrol ve doğal gaz gibi bir gün bitecek kaynaklar.',
      },
      {
        'kavram': 'Verimlilik',
        'tanim': 'Harcanan enerjinin ne kadarının işe dönüştüğü.',
      },
      {
        'kavram': 'Yalıtım',
        'tanim': 'Isının dışarı kaçmasını engelleyen uygulama.',
      },
    ],
    'oncesiSonrasi': [
      {
        'baslik': 'Boş odadaki lamba',
        'oncesi': 'Kimsenin olmadığı odada yanan lamba enerjiyi boşa harcar.',
        'sonrasi': 'Çıkarken söndürmek hiçbir şeyden vazgeçmeden tasarruf sağlar.',
      },
      {
        'baslik': 'Kaynak seçimi',
        'oncesi': 'Tükenebilir kaynaklar bir gün biter.',
        'sonrasi': 'Güneş ve rüzgâr yenilenir; kullandıkça tükenmez.',
      },
      {
        'baslik': 'Tasarrufun anlamı',
        'oncesi': 'Tasarruf, kısıtlanmak sanılır.',
        'sonrasi': 'Aynı işi daha az kaynakla yapmaktır.',
      },
    ],
}

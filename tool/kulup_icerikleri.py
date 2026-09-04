# -*- coding: utf-8 -*-
"""52 ogrenci kulubunun yillik calisma plani icerigi.

`build_kulup_dataset.py` bu dosyadaki havuzu okuyup
`assets/data/kulup_planlari.json.gz` uretir.

## Kaynak ve telif
Kulup ADLARI ve belge duzeni MEB mevzuatindan gelir:
* Ogrenci Kulupleri Cizelgesi (EK-4), Degisik: RG-18/1/2023-32077 — 52 kulup
* MEB Egitim Kurumlari Sosyal Etkinlikler Yonetmeligi
  (RG 08.06.2017 / 30090), ozellikle MADDE 8

Ay/amac/etkinlik METINLERI bu projede yazilmistir; hicbir hazir plan
dosyasindan kopyalanmamistir. Mevzuat metni telife tabi degildir,
uretilen icerik ise bize aittir.

## Yazim kurallari
`PANO_ICERIK_KURALLARI.md` burada da baglayicidir. Ozetle:

* **Yil sabitleme yok.** "2025-2026 yilinda" yazilmaz; yil kunyeden gelir.
* **Sube adi yok.** "4-A" gecmez, gerekirse "sinifimiz" denir.
* **Tek okula ozgu ayrinti yok.** "Okulumuzun spor salonunda" yerine
  "salonda veya sinifta" gibi secenekli yazilir.
* **Zorunlu malzeme varsayilmaz.** Projeksiyon, renkli yazici, fotokopi
  butcesi her okulda yok; etkinlik bunlara bagli olmamali.
* **Butce gerektiren etkinlik dayatilmaz.** Yonetmelik MADDE 8/6 giderleri
  okul-aile birligi ve bagisa baglar; garanti degildir.
* **Gezi hafife alinmaz.** MADDE 10 gezi icin veli izin belgesi (EK-5) ve
  gorevlendirme sarti koyar. Plan metni geziyi "duzenlenebilir" diye
  yazar, kesin taahhut olarak degil.

## Ay duzeni
Ogretim yili Eylul'de baslar, Haziran'da biter — 10 ay. Sabit iskelet
her kulupte ayni islevi tasir:

* **Eylul**  kurulus, uye ve gorev dagilimi, yil planlamasi
* **Ocak**   birinci donem degerlendirmesi, ikinci donem hazirligi
* **Haziran** yil sonu degerlendirme ve faaliyet raporu

Aradaki yedi ay kulubun kendi konusudur.
"""

# Her kulup: (ek4_no, ad, kisa_kod, tema, [(ay, amac, etkinlik) x10])
#
# `tema` PDF renk seridi ve listede gruplama icin kullanilir:
#   bilim, kultur, sanat, spor, doga, toplum, saglik, degerler

AYLAR = ['Eylül', 'Ekim', 'Kasım', 'Aralık', 'Ocak',
         'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran']


def _kurulus(ad, odak):
    """Eylul satiri — her kulupte ayni islev, konu adiyla ozellesir."""
    return (
        'Kulübün kuruluşunu tamamlamak ve çalışma konusunu öğrencilere tanıtmak.',
        f'{ad}’nün amacı ve çalışma alanı öğrencilere açıklanır. Kulüp üyeleri '
        'belirlenir, kulüp temsilcisi seçilir ve görev dağılımı yapılır. Yıl içinde '
        f'yapılacak çalışmalar üyelerin görüşü alınarak planlanır. {odak}'
    )


def _donem_sonu(odak):
    """Ocak satiri — birinci donem degerlendirmesi."""
    return (
        'Birinci dönem çalışmalarını değerlendirmek ve ikinci dönemi planlamak.',
        'Dönem boyunca yapılan çalışmalar üyelerle birlikte gözden geçirilir. '
        f'{odak} Tamamlanamayan işler not edilir ve ikinci dönem çalışma takvimi '
        'buna göre düzenlenir.'
    )


def _yil_sonu(odak):
    """Haziran satiri — faaliyet raporu."""
    return (
        'Yıl boyunca yapılan çalışmaları değerlendirmek ve raporlaştırmak.',
        'Kulübün yıl içinde yaptığı tüm çalışmalar listelenir. '
        f'{odak} Eksik kalan çalışmalar gelecek yıla not edilir ve yıl sonu '
        'kulüp faaliyet raporu hazırlanarak sosyal etkinlikler kuruluna sunulur.'
    )


KULUPLER = []


def kulup(no, ad, kod, tema, kurulus_odak, donem_odak, yil_odak, aylar):
    """Kulubu havuza ekler.

    `aylar` Ekim-Aralik ve Subat-Mayis icin 7 (amac, etkinlik) ciftidir;
    Eylul, Ocak ve Haziran ortak iskeletten uretilir.
    """
    assert len(aylar) == 7, f'{ad}: 7 ay bekleniyor, {len(aylar)} geldi'
    sira = [_kurulus(ad, kurulus_odak)]
    sira += aylar[:3]                      # Ekim, Kasım, Aralık
    sira.append(_donem_sonu(donem_odak))   # Ocak
    sira += aylar[3:]                      # Şubat, Mart, Nisan, Mayıs
    sira.append(_yil_sonu(yil_odak))       # Haziran
    KULUPLER.append({
        'no': no, 'ad': ad, 'kod': kod, 'tema': tema,
        'plan': [{'ay': AYLAR[i], 'amac': a, 'etkinlik': e}
                 for i, (a, e) in enumerate(sira)],
    })


# ====================================================================
# 1 — AFET HAZIRLIK KULÜBÜ
# ====================================================================
kulup(
    1, 'Afet Hazırlık Kulübü', 'afet', 'toplum',
    kurulus_odak='Okulun afet ve acil durumlara hazırlık bakımından mevcut '
                 'durumu öğrencilerle birlikte değerlendirilir.',
    donem_odak='Öğrencilerin afet, tahliye ve güvenli davranış konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Pano, gözlem, bilgilendirme ve farkındalık çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Afet ve acil durumlarda doğru davranış geliştirmek.',
         'Deprem, yangın, sel ve fırtına gibi afet durumlarında yapılması gereken '
         'temel davranışlar ele alınır. Öğrencilere okul binasındaki acil çıkış '
         'yolları, toplanma alanı ve güvenli bölgeler tanıtılır. Afet anında '
         'panik yerine planlı hareket etmenin önemi örnek olaylarla açıklanır.'),
        ('Depreme hazırlık ve güvenli tahliye konusunda farkındalık kazandırmak.',
         'Deprem öncesinde alınabilecek önlemler, deprem sırasında uygulanan '
         'çök-kapan-tutun davranışı ve deprem sonrasında güvenli tahliye süreci '
         'üzerinde durulur. Öğrenciler afet çantasında bulunması gereken '
         'malzemeleri araştırır ve kulüp panosu için bilgilendirici liste hazırlar.'),
        ('Yangın güvenliği ve okul içi riskleri tanımak.',
         'Yangının çıkış nedenleri, yangın sırasında yapılması gerekenler, yangın '
         'söndürme araçlarının bulunduğu yerler ve güvenli tahliye yolları '
         'tanıtılır. Öğrenciler okul içinde risk oluşturabilecek alanları '
         'gözlemleyerek güvenli okul ortamı için öneriler geliştirir.'),
        ('Sivil savunma ve acil durum organizasyonunu tanımak.',
         'Sivil savunmanın amacı, afetlerde dayanışma, acil durum ekipleri ile '
         'alarm ve uyarı sistemleri hakkında bilgilendirme yapılır. Öğrenciler '
         'afet anında okulda hangi görevlerin üstlenilebileceğini gösteren örnek '
         'görev kartları hazırlar.'),
        ('İlk yardım ve afet sonrası güvenli davranış bilinci kazandırmak.',
         'İlk yardımın amacı, doğru yardım çağrısı yapma, 112 Acil Çağrı Merkezinin '
         'kullanımı, yaralıya bilinçsiz müdahaleden kaçınma ve afet sonrası güvenli '
         'bekleme davranışları ele alınır. Öğrenciler afet sonrası ilk dakikalarda '
         'yapılması gerekenleri anlatan bilgilendirici pano hazırlar.'),
        ('Okulda ve çevrede afet risklerini fark etmek.',
         'Öğrenciler okul, sınıf, bahçe ve yakın çevrede afet veya kaza riski '
         'oluşturabilecek durumları gözlemler. Riskli davranışlarla güvenli '
         'davranışlar karşılaştırılır. Güvenli yaşam kurallarını içeren afiş ve '
         'uyarı kartları hazırlanır.'),
        ('Afete hazırlık bilincini okul geneline ve ailelere yaymak.',
         'Afet çantası, güvenli tahliye, aile afet planı ve acil durum iletişim '
         'bilgileri konularında sınıflara yönelik kısa bilgilendirme çalışmaları '
         'yapılır. Öğrenciler evde aileleriyle birlikte afet planı hazırlamaya '
         'teşvik edilir.'),
    ])

# ====================================================================
# 2 — BİLİM-FEN VE TEKNOLOJİ KULÜBÜ
# ====================================================================
kulup(
    2, 'Bilim-Fen ve Teknoloji Kulübü', 'bilim', 'bilim',
    kurulus_odak='Öğrencilerin ilgi duyduğu bilim ve teknoloji konuları '
                 'belirlenerek yıl içinde işlenecek başlıklar seçilir.',
    donem_odak='Yapılan deney, gözlem ve araştırma çalışmalarının öğrencilerde '
               'bıraktığı kazanımlar değerlendirilir.',
    yil_odak='Deney, gözlem, araştırma ve tanıtım çalışmaları değerlendirilir.',
    aylar=[
        ('Bilimsel düşünme ve gözlem alışkanlığı kazandırmak.',
         'Bilimsel yöntemin basamakları örneklerle açıklanır. Öğrenciler günlük '
         'hayatta merak ettikleri bir durumu soru hâline getirir, tahminde bulunur '
         've gözlem yaparak sonucunu not eder. Gözlem defteri tutma alışkanlığı '
         'başlatılır.'),
        ('Basit araç gereçlerle deney yapma becerisi geliştirmek.',
         'Sınıf ortamında güvenle yapılabilecek, günlük malzemelerle kurulabilen '
         'basit deneyler seçilir. Öğrenciler deney öncesi tahminlerini yazar, '
         'sonucu gözlemler ve tahminleriyle karşılaştırır. Deney sırasında '
         'uyulacak güvenlik kuralları hatırlatılır.'),
        ('Bilim insanlarını ve buluş süreçlerini tanımak.',
         'Farklı alanlarda çalışmış bilim insanlarının hayatları ve çalışma '
         'biçimleri araştırılır. Bir buluşun ortaya çıkışındaki merak, deneme ve '
         'başarısızlık süreci vurgulanır. Öğrenciler seçtikleri bilim insanını '
         'tanıtan kısa yazı veya pano çalışması hazırlar.'),
        ('Teknolojiyi bilinçli ve amaca uygun kullanmak.',
         'Teknolojinin günlük hayatı kolaylaştıran yönleri ile aşırı kullanımın '
         'getirdiği sorunlar karşılaştırılır. Ekran süresi, uyku ve derse '
         'odaklanma ilişkisi üzerinde durulur. Öğrenciler kendi teknoloji kullanım '
         'alışkanlıklarını bir hafta boyunca gözlemleyerek değerlendirir.'),
        ('Doğa olaylarını gözlem yoluyla açıklamak.',
         'Mevsim değişimi, hava olayları, gökyüzü gözlemi veya bitki gelişimi gibi '
         'konulardan biri seçilerek düzenli gözlem yapılır. Ölçüm ve kayıt tutmanın '
         'önemi vurgulanır. Elde edilen veriler basit çizelge veya grafikle '
         'gösterilir.'),
        ('Geri dönüşüm ve enerji konularını bilimsel açıdan ele almak.',
         'Malzemelerin geri dönüşüm süreçleri ve enerjinin verimli kullanımı '
         'bilimsel yönleriyle incelenir. Öğrenciler okulda tüketilen kaynakları '
         'gözlemleyerek tasarruf önerileri geliştirir ve bunları bilgilendirici '
         'çalışmayla paylaşır.'),
        ('Yıl içinde yapılan bilim çalışmalarını okul geneline tanıtmak.',
         'Yıl boyunca yapılan deney, gözlem ve araştırmalardan seçilenler sınıf '
         'veya okul düzeyinde tanıtılır. Öğrenciler çalışmalarını akranlarına '
         'anlatarak sunum becerisi kazanır. Tanıtım için pano ve afiş çalışması '
         'yapılır.'),
    ])

# ====================================================================
# 3 — BİLİNÇLİ TÜKETİCİ KULÜBÜ
# ====================================================================
kulup(
    3, 'Bilinçli Tüketici Kulübü', 'tuketici', 'toplum',
    kurulus_odak='Öğrencilerin tüketim alışkanlıkları üzerine kısa bir '
                 'değerlendirme yapılarak yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin bilinçli alışveriş ve tasarruf konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Bütçe, tasarruf, etiket okuma ve hak arama çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('İhtiyaç ile istek arasındaki farkı ayırt etmek.',
         'İhtiyaç ve istek kavramları günlük hayattan örneklerle karşılaştırılır. '
         'Öğrenciler bir hafta boyunca yaptıkları harcamaları ihtiyaç ve istek '
         'olarak ayırır. Sınırlı kaynakla öncelik belirlemenin önemi üzerinde '
         'durulur.'),
        ('Ürün etiketi ve son kullanma tarihi okumayı öğrenmek.',
         'Ambalaj üzerindeki etiket bilgileri, içindekiler listesi, üretim ve son '
         'kullanma tarihi ile güvenlik işaretleri tanıtılır. Öğrenciler evden '
         'getirdikleri boş ambalajlar üzerinde etiket okuma çalışması yapar.'),
        ('Tasarruf alışkanlığı ve bütçe bilinci kazandırmak.',
         'Harcama planı yapmanın, biriktirmenin ve gereksiz alışverişten '
         'kaçınmanın önemi ele alınır. Öğrenciler kendileri için basit bir '
         'harcama planı hazırlar. Suyun, elektriğin ve kırtasiye malzemelerinin '
         'tutumlu kullanımı üzerinde durulur.'),
        ('Reklamların tüketici tercihine etkisini fark etmek.',
         'Reklamların dikkat çekmek için kullandığı yöntemler örneklerle '
         'incelenir. Bir ürünün gerçekten ihtiyaç olup olmadığına karar verirken '
         'nelere bakılması gerektiği tartışılır. Öğrenciler gördükleri bir reklamı '
         'bu açıdan değerlendirir.'),
        ('Tüketici haklarını ve başvuru yollarını tanımak.',
         'Tüketicinin temel hakları, fiş ve fatura saklamanın önemi, ayıplı mal '
         'durumunda izlenecek yol ve başvuru mercileri tanıtılır. Öğrenciler '
         'tüketici haklarını anlatan bilgilendirici pano hazırlar.'),
        ('İsrafı önleme ve kaynakları verimli kullanma bilinci geliştirmek.',
         'Gıda israfı, kırtasiye israfı ve kullanılabilir eşyanın atılması gibi '
         'durumlar ele alınır. Öğrenciler okulda ve evde israfı azaltmak için '
         'uygulanabilir öneriler geliştirir ve bunları sınıflarla paylaşır.'),
        ('Bilinçli tüketim bilincini okul geneline yaymak.',
         'Yıl içinde öğrenilen konulardan seçilenler kısa bilgilendirme '
         'çalışmalarıyla diğer sınıflara aktarılır. Etiket okuma, tasarruf ve '
         'tüketici hakları konularında hazırlanan afişler okul panosunda '
         'sergilenir.'),
    ])


# ====================================================================
# 4 — BİLİŞİM VE İNTERNET KULÜBÜ
# ====================================================================
kulup(
    4, 'Bilişim ve İnternet Kulübü', 'bilisim', 'bilim',
    kurulus_odak='Öğrencilerin bilgisayar ve internet kullanım alışkanlıkları '
                 'kısaca değerlendirilerek yıl içinde işlenecek konular seçilir.',
    donem_odak='Öğrencilerin güvenli internet ve dijital okuryazarlık '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Güvenli kullanım, dijital okuryazarlık ve üretim çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Güvenli internet kullanımının temel kurallarını öğrenmek.',
         'Kişisel bilgilerin paylaşılmaması, güçlü parola oluşturma ve tanımayan '
         'kişilerden gelen isteklere karşı dikkatli olma konuları ele alınır. '
         'Öğrenciler güvenli internet kurallarını maddeler hâlinde yazarak kulüp '
         'panosunda paylaşır.'),
        ('İnternetteki bilginin doğruluğunu sorgulamayı öğrenmek.',
         'Bir bilginin kaynağının nasıl kontrol edileceği, farklı kaynaklardan '
         'doğrulamanın önemi ve yanlış bilginin nasıl yayıldığı örneklerle '
         'incelenir. Öğrenciler karşılaştıkları bir bilgiyi kaynağıyla birlikte '
         'değerlendirme çalışması yapar.'),
        ('Siber zorbalığı tanımak ve karşısında doğru davranmak.',
         'Siber zorbalığın ne olduğu, mağdur üzerindeki etkisi ve karşılaşıldığında '
         'yapılması gerekenler ele alınır. Yardım istenebilecek kişi ve kurumlar '
         'tanıtılır. Öğrenciler saygılı dijital iletişim kurallarını içeren '
         'çalışma hazırlar.'),
        ('Ekran süresini ve dijital alışkanlıkları yönetmek.',
         'Ekran süresinin uyku, ders çalışma ve göz sağlığı üzerindeki etkisi '
         'üzerinde durulur. Öğrenciler bir hafta boyunca ekran kullanımlarını '
         'gözlemleyerek kendilerine denge önerisi geliştirir.'),
        ('Bilgisayarı üretim amacıyla kullanmayı denemek.',
         'Okulun imkânları ölçüsünde metin yazma, tablo hazırlama, çizim veya '
         'basit kodlama gibi üretim çalışmalarından biri seçilir. İmkân yoksa '
         'aynı mantık kâğıt üzerinde algoritma ve akış şeması çalışmasıyla '
         'yürütülür.'),
        ('Dijital iz ve mahremiyet kavramını fark etmek.',
         'İnternette bırakılan izlerin kalıcılığı, paylaşımların ileride doğurduğu '
         'sonuçlar ve mahremiyetin önemi ele alınır. Öğrenciler paylaşım öncesi '
         'kendine sorulacak soruları belirleyerek kısa bir kontrol listesi '
         'hazırlar.'),
        ('Güvenli internet bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara kısa '
         'bilgilendirme çalışmalarıyla aktarılır. Güvenli parola, siber zorbalık '
         've bilgi doğrulama konularında hazırlanan afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 5 — ÇEVRE KORUMA KULÜBÜ
# ====================================================================
kulup(
    5, 'Çevre Koruma Kulübü', 'cevre', 'doga',
    kurulus_odak='Okulun ve yakın çevrenin çevre sorunları öğrencilerle '
                 'birlikte gözlemlenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin çevre duyarlılığı ve atık yönetimi konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Gözlem, geri dönüşüm, temizlik ve bilinçlendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Çevre kirliliğinin nedenlerini ve sonuçlarını tanımak.',
         'Hava, su, toprak ve gürültü kirliliğinin nedenleri ile canlılar '
         'üzerindeki etkileri ele alınır. Öğrenciler okul ve yakın çevrede '
         'gözlemledikleri kirlilik örneklerini not eder ve nedenleri üzerine '
         'değerlendirme yapar.'),
        ('Atıkları ayrıştırma ve geri dönüşüm alışkanlığı kazandırmak.',
         'Kâğıt, plastik, cam ve metal atıkların ayrıştırılması ile geri '
         'dönüşümün doğaya katkısı ele alınır. Sınıflarda atık ayrıştırma '
         'düzeninin nasıl kurulabileceği planlanır ve bilgilendirici etiketler '
         'hazırlanır.'),
        ('Su ve enerjiyi tutumlu kullanma bilinci geliştirmek.',
         'Suyun ve enerjinin okulda ve evde nerelerde boşa harcandığı gözlemlenir. '
         'Musluk, aydınlatma ve ısıtma kullanımında alınabilecek basit önlemler '
         'belirlenir. Öğrenciler hazırladıkları hatırlatma kartlarını uygun '
         'yerlere yerleştirir.'),
        ('Doğadaki canlıların yaşam alanlarını korumanın önemini kavramak.',
         'Bitki ve hayvanların yaşam alanlarının daralması, doğal dengenin '
         'bozulması ve bunun sonuçları ele alınır. Öğrenciler çevrede gözledikleri '
         'canlıları kaydeder ve yaşam alanlarını koruma yollarını araştırır.'),
        ('Ağaç ve yeşil alanların önemini kavramak.',
         'Ağaçların havayı temizlemesi, toprağı tutması ve iklime etkisi ele '
         'alınır. Okul bahçesinde veya çevrede bulunan ağaçlar gözlemlenir. '
         'İmkânlar ölçüsünde fidan dikimi veya bakım çalışması planlanır.'),
        ('Çevre temizliği çalışmasıyla sorumluluk bilinci geliştirmek.',
         'Okul bahçesi, sınıflar veya yakın çevrede güvenli koşullarda temizlik '
         've düzenleme çalışması yapılır. Çalışma öncesinde güvenlik kuralları '
         'hatırlatılır. Toplanan atıkların türlerine göre ayrıştırılması sağlanır.'),
        ('Çevre bilincini okul geneline ve ailelere yaymak.',
         'Geri dönüşüm, tasarruf ve doğa koruma konularında hazırlanan afiş ve '
         'bilgilendirme çalışmaları sınıflarla paylaşılır. Öğrenciler evde de '
         'uygulanabilecek çevre önerilerini ailelerine aktarır.'),
    ])

# ====================================================================
# 6 — ÇOCUK HAKLARI KULÜBÜ
# ====================================================================
kulup(
    6, 'Çocuk Hakları Kulübü', 'cocukhak', 'degerler',
    kurulus_odak='Öğrencilerin hak kavramına ilişkin bilgileri değerlendirilerek '
                 'yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin haklar, sorumluluklar ve eşitlik konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, hak arama ve akran paylaşımı çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Çocuk haklarının ne olduğunu ve neden gerekli olduğunu kavramak.',
         'Çocuk haklarının temel başlıkları yaşa uygun biçimde ele alınır. Yaşama, '
         'eğitim, sağlık, korunma ve oyun hakkı örneklerle açıklanır. Öğrenciler '
         'kendilerine tanınan hakları kendi cümleleriyle ifade eder.'),
        ('Hak ile sorumluluk arasındaki bağı kurmak.',
         'Her hakkın beraberinde bir sorumluluk getirdiği örneklerle işlenir. '
         'Sınıf içinde herkesin hakkını koruyan ortak kurallar üzerinde durulur. '
         'Öğrenciler hak ve sorumluluk eşleştirmesi içeren çalışma hazırlar.'),
        ('Eşitlik ve ayrımcılık kavramlarını fark etmek.',
         'Herkesin eşit haklara sahip olduğu, farklılıkların ayrım gerekçesi '
         'olamayacağı ele alınır. Dışlanma ve önyargının kişi üzerindeki etkisi '
         'örnek olaylarla tartışılır. Kapsayıcı davranış örnekleri belirlenir.'),
        ('Görüşünü ifade etme hakkını kullanmayı öğrenmek.',
         'Çocuğun kendisini ilgilendiren konularda görüş bildirme hakkı ele '
         'alınır. Görüş bildirirken saygılı dil kullanmanın önemi vurgulanır. '
         'Öğrenciler okul yaşamına ilişkin önerilerini yazılı olarak paylaşır.'),
        ('Korunma hakkını ve yardım isteme yollarını bilmek.',
         'Çocuğun her türlü kötü muameleden korunma hakkı ele alınır. Rahatsız '
         'edici bir durumla karşılaşıldığında güvenilen bir yetişkine başvurmanın '
         'önemi vurgulanır. Okulda ve dışarıda başvurulabilecek kişi ve kurumlar '
         'tanıtılır.'),
        ('Akranlar arasında saygılı iletişim kültürü geliştirmek.',
         'Akran ilişkilerinde saygı, dinleme ve anlaşmazlıkları sözle çözme '
         'üzerinde durulur. Zorbalığın hak ihlali olduğu vurgulanır. Öğrenciler '
         'sınıf içi iyi ilişkiler için ortak davranış ilkeleri belirler.'),
        ('Çocuk hakları bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara kısa '
         'bilgilendirme çalışmalarıyla aktarılır. Öğrenciler hakları anlatan afiş, '
         'şiir veya kısa metin çalışmalarını okul panosunda sergiler.'),
    ])

# ====================================================================
# 7 — DEĞERLER KULÜBÜ
# ====================================================================
kulup(
    7, 'Değerler Kulübü', 'degerler', 'degerler',
    kurulus_odak='Yıl içinde ele alınacak değerler öğrencilerin görüşü alınarak '
                 'aylara dağıtılır.',
    donem_odak='İşlenen değerlerin öğrenci davranışlarına yansıması '
               'değerlendirilir.',
    yil_odak='İşlenen değerler ve bunlara ilişkin çalışmalar değerlendirilir.',
    aylar=[
        ('Saygı değerini davranışa dönüştürmek.',
         'Saygının kişiye, emeğe, farklılığa ve ortak yaşam alanlarına yönelik '
         'boyutları ele alınır. Saygılı ve saygısız davranış örnekleri '
         'karşılaştırılır. Öğrenciler günlük hayattan saygı örnekleri toplayarak '
         'paylaşır.'),
        ('Sorumluluk değerini kavramak ve uygulamak.',
         'Kişinin kendine, ailesine, okuluna ve çevresine karşı sorumlulukları '
         'ele alınır. Üstlenilen bir işi zamanında ve özenle yapmanın önemi '
         'vurgulanır. Öğrenciler kendilerine bir sorumluluk belirleyip süreci '
         'takip eder.'),
        ('Dürüstlük değerini örneklerle işlemek.',
         'Doğru sözlü olmanın güven ilişkisindeki yeri ele alınır. Hata yapıldığında '
         'bunu kabul etmenin erdemi üzerinde durulur. Öğrenciler dürüstlük konulu '
         'kısa metin veya afiş çalışması hazırlar.'),
        ('Yardımlaşma ve dayanışma değerini yaşatmak.',
         'İhtiyaç sahibine el uzatmanın ve birlikte iş başarmanın önemi ele '
         'alınır. Okul içinde akranlara destek olmanın yolları belirlenir. '
         'Öğrenciler sınıf içinde uygulanabilir bir yardımlaşma önerisi geliştirir.'),
        ('Sabır ve kararlılık değerlerini kavramak.',
         'Bir hedefe ulaşmak için zaman ve emek gerektiği, güçlükler karşısında '
         'vazgeçmemenin önemi ele alınır. Öğrenciler zorlandıkları bir konuda '
         'kendilerine küçük bir hedef belirleyerek ilerlemelerini not eder.'),
        ('Vatanseverlik ve millî değerleri kavramak.',
         'Vatana ve millî değerlere bağlılığın günlük hayattaki karşılıkları ele '
         'alınır. Ortak yaşam alanlarını korumanın, kurallara uymanın ve topluma '
         'katkı sunmanın bu değerin parçası olduğu vurgulanır.'),
        ('İşlenen değerleri okul geneline yansıtmak.',
         'Yıl içinde ele alınan değerlerden seçilenler afiş, pano ve kısa '
         'bilgilendirme çalışmalarıyla okul geneline aktarılır. Öğrenciler '
         'değerleri anlatan çalışmalarını akranlarıyla paylaşır.'),
    ])

# ====================================================================
# 8 — DEMOKRASİ, İNSAN HAKLARI VE YURTTAŞLIK KULÜBÜ
# ====================================================================
kulup(
    8, 'Demokrasi, İnsan Hakları ve Yurttaşlık Kulübü', 'demokrasi', 'degerler',
    kurulus_odak='Öğrencilerin demokrasi ve yurttaşlık kavramlarına ilişkin '
                 'bilgileri değerlendirilerek yıl içinde işlenecek konular seçilir.',
    donem_odak='Öğrencilerin katılım, hak ve sorumluluk konularındaki kazanımları '
               'gözden geçirilir.',
    yil_odak='Tartışma, seçim uygulaması ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Demokrasinin temel ilkelerini kavramak.',
         'Demokrasinin ne anlama geldiği, çoğunluğun kararı ile azınlığın hakkının '
         'birlikte gözetilmesi ve ortak kararların nasıl alındığı ele alınır. '
         'Sınıf içinde ortak bir konuda karar alma uygulaması yapılır.'),
        ('Seçme ve seçilme sürecini uygulayarak öğrenmek.',
         'Aday olma, tanıtım yapma, oy verme ve sonucu kabul etme aşamaları '
         'üzerinde durulur. Kulüp temsilcisi veya sınıf başkanı seçimi bu '
         'aşamalara uyularak yürütülür. Seçim sonucuna saygının önemi vurgulanır.'),
        ('İnsan haklarının evrenselliğini kavramak.',
         'İnsan haklarının herkes için geçerli olduğu, doğuştan kazanıldığı ve '
         'devredilemeyeceği ele alınır. Hak ihlallerinin toplumda yol açtığı '
         'sonuçlar örneklerle tartışılır. Öğrenciler temel hakları anlatan '
         'çalışma hazırlar.'),
        ('Farklı görüşleri dinleme ve tartışma kültürü geliştirmek.',
         'Kendisiyle aynı düşünmeyen kişiyi dinlemenin, karşı görüşü anlamaya '
         'çalışmanın ve tartışmayı kişiselleştirmemenin önemi ele alınır. '
         'Öğrenciler belirlenen bir konuda kurallara uygun tartışma yürütür.'),
        ('Yurttaşlık sorumluluklarını günlük hayatla ilişkilendirmek.',
         'Kurallara uyma, ortak alanları koruma, vergisini bilen ve çevresine '
         'duyarlı yurttaş olma gibi sorumluluklar ele alınır. Öğrenciler okul '
         'yaşamında yurttaşlık sorumluluğunun karşılıklarını belirler.'),
        ('Kamu hizmeti sunan kurumları tanımak.',
         'Belediye, muhtarlık, emniyet, sağlık ve eğitim kurumlarının görevleri '
         'ele alınır. Yurttaşın bu kurumlara nasıl başvurabileceği üzerinde '
         'durulur. Öğrenciler bir kurumun görevlerini araştırarak tanıtır.'),
        ('Demokrasi bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara kısa '
         'bilgilendirme çalışmalarıyla aktarılır. Demokrasi, hak ve sorumluluk '
         'konulu afiş çalışmaları okul panosunda sergilenir.'),
    ])

# ====================================================================
# 9 — DENİZCİLİK KULÜBÜ
# ====================================================================
kulup(
    9, 'Denizcilik Kulübü', 'denizcilik', 'doga',
    kurulus_odak='Öğrencilerin denizler ve sular hakkındaki bilgileri '
                 'değerlendirilerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin deniz kültürü ve su güvenliği konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Araştırma, tanıtım ve farkındalık çalışmaları değerlendirilir.',
    aylar=[
        ('Türkiye’nin denizlerini ve kıyılarını tanımak.',
         'Ülkemizi çevreleyen denizler, önemli kıyı bölgeleri ve bunların '
         'ülkeye kattığı değer harita üzerinde incelenir. Öğrenciler seçtikleri '
         'bir denizi veya kıyı bölgesini araştırarak tanıtır.'),
        ('Deniz canlılarını ve deniz ekosistemini tanımak.',
         'Denizlerde yaşayan canlı çeşitliliği, besin zinciri ve ekosistemin '
         'dengesi ele alınır. Nesli tehlike altındaki deniz canlıları araştırılır. '
         'Öğrenciler deniz canlılarını tanıtan pano çalışması hazırlar.'),
        ('Denizlerin kirlenmesine karşı duyarlılık geliştirmek.',
         'Deniz kirliliğinin nedenleri, plastik atıkların denizlere ulaşma yolları '
         've canlılar üzerindeki etkisi ele alınır. Öğrenciler kirliliği azaltmak '
         'için günlük hayatta yapılabilecekleri belirler.'),
        ('Denizciliğin ülke ekonomisindeki yerini kavramak.',
         'Deniz taşımacılığı, balıkçılık, liman işletmeciliği ve turizmin ülke '
         'ekonomisine katkısı ele alınır. Denizcilikle ilgili meslekler tanıtılır. '
         'Öğrenciler ilgi duydukları bir mesleği araştırarak sunar.'),
        ('Su güvenliği ve yüzme bilincinin önemini kavramak.',
         'Suda güvenlik kuralları, tehlikeli alanlardan uzak durma ve boğulma '
         'riskine karşı alınacak önlemler ele alınır. Yüzme bilmenin bir yaşam '
         'becerisi olduğu vurgulanır. Güvenlik kuralları listesi hazırlanır.'),
        ('Denizcilik tarihimizi ve denizcilerimizi tanımak.',
         'Türk denizcilik tarihinde iz bırakmış kişiler ve olaylar araştırılır. '
         'Denizcilikle ilgili terimler ve gelenekler ele alınır. Öğrenciler '
         'araştırmalarını kısa metin veya pano çalışmasıyla paylaşır.'),
        ('Deniz sevgisini ve koruma bilincini okul geneline yaymak.',
         'Yıl içinde yapılan çalışmalardan seçilenler diğer sınıflara aktarılır. '
         'Deniz canlıları, kirlilik ve su güvenliği konulu çalışmalar okul '
         'panosunda sergilenir.'),
    ])

# ====================================================================
# 10 — ENERJİ VERİMLİLİĞİ KULÜBÜ
# ====================================================================
kulup(
    10, 'Enerji Verimliliği Kulübü', 'enerji', 'doga',
    kurulus_odak='Okulda enerjinin kullanıldığı alanlar öğrencilerle birlikte '
                 'gözlemlenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin enerji tasarrufu ve verimlilik konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Gözlem, ölçüm, tasarruf ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Enerjinin nereden geldiğini ve nasıl kullanıldığını kavramak.',
         'Enerji kaynakları, elektriğin üretim ve dağıtım süreci ile günlük '
         'hayatta enerjinin kullanıldığı alanlar ele alınır. Öğrenciler evde ve '
         'okulda enerji tüketen araçları listeler.'),
        ('Enerji israfını fark etmek ve azaltmak.',
         'Boş sınıfta açık kalan lamba, açık unutulan cihazlar ve ısı kaybı gibi '
         'israf örnekleri gözlemlenir. Öğrenciler okulda tasarruf sağlayacak '
         'basit önlemleri belirler ve hatırlatma kartları hazırlar.'),
        ('Isıtma ve yalıtımın enerji tüketimine etkisini kavramak.',
         'Isının nasıl kaybolduğu, pencere ve kapı kaynaklı kayıplar ile yalıtımın '
         'sağladığı fayda ele alınır. Öğrenciler sınıfta ısı kaybı olabilecek '
         'yerleri gözlemleyerek öneri geliştirir.'),
        ('Yenilenebilir enerji kaynaklarını tanımak.',
         'Güneş, rüzgâr, su ve jeotermal enerjinin nasıl kullanıldığı ile '
         'yenilenebilir kaynakların çevreye katkısı ele alınır. Öğrenciler '
         'seçtikleri bir kaynağı araştırarak tanıtır.'),
        ('Aydınlatmada verimli kullanım alışkanlığı kazandırmak.',
         'Gün ışığından yararlanma, gereksiz aydınlatmayı kapatma ve verimli '
         'ampul kullanımı ele alınır. Öğrenciler bir hafta boyunca sınıfta '
         'aydınlatma kullanımını gözlemleyerek sonuçlarını paylaşır.'),
        ('Ulaşımda enerji tüketimini fark etmek.',
         'Toplu taşıma, yürüyüş ve bisiklet kullanımının enerji tüketimi ve hava '
         'kirliliği üzerindeki etkisi ele alınır. Öğrenciler okula geliş '
         'biçimlerini değerlendirerek öneriler geliştirir.'),
        ('Enerji verimliliği bilincini okul geneline ve ailelere yaymak.',
         'Yıl içinde belirlenen tasarruf önerileri sınıflara aktarılır. '
         'Öğrenciler evde uygulanabilecek enerji tasarrufu önerilerini '
         'ailelerine iletir. Bilgilendirici afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 11 — ENGELLİLERLE DAYANIŞMA KULÜBÜ
# ====================================================================
kulup(
    11, 'Engellilerle Dayanışma Kulübü', 'engelli', 'toplum',
    kurulus_odak='Öğrencilerin engellilik konusundaki bilgi ve yaklaşımları '
                 'değerlendirilerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin farkındalık ve kapsayıcı davranış konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, erişilebilirlik ve dayanışma çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Engellilik kavramını doğru anlamak.',
         'Engellilik türleri, engelli bireylerin karşılaştığı güçlükler ve '
         'toplumun bakış açısının etkisi ele alınır. Acıma değil eşitlik '
         'temelinde yaklaşmanın önemi vurgulanır. Doğru ve yanlış ifadeler '
         'karşılaştırılır.'),
        ('Erişilebilirliğin ne olduğunu kavramak.',
         'Rampa, asansör, sesli uyarı ve hissedilebilir yüzey gibi düzenlemelerin '
         'işlevi ele alınır. Öğrenciler okul ve yakın çevrede erişilebilirlik '
         'durumunu gözlemleyerek eksikleri not eder.'),
        ('Görme ve işitme engelli bireylerin iletişim yollarını tanımak.',
         'Braille alfabesi ve işaret dili tanıtılır. İletişim kurarken dikkat '
         'edilecek davranışlar ele alınır. Öğrenciler öğrendikleri birkaç işareti '
         'veya braille harfini paylaşır.'),
        ('Kapsayıcı oyun ve etkinlik kurmayı öğrenmek.',
         'Herkesin katılabileceği oyunların nasıl kurulacağı ele alınır. Bir '
         'oyunun kurallarını herkesin katılımına açacak biçimde uyarlama '
         'çalışması yapılır. Dışlayıcı davranışların etkisi tartışılır.'),
        ('Engelli bireylerin başarı örneklerini tanımak.',
         'Sanat, spor, bilim ve iş hayatında başarılı olmuş engelli bireyler '
         'araştırılır. Fırsat eşitliğinin başarıdaki rolü vurgulanır. Öğrenciler '
         'seçtikleri kişiyi tanıtan çalışma hazırlar.'),
        ('Okul içinde dayanışma davranışı geliştirmek.',
         'Akranlara destek olmanın, yardımı dayatmadan önce sormanın ve '
         'kapsayıcı davranmanın önemi ele alınır. Öğrenciler okulda uygulanabilir '
         'dayanışma önerileri belirler.'),
        ('Farkındalığı okul geneline yaymak.',
         'Yıl içinde yapılan çalışmalardan seçilenler diğer sınıflara aktarılır. '
         'Erişilebilirlik ve kapsayıcı davranış konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 12 — eTWINNING KULÜBÜ
# ====================================================================
kulup(
    12, 'eTwinning Kulübü', 'etwinning', 'bilim',
    kurulus_odak='Kulübün proje tabanlı çalışma biçimi tanıtılarak yıl içinde '
                 'yürütülecek çalışma konuları belirlenir.',
    donem_odak='Öğrencilerin iş birliği, planlama ve paylaşım konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Proje planlama, ürün geliştirme ve tanıtım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Proje tabanlı çalışmanın basamaklarını öğrenmek.',
         'Bir projenin konu belirleme, planlama, görev paylaşımı, uygulama ve '
         'değerlendirme basamakları ele alınır. Öğrenciler örnek bir proje '
         'taslağı üzerinde bu basamakları uygular.'),
        ('Takım hâlinde çalışma becerisi geliştirmek.',
         'Görev paylaşımı, sorumluluk alma ve ortak karar verme üzerinde durulur. '
         'Öğrenciler küçük gruplara ayrılarak ortak bir ürün ortaya koyar. Grup '
         'içi iletişimde saygılı dil vurgulanır.'),
        ('Farklı kültürleri tanımaya istekli olmak.',
         'Başka ülkelerdeki okul yaşamı, gelenekler ve günlük alışkanlıklar '
         'araştırılır. Benzerlik ve farklılıklar karşılaştırılır. Öğrenciler '
         'kendi kültürlerini tanıtan kısa bir sunum hazırlar.'),
        ('Ortak ürün ortaya koymayı deneyimlemek.',
         'Seçilen konuda afiş, kitapçık, sergi veya sunum gibi bir ortak ürün '
         'hazırlanır. Ürünün her aşamasında tüm üyelerin katkısı gözetilir. '
         'Okulun imkânları ölçüsünde dijital veya basılı biçim seçilir.'),
        ('Çalışmayı belgelemeyi ve paylaşmayı öğrenmek.',
         'Yapılan çalışmanın kaydedilmesi, fotoğraf ve yazıyla belgelenmesi ele '
         'alınır. Paylaşım yapılırken izin ve mahremiyet kurallarına uyulması '
         'gerektiği vurgulanır.'),
        ('Emek ve katkıyı değerlendirmeyi öğrenmek.',
         'Grup çalışmasında herkesin katkısının görülmesi, öz değerlendirme ve '
         'akran değerlendirmesi ele alınır. Öğrenciler süreçte neyi iyi yaptığını '
         've neyi geliştirebileceğini yazar.'),
        ('Yürütülen çalışmaları okul geneline tanıtmak.',
         'Yıl içinde ortaya konan ürünler sınıf veya okul düzeyinde tanıtılır. '
         'Öğrenciler çalışmalarını akranlarına anlatarak sunum becerisi kazanır.'),
    ])

# ====================================================================
# 13 — FELSEFE VEYA DÜŞÜNCE EĞİTİMİ KULÜBÜ
# ====================================================================
kulup(
    13, 'Felsefe veya Düşünce Eğitimi Kulübü', 'felsefe', 'kultur',
    kurulus_odak='Öğrencilerin merak ettiği sorular derlenerek yıl içinde '
                 'ele alınacak başlıklar belirlenir.',
    donem_odak='Öğrencilerin soru sorma, gerekçelendirme ve dinleme '
               'becerilerindeki gelişim gözden geçirilir.',
    yil_odak='Tartışma, sorgulama ve yazma çalışmaları değerlendirilir.',
    aylar=[
        ('Soru sormayı ve merak etmeyi değerli görmek.',
         'İyi bir sorunun özellikleri, cevabı hemen bulunamayan soruların değeri '
         've merakın öğrenmedeki yeri ele alınır. Öğrenciler merak ettikleri '
         'soruları yazarak ortak bir soru panosu oluşturur.'),
        ('Düşüncesini gerekçelendirmeyi öğrenmek.',
         'Bir görüşü savunurken gerekçe göstermenin önemi ele alınır. Gerekçesiz '
         'iddia ile gerekçeli düşünce karşılaştırılır. Öğrenciler seçtikleri bir '
         'konuda görüşünü gerekçesiyle yazar.'),
        ('Farklı görüşleri dinleme alışkanlığı kazanmak.',
         'Karşı görüşü anlamaya çalışmanın, sözünü kesmemenin ve fikri kişiden '
         'ayırmanın önemi ele alınır. Belirlenen bir konu kurallara uygun biçimde '
         'tartışılır.'),
        ('Doğru ve yanlış üzerine düşünmeyi denemek.',
         'Günlük hayattan seçilen ikilem durumları üzerinde düşünülür. Bir '
         'davranışın neden doğru veya yanlış sayıldığı gerekçeleriyle tartışılır. '
         'Farklı sonuçlara varılabileceği kabul edilir.'),
        ('Kavramları tanımlamayı denemek.',
         'Dostluk, adalet, özgürlük gibi kavramlardan biri seçilerek tanımlanmaya '
         'çalışılır. Tanımın sınırları ve örnekler üzerinde durulur. Öğrenciler '
         'kendi tanımlarını yazarak karşılaştırır.'),
        ('Düşünürleri ve düşünce geleneklerini tanımak.',
         'Farklı dönem ve kültürlerden düşünürler ile ele aldıkları sorular '
         'araştırılır. Öğrenciler seçtikleri bir düşünürü ve sorusunu tanıtan '
         'kısa çalışma hazırlar.'),
        ('Düşünme kültürünü okul geneline yaymak.',
         'Yıl içinde tartışılan sorulardan seçilenler pano veya kısa metinlerle '
         'paylaşılır. Öğrenciler akranlarını da düşünmeye çağıran soru kartları '
         'hazırlar.'),
    ])

# ====================================================================
# 14 — FOTOĞRAFÇILIK KULÜBÜ
# ====================================================================
kulup(
    14, 'Fotoğrafçılık Kulübü', 'fotograf', 'sanat',
    kurulus_odak='Öğrencilerin kullanabileceği fotoğraf makinesi veya telefon '
                 'imkânı değerlendirilerek yıl içinde yapılacak çalışmalar '
                 'planlanır.',
    donem_odak='Öğrencilerin çerçeveleme, ışık ve konu seçimi konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Çekim, seçme, sergileme ve etik kullanım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Fotoğrafta konu ve çerçeve seçmeyi öğrenmek.',
         'Bir kareye neyin girip neyin çıkacağına karar verme, konuyu ortaya '
         'çıkarma ve gereksiz ayrıntıdan kaçınma ele alınır. Öğrenciler kâğıttan '
         'çerçeveyle görüntü seçme çalışması yapar; makine gerekmez.'),
        ('Işığın fotoğraftaki etkisini fark etmek.',
         'Gün ışığının yönü, gölge ve aydınlık farkı ile aynı konunun farklı '
         'ışıkta nasıl göründüğü ele alınır. Öğrenciler günün farklı saatlerinde '
         'aynı yeri gözlemleyerek farkı not eder.'),
        ('Fotoğrafla anlatım kurmayı denemek.',
         'Bir fotoğrafın ne anlattığı, izleyende ne uyandırdığı üzerinde durulur. '
         'Seçilen bir tema doğrultusunda çekim yapılır veya çekim imkânı yoksa '
         'çizimle karşılığı oluşturulur.'),
        ('Fotoğrafta izin ve mahremiyete uymayı öğrenmek.',
         'Kişilerin izni olmadan fotoğrafının çekilmemesi ve paylaşılmaması ele '
         'alınır. Mahremiyetin önemi ve paylaşımın sonuçları vurgulanır. Kulüp '
         'için uyulacak çekim ilkeleri yazılır.'),
        ('Doğa ve çevre fotoğrafçılığını denemek.',
         'Okul bahçesi ve yakın çevrede doğa, mevsim ve gündelik yaşam konulu '
         'çekimler yapılır. Konuya yaklaşma, sabırla bekleme ve doğaya zarar '
         'vermeme üzerinde durulur.'),
        ('Fotoğraf seçmeyi ve düzenlemeyi öğrenmek.',
         'Çok sayıda kare arasından seçim yapma ölçütleri ele alınır. Öğrenciler '
         'kendi çalışmalarından bir seçki oluşturur ve seçim gerekçesini anlatır.'),
        ('Yıl içinde üretilen çalışmaları sergilemek.',
         'Seçilen fotoğraf veya çalışmalar okul panosunda ya da sınıf içinde '
         'sergilenir. Sergilenen her çalışmanın yanına kısa açıklama yazılır. '
         'İzin alınmayan görseller sergilenmez.'),
    ])

# ====================================================================
# 15 — GELENEKSEL SANATLAR KULÜBÜ
# ====================================================================
kulup(
    15, 'Geleneksel Sanatlar Kulübü', 'gelenekselsanat', 'sanat',
    kurulus_odak='Yörede yaşayan geleneksel sanatlar öğrencilerle birlikte '
                 'belirlenerek yıl içinde ele alınacak dallar seçilir.',
    donem_odak='Öğrencilerin geleneksel sanatları tanıma ve uygulama '
               'konusundaki kazanımları gözden geçirilir.',
    yil_odak='Tanıtım, uygulama ve sergileme çalışmaları değerlendirilir.',
    aylar=[
        ('Geleneksel sanatların ne olduğunu ve neden korunduğunu kavramak.',
         'Hat, tezhip, ebru, çini, halı-kilim dokuma, ahşap ve bakır işçiliği gibi '
         'dallar tanıtılır. Bu sanatların kuşaktan kuşağa nasıl aktarıldığı ele '
         'alınır. Öğrenciler ilgi duydukları bir dalı araştırarak tanıtır.'),
        ('Yörenin kendine özgü el sanatlarını tanımak.',
         'Bulunulan yörede yaşatılan el sanatları ve bunları sürdüren ustalar '
         'araştırılır. Yörenin sanatını diğer bölgelerden ayıran özellikler ele '
         'alınır. Elde edilen bilgiler pano çalışmasıyla paylaşılır.'),
        ('Desen ve motiflerin anlamını fark etmek.',
         'Geleneksel motiflerin hangi anlamları taşıdığı, renk ve biçim '
         'tercihlerinin neye dayandığı ele alınır. Öğrenciler basit araçlarla '
         'motif çizimi çalışması yapar; boya ve kâğıt dışında malzeme gerekmez.'),
        ('El becerisi gerektiren bir uygulamayı denemek.',
         'Okulun imkânları ölçüsünde kâğıt katlama, basit dokuma, kalıp baskı '
         'veya çizim gibi güvenli bir uygulama seçilir. Kesici ve ısıtıcı araç '
         'gerektiren teknikler tercih edilmez. Sabır ve özenin önemi vurgulanır.'),
        ('Ustalık ve çıraklık geleneğini kavramak.',
         'Bir sanatın ustadan öğrenilme süreci, emek ve zaman gerektirdiği ele '
         'alınır. Meslek olarak geleneksel sanatlar tanıtılır. Öğrenciler '
         'araştırdıkları bir ustanın çalışma biçimini anlatır.'),
        ('Geleneksel sanatları bugünle ilişkilendirmek.',
         'Geleneksel motiflerin günümüz tasarımlarında nasıl kullanıldığı '
         'örneklerle incelenir. Öğrenciler bir motifi kendi çalışmalarında '
         'yeniden yorumlayarak uygular.'),
        ('Yıl içinde üretilen çalışmaları sergilemek.',
         'Yapılan çizim, desen ve uygulama çalışmalarından seçilenler sınıf '
         'içinde veya okul panosunda sergilenir. Her çalışmanın yanına hangi '
         'geleneksel sanattan esinlenildiği yazılır.'),
    ])

# ====================================================================
# 16 — GEZİ, TANITMA VE TURİZM KULÜBÜ
# ====================================================================
kulup(
    16, 'Gezi, Tanıtma ve Turizm Kulübü', 'gezi', 'kultur',
    kurulus_odak='Yörenin gezilebilecek değerleri öğrencilerle birlikte '
                 'listelenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin çevreyi tanıma ve tanıtma konusundaki kazanımları '
               'gözden geçirilir.',
    yil_odak='Araştırma, tanıtım ve gezi hazırlığı çalışmaları değerlendirilir.',
    aylar=[
        ('Yörenin tarihî ve doğal değerlerini tanımak.',
         'Bulunulan yörede bulunan tarihî yapılar, doğal güzellikler ve kültürel '
         'değerler araştırılır. Öğrenciler seçtikleri bir değeri kaynaklarıyla '
         'birlikte tanıtan çalışma hazırlar.'),
        ('Turizmin ülke ve yöre için önemini kavramak.',
         'Turizmin ekonomiye katkısı, tanıtımın rolü ve turizmle ilgili meslekler '
         'ele alınır. Ziyaretçiye karşı nazik ve yardımcı olmanın önemi '
         'vurgulanır.'),
        ('Gezi öncesi hazırlığın nasıl yapıldığını öğrenmek.',
         'Bir gezinin amacı, güzergâhı, süresi ve güvenlik önlemleri ele alınır. '
         'Veli izin belgesinin ve görevlendirmenin zorunlu olduğu vurgulanır. '
         'Öğrenciler örnek bir gezi taslağı hazırlar. Gezi, okulun imkânları ve '
         'gerekli izinler tamamlanırsa düzenlenebilir.'),
        ('Gezi sırasında uyulacak kuralları kavramak.',
         'Gruptan ayrılmama, ziyaret edilen yere zarar vermeme, çevreyi kirletmeme '
         've görevlilerin uyarılarına uyma gibi kurallar ele alınır. Öğrenciler '
         'gezi kuralları listesi hazırlar.'),
        ('Kültürel mirası koruma bilinci geliştirmek.',
         'Tarihî eserlerin neden korunması gerektiği, zarar veren davranışlar ve '
         'koruma yolları ele alınır. Öğrenciler koruma çağrısı içeren afiş '
         'hazırlar.'),
        ('Yöreyi tanıtan bir çalışma ortaya koymak.',
         'Yörenin değerlerini anlatan broşür, pano veya sunum hazırlanır. '
         'Tanıtımda doğru bilgi kullanmanın önemi vurgulanır. Çalışma okulun '
         'imkânlarına göre basılı veya el yapımı olur.'),
        ('Yapılan tanıtım çalışmalarını okul geneline ulaştırmak.',
         'Yıl içinde hazırlanan tanıtım çalışmaları diğer sınıflarla paylaşılır. '
         'Öğrenciler yörelerini akranlarına anlatarak sunum becerisi kazanır.'),
    ])

# ====================================================================
# 17 — GİRİŞİMCİLİK KULÜBÜ
# ====================================================================
kulup(
    17, 'Girişimcilik Kulübü', 'girisimcilik', 'toplum',
    kurulus_odak='Öğrencilerin ilgi duyduğu üretim ve hizmet alanları '
                 'belirlenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin fikir geliştirme, planlama ve iş birliği '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Fikir geliştirme, planlama ve tanıtım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Girişimciliğin ne olduğunu kavramak.',
         'Girişimciliğin bir ihtiyacı fark edip çözüm üretmek olduğu ele alınır. '
         'Girişimcinin sahip olması gereken merak, cesaret ve sorumluluk gibi '
         'özellikler tartışılır. Öğrenciler çevrelerinde gördükleri bir ihtiyacı '
         'not eder.'),
        ('Fikir üretme ve fikri geliştirme becerisi kazanmak.',
         'Bir soruna çok sayıda çözüm üretmenin yolları ele alınır. Fikirlerin '
         'eleştirilmeden önce toplanması gerektiği vurgulanır. Öğrenciler '
         'gruplar hâlinde fikir listesi çıkarır ve içinden birini seçer.'),
        ('Basit bir plan hazırlamayı öğrenmek.',
         'Bir fikrin hayata geçmesi için gereken adımlar, zaman, malzeme ve görev '
         'paylaşımı ele alınır. Öğrenciler seçtikleri fikir için basit bir plan '
         'taslağı hazırlar.'),
        ('Gelir ve giderin ne olduğunu kavramak.',
         'Bir işin maliyeti, geliri ve bunlar arasındaki ilişki yaşa uygun '
         'biçimde ele alınır. Öğrenciler örnek bir çalışma için basit gelir-gider '
         'tablosu hazırlar. Gerçek para toplanmaz, çalışma tasarım düzeyinde '
         'kalır.'),
        ('Takım hâlinde iş yürütmeyi deneyimlemek.',
         'Görev paylaşımı, sorumluluk alma ve anlaşmazlıkları çözme üzerinde '
         'durulur. Öğrenciler gruplar hâlinde belirledikleri fikri geliştirmeyi '
         'sürdürür ve süreçteki güçlükleri paylaşır.'),
        ('Fikri anlatma ve tanıtma becerisi kazanmak.',
         'Bir fikrin kısa ve anlaşılır biçimde nasıl anlatılacağı ele alınır. '
         'Öğrenciler fikirlerini akranlarına sunar ve gelen soruları yanıtlar. '
         'Yapıcı geri bildirim vermenin önemi vurgulanır.'),
        ('Geliştirilen fikirleri okul geneline tanıtmak.',
         'Yıl içinde geliştirilen fikirlerden seçilenler pano veya sunum yoluyla '
         'okul geneline tanıtılır. Öğrenciler süreçte neyi öğrendiklerini '
         'değerlendirir.'),
    ])

# ====================================================================
# 18 — GÖRSEL SANATLAR KULÜBÜ
# ====================================================================
kulup(
    18, 'Görsel Sanatlar Kulübü', 'gorselsanat', 'sanat',
    kurulus_odak='Öğrencilerin ilgi duyduğu sanat dalları ve okulun malzeme '
                 'imkânı değerlendirilerek yıl içinde yapılacak çalışmalar '
                 'planlanır.',
    donem_odak='Öğrencilerin çizim, renk ve kompozisyon konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Üretim, sergileme ve sanat okuma çalışmaları değerlendirilir.',
    aylar=[
        ('Çizginin ve biçimin anlatım gücünü fark etmek.',
         'Çizgi türleri, biçim ve oran üzerinde durulur. Öğrenciler kalem ve '
         'kâğıtla gözlem çizimi çalışması yapar. Çizimde acele etmemenin ve '
         'gözlemin önemi vurgulanır.'),
        ('Renkleri tanımak ve renklerle anlatım kurmak.',
         'Ana ve ara renkler, sıcak-soğuk renkler ile rengin duygu üzerindeki '
         'etkisi ele alınır. Öğrenciler renk karışımı denemeleri yapar. Boya '
         'imkânı sınırlıysa kuru boya veya renkli kâğıtla çalışılır.'),
        ('Kompozisyon kurmayı öğrenmek.',
         'Bir yüzeyde ögelerin nasıl yerleştirileceği, denge ve boşluk kullanımı '
         'ele alınır. Öğrenciler belirlenen bir konuda kompozisyon çalışması '
         'yapar.'),
        ('Farklı malzeme ve tekniklerle üretim denemek.',
         'Kolaj, baskı, karışık teknik veya artık malzemeyle üç boyutlu çalışma '
         'gibi seçeneklerden okulun imkânına uyanı seçilir. Malzeme toplanırken '
         'geri dönüşüme uygun olanlar tercih edilir.'),
        ('Sanat eserlerini okumayı ve yorumlamayı öğrenmek.',
         'Bir eserin konusu, rengi, biçimi ve izleyende uyandırdığı duygu '
         'üzerinde konuşulur. Farklı yorumların doğru olabileceği vurgulanır. '
         'Öğrenciler seçtikleri bir eseri kendi cümleleriyle anlatır.'),
        ('Sanatçıları ve sanat akımlarını tanımak.',
         'Farklı dönem ve kültürlerden sanatçılar araştırılır. Sanatçının '
         'yaşadığı dönemin eserine etkisi ele alınır. Öğrenciler seçtikleri '
         'sanatçıyı tanıtan çalışma hazırlar.'),
        ('Yıl içinde üretilen çalışmaları sergilemek.',
         'Seçilen çalışmalar sınıf içinde veya okul panosunda sergilenir. Her '
         'çalışmanın yanına öğrencinin kısa açıklaması eklenir. Sergilemede '
         'bütün üyelerin çalışmasına yer verilmesine özen gösterilir.'),
    ])

# ====================================================================
# 19 — HALK OYUNLARI KULÜBÜ
# ====================================================================
kulup(
    19, 'Halk Oyunları Kulübü', 'halkoyun', 'sanat',
    kurulus_odak='Çalışma yapılabilecek uygun alan ve süre belirlenerek yıl '
                 'içinde öğrenilecek oyunlar seçilir.',
    donem_odak='Öğrencilerin ritim, uyum ve grup çalışması konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Öğrenilen oyunlar ve gösteri çalışmaları değerlendirilir.',
    aylar=[
        ('Halk oyunlarının kültürel değerini kavramak.',
         'Halk oyunlarının hangi ihtiyaçtan doğduğu, yörelere göre nasıl '
         'farklılaştığı ve kuşaktan kuşağa nasıl aktarıldığı ele alınır. '
         'Öğrenciler yörelerinin oyunlarını araştırır.'),
        ('Ritim duygusu ve temel adımları kazanmak.',
         'Ritmi sayarak izleme, müzikle uyum ve temel adım kalıpları çalışılır. '
         'Isınma hareketlerinin sakatlanmayı önlemedeki önemi vurgulanır. '
         'Çalışma sınıfta veya uygun bir alanda yapılır.'),
        ('Bir yöre oyununu öğrenmeye başlamak.',
         'Seçilen bir yörenin oyunu adım adım çalışılır. Oyunun anlatmak '
         'istediği hikâye ve yöresel özellikleri ele alınır. Herkesin kendi '
         'hızında ilerlemesine imkân tanınır.'),
        ('Grup uyumu ve birlikte hareket becerisi geliştirmek.',
         'Sıra düzeni, birlikte başlama ve bitirme ile arkadaşını bekleme '
         'üzerinde durulur. Grup çalışmasında sabrın ve dayanışmanın önemi '
         'vurgulanır.'),
        ('Yöresel kıyafet ve müzikleri tanımak.',
         'Yörelere ait kıyafetlerin özellikleri ve oyunlara eşlik eden çalgılar '
         'araştırılır. Kıyafet temini zorunlu değildir; tanıtım görsel ve '
         'anlatım yoluyla yapılır.'),
        ('Öğrenilen oyunu bütünüyle uygulamak.',
         'Yıl içinde çalışılan oyun baştan sona uygulanır. Eksik kalan bölümler '
         'tekrar edilir. Öğrenciler birbirine geri bildirim vererek çalışmayı '
         'geliştirir.'),
        ('Çalışmayı okul geneline gösterebilmek.',
         'Okulun imkânları ölçüsünde sınıf içinde veya okul programında kısa bir '
         'gösteri yapılır. Gösteri şartı aranmaz; süreç boyunca kazanılan uyum '
         've kültürel bilgi esas alınır.'),
    ])

# ====================================================================
# 20 — HAVACILIK KULÜBÜ
# ====================================================================
kulup(
    20, 'Havacılık Kulübü', 'havacilik', 'bilim',
    kurulus_odak='Öğrencilerin havacılığa ilişkin merak ettiği konular '
                 'derlenerek yıl içinde ele alınacak başlıklar seçilir.',
    donem_odak='Öğrencilerin uçuş, gökyüzü ve havacılık tarihi konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Araştırma, model çalışması ve tanıtım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Uçmanın nasıl mümkün olduğunu kavramak.',
         'Havanın kaldırma kuvveti, kanat biçiminin işlevi ve dengenin önemi '
         'yaşa uygun biçimde ele alınır. Öğrenciler kâğıttan model uçak yaparak '
         'kanat biçiminin uçuşa etkisini gözlemler.'),
        ('Havacılık tarihini ve öncülerini tanımak.',
         'Uçma denemelerinin tarihi, ilk uçuşlar ve Türk havacılık tarihinde iz '
         'bırakmış kişiler araştırılır. Öğrenciler seçtikleri bir kişiyi veya '
         'olayı tanıtan çalışma hazırlar.'),
        ('Hava araçlarını ve kullanım alanlarını tanımak.',
         'Yolcu uçağı, helikopter, planör, balon ve insansız hava araçlarının '
         'kullanım alanları ele alınır. Öğrenciler ilgi duydukları aracı '
         'araştırarak tanıtır.'),
        ('Havacılıkla ilgili meslekleri tanımak.',
         'Pilotluk, hava trafik kontrolü, uçak bakım teknisyenliği ve kabin '
         'görevliliği gibi meslekler ile gerektirdiği eğitim ele alınır. '
         'Öğrenciler bir mesleği araştırarak sunar.'),
        ('Gökyüzünü ve hava olaylarını gözlemlemek.',
         'Bulut türleri, rüzgâr yönü ve hava durumunun uçuşa etkisi ele alınır. '
         'Öğrenciler belirli bir süre gökyüzü gözlemi yaparak kayıt tutar.'),
        ('Uzay ve havacılık ilişkisini kavramak.',
         'Atmosferin katmanları, uzaya çıkışın havacılıktan farkı ve uzay '
         'araştırmaları ele alınır. Öğrenciler merak ettikleri bir konuyu '
         'araştırarak paylaşır.'),
        ('Yıl içinde yapılan çalışmaları tanıtmak.',
         'Model çalışmaları, gözlem kayıtları ve araştırmalardan seçilenler '
         'sınıf içinde veya okul panosunda sergilenir. Öğrenciler çalışmalarını '
         'akranlarına anlatır.'),
    ])

# ====================================================================
# 21 — HAYVANLARI SEVME VE KORUMA KULÜBÜ
# ====================================================================
kulup(
    21, 'Hayvanları Sevme ve Koruma Kulübü', 'hayvan', 'doga',
    kurulus_odak='Öğrencilerin hayvanlarla ilgili gözlem ve deneyimleri '
                 'paylaşılarak yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin hayvan sevgisi ve sorumlu davranış konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, gözlem ve koruma çalışmaları değerlendirilir.',
    aylar=[
        ('Hayvanlara karşı sorumluluk bilinci geliştirmek.',
         'Hayvanların da acı, korku ve ihtiyaç duyduğu ele alınır. Hayvanlara '
         'yaklaşırken dikkat edilecek davranışlar ve güvenlik kuralları '
         'üzerinde durulur. Korkutmadan ve zarar vermeden gözlem yapmanın önemi '
         'vurgulanır.'),
        ('Sokak hayvanlarının ihtiyaçlarını fark etmek.',
         'Sokak hayvanlarının barınma, su ve besin ihtiyacı ile kış şartlarının '
         'etkisi ele alınır. Öğrenciler okul çevresinde gözlemlerini paylaşır ve '
         'yapılabilecekleri belirler. Uygulamalar okul yönetiminin bilgisi '
         'dâhilinde yürütülür.'),
        ('Hayvan haklarını ve ilgili düzenlemeleri tanımak.',
         'Hayvanlara kötü muamelenin sonuçları, ihbar yolları ve sorumlu '
         'kurumlar ele alınır. Öğrenciler hayvan haklarını anlatan bilgilendirici '
         'çalışma hazırlar.'),
        ('Evcil hayvan bakımının sorumluluk gerektirdiğini kavramak.',
         'Beslenme, temizlik, sağlık kontrolü ve düzenli ilgi ihtiyacı ele '
         'alınır. Hayvan sahiplenmenin uzun süreli bir sorumluluk olduğu '
         'vurgulanır. Sahiplenme kararının aileyle birlikte verilmesi gerektiği '
         'belirtilir.'),
        ('Nesli tehlike altındaki canlıları tanımak.',
         'Ülkemizde ve dünyada nesli azalan türler ile bunun nedenleri '
         'araştırılır. Doğal yaşam alanlarının korunmasının önemi ele alınır. '
         'Öğrenciler seçtikleri bir türü tanıtan çalışma hazırlar.'),
        ('Kuşları ve yaban hayatını gözlemlemek.',
         'Okul bahçesi ve yakın çevrede görülen kuşlar ve diğer canlılar '
         'gözlemlenir. Gözlem sırasında sessiz ve uzaktan izlemenin önemi '
         'vurgulanır. Öğrenciler gözlem kaydı tutar.'),
        ('Hayvan sevgisini okul geneline yaymak.',
         'Yıl içinde yapılan çalışmalardan seçilenler diğer sınıflara aktarılır. '
         'Hayvan hakları ve sorumlu sahiplenme konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 22 — HOŞ SADÂ MUSİKİ KULÜBÜ
# ====================================================================
kulup(
    22, 'Hoş Sadâ Musiki Kulübü', 'hossada', 'sanat',
    kurulus_odak='Öğrencilerin ses ve çalgı ilgisi değerlendirilerek yıl '
                 'içinde çalışılacak eserler ve konular seçilir.',
    donem_odak='Öğrencilerin dinleme, ritim ve birlikte söyleme konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Dinleme, repertuvar ve icra çalışmaları değerlendirilir.',
    aylar=[
        ('Geleneksel müziğimizin özelliklerini tanımak.',
         'Türk musikisinin ses düzeni, usul anlayışı ve batı müziğinden ayrılan '
         'yönleri yaşa uygun biçimde ele alınır. Öğrenciler dinledikleri eserler '
         'üzerine izlenimlerini paylaşır.'),
        ('Doğru nefes ve ses kullanımını öğrenmek.',
         'Nefes alma, ses açma ve sesi zorlamadan kullanma çalışmaları yapılır. '
         'Sesi yormanın zararları vurgulanır. Çalışmalar kısa tutulur ve herkesin '
         'kendi ses aralığında kalması sağlanır.'),
        ('Usul ve ritim duygusu kazanmak.',
         'Temel usuller el vuruşuyla çalışılır. Ritmi birlikte tutmanın ve '
         'birbirini dinlemenin önemi vurgulanır. Çalgı gerekmez; el ve ayak '
         'vuruşuyla çalışılabilir.'),
        ('Bir eseri birlikte seslendirmeyi öğrenmek.',
         'Seçilen bir eser bölüm bölüm çalışılır. Birlikte başlama, aynı hızda '
         'gitme ve birlikte bitirme üzerinde durulur. Herkesin kendi hızında '
         'ilerlemesine imkân tanınır.'),
        ('Çalgıları ve seslerini tanımak.',
         'Geleneksel çalgılar ve çıkardıkları sesler tanıtılır. Çalgı temini '
         'zorunlu değildir; tanıtım dinleme ve anlatım yoluyla yapılır. '
         'Öğrenciler ilgi duydukları çalgıyı araştırarak tanıtır.'),
        ('Söz ve ezgi ilişkisini fark etmek.',
         'Bir eserin sözünün anlamı ile ezgisinin uyumu üzerinde durulur. '
         'Öğrenciler çalıştıkları eserin sözlerini inceleyerek neyi anlattığını '
         'açıklar.'),
        ('Çalışmayı okul geneline ulaştırmak.',
         'Okulun imkânları ölçüsünde sınıf içinde veya okul programında kısa bir '
         'dinleti yapılır. Dinleti şartı aranmaz; yıl boyunca kazanılan dinleme '
         've birlikte söyleme becerisi esas alınır.'),
    ])

# ====================================================================
# 23 — SAĞLIK VE GÜVENLİK KULÜBÜ
# ====================================================================
kulup(
    23, 'Sağlık ve Güvenlik Kulübü', 'saglikguvenlik', 'saglik',
    kurulus_odak='Okulda sağlık ve güvenlik bakımından dikkat gerektiren '
                 'konular belirlenerek yıl içinde ele alınacak başlıklar '
                 'seçilir.',
    donem_odak='Öğrencilerin güvenli davranış ve sağlık bilinci konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Gözlem, bilgilendirme ve farkındalık çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Okul içinde güvenli davranış kurallarını kavramak.',
         'Merdivenlerde, koridorlarda ve bahçede güvenli hareket etme, itişmeme '
         've kurallara uyma ele alınır. Öğrenciler okulda kaza riski taşıyan '
         'davranışları gözlemleyerek listeler.'),
        ('Temel ilk yardım bilgisini kazanmak.',
         'İlk yardımın amacı, yardım çağırma, 112 Acil Çağrı Merkezinin kullanımı '
         've bilinçsiz müdahaleden kaçınma ele alınır. Öğrencilerin uygulama '
         'değil, doğru davranış bilgisi kazanması hedeflenir.'),
        ('Bulaşıcı hastalıklardan korunmayı öğrenmek.',
         'El yıkama, öksürük ve hapşırık adabı, ortak eşya kullanımı ve '
         'havalandırmanın önemi ele alınır. Öğrenciler korunma kurallarını '
         'anlatan bilgilendirici çalışma hazırlar.'),
        ('Beslenme ile sağlık arasındaki ilişkiyi kavramak.',
         'Dengeli beslenme, kahvaltının önemi, su tüketimi ve abur cuburun '
         'etkileri ele alınır. Öğrenciler bir hafta boyunca beslenme '
         'alışkanlıklarını gözlemleyerek değerlendirir.'),
        ('Beden sağlığı için hareketin önemini kavramak.',
         'Düzenli hareketin bedene ve zihne katkısı, uzun süre oturmanın etkileri '
         've uyku düzeni ele alınır. Öğrenciler günlük hareket önerileri '
         'geliştirir.'),
        ('Ev ve çevrede güvenlik risklerini tanımak.',
         'Elektrik, ocak, sıcak su ve ilaç gibi risklerle karşılaşıldığında '
         'yapılması gerekenler ele alınır. Öğrenciler evde güvenlik kontrol '
         'listesi hazırlayarak ailesiyle paylaşır.'),
        ('Sağlık ve güvenlik bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara kısa '
         'bilgilendirme çalışmalarıyla aktarılır. Hazırlanan afişler okul '
         'panosunda sergilenir.'),
    ])

# ====================================================================
# 24 — İZCİLİK KULÜBÜ
# ====================================================================
kulup(
    24, 'İzcilik Kulübü', 'izcilik', 'doga',
    kurulus_odak='İzciliğin çalışma biçimi tanıtılarak yıl içinde ele '
                 'alınacak konular ve uygulamalar belirlenir.',
    donem_odak='Öğrencilerin doğada güvenli davranış ve grup çalışması '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Beceri, doğa bilgisi ve dayanışma çalışmaları değerlendirilir.',
    aylar=[
        ('İzciliğin amacını ve ilkelerini kavramak.',
         'İzciliğin doğa sevgisi, dayanışma ve kendi kendine yetme üzerine '
         'kurulduğu ele alınır. İzcilik ilkeleri ve selamı tanıtılır. Öğrenciler '
         'bu ilkelerin günlük hayattaki karşılıklarını tartışır.'),
        ('Doğada güvenli davranış kurallarını öğrenmek.',
         'Gruptan ayrılmama, gidilecek yeri bildirme, hava şartlarına hazırlık ve '
         'doğaya zarar vermeme ele alınır. Etkinlikler okul yönetiminin bilgisi '
         've gerekli izinler dâhilinde yürütülür.'),
        ('Temel izci becerilerini tanımak.',
         'Düğüm çeşitleri, sırt çantası düzeni ve temel malzeme bilgisi ele '
         'alınır. Düğüm çalışması ip veya kordonla sınıfta güvenle yapılabilir. '
         'Kesici ve ateşli araç kullanılmaz.'),
        ('Yön bulma ve harita okuma becerisi kazanmak.',
         'Yön kavramı, pusula mantığı ve doğal işaretlerle yön bulma ele alınır. '
         'Öğrenciler okul bahçesi veya sınıf planı üzerinde basit yön bulma '
         'çalışması yapar.'),
        ('Doğayı tanıma ve iz sürme becerisi geliştirmek.',
         'Bitki ve hayvan izlerini gözlemleme, doğadaki değişimi fark etme ele '
         'alınır. Öğrenciler okul bahçesinde gözlem yaparak kayıt tutar. Doğadan '
         'canlı veya bitki toplanmaz.'),
        ('Dayanışma ve topluma hizmet bilinci geliştirmek.',
         'İzciliğin yardımlaşma yönü ele alınır. Okul içinde yapılabilecek '
         'gönüllü çalışmalar belirlenir. Çalışmalar okul yönetiminin bilgisi '
         'dâhilinde yürütülür.'),
        ('Kazanılan becerileri değerlendirmek ve paylaşmak.',
         'Yıl içinde öğrenilen beceriler sınıf içinde uygulamalı olarak '
         'gösterilir. Öğrenciler izcilik ilkelerinin kendilerine kattıklarını '
         'değerlendirir.'),
    ])

# ====================================================================
# 25 — KIZILAY VE KAN BAĞIŞI KULÜBÜ
# ====================================================================
kulup(
    25, 'Kızılay ve Kan Bağışı Kulübü', 'kizilay', 'toplum',
    kurulus_odak='Kızılayın çalışma alanları tanıtılarak yıl içinde ele '
                 'alınacak konular belirlenir.',
    donem_odak='Öğrencilerin yardımlaşma ve toplumsal dayanışma konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, tanıtım ve dayanışma çalışmaları değerlendirilir.',
    aylar=[
        ('Kızılayın görevlerini ve tarihini tanımak.',
         'Kızılayın kuruluşu, afet ve acil durumlardaki görevleri ile '
         'yürüttüğü yardım çalışmaları ele alınır. Öğrenciler kurumun çalışma '
         'alanlarını tanıtan çalışma hazırlar.'),
        ('Kanın ve kan bağışının önemini kavramak.',
         'Kanın vücuttaki görevi, kan gruplarının ne anlama geldiği ve kan '
         'bağışının hayat kurtarmadaki rolü yaşa uygun biçimde ele alınır. '
         'Öğrenciler bağışın gönüllülük esasına dayandığını öğrenir.'),
        ('Yardımlaşmanın toplumsal değerini kavramak.',
         'İhtiyaç sahibine el uzatmanın, karşılık beklemeden yardım etmenin ve '
         'dayanışmanın toplumu güçlendirdiği ele alınır. Öğrenciler okulda '
         'uygulanabilir yardımlaşma önerileri geliştirir.'),
        ('Afet ve acil durumlarda yardım çalışmalarını tanımak.',
         'Afet anında yürütülen barınma, beslenme ve sağlık yardımı çalışmaları '
         'ele alınır. Gönüllülüğün bu süreçteki rolü vurgulanır. Öğrenciler '
         'araştırmalarını paylaşır.'),
        ('İhtiyaç sahiplerine karşı duyarlılık geliştirmek.',
         'Yardımın kişiyi incitmeden, mahremiyete saygı gösterilerek yapılması '
         'gerektiği ele alınır. Öğrenciler yardım ederken dikkat edilecek '
         'davranışları belirler.'),
        ('Gönüllülük bilinci kazandırmak.',
         'Gönüllü çalışmanın ne olduğu, kişiye ve topluma katkısı ele alınır. '
         'Okulda yapılabilecek gönüllü çalışmalar belirlenir. Uygulamalar okul '
         'yönetiminin bilgisi dâhilinde yürütülür.'),
        ('Farkındalığı okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Kan bağışı ve yardımlaşma konulu afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 26 — KİŞİSEL VERİLERİ KORUMA KULÜBÜ
# ====================================================================
kulup(
    26, 'Kişisel Verileri Koruma Kulübü', 'kvk', 'bilim',
    kurulus_odak='Öğrencilerin çevrim içi paylaşım alışkanlıkları kısaca '
                 'değerlendirilerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin kişisel veri ve mahremiyet konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, güvenli kullanım ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Kişisel verinin ne olduğunu kavramak.',
         'Ad, adres, telefon, okul bilgisi, fotoğraf ve konum gibi bilgilerin '
         'kişisel veri sayıldığı ele alınır. Bu bilgilerin başkasının eline '
         'geçmesi hâlinde doğabilecek sonuçlar örneklerle açıklanır.'),
        ('Mahremiyetin neden korunması gerektiğini anlamak.',
         'Özel hayatın gizliliği, izinsiz paylaşımın yol açtığı rahatsızlık ve '
         'başkasının bilgisini paylaşmanın da bir ihlal olduğu ele alınır. '
         'Öğrenciler paylaşım öncesi izin isteme alışkanlığı üzerinde durur.'),
        ('Parola güvenliğini ve hesap korumayı öğrenmek.',
         'Güçlü parola oluşturma, parolayı kimseyle paylaşmama ve farklı '
         'hesaplarda aynı parolayı kullanmama ele alınır. Öğrenciler güvenli '
         'parola kurallarını maddeler hâlinde yazar.'),
        ('Çevrim içi ortamlarda dikkat edilecekleri kavramak.',
         'Tanımayan kişilerden gelen istekler, ödül ve hediye vaadi içeren '
         'iletiler ile bilgi isteyen bağlantılar ele alınır. Şüpheli durumda '
         'yetişkine danışmanın önemi vurgulanır.'),
        ('Fotoğraf ve görüntü paylaşımında izin kavramını öğrenmek.',
         'Başkasının fotoğrafını izinsiz çekmeme ve paylaşmama üzerinde durulur. '
         'Paylaşılan görüntünün geri alınamayabileceği vurgulanır. Öğrenciler '
         'paylaşım öncesi kontrol listesi hazırlar.'),
        ('Haklarını ve başvuru yollarını tanımak.',
         'Kişisel verilerin korunmasına ilişkin hakların bulunduğu, rahatsız '
         'edici bir durumda ailesine, öğretmenine veya yetkili kuruma '
         'başvurulabileceği ele alınır.'),
        ('Veri güvenliği bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Parola güvenliği ve mahremiyet konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 27 — KOOPERATİFÇİLİK KULÜBÜ
# ====================================================================
kulup(
    27, 'Kooperatifçilik Kulübü', 'kooperatif', 'toplum',
    kurulus_odak='Birlikte iş yapma fikri tanıtılarak yıl içinde ele alınacak '
                 'konular belirlenir.',
    donem_odak='Öğrencilerin ortak çalışma ve paylaşım konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='İş birliği, planlama ve paylaşım çalışmaları değerlendirilir.',
    aylar=[
        ('Kooperatifin ne olduğunu kavramak.',
         'Kişilerin ortak ihtiyaçlarını birlikte karşılamak üzere bir araya '
         'gelmesi ele alınır. Tek başına yapılamayanın birlikte yapılabildiği '
         'örneklerle açıklanır.'),
        ('Ortak karar alma ve eşit söz hakkını uygulamak.',
         'Kooperatifte her üyenin eşit söz hakkı olduğu ele alınır. Öğrenciler '
         'ortak bir konuda tartışarak karar alır. Azınlıkta kalan görüşe saygının '
         'önemi vurgulanır.'),
        ('Paylaşma ve dayanışma alışkanlığı kazanmak.',
         'Ortak kullanılan eşyanın korunması, sırayla kullanma ve paylaşma '
         'üzerinde durulur. Sınıf içinde ortak kullanım düzeni oluşturulur.'),
        ('Emeğin ve katkının değerini kavramak.',
         'Ortak çalışmada herkesin katkısının önemi ele alınır. Katkı sunmayan '
         've fazla yük alan durumların gruba etkisi tartışılır. Adil görev '
         'paylaşımı üzerinde durulur.'),
        ('Basit bir ortak çalışma planlamak.',
         'Sınıf veya kulüp için ortak bir çalışma belirlenir; görev paylaşımı ve '
         'takvim çıkarılır. Çalışma tasarım düzeyinde kalır, para toplanmaz.'),
        ('Tutumlu olmayı ve kaynağı korumayı öğrenmek.',
         'Ortak kaynakların tutumlu kullanımı ve israfın gruba maliyeti ele '
         'alınır. Öğrenciler sınıfta kaynak kullanımını gözlemleyerek öneri '
         'geliştirir.'),
        ('Yürütülen ortak çalışmayı değerlendirmek ve paylaşmak.',
         'Yıl içinde yürütülen ortak çalışma sonuçlarıyla birlikte '
         'değerlendirilir. Öğrenciler birlikte çalışmanın kendilerine '
         'kattıklarını akranlarıyla paylaşır.'),
    ])

# ====================================================================
# 28 — KÜLTÜR VE EDEBİYAT KULÜBÜ
# ====================================================================
kulup(
    28, 'Kültür ve Edebiyat Kulübü', 'kulturedebiyat', 'kultur',
    kurulus_odak='Öğrencilerin okuma ilgisi ve ilgi duyduğu türler '
                 'belirlenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin okuma, yazma ve ifade konularındaki kazanımları '
               'gözden geçirilir.',
    yil_odak='Okuma, yazma ve paylaşım çalışmaları değerlendirilir.',
    aylar=[
        ('Okuma alışkanlığı kazandırmak.',
         'Düzenli okumanın kelime dağarcığına ve anlama becerisine katkısı ele '
         'alınır. Öğrenciler kendi seçtikleri bir kitabı okumaya başlar ve okuma '
         'günlüğü tutar.'),
        ('Edebî türleri tanımak.',
         'Şiir, hikâye, roman, deneme ve tiyatro gibi türlerin özellikleri '
         'örneklerle ele alınır. Öğrenciler ilgi duydukları türden bir örnek '
         'seçerek sınıfla paylaşır.'),
        ('Okuduğunu değerlendirme becerisi kazanmak.',
         'Bir metnin konusu, kahramanları ve vermek istediği üzerine konuşulur. '
         'Farklı yorumların doğal olduğu vurgulanır. Öğrenciler okudukları '
         'metin üzerine kısa değerlendirme yazar.'),
        ('Kendi metnini yazmayı denemek.',
         'Konu seçme, plan yapma ve yazıyı gözden geçirme aşamaları ele alınır. '
         'Öğrenciler kısa bir hikâye, şiir veya deneme yazar. İlk yazının son '
         'hâl olmadığı vurgulanır.'),
        ('Yazarları ve şairleri tanımak.',
         'Edebiyatımızda iz bırakmış yazar ve şairler ile eserleri araştırılır. '
         'Yaşadıkları dönemin eserlerine etkisi ele alınır. Öğrenciler seçtikleri '
         'kişiyi tanıtan çalışma hazırlar.'),
        ('Sözlü ifade ve dinleme becerisi geliştirmek.',
         'Okuduğunu veya yazdığını topluluk önünde anlatma çalışması yapılır. '
         'Dinleyicinin sabırla dinlemesi ve yapıcı geri bildirim vermesi '
         'üzerinde durulur.'),
        ('Üretilen metinleri okul geneline ulaştırmak.',
         'Yıl içinde yazılan metinlerden seçilenler okul panosunda veya sınıf '
         'içinde paylaşılır. Öğrenciler kendi yazılarını okuyarak sunum becerisi '
         'kazanır.'),
    ])

# ====================================================================
# 29 — KÜLTÜR VE TABİAT VARLIKLARINI KORUMA VE OKUL MÜZESİ KULÜBÜ
# ====================================================================
kulup(
    29, 'Kültür ve Tabiat Varlıklarını Koruma ve Okul Müzesi Kulübü',
    'kulturvarlik', 'kultur',
    kurulus_odak='Yörede bulunan kültür ve tabiat varlıkları öğrencilerle '
                 'birlikte listelenerek yıl içinde ele alınacak konular '
                 'seçilir.',
    donem_odak='Öğrencilerin koruma bilinci ve belgeleme konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Araştırma, belgeleme ve sergileme çalışmaları değerlendirilir.',
    aylar=[
        ('Kültür ve tabiat varlığı kavramını tanımak.',
         'Tarihî yapı, arkeolojik alan, anıt ağaç ve doğal oluşum gibi varlıklar '
         'örneklerle tanıtılır. Bunların neden ortak miras sayıldığı ele alınır. '
         'Öğrenciler yörelerindeki varlıkları araştırır.'),
        ('Tarihî eserlere zarar veren davranışları fark etmek.',
         'Yazı yazma, parça koparma, çöp bırakma ve izinsiz kazı gibi davranışlar '
         've bunların geri döndürülemez sonuçları ele alınır. Koruma çağrısı '
         'içeren afiş hazırlanır.'),
        ('Okul müzesi fikrini ve amacını kavramak.',
         'Okulun geçmişini yansıtan belge, fotoğraf ve eşyaların bir arada '
         'toplanmasının değeri ele alınır. Toplanacak malzemenin izinle ve '
         'zarar verilmeden alınması gerektiği vurgulanır.'),
        ('Belgeleme ve kayıt tutmayı öğrenmek.',
         'Bir eşyanın nereden geldiği, kime ait olduğu ve hangi döneme ait '
         'olduğunun kaydedilmesi ele alınır. Öğrenciler örnek kayıt fişi '
         'hazırlayarak doldurma çalışması yapar.'),
        ('Sözlü tarih çalışmasını tanımak.',
         'Yaşlı kişilerden geçmişe dair bilgi derlemenin değeri ele alınır. '
         'Görüşme yapılırken izin alma ve saygılı davranmanın önemi vurgulanır. '
         'Öğrenciler aile büyüklerinden derledikleri anıları paylaşır.'),
        ('Doğal varlıkları korumanın önemini kavramak.',
         'Anıt ağaçlar, mağaralar, göller ve korunan alanlar ele alınır. Doğal '
         'varlıkların bozulma nedenleri araştırılır. Öğrenciler koruma önerileri '
         'geliştirir.'),
        ('Derlenen çalışmaları sergilemek.',
         'Yıl içinde derlenen bilgi, fotoğraf ve kayıtlardan bir sergi köşesi '
         'oluşturulur. Sergilenen her ögenin yanına açıklama yazılır. İzin '
         'alınmayan malzeme sergilenmez.'),
    ])

# ====================================================================
# 30 — KÜTÜPHANECİLİK KULÜBÜ
# ====================================================================
kulup(
    30, 'Kütüphanecilik Kulübü', 'kutuphane', 'kultur',
    kurulus_odak='Okulun kitap imkânı ve öğrencilerin okuma ilgisi '
                 'değerlendirilerek yıl içinde yapılacak çalışmalar planlanır.',
    donem_odak='Öğrencilerin okuma alışkanlığı ve kitap düzeni konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Okuma, düzenleme ve tanıtım çalışmaları değerlendirilir.',
    aylar=[
        ('Kütüphane düzenini ve kitap bulmayı öğrenmek.',
         'Kitapların konularına göre nasıl sıralandığı, künye bilgisi ve kitap '
         'arama yolları ele alınır. Sınıf veya okul kitaplığında düzen çalışması '
         'yapılır.'),
        ('Kitaba özen göstermeyi alışkanlık hâline getirmek.',
         'Kitabın yıpranmadan kullanılması, zamanında iade edilmesi ve ortak '
         'kullanılan kitabın korunması ele alınır. Öğrenciler kitap kullanım '
         'kuralları hazırlar.'),
        ('Sınıf veya okul kitaplığını zenginleştirmek.',
         'Okunmuş kitapların paylaşımı ve kitaplığa katkı yolları ele alınır. '
         'Katkı gönüllülük esasına dayanır, kimseden kitap veya bağış istenmez. '
         'Getirilen kitaplar kayda geçirilir.'),
        ('Okuduğunu paylaşma alışkanlığı kazanmak.',
         'Okunan kitabı başkasına anlatmanın anlamayı pekiştirdiği ele alınır. '
         'Öğrenciler okudukları kitabı kısaca tanıtır ve neden önerdiğini '
         'açıklar.'),
        ('Farklı kaynak türlerini tanımak.',
         'Sözlük, ansiklopedi, dergi ve başvuru kaynakları tanıtılır. Bilgi '
         'ararken hangi kaynağa bakılacağı ele alınır. Öğrenciler bir konuyu '
         'farklı kaynaklardan araştırır.'),
        ('Okuma kültürünü akranlara yaymak.',
         'Okuma saatinin nasıl düzenleneceği ve akranları okumaya özendirme '
         'yolları ele alınır. Öğrenciler kitap tanıtım kartları hazırlar.'),
        ('Yıl içinde yapılan çalışmaları paylaşmak.',
         'Hazırlanan kitap tanıtımları ve okuma kayıtları okul panosunda '
         'sergilenir. Yıl boyunca okunan kitaplar değerlendirilir.'),
    ])

# ====================================================================
# 31 — MESLEK TANITMA KULÜBÜ
# ====================================================================
kulup(
    31, 'Meslek Tanıtma Kulübü', 'meslektanitma', 'toplum',
    kurulus_odak='Öğrencilerin merak ettiği meslekler derlenerek yıl içinde '
                 'tanıtılacak alanlar belirlenir.',
    donem_odak='Öğrencilerin meslekleri tanıma ve kendini değerlendirme '
               'konusundaki kazanımları gözden geçirilir.',
    yil_odak='Tanıtım, araştırma ve öz değerlendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Mesleklerin toplumdaki yerini kavramak.',
         'Her mesleğin bir ihtiyacı karşıladığı ve toplumun bütün mesleklere '
         'ihtiyaç duyduğu ele alınır. Meslekler arasında değer sıralaması '
         'yapılmaması gerektiği vurgulanır.'),
        ('İlgi ve yetenek kavramını tanımak.',
         'Kişinin nelerden hoşlandığı ve nelerde kolaylık çektiği üzerinde '
         'durulur. İlgi ve yeteneğin meslek seçimindeki rolü ele alınır. '
         'Öğrenciler kendilerini değerlendiren kısa bir çalışma yapar.'),
        ('Çevredeki meslekleri yakından tanımak.',
         'Okulda ve yakın çevrede görülen meslekler listelenir. Bu mesleklerin '
         'günlük çalışma biçimi araştırılır. Öğrenciler bir mesleği tanıtan '
         'çalışma hazırlar.'),
        ('Mesleklerin gerektirdiği eğitimi öğrenmek.',
         'Bir mesleğe ulaşmak için gereken okul, bölüm ve süre ele alınır. '
         'Öğrenciler ilgi duydukları mesleğin eğitim yolunu araştırarak '
         'paylaşır.'),
        ('Değişen ve yeni ortaya çıkan meslekleri tanımak.',
         'Teknolojiyle birlikte değişen çalışma biçimleri ve yeni meslek '
         'alanları ele alınır. Öğrenciler geleceğe dair merak ettiklerini '
         'tartışır.'),
        ('Çalışma hayatında uyulacak değerleri kavramak.',
         'Dürüstlük, zamanında iş teslimi, iş birliği ve emeğe saygı ele alınır. '
         'Öğrenciler bu değerlerin okul hayatındaki karşılıklarını belirler.'),
        ('Yıl içinde yapılan tanıtımları paylaşmak.',
         'Hazırlanan meslek tanıtımları okul panosunda sergilenir veya diğer '
         'sınıflarla paylaşılır. Öğrenciler yıl içinde ilgi alanlarında oluşan '
         'değişimi değerlendirir.'),
    ])

# ====================================================================
# 32 — MESLEKİ TATBİKAT KULÜBÜ
# ====================================================================
kulup(
    32, 'Mesleki Tatbikat Kulübü', 'meslekitatbikat', 'toplum',
    kurulus_odak='Okulun alan ve imkânlarına uygun uygulama konuları '
                 'belirlenerek yıl içinde yapılacak çalışmalar planlanır.',
    donem_odak='Öğrencilerin uygulama, iş güvenliği ve düzenli çalışma '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Uygulama, iş güvenliği ve ürün çalışmaları değerlendirilir.',
    aylar=[
        ('İş güvenliğinin temel kurallarını kavramak.',
         'Çalışma alanında düzen, uygun kıyafet, araç kullanımında dikkat ve '
         'uyarı işaretleri ele alınır. Güvenlik kurallarına uymadan uygulamaya '
         'başlanmayacağı vurgulanır.'),
        ('Çalışma alanını düzenli tutmayı öğrenmek.',
         'Araç gerecin yerli yerinde bulundurulması, çalışma sonrası toplama ve '
         'temizlik ele alınır. Öğrenciler çalışma alanı düzen kurallarını yazar.'),
        ('Basit bir uygulamayı adım adım yürütmek.',
         'Okulun alanına ve imkânına uygun, güvenli bir uygulama seçilir. '
         'Uygulama öncesi plan yapma, adımları sırayla izleme ve sonucu kontrol '
         'etme üzerinde durulur.'),
        ('Ölçme ve kontrol alışkanlığı kazanmak.',
         'Bir işin istenen ölçüde yapılıp yapılmadığının kontrolü ele alınır. '
         'Öğrenciler yaptıkları çalışmayı ölçerek değerlendirir. Hatanın fark '
         'edilip düzeltilmesinin doğal olduğu vurgulanır.'),
        ('Takım hâlinde iş yürütmeyi öğrenmek.',
         'Görev paylaşımı, sırayla çalışma ve birbirini uyarma ele alınır. '
         'Öğrenciler gruplar hâlinde bir çalışmayı birlikte tamamlar.'),
        ('Malzemeyi tutumlu kullanmayı öğrenmek.',
         'Malzeme israfının maliyeti ve artık malzemenin değerlendirilmesi ele '
         'alınır. Öğrenciler çalışmalarında tasarruf yollarını belirler.'),
        ('Ortaya konan çalışmaları değerlendirmek ve tanıtmak.',
         'Yıl içinde yapılan uygulamalar bir arada değerlendirilir. Seçilen '
         'çalışmalar sınıf içinde veya okul panosunda tanıtılır.'),
    ])

# ====================================================================
# 33 — MUN (MODEL BİRLEŞMİŞ MİLLETLER) KULÜBÜ
# ====================================================================
kulup(
    33, 'MUN (Model Birleşmiş Milletler) Kulübü', 'mun', 'kultur',
    kurulus_odak='Kulübün çalışma biçimi tanıtılarak yıl içinde ele alınacak '
                 'gündem konuları belirlenir.',
    donem_odak='Öğrencilerin araştırma, tartışma ve temsil konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Araştırma, müzakere ve sunum çalışmaları değerlendirilir.',
    aylar=[
        ('Birleşmiş Milletleri ve amacını tanımak.',
         'Birleşmiş Milletlerin kuruluş amacı, organları ve çalışma alanları '
         'ele alınır. Uluslararası iş birliğinin neden gerekli olduğu tartışılır.'),
        ('Ülkeleri ve dünya sorunlarını tanımak.',
         'Farklı ülkelerin coğrafyası, nüfusu ve öne çıkan özellikleri '
         'araştırılır. Açlık, eğitim, iklim ve barış gibi ortak sorunlar ele '
         'alınır. Öğrenciler bir ülkeyi araştırarak tanıtır.'),
        ('Bir konuyu araştırma ve görüş oluşturma becerisi kazanmak.',
         'Gündem konusunda güvenilir kaynaklardan bilgi toplama ve görüş '
         'oluşturma ele alınır. Öğrenciler temsil ettikleri ülkenin konuya '
         'bakışını yazılı olarak hazırlar.'),
        ('Kurallı tartışma ve müzakere yürütmeyi öğrenmek.',
         'Söz alma sırası, süre sınırı ve karşı görüşe saygı ele alınır. '
         'Öğrenciler belirlenen gündemde kurallara uygun bir müzakere yürütür.'),
        ('Uzlaşma metni oluşturmayı denemek.',
         'Farklı görüşlerin ortak bir metinde nasıl buluşturulacağı ele alınır. '
         'Öğrenciler gruplar hâlinde kısa bir uzlaşma metni yazar.'),
        ('Topluluk önünde konuşma becerisi geliştirmek.',
         'Hazırlıklı konuşma, göz teması ve süreyi kullanma üzerinde durulur. '
         'Öğrenciler hazırladıkları görüşü topluluk önünde sunar.'),
        ('Yıl içinde yürütülen çalışmaları değerlendirmek ve paylaşmak.',
         'Ele alınan gündemler ve varılan sonuçlar değerlendirilir. Öğrenciler '
         'süreçte kazandıkları araştırma ve konuşma becerisini paylaşır.'),
    ])

# ====================================================================
# 34 — MÜNAZARA KULÜBÜ
# ====================================================================
kulup(
    34, 'Münazara Kulübü', 'munazara', 'kultur',
    kurulus_odak='Münazaranın kuralları tanıtılarak yıl içinde tartışılacak '
                 'konular belirlenir.',
    donem_odak='Öğrencilerin savunma, dinleme ve gerekçelendirme '
               'becerilerindeki gelişim gözden geçirilir.',
    yil_odak='Tartışma, hazırlık ve değerlendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Münazaranın kurallarını ve düzenini öğrenmek.',
         'Taraflar, konuşma sırası, süre ve jüri düzeni ele alınır. Tartışmanın '
         'kişiye değil fikre yönelmesi gerektiği vurgulanır.'),
        ('Görüşünü gerekçelendirmeyi öğrenmek.',
         'Bir savı destekleyen gerekçe, örnek ve kaynak kullanımı ele alınır. '
         'Öğrenciler seçtikleri bir konuda savlarını gerekçeleriyle yazar.'),
        ('Karşı görüşü anlama ve yanıtlama becerisi kazanmak.',
         'Karşı tarafın savını dinleme, zayıf yönünü belirleme ve saygılı '
         'yanıt verme ele alınır. Öğrenciler karşı savlara yanıt hazırlar.'),
        ('Savunulan görüşe hazırlanmayı öğrenmek.',
         'Kendi görüşüne katılmadığı bir tarafı savunmanın bakış açısını '
         'genişlettiği ele alınır. Öğrenciler kura ile belirlenen tarafı '
         'savunmak üzere hazırlanır.'),
        ('Kurallara uygun münazara yürütmek.',
         'Belirlenen konuda taraflar hazırlıklarını sunar. Süreye ve sıraya '
         'uyulur. Sonuçta kazanan tarafın değil, ortaya konan gerekçelerin '
         'değerlendirilmesine ağırlık verilir.'),
        ('Dinleme ve değerlendirme becerisi geliştirmek.',
         'Jüri gözüyle dinleme, ölçütlere göre değerlendirme ve yapıcı geri '
         'bildirim verme ele alınır. Öğrenciler birbirlerinin konuşmasını '
         'değerlendirir.'),
        ('Yıl içinde yapılan münazaraları değerlendirmek.',
         'Ele alınan konular ve tartışma süreçleri değerlendirilir. Öğrenciler '
         'konuşma, dinleme ve gerekçelendirme becerilerindeki gelişimlerini '
         'paylaşır.'),
    ])

# ====================================================================
# 35 — MÜZİK KULÜBÜ
# ====================================================================
kulup(
    35, 'Müzik Kulübü', 'muzik', 'sanat',
    kurulus_odak='Öğrencilerin müzik ilgisi ve okulun çalgı imkânı '
                 'değerlendirilerek yıl içinde çalışılacak konular seçilir.',
    donem_odak='Öğrencilerin dinleme, ritim ve birlikte söyleme konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Dinleme, söyleme ve icra çalışmaları değerlendirilir.',
    aylar=[
        ('Sesi doğru kullanmayı öğrenmek.',
         'Nefes alma, ses açma ve sesi zorlamadan kullanma çalışmaları yapılır. '
         'Herkesin ses aralığının farklı olduğu vurgulanır. Çalışmalar kısa '
         'tutulur.'),
        ('Ritim duygusu kazanmak.',
         'Vuruş, tempo ve basit ritim kalıpları el ve ayak vuruşuyla çalışılır. '
         'Çalgı gerekmez. Birlikte aynı tempoda kalmanın önemi vurgulanır.'),
        ('Bir eseri birlikte söylemeyi öğrenmek.',
         'Seçilen bir eser bölüm bölüm çalışılır. Birlikte başlama, aynı hızda '
         'gitme ve birlikte bitirme üzerinde durulur. Herkesin kendi hızında '
         'ilerlemesine imkân tanınır.'),
        ('Müzik türlerini tanımak.',
         'Halk müziği, sanat müziği, marşlar ve dünya müziklerinden örnekler '
         'dinlenir. Türler arasındaki farklar ele alınır. Öğrenciler '
         'izlenimlerini paylaşır.'),
        ('Çalgıları ve seslerini tanımak.',
         'Telli, üflemeli ve vurmalı çalgılar tanıtılır. Çalgı temini zorunlu '
         'değildir; tanıtım dinleme ve anlatım yoluyla yapılır. Öğrenciler ilgi '
         'duydukları çalgıyı araştırır.'),
        ('Müzikle duygu ve anlam ilişkisini fark etmek.',
         'Bir eserin uyandırdığı duygu, sözlerinin anlamı ve ezgiyle uyumu '
         'üzerinde durulur. Öğrenciler çalıştıkları eserin neyi anlattığını '
         'açıklar.'),
        ('Çalışmayı okul geneline ulaştırmak.',
         'Okulun imkânları ölçüsünde sınıf içinde veya okul programında kısa bir '
         'dinleti yapılır. Dinleti şartı aranmaz; yıl boyunca kazanılan beceri '
         'esas alınır.'),
    ])

# ====================================================================
# 36 — ÖRNEK VE ÖNCÜ ŞAHSİYETLER TANITIM KULÜBÜ
# ====================================================================
kulup(
    36, 'Örnek ve Öncü Şahsiyetler Tanıtım Kulübü', 'oncusahsiyet', 'degerler',
    kurulus_odak='Yıl içinde tanıtılacak alanlar ve kişiler öğrencilerin '
                 'görüşü alınarak belirlenir.',
    donem_odak='Tanıtılan kişilerin öğrencilerde bıraktığı izlenim '
               'değerlendirilir.',
    yil_odak='Araştırma, tanıtım ve paylaşım çalışmaları değerlendirilir.',
    aylar=[
        ('Örnek alınacak kişilerin ortak özelliklerini fark etmek.',
         'Bir kişiyi örnek kılan çalışkanlık, dürüstlük, kararlılık ve topluma '
         'katkı gibi özellikler ele alınır. Ün ile örneklik arasındaki fark '
         'tartışılır.'),
        ('Bilim ve düşünce alanında iz bırakmış kişileri tanımak.',
         'Bilim ve düşünce alanında eser vermiş kişiler araştırılır. '
         'Çalışmalarının hangi ihtiyaçtan doğduğu ele alınır. Öğrenciler '
         'seçtikleri kişiyi tanıtan çalışma hazırlar.'),
        ('Millî mücadelede iz bırakmış kişileri tanımak.',
         'Millî mücadele döneminde görev almış kişiler ve fedakârlıkları '
         'araştırılır. Öğrenciler araştırmalarını kısa metin veya pano '
         'çalışmasıyla paylaşır.'),
        ('Sanat ve edebiyat alanında iz bırakmış kişileri tanımak.',
         'Edebiyat, müzik ve görsel sanatlarda eser vermiş kişiler araştırılır. '
         'Eserlerinin dönemine etkisi ele alınır. Öğrenciler seçtikleri kişiyi '
         'tanıtır.'),
        ('Topluma hizmet etmiş kişileri tanımak.',
         'Eğitim, sağlık ve yardımlaşma alanında topluma katkı sunmuş kişiler '
         'araştırılır. Karşılık beklemeden hizmet etmenin değeri vurgulanır.'),
        ('Yakın çevredeki örnek kişileri fark etmek.',
         'Ailede, okulda ve çevrede işini özenle yapan, güvenilir ve yardımsever '
         'kişiler üzerinde durulur. Örnekliğin uzakta aranmadığı vurgulanır. '
         'Öğrenciler çevrelerinden bir örnek anlatır.'),
        ('Yıl içinde yapılan tanıtımları okul geneline ulaştırmak.',
         'Hazırlanan tanıtım çalışmalarından seçilenler okul panosunda '
         'sergilenir. Öğrenciler örnek aldıkları özelliği kendi hayatlarında '
         'nasıl uygulayacaklarını paylaşır.'),
    ])

# ====================================================================
# 37 — PULCULUK KULÜBÜ
# ====================================================================
kulup(
    37, 'Pulculuk Kulübü', 'pulculuk', 'kultur',
    kurulus_odak='Pul biriktirmenin ne olduğu tanıtılarak yıl içinde ele '
                 'alınacak konular belirlenir.',
    donem_odak='Öğrencilerin biriktirme, sınıflandırma ve araştırma '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Derleme, sınıflandırma ve sergileme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Pulun ne olduğunu ve neden çıkarıldığını kavramak.',
         'Pulun posta hizmetindeki işlevi, üzerindeki bilgiler ve ülkeleri '
         'tanıtma yönü ele alınır. Öğrenciler evlerinde bulabildikleri pul veya '
         'zarfları inceler. Pul temini zorunlu değildir.'),
        ('Pulları konularına göre ayırmayı öğrenmek.',
         'Pulların konu, ülke ve yıla göre sınıflandırılması ele alınır. '
         'Sınıflandırmanın araştırmayı kolaylaştırdığı vurgulanır. Öğrenciler '
         'örnek bir sınıflandırma çalışması yapar.'),
        ('Pulları koruma ve saklama yollarını öğrenmek.',
         'Pulun yıpranmadan saklanması, nemden ve güneşten korunması ele alınır. '
         'Öğrenciler kâğıttan basit saklama zarfı hazırlar.'),
        ('Pullar üzerinden tarih ve kültür okumayı denemek.',
         'Bir pulun hangi olayı veya kişiyi anmak için çıkarıldığı araştırılır. '
         'Öğrenciler seçtikleri bir konuyu pul üzerinden anlatan çalışma '
         'hazırlar.'),
        ('Koleksiyon yapmanın kazandırdıklarını fark etmek.',
         'Sabır, düzen, araştırma ve sınıflandırma alışkanlığı ele alınır. '
         'Koleksiyonun pahalı olmak zorunda olmadığı vurgulanır.'),
        ('Kendi pul tasarımını yapmayı denemek.',
         'Bir pulun neyi anlatabileceği üzerinde durulur. Öğrenciler kendi '
         'seçtikleri konuda kâğıt üzerinde pul tasarımı çizer.'),
        ('Yıl içinde derlenen çalışmaları sergilemek.',
         'Derlenen pullar, tasarımlar ve araştırmalar sınıf içinde veya okul '
         'panosunda sergilenir. Her ögenin yanına kısa açıklama yazılır.'),
    ])

# ====================================================================
# 38 — SAĞLIK, TEMİZLİK VE BESLENME KULÜBÜ
# ====================================================================
kulup(
    38, 'Sağlık, Temizlik ve Beslenme Kulübü', 'saglikbeslenme', 'saglik',
    kurulus_odak='Öğrencilerin temizlik ve beslenme alışkanlıkları kısaca '
                 'değerlendirilerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin temizlik ve beslenme konularındaki kazanımları '
               'gözden geçirilir.',
    yil_odak='Farkındalık, gözlem ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Kişisel temizlik alışkanlıklarını kazanmak.',
         'El yıkama, diş fırçalama, banyo ve tırnak bakımı ele alınır. El '
         'yıkamanın hastalıklardan korunmadaki rolü vurgulanır. Öğrenciler '
         'günlük temizlik takip çizelgesi hazırlar.'),
        ('Dengeli beslenmeyi öğrenmek.',
         'Besin grupları, kahvaltının önemi ve öğün düzeni ele alınır. '
         'Öğrenciler bir gün boyunca yediklerini kaydedip besin gruplarına göre '
         'değerlendirir.'),
        ('Suyun ve düzenli su tüketiminin önemini kavramak.',
         'Suyun vücuttaki görevi, günlük su ihtiyacı ve şekerli içeceklerin '
         'etkileri ele alınır. Öğrenciler su tüketimlerini gözlemler.'),
        ('Sınıf ve okul temizliğine katkı sunmak.',
         'Ortak alanların temiz tutulması, çöpün yerine atılması ve sıraların '
         'düzeni ele alınır. Öğrenciler sınıf temizlik kuralları belirler.'),
        ('Ambalajlı gıdaları bilinçli seçmeyi öğrenmek.',
         'Son kullanma tarihi, içindekiler listesi ve şeker-tuz içeriği ele '
         'alınır. Öğrenciler boş ambalajlar üzerinde etiket okuma çalışması '
         'yapar.'),
        ('Uyku ve hareketin sağlığa etkisini kavramak.',
         'Yeterli uykunun derse odaklanmaya etkisi ve düzenli hareketin faydası '
         'ele alınır. Öğrenciler kendilerine uygun günlük düzen önerisi '
         'geliştirir.'),
        ('Sağlık ve temizlik bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'El yıkama ve dengeli beslenme konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 39 — SATRANÇ KULÜBÜ
# ====================================================================
kulup(
    39, 'Satranç Kulübü', 'satranc', 'spor',
    kurulus_odak='Öğrencilerin satranç bilgisi ve okulun takım imkânı '
                 'değerlendirilerek yıl içinde yapılacak çalışmalar planlanır.',
    donem_odak='Öğrencilerin kural bilgisi, planlama ve sabır konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Kural öğrenme, oyun ve değerlendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Taşları ve temel kuralları öğrenmek.',
         'Tahta düzeni, taşların hareketi ve oyunun amacı ele alınır. Takım '
         'yoksa kâğıda çizilen tahta ve karton taşlarla çalışılabilir.'),
        ('Şah çekme ve mat kavramını kavramak.',
         'Şahın korunması, şah çekme ve mat durumları örneklerle çalışılır. '
         'Öğrenciler basit mat kuruluşlarını tahta üzerinde uygular.'),
        ('Oyun başlangıcını planlamayı öğrenmek.',
         'Merkezi tutma, taşları geliştirme ve şahı güvene alma ele alınır. '
         'Aceleci hamlenin sonuçları örneklerle gösterilir.'),
        ('Hamle öncesi düşünme alışkanlığı kazanmak.',
         'Rakibin hamlesini öngörme, taş değerlerini gözetme ve acele etmeme '
         'üzerinde durulur. Öğrenciler hamlelerinin gerekçesini sözle açıklar.'),
        ('Kazanmayı ve kaybetmeyi olgunlukla karşılamak.',
         'Rakibe saygı, oyun sonunda tokalaşma ve yenilgiden ders çıkarma ele '
         'alınır. Kaybetmenin öğrenmenin parçası olduğu vurgulanır.'),
        ('Oyunları değerlendirme becerisi kazanmak.',
         'Biten bir oyunun geriye dönük incelenmesi ve hataların bulunması ele '
         'alınır. Öğrenciler oynadıkları bir oyunu birlikte değerlendirir.'),
        ('Yıl içindeki gelişimi değerlendirmek ve paylaşmak.',
         'Okulun imkânları ölçüsünde sınıf içi eşleşmeler düzenlenir. Turnuva '
         'şartı aranmaz. Öğrenciler yıl boyunca kazandıkları planlama ve sabır '
         'becerisini değerlendirir.'),
    ])

# ====================================================================
# 40 — ŞEHİR VE MEDENİYET KULÜBÜ
# ====================================================================
kulup(
    40, 'Şehir ve Medeniyet Kulübü', 'sehirmedeniyet', 'kultur',
    kurulus_odak='Öğrencilerin yaşadıkları yerle ilgili gözlemleri '
                 'paylaşılarak yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin şehir kültürü ve ortak yaşam konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Gözlem, araştırma ve tanıtım çalışmaları değerlendirilir.',
    aylar=[
        ('Yaşadığı yeri tanımak.',
         'Bulunulan yerin tarihi, adının kaynağı ve öne çıkan özellikleri '
         'araştırılır. Öğrenciler yaşadıkları yeri tanıtan çalışma hazırlar.'),
        ('Şehri oluşturan ögeleri fark etmek.',
         'Meydan, cadde, park, çarşı ve ibadet yeri gibi ögelerin şehirdeki '
         'işlevi ele alınır. Öğrenciler çevrelerinde bu ögeleri gözlemler.'),
        ('Ortak yaşam kurallarını kavramak.',
         'Gürültü, çöp, park düzeni ve komşuluk ilişkileri ele alınır. Ortak '
         'alanların herkese ait olduğu vurgulanır. Öğrenciler ortak yaşam '
         'kuralları listesi hazırlar.'),
        ('Şehirdeki tarihî dokuyu tanımak.',
         'Eski yapılar, sokak dokusu ve bunların korunması ele alınır. '
         'Öğrenciler çevrelerindeki tarihî bir yapıyı araştırarak tanıtır.'),
        ('Şehir sorunlarını fark etmek ve öneri geliştirmek.',
         'Trafik, çevre kirliliği, yeşil alan azlığı ve erişilebilirlik gibi '
         'sorunlar ele alınır. Öğrenciler gözlemledikleri bir sorun için öneri '
         'geliştirir.'),
        ('Medeniyet kavramını anlamaya çalışmak.',
         'Bir toplumun ürettiği bilgi, sanat ve yaşam biçiminin medeniyeti '
         'oluşturduğu ele alınır. Farklı medeniyetlerin birbirine katkısı '
         'üzerinde durulur.'),
        ('Yıl içinde yapılan çalışmaları paylaşmak.',
         'Hazırlanan tanıtım ve öneri çalışmaları okul panosunda sergilenir '
         'veya diğer sınıflarla paylaşılır.'),
    ])

# ====================================================================
# 41 — ŞİİR VE TEFEKKÜR KULÜBÜ
# ====================================================================
kulup(
    41, 'Şiir ve Tefekkür Kulübü', 'siir', 'kultur',
    kurulus_odak='Öğrencilerin şiir ilgisi değerlendirilerek yıl içinde ele '
                 'alınacak şairler ve temalar belirlenir.',
    donem_odak='Öğrencilerin şiir okuma, anlama ve yazma konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Okuma, yazma ve dinleti çalışmaları değerlendirilir.',
    aylar=[
        ('Şiiri diğer türlerden ayıran özellikleri kavramak.',
         'Ölçü, uyak, imge ve söyleyiş özellikleri örneklerle ele alınır. '
         'Öğrenciler beğendikleri bir şiiri getirerek neyi sevdiklerini anlatır.'),
        ('Şiir okumayı ve anlamlandırmayı öğrenmek.',
         'Bir şiirin neyi anlattığı, hangi duyguyu uyandırdığı üzerinde '
         'konuşulur. Farklı yorumların doğal olduğu vurgulanır.'),
        ('Şairleri ve dönemlerini tanımak.',
         'Edebiyatımızda iz bırakmış şairler araştırılır. Yaşadıkları dönemin '
         'şiirlerine etkisi ele alınır. Öğrenciler seçtikleri şairi tanıtır.'),
        ('Kendi şiirini yazmayı denemek.',
         'Konu seçme, imge kurma ve söyleyişe özen gösterme ele alınır. '
         'Öğrenciler kısa bir şiir yazar. İlk yazının son hâl olmadığı '
         'vurgulanır.'),
        ('Şiiri sesli okumayı öğrenmek.',
         'Vurgu, tonlama ve duraklama üzerinde durulur. Öğrenciler seçtikleri '
         'şiiri topluluk önünde okur. Dinleyicinin sabırla dinlemesi vurgulanır.'),
        ('Düşünme ve iç muhasebe alışkanlığı kazanmak.',
         'Şiirin insanı düşünmeye sevk eden yönü ele alınır. Öğrenciler bir şiir '
         'üzerine kendi düşüncelerini yazar.'),
        ('Yıl içinde üretilenleri okul geneline ulaştırmak.',
         'Yazılan şiirlerden seçilenler okul panosunda sergilenir. Okulun '
         'imkânları ölçüsünde kısa bir şiir dinletisi düzenlenebilir.'),
    ])

# ====================================================================
# 42 — SOSYAL YARDIMLAŞMA VE DAYANIŞMA, ÇOCUK ESİRGEME KULÜBÜ
# ====================================================================
kulup(
    42, 'Sosyal Yardımlaşma ve Dayanışma, Çocuk Esirgeme Kulübü',
    'sosyalyardim', 'toplum',
    kurulus_odak='Yardımlaşmanın okul içinde nasıl yürütüleceği belirlenerek '
                 'yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin dayanışma ve duyarlılık konularındaki kazanımları '
               'gözden geçirilir.',
    yil_odak='Farkındalık, dayanışma ve paylaşım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Yardımlaşmanın toplumsal değerini kavramak.',
         'Karşılık beklemeden yardım etmenin ve dayanışmanın toplumu '
         'güçlendirdiği ele alınır. Yardımın kişiyi incitmeden yapılması '
         'gerektiği vurgulanır.'),
        ('Mahremiyete saygıyı öğrenmek.',
         'Yardım edilen kişinin adının açıklanmaması, durumunun başkalarıyla '
         'konuşulmaması ve onurunun korunması ele alınır. Kulüp için uyulacak '
         'ilkeler yazılır.'),
        ('Akranlar arasında dayanışmayı geliştirmek.',
         'Ders çalışmasında destek olma, yalnız kalan arkadaşı gruba katma ve '
         'paylaşma ele alınır. Öğrenciler okulda uygulanabilir dayanışma '
         'önerileri belirler.'),
        ('Çocukların korunma ihtiyacını kavramak.',
         'Çocukların korunmaya ihtiyaç duyduğu durumlar ve bu alanda çalışan '
         'kurumlar tanıtılır. Rahatsız edici bir durumda güvenilen bir yetişkine '
         'başvurmanın önemi vurgulanır.'),
        ('Gönüllülük bilinci kazanmak.',
         'Gönüllü çalışmanın ne olduğu ve kişiye kattıkları ele alınır. Okulda '
         'yapılabilecek gönüllü çalışmalar belirlenir. Uygulamalar okul '
         'yönetiminin bilgisi dâhilinde yürütülür.'),
        ('Paylaşma alışkanlığını yaşatmak.',
         'Kullanılabilir durumdaki kitap, oyuncak veya kırtasiye malzemesinin '
         'paylaşımı ele alınır. Katkı gönüllülük esasına dayanır; kimseden '
         'bağış istenmez.'),
        ('Dayanışma bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Yardımlaşma ve dayanışma konulu afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 43 — SOSYAL MEDYA KULÜBÜ
# ====================================================================
kulup(
    43, 'Sosyal Medya Kulübü', 'sosyalmedya', 'bilim',
    kurulus_odak='Öğrencilerin sosyal medya kullanım alışkanlıkları kısaca '
                 'değerlendirilerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin bilinçli kullanım ve dijital iletişim '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, içerik değerlendirme ve paylaşım çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Sosyal medyanın yararlarını ve risklerini birlikte görmek.',
         'Bilgiye ulaşma ve iletişim kolaylığı ile zaman kaybı, yanlış bilgi ve '
         'mahremiyet riski birlikte ele alınır. Öğrenciler kendi kullanımlarını '
         'değerlendirir.'),
        ('Paylaşım öncesi düşünme alışkanlığı kazanmak.',
         'Paylaşılan içeriğin kalıcılığı ve başkalarını etkileyebileceği ele '
         'alınır. Öğrenciler paylaşım öncesi kendine sorulacak soruları '
         'belirler.'),
        ('Yanlış bilgiyi ayırt etmeyi öğrenmek.',
         'Kaynağı belirsiz içerik, abartılı başlık ve doğrulama yolları ele '
         'alınır. Öğrenciler karşılaştıkları bir içeriği kaynağıyla birlikte '
         'değerlendirir.'),
        ('Dijital ortamda saygılı iletişim kurmak.',
         'Yorum yazarken kullanılan dil, alay ve dışlamanın etkisi ele alınır. '
         'Siber zorbalıkla karşılaşıldığında yapılacaklar belirlenir.'),
        ('Ekran süresini yönetmeyi öğrenmek.',
         'Sosyal medyada geçen sürenin uyku, ders ve arkadaşlık ilişkilerine '
         'etkisi ele alınır. Öğrenciler bir hafta boyunca kullanımlarını '
         'gözlemler.'),
        ('Yararlı içerik üretmeyi denemek.',
         'Bilgilendirici ve yapıcı içeriğin nasıl hazırlanacağı ele alınır. '
         'Öğrenciler okul panosu için bilgilendirici bir içerik hazırlar. '
         'Çalışma okul dışına yayımlanmaz.'),
        ('Bilinçli kullanım bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Hazırlanan afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 44 — SPOR KULÜBÜ
# ====================================================================
kulup(
    44, 'Spor Kulübü', 'spor', 'spor',
    kurulus_odak='Okulun alan ve malzeme imkânı ile öğrencilerin ilgi '
                 'duyduğu branşlar değerlendirilerek yıl içinde yapılacak '
                 'çalışmalar planlanır.',
    donem_odak='Öğrencilerin hareket becerisi, kurallara uyma ve takım '
               'çalışması konularındaki kazanımları gözden geçirilir.',
    yil_odak='Hareket, kural bilgisi ve takım çalışması değerlendirilir.',
    aylar=[
        ('Isınma ve güvenli hareket alışkanlığı kazanmak.',
         'Isınma hareketlerinin sakatlanmayı önlemedeki rolü ve soğuma '
         'hareketlerinin önemi ele alınır. Çalışma öncesi ısınma alışkanlık '
         'hâline getirilir. Rahatsızlığı olan öğrenciler zorlanmaz.'),
        ('Temel hareket becerilerini geliştirmek.',
         'Koşma, sıçrama, denge ve koordinasyon çalışmaları yapılır. Çalışmalar '
         'bahçede, salonda veya uygun bir alanda yürütülür. Herkesin kendi '
         'düzeyinde ilerlemesine imkân tanınır.'),
        ('Bir spor dalının kurallarını öğrenmek.',
         'Okulun imkânına uygun bir branş seçilerek temel kuralları ele alınır. '
         'Kurallara uymanın oyunu mümkün kıldığı vurgulanır. Malzeme sınırlıysa '
         'basitleştirilmiş kurallarla oynanır.'),
        ('Takım hâlinde oynamayı öğrenmek.',
         'Görev paylaşımı, pas verme, arkadaşını bekleme ve takım içi iletişim '
         'ele alınır. Bireysel başarının takım başarısına bağlı olduğu '
         'vurgulanır.'),
        ('Sporda dürüstlüğü ve rakibe saygıyı kavramak.',
         'Kurallara uyma, hakem kararına saygı, kazanınca övünmeme ve '
         'kaybedince küsmeme ele alınır. Öğrenciler adil oyun ilkeleri '
         'belirler.'),
        ('Düzenli sporun sağlığa katkısını kavramak.',
         'Hareketin bedene ve zihne katkısı, uyku ve beslenmeyle ilişkisi ele '
         'alınır. Öğrenciler kendilerine uygun haftalık hareket planı '
         'hazırlar.'),
        ('Yıl içindeki gelişimi değerlendirmek.',
         'Okulun imkânları ölçüsünde sınıf içi eşleşme veya gösteri düzenlenir. '
         'Turnuva şartı aranmaz. Öğrenciler yıl boyunca kazandıkları beceri ve '
         'alışkanlıkları değerlendirir.'),
    ])

# ====================================================================
# 45 — SİBERAY KULÜBÜ
# ====================================================================
kulup(
    45, 'Siberay Kulübü', 'siberay', 'bilim',
    kurulus_odak='Öğrencilerin çevrim içi ortamlarda karşılaştıkları durumlar '
                 'paylaşılarak yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin siber güvenlik ve güvenli kullanım konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, güvenli kullanım ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Siber güvenliğin ne olduğunu kavramak.',
         'Çevrim içi ortamlarda karşılaşılabilecek riskler ve korunma yolları '
         'ele alınır. Güvenliğin yalnızca teknik değil davranışla da ilgili '
         'olduğu vurgulanır.'),
        ('Hesap güvenliğini sağlamayı öğrenmek.',
         'Güçlü parola oluşturma, parolayı paylaşmama ve şüpheli bağlantılara '
         'tıklamama ele alınır. Öğrenciler güvenli kullanım kurallarını '
         'maddeler hâlinde yazar.'),
        ('Zararlı içerik ve dolandırıcılığı tanımak.',
         'Ödül vaadi, hediye çekilişi ve bilgi isteyen iletiler gibi yöntemler '
         'örneklerle ele alınır. Şüpheli durumda yetişkine danışmanın önemi '
         'vurgulanır.'),
        ('Siber zorbalıkla mücadeleyi öğrenmek.',
         'Siber zorbalığın etkileri, karşılaşıldığında yapılacaklar ve yardım '
         'istenebilecek kişiler ele alınır. Kanıt saklamanın ve yalnız '
         'kalmamanın önemi vurgulanır.'),
        ('Oyun ve uygulama kullanımında dengeyi kurmak.',
         'Oyun süresinin uyku ve derse etkisi, uygulama içi harcama riskleri ve '
         'yaş sınırlarının anlamı ele alınır. Öğrenciler kendilerine denge '
         'önerisi geliştirir.'),
        ('Dijital ayak izini fark etmek.',
         'Çevrim içi bırakılan izlerin kalıcılığı ve ileride doğurabileceği '
         'sonuçlar ele alınır. Öğrenciler paylaşım öncesi kontrol listesi '
         'hazırlar.'),
        ('Güvenli internet bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Hazırlanan afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 46 — TİYATRO KULÜBÜ
# ====================================================================
kulup(
    46, 'Tiyatro Kulübü', 'tiyatro', 'sanat',
    kurulus_odak='Öğrencilerin ilgisi ve okulun sahne imkânı değerlendirilerek '
                 'yıl içinde çalışılacak metinler ve konular belirlenir.',
    donem_odak='Öğrencilerin ifade, canlandırma ve grup çalışması konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Metin çalışması, canlandırma ve gösterim çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Kendini ifade etme ve doğaçlama becerisi kazanmak.',
         'Beden dili, jest ve mimikle anlatım çalışılır. Kısa doğaçlama '
         'oyunlarıyla öğrencilerin çekingenliği azaltılır. Kimse zorlanmaz, '
         'katılım isteğe bağlı tutulur.'),
        ('Ses ve diksiyon çalışması yapmak.',
         'Nefes, sesi duyurma, vurgu ve anlaşılır konuşma çalışılır. Sesi '
         'zorlamadan kullanmanın önemi vurgulanır.'),
        ('Metin okuma ve rol çözümleme becerisi kazanmak.',
         'Seçilen metin birlikte okunur. Karakterlerin ne istediği ve neden öyle '
         'davrandığı üzerinde durulur. Öğrenciler kendi rollerini yorumlar.'),
        ('Sahne düzeni ve grup uyumunu öğrenmek.',
         'Sahnede duruş, arkadaşını dinleme ve replik sırası ele alınır. Sahne '
         'olmasa da sınıf içinde belirlenen bir alanda çalışılabilir.'),
        ('Basit sahne ögeleriyle üretim yapmak.',
         'Dekor ve kostümün artık malzemeyle nasıl hazırlanabileceği ele alınır. '
         'Masraf gerektiren malzeme zorunlu tutulmaz; yaratıcı çözümler tercih '
         'edilir.'),
        ('Oyunu bütünüyle çalışmak.',
         'Metin baştan sona uygulanır. Eksik kalan bölümler tekrar edilir. '
         'Öğrenciler birbirine yapıcı geri bildirim verir.'),
        ('Çalışmayı okul geneline ulaştırmak.',
         'Okulun imkânları ölçüsünde sınıf içinde veya okul programında bir '
         'gösterim yapılır. Gösterim şartı aranmaz; süreçte kazanılan ifade '
         'becerisi esas alınır.'),
    ])

# ====================================================================
# 47 — TRAFİK GÜVENLİĞİ VE İLKYARDIM KULÜBÜ
# ====================================================================
kulup(
    47, 'Trafik Güvenliği ve İlkyardım Kulübü', 'trafik', 'saglik',
    kurulus_odak='Okul çevresindeki trafik durumu öğrencilerle birlikte '
                 'gözlemlenerek yıl içinde ele alınacak konular seçilir.',
    donem_odak='Öğrencilerin trafik kuralları ve güvenli davranış '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Gözlem, farkındalık ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Yaya olarak güvenli davranmayı öğrenmek.',
         'Yaya geçidi kullanımı, karşıya geçerken dikkat edilecekler ve kaldırım '
         'kullanımı ele alınır. Öğrenciler okul çevresinde güvenli güzergâhı '
         'belirler.'),
        ('Trafik işaretlerini tanımak.',
         'Sık karşılaşılan uyarı, yasak ve bilgi işaretleri ile trafik ışıkları '
         'ele alınır. Öğrenciler işaretleri tanıtan kartlar hazırlar.'),
        ('Araçta güvenliği kavramak.',
         'Emniyet kemeri, arka koltuk kuralı ve araçta dikkat dağıtıcı '
         'davranışlardan kaçınma ele alınır. Öğrenciler bu kuralları ailesiyle '
         'paylaşır.'),
        ('Bisiklet ve scooter güvenliğini öğrenmek.',
         'Kask kullanımı, uygun alanda sürme ve gece görünürlüğü ele alınır. '
         'Kurallara uymanın kendini ve başkasını koruduğu vurgulanır.'),
        ('Temel ilk yardım bilgisini kazanmak.',
         'İlk yardımın amacı, 112 Acil Çağrı Merkezinin kullanımı, olay yeri '
         'güvenliği ve bilinçsiz müdahaleden kaçınma ele alınır. Uygulama değil, '
         'doğru davranış bilgisi hedeflenir.'),
        ('Okul çevresindeki trafik risklerini gözlemlemek.',
         'Öğrenciler okul çevresinde güvenli olmayan noktaları gözlemleyerek not '
         'eder. Gözlem sırasında yol kenarına yaklaşılmaz, güvenli mesafe '
         'korunur. Belirlenen riskler okul yönetimine iletilir.'),
        ('Trafik güvenliği bilincini okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Yaya güvenliği ve trafik işaretleri konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 48 — YABANCI DİLLER KULÜBÜ
# ====================================================================
kulup(
    48, 'Yabancı Diller Kulübü', 'yabancidil', 'kultur',
    kurulus_odak='Öğrencilerin dil düzeyi ve ilgisi değerlendirilerek yıl '
                 'içinde çalışılacak konular belirlenir.',
    donem_odak='Öğrencilerin kelime dağarcığı ve konuşma cesareti '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Kelime, konuşma ve kültür tanıma çalışmaları değerlendirilir.',
    aylar=[
        ('Günlük iletişim kalıplarını öğrenmek.',
         'Selamlaşma, tanışma ve teşekkür kalıpları çalışılır. Öğrenciler '
         'ikişerli gruplar hâlinde kısa karşılıklı konuşma yapar. Hata yapmanın '
         'öğrenmenin parçası olduğu vurgulanır.'),
        ('Kelime dağarcığını genişletmek.',
         'Belirlenen bir konuda kelimeler öğrenilir. Kelime kartı hazırlama ve '
         'tekrar etme yöntemleri ele alınır. Öğrenciler kendi kelime defterini '
         'oluşturur.'),
        ('Dinlediğini anlama becerisi geliştirmek.',
         'Yavaş ve anlaşılır bir metin veya şarkı dinlenerek anlaşılanlar '
         'paylaşılır. Her kelimeyi anlamanın gerekmediği vurgulanır.'),
        ('Konuşma cesareti kazanmak.',
         'Kısa cümlelerle kendini ifade etme çalışılır. Öğrenciler kendilerini, '
         'ailelerini veya sevdikleri bir konuyu birkaç cümleyle anlatır. '
         'Düzeltme yapıcı biçimde yapılır.'),
        ('Dilin konuşulduğu kültürleri tanımak.',
         'Öğrenilen dilin konuşulduğu ülkelerin günlük yaşamı, gelenekleri ve '
         'okul hayatı araştırılır. Öğrenciler bir ülkeyi tanıtan çalışma '
         'hazırlar.'),
        ('Basit metin okuma ve yazma denemek.',
         'Kısa ve düzeye uygun bir metin okunur. Öğrenciler öğrendikleri '
         'kalıplarla birkaç cümlelik metin yazar.'),
        ('Yıl içinde öğrenilenleri paylaşmak.',
         'Hazırlanan kelime kartları, tanıtımlar ve kısa metinler okul panosunda '
         'sergilenir. Öğrenciler öğrendiklerini akranlarıyla paylaşır.'),
    ])

# ====================================================================
# 49 — YAYIN VE İLETİŞİM KULÜBÜ
# ====================================================================
kulup(
    49, 'Yayın ve İletişim Kulübü', 'yayin', 'kultur',
    kurulus_odak='Okulda yürütülebilecek yayın çalışmaları belirlenerek yıl '
                 'içinde yapılacak işler planlanır.',
    donem_odak='Öğrencilerin haber yazma, doğrulama ve paylaşım konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Haber, yayın ve tanıtım çalışmaları değerlendirilir.',
    aylar=[
        ('Haberin ne olduğunu ve nasıl yazıldığını öğrenmek.',
         'Haberin doğruluk, güncellik ve ilgi ölçütleri ile temel soruları ele '
         'alınır. Öğrenciler okulda gerçekleşen bir olayı haber biçiminde yazar.'),
        ('Bilgiyi doğrulamayı alışkanlık hâline getirmek.',
         'Kaynak gösterme, farklı kaynaklardan doğrulama ve duyuma dayalı bilgi '
         'yayınlamama ele alınır. Doğrulanmamış bilginin zararı vurgulanır.'),
        ('Röportaj yapmayı öğrenmek.',
         'Soru hazırlama, izin alma ve saygılı görüşme ele alınır. Öğrenciler '
         'okulda bir kişiyle görüşme yaparak metne dönüştürür. Görüşülen kişiden '
         'izin alınmadan yayımlanmaz.'),
        ('Okul yayını hazırlamayı denemek.',
         'Bir yayının bölümleri, sayfa düzeni ve içerik dengesi ele alınır. '
         'Okulun imkânına göre pano gazetesi veya basılı bülten hazırlanır.'),
        ('Yazıda dil ve üslup özenini kazanmak.',
         'Anlaşılır cümle kurma, imla ve başlık seçimi ele alınır. Öğrenciler '
         'yazdıkları metni gözden geçirerek düzeltir.'),
        ('İletişimde sorumluluğu kavramak.',
         'Yayımlanan içeriğin başkalarını etkileyebileceği, kişi haklarına ve '
         'mahremiyete saygı gösterilmesi gerektiği ele alınır. Yayın ilkeleri '
         'yazılır.'),
        ('Hazırlanan yayını okul geneline ulaştırmak.',
         'Yıl içinde hazırlanan haber, röportaj ve yazılar okul panosunda '
         'yayımlanır. Öğrenciler yayın sürecinde kazandıklarını değerlendirir.'),
    ])

# ====================================================================
# 50 — YEŞİLAY KULÜBÜ
# ====================================================================
kulup(
    50, 'Yeşilay Kulübü', 'yesilay', 'saglik',
    kurulus_odak='Yeşilayın çalışma alanları tanıtılarak yıl içinde ele '
                 'alınacak konular belirlenir.',
    donem_odak='Öğrencilerin bağımlılıktan korunma ve sağlıklı yaşam '
               'konularındaki kazanımları gözden geçirilir.',
    yil_odak='Farkındalık, korunma ve bilgilendirme çalışmaları '
             'değerlendirilir.',
    aylar=[
        ('Bağımlılığın ne olduğunu kavramak.',
         'Bağımlılığın kişinin iradesini nasıl etkilediği ve yaşamına verdiği '
         'zarar yaşa uygun biçimde ele alınır. Bağımlılığın bir hastalık olduğu '
         've yardım alınabileceği vurgulanır.'),
        ('Teknoloji ve oyun bağımlılığını fark etmek.',
         'Ekran ve oyun kullanımının ne zaman zarara dönüştüğü, uyku ve derse '
         'etkisi ele alınır. Öğrenciler kendi kullanım sürelerini gözlemler.'),
        ('Sağlıklı yaşam alışkanlıklarını benimsemek.',
         'Düzenli uyku, dengeli beslenme, hareket ve hobi edinmenin koruyucu '
         'rolü ele alınır. Öğrenciler kendilerine uygun günlük düzen önerisi '
         'geliştirir.'),
        ('Akran baskısına karşı hayır diyebilmek.',
         'Arkadaş grubunun etkisi, kabul görme isteği ve zararlı bir teklife '
         'karşı hayır demenin yolları ele alınır. Öğrenciler örnek durumlar '
         'üzerinde yanıt geliştirir.'),
        ('Zararlı alışkanlıkların bedene etkisini kavramak.',
         'Tütün ve benzeri zararlı maddelerin bedene verdiği zarar bilimsel '
         'yönleriyle ele alınır. Korkutma değil bilgilendirme esas alınır.'),
        ('Yardım isteme yollarını bilmek.',
         'Bağımlılıkla mücadelede başvurulabilecek kişi ve kurumlar tanıtılır. '
         'Yardım istemenin zayıflık olmadığı vurgulanır. Öğrenciler '
         'başvurulabilecek yerleri not eder.'),
        ('Farkındalığı okul geneline yaymak.',
         'Yıl içinde işlenen konulardan seçilenler diğer sınıflara aktarılır. '
         'Sağlıklı yaşam ve bağımlılıktan korunma konulu afişler okul panosunda '
         'sergilenir.'),
    ])

# ====================================================================
# 51 — YEŞİLİ KORUMA KULÜBÜ
# ====================================================================
kulup(
    51, 'Yeşili Koruma Kulübü', 'yesilkoruma', 'doga',
    kurulus_odak='Okul bahçesi ve çevredeki yeşil alanlar öğrencilerle '
                 'birlikte gözlemlenerek yıl içinde ele alınacak konular '
                 'seçilir.',
    donem_odak='Öğrencilerin bitki bakımı ve yeşil alan koruma konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Gözlem, bakım ve bilinçlendirme çalışmaları değerlendirilir.',
    aylar=[
        ('Bitkilerin yaşam döngüsünü tanımak.',
         'Tohum, filiz, büyüme ve mevsim döngüsü ele alınır. Öğrenciler basit '
         'kaplarda tohum çimlendirerek düzenli gözlem kaydı tutar.'),
        ('Ağaçların çevreye katkısını kavramak.',
         'Havayı temizleme, gölge, toprağı tutma ve canlılara yuva olma işlevi '
         'ele alınır. Okul bahçesindeki ağaçlar gözlemlenerek tanıtılır.'),
        ('Bitki bakımını öğrenmek.',
         'Sulama düzeni, ışık ihtiyacı ve toprağın önemi ele alınır. Öğrenciler '
         'sınıf veya bahçedeki bitkilerin bakımını sırayla üstlenir.'),
        ('Yeşil alanların azalma nedenlerini fark etmek.',
         'Yapılaşma, kirlilik ve bilinçsiz kullanım gibi nedenler ele alınır. '
         'Öğrenciler çevrelerinde gözlemlerini paylaşarak öneri geliştirir.'),
        ('Fidan dikimi ve bakımının değerini kavramak.',
         'Fidanın dikimden sonra da bakım gerektirdiği vurgulanır. Okulun '
         'imkânları ve yönetimin uygun görmesi hâlinde fidan dikimi veya mevcut '
         'bitkilerin bakımı yapılır.'),
        ('Yerel bitki örtüsünü tanımak.',
         'Yörede doğal olarak yetişen bitkiler araştırılır. Yerel türlerin '
         'korunmasının önemi ele alınır. Öğrenciler tanıtım çalışması hazırlar.'),
        ('Yeşili koruma bilincini okul geneline yaymak.',
         'Yıl içinde yapılan çalışmalardan seçilenler diğer sınıflara aktarılır. '
         'Ağaç ve yeşil alan konulu afişler okul panosunda sergilenir.'),
    ])

# ====================================================================
# 52 — ZEKÂ OYUNLARI KULÜBÜ
# ====================================================================
kulup(
    52, 'Zekâ Oyunları Kulübü', 'zekaoyun', 'bilim',
    kurulus_odak='Okulun oyun malzemesi imkânı değerlendirilerek yıl içinde '
                 'çalışılacak oyun türleri belirlenir.',
    donem_odak='Öğrencilerin akıl yürütme, strateji ve sabır konularındaki '
               'kazanımları gözden geçirilir.',
    yil_odak='Oyun, strateji ve değerlendirme çalışmaları değerlendirilir.',
    aylar=[
        ('Akıl yürütme oyunlarını tanımak.',
         'Zekâ oyunlarının türleri ve düşünmeye katkısı ele alınır. Kâğıt kalem '
         'yeterli olan oyunlarla başlanır; malzeme zorunlu değildir.'),
        ('Örüntü ve mantık kurmayı öğrenmek.',
         'Sayı ve şekil örüntüleri, eksik parçayı bulma ve kural çıkarma '
         'çalışılır. Öğrenciler kendi örüntülerini kurarak arkadaşlarına sorar.'),
        ('Strateji oyunlarında plan yapmayı öğrenmek.',
         'Hamle öncesi düşünme, rakibin hamlesini öngörme ve plan kurma ele '
         'alınır. Öğrenciler oynadıkları oyunda hamle gerekçelerini açıklar.'),
        ('Sabır ve deneme alışkanlığı kazanmak.',
         'Bir bulmacanın ilk denemede çözülmemesinin doğal olduğu vurgulanır. '
         'Farklı yol deneme ve pes etmeme üzerinde durulur.'),
        ('Geometrik ve mekânsal düşünme becerisi geliştirmek.',
         'Katlama, parça birleştirme ve mekânda konumlandırma çalışmaları '
         'yapılır. Kâğıt ve karton yeterlidir.'),
        ('Kendi oyununu tasarlamayı denemek.',
         'Bir oyunun kuralları, amacı ve kazanma ölçütü ele alınır. Öğrenciler '
         'gruplar hâlinde basit bir oyun tasarlayarak kurallarını yazar.'),
        ('Yıl içindeki gelişimi değerlendirmek ve paylaşmak.',
         'Tasarlanan oyunlar ve çözülen bulmacalar sınıf içinde paylaşılır. '
         'Okulun imkânları ölçüsünde sınıf içi eşleşmeler düzenlenebilir; '
         'turnuva şartı aranmaz.'),
    ])

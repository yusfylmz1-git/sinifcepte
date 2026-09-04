"""
!!! KULLANIMDAN KALDIRILDI - CALISTIRMAYIN !!!
Ayrintilar icin: scripts/_deprecated/README.md
Yerine: python scripts/maarif/build_curriculum.py --year <yil>
"""
import sys

print(__doc__, file=sys.stderr)
raise SystemExit(
    "Bu script kullanimdan kaldirildi. "
    "Kullanin: python scripts/maarif/build_curriculum.py --year <yil>"
)

# --- Eski kod yalnizca referans icin asagida korunuyor ---

if False:  # noqa
    """
    SınıfCepte - MEB Maarif Modeli Lise (9-12. Sınıf) ve İmam Hatip Müfredat Jeneratörü & Birleştirici
    Bu script, 9, 10, 11, 12. sınıf tüm branşlarını (Fizik, Kimya, Biyoloji, Türk Dili ve Edebiyatı,
    Tarih, Coğrafya, Felsefe, Matematik, İngilizce, Din Kültürü vb.) Maarif modeline uygun 36 haftalık
    zengin kazanımlarla üretir ve mevcut 1-8. sınıf verileriyle birleştirir.
    """

    import os
    import sys
    import json
    import re

    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
    OUTPUT_JSON = os.path.join(DATA_DIR, "official_maarif_kazanimlar.json")

    # 2026-2027 Resmî MEB Takvimi Tarihleri (39 Hafta)
    ACADEMIC_WEEKS_2026_2027 = {
        1: {"start": "2026-09-14", "end": "2026-09-18", "formatted": "14 - 18 Eylül 2026", "month": "Eylül", "term": 1},
        2: {"start": "2026-09-21", "end": "2026-09-25", "formatted": "21 - 25 Eylül 2026", "month": "Eylül", "term": 1},
        3: {"start": "2026-09-28", "end": "2026-10-02", "formatted": "28 Eylül - 2 Ekim 2026", "month": "Ekim", "term": 1},
        4: {"start": "2026-10-05", "end": "2026-10-09", "formatted": "5 - 9 Ekim 2026", "month": "Ekim", "term": 1},
        5: {"start": "2026-10-12", "end": "2026-10-16", "formatted": "12 - 16 Ekim 2026", "month": "Ekim", "term": 1},
        6: {"start": "2026-10-19", "end": "2026-10-23", "formatted": "19 - 23 Ekim 2026", "month": "Ekim", "term": 1},
        7: {"start": "2026-10-26", "end": "2026-10-30", "formatted": "26 - 30 Ekim 2026", "month": "Ekim", "term": 1},
        8: {"start": "2026-11-02", "end": "2026-11-06", "formatted": "2 - 6 Kasım 2026", "month": "Kasım", "term": 1, "is_otp": True},
        9: {"start": "2026-11-09", "end": "2026-11-13", "formatted": "9 - 13 Kasım 2026", "month": "Kasım", "term": 1},
        10: {"start": "2026-11-16", "end": "2026-11-20", "formatted": "16 - 20 Kasım 2026 (1. Dönem Ara Tatil)", "month": "Kasım", "term": 1, "is_holiday": True, "holiday_note": "1. Dönem Ara Tatili"},
        11: {"start": "2026-11-23", "end": "2026-11-27", "formatted": "23 - 27 Kasım 2026", "month": "Kasım", "term": 1},
        12: {"start": "2026-11-30", "end": "2026-12-04", "formatted": "30 Kasım - 4 Aralık 2026", "month": "Aralık", "term": 1},
        13: {"start": "2026-12-07", "end": "2026-12-11", "formatted": "7 - 11 Aralık 2026", "month": "Aralık", "term": 1},
        14: {"start": "2026-12-14", "end": "2026-12-18", "formatted": "14 - 18 Aralık 2026", "month": "Aralık", "term": 1},
        15: {"start": "2026-12-21", "end": "2026-12-25", "formatted": "21 - 25 Aralık 2026", "month": "Aralık", "term": 1},
        16: {"start": "2026-12-28", "end": "2027-01-01", "formatted": "28 Aralık 2026 - 1 Ocak 2027", "month": "Ocak", "term": 1},
        17: {"start": "2027-01-04", "end": "2027-01-08", "formatted": "4 - 8 Ocak 2027", "month": "Ocak", "term": 1, "is_otp": True},
        18: {"start": "2027-01-11", "end": "2027-01-15", "formatted": "11 - 15 Ocak 2027 (Sosyal Etkinlikler Haftası)", "month": "Ocak", "term": 1, "is_social_event": True},
        19: {"start": "2027-01-18", "end": "2027-01-22", "formatted": "18 - 22 Ocak 2027 (Yarıyıl Tatili 1. Hafta)", "month": "Ocak", "term": 1, "is_holiday": True, "holiday_note": "Yarıyıl Tatili (1. Hafta)"},
        20: {"start": "2027-01-25", "end": "2027-01-29", "formatted": "25 - 29 Ocak 2027 (Yarıyıl Tatili 2. Hafta)", "month": "Ocak", "term": 1, "is_holiday": True, "holiday_note": "Yarıyıl Tatili (2. Hafta)"},
        21: {"start": "2027-02-01", "end": "2027-02-05", "formatted": "1 - 5 Şubat 2027 (2. Dönem Başlangıcı)", "month": "Şubat", "term": 2},
        22: {"start": "2027-02-08", "end": "2027-02-12", "formatted": "8 - 12 Şubat 2027", "month": "Şubat", "term": 2},
        23: {"start": "2027-02-15", "end": "2027-02-19", "formatted": "15 - 19 Şubat 2027", "month": "Şubat", "term": 2},
        24: {"start": "2027-02-22", "end": "2027-02-26", "formatted": "22 - 26 Şubat 2027", "month": "Şubat", "term": 2},
        25: {"start": "2027-03-01", "end": "2027-03-05", "formatted": "1 - 5 Mart 2027", "month": "Mart", "term": 2},
        26: {"start": "2027-03-08", "end": "2027-03-12", "formatted": "8 - 12 Mart 2027", "month": "Mart", "term": 2},
        27: {"start": "2027-03-15", "end": "2027-03-19", "formatted": "15 - 19 Mart 2027", "month": "Mart", "term": 2},
        28: {"start": "2027-03-22", "end": "2027-03-26", "formatted": "22 - 26 Mart 2027 (2. Dönem Ara Tatil)", "month": "Mart", "term": 2, "is_holiday": True, "holiday_note": "2. Dönem Ara Tatili"},
        29: {"start": "2027-03-29", "end": "2027-04-02", "formatted": "29 Mart - 2 Nisan 2027", "month": "Nisan", "term": 2, "is_otp": True},
        30: {"start": "2027-04-05", "end": "2027-04-09", "formatted": "5 - 9 Nisan 2027", "month": "Nisan", "term": 2},
        31: {"start": "2027-04-12", "end": "2027-04-16", "formatted": "12 - 16 Nisan 2027", "month": "Nisan", "term": 2},
        32: {"start": "2027-04-19", "end": "2027-04-23", "formatted": "19 - 23 Nisan 2027 (23 Nisan Ulusal Egemenlik)", "month": "Nisan", "term": 2},
        33: {"start": "2027-04-26", "end": "2027-04-30", "formatted": "26 - 30 Nisan 2027", "month": "Nisan", "term": 2},
        34: {"start": "2027-05-03", "end": "2027-05-07", "formatted": "3 - 7 Mayıs 2027", "month": "Mayıs", "term": 2},
        35: {"start": "2027-05-10", "end": "2027-05-14", "formatted": "10 - 14 Mayıs 2027", "month": "Mayıs", "term": 2},
        36: {"start": "2027-05-17", "end": "2027-05-21", "formatted": "17 - 21 Mayıs 2027 (19 Mayıs Atatürk'ü Anma)", "month": "Mayıs", "term": 2},
        37: {"start": "2027-05-24", "end": "2027-05-28", "formatted": "24 - 28 Mayıs 2027 (Yıl Sonu Sosyal Etkinlik)", "month": "Mayıs", "term": 2, "is_social_event": True},
        38: {"start": "2027-05-31", "end": "2027-06-04", "formatted": "31 Mayıs - 4 Haziran 2027", "month": "Haziran", "term": 2},
        39: {"start": "2027-06-07", "end": "2027-06-11", "formatted": "7 - 11 Haziran 2027 (Kapanış & Karne Haftası)", "month": "Haziran", "term": 2}
    }

    HIGH_SCHOOL_COURSES = [
        # --- KİMYA ---
        {
            "subjectCode": "KIMYA", "subjectName": "Kimya", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Kimya Bilimi ve Güvenlik", "KMY.9.1", ["Kimyanın bilim olma süreci ve sembolik dili açıklar.", "Laboratuvarda iş sağlığı ve güvenliği kurallarını uygular.", "Kimya disiplinleri ve kimyacıların çalışma alanlarını analiz eder."]),
                    ("2. Tema: Atom ve Periyodik Sistem", "KMY.9.2", ["Atom modellerinin tarihsel gelişimini açıklar.", "Atomun yapısını oluşturan temel tanecikleri ayırt eder.", "Elementlerin periyodik sistemdeki yerini ve özelliklerini belirler."]),
                    ("3. Tema: Kimyasal Türler Arası Etkileşimler", "KMY.9.3", ["Kimyasal türleri ve aralarındaki etkileşimleri sınıflandırır.", "İyonik, kovalent ve metalik bağ oluşumunu modeller.", "Zayıf etkileşimleri hidrojen bağı ve van der Waals olarak analiz eder."]),
                    ("4. Tema: Maddenin Halleri", "KMY.9.4", ["Katı, sıvı ve gaz hallerinin temel özelliklerini açıklar.", "Sıvılarda viskozite ve buhar basıncı ilişkisini yorumlar.", "Gazların genel özelliklerini ve plazma halini inceler."]),
                    ("5. Tema: Çevre Kimyası", "KMY.9.5", ["Hava, su ve toprak kirliliğine neden olan kimyasalları açıklar.", "Çevreye zararlı kimyasal maddelerin etkilerini azaltma yöntemlerini tartışır."])
                ],
                10: [
                    ("1. Tema: Kimyanın Temel Kanunları ve Hesaplamalar", "KMY.10.1", ["Kütlenin korunumu, sabit oranlar ve katlı oranlar kanunlarını hesaplar.", "Mol kavramını ve kimyasal denklem hesaplamalarını uygular.", "Sınırlayıcı bileşen ve yüzde verim problemlerini çözer."]),
                    ("2. Tema: Karışımlar", "KMY.10.2", ["Homojen ve heterojen karışımları ayırt eder.", "Kütlece yüzde, hacimce yüzde ve ppm derişim hesaplamaları yapar.", "Karışımları ayırma ve saflaştırma tekniklerini açıklar."]),
                    ("3. Tema: Asitler, Bazlar ve Tuzlar", "KMY.10.3", ["Asit ve bazların genel özelliklerini ve pH kavramını analiz eder.", "Asit-baz tepkimelerini ve nötralleşme sürecini modeller.", "Tuzların kullanım alanlarını ve yapısal özelliklerini inceler."]),
                    ("4. Tema: Kimya Her Yerde", "KMY.10.4", ["Temizlik maddeleri, polimerler, kozmetikler ve ilaçların kimyasal yapısını açıklar.", "Gıdalarda kullanılan kimyasal katkı maddelerini sorgular."])
                ],
                11: [
                    ("1. Tema: Modern Atom Teorisi", "KMY.11.1", ["Kuantum sayıları ve orbitallerin enerji düzeylerini açıklar.", "Elektron dizilimlerini Aufbau, Pauli ve Hund kurallarıyla yazar.", "Periyodik özelliklerdeki değişim eğilimlerini analiz eder."]),
                    ("2. Tema: Gazlar", "KMY.11.2", ["İdeal gaz yasasını ve gaz kanunlarını uygular.", "Gazların kinetik teorisini ve difüzyon hızlarını açıklar.", "Gerçek gazlar ile ideal gazlar arasındaki farkları yorumlar."]),
                    ("3. Tema: Sıvı Çözeltiler ve Çözünürlük", "KMY.11.3", ["Molarite, molalite ve mol kesri hesaplamaları yapar.", "Koligatif özellikleri buhar basıncı, donma ve kaynama noktası üzerinden açıklar.", "Çözünürlüğe etki eden faktörleri grafiklerle yorumlar."]),
                    ("4. Tema: Kimyasal Tepkimelerde Enerji ve Hız", "KMY.11.4", ["Tepkime entalpisini ve bağ enerjilerini hesaplar.", "Tepkime hızını ve hıza etki eden faktörleri çarpışma teorisiyle açıklar."]),
                    ("5. Tema: Kimyasal Denge", "KMY.11.5", ["Denge bağıntısını (Kc, Kp) kurar ve hesaplar.", "Le Chatelier ilkesine göre dengeye etki eden faktörleri analiz eder.", "Sulu çözeltilerde asit-baz dengesi ve Kç değerini hesaplar."])
                ],
                12: [
                    ("1. Tema: Kimya ve Elektrik", "KMY.12.1", ["İndirgenme-yükseltgenme tepkimelerini denkleştirir.", "Galvanik pilleri, elektrot potansiyellerini ve Nernst eşitliğini hesaplar.", "Elektroliz ve Faraday yasalarını korozyondan korunma ile ilişkilendirir."]),
                    ("2. Tema: Karbon Kimyasına Giriş", "KMY.12.2", ["Karbonun allotroplarını ve hibritleşme türlerini (sp3, sp2, sp) modeller.", "Lewis formülleri ve VSEPR teorisi ile molekül geometrisini belirler."]),
                    ("3. Tema: Organik Bileşikler", "KMY.12.3", ["Alkan, alken ve alkinlerin adlandırılmasını ve reaksiyonlarını açıklar.", "Fonksiyonel grupları (alkol, eter, aldehit, keton, karboksilik asit, ester) sınıflandırır."]),
                    ("4. Tema: Enerji Kaynakları ve Bilimsel Gelişmeler", "KMY.12.4", ["Fosil yakıtlar, yenilenebilir enerji kaynakları ve nükleer enerjiyi karşılaştırır.", "Yeşil kimya ve sürdürülebilirlik ilkelerini açıklar."])
                ]
            }
        },

        # --- FİZİK ---
        {
            "subjectCode": "FIZIK", "subjectName": "Fizik", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Fizik Bilimine Giriş ve Madde", "FZK.9.1", ["Fiziğin alt dallarını ve temel/türetilmiş büyüklükleri sınıflandırır.", "Özkütle ve dayanıklılık kavramlarını katı ve sıvılarda hesaplar.", "Adezyon, kohezyon, yüzey gerilimi ve kılcallık olaylarını açıklar."]),
                    ("2. Tema: Hareket ve Kuvvet", "FZK.9.2", ["Konum, alınan yol, yer değiştirme, hız ve sürat kavramlarını grafiklerle analiz eder.", "Newton'ın hareket yasalarını (Eylemsizlik, Temel Yasa, Etki-Tepki) uygular.", "Sürtünme kuvvetini statik ve kinetik olarak modeller."]),
                    ("3. Tema: Enerji", "FZK.9.3", ["İş, güç ve mekanik enerji hesaplamaları yapar.", "Kinetik ve potansiyel enerji dönüşümlerini ve enerjinin korunumunu modeller.", "Verim ve yenilenebilir enerji kaynaklarını açıklar."]),
                    ("4. Tema: Isı ve Sıcaklık", "FZK.9.4", ["Isı, sıcaklık ve iç enerji kavramlarını ayırt eder.", "Hal değişimi ve ısıl denge hesaplamaları yapar.", "Isı iletim yollarını ve genleşmeyi modeller."]),
                    ("5. Tema: Elektrostatik", "FZK.9.5", ["Elektrik yüklerini ve sürtünme/dokunma/etki ile elektriklenmeyi açıklar.", "Coulomb yasasını ve elektriksel alanı modeller."])
                ],
                10: [
                    ("1. Tema: Elektrik ve Manyetizma", "FZK.10.1", ["Ohm yasasını, eşdeğer direnç ve elektriksel güç/enerji hesaplarını yapar.", "Mıknatısların manyetik alanını ve akım taşıyan telin manyetik etkisini açıklar."]),
                    ("2. Tema: Basınç ve Kaldırma Kuvveti", "FZK.10.2", ["Katı, sıvı ve gaz basıncını Pascal ve Bernoulli prensipleriyle açıklar.", "Sıvıların kaldırma kuvvetini Archimedes ilkesiyle modeller."]),
                    ("3. Tema: Dalgalar", "FZK.10.3", ["Yay, su, ses ve deprem dalgalarının temel özelliklerini inceler.", "Dalgaların yansıma, kırılma ve girişim olaylarını açıklar."]),
                    ("4. Tema: Optik", "FZK.10.4", ["Aydınlanma, gölge oluşumu ve düzlem/küresel aynalarda görüntü özelliklerini modeller.", "Işığın kırılması, tam yansıma ve merceklerde odaklanmayı açıklar."])
                ],
                11: [
                    ("1. Tema: Vektörler ve Bağıl Hareket", "FZK.11.1", ["İki ve üç boyutlu vektörleri bileşenlerine ayırır ve toplar.", "Bir boyutta ve iki boyutta bağıl hareket problemlerini çözer."]),
                    ("2. Tema: Newton'ın Hareket Yasaları ve İvmeli Hareket", "FZK.11.2", ["Eğik düzlemde ve sürtünmeli ortamlarda dinamik hesaplamalar yapar.", "Bir ve iki boyutta sabit ivmeli hareket grafiklerini yorumlar."]),
                    ("3. Tema: İtme ve Çizgisel Momentum", "FZK.11.3", ["İtme ve momentum değişimi ilişkisini kurar.", "Esnek ve esnek olmayan çarpışmalarda momentum korunumunu uygular."]),
                    ("4. Tema: Tork, Denge ve Basit Makineler", "FZK.11.4", ["Tork hesaplar ve cisimlerin denge şartlarını belirler.", "Kaldıraç, makara, eğik düzlem ve vida verimini hesaplar."]),
                    ("5. Tema: Elektrik ve Manyetizma (İleri)", "FZK.11.5", ["Elektriksel potansiyel enerji ve sığaçları inceler.", "Manyetik kuvvet, indüksiyon emk ve alternatif akımı analiz eder."])
                ],
                12: [
                    ("1. Tema: Çembersel Hareket", "FZK.12.1", ["Düzgün çembersel hareket değişkenlerini (açısal hız, merkezcil ivme) hesaplar.", "Dönerek öteleme hareketi ve açısal momentumun korunumunu açıklar.", "Kepler yasalarını ve kütle çekim kuvvetini modeller."]),
                    ("2. Tema: Basit Harmonik Hareket", "FZK.12.2", ["Yaylı sarkaç ve basit sarkaç periyot denklemlerini uygular.", "Harmonik harekette hız, ivme ve kuvvet grafiklerini yorumlar."]),
                    ("3. Tema: Dalga Mekaniği ve Işık Teorileri", "FZK.12.3", ["Su ve ışık dalgalarında kırınım, girişim ve Doppler olayını inceler.", "Elektromanyetik spektrum özelliklerini ve fotoelektrik olayı modeller."]),
                    ("4. Tema: Atom Fiziği ve Modern Fizik", "FZK.12.4", ["Bohr atom modelini, Compton saçılmasını ve De Broglie dalga boyunu açıklar.", "Özel görelilik teorisini ve modern fiziğin teknolojideki yerini tartışır."])
                ]
            }
        },

        # --- BİYOLOJİ ---
        {
            "subjectCode": "BIYOLOJI", "subjectName": "Biyoloji", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Yaşam Bilimi Biyoloji", "BYL.9.1", ["Canlıların ortak özelliklerini açıklar.", "İnorganik ve organik bileşiklerin canlılar için önemini analiz eder.", "Enzimlerin yapısını ve çalışmasına etki eden faktörleri inceler."]),
                    ("2. Tema: Hücre ve Madde Geçişleri", "BYL.9.2", ["Prokaryot ve ökaryot hücre yapılarını organellerle karşılaştırır.", "Pasif taşıma (difüzyon, ozmoz) ve aktif taşıma mekanizmalarını modeller."]),
                    ("3. Tema: Canlılar Dünyası ve Sınıflandırma", "BYL.9.3", ["Sınıflandırma basamaklarını ve ikili adlandırma kuralını uygular.", "Bakteriler, Arkeler, Protistler, Bitkiler, Mantarlar ve Hayvanlar alemini inceler."])
                ],
                10: [
                    ("1. Tema: Hücre Bölünmeleri", "BYL.10.1", ["Mitoz bölünmenin evrelerini ve eşeysiz üreme çeşitlerini açıklar.", "Mayoz bölünmenin evrelerini ve genetik çeşitlilikle ilişkisini modeller."]),
                    ("2. Tema: Kalıtımın Genel İlkeleri", "BYL.10.2", ["Mendel ilkelerini, monohibrit ve dihibrit çaprazlamaları uygular.", "Eş baskınlık, çok alellilik ve kan grupları kalıtımını çözer.", "Cinsiyete bağlı kalıtım ve soyağacı analizleri yapar."]),
                    ("3. Tema: Ekosistem Ekolojisi ve Çevre", "BYL.10.3", ["Besin zinciri, enerji piramidi ve madde döngülerini açıklar.", "Biyoçeşitliliğin korunması ve çevre kirliliğiyle mücadeleyi değerlendirir."])
                ],
                11: [
                    ("1. Tema: İnsan Fizyolojisi (Sistemler)", "BYL.11.1", ["Sinir sistemi, endokrin sistem ve duyu organlarının işleyişini modeller.", "Destek-hareket, sindirim, dolaşım ve bağışıklık sistemini analiz eder.", "Solunum, boşaltım ve üreme sistemlerinin homeostazi ilişkisini açıklar."]),
                    ("2. Tema: Komünite ve Popülasyon Ekolojisi", "BYL.11.2", ["Komünitede tür içi ve türler arası rekabet/simbiyotik ilişkileri açıklar.", "Popülasyon büyüme eğrilerini ve taşıma kapasitesini inceler."])
                ],
                12: [
                    ("1. Tema: Genden Proteine", "BYL.12.1", ["DNA ve RNA'nın yapısını, replikasyon sürecini açıklar.", "Genetik şifre, transkripsiyon ve translasyon ile protein sentezini modeller.", "Biyoteknoloji ve gen mühendisliği uygulamalarını değerlendirir."]),
                    ("2. Tema: Canlılarda Enerji Dönüşümleri", "BYL.12.2", ["Fotosentez ve kemosentez tepkimelerini ışığa bağımlı/bağımsız olarak açıklar.", "Oksijenli, oksijensiz solunum ve fermantasyon süreçlerini karşılaştırır."]),
                    ("3. Tema: Bitki Biyolojisi", "BYL.12.3", ["Bitkisel dokuları, organları ve su/besin taşınım mekanizmalarını açıklar.", "Bitkilerde hormonlar ve hareket tepkilerini inceler."])
                ]
            }
        },

        # --- TÜRK DİLİ VE EDEBİYATI ---
        {
            "subjectCode": "EDEBIYAT", "subjectName": "Türk Dili ve Edebiyatı", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Giriş ve Edebiyatın Doğası", "EDB.9.1", ["Edebiyatın bilimlerle ilişkisini ve güzel sanatlar içindeki yerini açıklar.", "İletişim ögelerini ve dilin işlevlerini metinler üzerinde gösterir."]),
                    ("2. Tema: Hikâye (Öykü)", "EDB.9.2", ["Olay ve durum hikâyesinin yapı unsurlarını (olay, kişi, zaman, mekân) çözümler.", "Metindeki anlatım biçimleri ve düşünceyi geliştirme yollarını belirler."]),
                    ("3. Tema: Şiir ve Nazım Biçimleri", "EDB.9.3", ["Şiirde tema, imge, ahenk unsurları (ölçü, uyak, redif) ve söz sanatlarını analiz eder."]),
                    ("4. Tema: Masal, Fabl ve Roman", "EDB.9.4", ["Masal ve fabl türünün özelliklerini karşılaştırır.", "Roman türünün yapı unsurlarını ve bakış açılarını inceler."]),
                    ("5. Tema: Tiyatro ve Öğretici Metinler", "EDB.9.5", ["Tiyatro türlerini (trajedi, komedi, dram) ve öğretici metinleri (biyografi, mektup, günlük) inceler."])
                ],
                10: [
                    ("1. Tema: Türk Edebiyatının Tarihî Dönemleri", "EDB.10.1", ["Türk edebiyatının dönemlerini (İslamiyet Öncesi, İslami Dönem, Batı Etkisinde) sınıflandırır."]),
                    ("2. Tema: Hikâye ve Destan Geleneği", "EDB.10.2", ["Dede Korkut Hikâyeleri, Halk Hikâyeleri ve Mesnevileri çözümler.", "Türk ve Dünya destanlarının mitolojik ögelerini karşılaştırır."]),
                    ("3. Tema: İslamiyet Etkisindeki Türk Şiiri", "EDB.10.3", ["Geçiş dönemi eserlerini (Kutadgu Bilig, Divanü Lugati't-Türk) çözümler.", "Halk şiiri (Koşma, Semai, İlahi) ve Divan şiiri (Gazel, Kaside, Şarkı) nazım biçimlerini tahlil eder."]),
                    ("4. Tema: Tanzimat'tan Cumhuriyete Roman ve Tiyatro", "EDB.10.4", ["Geleneksel Türk tiyatrosu (Karagöz, Orta Oyunu) ile modern tiyatroyu karşılaştırır.", "Tanzimat ve Servet-i Fünun dönemi romanlarının tematik özelliklerini çözümler."])
                ],
                11: [
                    ("1. Tema: 19. Yüzyıl Batı Etkisinde Türk Şiiri", "EDB.11.1", ["Tanzimat, Servet-i Fünun ve Millî Edebiyat dönemi şiir anlayışlarını karşılaştırır.", "Şiir akımlarını (Romantizm, Sembolizm, Parnasizm) metinler üzerinde inceler."]),
                    ("2. Tema: Millî Edebiyat ve Cumhuriyet Romanı", "EDB.11.2", ["Millî Edebiyat ve Cumhuriyet'in ilk yıllarındaki romanları tema ve kurgu yönünden inceler."]),
                    ("3. Tema: Öğretici Metinler ve Tiyatro", "EDB.11.3", ["Makale, fıkra, sohbet ve eleştiri türlerinin özelliklerini çözümler.", "Cumhuriyet Dönemi tiyatrosunun toplumsal ve bireysel temalarını analiz eder."])
                ],
                12: [
                    ("1. Tema: Cumhuriyet Dönemi Türk Şiiri", "EDB.12.1", ["Saf şiir, toplumcu gerçekçi şiir, Garip akımı ve İkinci Yeni şiirini karşılaştırır.", "1980 sonrası Türk şiirinin tematik yönelimlerini çözümler."]),
                    ("2. Tema: Cumhuriyet Dönemi Roman ve Hikâyesi", "EDB.12.2", ["Bireyin iç dünyasını esas alan, toplumcu gerçekçi ve modernist romanları çözümler."]),
                    ("3. Tema: Deneme, Söylev ve Dünya Edebiyatı", "EDB.12.3", ["Deneme ve söylev türünün dilsel özelliklerini analiz eder.", "Dünya edebiyatının başyapıtlarını evrensel temalar açısından yorumlar."])
                ]
            }
        },

        # --- TARİH & İNKILAP TARİHİ ---
        {
            "subjectCode": "TARIH", "subjectName": "Tarih", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Tarih ve Zaman", "TAR.9.1", ["Tarih biliminin yöntemini, kaynaklarını ve takvim sistemlerini açıklar."]),
                    ("2. Tema: İnsanlığın İlk Dönemleri ve Orta Çağ", "TAR.9.2", ["İlk Çağ medeniyetlerinin siyasi, hukuki ve ekonomik yapılarını inceler.", "Orta Çağ'da feodalite, imparatorluklar ve ticaret yollarını analiz eder."]),
                    ("3. Tema: İlk ve Orta Çağlarda Türk Dünyası", "TAR.9.3", ["Orta Asya Türk devletlerinin teşkilat yapısını, ordu ve kut anlayışını açıklar."]),
                    ("4. Tema: İslam Medeniyetinin Doğuşu ve Türkler", "TAR.9.4", ["Dört Halife ve Emevi-Abbasi dönemlerinin siyasi/kültürel mirasını açıklar.", "Türklerin İslamiyet'i kabulü ve ilk Türk İslam devletlerini (Karahanlı, Gazneli, Selçuklu) çözümler."])
                ],
                10: [
                    ("1. Tema: Selçuklu Türkiyesi ve Osmanlı'nın Kuruluşu", "TAR.10.1", ["Anadolu Selçuklu Devleti'nin teşkilatını ve Haçlı Seferleri'nin etkilerini çözümler.", "Osmanlı Beyliği'nin kuruluş dinamiklerini ve gaza politikasını analiz eder."]),
                    ("2. Tema: Dünya Gücü Osmanlı Devleti", "TAR.10.2", ["İstanbul'un fethinin sonuçlarını ve Fatih-Yavuz-Kanuni dönemlerini inceler.", "Osmanlı merkez ve taşra teşkilatını, tımar sistemini ve yeniçeri ocağını açıklar."]),
                    ("3. Tema: Klasik Çağ Osmanlı Medeniyeti", "TAR.10.3", ["Osmanlı'da hukuk, eğitim (medrese), mimari ve tasavvufi hayatı inceler."])
                ],
                11: [
                    ("1. Tema: Değişen Dünya Dengeleri ve Osmanlı", "TAR.11.1", ["17. ve 18. yüzyılda Osmanlı'nın diplomasi ve savaş stratejilerini analiz eder."]),
                    ("2. Tema: Değişim Çağında Avrupa ve Islahatlar", "TAR.11.2", ["Coğrafi Keşifler, Rönesans, Reform ve Sanayi Devrimi'nin Osmanlı'ya etkilerini açıklar.", "Osmanlı'da Lale Devri ve 18. yüzyıl ıslahat hareketlerini değerlendirir."]),
                    ("3. Tema: 19. Yüzyıl Denge Stratejisi ve Meşrutiyet", "TAR.11.3", ["Tanzimat ve Islahat Fermanları ile I. ve II. Meşrutiyet süreçlerini demokratikleşme açısından açıklar."])
                ],
                12: [
                    ("1. Tema: 20. Yüzyıl Başlarında Osmanlı ve Millî Mücadele", "TAR.12.1", ["Trablusgarp, Balkan ve I. Dünya Savaşı'nın sebeplerini ve cephelerini inceler.", "Kuvâ-yı Millîye, Amasya Genelgesi, Erzurum ve Sivas Kongreleri ile TBMM'nin açılışını analiz eder."]),
                    ("2. Tema: Kurtuluş Savaşı ve Mudanya-Lozan", "TAR.12.2", ["Doğu, Güney ve Batı Cephesi muharebelerini (Sakarya, Büyük Taarruz) açıklar.", "Lozan Barış Antlaşması'nın uluslararası kazanımlarını değerlendirir."]),
                    ("3. Tema: Atatürkçülük ve Türk İnkılabı", "TAR.12.3", ["Atatürk ilkelerini (Cumhuriyetçilik, Milliyetçilik, Halkçılık, Devletçilik, Laiklik, İnkılapçılık) açıklar.", "Siyasi, hukuki, eğitim ve toplumsal alandaki inkılapları analiz eder."])
                ]
            }
        },

        # --- COĞRAFYA ---
        {
            "subjectCode": "COGRAFYA", "subjectName": "Coğrafya", "grades": [9, 10], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Doğa ve İnsan & Harita Bilgisi", "COG.9.1", ["Coğrafyanın bölümlerini ve harita projeksiyonları/ölçek hesaplarını uygular.", "İzohips yöntemini ve coğrafi koordinat sistemini analiz eder."]),
                    ("2. Tema: Dünya'nın Şekli ve Hareketleri", "COG.9.2", ["Dünya'nın eksen eğikliği, yıllık hareketi ve mevsimlerin oluşumunu modeller."]),
                    ("3. Tema: İklim Bilgisi (Atmosfer ve Sıcaklık)", "COG.9.3", ["Sıcaklık, basınç, rüzgârlar, nem ve yağış oluşumunu grafiklerle inceler.", "Büyük iklim tiplerini ve Türkiye'nin iklim özelliklerini karşılaştırır."]),
                    ("4. Tema: Beşerî Sistemler ve Yerleşme", "COG.9.4", ["İlk yerleşmelerin kuruluş yerlerini ve yerleşmeyi etkileyen faktörleri açıklar."])
                ],
                10: [
                    ("1. Tema: Dünya'nın Yapısı ve İç/Dış Kuvvetler", "COG.10.1", ["Levha tektoniğini, orojenez, epirojenez, volkanizma ve depremleri inceler.", "Akarsu, rüzgâr, buzul ve dalga şekillerini Türkiye haritası üzerinde modeller."]),
                    ("2. Tema: Türkiye'nin Su, Toprak ve Bitki Varlığı", "COG.10.2", ["Türkiye'nin akarsu, göl ve yeraltı sularını, toprak ve bitki örtüsünü inceler."]),
                    ("3. Tema: Nüfus, Göç ve Doğal Afetler", "COG.10.3", ["Nüfus piramitlerini yorumlar ve göç türlerinin ekonomik/sosyal etkilerini analiz eder.", "Doğal afet türlerini ve afet yönetim süreçlerini değerlendirir."])
                ]
            }
        },

        # --- FELSEFE ---
        {
            "subjectCode": "FELSEFE", "subjectName": "Felsefe", "grades": [10, 11], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                10: [
                    ("1. Tema: Felsefeyi Tanıma ve Düşünme", "FEL.10.1", ["Felsefi düşüncenin özelliklerini (refleksif, tutarlı, eleştirel) açıklar.", "Akıl yürütme yöntemlerini (tümdengelim, tümevarım, analoji) analiz eder."]),
                    ("2. Tema: Varlık ve Bilgi Felsefesi", "FEL.10.2", ["Ontoloji ve epistemolojinin temel problemlerini, realizm, idealizm, rasyonalizm ve empirizm akımlarını karşılaştırır."]),
                    ("3. Tema: Ahlak, Din, Siyaset ve Sanat Felsefesi", "FEL.10.3", ["Ahlak felsefesinde iyi-kötü ve özgürlük kavramlarını, siyasette meşruiyet ve ütopya kavramlarını inceler."])
                ],
                11: [
                    ("1. Tema: İlk Çağ ve Orta Çağ Felsefesi", "FEL.11.1", ["Sokrates, Platon ve Aristoteles'in felsefi görüşlerini çözümler.", "Patristik ve Skolastik felsefe ile İslam felsefesinin (Farabi, İbn Sina, Gazali, İbn Rüşd) katkılarını analiz eder."]),
                    ("2. Tema: Rönesans ve 17-18. Yüzyıl Aydınlanma Felsefesi", "FEL.11.2", ["Descartes, Spinoza, Locke, Kant ve Hegel'in bilgi ve toplum anlayışlarını karşılaştırır."]),
                    ("3. Tema: 19 ve 20. Yüzyıl Felsefesi", "FEL.11.3", ["Pozitivizm, Marksizm, Egzistansiyalizm ve Hermeneutik akımlarını değerlendirir."])
                ]
            }
        },

        # --- MATEMATİK (LİSE) ---
        {
            "subjectCode": "MAT", "subjectName": "Matematik", "grades": [9, 10, 11, 12], "category": "core", "publisher": "MEB Yayınları",
            "themes": {
                9: [
                    ("1. Tema: Mantık ve Kümeler", "MAT.9.1", ["Önermeleri, bileşik önermeleri ve doğruluk tablolarını açıklar.", "Kümelerde işlemler, kartezyen çarpım ve küme problemlerini çözer."]),
                    ("2. Tema: Sayı Kümeleri ve Denklem/Eşitsizlikler", "MAT.9.2", ["Bölünebilme kuralları, EBOB-EKOK problemlerini modeller.", "Birinci dereceden bir ve iki bilinmeyenli denklem/eşitsizlikleri çözer.", "Mutlak değerli denklem ve eşitsizlikleri analiz eder."]),
                    ("3. Tema: Üslü ve Köklü İfadeler & Oran-Orantı", "MAT.9.3", ["Üslü ve köklü sayı işlemlerini uygular.", "Doğru, ters ve bileşik orantı problemlerini çözer."]),
                    ("4. Tema: Üçgenler ve Geometri", "MAT.9.4", ["Üçgende açılar, açı-kenar bağıntıları ve eşlik/benzerlik kurallarını uygular.", "Pisagor ve Öklid teoremleri ile trigonometrik oranları hesaplar."])
                ],
                10: [
                    ("1. Tema: Sayma ve Olasılık", "MAT.10.1", ["Toplama ve çarpma yoluyla sayma, permütasyon ve kombinasyon hesaplar.", "Binom açılımını ve basit/koşullu olasılık problemlerini çözer."]),
                    ("2. Tema: Fonksiyonlar", "MAT.10.2", ["Fonksiyon tanımı, çeşitleri (bire bir, örten, sabit, birim) ve grafiklerini çizer.", "Bileşke fonksiyon ve ters fonksiyon işlemlerini modeller."]),
                    ("3. Tema: Polinomlar ve İkinci Dereceden Denklemler", "MAT.10.3", ["Polinomlarda bölme ve çarpanlara ayırma yöntemlerini uygular.", "İkinci dereceden denklemlerin köklerini ve karmaşık sayıları çözümler."]),
                    ("4. Tema: Dörtgenler ve Çokgenler", "MAT.10.4", ["Düzgün çokgenler, yamuk, paralelkenar, eşkenar dörtgen, dikdörtgen, kare ve deltoid alan hesaplamaları yapar."])
                ],
                11: [
                    ("1. Tema: Trigonometri", "MAT.11.1", ["Yönlü açılar, birim çember ve trigonometrik fonksiyonları modeller.", "Sinüs ve kosinüs teoremleri ile trigonometrik grafik ve denklemleri çözer."]),
                    ("2. Tema: Analitik Geometri", "MAT.11.2", ["İki nokta arası uzaklık, doğru denklemi ve doğrunun analitik incelemesini yapar."]),
                    ("3. Tema: Fonksiyonlarda Uygulamalar ve İkinci Dereceden Eşitsizlikler", "MAT.11.3", ["Parabol denklemleri ve tepe noktası grafiklerini çizer.", "İkinci dereceden eşitsizlik sistemlerini işaret tablolarıyla çözer."]),
                    ("4. Tema: Çember ve Daire", "MAT.11.4", ["Çemberde açılar, teğet-kiriş özellikleri ve dairede alan hesaplar."])
                ],
                12: [
                    ("1. Tema: Üstel ve Logaritmik Fonksiyonlar", "MAT.12.1", ["Üstel fonksiyonları ve logaritma özelliklerini modeller.", "Logaritmalı denklem/eşitsizlikleri ve gerçek hayat problemlerini çözer."]),
                    ("2. Tema: Diziler", "MAT.12.2", ["Aritmetik ve geometrik dizi genel terim ve toplam formüllerini uygular."]),
                    ("3. Tema: Türev ve Uygulamaları", "MAT.12.3", ["Limit ve süreklilik kavramını açıklar.", "Türev alma kurallarını, teğet denklemini ve maksimum-minimum problemlerini çözer."]),
                    ("4. Tema: İntegral ve Alan Hesabı", "MAT.12.4", ["Belirsiz ve belirli integral hesaplar.", "Eğriler altında kalan alanı integral yardımıyla modeller."])
                ]
            }
        }
    ]

    def generate_maarif_pedagogical_meta(subject_code, grade, unit_title, topic_title, outcome_desc, is_otp=False, is_soc=False, is_hol=False):
        if is_hol:
            return {
                "maarifSummary": "Bu hafta MEB resmî çalışma takvimi uyarınca eğitim öğretime ara verilmiştir.",
                "maarifValues": "Dinlenme, Aile Bağı",
                "maarifSkills": "SDB1.1 Öz Farkındalık",
                "differentiation": "Öğrencilerin serbest okuma ve kültürel etkinliklerle dinlenmesi tavsiye edilir."
            }
        if is_soc:
            return {
                "maarifSummary": "MEB Sosyal Etkinlikler Haftası: Dönem sonu bilimsel, sanatsal, sportif ve kültürel etkinliklerle okul iklimi ve aidiyet pekiştirilir.",
                "maarifValues": "İş Birliği, Paylaşım, Estetik, Vatanseverlik",
                "maarifSkills": "SDB2.2 Toplumsal Katılım, SDB2.3 Takım Çalışması",
                "differentiation": "Öğrenci ilgi ve yeteneklerine göre kulüp ve grup bazlı serbest etkinlikler düzenlenir."
            }
        if is_otp:
            return {
                "maarifSummary": "Okul Temelli Planlama (OTP) Haftası: Okulun imkânları, yerel çevre şartları ve zümre kararları doğrultusunda derinleştirme veya telafi çalışmaları yürütülür.",
                "maarifValues": "Sorumluluk, Öz Denetim, Dayanışma",
                "maarifSkills": "KB2.10 Problem Çözme, AB1 Bilimsel Sorgulama",
                "differentiation": "Geri bildirim temelli bireysel destek veya ileri düzey zenginleştirme görevleri verilir."
            }

        # Branşa göre pedagojik sentez
        sub = (subject_code or "").upper()
        topic = topic_title or unit_title or "Konu"

        if sub in ["KIMYA", "FIZIK", "BIYOLOJI", "FEN"]:
            summary = f"Bu hafta '{topic}' konusu; bilimsel sorgulama, deney/modelleme ve günlük hayat bağlantıları kurularak işlenir. Öğrencilerin hipotez kurma ve sebep-sonuç ilişkilerini analiz etmesi hedeflenir."
            values = "Bilimsellik, Doğa Sevgisi, Merak, Sorumluluk"
            skills = "AB1 Bilimsel Sorgulama, KB2.4 Çözümleme, KB2.6 Bilgi Toplama"
            diff = "Görsel modeller, animasyonlar ve kavram haritalarıyla somutlaştırma sağlanır."
        elif sub in ["TURKCE", "EDEBIYAT", "YAZARLIK"]:
            summary = f"Bu hafta '{topic}' konusu; metin tahlili, eleştirel okuma ve yaratıcı yazma teknikleriyle işlenir. Dil zevki, kelime dağarcığı ve kendini doğru ifade etme becerisi ön plandadır."
            values = "Estetik, Vatanseverlik, Duyarlılık, Nezaket"
            skills = "AB3 Eleştirel Okuma, KB2.15 İfade Etme, SDB1.2 İletişim"
            diff = "Farklı seviyelerdeki metinler ve sesli/görsel canlandırma teknikleriyle desteklenir."
        elif sub in ["MAT"]:
            summary = f"Bu hafta '{topic}' konusu; somut materyaller, görselleştirmeler ve gerçek hayat problemleriyle modellenir. Mantıksal akıl yürütme ve problem çözme stratejileri geliştirilir."
            values = "Sabır, Akıl Yürütme, Çalışkanlık, Tutarlılık"
            skills = "KB2.10 Matematiksel Modelleme, AB2 Akıl Yürütme, KB2.3 Karşılaştırma"
            diff = "Kademeli zorluk seviyesindeki problem setleri ve somut manipülatiflerle zenginleştirilir."
        elif sub in ["TARIH", "SOSYAL", "INKILAP"]:
            summary = f"Bu hafta '{topic}' konusu; tarihsel empati, birincil kaynak analizi ve kronolojik düşünme yöntemleriyle işlenir. Millî bilinç ve vatandaşlık sorumluluğu pekiştirilir."
            values = "Vatanseverlik, Adalet, Tarih Bilinci, Sorumluluk"
            skills = "AB4 Tarihsel Empati, KB2.8 Kanıt Kullanma, SDB2.2 Toplumsal Katılım"
            diff = "Tarihsel harita, görsel belge ve dijital arşiv incelemeleriyle desteklenir."
        elif sub in ["COGRAFYA"]:
            summary = f"Bu hafta '{topic}' konusu; harita okuryazarlığı, mekânsal düşünme ve doğa-insan etkileşimi ekseninde incelenir. Çevre duyarlılığı ve sürdürülebilirlik vurgulanır."
            values = "Çevre Bilinci, Doğa Sevgisi, Sorumluluk, Sürdürülebilirlik"
            skills = "AB5 Mekânsal Düşünme, KB2.14 Harita Okuma, SDB2.1 Çevre Duyarlılığı"
            diff = "Tematik haritalar, CBS görselleri ve arazi gözlemleriyle zenginleştirilir."
        elif sub in ["FELSEFE"]:
            summary = f"Bu hafta '{topic}' konusu; felsefi sorgulama, kavramsal analiz ve argümantasyon yöntemleriyle ele alınır. Eleştirel ve tutarlı düşünme disiplini geliştirilir."
            values = "Eleştirel Düşünme, Merak, Dürüstlük, Hoşgörü"
            skills = "KB2.7 Argümantasyon, KB2.1 Analiz, SDB1.1 Öz Farkındalık"
            diff = "Sokratesçi diyalog ve vaka tartışmalarıyla fikir üretimi teşvik edilir."
        elif sub in ["BILISIM", "HAREZMI", "TEKNO_TASARIM"]:
            summary = f"Bu hafta '{topic}' konusu; algoritmik düşünme, tasarım odaklı problem çözme ve dijital üretim etkinlikleriyle uygulamalı olarak işlenir."
            values = "Dijital Etik, Üretkenlik, İş Birliği, Sorumluluk"
            skills = "AB6 Algoritmik Düşünme, KB2.16 Dijital Üretim, SDB2.3 Takım Çalışması"
            diff = "Aşamalı blok/metin kodlama görevleri ve proje temelli grup çalışmalarıyla uygulanır."
        elif sub in ["DIN", "KURAN", "PEYGAMBER", "ARAPCA"]:
            summary = f"Bu hafta '{topic}' konusu; ahlaki erdemler, evrensel değerler ve toplumsal dayanışma ilkeleri odağında hayatla bağ kurularak işlenir."
            values = "Adalet, Merhamet, Dürüstlük, Yardımlaşma, Saygı"
            skills = "AB7 Ahlaki Muhakeme, SDB1.3 Empati, KB2.2 Yorumlama"
            diff = "Örnek olay incelemeleri ve hikâyeleme yöntemleriyle kavratılır."
        elif sub in ["INGILIZCE", "ALMANCA"]:
            summary = f"Bu hafta '{topic}' konusu; iletişimsel yaklaşım, interaktif diyaloglar ve bağlamsal kelime kullanımıyla 4 temel dil becerisi dengelenerek işlenir."
            values = "Kültürel Farkındalık, İletişim, Özgüven, Hoşgörü"
            skills = "AB8 İletişimsel Yeterlilik, SDB1.2 Etkileşim, KB2.5 Dinleme-Konuşma"
            diff = "Rol oynama (role-play), görsel flashcard'lar ve dijital dinleme etkinlikleriyle desteklenir."
        elif sub in ["BEDEN", "GORSEL", "MUZIK", "SAGLIK"]:
            summary = f"Bu hafta '{topic}' konusu; bedensel koordinasyon, estetik algı ve yaratıcı ifade teknikleriyle uygulamalı ve dinamik olarak işlenir."
            values = "Estetik, Sağlıklı Yaşam, Disiplin, Saygı"
            skills = "AB9 Kinestetik ve Sanatsal Yeterlilik, SDB1.2 İfade Becerisi"
            diff = "Bireysel yetenek ve ritimlere uygun basamaklandırılmış egzersizlerle işlenir."
        else:
            summary = f"Bu hafta '{topic}' konusu; aktif öğrenme yöntemleri, soru-cevap ve öğrenci merkezli etkinliklerle Maarif Modeli felsefesine uygun olarak işlenir."
            values = "Sorumluluk, Merak, Çalışkanlık"
            skills = "KB2.10 Problem Çözme, KB2.4 Çözümleme"
            diff = "Görsel ve metinsel ek materyallerle çeşitlendirilir."

        return {
            "maarifSummary": summary,
            "maarifValues": values,
            "maarifSkills": skills,
            "differentiation": diff
        }

    def generate_high_school_outcomes():
        outcomes = []

        for course in HIGH_SCHOOL_COURSES:
            sub_code = course["subjectCode"]
            sub_name = course["subjectName"]
            category = course["category"]
            publisher = course["publisher"]

            for grade in course["grades"]:
                grade_themes = course["themes"].get(grade, [])
                if not grade_themes:
                    continue

                theme_idx = 0
                theme_sub_idx = 0

                for week_num in range(1, 40):
                    week_info = ACADEMIC_WEEKS_2026_2027.get(week_num, {})
                    date_str = week_info.get("formatted", f"{week_num}. Hafta (2026-2027)")

                    is_hol = week_info.get("is_holiday", False)
                    is_otp = week_info.get("is_otp", False)
                    is_soc = week_info.get("is_social_event", False)

                    if is_hol:
                        hol_title = week_info.get("holiday_note", "Resmî Tatil")
                        ped = generate_maarif_pedagogical_meta(sub_code, grade, hol_title, hol_title, "", is_hol=True)
                        outcomes.append({
                            "id": f"out_lise_{grade}_{sub_code}_w{week_num}",
                            "academicYear": "2026-2027",
                            "gradeLevel": grade,
                            "subjectCode": sub_code,
                            "subjectName": sub_name,
                            "publisher": publisher,
                            "fullTitle": f"{grade}. Sınıf {sub_name} ({publisher})",
                            "category": category,
                            "schoolType": "HIGH",
                            "isMaarif": True,
                            "weekNumber": week_num,
                            "dateRangeStr": date_str,
                            "unitTitle": hol_title,
                            "topicTitle": hol_title,
                            "outcomeCode": "TATIL",
                            "outcomeDescription": f"{hol_title} - Eğitim Öğretime Ara",
                            "isHolidayWeek": True,
                            "holidayNote": hol_title,
                            "isOtpWeek": False,
                            "isSocialEventWeek": False,
                            "maarifSummary": ped["maarifSummary"],
                            "maarifValues": ped["maarifValues"],
                            "maarifSkills": ped["maarifSkills"],
                            "differentiation": ped["differentiation"]
                        })
                    elif is_soc:
                        soc_title = "MEB Sosyal Etkinlikler ve Okul Kültürü Haftası"
                        ped = generate_maarif_pedagogical_meta(sub_code, grade, "Sosyal Etkinlikler", soc_title, "", is_soc=True)
                        outcomes.append({
                            "id": f"out_lise_{grade}_{sub_code}_w{week_num}",
                            "academicYear": "2026-2027",
                            "gradeLevel": grade,
                            "subjectCode": sub_code,
                            "subjectName": sub_name,
                            "publisher": publisher,
                            "fullTitle": f"{grade}. Sınıf {sub_name} ({publisher})",
                            "category": category,
                            "schoolType": "HIGH",
                            "isMaarif": True,
                            "weekNumber": week_num,
                            "dateRangeStr": date_str,
                            "unitTitle": "Sosyal Etkinlikler",
                            "topicTitle": "Sosyal, Kültürel ve Sanatsal Etkinlikler",
                            "outcomeCode": f"{sub_code}.{grade}.ETK",
                            "outcomeDescription": "Dönem sonu sosyal, kültürel, sanatsal ve bilimsel etkinlikler gerçekleştirilir.",
                            "isHolidayWeek": False,
                            "holidayNote": None,
                            "isOtpWeek": False,
                            "isSocialEventWeek": True,
                            "maarifSummary": ped["maarifSummary"],
                            "maarifValues": ped["maarifValues"],
                            "maarifSkills": ped["maarifSkills"],
                            "differentiation": ped["differentiation"]
                        })
                    else:
                        cur_theme_tuple = grade_themes[theme_idx % len(grade_themes)]
                        theme_title = cur_theme_tuple[0]
                        base_code = cur_theme_tuple[1]
                        kazanim_list = cur_theme_tuple[2]

                        cur_kazanim = kazanim_list[theme_sub_idx % len(kazanim_list)]
                        outcome_code = f"{base_code}.{theme_sub_idx + 1}"
                        topic_title = theme_title.split(":")[-1].strip() if ":" in theme_title else theme_title

                        ped = generate_maarif_pedagogical_meta(sub_code, grade, theme_title, topic_title, cur_kazanim, is_otp=is_otp)

                        outcomes.append({
                            "id": f"out_lise_{grade}_{sub_code}_w{week_num}",
                            "academicYear": "2026-2027",
                            "gradeLevel": grade,
                            "subjectCode": sub_code,
                            "subjectName": sub_name,
                            "publisher": publisher,
                            "fullTitle": f"{grade}. Sınıf {sub_name} ({publisher})",
                            "category": category,
                            "schoolType": "HIGH",
                            "isMaarif": True,
                            "weekNumber": week_num,
                            "dateRangeStr": date_str,
                            "unitTitle": theme_title,
                            "topicTitle": topic_title,
                            "outcomeCode": outcome_code,
                            "outcomeDescription": cur_kazanim,
                            "isHolidayWeek": False,
                            "holidayNote": None,
                            "isOtpWeek": is_otp,
                            "isSocialEventWeek": False,
                            "maarifSummary": ped["maarifSummary"],
                            "maarifValues": ped["maarifValues"],
                            "maarifSkills": ped["maarifSkills"],
                            "differentiation": ped["differentiation"]
                        })

                        theme_sub_idx += 1
                        if theme_sub_idx >= len(kazanim_list):
                            theme_sub_idx = 0
                            theme_idx += 1

        return outcomes

    def main():
        print("🚀 Maarif Müfredat Pipeline Başlatılıyor (Pedagojik Zenginleştirme)...")

        existing_outcomes = []
        if os.path.exists(OUTPUT_JSON):
            with open(OUTPUT_JSON, "r", encoding="utf-8") as f:
                existing_outcomes = json.load(f)
            print(f"📦 Mevcut Kayıt Sayısı: {len(existing_outcomes)}")

        # 1-8. sınıf kayıtlarını da Maarif pedagojik alanlarıyla zenginleştir
        filtered_existing = [o for o in existing_outcomes if o.get("gradeLevel", 0) < 9]
        for item in filtered_existing:
            g = item.get("gradeLevel", 5)
            sub = item.get("subjectCode", "GENEL")
            unit = item.get("unitTitle", "")
            topic = item.get("topicTitle", "")
            desc = item.get("outcomeDescription", "")
            is_hol = item.get("isHolidayWeek", False)
            is_soc = item.get("isSocialEventWeek", False)
            is_otp = item.get("isOtpWeek", False)

            if not item.get("schoolType"):
                item["schoolType"] = "PRIMARY" if g <= 4 else "MIDDLE"

            ped = generate_maarif_pedagogical_meta(sub, g, unit, topic, desc, is_otp=is_otp, is_soc=is_soc, is_hol=is_hol)
            item["maarifSummary"] = item.get("maarifSummary") or ped["maarifSummary"]
            item["maarifValues"] = item.get("maarifValues") or ped["maarifValues"]
            item["maarifSkills"] = item.get("maarifSkills") or ped["maarifSkills"]
            item["differentiation"] = item.get("differentiation") or ped["differentiation"]

        lise_outcomes = generate_high_school_outcomes()
        print(f"🎓 Üretilen Lise (9-12) Maarif Kayıt Sayısı: {len(lise_outcomes)}")

        unified = filtered_existing + lise_outcomes
        print(f"🌟 Toplam Birleşik MEB Maarif Kayıt Sayısı: {len(unified)}")

        with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
            json.dump(unified, f, ensure_ascii=False, indent=2)
        print(f"✅ Master JSON kaydedildi: {OUTPUT_JSON}")

        js_output_path = os.path.join(os.path.dirname(__file__), "..", "admin_portal", "js", "curriculum_presets.js")
        with open(js_output_path, "w", encoding="utf-8") as f:
            f.write("/**\n")
            f.write(" * SınıfCepte - MEB Maarif Modeli Resmî Kazanım ve Yıllık Plan Veri Paketi\n")
            f.write(f" * Toplam Kayıt: {len(unified)} | 1-12. Sınıflar Tüm Branşlar\n")
            f.write(" */\n\n")
            f.write("window.OFFICIAL_MAARIF_OUTCOMES_PRESET = ")
            f.write(json.dumps(unified, ensure_ascii=False, indent=2))
            f.write(";\n\n")
            f.write("class CurriculumPresets {\n")
            f.write("  static getAllOfficialPresets() {\n")
            f.write("    return window.OFFICIAL_MAARIF_OUTCOMES_PRESET || [];\n")
            f.write("  }\n")
            f.write("}\n")
            f.write("window.CurriculumPresets = CurriculumPresets;\n")
        print(f"✅ JS Presets kaydedildi: {js_output_path}")

    if __name__ == "__main__":
        main()

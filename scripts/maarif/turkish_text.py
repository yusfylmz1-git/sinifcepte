"""
SınıfCepte - Türkçe metin normalizasyonu ve branş kodu tespiti.

Python'un str.lower() metodu Türkçe 'İ' harfini 'i' + U+0307 (birleşen
nokta) olarak küçültür. Bu yüzden ham `"İNGİLİZCE".lower()` içinde
`"ingilizce"` aranınca sonuç False döner. Boru hattındaki branş tespiti
tam olarak bu nedenle İngilizce ve İnkılap Tarihi derslerini "GENEL"
kovasına atıyordu; bu da doküman kimliklerinin çakışmasına yol açıyordu.

`fold()` hem bu birleşen noktayı hem de Türkçe'ye özgü harfleri
ASCII karşılıklarına indirger, böylece anahtar kelime araması güvenli olur.
"""

from __future__ import annotations

import re
import unicodedata

# Küçültmeden ÖNCE uygulanır: 'İ' -> 'i', 'I' -> 'ı' (Türkçe kuralı)
_UPPER_MAP = str.maketrans({"İ": "i", "I": "ı"})

# Küçültmeden SONRA uygulanır: aksanları ASCII'ye indirger
_FOLD_MAP = str.maketrans({
    "ı": "i", "ğ": "g", "ü": "u", "ş": "s", "ö": "o", "ç": "c", "â": "a",
    "î": "i", "û": "u",
})


def turkish_lower(text: str) -> str:
    """Türkçe kurallarına uyan küçük harfe çevirme."""
    if not text:
        return ""
    return text.translate(_UPPER_MAP).lower()


def fold(text: str) -> str:
    """Anahtar kelime karşılaştırması için ASCII'ye indirgenmiş biçim.

    'T.C. İNKILAP TARİHİ' -> 't.c. inkilap tarihi'
    """
    if not text:
        return ""
    lowered = turkish_lower(text)
    # lower() bazı girdilerde birleşen nokta (U+0307) bırakır; ayıklanır.
    lowered = unicodedata.normalize("NFD", lowered)
    lowered = "".join(ch for ch in lowered if ch != "̇")
    lowered = unicodedata.normalize("NFC", lowered)
    return lowered.translate(_FOLD_MAP)


def slugify(text: str) -> str:
    """Doküman kimliğinde kullanılabilir güvenli anahtar."""
    folded = fold(text)
    slug = re.sub(r"[^a-z0-9]+", "_", folded).strip("_")
    return slug or "genel"


# Sıra ÖNEMLİ: daha özel eşleşmeler önce denenir. Örneğin "Türk Dili ve
# Edebiyatı" hem 'turkce' hem 'edebiyat' içerebileceğinden edebiyat önce gelir;
# "T.C. İnkılap Tarihi" hem 'tarih' hem 'inkilap' içerdiğinden inkilap önce gelir.
SUBJECT_RULES: list[tuple[str, tuple[str, ...]]] = [
    # İHÖ dersleri DIN kovasına düşmeden önce yakalanır. Her biri ayrı
    # bir derstir ve ayrı kod almalıdır: aynı koda toplanınca doküman
    # kimlikleri (sinif_kod_yayinevi_hafta) çakışıyor ve kayıtlar
    # birbirini eziyordu.
    ("KURAN_ANLAM", ("kur'an'in anlam dunyasi", "kuranin anlam dunyasi",
                     "kuran anlam dunyasi")),
    ("KURAN", ("kur'an-i kerim", "kurani kerim", "kur'an")),
    ("PEYGAMBER", ("peygamberimizin hayati", "peygamber")),
    ("SIYER", ("siyer",)),
    ("FIKIH", ("fikih",)),
    ("HADIS", ("hadis",)),
    ("TEFSIR", ("tefsir",)),
    ("KELAM", ("kelam",)),
    ("AKAID", ("akaid",)),
    ("HITABET", ("hitabet",)),
    ("ISLAM_KULTUR", ("islam kultur",)),
    ("TEMEL_DINI", ("temel dini bilgiler", "temel dini")),
    ("AIHL_MESLEK", ("aihl meslek",)),
    ("ARAPCA", ("arapca",)),
    ("INKILAP", ("inkilap", "ataturkculuk")),
    ("EDEBIYAT", ("turk dili ve edebiyat", "edebiyat")),
    ("TURKCE", ("turkce",)),
    # Coklu Yabanci Dil Egitim Modeli SECILMIS okullarda okutuluyor.
    # Genel yabanci dil kurallarindan ONCE gelmeli: liste sirali
    # taraniyor ve "ingilizce" ipucu once eslesirse CYDEM dersi normal
    # dersle ayni koda duser, ikisi birbirini ezer.
    ("INGILIZCE_CYDEM", ("ingilizce (coklu yabanci dil)",)),
    ("ALMANCA_CYDEM", ("almanca (coklu yabanci dil)",)),
    ("INGILIZCE", ("ingilizce", "english")),
    ("ALMANCA", ("almanca", "deutsch")),
    ("FIZIK", ("fizik",)),
    ("KIMYA", ("kimya",)),
    ("BIYOLOJI", ("biyoloji",)),
    ("FEN", ("fen bilimleri", "fen bilgisi", "fen ve teknoloji", "fen")),
    ("COGRAFYA", ("cografya",)),
    ("TARIH", ("tarih",)),
    # Felsefe grubu dersleri ayrı ayrı okutulur ve öğrencinin ders
    # programında ayrı satırlardır; tek kovaya toplanmaları hem kimlik
    # çakışması hem yanlış filtreleme üretiyordu.
    ("PSIKOLOJI", ("psikoloji", "psiokoloji")),
    ("SOSYOLOJI", ("sosyoloji",)),
    ("MANTIK", ("mantik",)),
    ("SOSYAL_BILIM", ("sosyal bilim calismalari",)),
    ("FELSEFE", ("felsefe",)),
    ("SOSYAL", ("sosyal bilgiler", "vatandaslik")),
    ("HAYAT", ("hayat bilgisi",)),
    # Seçmeli dersler zorunlu derslerden ÖNCE yakalanmalı: aynı koda
    # düşerlerse doküman kimliği çakışıyor ve filtreleme bozuluyor
    # ("Matematik ve Bilim Uygulamaları" -> MAT, "Matematik" -> MAT).
    ("MAT_BILIM_UYG", ("matematik ve bilim uygulamalari",)),
    ("BILIM_UYG", ("bilim uygulamalari",)),
    ("MAT", ("matematik", "geometri")),
    ("BILISIM", ("bilisim", "yazilim", "kodlama", "bilgisayar")),
    ("HAREZMI", ("harezmi",)),
    ("TEKNO_TASARIM", ("teknoloji ve tasarim", "teknoloji tasarim")),
    # Yalnızca Din Kültürü ve Ahlak Bilgisi; diğer din dersleri yukarıda
    # kendi kodlarını alır.
    ("DIN", ("din kulturu", "ahlak bilgisi")),
    ("BEDEN_TEMEL", ("beden egitimi ve sporun temelleri",)),
    ("ATLETIK_PERF", ("cocuklarda atletik performans",)),
    # MEB bunlari AYRI ders olarak yayimliyor: 1-4'te "Beden Egitimi ve
    # Oyun", 5-12'de "Beden Egitimi ve Spor". Ayni koda duserlerse
    # benzersizlik anahtari bozulup birbirlerini eziyorlar.
    ("BEDEN_OYUN", ("beden egitimi ve oyun",)),
    ("BEDEN", ("beden egitimi", "spor", "oyun ve fiziki")),
    ("MUZIK", ("muzik",)),
    ("GORSEL", ("gorsel sanatlar", "resim")),
    ("REHBERLIK", ("rehberlik", "kariyer")),
    ("SAGLIK", ("saglik bilgisi", "trafik")),
]


def detect_subject_code(subject_name: str) -> str:
    """Ders adından branş kodunu çıkarır.

    Eşleşme bulunamazsa 'GENEL' yerine ders adından türetilmiş bir kod
    döner; böylece farklı dersler tek kovada birleşip doküman kimliği
    çakışmasına yol açmaz.
    """
    folded = fold(subject_name)
    if not folded.strip():
        return "GENEL"

    for code, keywords in SUBJECT_RULES:
        if any(keyword in folded for keyword in keywords):
            return code

    return slugify(subject_name).upper()[:24]


# MEB ortaokul/lise seçmeli ders adları. Bu liste panelin "Seçmeli"
# sekmesini besler; eksik olması sekmeyi boş bırakır.
ELECTIVE_HINTS = (
    "secmeli", "masal", "zeka oyun", "hukuk", "yazarlik", "medya okuryazar",
    "dusunme egitimi", "geleneksel sanatlar", "gorgu kurallari", "nezaket",
    "halk oyunlari", "okuma becerileri", "matematik ve bilim uygulamalari",
    "robotik kodlama", "yapay zeka uygulamalari", "trafik guvenligi",
    "spor ve fiziki etkinlikler", "cevre egitimi", "bilim uygulamalari",
    "insan haklari", "vatandaslik ve demokrasi", "coklu yabanci dil",
)
COURSE_HINTS = ("kurs", "dyk", "destekleme ve yetistirme", "telafi")
IHO_HINTS = ("arapca", "kuran", "kur'an", "siyer", "peygamber", "temel dini",
             "fikih", "tefsir", "hadis", "imam hatip", "osmanli turkcesi",
             # AİHL meslek dersleri (DÖGM çerçeve planları)
             "akaid", "kelam", "hitabet", "islam kultur", "aihl",
             "dinler tarihi", "mesleki arapca")
HAREZMI_HINTS = ("harezmi", "butunlesik", "proje tabanli",
                 "proje tasarimi ve uygulamalari")


def detect_category(subject_name: str) -> str:
    folded = fold(subject_name)
    if any(h in folded for h in COURSE_HINTS):
        return "course"
    if any(h in folded for h in HAREZMI_HINTS):
        return "harezmi"
    if any(h in folded for h in IHO_HINTS):
        return "iho"
    if any(h in folded for h in ELECTIVE_HINTS):
        return "elective"
    return "core"


def school_type_for_grade(grade: int) -> str:
    if grade <= 4:
        return "PRIMARY"
    if grade <= 8:
        return "MIDDLE"
    return "HIGH"

"""
SınıfCepte - MEB TYMM resmî taslak yıllık planlarını ham kayda çevirir.

    python scripts/maarif/import_tymm_plans.py

`fetch_tymm_plans.py` ile indirilen Excel planlarını okur. Bu planlar
MEB'in resmî haftalık dağılımını içerir; boru hattının 9-12. sınıf için
ihtiyaç duyduğu gerçek veri budur.

İki farklı sayfa düzeni destekleniyor:

  A) Yeni Maarif düzeni (dosyaların çoğu) - iki satırlık birleşik başlık:
     SÜRE | ÜNİTE/TEMA - İÇERİK ÇERÇEVESİ | ÖĞRENME ÇIKTILARI VE SÜREÇ
     BİLEŞENLERİ | ÖĞRENME KANITLARI | PROGRAMLAR ARASI BİLEŞENLER | ...
     alt başlıklar: AY | HAFTA | DERS SAATİ | ÜNİTE/TEMA | KONU |
     ÖĞRENME ÇIKTILARI | SÜREÇ BİLEŞENLERİ | ÖLÇME VE DEĞERLENDİRME |
     SDB | DEĞERLER | OKURYAZARLIK | BELİRLİ GÜN VE HAFTALAR | ...

  B) Klasik düzen (müzik 11-12): AY | HAFTA | DERS SAATİ | ÜNİTE | KONU |
     KAZANIM | KAZANIM AÇIKLAMASI | ...

Okul türü (Anadolu / Fen / Sosyal Bilimler Lisesi) dosya adından okunur ve
`publisher` alanına yazılır; böylece aynı sınıf-branşın farklı okul türü
planları birbirini ezmez.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys

# Windows konsolu cp1254'tür; Türkçe dosya adları yazdırılırken çökmesin.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academic_calendar import TOTAL_WEEKS, build_calendar  # noqa: E402
from outcome_parts import find_code_positions  # noqa: E402
from turkish_text import fold  # noqa: E402

try:
    import openpyxl
except ImportError:  # pragma: no cover
    print("HATA: openpyxl gerekli.  pip install openpyxl")
    raise SystemExit(1)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Ham kaynaklar uygulama paketine girmesin diye assets/ dışında tutulur.
DEFAULT_DIR = os.path.join(REPO_ROOT, "data_sources", "tymm_plans")
DEFAULT_OUTPUT = os.path.join(REPO_ROOT, "data_sources", "tymm_plan_raw.json")

# Okul türü etiketleri; publisher alanında ayırt edici olarak kullanılır.
# Aranan metinler fold() ile ASCII'ye indirgendiği için ipuçları da ASCII.
SCHOOL_TYPES = [
    (("sosyal bilimler lisesi",), "Sosyal Bilimler Lisesi"),
    (("fen lisesi", "fen bilimler lisesi", "fen bilimleri lisesi", "f.l."), "Fen Lisesi"),
    (("anadolu lisesi",), "Anadolu Lisesi"),
]

COURSE_NAMES = {
    "beden-egitimi-ve-spor-dersi": "Beden Eğitimi ve Spor",

    # MEB Eylül 2026'da ilkokul/ortaokul planlarini yayimladi. Klasor
    # adlari damga tasiyor (`_20260903_120014_364`); slug eslesmesi
    # damgasiz on ek uzerinden yapilir (bkz. `_slug_kok`).
    "beden-egitimi-ve-oyun-dersi": "Beden Eğitimi ve Oyun",
    "bilisim-teknolojileri-ve-yazilim-dersi": "Bilişim Teknolojileri ve Yazılım",
    # Coklu Yabanci Dil Egitim Modeli (CYDEM) SECILMIS okullarda
    # okutuluyor; normal ortaokulda bu ders yok. Ad ayirt edilmezse
    # ogretmen listede "Almanca" gorup kendi okulunda olmayan bir
    # dersi arar.
    "coklu-yabanci-dil-egitim-modeli-almanca-dersi":
        "Almanca (Çoklu Yabancı Dil)",
    "coklu-yabanci-dil-egitim-modeli-ingilizce":
        "İngilizce (Çoklu Yabancı Dil)",
    "fen-bilimleri-dersi": "Fen Bilimleri",
    "hayat-bilgisi-dersi": "Hayat Bilgisi",
    "ilkokul-matematik-dersi": "Matematik",
    "ilkokul-turkce-dersi": "Türkçe",
    "ilkokul-turkce-dersi-ada-yayinlari-ders-kitabi-yillik-plani": "Türkçe",
    "ingilizce-dersi": "İngilizce",
    "insan-haklarivatandaslik-ve-demokrasi-dersi":
        "İnsan Hakları, Yurttaşlık ve Demokrasi",
    "ortaokul-matematik-dersi": "Matematik",
    "ortaokul-teknoloji-ve-tasarim-dersi": "Teknoloji ve Tasarım",
    "ortaokul-turkce-dersi": "Türkçe",
    "sosyal-bilgiler-dersi": "Sosyal Bilgiler",
    "tc-inkilap-tarihi-ve-ataturkculuk-dersi":
        "T.C. İnkılap Tarihi ve Atatürkçülük",

    "biyoloji-dersi": "Biyoloji",
    "cografya-dersi": "Coğrafya",
    "felsefe-dersi": "Felsefe",
    "fizik-dersi": "Fizik",
    "gorsel-sanatlar-dersi": "Görsel Sanatlar",
    "kimya-dersi": "Kimya",
    "matematik-dersi": "Matematik",
    "muzik-dersi": "Müzik",
    "tarih-dersi": "Tarih",
    "turk-dili-ve-edebiyati-dersi": "Türk Dili ve Edebiyatı",

    # DÖGM çerçeve yıllık planlarının klasör adları (dogm.meb.gov.tr).
    # Bu dersler TYMM portalında YOKTUR; İmam Hatip ve din dersleri
    # yalnızca Din Öğretimi Genel Müdürlüğü tarafından yayımlanır.
    "KuraniKerim": "Kur'an-ı Kerim",
    "PeygamberimizinHayati": "Peygamberimizin Hayatı",
    "TemelDiniBilgiler": "Temel Dinî Bilgiler",
    "KuranAnlamDunyasi": "Kur'an'ın Anlam Dünyası",
    "Arapca": "Arapça",
    "DKAB": "Din Kültürü ve Ahlak Bilgisi",
    "AihlMeslek": "AİHL Meslek Dersleri",
}

# AİHL meslek dersleri tek klasörde toplanır; gerçek ders adı dosya
# adındadır ('...aihl_fikih10_TYMM.xlsx' -> Fıkıh).
AIHL_SUBJECTS = [
    ("fikih", "Fıkıh"),
    ("hadis", "Hadis"),
    ("tefsir", "Tefsir"),
    ("kelam", "Kelam"),
    ("akaid", "Akaid"),
    ("siyer", "Siyer"),
    ("hitabet", "Hitabet ve Mesleki Uygulama"),
    ("islamkulturmedeniyeti", "İslam Kültür ve Medeniyeti"),
    ("islam kultur", "İslam Kültür ve Medeniyeti"),
    ("kuran", "Kur'an-ı Kerim"),
    ("arapca", "Arapça"),
    ("temeldinibilgiler", "Temel Dinî Bilgiler"),
]

# Sekme adından okunan, dosya klasöründen farklı olabilecek dersler.
# Anahtarlar fold() çıktısıyla karşılaştırılır (ASCII, küçük harf).
SHEET_SUBJECT_OVERRIDES = [
    ("inkilap", "T.C. İnkılap Tarihi ve Atatürkçülük"),
    ("mantik", "Mantık"),
    ("psikoloji", "Psikoloji"),
    ("psiokoloji", "Psikoloji"),  # kaynak dosya adındaki yazım hatası
    ("sosyoloji", "Sosyoloji"),
    ("sbc", "Sosyal Bilim Çalışmaları"),
    ("scb", "Sosyal Bilim Çalışmaları"),
]


# Bir kazanım metni bu uzunluğu aşıyorsa sonraki haftalara TAŞINMAZ:
# o kadar uzun bir hücre tek haftanın içeriği değil, ünitenin tamamının
# kazanım listesidir.
# 400'dü: 379 karakterlik ünite blokları (Mesleki Arapça) eşiğin altında
# kalıp olduğu gibi 5 haftaya kopyalanıyordu.
MAX_CARRIED_OUTCOME = 260


def clean(value) -> str:
    if value is None:
        return ""
    return re.sub(r"[ \t]+", " ", str(value)).replace("\xa0", " ").strip()


def flatten(value) -> str:
    """Hücre içi satır sonlarını tek boşluğa indirger."""
    return re.sub(r"\s+", " ", clean(value)).strip()


class _XlsSheet:
    """xlrd sayfasini openpyxl arayuzuyle sunar.

    `read_sheet` yalnizca `iter_rows(values_only=True)` kullaniyor;
    tek ihtiyac bu.
    """

    def __init__(self, sheet):
        self._sheet = sheet

    def iter_rows(self, max_row=None, values_only=True):
        son = self._sheet.nrows if max_row is None else min(max_row, self._sheet.nrows)
        for i in range(son):
            yield tuple(self._sheet.cell_value(i, j)
                        for j in range(self._sheet.ncols))


class _XlsBook:
    """xlrd kitabini openpyxl arayuzuyle sunar."""

    def __init__(self, path):
        import xlrd  # yalnizca .xls varsa gerekir
        self._book = xlrd.open_workbook(path)
        self.sheetnames = list(self._book.sheet_names())

    def __getitem__(self, name):
        return _XlsSheet(self._book.sheet_by_name(name))

    def close(self):
        self._book.release_resources()


def open_plan_workbook(path: str):
    """Plan dosyasini acar; .xls ve .xlsx ikisini de destekler.

    MEB bazi dersleri hala eski .xls biciminde yayimliyor (Gorsel
    Sanatlar). openpyxl bu bicimi acmadigi icin o dosya TAMAMEN
    dusuyordu — sekiz sinifin plani birden.
    """
    if path.lower().endswith(".xls"):
        return _XlsBook(path)
    return openpyxl.load_workbook(path, read_only=True, data_only=True)


def detect_school_type(filename: str) -> str:
    """Dosya adindan okul turu (Anadolu / Fen / Sosyal Bilimler Lisesi).

    Bulunamazsa BOS doner. Once "MEB Yayınları" donuyordu ve bu bir
    okul turu degil, "bilinmiyor" demekti; kaynak alaniyla karisip
    Maarif rozetinin yanlis basilmasina yol aciyordu (olcum: 89 ders
    rozet almasi gerekirken almiyordu).

    Kaynak bilgisi artik ayri alanda: bkz. `source`.
    """
    lowered = fold(filename)
    for needles, label in SCHOOL_TYPES:
        if any(n in lowered for n in needles):
            return label
    return ""


# Sosyal bilimler lisesi seçmeli dersleri ('SBÇ 1/2/3', 'Sosyoloji 1')
# sınıf yerine seviye numarası taşır. MEB bunları 11. sınıfta okutur.
SOCIAL_SCIENCE_ELECTIVE_GRADE = 11


def detect_grade(sheet_name: str, filename: str = "") -> int | None:
    """Sınıf seviyesini sekme adından, olmazsa dosya adından çıkarır.

    TYMM planlarında sekme '10. SINIF' gibidir. DÖGM çerçeve planlarında
    ise tek sekme vardır ve adı 'Sayfa1'dir; sınıf bilgisi dosya adında
    saklıdır ('2026-2027kuran5_TYMM.xlsx', '2026-2027dkab10_TYMM.xlsx').
    """
    text = clean(sheet_name)
    match = re.search(r"(\d{1,2})\s*\.?\s*SINIF", text, re.IGNORECASE)
    if match:
        grade = int(match.group(1))
        return grade if 1 <= grade <= 12 else None
    if re.search(r"hazırlık|hazirlik", text, re.IGNORECASE):
        return None  # hazırlık sınıfı 1-12 dışında; atlanır

    # 'SBÇ 1/2/3' (Sosyal Bilim Çalışmaları) ve 'Sosyoloji 1' gibi
    # sekmelerdeki sayı SINIF DEĞİL ders seviyesidir; bu dersler sosyal
    # bilimler liselerinde okutulur. Sayıyı sınıf sanmak 1., 2., 3. sınıf
    # kayıtları üretiyordu.
    folded_sheet = fold(text)
    if re.match(r"^(sbc|scb|sosyoloji|psikoloji|mantik)\b", folded_sheet):
        return SOCIAL_SCIENCE_ELECTIVE_GRADE

    # MEB'in Eylul 2026 ilkokul/ortaokul dosyalarinda sekme adi
    # "FEN BILIMLERI 3 (TYMM)", "MUZIK-1 (TYMM)", "TURKCE 5 CERCEVE..."
    # bicimindedir; "SINIF" sozcugu gecmez. Bu sayfalar SESSIZCE
    # dusuyordu (Fen Bilimleri hic gelmedi, Turkce'nin 22 kaydi geldi).
    #
    # Sayi DERS ADINA BITISIK aranir; serbest gezen sayi ders numarasi
    # olabiliyor ("SBC 2"). Yukaridaki seceli ders kontrolu zaten
    # onden calistigi icin o durumlar buraya hic ulasmaz.
    # "Sayfa1" / "Sheet1" adsiz sekmedir; sondaki sayi SEKME numarasi,
    # sinif DEGIL. Once 1. sinif sanilip dosyanin tamami oraya
    # yaziliyordu. Kademe dosya adindan okunmali (asagida).
    if re.match(r"^(sayfa|sheet|tablo)\s*\d*$", folded_sheet):
        pass
    else:
        # "FEN BILIMLERI 3 (TYMM)", "MUZIK-1", "BTY_5", "TEK-TAS 7":
        # ders adi/kisaltmasi + kademe. Ayirici bosluk, tire veya alt
        # cizgi olabilir.
        ders_bitisik = re.match(
            r"^([a-z][a-z .'_-]{1,}?)[\s_-]*(\d{1,2})(?![0-9])", folded_sheet
        )
        if ders_bitisik:
            grade = int(ders_bitisik.group(2))
            if 1 <= grade <= 12:
                return grade

    if filename:
        name = fold(filename)
        # Yıl önekini ('2026-2027') at, kalanında sınıf numarasını ara.
        name = re.sub(r"20\d{2}\s*[-_]\s*20\d{2}", " ", name)
        if re.search(r"hazirlik", name):
            return None
        # Kopya numarasını at: 'PSIOKOLOJI DERSI (3) - Kopya' -> (3) sınıf değil.
        name = re.sub(r"\(\s*\d+\s*\)", " ", name)

        # Sınıf numarası yalnızca bir DERS ADINA bitişikse güvenilirdir
        # ('kuran5', 'dkab10', 'fikih10', 'arapca_5_iho'). Serbest gezen
        # sayılar ders numarasıdır, sınıf değil: 'SBÇ 2' / 'SBÇ 3'
        # 2. ve 3. sınıf sanılıyordu.
        match = re.search(r"[a-z]{3,}[_\s-]?(\d{1,2})(?![0-9])", name)
        if match:
            grade = int(match.group(1))
            if 1 <= grade <= 12:
                return grade
    return None


# Klasor adindaki MEB damgasi: "..._20260903_120014_364"
_DAMGA = re.compile(r"[-_]?\d{8}[-_]\d{6}[-_]\d+$")
# Ad kuyrugu: "...-dersi-yillik-planlar" / "...-taslak-yillik-planlar"
_AD_KUYRUGU = re.compile(
    r"[-_](taslak[-_])?(cerceve[-_])?yillik[-_]plan(lar|i)?$"
)


def _slug_kok(course_slug: str) -> str:
    """Klasor adindan damgayi ve plan kuyrugunu atar.

    MEB dosyalari `_20260903_120014_364` damgasi tasiyor ve bu damga
    her yayinda degisiyor. Slug'i damgayla eslestirseydik MEB dosyayi
    her guncelledigi vakit ders adi bozulurdu.
    """
    kok = _DAMGA.sub("", course_slug)
    onceki = None
    while kok != onceki:
        onceki = kok
        kok = _AD_KUYRUGU.sub("", kok)
    return kok


def detect_subject(course_slug: str, sheet_name: str, filename: str) -> str:
    haystack = fold(f"{sheet_name} {filename}")
    for needle, name in SHEET_SUBJECT_OVERRIDES:
        if needle in haystack:
            return name
    # AİHL meslek dersleri tek klasörde; ders adı dosya adından okunur.
    if course_slug == "AihlMeslek":
        for needle, name in AIHL_SUBJECTS:
            if needle in fold(filename):
                return name
    kok = _slug_kok(course_slug)
    bilinen = COURSE_NAMES.get(course_slug) or COURSE_NAMES.get(kok)
    if bilinen:
        return bilinen
    # Bilinmeyen ders: damgasiz kokten okunabilir bir ad uret. MEB yeni
    # bir ders yayimladiginda ad bozuk cikmasin diye; sozluge eklenene
    # kadar gecici olarak kullanilir.
    return kok.replace("-", " ").replace("_", " ").strip().title()


def detect_variant(sheet_name: str) -> str:
    """Sekme adındaki ders saati varyantını döner ('2 SAAT' / '4 SAAT').

    Coğrafya 11 ve 12'de aynı sınıfın iki ayrı haftalık planı var
    (haftada 2 saat ve 4 saat okutulan gruplar). Varyant ayrılmazsa
    iki plan aynı hafta numarasına düşüp birbirini eziyor.
    """
    match = re.search(r"(\d+)\s*SAAT", clean(sheet_name), re.IGNORECASE)
    return f"{match.group(1)} Saat" if match else ""


# Hücredeki gün/ay bilgisini yakalar: '1. Hafta: 14-18 Eylül'
_MONTH_NAMES = {
    "ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6,
    "temmuz": 7, "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12,
    # Yabanci dil planlari (CYDEM, Ingilizce) tarihleri INGILIZCE yazar.
    # Tarih eslesmesi etiketten guvenilir oldugu icin (tatil haftalari
    # kaymasin) bu adlar da taninmali.
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5,
    "june": 6, "july": 7, "august": 8, "september": 9, "october": 10,
    "november": 11, "december": 12,
    # CYDEM Almanca planlari (september/november ingilizceyle ayni).
    "januar": 1, "februar": 2, "marz": 3, "mai": 5, "juni": 6,
    "juli": 7, "oktober": 10, "dezember": 12,
}
_DAY_MONTH = re.compile(
    r"(\d{1,2})\s*(?:-|–|\s)\s*(?:\d{1,2}\s*)?"
    r"(ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|"
    r"aralik|january|february|march|april|may|june|july|august|september|"
    r"october|november|december|"
    r"januar|februar|marz|mai|juni|juli|oktober|dezember)"
)


def parse_week_label(value: str) -> int | None:
    """'1. Hafta:  14-18 Eylül' -> 1 (etiketteki ham numara)."""
    text = clean(value)
    if not text:
        return None
    match = re.match(r"\s*(\d{1,2})\s*\.?\s*(?:hafta|week)", text, re.IGNORECASE)
    if match:
        week = int(match.group(1))
        return week if 1 <= week <= TOTAL_WEEKS else None
    # Ingilizce planlarda sayi SONRA gelir: "Week 1: 14-18 September".
    # Turkce kalip ("1. Hafta") bunu yakalamiyordu ve CYDEM sayfalari
    # basliklari okunsa bile tek kayit uretmiyordu.
    match = re.match(r"\s*week\s*(\d{1,2})", text, re.IGNORECASE)
    if match:
        week = int(match.group(1))
        return week if 1 <= week <= TOTAL_WEEKS else None
    # Almanca: "1. Woche: 14.-18. September"
    match = re.match(r"\s*(\d{1,2})\s*\.?\s*woche", text, re.IGNORECASE)
    if match:
        week = int(match.group(1))
        return week if 1 <= week <= TOTAL_WEEKS else None
    return None


def parse_week_start(value: str) -> tuple[int, int] | None:
    """Hücredeki başlangıç gününü (gun, ay) olarak döner; yoksa None."""
    match = _DAY_MONTH.search(fold(clean(value)))
    if not match:
        return None
    return int(match.group(1)), _MONTH_NAMES[match.group(2)]


def parse_week(value: str, date_index: dict[tuple[int, int], int] | None = None) -> int | None:
    """Satırı TAKVİM hafta numarasına eşler.

    Öncelik tarihtedir. Sebebi: DÖGM çerçeve planları haftaları DERS
    haftası olarak numaralandırır (tatiller ayrı satırdır ve sayıya
    girmez), TYMM planları ise takvim haftası kullanır. İki kaynağın
    etiketleri aynı haftada farklı sayılar gösterir; ayrıca DÖGM'ün
    yazdığı tatil tarihleri MEB genelgesiyle birebir örtüşmeyebilir.
    Tarihten eşleyince her iki kaynak da aynı takvime oturur.
    """
    if date_index:
        start = parse_week_start(value)
        if start and start in date_index:
            return date_index[start]
    return parse_week_label(value)



# Turkce beceri parcalarini ayiran isaret.
#
# Dort beceri (dinleme, okuma, konusma, yazma) tek hucrede degil ayri
# sutunlarda gelir ama birlestirildiginde 5900+ karakter olur ve tek
# blok sayilir. Bu isaret, _spread_long_outcomes'in parcalari
# ayirmasini saglar; boylece her hafta bir beceriyi gosterir.
BECERI_AYIRICI = "␟"  # gorunmez birim ayirici


def split_outcome_list(text: str) -> list[str]:
    # Beceri sutunlarindan gelen metin zaten parcalanmis halde
    # isaretlenmistir; kod tahminine gerek yok.
    if BECERI_AYIRICI in text:
        return [p.strip() for p in text.split(BECERI_AYIRICI) if p.strip()]
    """Tek hücreye sığdırılmış kazanım listesini parçalarına ayırır.

    Bazı çerçeve planlarda (Arapça) ünitenin TÜM kazanımları ünitenin ilk
    haftasına tek hücrede yazılır:

        "ARP.10.1.1. DİNLEME... 10.1.1.1. Akrabalar... 10.1.1.2. ..."

    Metin ~1900 karakterdir ve olduğu gibi gösterilince kart okunmaz.
    Kazanım kodlarının BAŞLADIĞI yerlerden bölüp her parçayı ayrı öğe
    yaparız.

    Bölme regex ile YAPILMAZ: '10.1.1.1.' kodunun içinde '1.1.1.' alt
    dizisi de bulunduğu için lookahead kodu ortadan kesiyordu. Bunun
    yerine kod konumları taranıp yalnızca gerçek başlangıçlar kullanılır.
    """
    if not text:
        return []

    # Kod deseni TEK yerde tanımlıdır (outcome_parts). Burada ikinci bir
    # kopya tutmak, 'MARP11.1.1' gibi son noktası olmayan kodların yalnızca
    # bir tarafta tanınmasına yol açıyordu: kayıtlar tek blok kalıp
    # haftalara bölünemiyor, aynı metin 5 hafta tekrar ediyordu.
    starts = [pos for pos, _ in find_code_positions(text)]

    if len(starts) < 2:
        return [text.strip()]

    parts: list[str] = []
    for index, begin in enumerate(starts):
        finish = starts[index + 1] if index + 1 < len(starts) else len(text)
        piece = text[begin:finish].strip()
        if piece:
            parts.append(piece)

    # Yalnızca başlık taşıyan kırıntıyı ('ARP.10.1.1. DİNLEME') bir
    # sonrakine iliştir; tek başına anlamlı bir hafta içeriği değildir.
    merged: list[str] = []
    for part in parts:
        if merged and len(part) < 30:
            merged[-1] = f"{merged[-1]} {part}"
        elif len(part) < 30 and len(merged) == 0:
            merged.append(part)
        else:
            merged.append(part)
    return merged or [text.strip()]


# Turkce planlarinda kazanimlarin dagildigi beceri sutunlari.
# Etiket, hucre icerigi birlestirilirken basa yazilir.
_BECERI_ALANLARI = {
    "skill_listen": "Dinleme/İzleme",
    "skill_read": "Okuma",
    "skill_speak": "Konuşma",
    "skill_write": "Yazma",
}


def locate_header(rows: list[tuple]) -> tuple[int, dict[str, int], str]:
    """Alt başlık satırını bulur; sütun eşlemesi ve PROGRAM DÜZENİ döner.

    Düzen, kaynağın hangi öğretim programına ait olduğunu söyler ve
    ölçümle doğrulandı: MEB aynı dosyada iki programı birden veriyor.

        FEN BİLİMLERİ 3 (TYMM) -> "ÖĞRENME ÇIKTILARI VE SÜREÇ BİLEŞENLERİ"
        FEN BİLİMLERİ 4        -> "KAZANIM" + "KAZANIM AÇIKLAMASI"

    Sayfa adındaki "(TYMM)" işareti tek başına yetmez: lise
    dosyalarında hiç yok, oysa içerikleri Maarif düzeninde. Sütun
    başlığı ise içeriğin kendisinden gelir.

    Dönen düzen: 'maarif' | 'legacy'
    """
    # Sıra ÖNEMLİ ve eşleşme TAM BAŞLIK üzerinden yapılır. Gevşek "içeriyor"
    # eşlemesi yanlış sütun seçiyordu: "ÖLÇME VE DEĞERLENDİRME" başlığı
    # "değerler" ipucuyla eşleşip DEĞERLER sütununun yerine geçiyor, kazanım
    # metni yerine ölçme cümlesi okunuyordu (tüm haftalarda aynı cümle).
    # İpuçları ASCII'ye katlanmış biçimde yazılır; başlık hücreleri de
    # turkish_text.fold() ile katlanır. str.lower() Türkçe 'İ' harfini
    # bozduğu için burada KULLANILMAZ ("HAFTA" -> "hafta" güvenli değil,
    # "ÖLÇME" gibi başlıklarda birleşen nokta kalıyordu).
    hints: list[tuple[str, tuple[str, ...]]] = [
        # Yabanci dil planlarinda (CYDEM, Ingilizce) sutun basliklari
        # INGILIZCE yazilmis: WEEK / LEARNING OUTCOMES / THEME. Yalnizca
        # Turkce ipucu arandigi icin 8 sayfa dusuyordu — 5-8. sinif
        # Ingilizce ve Almanca, yani Maarif'in yururlukte oldugu
        # kademeler.
        # CYDEM Almanca planlarinda basliklar ALMANCA yazilmis:
        # WOCHE / LERNERGEBNISSE / INHALTSRAHMEN. Ingilizce destegi
        # eklenmisti ama Almancasi yoktu ve dosya tamamen dusuyordu
        # (5-8. sinif, Maarif isaretli).
        ("hours", ("ders saati", "ders saat", "class hour", "class hours",
                   "lesson hour", "unterrichtsstunde", "stunde")),
        ("week", ("hafta", "week", "woche")),
        ("month", ("ay", "month", "monat")),
        ("unit", ("unite/tema", "unite", "tema", "theme and content frame",
                  "theme", "unterrichtseinheiten", "thema")),
        ("topic", ("konu (icerik cercevesi)", "konu", "content frame",
                   "sub-theme", "inhaltsrahmen", "lektion")),
        # "learning skills and learning outcomes": Ingilizce planlarinda
        # baslik boyle yaziliyor ve "learning outcomes" ile BASLAMIYOR.
        # Eslesme baslangic uzerinden yapildigi icin 4., 7. ve 8. sinif
        # sayfalari dusuyordu. Gevsek "iceriyor" eslesmesi tehlikeli
        # (bkz. yukaridaki not), o yuzden tam ifade eklendi.
        ("outcome", ("ogrenme ciktilari", "kazanim",
                     "learning skills and learning outcomes",
                     "learning outcomes", "learning outcome",
                     "lernergebnisse", "lernziele")),
        # Turkce planlarinda tek bir "ogrenme ciktilari" sutunu YOK;
        # kazanimlar dort beceriye dagilmis. Ayri alanlar olarak
        # taninir, sonra birlestirilir (bkz. `_BECERI_ALANLARI`).
        ("skill_listen", ("dinleme/izleme", "dinleme")),
        ("skill_read", ("okuma",)),
        ("skill_speak", ("konusma",)),
        ("skill_write", ("yazma",)),
        ("process", ("surec bilesenleri", "kazanim aciklamasi",
                     "indicators for learning", "process components",
                     "prozesskomponenten")),
        ("assessment", ("olcme ve degerlendirme", "olcme",
                        "assessment and evaluation", "assessment")),
        ("sel", ("sosyal - duygusal ogrenme becerileri", "sosyal-duygusal",
                 "sosyal duygusal")),
        ("values", ("degerler",)),
        ("literacy", ("okuryazarlik becerileri", "okuryazarlik")),
        ("days", ("belirli gun ve haftalar", "belirli gun")),
        ("diff", ("farklilastirma",)),
        ("otp", ("okul temelli planlama", "okul temelli")),
    ]

    def match_field(cell: str) -> str | None:
        """Başlık hücresini tek bir alana eşler; en uzun ipucu kazanır."""
        # Sondaki cogul eki esnetilir: MEB ayni dosyada bile yazimi
        # degistiriyor ("learning outcomes" / "learning outcome") ve
        # tek harf yuzunden sayfa tamamen dusuyordu.
        #
        # Gevsek "iceriyor" eslesmesine DONULMEZ: o, "olcme ve
        # degerlendirme" basligini "degerler"e kaydiriyordu.
        def tekillestir(t: str) -> str:
            return t[:-1] if t.endswith("s") else t

        sade = tekillestir(cell)
        best_field, best_len = None, 0
        for field, needles in hints:
            for needle in needles:
                sade_needle = tekillestir(needle)
                if (cell == needle or cell.startswith(needle)
                        or sade == sade_needle
                        or sade.startswith(sade_needle)):
                    if len(needle) > best_len:
                        best_field, best_len = field, len(needle)
        return best_field

    # Hangi ipucunun eslestigi duzeni belirler.
    def duzen_belirle(basliklar: list[str]) -> str:
        for c in basliklar:
            if (c.startswith("ogrenme ciktilari")
                    or c.startswith("surec bilesenleri")
                    or c.startswith("learning outcomes")
                    or c.startswith("learning skills and learning outcomes")
                    or c.startswith("lernergebnisse")
                    or c.startswith("lernziele")
                    # Turkce plani beceri sutunlariyla gelir ama ust
                    # satirda "ogrenme ciktilari ve surec bilesenleri"
                    # birlesik basligi durur; yine de acikca kontrol
                    # edilir.
                    or c.startswith("dinleme/izleme")):
                return "maarif"
        return "legacy"

    # Aday satirin isareti "hafta" sutunudur. Yabanci dil planlarinda
    # bu sutun "WEEK" yazar; yalnizca Turkce arandigi icin o sayfalarin
    # hicbir satiri aday olmuyor ve ipuclarina bakilmadan dusuyorlardi.
    def hafta_sutunu(c: str) -> bool:
        return (c == "hafta" or c.startswith("hafta")
                or c == "week" or c.startswith("week ")
                or c == "woche" or c.startswith("woche "))

    for index in range(min(8, len(rows))):
        cells = [fold(flatten(c)) for c in rows[index]]
        if not any(hafta_sutunu(c) for c in cells):
            continue

        # Başlıklar birden fazla satıra yayılabiliyor. Arapça çerçeve
        # planlarında SÜRE/ÜNİTE üst satırda, Ölçme/DEĞERLER bir alt
        # satırda, AY|HAFTA|SAAT ise bir alt satırda duruyor. Tek satıra
        # bakınca 'outcome' bulunamıyor ve dosya tamamen atlanıyordu.
        merged: list[str] = list(cells)
        for extra in (index - 1, index - 2, index + 1, index + 2):
            if not 0 <= extra < len(rows):
                continue
            for col, value in enumerate(rows[extra]):
                text = fold(flatten(value))
                if not text:
                    continue
                while len(merged) <= col:
                    merged.append("")
                if not merged[col]:
                    merged[col] = text

        mapping: dict[str, int] = {}
        for col, cell in enumerate(merged):
            if not cell:
                continue
            field = match_field(cell)
            if field and field not in mapping:
                mapping[field] = col

        # Turkce planinda `outcome` yok ama beceri sutunlari var;
        # onlar da kazanim tasiyor.
        beceri_var = any(k in mapping for k in _BECERI_ALANLARI)
        if "week" in mapping and ("outcome" in mapping or beceri_var):
            return index, mapping, duzen_belirle(merged)
    return -1, {}, "legacy"


def build_date_index(academic_year: str) -> dict[tuple[int, int], int]:
    """(gun, ay) -> takvim hafta numarasi eslemesi.

    Bir haftanin pazartesi-cuma araligindaki HER gun o haftaya isaret eder;
    boylece kaynak dosyalar araligi farkli yazsa da ('14-18 Eylul' /
    '15-19 Eylul') dogru haftaya oturur.
    """
    index: dict[tuple[int, int], int] = {}
    for week, info in build_calendar(academic_year).items():
        start = datetime.date.fromisoformat(info["start"])
        for offset in range(5):  # pazartesi..cuma
            day = start + datetime.timedelta(days=offset)
            index.setdefault((day.day, day.month), week)
    return index


def read_sheet(worksheet, sheet_name: str, course_slug: str,
               filename: str,
               date_index: dict[tuple[int, int], int] | None = None,
               portal: str = "tymm",
               ) -> tuple[list[dict], list[str]]:
    problems: list[str] = []
    grade = detect_grade(sheet_name, filename)
    if grade is None:
        # Hazirlik sinifi bilerek atlanir (1-12 disi) ve uyari uretmez.
        # Ama BASKA bir sebeple kademe okunamiyorsa bu veri kaybidir ve
        # gorunur olmali: Fen Bilimleri'nin tamami boyle sessizce
        # dusmustu, uyari listesinde bile yoktu.
        if not re.search(r"hazırlık|hazirlik", clean(sheet_name), re.IGNORECASE):
            return [], [
                f"{filename} / {sheet_name}: kademe okunamadi, sayfa atlandi"
            ]
        return [], []

    rows = list(worksheet.iter_rows(values_only=True))
    header_index, columns, duzen = locate_header(rows)
    if header_index == -1:
        return [], [f"{filename} / {sheet_name}: baslik satiri bulunamadi"]

    subject = detect_subject(course_slug, sheet_name, filename)
    # Yayınevi etiketi grubun kimliğini taşır: aynı sınıf-branşın farklı
    # okul türü ve ders saati planları ayrı gruplar olarak durmalı.
    # Okul turu bulunamazsa BOS kalir; "MEB Yayinlari" uydurulmaz.
    publisher = detect_school_type(filename)
    variant = detect_variant(sheet_name)
    if variant:
        publisher = f"{publisher} · {variant}" if publisher else variant

    def cell(row: tuple, field: str) -> str:
        index = columns.get(field, -1)
        if index == -1 or index >= len(row):
            return ""
        return flatten(row[index])

    records: list[dict] = []
    seen: set[int] = set()
    # Birleşik hücrelerde değer yalnızca ilk satırda yazar; sonraki
    # haftalara taşınır. Bir kazanım çoğu planda 2-4 hafta sürer ve
    # ara satırlar boş bırakılır; taşımazsak o haftalar tamamen düşer
    # (hitabet 11'de 40 haftanın yalnızca 10'u okunuyordu).
    last_unit = ""
    last_topic = ""
    last_outcome = ""
    last_values = ""
    last_skills = ""

    for row in rows[header_index + 1:]:
        if not any(row):
            continue
        week = parse_week(cell(row, "week"), date_index)
        if week is None or week in seen:
            continue
        seen.add(week)

        unit = cell(row, "unit") or last_unit
        topic = cell(row, "topic") or last_topic
        last_unit, last_topic = unit or last_unit, topic or last_topic

        own_outcome = cell(row, "outcome")
        # Taşıma yalnızca KISA kazanım metinleri için yapılır.
        #
        # Bazı çerçeve planlarda (Arapça) ünitenin TÜM kazanımları ünitenin
        # ilk haftasına tek hücrede yazılır (~1900 karakter). Bunu sonraki
        # haftalara kopyalamak hem kartı okunmaz hâle getiriyor hem de aynı
        # dev metni 5 hafta boyunca tekrar ediyordu. Bu durumda metin
        # yalnızca kendi haftasında kalır; diğer haftalar süreç bileşeni
        # veya ünite/konu başlığıyla temsil edilir.
        # Turkce plani: kazanimlar dort beceri sutununda. Beceri adi
        # basa yazilir ki hangi kazanimin hangi beceriye ait oldugu
        # belli olsun.
        if not own_outcome:
            parcalar = []
            for alan, etiket in _BECERI_ALANLARI.items():
                metin = cell(row, alan)
                if metin:
                    parcalar.append(f"{etiket}: {metin}")
            if parcalar:
                # Ayirici ile birlestirilir: metin uzunsa
                # _spread_long_outcomes bunlari haftalara dagitir,
                # kisaysa ayirici temizlenir (asagida).
                own_outcome = BECERI_AYIRICI.join(parcalar)

        outcome = own_outcome or (
            last_outcome if len(last_outcome) <= MAX_CARRIED_OUTCOME else ""
        )
        if own_outcome:
            last_outcome = own_outcome
        process = cell(row, "process")
        # Haftayı birbirinden ayıran asıl alan süreç bileşenidir; kazanım
        # kodu birkaç hafta aynı kalabilir.
        description = " ".join(p for p in (outcome, process) if p).strip()
        if not description:
            continue

        values = cell(row, "values") or last_values
        literacy = cell(row, "literacy")
        sel = cell(row, "sel")
        skills = ", ".join(p for p in (sel, literacy) if p) or last_skills
        last_values = values or last_values
        last_skills = skills or last_skills

        records.append({
            "gradeLevel": grade,
            "subjectName": subject,
            "publisher": publisher,
            "weekNumber": week,
            "unitTitle": unit,
            "topicTitle": topic or unit,
            "outcomeDescription": description,
            "outcomeCode": extract_code(outcome),
            "maarifValues": values or None,
            "maarifSkills": skills or None,
            "differentiation": cell(row, "diff") or None,
            # Kaynak IKI bilgi tasir:
            #   portal : hangi MEB sitesinden indi (tymm / dogm)
            #   duzen  : Maarif programi mi eski program mi
            #
            # Duzen Excel sutun basligindan OLCULUR, tahmin edilmez:
            #   'maarif' -> "OGRENME CIKTILARI VE SUREC BILESENLERI"
            #   'legacy' -> "KAZANIM" + "KAZANIM ACIKLAMASI"
            #
            # Ikisi ayri tutulur cunku DOGM planlari da Maarif duzeninde
            # olabiliyor; onlara "TYMM" demek yaniltici olur.
            "sourcePortal": portal,
            "sourceProgram": "maarif" if duzen == "maarif" else "legacy",
            "source": portal if duzen == "maarif" else "legacy",
            "sourceFile": filename,
            "sourceSheet": sheet_name,
        })

    records = _spread_long_outcomes(records)

    # Beceri ayiricisi YALNIZCA parcalama icin vardi; nihai metne
    # sizmamali. Gorunmez bir karakter resmi evraga ve ogretmenin
    # gordugu karta girerse teshisi zor bir kusur olur.
    for kayit in records:
        metin = kayit.get("outcomeDescription") or ""
        if BECERI_AYIRICI in metin:
            kayit["outcomeDescription"] = re.sub(
                r"\s+", " ", metin.replace(BECERI_AYIRICI, " ")
            ).strip()

    if records and len(records) < 20:
        problems.append(
            f"{filename} / {sheet_name}: yalnizca {len(records)} hafta okundu"
        )
    return records, problems


def _spread_long_outcomes(records: list[dict]) -> list[dict]:
    """Ünite başına tek hücrede toplanmış kazanımları haftalara dağıtır.

    Kaynak, ünitenin tüm kazanımlarını ilk haftaya yazıp sonraki haftaları
    boş bırakabiliyor. O blok bir sonraki dolu haftaya kadar sürer; listeyi
    o aralığa eşit dağıtırsak her hafta kendi kazanımını gösterir.
    """
    if not records:
        return records

    ordered = sorted(records, key=lambda r: r["weekNumber"])
    result: list[dict] = []

    for index, record in enumerate(ordered):
        description = record.get("outcomeDescription") or ""
        if len(description) <= MAX_CARRIED_OUTCOME:
            result.append(record)
            continue

        parts = split_outcome_list(description)
        if len(parts) < 2:
            result.append(record)
            continue

        # Blok, bir sonraki kayda kadar sürer.
        start = record["weekNumber"]
        end = (ordered[index + 1]["weekNumber"] if index + 1 < len(ordered)
               else TOTAL_WEEKS + 1)
        # Blok kendi aralığının dışına taşmamalı: 39 haftalık takvimde
        # 52. hafta diye bir şey yok ve boru hattı böyle kayıtları eler.
        span = max(1, min(end - start, len(parts), TOTAL_WEEKS + 1 - start))

        # Parçaları span kadar gruba böl.
        per = max(1, -(-len(parts) // span))
        for offset in range(span):
            chunk = parts[offset * per:(offset + 1) * per]
            if not chunk:
                break
            clone = dict(record)
            clone["weekNumber"] = start + offset
            clone["outcomeDescription"] = " ".join(chunk)
            result.append(clone)

    # Aynı haftaya iki kayıt düşmesin.
    seen: set[int] = set()
    unique: list[dict] = []
    for record in sorted(result, key=lambda r: r["weekNumber"]):
        if record["weekNumber"] in seen:
            continue
        seen.add(record["weekNumber"])
        unique.append(record)
    return unique


def extract_code(text: str) -> str | None:
    """'FEL.10.1.1. Felsefenin anlamını...' -> 'FEL.10.1.1'"""
    match = re.match(r"\s*([A-ZÇĞİÖŞÜ]{2,6}\.\d{1,2}(?:\.\d{1,2})+)", clean(text))
    return match.group(1) if match else None


def import_directory(root: str, academic_year: str = "2026-2027"
                     ) -> tuple[list[dict], list[str]]:
    # Portal klasor yolundan okunur: "data_sources/dogm_plans" -> dogm.
    # Ayri bir bayrak istemek riskli olurdu; unutulursa kayitlar yanlis
    # kaynakla etiketlenirdi.
    portal = "dogm" if "dogm" in os.path.basename(
        os.path.normpath(root)).lower() else "tymm"
    records: list[dict] = []
    problems: list[str] = []
    date_index = build_date_index(academic_year)

    for course_slug in sorted(os.listdir(root)):
        course_dir = os.path.join(root, course_slug)
        if not os.path.isdir(course_dir) or course_slug.startswith("_"):
            continue

        for filename in sorted(os.listdir(course_dir)):
            if not filename.endswith((".xlsx", ".xls")):
                continue
            # macOS arşiv artıkları ('._' önekli) gerçek Excel değildir.
            if filename.startswith("._"):
                continue

            path = os.path.join(course_dir, filename)
            try:
                workbook = open_plan_workbook(path)
            except Exception as error:
                problems.append(f"{filename}: acilamadi ({error})")
                continue

            for sheet_name in workbook.sheetnames:
                sheet_records, sheet_problems = read_sheet(
                    workbook[sheet_name], sheet_name, course_slug, filename,
                    date_index, portal)
                records.extend(sheet_records)
                problems.extend(sheet_problems)
            workbook.close()

    return records, problems


def main() -> int:
    parser = argparse.ArgumentParser(description="TYMM taslak yıllık plan içe aktarıcı")
    parser.add_argument("--dir", default=DEFAULT_DIR)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--year", default="2026-2027",
                        help="Takvim eslemesi icin egitim ogretim yili")
    args = parser.parse_args()

    if not os.path.isdir(args.dir):
        print(f"HATA: Klasor yok: {args.dir}")
        print("Once indirin: python scripts/maarif/fetch_tymm_plans.py")
        return 1

    records, problems = import_directory(args.dir, args.year)
    if not records:
        print("HATA: Hicbir plan okunamadi.")
        return 1

    groups = {(r["gradeLevel"], r["subjectName"], r["publisher"]) for r in records}
    grades = sorted({r["gradeLevel"] for r in records})

    print(f"Okunan kayit  : {len(records)}")
    print(f"Ders grubu    : {len(groups)}")
    print(f"Siniflar      : {grades}")

    # Benzersizlik: asil mesele buydu
    by_group: dict[tuple, list[str]] = {}
    for record in records:
        key = (record["gradeLevel"], record["subjectName"], record["publisher"])
        by_group.setdefault(key, []).append(record["outcomeDescription"])
    ratios = [(len(set(v)) / len(v)) for v in by_group.values() if v]
    if ratios:
        strong = sum(1 for r in ratios if r >= 0.9)
        print(f"Benzersizlik  : {strong}/{len(ratios)} grup %90 uzeri")

    if problems:
        print(f"\n{len(problems)} uyari:")
        for problem in problems[:10]:
            print(f"  - {problem}")
        if len(problems) > 10:
            print(f"  ... {len(problems) - 10} uyari daha")

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)
    print(f"\nYazildi: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

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


def detect_school_type(filename: str) -> str:
    lowered = fold(filename)
    for needles, label in SCHOOL_TYPES:
        if any(n in lowered for n in needles):
            return label
    return "MEB Yayınları"


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
    return COURSE_NAMES.get(course_slug, course_slug.replace("-", " ").title())


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
}
_DAY_MONTH = re.compile(
    r"(\d{1,2})\s*(?:-|–|\s)\s*(?:\d{1,2}\s*)?"
    r"(ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik)"
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



def split_outcome_list(text: str) -> list[str]:
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


def locate_header(rows: list[tuple]) -> tuple[int, dict[str, int]]:
    """Alt başlık satırını bulur ve sütun eşlemesi döner."""
    # Sıra ÖNEMLİ ve eşleşme TAM BAŞLIK üzerinden yapılır. Gevşek "içeriyor"
    # eşlemesi yanlış sütun seçiyordu: "ÖLÇME VE DEĞERLENDİRME" başlığı
    # "değerler" ipucuyla eşleşip DEĞERLER sütununun yerine geçiyor, kazanım
    # metni yerine ölçme cümlesi okunuyordu (tüm haftalarda aynı cümle).
    # İpuçları ASCII'ye katlanmış biçimde yazılır; başlık hücreleri de
    # turkish_text.fold() ile katlanır. str.lower() Türkçe 'İ' harfini
    # bozduğu için burada KULLANILMAZ ("HAFTA" -> "hafta" güvenli değil,
    # "ÖLÇME" gibi başlıklarda birleşen nokta kalıyordu).
    hints: list[tuple[str, tuple[str, ...]]] = [
        ("hours", ("ders saati", "ders saat")),
        ("week", ("hafta",)),
        ("month", ("ay",)),
        ("unit", ("unite/tema", "unite", "tema")),
        ("topic", ("konu (icerik cercevesi)", "konu")),
        ("outcome", ("ogrenme ciktilari", "kazanim")),
        ("process", ("surec bilesenleri", "kazanim aciklamasi")),
        ("assessment", ("olcme ve degerlendirme", "olcme")),
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
        best_field, best_len = None, 0
        for field, needles in hints:
            for needle in needles:
                # Tam eşleşme veya başlığın ipucuyla başlaması güvenlidir;
                # "olcme ve degerlendirme" başlığı "degerler"e kaymaz.
                if cell == needle or cell.startswith(needle):
                    if len(needle) > best_len:
                        best_field, best_len = field, len(needle)
        return best_field

    for index in range(min(8, len(rows))):
        cells = [fold(flatten(c)) for c in rows[index]]
        if not any(c == "hafta" or c.startswith("hafta") for c in cells):
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

        if "week" in mapping and "outcome" in mapping:
            return index, mapping
    return -1, {}


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
               ) -> tuple[list[dict], list[str]]:
    problems: list[str] = []
    grade = detect_grade(sheet_name, filename)
    if grade is None:
        return [], []  # hazırlık sınıfı vb. sessizce atlanır

    rows = list(worksheet.iter_rows(values_only=True))
    header_index, columns = locate_header(rows)
    if header_index == -1:
        return [], [f"{filename} / {sheet_name}: baslik satiri bulunamadi"]

    subject = detect_subject(course_slug, sheet_name, filename)
    # Yayınevi etiketi grubun kimliğini taşır: aynı sınıf-branşın farklı
    # okul türü ve ders saati planları ayrı gruplar olarak durmalı.
    publisher = detect_school_type(filename)
    variant = detect_variant(sheet_name)
    if variant:
        publisher = f"{publisher} · {variant}"

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
            "sourceFile": filename,
            "sourceSheet": sheet_name,
        })

    records = _spread_long_outcomes(records)

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
                workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
            except Exception as error:
                problems.append(f"{filename}: acilamadi ({error})")
                continue

            for sheet_name in workbook.sheetnames:
                sheet_records, sheet_problems = read_sheet(
                    workbook[sheet_name], sheet_name, course_slug, filename,
                    date_index)
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

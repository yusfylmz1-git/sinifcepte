"""
SınıfCepte - Müfredat Boru Hattı (tek giriş noktası)

    python scripts/maarif/build_curriculum.py --year 2027-2028

Yapılan işler:
  1. Mevcut kazanım havuzunu okur (assets/data/official_maarif_kazanimlar.json)
     veya --source ile verilen dosyayı kullanır.
  2. Branş kodlarını Türkçe uyumlu biçimde yeniden hesaplar (İ harfi hatası).
  3. Haftaları hedef yılın MEB takvimine göre yeniden tarihlendirir.
  4. Doküman kimliklerini çakışmasız üretir.
  5. Eksik Maarif pedagojik alanlarını doldurur.
  6. Çıktıyı hem assets/data/*.json hem admin_portal/js/curriculum_presets.js
     olarak yazar; JS dosyası panelin beklediği API'yi (CurriculumPresets) sağlar.
  7. --check ile hiçbir dosya yazmadan doğrulama yapar.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academic_calendar import TOTAL_WEEKS, build_calendar, parse_academic_year  # noqa: E402
from outcome_parts import outcome_codes, parse_outcomes  # noqa: E402
from pedagogy import build_meta  # noqa: E402
from turkish_text import (  # noqa: E402
    detect_category,
    detect_subject_code,
    fold,
    school_type_for_grade,
    slugify,
)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA_JSON = os.path.join(REPO_ROOT, "assets", "data", "official_maarif_kazanimlar.json")
PRESETS_JS = os.path.join(REPO_ROOT, "admin_portal", "js", "curriculum_presets.js")


# --------------------------------------------------------------------------
# Metin temizliği
# --------------------------------------------------------------------------

_MONTHS = (
    r"September|October|November|December|January|February|March|April|May|June|July|August|"
    r"Eylül|Ekim|Kasım|Aralık|Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos"
)

# Kaynak Excel'lerde kazanım metinlerinin BAŞINDA önceki yıla ait hafta
# başlığı gömülü geliyor: "Week 1: 8-12 September | ...", "3.Week: 22-26
# September | ...". Bu tarihler uygulamanın gösterdiği güncel takvimle
# çelişiyordu; yalnızca bu ÖNEK ayıklanır.
#
# DİKKAT: Metin içindeki "Orman Haftası (21-26 Mart)" gibi belirli gün ve
# hafta adları KORUNUR - bunlar takvim değil müfredat içeriğidir.
# Kaynak Excel'lerde kazanım metninin BAŞINDA önceki yıla ait hafta
# başlığı gömülü geliyor:
#   "Week 1: 8-12 September | ..."
#   "Week 4: 29 September- 3 October | ..."   (iki ay adı)
#   "Week 16: 29 December 2 January | ..."    (yıl geçişi, ayraçsız)
#   "3.Week: 22-26 September | ..."
#
# Bu tarihler uygulamanın gösterdiği güncel takvimle ÇELİŞİYOR: kaynak
# "Week 30" derken kayıt bizim takvimimizde 33. haftaya düşebiliyor.
#
# Tek desenle yakalamak kırılgan olduğu için iki aşamalı yaklaşım:
#   1. Metin bir hafta etiketiyle mi başlıyor?
#   2. Etiketten sonraki ilk '|' ayracına kadar olan kısım yalnızca
#      tarih parçalarından mı oluşuyor? Öyleyse o önek atılır.
#
# DİKKAT: Metin içindeki "Orman Haftası (21-26 Mart)" gibi anma haftaları
# KORUNUR — bunlar takvim değil müfredat içeriğidir.
_WEEK_PREFIX_LABEL = re.compile(
    r"^\s*\d*\s*\.?\s*(?:Week|Hafta)\s*\d*\s*[:.\-]?\s*",
    re.IGNORECASE,
)
_ONLY_DATE_TOKENS = re.compile(
    rf"^(?:\s|\d|[-–—,./]|{_MONTHS})*$", re.IGNORECASE)



# Kart üzerinde okunabilir kalan üst sınır. Kaynak Excel'lerde bazı
# hücreler dönemin TÜM kelime listesini taşıyor (7. sınıf İngilizce'de
# 30.672 karakter); olduğu gibi basılınca kart kullanılamaz hâle geliyor.
MAX_DESCRIPTION = 700


def trim_description(text: str) -> str:
    """Aşırı uzun kazanım metnini cümle sınırında kısaltır."""
    if not text or len(text) <= MAX_DESCRIPTION:
        return text

    window = text[:MAX_DESCRIPTION]
    for mark in (". ", "; ", ", "):
        cut = window.rfind(mark)
        if cut > MAX_DESCRIPTION * 0.6:
            return window[:cut + 1].strip() + " …"
    cut = window.rfind(" ")
    return (window[:cut] if cut > 0 else window).strip() + " …"


# Kaynak dosyalarda kazanım kodunun içine boşluk kaçabiliyor
# ('KK.7. 4.1.' — MEB'in kendi yazım hatası). Kod bütün olmazsa hem
# okunmuyor hem de kod bazlı arama tutmuyor.
_CODE_INNER_SPACE = re.compile(r"\b([A-ZÇĞİÖŞÜ]{2,6}\.\d{1,2})\.\s+(\d)")
_NUMBER_INNER_SPACE = re.compile(r"\b(\d{1,2})\.\s+(\d{1,2}\.)")


def normalize_codes(text: str) -> str:
    """Kazanım kodundaki iç boşlukları kapatır."""
    if not text:
        return ""
    previous = None
    while previous != text:
        previous = text
        text = _CODE_INNER_SPACE.sub(r"\1.\2", text)
        text = _NUMBER_INNER_SPACE.sub(r"\1.\2", text)
    return text


# Kaynak planlarda bazı haftalar DOLDURULMAMIŞ gelir. İki biçimi var:
#   1. Yalnızca tarih: "Week 4: 29 September - 3 October"
#   2. Uydurma dolgu:  "... ünitesi kapsamında haftalık MEB müfredat
#                       kazanımları, kavram tahlili ve öğrenme süreçleri."
# İkisi de gerçek kazanım DEĞİLDİR; "Planlanmamış Hafta" işaretlenir ve
# uydurma kazanım kodu üretilmez.
_TITLE_ONLY = re.compile(
    r"^\s*(?:SCHOOL[- ]BASED PLANNING|OKUL TEMELLİ PLANLAMA|"
    r"REVISION|REVİZYON|TEKRAR|DEĞERLENDİRME|ASSESSMENT)\s*$",
    re.IGNORECASE,
)

_FILLER_PHRASES = (
    "müfredat kazanımları, kavram tahlili",
    "MEB müfredat kazanımı ve öğrenme",
    "kapsamında haftalık MEB müfredat",
    "hafta MEB Maarif kazanımı ve etkinlikleri",
)


def _is_date_only(body: str) -> bool:
    """Metin yalnızca hafta etiketi + tarihten mi ibaret?"""
    stripped = _WEEK_PREFIX_LABEL.sub("", body, count=1)
    if stripped == body:
        return False
    return bool(_ONLY_DATE_TOKENS.match(stripped))


def is_unplanned(text: str) -> bool:
    """Metin gerçek kazanım mı, yoksa boş/dolgu mu?"""
    body = (text or "").strip()
    if not body:
        return True
    if _is_date_only(body) or _TITLE_ONLY.match(body):
        return True
    return any(phrase in body for phrase in _FILLER_PHRASES)


def strip_stale_dates(text: str) -> str:
    """Kazanım metninin başındaki eski yıla ait hafta başlığını kaldırır."""
    if not text:
        return ""

    label = _WEEK_PREFIX_LABEL.match(text)
    if not label:
        return text.strip()

    rest = text[label.end():]
    # Ayraca kadar olan kısım tarihse önek at; değilse metne dokunma.
    head, sep, tail = rest.partition("|")
    if sep and _ONLY_DATE_TOKENS.match(head):
        cleaned = tail.strip(" |\t")
        return cleaned or text.strip()

    # Ayraç yoksa: kalanın tamamı tarihse metin zaten içeriksizdir
    # (is_unplanned yakalar); orijinali koru.
    return text.strip()


# Yalnızca ÖNEKTEKİ eski hafta başlıklarını sayar; metin içindeki
# "Orman Haftası (21-26 Mart)" gibi anma haftaları sayılmaz.
def count_stale_dates(records: list[dict]) -> int:
    fields = ("outcomeDescription", "unitTitle", "topicTitle")
    def has_prefix(value: str) -> bool:
        label = _WEEK_PREFIX_LABEL.match(value or "")
        if not label:
            return False
        head, sep, _ = (value or "")[label.end():].partition("|")
        return bool(sep and _ONLY_DATE_TOKENS.match(head))

    return sum(1 for r in records
               if any(has_prefix(r.get(f) or "") for f in fields))


# --------------------------------------------------------------------------
# Doğrulama
# --------------------------------------------------------------------------

def validate(records: list[dict]) -> list[str]:
    """Yayına engel olacak veri hatalarını döner. Boş liste = temiz."""
    problems: list[str] = []

    ids = [r.get("id") for r in records]
    duplicates = {i for i in ids if i and ids.count(i) > 1}
    if duplicates:
        sample = ", ".join(sorted(duplicates)[:5])
        problems.append(
            f"{len(duplicates)} adet çakışan doküman kimliği var (örn: {sample}). "
            "Bu kayıtlar SQLite tohumlamasında birbirini eziyor."
        )

    missing_id = sum(1 for r in records if not r.get("id"))
    if missing_id:
        problems.append(f"{missing_id} kaydın 'id' alanı boş.")

    # Her ders grubu 39 haftayı eksiksiz kapsamalı
    groups: dict[tuple, set[int]] = {}
    for r in records:
        key = (r.get("gradeLevel"), r.get("subjectCode"), r.get("publisher"))
        groups.setdefault(key, set()).add(r.get("weekNumber"))

    incomplete = [k for k, weeks in groups.items() if weeks != set(range(1, TOTAL_WEEKS + 1))]
    if incomplete:
        sample = "; ".join(f"{k[0]}. sınıf {k[1]} ({k[2]})" for k in incomplete[:3])
        problems.append(
            f"{len(incomplete)} ders grubunda 39 haftanın tamamı yok (örn: {sample})."
        )

    for r in records:
        week = r.get("weekNumber")
        if not isinstance(week, int) or not 1 <= week <= TOTAL_WEEKS:
            problems.append(f"Geçersiz hafta numarası: {r.get('id')} -> {week}")
            break

    empty_desc = sum(1 for r in records if not (r.get("outcomeDescription") or "").strip())
    if empty_desc:
        problems.append(f"{empty_desc} kaydın kazanım açıklaması boş.")

    return problems


def repetition_report(records: list[dict]) -> list[tuple[tuple, int, int]]:
    """Ders haftaları içinde tekrarlanan kazanımları raporlar (uyarı, hata değil)."""
    groups: dict[tuple, list[str]] = {}
    for r in records:
        if r.get("isHolidayWeek") or r.get("isSocialEventWeek"):
            continue
        key = (r.get("gradeLevel"), r.get("subjectCode"), r.get("publisher"))
        groups.setdefault(key, []).append(r.get("outcomeDescription", ""))

    report = []
    for key, descs in groups.items():
        unique = len(set(descs))
        if unique < len(descs):
            report.append((key, len(descs), unique))
    report.sort(key=lambda item: item[2] / item[1] if item[1] else 1)
    return report


# --------------------------------------------------------------------------
# Yeniden inşa
# --------------------------------------------------------------------------

# MEB resmî planlarında DEĞERLER sütunu "D3. Çalışkanlık, D5. Duyarlılık"
# biçiminde numaralı erdem kodları taşır. Eski üretilmiş veride ise değerler
# düz metindir ("Estetik, Sağlıklı Yaşam"). Ayırt edici işaret budur:
# beceri kodları (AB/KB/SDB) her iki kaynakta da geçtiği için kullanılamaz.
_OFFICIAL_VALUE_CODE = re.compile(r"\bD\d{1,2}\.")


def is_official_meta(text: str | None) -> bool:
    """Metin MEB resmî planından gelen kodlu DEĞERLER listesi mi?"""
    return bool(text and _OFFICIAL_VALUE_CODE.search(text))



# TYMM öğretim programı PDF'lerinden çıkarılan, kazanım koduna bağlı
# resmî ders yaşantıları (extract_pdf_activities.py üretir).
PDF_ACTIVITIES = os.path.join(REPO_ROOT, "data_sources", "pdf_activities.json")


def load_pdf_activities() -> dict[str, str]:
    """Kazanım kodu -> MEB'in yazdığı öğrenme-öğretme uygulaması."""
    if not os.path.exists(PDF_ACTIVITIES):
        return {}
    try:
        with open(PDF_ACTIVITIES, encoding="utf-8") as handle:
            data = json.load(handle)
        return {k: v for k, v in data.items() if isinstance(v, str) and v.strip()}
    except (OSError, ValueError):
        return {}


def annotate_multi_week_spans(records: list[dict]) -> None:
    """Aynı kazanımın birden çok hafta sürdüğünü kayda işler.

    Kaynak planlarda bir kazanım 2-5 hafta sürebiliyor ve o haftaların
    metni BİREBİR aynı oluyor (2. sınıf Türkçe'de aynı kazanım 5 hafta).
    Bu bir veri hatası değil, MEB planının gerçeği.

    Özet uydurmak yerine durumu görünür kılıyoruz: kayda kaçıncı hafta
    olduğu ve toplam kaç hafta sürdüğü yazılır; kart bunu
    "3 haftalık kazanımın 2. haftası" gibi gösterir. Öğretmen böylece
    tekrarın hata değil plan gereği olduğunu anlar.
    """
    groups: dict[tuple, list[dict]] = {}
    for record in records:
        if record.get("isHolidayWeek"):
            continue
        key = (record["gradeLevel"], record["subjectCode"], record["publisher"])
        groups.setdefault(key, []).append(record)

    for items in groups.values():
        items.sort(key=lambda r: r["weekNumber"])
        run_start = 0
        for index in range(1, len(items) + 1):
            same = (
                index < len(items)
                and items[index]["outcomeDescription"]
                == items[run_start]["outcomeDescription"]
                and items[index]["weekNumber"]
                == items[index - 1]["weekNumber"] + 1
            )
            if same:
                continue

            span = index - run_start
            if span > 1:
                for offset in range(span):
                    items[run_start + offset]["spanIndex"] = offset + 1
                    items[run_start + offset]["spanTotal"] = span
            run_start = index


def rebuild(records: list[dict], academic_year: str) -> list[dict]:
    """Kayıtları hedef yıla göre normalize eder ve kimlikleri çakışmasız üretir."""
    calendar = build_calendar(academic_year)
    # MEB'in resmî ders anlatımları; kazanım koduyla eşleştirilir.
    pdf_activities = load_pdf_activities()
    rebuilt: list[dict] = []
    used_ids: set[str] = set()

    for record in records:
        grade = int(record.get("gradeLevel") or 5)
        subject_name = (record.get("subjectName") or "Genel Ders").strip()
        # Publisher YALNIZCA okul turudur (Anadolu / Fen / Sosyal
        # Bilimler Lisesi). Bos kalabilir; "MEB Yayinlari" yazmak bir
        # okul turu degil "bilinmiyor" demekti ve kaynak alaniyla
        # karisip Maarif rozetini bozuyordu.
        publisher = (record.get("publisher") or "").strip()
        week = int(record.get("weekNumber") or 1)
        if not 1 <= week <= TOTAL_WEEKS:
            continue

        # ADA Yayinlari plani ayri bir DERS degil; ayni Turkce dersinin
        # farkli ders kitabina gore plani. Ders adi Turkce olmali,
        # ayrim publisher alaninda durmali.
        if "ada yayinlari" in fold(subject_name):
            publisher = publisher or "ADA Yayınları"
            subject_name = "Türkçe"

        # Branş kodu ham ders adından yeniden hesaplanır; eski verideki
        # 'GENEL' çöp kovası bu adımda temizlenir.
        subject_code = detect_subject_code(subject_name)
        # Kategori her zaman ders adından yeniden hesaplanır. Eski veride
        # tüm kayıtlar "core" olarak gömülüydü; korunursa panelin
        # Seçmeli/Kurs/İHO/Harezmi sekmeleri hep boş kalıyordu.
        category = detect_category(subject_name)
        info = calendar[week]

        is_holiday = info["is_holiday"]
        is_otp = info["is_otp"] and not is_holiday
        is_social = info["is_social_event"] and not is_holiday

        # Eski yıla ait gömülü hafta tarihleri ayıklanır; takvim bilgisi
        # yalnızca dateRange alanlarından gelir.
        unit_title = strip_stale_dates(record.get("unitTitle") or "")
        topic_title = strip_stale_dates(record.get("topicTitle") or "")
        raw_description = record.get("outcomeDescription") or ""
        description = trim_description(
            normalize_codes(strip_stale_dates(raw_description)))
        outcome_code = record.get("outcomeCode")

        # Takvim durumu değişmişse (yeni yılda tatil haftası kaymışsa)
        # içerik metinleri de o duruma uydurulur.
        if is_holiday:
            note = info["holiday_note"] or "Resmî Tatil"
            unit_title = topic_title = note
            outcome_code = "TATIL"
            description = f"{note} - MEB resmî çalışma takvimi uyarınca eğitim öğretime ara verilmiştir."
        elif is_social:
            unit_title = unit_title or "Sosyal Etkinlikler"
            topic_title = "Sosyal, Kültürel ve Sanatsal Etkinlikler"
            description = description or (
                "Dönem sonu sosyal, kültürel, sanatsal ve bilimsel etkinlikler gerçekleştirilir."
            )

        if not unit_title:
            unit_title = f"{(week - 1) // 5 + 1}. Ünite"
        if not topic_title:
            topic_title = unit_title
        # Boş veya dolgu metin: gerçek kazanım yok.
        unplanned = (
            not is_holiday
            and not is_social
            # HAM metne bakılır; temizlik sonrası kalan parça yanıltıyor.
            and (is_unplanned(raw_description) or is_unplanned(description))
        )
        if unplanned:
            description = (
                f"{topic_title or unit_title} — bu hafta için kaynak planda "
                "kazanım belirtilmemiş."
            )

        parts = parse_outcomes(description)
        codes = outcome_codes(description)
        # Tek kod varsa outcomeCode alanını ondan doldur; kaynakta çoğu
        # zaman bu alan boş geliyor.
        if not outcome_code and len(codes) == 1:
            outcome_code = codes[0]
        # Planlanmamış haftaya kazanım kodu YAZILMAZ. Eskiden 'GENEL.5.4'
        # gibi uydurma kodlar üretiliyor ve gerçek kazanım koduymuş gibi
        # görünüyordu.
        if unplanned:
            outcome_code = None
        # 'GENEL.5.4' gibi kodlar MEB'in değil, eski bir üretimin izidir;
        # gerçek kazanım koduymuş gibi görünüp yanıltıyordu.
        if outcome_code and outcome_code.upper().startswith("GENEL"):
            outcome_code = None

        # Kazanım kodlarından ilkinin PDF'teki resmî anlatımı.
        official_activity = None
        for candidate in codes:
            if candidate in pdf_activities:
                official_activity = pdf_activities[candidate]
                break

        meta = build_meta(
            subject_code, unit_title, topic_title, description,
            is_otp=is_otp, is_social=is_social, is_holiday=is_holiday,
        )

        # Kaynaktan gelen pedagojik alanlar YALNIZCA resmî MEB planından
        # geliyorsa korunur (D3./SDB1.2/OB1 gibi kodlu). Eski üretilmiş
        # değerler yeniden hesaplanır: o veri, branş kodu hatalıyken
        # üretilmişti ve Matematik'e Beden Eğitimi becerileri yazıyordu.
        source_values = record.get("maarifValues")
        source_skills = record.get("maarifSkills")
        keep_source = is_official_meta(source_values)

        school_type = school_type_for_grade(grade)
        year_key = parse_academic_year(academic_year)[0]
        # Yayınevi kimliğe girer; aynı sınıf/branşta birden fazla yayınevinin
        # planı bir arada durabilsin diye.
        doc_id = f"out_{school_type.lower()}_{year_key}_{grade}_{subject_code}_{slugify(publisher)}_w{week}"
        if doc_id in used_ids:
            suffix = 2
            while f"{doc_id}_v{suffix}" in used_ids:
                suffix += 1
            doc_id = f"{doc_id}_v{suffix}"
        used_ids.add(doc_id)

        rebuilt.append({
            "id": doc_id,
            "academicYear": academic_year,
            "gradeLevel": grade,
            "subjectCode": subject_code,
            "subjectName": subject_name,
            "publisher": publisher,
            "fullTitle": f"{grade}. Sınıf - {subject_name} - {publisher}",
            "category": category,
            "schoolType": school_type,
            # Kaynak: hangi MEB sitesinden geldi ve hangi programa ait.
            # Excel sutun basligindan OLCULUR, tahmin edilmez.
            "sourcePortal": record.get("sourcePortal") or "",
            "sourceProgram": record.get("sourceProgram") or "",
            # Maarif rozeti buradan turetilir.
            #
            # Once SABIT True yaziliyordu: 9087 kaydin hepsi, Maarif'in
            # yururlukte olmadigi 3-4, 7-8, 11-12. siniflar dahil.
            # Ogretmene guncel program diye eski programi gostermek
            # yaniltici.
            "isMaarif": record.get("sourceProgram") == "maarif",
            "weekNumber": week,
            "teachingWeekNumber": info["teaching_week"],
            "dateRangeStr": info["formatted"],
            "dateRange": {
                "startDate": info["start"],
                "endDate": info["end"],
                "formatted": info["formatted"],
            },
            "term": info["term"],
            "unitTitle": unit_title,
            "topicTitle": topic_title,
            "outcomeCode": outcome_code,
            "outcomeDescription": description,
            # Bir hafta birden fazla kazanım taşıyabiliyor (MEB planlarında
            # 317 kayıtta böyle). Düz metin olarak basılınca hangi maddenin
            # hangi kazanıma ait olduğu anlaşılmıyordu; uygulama bu yapıyı
            # kullanarak her kazanımı ayrı blok gösterir.
            "outcomeParts": parts,
            "outcomeCodes": codes,
            "isHolidayWeek": is_holiday,
            "holidayNote": info["holiday_note"],
            "isOtpWeek": is_otp,
            "isSocialEventWeek": is_social,
            "maarifSummary": meta["maarifSummary"],
            "maarifValues": (source_values if keep_source else None) or meta["maarifValues"],
            "maarifSkills": (source_skills if keep_source else None) or meta["maarifSkills"],
            "differentiation": (record.get("differentiation") if keep_source else None)
                               or meta["differentiation"],
            # OTP / sosyal etkinlik haftalarında branşa uygun ÖNERİ
            # etkinlikleri. Resmî kazanım değildir; MEB bu haftalarda
            # içerik belirlemez, karar zümrenindir.
            "suggestedActivities": meta.get("suggestedActivities") or [],
            # MEB'in öğretim programı PDF'inde bu kazanım için yazdığı
            # ders anlatımı. Bizim ürettiğimiz özetten farklı olarak
            # RESMÎ metindir; kartta öyle etiketlenir.
            "officialActivity": official_activity,
            # Haftalık dağılım MEB tarafından yayımlanmadıysa (seçmeli
            # dersler) kazanımlar eşit dağıtılır ve bu bayrak konur.
            # Kazanımların KENDİSİ resmîdir, yalnızca hangi hafta
            # işleneceği tahmindir; kart bunu açıkça yazar.
            "isEstimatedSchedule": bool(record.get("isEstimatedSchedule")),
            # Kaynak planda bu hafta için kazanım yok.
            "isPlaceholder": unplanned,
            "hasOfficialMeta": keep_source,
        })

    rebuilt = _fill_missing_weeks(rebuilt, calendar, academic_year, used_ids)
    # AYNI BRANS KODU TEK ADLA GORUNSUN.
    #
    # Ayni ders eski veride BUYUK HARF ("BEDEN EGITIMI VE SPOR"), yeni
    # resmi veride Baslik Bicimi ("Beden Egitimi ve Spor") yazilmis.
    # Ders listesinde iki kez gorunuyor ve ogretmen hangisinin guncel
    # oldugunu bilemiyor.
    #
    # Resmi kaynaktan (sourcePortal dolu) gelen ad kazanir; esitlikte
    # en cok kullanilan.
    import collections as _c
    ad_oylari: dict[str, _c.Counter] = {}
    for r in rebuilt:
        anahtar = r["subjectCode"]
        sayac = ad_oylari.setdefault(anahtar, _c.Counter())
        # Resmi kayitlar agir basar.
        agirlik = 1000 if r.get("sourcePortal") else 1
        sayac[r["subjectName"]] += agirlik
    for r in rebuilt:
        anahtar = r["subjectCode"]
        kazanan = ad_oylari[anahtar].most_common(1)[0][0]
        if r["subjectName"] != kazanan:
            r["subjectName"] = kazanan
            r["fullTitle"] = (f'{r["gradeLevel"]}. Sınıf - {kazanan}'
                              + (f' - {r["publisher"]}' if r["publisher"] else ''))

    rebuilt.sort(key=lambda r: (r["gradeLevel"], r["subjectCode"], r["publisher"], r["weekNumber"]))
    annotate_multi_week_spans(rebuilt)
    return rebuilt


def _fill_missing_weeks(records: list[dict], calendar: dict, academic_year: str,
                        used_ids: set[str]) -> list[dict]:
    """Kaynakta bulunmayan takvim haftalarını tamamlar.

    MEB'in resmî taslak yıllık planları yalnızca ders yapılan haftaları
    satır olarak yazar; ara tatil ve yarıyıl haftaları listede yoktur.
    Uygulama 39 haftalık akışı gösterdiği için bu boşluklar takvimden
    doldurulur. İçerik UYDURULMAZ: tatil haftası tatil kartı olur,
    diğerleri boş ders haftası olarak işaretlenir.
    """
    groups: dict[tuple, list[dict]] = {}
    for record in records:
        key = (record["gradeLevel"], record["subjectCode"], record["publisher"])
        groups.setdefault(key, []).append(record)

    filled: list[dict] = list(records)

    for key, items in groups.items():
        present = {item["weekNumber"] for item in items}
        missing = [w for w in range(1, TOTAL_WEEKS + 1) if w not in present]
        if not missing:
            continue

        template = items[0]
        for week in missing:
            info = calendar[week]
            is_holiday = info["is_holiday"]
            is_otp = info["is_otp"] and not is_holiday
            is_social = info["is_social_event"] and not is_holiday

            if is_holiday:
                note = info["holiday_note"] or "Resmî Tatil"
                unit = topic = note
                code = "TATIL"
                description = (
                    f"{note} - MEB resmî çalışma takvimi uyarınca "
                    "eğitim öğretime ara verilmiştir."
                )
            elif is_social:
                unit = "Sosyal Etkinlikler"
                topic = "Sosyal, Kültürel ve Sanatsal Etkinlikler"
                code = None
                description = (
                    "Dönem sonu sosyal, kültürel, sanatsal ve bilimsel "
                    "etkinlikler gerçekleştirilir."
                )
            elif is_otp:
                unit = topic = "Okul Temelli Planlama"
                code = None
                description = (
                    "Okul Temelli Planlama haftası: zümre kararlarına göre "
                    "derinleştirme veya telafi çalışmaları yürütülür."
                )
            else:
                # Resmî planda karşılığı olmayan ders haftası: içerik
                # uydurmak yerine açıkça boş bırakılır.
                unit = topic = "Planlanmamış Hafta"
                code = None
                description = (
                    "Bu hafta için resmî yıllık planda kayıt bulunmuyor. "
                    "Zümre kararına göre doldurulmalıdır."
                )

            meta = build_meta(key[1], unit, topic, is_otp=is_otp,
                              is_social=is_social, is_holiday=is_holiday)

            doc_id = (f"out_{template['schoolType'].lower()}_"
                      f"{parse_academic_year(academic_year)[0]}_{key[0]}_{key[1]}_"
                      f"{slugify(key[2])}_w{week}")
            suffix = 2
            while doc_id in used_ids:
                doc_id = f"{doc_id}_v{suffix}"
                suffix += 1
            used_ids.add(doc_id)

            filled.append({
                **template,
                "id": doc_id,
                "weekNumber": week,
                "teachingWeekNumber": info["teaching_week"],
                "dateRangeStr": info["formatted"],
                "dateRange": {
                    "startDate": info["start"],
                    "endDate": info["end"],
                    "formatted": info["formatted"],
                },
                "term": info["term"],
                "unitTitle": unit,
                "topicTitle": topic,
                "outcomeCode": code,
                "outcomeDescription": description,
                "isHolidayWeek": is_holiday,
                "holidayNote": info["holiday_note"],
                "isOtpWeek": is_otp,
                "isSocialEventWeek": is_social,
                "isPlaceholder": not (is_holiday or is_social or is_otp),
                **meta,
            })

    return filled


# --------------------------------------------------------------------------
# Çıktı yazımı
# --------------------------------------------------------------------------

def write_presets_js(records: list[dict], academic_year: str, path: str) -> None:
    """Admin panelinin beklediği API ile JS veri dosyasını üretir.

    Panel `CurriculumPresets.getAllOfficialPresets()` ve
    `CurriculumPresets.applyPreset()` çağırır; bu yüzden sınıf burada
    tanımlanır. Yalnızca ham diziyi yazmak paneli sessizce boş bırakır.
    """
    # Panelin yükünü küçültmek için iki sıkıştırma uygulanır:
    #   1) Tekrar eden uzun metinler (differentiation'da 5811 kayda karşılık
    #      yalnızca 50 benzersiz değer var) bir sözlüğe alınıp indisle anılır.
    #   2) dateRange sözlüğü atılır; 'formatted' alanı dateRangeStr ile
    #      birebir aynı, start/end panelde kullanılmıyor.
    # Böylece 11 MB'lık dosya belirgin biçimde küçülür ve tarayıcı hem daha
    # hızlı ayrıştırır hem de daha az bellek harcar.
    pooled_fields = ("maarifSummary", "maarifValues", "maarifSkills",
                     "differentiation", "unitTitle", "topicTitle")
    pools: dict[str, list[str]] = {field: [] for field in pooled_fields}
    pool_index: dict[str, dict[str, int]] = {field: {} for field in pooled_fields}

    compact_records = []
    for record in records:
        item = {k: v for k, v in record.items() if k != "dateRange"}
        for field in pooled_fields:
            value = item.get(field)
            if not isinstance(value, str) or not value:
                continue
            index = pool_index[field].get(value)
            if index is None:
                index = len(pools[field])
                pools[field].append(value)
                pool_index[field][value] = index
            item[field] = index
        compact_records.append(item)

    payload = json.dumps(compact_records, ensure_ascii=False, separators=(",", ":"))
    pools_payload = json.dumps(pools, ensure_ascii=False, separators=(",", ":"))
    fields_payload = json.dumps(list(pooled_fields))

    content = f"""/**
 * SınıfCepte Admin Portalı - Resmî MEB Maarif Modeli Müfredat Kütüphanesi
 * Eğitim Öğretim Yılı: {academic_year}
 * Toplam Kayıt: {len(records)}
 *
 * OTOMATİK ÜRETİLDİ - elle düzenlemeyin.
 * Yeniden üretmek için:
 *   python scripts/maarif/build_curriculum.py --year {academic_year}
 *
 * Tekrar eden metinler _POOLS sözlüğünde tutulur; kayıtlarda indis olarak
 * durur ve yükleme sırasında geri yazılır.
 */

window.OFFICIAL_MAARIF_POOLS = {pools_payload};
window.OFFICIAL_MAARIF_POOLED_FIELDS = {fields_payload};

window.OFFICIAL_MAARIF_OUTCOMES_PRESET = (function () {{
  const rows = {payload};
  const pools = window.OFFICIAL_MAARIF_POOLS;
  const fields = window.OFFICIAL_MAARIF_POOLED_FIELDS;
  for (let i = 0; i < rows.length; i++) {{
    const row = rows[i];
    for (let f = 0; f < fields.length; f++) {{
      const key = fields[f];
      const value = row[key];
      if (typeof value === 'number') row[key] = pools[key][value];
    }}
    // Flutter tarafındaki dateRange yapısı panelde dateRangeStr ile temsil
    // edilir; geriye dönük okuyucular için türetilir.
    if (row.dateRangeStr) {{
      row.dateRange = {{ formatted: row.dateRangeStr }};
    }}
  }}
  return rows;
}})();

// Geriye dönük uyumluluk: eski sürümler ham diziyi bu adla okuyordu.
window.CURRICULUM_PRESETS = window.OFFICIAL_MAARIF_OUTCOMES_PRESET;

class CurriculumPresets {{
  static get ACADEMIC_YEAR() {{
    return '{academic_year}';
  }}

  static getAllOfficialPresets() {{
    return window.OFFICIAL_MAARIF_OUTCOMES_PRESET || [];
  }}

  /** Sınıf/branş anahtarına göre alt küme uygular. presetKey: 'GRADE_SUBJECT' */
  static applyPreset(presetKey, outcomesManager) {{
    const all = this.getAllOfficialPresets();
    if (!presetKey || presetKey === 'ALL') {{
      outcomesManager.outcomes = [...all];
      outcomesManager.save();
      return outcomesManager.outcomes.length;
    }}

    const [gradePart, subjectPart] = String(presetKey).split('_');
    const grade = parseInt(gradePart, 10);
    const subset = all.filter((item) => {{
      const gradeMatches = Number.isNaN(grade) || item.gradeLevel === grade;
      const subjectMatches = !subjectPart || item.subjectCode === subjectPart;
      return gradeMatches && subjectMatches;
    }});

    // Aynı sınıf/branşın eski kayıtlarını temizleyip yenisini koy.
    const keep = outcomesManager.outcomes.filter((item) => {{
      const gradeMatches = Number.isNaN(grade) || item.gradeLevel === grade;
      const subjectMatches = !subjectPart || item.subjectCode === subjectPart;
      return !(gradeMatches && subjectMatches);
    }});

    outcomesManager.outcomes = keep.concat(subset);
    outcomesManager.save();
    return subset.length;
  }}
}}

window.CurriculumPresets = CurriculumPresets;
"""
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(content)


def main() -> int:
    parser = argparse.ArgumentParser(description="SınıfCepte müfredat boru hattı")
    parser.add_argument("--year", default="2026-2027",
                        help="Hedef eğitim öğretim yılı (örn. 2027-2028)")
    parser.add_argument("--source", default=DATA_JSON,
                        help="Kaynak kazanım JSON dosyası")
    parser.add_argument("--check", action="store_true",
                        help="Dosya yazmadan yalnızca doğrula")
    args = parser.parse_args()

    parse_academic_year(args.year)  # biçim hatasını erken yakala

    if not os.path.exists(args.source):
        print(f"HATA: Kaynak dosya bulunamadı: {args.source}")
        return 1

    with open(args.source, "r", encoding="utf-8") as handle:
        source_records = json.load(handle)
    print(f"Kaynak kayit sayisi : {len(source_records)}")

    stale_before = count_stale_dates(source_records)
    records = rebuild(source_records, args.year)
    stale_after = count_stale_dates(records)
    print(f"Uretilen kayit      : {len(records)}")
    print(f"Egitim ogretim yili : {args.year}")
    if stale_before:
        print(f"Eski tarih temizligi: {stale_before} -> {stale_after} kayit")

    problems = validate(records)
    if problems:
        print("\nDOGRULAMA HATALARI:")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("Dogrulama           : temiz (kimlik cakismasi yok, 39 hafta tam)")

    repeats = repetition_report(records)
    if repeats:
        print(f"\nUYARI: {len(repeats)} ders grubunda kazanim metni tekrar ediyor.")
        print("Bu bir veri kalitesi sorunudur; ilgili branslara gercek yillik plan girilmeli.")
        for key, total, unique in repeats[:8]:
            print(f"  - {key[0]}. sinif {key[1]}: {total} ders haftasi / {unique} benzersiz kazanim")

    if args.check:
        print("\n--check modu: hicbir dosya yazilmadi.")
        return 0

    with open(DATA_JSON, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)
    print(f"\nYazildi: {DATA_JSON}")

    write_presets_js(records, args.year, PRESETS_JS)
    print(f"Yazildi: {PRESETS_JS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

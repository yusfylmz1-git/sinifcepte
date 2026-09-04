"""
SınıfCepte - Seçmeli ders haftalık planı üretici (PDF kazanımlarından).

    python scripts/maarif/build_elective_plans.py

DURUM: MEB seçmeli dersler için TASLAK YILLIK PLAN yayımlamıyor.
`tymm.meb.gov.tr/taslak-cerceve-planlari` yalnızca 11 zorunlu dersi
kapsıyor; seçmeli derslerin haftalık dağılımı yok.

Elimizde olan: öğretim programı PDF'lerinden çıkarılmış RESMÎ kazanım
kodları ve MEB'in ders anlatımları (`pdf_activities.json`).

Bu script o kazanımları ders haftalarına EŞİT DAĞITIR. Dağıtım MEB'in
kararı DEĞİLDİR; bu yüzden üretilen her kayıt `isEstimatedSchedule=True`
ile işaretlenir ve uygulama bunu açıkça belirtir:

    "Haftalık dağılım MEB tarafından yayımlanmadı; kazanımlar eşit
     dağıtılmıştır. Zümrenizin planına göre değişebilir."

Kazanımların KENDİSİ resmîdir, yalnızca hangi hafta işleneceği tahmindir.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academic_calendar import TOTAL_WEEKS, build_calendar  # noqa: E402
from turkish_text import detect_category  # noqa: E402

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES = os.path.join(REPO_ROOT, "data_sources")
CATALOG = os.path.join(SOURCES, "tymm_program_catalog.json")
ACTIVITIES = os.path.join(SOURCES, "pdf_activities.json")
DEFAULT_OUTPUT = os.path.join(SOURCES, "elective_plan_raw.json")

# Kazanım kodu öneki -> (ders adı, sınıf listesi).
# Önekler pdf_activities.json'daki gerçek kodlardan alındı.
# Kazanım kodu öneki -> (ders adı, ders kategorisi, okutulduğu sınıflar).
#
# DİKKAT: Koddaki İLK sayı SINIF DEĞİL, ünite numarasıdır ('GKN.1.1.1' =
# 1. ünite, 1. kazanım). Bu yüzden sınıf koddan okunamaz; MEB'in haftalık
# ders çizelgesindeki seviyeler burada elle yazılır.
ELECTIVE_COURSES: dict[str, tuple[str, tuple[int, ...]]] = {
    "GKN": ("Görgü Kuralları ve Nezaket", (5, 6, 7, 8)),
    "RİHO": ("Ritim Eğitimi ve Halk Oyunları", (5, 6, 7, 8)),
    "MD": ("Masal ve Destanlarımız", (5, 6)),
    "YYB": ("Yazarlık ve Yazma Becerileri", (6, 7, 8)),
    "TG": ("Trafik Güvenliği", (4,)),
    "MU": ("Matematik ve Bilim Uygulamaları", (5, 6, 7, 8)),
    "BU": ("Bilim Uygulamaları", (5, 6, 7, 8)),
    "TT": ("Teknoloji ve Tasarım", (7, 8)),
    "ÇAPU": ("Çocuklarda Atletik Performans Uygulamaları", (9, 10, 11, 12)),
    "BEST": ("Beden Eğitimi ve Sporun Temelleri", (9, 10, 11, 12)),
}


def load_json(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def build_records(activities: dict[str, str], academic_year: str) -> list[dict]:
    calendar = build_calendar(academic_year)
    teaching_weeks = [w for w, info in calendar.items() if not info["is_holiday"]]

    # Önek bazında kazanımları topla (sınıf koddan okunamaz).
    buckets: dict[str, list[tuple[str, str]]] = {}
    for code, body in sorted(activities.items()):
        prefix_match = re.match(r"[A-ZÇĞİÖŞÜ]+", code)
        if not prefix_match:
            continue
        prefix = prefix_match.group()
        if prefix in ELECTIVE_COURSES:
            buckets.setdefault(prefix, []).append((code, body))

    records: list[dict] = []
    for prefix, items in sorted(buckets.items()):
        name, grades = ELECTIVE_COURSES[prefix]
        category = detect_category(name)
        total = len(teaching_weeks)

        for grade in grades:
            for index, week in enumerate(teaching_weeks):
                position = min(index * len(items) // total, len(items) - 1)
                code, body = items[position]
                records.append({
                    "gradeLevel": grade,
                    "subjectName": name,
                    "publisher": "MEB Yayınları",
                    "weekNumber": week,
                    "unitTitle": name,
                    "topicTitle": name,
                    "outcomeCode": code,
                    "outcomeDescription": f"{code} {body}",
                    "category": category,
                    # Haftalık dağılım MEB'in değil, bizim tahminimiz.
                    "isEstimatedSchedule": True,
                })

    return records


def main() -> int:
    parser = argparse.ArgumentParser(description="Seçmeli ders planı üretici")
    parser.add_argument("--year", default="2026-2027")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    activities = load_json(ACTIVITIES)
    if not activities:
        print(f"HATA: {ACTIVITIES} yok veya bos.")
        print("Once calistirin: python scripts/maarif/extract_pdf_activities.py")
        return 1

    records = build_records(activities, args.year)
    if not records:
        print("UYARI: Secmeli ders kazanimi bulunamadi.")
        return 1

    groups = {(r["gradeLevel"], r["subjectName"]) for r in records}
    print(f"Uretilen kayit : {len(records)}")
    print(f"Ders grubu     : {len(groups)}")
    for grade, name in sorted(groups):
        count = sum(1 for r in records
                    if r["gradeLevel"] == grade and r["subjectName"] == name)
        unique = len({r["outcomeCode"] for r in records
                      if r["gradeLevel"] == grade and r["subjectName"] == name})
        print(f"   {grade:2d}. {name[:36]:<38} {count} hafta / {unique} kazanim")

    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)
    print(f"\nYazildi: {args.output}")
    print("\nNOT: Haftalik dagilim MEB'in karari DEGILDIR; kazanimlar esit")
    print("dagitilmistir ve kayitlar isEstimatedSchedule ile isaretlidir.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

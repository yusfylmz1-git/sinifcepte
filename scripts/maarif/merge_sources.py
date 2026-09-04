"""
SınıfCepte - Kaynakları birleştirip boru hattına verilecek ham veriyi üretir.

    python scripts/maarif/merge_sources.py

Üç kaynak vardır ve hiçbiri diğerini kapsamaz:

  1. Zümre Excel'i (1-8. sınıf)        -> import_excel.py
     Okulun kendi yıllık planı. MEB 1-8 için taslak plan yayımlamıyor.

  2. TYMM taslak yıllık planları (9-12) -> fetch/import_tymm_plans.py
     tymm.meb.gov.tr/taslak-cerceve-planlari

  3. DÖGM çerçeve yıllık planları       -> fetch_dogm_plans.py
     dogm.meb.gov.tr - İmam Hatip ve din dersleri. Bu dersler TYMM
     portalında YOKTUR; panelin İHÖ sekmesini yalnızca bu kaynak doldurur.

Aynı (sınıf, ders, yayınevi, hafta) için birden fazla kayıt gelirse
öncelik sırası: DÖGM > TYMM > mevcut/zümre. Resmî kaynak elle girilen
veriyi ezer.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(REPO_ROOT, "data_sources")
SHIPPED = os.path.join(REPO_ROOT, "assets", "data", "official_maarif_kazanimlar.json")
DEFAULT_OUTPUT = os.path.join(SOURCES_DIR, "merged_raw.json")

RAW_FIELDS = (
    "gradeLevel", "subjectName", "publisher", "weekNumber",
    "unitTitle", "topicTitle", "outcomeDescription", "outcomeCode",
    "maarifSummary", "maarifValues", "maarifSkills", "differentiation",
    "category", "isEstimatedSchedule",
)


def to_raw(record: dict) -> dict:
    return {key: record.get(key) for key in RAW_FIELDS}


def load(path: str, label: str) -> list[dict]:
    if not os.path.exists(path):
        print(f"  {label:<34} (yok, atlandi)")
        return []
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    print(f"  {label:<34} {len(data)} kayit")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description="Kaynak birleştirici")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    print("Kaynaklar okunuyor:")
    shipped = load(SHIPPED, "mevcut yayin verisi")
    tymm = load(os.path.join(SOURCES_DIR, "tymm_plan_raw.json"), "TYMM taslak planlari (9-12)")
    dogm = load(os.path.join(SOURCES_DIR, "dogm_plan_raw.json"), "DOGM cerceve planlari (IHO)")
    elective = load(os.path.join(SOURCES_DIR, "elective_plan_raw.json"),
                    "Secmeli ders planlari (tahmini)")

    if not shipped and not tymm and not dogm and not elective:
        print("\nHATA: Hicbir kaynak bulunamadi.")
        return 1

    # Anahtar: aynı dersin aynı haftası tek kayıt olmalı.
    merged: dict[tuple, dict] = {}

    def add(records: list[dict], overwrite: bool) -> int:
        added = 0
        for record in records:
            key = (
                record.get("gradeLevel"),
                (record.get("subjectName") or "").casefold(),
                (record.get("publisher") or "").casefold(),
                record.get("weekNumber"),
            )
            if key in merged and not overwrite:
                continue
            merged[key] = to_raw(record)
            added += 1
        return added

    # 1-8 zümre verisi tabandır; 9-12'yi resmî kaynak yeniden yazar.
    base = [r for r in shipped if (r.get("gradeLevel") or 0) <= 8]
    add(base, overwrite=True)
    print(f"\n1-8 taban kayit     : {len(base)}")
    print(f"TYMM eklenen        : {add(tymm, overwrite=True)}")
    print(f"DOGM eklenen        : {add(dogm, overwrite=True)}")
    # Seçmeli planlar TAHMİNÎ dağılımdır; resmî kaynakları ezmez.
    print(f"Secmeli eklenen     : {add(elective, overwrite=False)}")

    records = list(merged.values())
    records.sort(key=lambda r: (r["gradeLevel"], r["subjectName"] or "",
                                r["publisher"] or "", r["weekNumber"] or 0))

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)

    grades = sorted({r["gradeLevel"] for r in records})
    print(f"\nToplam benzersiz    : {len(records)}")
    print(f"Siniflar            : {grades}")
    print(f"\nYazildi: {args.output}")
    print("\nSonraki adim:")
    print(f'  python scripts/maarif/build_curriculum.py --source "{args.output}" --year 2026-2027')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""
SınıfCepte - Kazanım verisi kalite denetimi.

    python scripts/maarif/audit_data.py              # özet + sorunlu gruplar
    python scripts/maarif/audit_data.py --full       # 1. sınıftan 12'ye tüm dersler
    python scripts/maarif/audit_data.py --grade 5    # tek sınıf
    python scripts/maarif/audit_data.py --samples 3  # her gruptan örnek satır

Gözle bakarak yakalanan hataları (uydurma 'GENEL.5.4' kodu, "Week 4:
29 September" gibi tarih-metinler, aynı kazanımın 7 hafta tekrarı,
1871 karakterlik ünite blokları) sistematik olarak arar.

Her ders grubu için şu kontroller yapılır:

  KOD      Kazanım kodu tanınıyor mu, uydurma mı?
  DOLU     Kaç hafta gerçek içerik taşıyor?
  BENZERSİZ Aynı metin kaç kez tekrar ediyor?
  UZUNLUK  Kartta okunamayacak kadar uzun mu?
  BOZUK    Kod ortadan bölünmüş mü, tarih artığı kalmış mı?

Çıkış kodu: sorun bulunursa 1, temizse 0 (CI'da kullanılabilir).
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build_curriculum import is_unplanned  # noqa: E402
from outcome_parts import outcome_codes  # noqa: E402

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(REPO_ROOT, "assets", "data", "official_maarif_kazanimlar.json")

# Kartta okunabilir üst sınır (build_curriculum ile aynı mantık).
LONG_TEXT = 720

# Kod ortadan bölünmüş: 'A RP. 1 0.1.1' / '10. 1.1.2'
BROKEN_CODE = [
    re.compile(r"\b[A-ZÇĞİÖŞÜ]\s+[A-ZÇĞİÖŞÜ]{1,5}\s*\.\s*\d"),
    re.compile(r"\b\d\s+\d+\.\d"),
    re.compile(r"\d\.\s+\d+\.\d"),
]

# Metinde kalmış eski yıl tarihi.
STALE_DATE = re.compile(
    r"\b(?:Week|Hafta)\s*\d+\s*[:.]", re.IGNORECASE)

CATEGORY_LABEL = {
    "core": "Ders",
    "elective": "Seçmeli",
    "iho": "İHÖ",
    "course": "Kurs",
    "harezmi": "Harezmî",
}


class GroupReport:
    """Tek bir (sınıf, ders, yayınevi) grubunun denetim sonucu."""

    def __init__(self, key: tuple, records: list[dict]) -> None:
        self.grade, self.subject, self.publisher = key
        self.records = sorted(records, key=lambda r: r["weekNumber"])
        self.category = records[0].get("category", "core")

        lessons = [r for r in self.records
                   if not (r.get("isHolidayWeek") or r.get("isOtpWeek")
                           or r.get("isSocialEventWeek"))]
        self.lesson_count = len(lessons)

        self.unplanned = [r for r in lessons if r.get("isPlaceholder")]
        real = [r for r in lessons if not r.get("isPlaceholder")]
        self.real_count = len(real)

        descriptions = [r.get("outcomeDescription", "") for r in real]
        self.unique = len(set(descriptions))

        self.without_code = [r for r in real if not r.get("outcomeCode")]
        self.fabricated = [r for r in self.records
                           if (r.get("outcomeCode") or "").upper().startswith("GENEL")]
        self.too_long = [r for r in self.records
                         if len(r.get("outcomeDescription") or "") > LONG_TEXT]
        self.broken = [r for r in self.records
                       if any(p.search(r.get("outcomeDescription") or "")
                              for p in BROKEN_CODE)]
        self.stale = [r for r in self.records
                      if STALE_DATE.search(r.get("outcomeDescription") or "")]
        self.estimated = any(r.get("isEstimatedSchedule") for r in self.records)

        weeks = {r["weekNumber"] for r in self.records}
        self.missing_weeks = sorted(set(range(1, 40)) - weeks)

    @property
    def uniqueness(self) -> float:
        return self.unique / self.real_count if self.real_count else 0.0

    @property
    def coverage(self) -> float:
        return self.real_count / self.lesson_count if self.lesson_count else 0.0

    def problems(self) -> list[str]:
        """Yayına engel veya dikkat isteyen bulgular."""
        found: list[str] = []
        if self.missing_weeks:
            found.append(f"eksik hafta: {len(self.missing_weeks)}")
        if self.fabricated:
            found.append(f"UYDURMA KOD: {len(self.fabricated)}")
        if self.broken:
            found.append(f"bölünmüş kod: {len(self.broken)}")
        if self.stale:
            found.append(f"tarih artığı: {len(self.stale)}")
        if self.too_long:
            found.append(f"aşırı uzun: {len(self.too_long)}")
        if self.coverage < 0.5:
            found.append(f"içerik %{self.coverage * 100:.0f}")
        if self.real_count and self.uniqueness < 0.35:
            found.append(f"tekrar (benzersiz %{self.uniqueness * 100:.0f})")
        return found

    def status(self) -> str:
        problems = self.problems()
        if any(p.startswith(("UYDURMA", "bölünmüş", "eksik")) for p in problems):
            return "HATA"
        if problems:
            return "UYARI"
        return "TEMİZ"


def load_records() -> list[dict]:
    with open(DATA, encoding="utf-8") as handle:
        return json.load(handle)


def build_reports(records: list[dict]) -> list[GroupReport]:
    groups: dict[tuple, list[dict]] = {}
    for record in records:
        key = (record["gradeLevel"], record["subjectName"], record["publisher"])
        groups.setdefault(key, []).append(record)
    return [GroupReport(k, v) for k, v in sorted(groups.items())]


def print_group(report: GroupReport, samples: int) -> None:
    status = report.status()
    mark = {"HATA": "✗", "UYARI": "!", "TEMİZ": "✓"}[status]
    label = CATEGORY_LABEL.get(report.category, report.category)
    tag = " [tahminî takvim]" if report.estimated else ""

    print(f"  {mark} {report.subject[:34]:<34} {report.publisher[:22]:<22} "
          f"{label:<8} içerik {report.real_count:2d}/{report.lesson_count:2d} "
          f"benzersiz %{report.uniqueness * 100:3.0f}{tag}")

    problems = report.problems()
    if problems:
        print(f"      -> {', '.join(problems)}")

    for record in report.records[:samples] if samples else []:
        flag = "PLANSIZ" if record.get("isPlaceholder") else "       "
        code = record.get("outcomeCode") or "-"
        body = (record.get("outcomeDescription") or "")[:64]
        print(f"      w{record['weekNumber']:2d} {flag} {code:<14} {body}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Kazanım verisi denetimi")
    parser.add_argument("--full", action="store_true",
                        help="Tüm sınıf ve dersleri sırayla listele")
    parser.add_argument("--grade", type=int, help="Yalnızca bu sınıf")
    parser.add_argument("--samples", type=int, default=0,
                        help="Her gruptan N örnek satır göster")
    args = parser.parse_args()

    if not os.path.exists(DATA):
        print(f"HATA: Veri yok: {DATA}")
        return 1

    records = load_records()
    reports = build_reports(records)
    if args.grade:
        reports = [r for r in reports if r.grade == args.grade]

    total = len(reports)
    errors = [r for r in reports if r.status() == "HATA"]
    warnings = [r for r in reports if r.status() == "UYARI"]
    clean = total - len(errors) - len(warnings)

    if args.full or args.grade:
        current = None
        for report in reports:
            if report.grade != current:
                current = report.grade
                subjects = sum(1 for r in reports if r.grade == current)
                print(f"\n{'=' * 78}")
                print(f"{current}. SINIF  ({subjects} ders grubu)")
                print("=" * 78)
            print_group(report, args.samples)
    else:
        if errors:
            print("HATALI GRUPLAR")
            print("-" * 78)
            for report in errors:
                print(f"  {report.grade:2d}. sınıf", end=" ")
                print_group(report, args.samples)
        if warnings:
            print("\nUYARILI GRUPLAR (ilk 15)")
            print("-" * 78)
            for report in warnings[:15]:
                print(f"  {report.grade:2d}. sınıf", end=" ")
                print_group(report, 0)

    print(f"\n{'=' * 78}")
    print(f"TOPLAM {total} ders grubu:  "
          f"temiz {clean}  |  uyarı {len(warnings)}  |  HATA {len(errors)}")

    # Genel istatistikler
    all_records = [r for rep in reports for r in rep.records]
    lessons = [r for r in all_records
               if not (r.get("isHolidayWeek") or r.get("isOtpWeek")
                       or r.get("isSocialEventWeek"))]
    unplanned = sum(1 for r in lessons if r.get("isPlaceholder"))
    fabricated = sum(1 for r in all_records
                     if (r.get("outcomeCode") or "").upper().startswith("GENEL"))
    print(f"Ders haftası {len(lessons)} | içeriksiz {unplanned} "
          f"(%{unplanned / len(lessons) * 100:.0f}) | uydurma kod {fabricated}")

    by_category = collections.Counter(r.get("category") for r in all_records)
    print("Kategori:", dict(by_category))

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

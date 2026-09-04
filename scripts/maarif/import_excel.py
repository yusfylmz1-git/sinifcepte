"""
SınıfCepte - Excel yıllık plan içe aktarıcı.

    python scripts/maarif/import_excel.py --excel "C:\\...\\TUM_DERSLER.xlsx" --year 2026-2027

Zümre/MEB çerçeve planlarını taşıyan Excel dosyasını okur ve boru hattının
anladığı ham kayıt listesine çevirir. Çıktı doğrudan build_curriculum.py'ye
verilir; branş kodu, takvim ve kimlik üretimi orada yapılır.

Beklenen sekme yapısı (59 sekmede doğrulandı):
    Plan Sırası | Ders Tipi | Branş | Sınıf | Yayın / Program | Ünite / Tema | Kazanım / Konu | Hafta

Sekme adı `<sınıf>-<branş>-<yayınevi>` biçimindedir (örn. "5-Matematik-TYMM")
ve hücre değerleri eksikse yedek olarak kullanılır.

ÖNEMLİ: Bu script veri UYDURMAZ. Bir hafta kaynakta yoksa boş bırakılır ve
raporlanır; eski boru hattı gibi tema listesini döngüye sokup sahte kazanım
üretmez.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academic_calendar import TOTAL_WEEKS  # noqa: E402

try:
    import openpyxl
except ImportError:  # pragma: no cover
    print("HATA: openpyxl gerekli.  pip install openpyxl")
    raise SystemExit(1)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Ara çıktı; uygulama paketine girmemesi için assets/ dışında tutulur.
DEFAULT_OUTPUT = os.path.join(REPO_ROOT, "data_sources", "imported_raw_outcomes.json")

# Sekme adındaki kısaltmaların tam yayınevi adına karşılığı
PUBLISHER_ALIASES = {
    "tymm": "TYMM (Maarif Modeli)",
    "cydem": "ÇYDEM (Maarif Modeli)",
    "çydem": "ÇYDEM (Maarif Modeli)",
    "meb": "MEB Yayınları",
    "özgün": "Özgün Yayınları",
    "ozgun": "Özgün Yayınları",
    "hecce": "Hecce Yayınları",
    "ilke": "İlke Yayınları",
    "i̇lke": "İlke Yayınları",
    "ada": "Ada Yayınları",
    "koza": "Koza Yayınları",
    "anıttepe": "Anıttepe Yayınları",
}

COLUMN_HINTS = {
    "planOrder": ("plan sırası", "sıra"),
    "lessonType": ("ders tipi",),
    "subject": ("branş", "brans"),
    "grade": ("sınıf", "sinif"),
    "publisher": ("yayın", "program", "yayin"),
    "unit": ("ünite", "tema", "unite"),
    "outcome": ("kazanım", "konu", "kazanim"),
    "week": ("hafta", "week"),
}


def clean(value) -> str:
    if value is None:
        return ""
    return re.sub(r"\s+", " ", str(value)).strip()


def normalize_publisher(raw: str) -> str:
    text = clean(raw)
    if not text:
        return ""
    key = text.casefold()
    for alias, full in PUBLISHER_ALIASES.items():
        if key == alias or key.startswith(alias):
            return full
    return text


def parse_sheet_name(sheet_name: str) -> tuple[int | None, str, str]:
    """'5-Matematik-TYMM' -> (5, 'Matematik', 'TYMM (Maarif Modeli)')."""
    base = re.sub(r"_\d+$", "", sheet_name.strip())  # '_2' varyant ekini at
    parts = [p.strip() for p in base.split("-") if p.strip()]
    grade = None
    if parts and parts[0].isdigit():
        grade = int(parts[0])
        parts = parts[1:]
    subject = parts[0] if parts else ""
    publisher = normalize_publisher(parts[1]) if len(parts) > 1 else ""
    return grade, subject, publisher


def locate_columns(rows: list[tuple]) -> tuple[int, dict[str, int]]:
    """Başlık satırını ve sütun indekslerini bulur."""
    for row_index in range(min(5, len(rows))):
        cells = [clean(c).casefold() for c in rows[row_index]]
        if not any("kazanım" in c or "kazanim" in c for c in cells):
            continue

        mapping: dict[str, int] = {}
        for col_index, cell in enumerate(cells):
            if not cell:
                continue
            for field, hints in COLUMN_HINTS.items():
                if field in mapping:
                    continue
                if any(hint in cell for hint in hints):
                    mapping[field] = col_index
                    break
        if "outcome" in mapping:
            return row_index, mapping
    return -1, {}


def read_sheet(worksheet, sheet_name: str) -> tuple[list[dict], list[str]]:
    problems: list[str] = []
    rows = list(worksheet.iter_rows(values_only=True))
    if len(rows) < 2:
        return [], [f"{sheet_name}: sekme boş"]

    header_index, columns = locate_columns(rows)
    if header_index == -1:
        return [], [f"{sheet_name}: başlık satırı bulunamadı (Kazanım sütunu yok)"]

    default_grade, default_subject, default_publisher = parse_sheet_name(sheet_name)

    def cell(row: tuple, field: str) -> str:
        index = columns.get(field, -1)
        if index == -1 or index >= len(row):
            return ""
        return clean(row[index])

    records: list[dict] = []
    seen_weeks: set[int] = set()

    for row in rows[header_index + 1:]:
        if not any(row):
            continue

        week_text = cell(row, "week")
        week_match = re.search(r"\d+", week_text)
        if not week_match:
            continue  # hafta numarası olmayan satır plan satırı değildir
        week = int(week_match.group())
        if not 1 <= week <= TOTAL_WEEKS:
            problems.append(f"{sheet_name}: geçersiz hafta {week}, satır atlandı")
            continue
        if week in seen_weeks:
            problems.append(f"{sheet_name}: {week}. hafta birden fazla satırda, ilki kullanıldı")
            continue
        seen_weeks.add(week)

        grade_text = cell(row, "grade")
        grade = int(grade_text) if grade_text.isdigit() else default_grade
        if grade is None:
            problems.append(f"{sheet_name}: sınıf belirlenemedi, sekme atlandı")
            return [], problems

        subject_name = cell(row, "subject") or default_subject
        publisher = normalize_publisher(cell(row, "publisher")) or default_publisher or "MEB Yayınları"

        records.append({
            "gradeLevel": grade,
            "subjectName": subject_name,
            "publisher": publisher,
            "weekNumber": week,
            "unitTitle": cell(row, "unit"),
            "topicTitle": cell(row, "unit"),
            "outcomeDescription": cell(row, "outcome"),
            "sourceSheet": sheet_name,
        })

    missing = sorted(set(range(1, TOTAL_WEEKS + 1)) - seen_weeks)
    if missing:
        problems.append(
            f"{sheet_name}: {len(missing)} hafta eksik ({', '.join(map(str, missing[:6]))}"
            f"{'...' if len(missing) > 6 else ''}) - boş kayıtla tamamlandı"
        )
        # Boru hattı 39 haftanın tamamını ister; eksikler BOŞ olarak eklenir,
        # sahte içerik uydurulmaz.
        for week in missing:
            template = records[0] if records else {}
            records.append({
                "gradeLevel": template.get("gradeLevel", default_grade),
                "subjectName": template.get("subjectName", default_subject),
                "publisher": template.get("publisher", default_publisher or "MEB Yayınları"),
                "weekNumber": week,
                "unitTitle": "",
                "topicTitle": "",
                "outcomeDescription": "",
                "sourceSheet": sheet_name,
                "isPlaceholder": True,
            })

    records.sort(key=lambda r: r["weekNumber"])
    return records, problems


def import_workbook(path: str, skip_sheets: tuple[str, ...] = (),
                    keep_variants: bool = False) -> tuple[list[dict], list[str]]:
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    all_records: list[dict] = []
    all_problems: list[str] = []

    # '5-İngilizce-ÇYDEM' ve '5-İngilizce-ÇYDEM_2' aynı dersin iki kopyasıdır.
    # İkisi de alınırsa aynı ders grubu 39 yerine 78 hafta görünür ve
    # kazanımlar tekrar ediyormuş gibi raporlanır. Varsayılan olarak en çok
    # dolu haftası olan varyant seçilir.
    by_group: dict[tuple, list[tuple[str, list[dict]]]] = {}

    for sheet_name in workbook.sheetnames:
        if sheet_name in skip_sheets or sheet_name.startswith("~"):
            continue
        records, problems = read_sheet(workbook[sheet_name], sheet_name)
        all_problems.extend(problems)
        if not records:
            continue

        if keep_variants:
            all_records.extend(records)
            continue

        first = records[0]
        key = (first["gradeLevel"], first["subjectName"].casefold(), first["publisher"])
        by_group.setdefault(key, []).append((sheet_name, records))

    if keep_variants:
        return all_records, all_problems

    for key, candidates in by_group.items():
        if len(candidates) == 1:
            all_records.extend(candidates[0][1])
            continue

        # En çok gerçek (placeholder olmayan) kaydı olan varyantı seç.
        def filled(item: tuple[str, list[dict]]) -> int:
            return sum(1 for r in item[1] if not r.get("isPlaceholder"))

        best = max(candidates, key=filled)
        dropped = [name for name, _ in candidates if name != best[0]]
        all_problems.append(
            f"{key[0]}. sınıf {key[1]} ({key[2]}): {len(candidates)} kopya sekme bulundu, "
            f"'{best[0]}' kullanıldı, atlanan: {', '.join(dropped)}"
        )
        all_records.extend(best[1])

    return all_records, all_problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Excel yıllık plan içe aktarıcı")
    parser.add_argument("--excel", required=True, help="Kaynak .xlsx dosyası")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--skip", nargs="*", default=["TÜM DERSLER BİRLEŞİK"],
                        help="Atlanacak sekme adları")
    parser.add_argument("--keep-variants", action="store_true",
                        help="Kopya sekmeleri ('_2') ayıklama, hepsini al")
    args = parser.parse_args()

    if not os.path.exists(args.excel):
        print(f"HATA: Excel bulunamadi: {args.excel}")
        return 1

    print(f"Okunuyor: {args.excel}")
    records, problems = import_workbook(args.excel, tuple(args.skip), args.keep_variants)

    groups = {(r["gradeLevel"], r["subjectName"], r["publisher"]) for r in records}
    placeholders = sum(1 for r in records if r.get("isPlaceholder"))

    print(f"Okunan kayit    : {len(records)}")
    print(f"Ders grubu      : {len(groups)}")
    if placeholders:
        print(f"Bos hafta       : {placeholders} (kaynakta yoktu, uydurulmadi)")

    if problems:
        print(f"\n{len(problems)} uyari:")
        for problem in problems[:15]:
            print(f"  - {problem}")
        if len(problems) > 15:
            print(f"  ... {len(problems) - 15} uyari daha")

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(records, handle, ensure_ascii=False, indent=2)
    print(f"\nYazildi: {args.output}")
    print(f"\nSonraki adim:\n  python scripts/maarif/build_curriculum.py "
          f"--source \"{args.output}\" --year <yil>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

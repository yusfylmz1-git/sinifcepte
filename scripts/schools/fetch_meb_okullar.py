#!/usr/bin/env python3
"""Operatör makinesi: isteğe bağlı üçüncü parti / MEB çekimi. CI'da çağrılmaz."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen

FIXTURE_DIR = Path(__file__).resolve().parent / "fixtures"
FIXTURE_DIR.mkdir(parents=True, exist_ok=True)

GITHUB_JSON = (
    "https://raw.githubusercontent.com/MehmetHuseyinDelipalta/"
    "MEB-Okul-Veritabani/main/T%C3%BCm%20Okullar/okullar.json"
)


def main() -> int:
    dest = FIXTURE_DIR / "meb_raw_github.json"
    print("GitHub kamu dizinini indirmeyi deniyorum (MEB AJAX CI'da yok).")
    try:
        req = Request(GITHUB_JSON, headers={"User-Agent": "SinifCepteSchoolImport/1.0"})
        with urlopen(req, timeout=120) as resp:
            payload = resp.read()
        dest.write_bytes(payload)
        print(f"yazildi {dest} ({len(payload)} byte)")
        return 0
    except Exception as exc:
        print(f"indirme basarisiz: {exc}", file=sys.stderr)
        print("Elle bir CSV/JSON koyun: scripts/schools/fixtures/")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

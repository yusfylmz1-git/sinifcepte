#!/usr/bin/env python3
"""Fixture + mevcut JSON'dan 81 il shard'ı üretir. Canlı MEB HTTP çağırmaz."""
from __future__ import annotations

import hashlib
import json
import os
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROVINCES_PATH = ROOT / "assets" / "data" / "provinces_districts.json"
LEGACY_SCHOOLS = ROOT / "assets" / "data" / "schools_data.json"
OUT_DIR = ROOT / "assets" / "data" / "schools"
FIXTURE_DIR = ROOT / "scripts" / "schools" / "fixtures"
LEGACY_DIR = ROOT / "assets" / "data" / "legacy"


def normalize_tr(text: str) -> str:
    table = str.maketrans(
        {
            "İ": "i",
            "I": "i",
            "ı": "i",
            "Ğ": "g",
            "ğ": "g",
            "Ü": "u",
            "ü": "u",
            "Ş": "s",
            "ş": "s",
            "Ö": "o",
            "ö": "o",
            "Ç": "c",
            "ç": "c",
        }
    )
    return text.translate(table).lower().strip()


def infer_type(name: str) -> str:
    n = name.lower()
    if "bilsem" in n or "bilim ve sanat" in n:
        return "BİLSEM"
    if "özel" in n or "kolej" in n:
        return "Özel Okul / Kolej"
    if "sosyal bilimler" in n:
        return "Sosyal Bilimler Lisesi"
    if "fen lisesi" in n:
        return "Fen Lisesi"
    if "mesleki" in n or "mtal" in n or "teknik anadolu" in n:
        return "Mesleki ve Teknik Anadolu Lisesi"
    if "imam hatip lisesi" in n or "anadolu imam" in n:
        return "Anadolu İmam Hatip Lisesi"
    if "imam hatip ortaokulu" in n:
        return "İmam Hatip Ortaokulu"
    if "anadolu lisesi" in n or "çpal" in n or "çok programlı" in n:
        return "Anadolu Lisesi"
    if "ortaokul" in n:
        return "Ortaokul"
    if "ilkokul" in n:
        return "İlkokul"
    return "Diğer"


def excluded(name: str) -> bool:
    n = name.lower()
    return any(
        token in n
        for token in (
            "milli eğitim müdürlüğü",
            "ilçe milli",
            "il milli",
            "bakanlık",
        )
    )


def load_provinces():
    provinces = json.loads(PROVINCES_PATH.read_text(encoding="utf-8"))
    by_name = {normalize_tr(p["name"]): p for p in provinces}
    return provinces, by_name


def stable_slug(text: str) -> str:
    n = normalize_tr(text)
    n = re.sub(r"[^a-z0-9]+", "_", n).strip("_")
    return n[:48] or "okul"


def school_id(city_code: str, raw: dict) -> str:
    yol = str(raw.get("YOL") or raw.get("yol") or "")
    if yol:
        segment = yol.replace("\\", "/").rstrip("/").split("/")[-1]
        if segment.isdigit():
            return f"meb_{segment}"
    kod = str(raw.get("meb_kurum_kodu") or raw.get("KURUM_KODU") or raw.get("id") or "")
    digits = re.sub(r"\D", "", kod)
    if digits:
        return f"meb_{city_code}_{digits}"
    return f"meb_{city_code}_{stable_slug(raw.get('name') or raw.get('OKUL_ADI') or 'okul')}"


def collect_rows(provinces, by_name):
    rows = []
    sources = []

    for fixture in sorted(FIXTURE_DIR.glob("*.json*")):
        if fixture.name.endswith(".md"):
            continue
        try:
            payload = json.loads(fixture.read_text(encoding="utf-8"))
            sources.append(fixture.name)
            if isinstance(payload, list):
                rows.extend(payload)
            elif isinstance(payload, dict):
                if isinstance(payload.get("schools"), list):
                    rows.extend(payload["schools"])
                else:
                    for city, districts in payload.items():
                        if not isinstance(districts, dict):
                            continue
                        for district, schools in districts.items():
                            if not isinstance(schools, list):
                                continue
                            for sch in schools:
                                if isinstance(sch, dict):
                                    sch = dict(sch)
                                    sch.setdefault("city", city)
                                    sch.setdefault("IL", city)
                                    sch.setdefault("district", district)
                                    sch.setdefault("ILCE", district)
                                    rows.append(sch)
        except Exception as exc:
            print(f"fixture atlandı {fixture}: {exc}")

    extra = Path(os.environ.get("SINIFCEPTE_SCHOOL_SOURCE", "").strip())
    if extra and extra.exists():
        try:
            payload = json.loads(extra.read_text(encoding="utf-8"))
            sources.append(extra.name)
            if isinstance(payload, list):
                rows.extend(payload)
            elif isinstance(payload, dict):
                if isinstance(payload.get("schools"), list):
                    rows.extend(payload["schools"])
                else:
                    for city, districts in payload.items():
                        if city == "BAKANLIK" or not isinstance(districts, dict):
                            continue
                        for district, schools in districts.items():
                            if not isinstance(schools, list):
                                continue
                            for sch in schools:
                                if isinstance(sch, dict):
                                    sch = dict(sch)
                                    sch.setdefault("city", city)
                                    sch.setdefault("IL", city)
                                    sch.setdefault("district", district)
                                    sch.setdefault("ILCE", district)
                                    rows.append(sch)
        except Exception as exc:
            print(f"extra source atlandı {extra}: {exc}")

    if LEGACY_SCHOOLS.exists():
        try:
            legacy = json.loads(LEGACY_SCHOOLS.read_text(encoding="utf-8"))
            if isinstance(legacy, list):
                rows.extend(legacy)
                sources.append("schools_data.json")
        except Exception as exc:
            print(f"legacy atlandı: {exc}")

    return rows, sources


def normalize_row(raw: dict, by_name: dict) -> dict | None:
    name = (raw.get("name") or raw.get("OKUL_ADI") or raw.get("okul_adi") or "").strip()
    city = (raw.get("city") or raw.get("IL") or raw.get("il") or "").strip()
    district = (raw.get("district") or raw.get("ILCE") or raw.get("ilce") or "").strip()
    if not name or not city or excluded(name):
        return None
    province = by_name.get(normalize_tr(city))
    if not province:
        return None
    city_code = str(province["code"]).zfill(2)
    city_name = province["name"]
    sid = school_id(city_code, raw)
    kurum = None
    if sid.startswith("meb_") and sid.count("_") == 1:
        kurum = sid.split("_", 1)[1]
    return {
        "id": sid,
        "meb_kurum_kodu": raw.get("meb_kurum_kodu") or kurum,
        "name": name,
        "city": city_name,
        "city_code": city_code,
        "district": district or "Merkez",
        "type": raw.get("type") or infer_type(name),
        "status": "active",
        "source": "resmi_liste",
    }


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    LEGACY_DIR.mkdir(parents=True, exist_ok=True)
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)
    provinces, by_name = load_provinces()
    raw_rows, sources = collect_rows(provinces, by_name)

    by_id = {}
    unmapped = 0
    for raw in raw_rows:
        if not isinstance(raw, dict):
            continue
        row = normalize_row(raw, by_name)
        if row is None:
            unmapped += 1
            continue
        by_id[row["id"]] = row

    shards = defaultdict(list)
    for row in by_id.values():
        shards[row["city_code"]].append(row)

    provinces_meta = []
    for p in provinces:
        code = str(p["code"]).zfill(2)
        schools = sorted(shards.get(code, []), key=lambda s: (s["district"], s["name"]))
        out_file = OUT_DIR / f"tr_{code}.json"
        out_file.write_text(json.dumps(schools, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        digest = hashlib.sha256(out_file.read_bytes()).hexdigest()
        provinces_meta.append(
            {
                "code": code,
                "name": p["name"],
                "count": len(schools),
                "file": f"tr_{code}.json",
                "sha256": digest,
            }
        )

    total = sum(p["count"] for p in provinces_meta)
    manifest = {
        "calendar_version": 1,
        "outcomes_version": 1,
        "announcements_version": 1,
        "school_directory_version": 1,
        "min_app_version": "1.0.0",
        "latest_app_version": "1.0.0",
        "maintenance_mode": False,
        "maintenance_message": None,
        "last_updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pack_base_url": "",
        "source": "+".join(sources) or "empty",
        "source_fetched_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "total_schools": total,
        "unmapped_rows": unmapped,
        "provinces": provinces_meta,
    }
    (OUT_DIR / "schools_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    if LEGACY_SCHOOLS.exists():
        target = LEGACY_DIR / "schools_data.json"
        if not target.exists():
            target.write_bytes(LEGACY_SCHOOLS.read_bytes())

    print(f"okullar={total} kaynak={sources} unmapped={unmapped}")
    empty = [p["name"] for p in provinces_meta if p["count"] == 0]
    if empty:
        print(f"bos_iller={len(empty)} ornek={empty[:8]}")


if __name__ == "__main__":
    main()

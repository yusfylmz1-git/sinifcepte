"""
!!! KULLANIMDAN KALDIRILDI - CALISTIRMAYIN !!!
Ayrintilar icin: scripts/_deprecated/README.md
Yerine: python scripts/maarif/build_curriculum.py --year <yil>
"""
import sys

print(__doc__, file=sys.stderr)
raise SystemExit(
    "Bu script kullanimdan kaldirildi. "
    "Kullanin: python scripts/maarif/build_curriculum.py --year <yil>"
)

# --- Eski kod yalnizca referans icin asagida korunuyor ---

if False:  # noqa
    import json
    import os

    JSON_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "official_maarif_kazanimlar.json")
    JS_PATH = os.path.join(os.path.dirname(__file__), "..", "admin_portal", "js", "curriculum_presets.js")

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"Loaded {len(data)} outcomes from {JSON_PATH}")

    js_content = f"""/**
     * SınıfCepte Admin Portalı - Resmî MEB Maarif Modeli Müfredat Kütüphanesi
     * Toplam {len(data)} Haftalık Kazanım ve Yıllık Plan
     * Otomatik üretildi.
     */
    const CurriculumPresets = {{
      OFFICIAL_DATABASE: {json.dumps(data, ensure_ascii=False, indent=2)}
    }};

    if (typeof window !== 'undefined') {{
      window.CurriculumPresets = CurriculumPresets;
    }}
    """

    with open(JS_PATH, "w", encoding="utf-8") as f:
        f.write(js_content)

    print(f"Successfully generated {JS_PATH}")

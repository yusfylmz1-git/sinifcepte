"""
SınıfCepte - tymm.meb.gov.tr resmî öğretim programı KATALOĞU indirici.

ÖNEMLİ - bu script ne yapar, ne yapmaz:

  YAPAR : tymm.meb.gov.tr üzerindeki ders sayfalarını ve her dersin resmî
          öğretim programı PDF bağlantısını listeler.
  YAPMAZ: haftalık kazanım/yıllık plan ÜRETMEZ.

Nedeni: TYMM portalı öğretim programlarını yalnızca PDF olarak yayımlar.
PDF'ler ders kazanımlarını içerir ama haftalara dağıtılmış yıllık plan
içermez; haftalık dağılım okul zümreleri tarafından yapılır. Dolayısıyla
"siteden çekip doğrudan haftalık plan üretmek" mümkün değildir.

Bu script kataloğu çıkarır; hangi derste program güncellenmiş, hangi ders
elimizdeki veri paketinde eksik, onu görmeye yarar. Haftalık plan verisi
Excel/zümre kaynaklarından build_curriculum.py ile üretilir.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from turkish_text import detect_category, detect_subject_code  # noqa: E402

BASE_URL = "https://tymm.meb.gov.tr"
CATALOG_PATH = "/ogretim-programlari/"
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUTPUT_JSON = os.path.join(REPO_ROOT, "data_sources", "tymm_program_catalog.json")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def fetch(url: str, timeout: int = 25) -> str | None:
    """Sayfayı indirir. Hata durumunda None döner ve sebebi bildirir."""
    # Bazı ders adresleri Türkçe harf içeriyor ('...halk-oyunları-dersi');
    # ham hâlde gönderilirse http istemcisi ascii kodlamada patlar.
    url = urllib.parse.quote(url, safe=":/?&=%#")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    # NOT: Sertifika doğrulaması AÇIK bırakıldı. Eski sürüm CERT_NONE
    # kullanıyordu; bu, ortadaki adam saldırısına açık hâle getiriyordu.
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(request, context=context, timeout=timeout) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, errors="replace")
    except urllib.error.HTTPError as error:
        print(f"  HTTP {error.code}: {url}")
    except urllib.error.URLError as error:
        print(f"  Baglanti hatasi: {url} ({error.reason})")
    except ssl.SSLError as error:
        print(f"  SSL hatasi: {url} ({error})")
    except TimeoutError:
        print(f"  Zaman asimi: {url}")
    return None


def strip_tags(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html)).strip()


def fetch_program_list() -> list[dict]:
    """Ders listesini JSON ucundan sayfalayarak çeker.

    Sayfa HTML'i dersleri JavaScript ile yüklüyor ve her istekte RASTGELE
    20 ders döndürüyor. HTML'i regex ile taramak bu yüzden eksik sonuç
    verir (72 dersin yalnızca 20'si). Doğru yol sayfalı JSON ucudur;
    sıralama rastgele olduğu için ilk yanıttaki `seed` sonraki sayfalara
    taşınmalı, yoksa kayıtlar tekrarlanır.
    """
    first_raw = fetch(f"{BASE_URL}/Ders/GetProgramList?page=1")
    if not first_raw:
        return []
    first = json.loads(first_raw)

    items = list(first.get("items") or [])
    seed = first.get("seed")
    total_pages = int(first.get("totalPages") or 1)

    for page in range(2, total_pages + 1):
        url = f"{BASE_URL}/Ders/GetProgramList?page={page}"
        if seed is not None:
            url += f"&seed={seed}"
        raw = fetch(url)
        if not raw:
            continue
        items.extend(json.loads(raw).get("items") or [])

    unique = {item["id"]: item for item in items if item.get("id") is not None}
    expected = int(first.get("totalCount") or len(unique))
    if len(unique) != expected:
        print(f"  UYARI: {expected} ders bekleniyordu, {len(unique)} alindi")
    return list(unique.values())


def parse_lesson(html: str, slug: str) -> dict:
    title_match = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.IGNORECASE | re.DOTALL)
    title = strip_tags(title_match.group(1)) if title_match else slug.replace("-", " ")

    # Dersin kendi programı: paylaşılan kılavuz/broşür PDF'lerini eler.
    pdfs = re.findall(r'href=["\']([^"\']+\.pdf)["\']', html, re.IGNORECASE)
    program_pdfs = [p for p in dict.fromkeys(pdfs)
                    if "/upload/kilavuz/" not in p and "/upload/brosur/" not in p]

    return {
        "slug": slug,
        "title": title,
        "subjectCode": detect_subject_code(title),
        "url": f"{BASE_URL}/ogretim-programlari/ders/{slug}",
        "programPdfs": [p if p.startswith("http") else BASE_URL + p for p in program_pdfs],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="TYMM öğretim programı kataloğu")
    parser.add_argument("--output", default=OUTPUT_JSON)
    parser.add_argument("--limit", type=int, default=0,
                        help="Yalnızca ilk N dersi çek (test için)")
    args = parser.parse_args()

    print(f"Ders listesi aliniyor: {BASE_URL}/Ders/GetProgramList")
    programs = fetch_program_list()
    if not programs:
        print("HATA: Ders listesi alinamadi. Site yapisi degismis olabilir.")
        return 1

    if args.limit:
        programs = programs[:args.limit]
    print(f"Bulunan ders: {len(programs)}")

    entries, failed = [], []
    for index, program in enumerate(programs, 1):
        slug = program.get("url") or ""
        if not slug:
            continue
        print(f"  [{index}/{len(programs)}] {slug}")
        page = fetch(f"{BASE_URL}/ogretim-programlari/ders/{slug}")
        if not page:
            failed.append(slug)
            continue
        entry = parse_lesson(page, slug)
        # Liste ucundan gelen resmî ad ve kademe bilgisi daha güvenilir.
        entry["title"] = program.get("dersAdi") or entry["title"]
        entry["subjectCode"] = detect_subject_code(entry["title"])
        entry["category"] = detect_category(entry["title"])
        entry["kademe"] = program.get("kademe")
        entries.append(entry)

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump({
            "source": BASE_URL + CATALOG_PATH,
            "lessonCount": len(entries),
            "lessons": entries,
        }, handle, ensure_ascii=False, indent=2)

    print(f"\nYazildi: {args.output} ({len(entries)} ders)")
    if failed:
        print(f"Alinamayan {len(failed)} ders: {', '.join(failed)}")

    print("\nNOT: Bu katalog haftalik kazanim URETMEZ. TYMM programlari PDF")
    print("olarak yayimlanir ve haftalik dagilim icermez. Haftalik plan verisi")
    print("icin: python scripts/maarif/build_curriculum.py --year <yil>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

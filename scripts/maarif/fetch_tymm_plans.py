"""
SınıfCepte - MEB TYMM resmî TASLAK YILLIK PLAN indirici.

    python scripts/maarif/fetch_tymm_plans.py --year 2026-2027

tymm.meb.gov.tr/taslak-cerceve-planlari sayfasındaki resmî taslak yıllık plan
ZIP arşivlerini indirir ve açar. Bu arşivler, öğretim programı PDF'lerinin
AKSİNE kazanımları haftalara dağıtılmış hâlde içerir:

    AY | HAFTA | DERS SAATİ | ÜNİTE/TEMA | KONU | ÖĞRENME ÇIKTILARI |
    SÜREÇ BİLEŞENLERİ | ÖLÇME VE DEĞERLENDİRME | SDB | DEĞERLER |
    OKURYAZARLIK BECERİLERİ | BELİRLİ GÜN VE HAFTALAR | FARKLILAŞTIRMA |
    OKUL TEMELLİ PLANLAMA

Yani uygulamanın gösterdiği her alan resmî kaynakta karşılığını buluyor.

İndirilen dosyalar `--out` klasörüne açılır; içeriği okumak için
`import_tymm_plans.py` kullanılır.
"""

from __future__ import annotations

import argparse
import os
import re
import ssl
import sys
import urllib.error
import urllib.request
import zipfile

BASE_URL = "https://tymm.meb.gov.tr"
PLANS_PATH = "/taslak-cerceve-planlari"
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# NOT: assets/data/ Flutter paketine gömülür. Ham kaynak dosyalar
# (~5 MB Excel) uygulamaya girmesin diye depo kökünde ayrı tutulur.
DEFAULT_OUT = os.path.join(REPO_ROOT, "data_sources", "tymm_plans")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def fetch(url: str, timeout: int = 120) -> bytes | None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    context = ssl.create_default_context()  # sertifika doğrulaması açık
    try:
        with urllib.request.urlopen(request, context=context, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        print(f"  HTTP {error.code}: {url}")
    except urllib.error.URLError as error:
        print(f"  Baglanti hatasi: {error.reason}")
    except TimeoutError:
        print(f"  Zaman asimi: {url}")
    return None


def decode_member_name(info: zipfile.ZipInfo) -> str:
    """Arşiv içi dosya adını doğru kodlamayla çözer.

    ZIP, UTF-8 bayrağı (0x800) yoksa adları cp437 kabul eder; Python da
    öyle çözer. MEB arşivleri Türkçe adları Windows-1254 ile yazdığı için
    'LİSESİ' -> 'LÿSESÿ' gibi bozuk adlar çıkıyordu; okul türü bu yüzden
    tespit edilemiyordu. Ham baytları geri alıp doğru kodlamayla çözüyoruz.
    """
    if info.flag_bits & 0x800:
        return info.filename  # zaten UTF-8

    raw = info.filename.encode("cp437", errors="replace")
    for encoding in ("utf-8", "cp1254", "cp857"):
        try:
            decoded = raw.decode(encoding)
        except UnicodeDecodeError:
            continue
        # Türkçe harf içeriyorsa doğru kodlamayı bulduk sayılır.
        if any(ch in decoded for ch in "İıĞğŞşÇçÖöÜü"):
            return decoded
    return raw.decode("cp1254", errors="replace")


def discover_plan_archives(html: str) -> list[tuple[str, str]]:
    """(ders_slug, mutlak_url) listesi döner."""
    hrefs = re.findall(r'href="([^"]+\.zip)"', html, re.IGNORECASE)
    found: list[tuple[str, str]] = []
    for href in dict.fromkeys(hrefs):
        filename = href.rsplit("/", 1)[-1]
        # 'felsefe-dersi-taslak-yillik-planlar_20260827_123428_620.zip'
        slug = re.sub(r"-taslak-yillik-planlar.*$", "", filename, flags=re.IGNORECASE)
        slug = re.sub(r"\.zip$", "", slug, flags=re.IGNORECASE)
        url = href if href.startswith("http") else BASE_URL + href
        found.append((slug, url))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="TYMM taslak yıllık plan indirici")
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--only", nargs="*", help="Yalnızca bu ders slug'larını indir")
    parser.add_argument("--list", action="store_true", help="İndirme, yalnızca listele")
    args = parser.parse_args()

    print(f"Sayfa aliniyor: {BASE_URL}{PLANS_PATH}")
    page = fetch(BASE_URL + PLANS_PATH, timeout=40)
    if not page:
        print("HATA: Sayfa alinamadi.")
        return 1

    archives = discover_plan_archives(page.decode("utf-8", errors="replace"))
    if not archives:
        print("HATA: Taslak plan arsivi bulunamadi. Site yapisi degismis olabilir.")
        return 1

    if args.only:
        wanted = {s.casefold() for s in args.only}
        archives = [a for a in archives if a[0].casefold() in wanted]

    print(f"Bulunan taslak plan arsivi: {len(archives)}\n")
    for slug, url in archives:
        print(f"  {slug:<42} {url.rsplit('/', 1)[-1]}")

    if args.list:
        return 0

    os.makedirs(args.out, exist_ok=True)
    zip_dir = os.path.join(args.out, "_zip")
    os.makedirs(zip_dir, exist_ok=True)

    extracted_total = 0
    failed: list[str] = []

    print()
    for index, (slug, url) in enumerate(archives, 1):
        print(f"[{index}/{len(archives)}] {slug}")
        blob = fetch(url)
        if not blob:
            failed.append(slug)
            continue

        zip_path = os.path.join(zip_dir, f"{slug}.zip")
        with open(zip_path, "wb") as handle:
            handle.write(blob)

        target = os.path.join(args.out, slug)
        os.makedirs(target, exist_ok=True)
        try:
            with zipfile.ZipFile(zip_path) as archive:
                members = [i for i in archive.infolist()
                           if i.filename.lower().endswith((".xlsx", ".xls"))]
                written = 0
                for info in members:
                    name = os.path.basename(decode_member_name(info))
                    # macOS arşiv artıkları gerçek Excel değildir.
                    if not name or name.startswith("._"):
                        continue
                    with archive.open(info) as src:
                        with open(os.path.join(target, name), "wb") as dst:
                            dst.write(src.read())
                    written += 1
                extracted_total += written
                print(f"     {len(blob) // 1024} KB -> {written} plan dosyasi")
        except zipfile.BadZipFile:
            print("     HATA: bozuk zip")
            failed.append(slug)

    print(f"\nToplam {extracted_total} plan dosyasi cikarildi: {args.out}")
    if failed:
        print(f"Alinamayan: {', '.join(failed)}")
    print("\nSonraki adim:")
    print(f"  python scripts/maarif/import_tymm_plans.py --dir \"{args.out}\"")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

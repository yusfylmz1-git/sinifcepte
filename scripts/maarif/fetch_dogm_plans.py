"""
SınıfCepte - MEB DÖGM resmî ÇERÇEVE YILLIK PLAN indirici.

    python scripts/maarif/fetch_dogm_plans.py --year 2026-2027

Din Öğretimi Genel Müdürlüğü (dogm.meb.gov.tr) İmam Hatip ve din dersleri
çerçeve yıllık planlarını yayımlar. TYMM portalında bu dersler YOKTUR:

    Kur'an-ı Kerim · Peygamberimizin Hayatı · Temel Dinî Bilgiler ·
    Arapça · DKAB · AİHL meslek dersleri (fıkıh, hadis, tefsir, kelam,
    siyer, hitabet, İslam kültürü) · Kur'an'ın Anlam Dünyası

Dosyalar doğrudan .xlsx ve TYMM taslak planlarıyla aynı şemaya sahip:
    AY | HAFTA | DERS SAATİ | ÜNİTE | KONU | ANAHTAR KAVRAMLAR |
    ÖĞRENME ÇIKTILARI | SÜREÇ BİLEŞENLERİ | ÖLÇME | SDB | DEĞERLER |
    OKURYAZARLIK | BELİRLİ GÜN VE HAFTALAR | OKUL TEMELLİ PLANLAMA

Bu yüzden indirilen dosyalar import_tymm_plans.py ile okunabilir.
"""

from __future__ import annotations

import argparse
import os
import re
import ssl
import time
import sys
import urllib.error
import urllib.parse
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BASE_URL = "https://dogm.meb.gov.tr"
PLANS_PATH = "/www/cerceve-yillik-planlar/icerik/2257"
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# assets/ Flutter paketine gömülür; ham kaynaklar depo kökünde tutulur.
DEFAULT_OUT = os.path.join(REPO_ROOT, "data_sources", "dogm_plans")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

# Klasör adından okunan insan-okur ders adı.
GROUP_NAMES = {
    "KuraniKerim": "Kur'an-ı Kerim",
    "PeygamberimizinHayati": "Peygamberimizin Hayatı",
    "TemelDiniBilgiler": "Temel Dinî Bilgiler",
    "KuranAnlamDunyasi": "Kur'an'ın Anlam Dünyası",
    "Arapca": "Arapça",
    "DKAB": "Din Kültürü ve Ahlak Bilgisi",
    "AihlMeslek": "AİHL Meslek Dersleri",
}


# Sunucu bir dosyayi bir kosuda verip otekinde reddedebiliyor.
#
# Olcum: script iki kez ust uste calistirildi, ikisinde de 46/52 indi
# ama EKSIKLER FARKLIYDI. Yani dosyalar duruyor, dogm.meb.gov.tr
# baglantiyi rastgele kapatiyor (WinError 10054). Ayni davranis
# ÖSYM'de de gorulmustu.
DENEME = 4


def fetch(url: str, timeout: int = 90) -> bytes | None:
    url = urllib.parse.quote(url, safe=":/?&=%#")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    context = ssl.create_default_context()  # sertifika doğrulaması açık

    for deneme in range(1, DENEME + 1):
        try:
            with urllib.request.urlopen(
                request, context=context, timeout=timeout
            ) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            # 404 gercekten yok demek; yeniden denemek bosuna.
            # 5xx sunucu gecici hatasi olabilir, denenir.
            if error.code < 500:
                print(f"  HTTP {error.code}: {url}")
                return None
            son = f"HTTP {error.code}"
        except urllib.error.URLError as error:
            son = f"Baglanti hatasi: {error.reason}"
        except TimeoutError:
            son = "Zaman asimi"

        if deneme < DENEME:
            # Kisa bir bekleme sunucunun kendine gelmesine yetiyor.
            time.sleep(1.5 * deneme)

    print(f"  {son} ({DENEME} deneme): {url}")
    return None


def discover(html: str, year: str) -> list[tuple[str, str, str]]:
    """(grup, dosya_adi, mutlak_url) listesi döner."""
    hrefs = re.findall(r'href="([^"]+\.xlsx?)"', html, re.IGNORECASE)
    found: list[tuple[str, str, str]] = []
    for href in dict.fromkeys(hrefs):
        filename = href.rsplit("/", 1)[-1]
        # Yalnızca hedef eğitim öğretim yılının planları.
        if year and year not in href:
            continue
        group = "Diger"
        if "/CerceveYillikPlan/" in href:
            tail = href.split("/CerceveYillikPlan/", 1)[1]
            if "/" in tail:
                group = tail.split("/", 1)[0]
        url = href if href.startswith("http") else BASE_URL + href
        found.append((group, filename, url))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="DÖGM çerçeve yıllık plan indirici")
    parser.add_argument("--year", default="2026-2027",
                        help="Hedef eğitim öğretim yılı (dosya adındaki önek)")
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--list", action="store_true", help="İndirme, yalnızca listele")
    args = parser.parse_args()

    print(f"Sayfa aliniyor: {BASE_URL}{PLANS_PATH}")
    page = fetch(BASE_URL + PLANS_PATH, timeout=45)
    if not page:
        print("HATA: Sayfa alinamadi.")
        return 1

    items = discover(page.decode("utf-8", errors="replace"), args.year)
    if not items:
        print(f"HATA: {args.year} icin plan bulunamadi. "
              "Site yapisi degismis veya yil yayimlanmamis olabilir.")
        return 1

    groups: dict[str, int] = {}
    for group, _, _ in items:
        groups[group] = groups.get(group, 0) + 1

    print(f"Bulunan plan dosyasi: {len(items)}  (yil: {args.year})\n")
    for group, count in sorted(groups.items(), key=lambda kv: -kv[1]):
        print(f"  {GROUP_NAMES.get(group, group):<28} {count} dosya")

    if args.list:
        return 0

    os.makedirs(args.out, exist_ok=True)
    written, failed = 0, []

    print()
    for index, (group, filename, url) in enumerate(items, 1):
        target_dir = os.path.join(args.out, group)
        os.makedirs(target_dir, exist_ok=True)
        target = os.path.join(target_dir, filename)
        print(f"[{index}/{len(items)}] {group}/{filename}")

        blob = fetch(url)
        if not blob:
            failed.append(filename)
            continue
        with open(target, "wb") as handle:
            handle.write(blob)
        written += 1

    print(f"\nToplam {written} plan dosyasi indirildi: {args.out}")
    if failed:
        print(f"Alinamayan {len(failed)} dosya: {', '.join(failed[:5])}")
    print("\nSonraki adim:")
    print(f'  python scripts/maarif/import_tymm_plans.py --dir "{args.out}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

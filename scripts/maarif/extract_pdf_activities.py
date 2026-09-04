"""
SınıfCepte - TYMM öğretim programı PDF'lerinden ders yaşantısı çıkarıcı.

    python scripts/maarif/extract_pdf_activities.py

tymm.meb.gov.tr/ogretim-programlari sayfasındaki resmî program PDF'leri
haftalık dağılım İÇERMEZ, ama her kazanım kodu için MEB'in yazdığı
"Öğrenme-Öğretme Uygulamaları" bölümünü içerir:

    BTY.5.1.1. Günlük Yaşamda Kullanılan Bilişim Teknolojilerini
    Sınıflandırabilme — "Öğrencilere 'bilişim teknolojileri' terimi
    hakkında ne düşündükleri sorularak beyin fırtınası yapılır..."

Bu metin, uygulamadaki Maarif ders özetinin yerini alabilecek TEK resmî
kaynaktır: kazanıma özgüdür, MEB yazmıştır ve bizim verimizde zaten
kazanım kodu bulunduğu için kodla eşleştirilebilir.

Çıktı: data_sources/pdf_activities.json
    { "BTY.5.1.1": "Öğrencilere ... yapılır.", ... }

Sonra `build_curriculum.py` bu metni kazanım koduna göre kayda bağlar.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import ssl
import sys
import urllib.parse
import urllib.request

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import pypdf
except ImportError:  # pragma: no cover
    print("HATA: pypdf gerekli.  pip install pypdf")
    raise SystemExit(1)

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES = os.path.join(REPO_ROOT, "data_sources")
CATALOG = os.path.join(SOURCES, "tymm_program_catalog.json")
PDF_DIR = os.path.join(SOURCES, "tymm_pdf")
DEFAULT_OUTPUT = os.path.join(SOURCES, "pdf_activities.json")

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

# Kazanım kodu: 'BTY.5.1.1' / 'MAT.10.2.3'
_CODE = re.compile(r"\b[A-ZÇĞİÖŞÜ]{2,6}\.\d{1,2}\.\d{1,2}\.\d{1,2}\b")

# MEB'in ders anlatımını topladığı bölüm başlığı.
_SECTION = "Öğrenme-Öğretme Uygulamaları"

# En az bu kadar karakter yoksa anlamlı bir anlatım değildir.
MIN_BODY = 220
# Kart için üst sınır.
MAX_BODY = 600


def fetch(url: str, timeout: int = 120) -> bytes | None:
    url = urllib.parse.quote(url, safe=":/?&=%#")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(
                request, context=ssl.create_default_context(), timeout=timeout) as response:
            return response.read()
    except Exception as error:  # ağ hataları tek tek raporlanır
        print(f"     indirilemedi: {type(error).__name__}")
        return None


def read_pdf_text(path: str) -> str:
    """PDF metnini tek satıra indirger ve satır sonu tirelemesini onarır."""
    try:
        reader = pypdf.PdfReader(path)
    except Exception as error:
        print(f"     okunamadi: {type(error).__name__}")
        return ""

    raw = "\n".join((page.extract_text() or "") for page in reader.pages)
    # PDF dizgisi kelimeleri satır sonunda bölüyor ve tirenin iki yanına
    # boşluk koyabiliyor: 'sınıflandır- ma', 'tar - tışma', 'ko -\nlaylaştıran'.
    # Önce tüm boşlukları tekleştirip sonra tireyi kapatıyoruz.
    raw = re.sub(r"\s+", " ", raw)
    raw = re.sub(r"(\w)\s*-\s+(?=[a-zçğıöşü])", r"\1", raw)
    return raw.strip()


def clean_body(text: str) -> str:
    """Anlatımı kart için sadeleştirir."""
    # Baştaki kod ve büyük harfli başlık tekrarını at.
    text = _CODE.sub("", text, count=1).lstrip(" .")
    # Süreç bileşeni listesiyle başlıyorsa (a) b) c)) bu anlatım değildir.
    text = text.strip()

    if len(text) > MAX_BODY:
        window = text[:MAX_BODY]
        cut = window.rfind(". ")
        text = (window[:cut + 1] if cut > MAX_BODY * 0.5 else window.rstrip()) + " …"
    return text.strip()


def extract_activities(text: str) -> dict[str, str]:
    """PDF metninden kazanım kodu -> ders yaşantısı sözlüğü çıkarır."""
    found: dict[str, str] = {}

    for marker in re.finditer(re.escape(_SECTION), text):
        tail = text[marker.end():marker.end() + 12000]
        hits = [(m.start(), m.group()) for m in _CODE.finditer(tail)]
        for index, (position, code) in enumerate(hits):
            end = hits[index + 1][0] if index + 1 < len(hits) else min(len(tail), position + 2500)
            body = clean_body(tail[position:end])

            # Yalnızca süreç bileşeni listesi olan bloklar elenir: gerçek
            # anlatım "...yapılır/istenir/sağlanır" gibi ders akışı içerir.
            if len(body) < MIN_BODY:
                continue
            letters = len(re.findall(r"\b[a-zçğıöşü]\)", body))
            if letters >= 3 and not re.search(r"yapılır|istenir|sağlanır|sunulur|verilir", body):
                continue

            # Aynı kod birden çok yerde geçerse en uzun anlatımı tut.
            if code not in found or len(body) > len(found[code]):
                found[code] = body

    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="TYMM PDF ders yaşantısı çıkarıcı")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int, default=0, help="Yalnızca ilk N ders")
    parser.add_argument("--keep-pdf", action="store_true",
                        help="İndirilen PDF'leri sakla (yeniden indirmemek için)")
    args = parser.parse_args()

    if not os.path.exists(CATALOG):
        print(f"HATA: Katalog yok: {CATALOG}")
        print("Once calistirin: python scripts/maarif/fetch_tymm_catalog.py")
        return 1

    with open(CATALOG, encoding="utf-8") as handle:
        lessons = json.load(handle).get("lessons", [])

    lessons = [l for l in lessons if l.get("programPdfs")]
    if args.limit:
        lessons = lessons[:args.limit]

    print(f"PDF'i olan ders: {len(lessons)}\n")
    os.makedirs(PDF_DIR, exist_ok=True)

    activities: dict[str, str] = {}
    failed: list[str] = []

    for index, lesson in enumerate(lessons, 1):
        url = lesson["programPdfs"][0]
        name = os.path.basename(urllib.parse.urlparse(url).path)
        path = os.path.join(PDF_DIR, name)
        print(f"[{index}/{len(lessons)}] {lesson['title'][:52]}")

        if not os.path.exists(path):
            blob = fetch(url)
            if not blob:
                failed.append(lesson["title"])
                continue
            with open(path, "wb") as handle:
                handle.write(blob)

        text = read_pdf_text(path)
        if not text:
            failed.append(lesson["title"])
            continue

        found = extract_activities(text)
        for code, body in found.items():
            if code not in activities or len(body) > len(activities[code]):
                activities[code] = body
        print(f"     {len(found)} kazanim anlatimi")

        if not args.keep_pdf:
            try:
                os.remove(path)
            except OSError:
                pass

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as handle:
        json.dump(activities, handle, ensure_ascii=False, indent=2)

    print(f"\nToplam {len(activities)} kazanim anlatimi cikarildi.")
    print(f"Yazildi: {args.output}")
    if failed:
        print(f"Alinamayan {len(failed)} ders: {', '.join(failed[:4])}")
    print("\nSonraki adim: build_curriculum.py bunu kazanim koduna gore baglar.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

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
    """
    SınıfCepte - MEB Maarif Modeli Resmî Web Crawler (tymm.meb.gov.tr)
    Bu script, tymm.meb.gov.tr portalındaki resmî ders, ünite ve öğrenme çıktılarını otomatik olarak çeker.
    """

    import os
    import sys
    import json
    import urllib.request
    import ssl
    import re

    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    BASE_URL = "https://tymm.meb.gov.tr"
    OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    def fetch_url(url):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/html, */*',
                'X-Requested-With': 'XMLHttpRequest'
            }
        )
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
                data = resp.read()
                return data.decode('utf-8')
        except Exception as e:
            print(f"Hata ({url}): {e}")
            return None

    def main():
        print("🚀 tymm.meb.gov.tr Web Crawler Başlatılıyor...")

        # Ana program sayfasını al
        html = fetch_url(f"{BASE_URL}/ogretim-programlari/")
        if not html:
            print("❌ Ana sayfa çekilemedi!")
            return

        # Ders linklerini ayıkla
        lesson_links = set(re.findall(r'href=["\'](/ogretim-programlari/ders/[^"\']+)["\']', html))
        print(f"✅ Bulunan Maarif Ders Sayfası Sayısı: {len(lesson_links)}")

        all_programs = []
        for link in lesson_links:
            full_url = f"{BASE_URL}{link}"
            slug = link.split('/')[-1]
            print(f"  📖 Çekiliyor: {slug}...")

            page_html = fetch_url(full_url)
            if not page_html:
                continue

            title_match = re.search(r'<h1[^>]*>(.*?)</h1>', page_html, re.I | re.S)
            title = re.sub(r'<[^>]+>', '', title_match.group(1)).strip() if title_match else slug

            all_programs.append({
                "slug": slug,
                "title": title,
                "url": full_url
            })

        output_path = os.path.join(OUTPUT_DIR, "tymm_raw_programs.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(all_programs, f, ensure_ascii=False, indent=2)

        print(f"\n🎉 tymm.meb.gov.tr taraması tamamlandı! {len(all_programs)} ders listesi '{output_path}' dosyasına kaydedildi.")

    if __name__ == "__main__":
        main()

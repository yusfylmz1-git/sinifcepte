"""SınıfCepte - Yıllık müfredat güncellemesi: TEK KOMUT.

    python scripts/maarif/yillik_guncelle.py --year 2027-2028

MEB'in iki sitesinden planları indirir, işler, birleştirir ve yayın
paketini üretir. Her adımı ayrı ayrı çalıştırmak da mümkün (bkz.
README) ama yılda bir yapılan bir iş için sıra hatırlamak gereksiz.

## Ne zaman çalıştırılır

MEB çalışma takvimini ve taslak yıllık planları genellikle **ağustos
sonunda** yayımlıyor. Ölçüm: 2026-2027 planları 31 Ağustos – 3 Eylül
tarihlerinde yüklenmiş.

## Önce yapılması gereken

`overrides/<yıl>.json` dosyası hazır olmalı: ara tatil haftaları bir
kuraldan türetilemez, MEB tebliğinden elle girilir. Yoksa bu betik
uyarır ve durur.

## Sonrasında

Paket APK ile dağıtılır — bu bilinçli bir karar. Müfredat yılda bir
değişiyor; 30.000 öğretmene bulut üzerinden dağıtmak ölçüldüğünde
yılda ~$11-23 tutuyor ve mağaza güncellemesi bunu sıfıra indiriyor.
Uygulama, varlık parmak izi değiştiği için yeni paketi kendiliğinden
yeniden tohumluyor.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BURASI = os.path.dirname(os.path.abspath(__file__))
KOK = os.path.abspath(os.path.join(BURASI, "..", ".."))


def calistir(baslik: str, betik: str, *args: str) -> bool:
    """Bir adımı çalıştırır; başarısızsa False döner."""
    print()
    print("=" * 66)
    print(f"  {baslik}")
    print("=" * 66)
    sonuc = subprocess.run(
        [sys.executable, os.path.join(BURASI, betik), *args],
        cwd=KOK,
    )
    if sonuc.returncode != 0:
        print(f"\nHATA: {betik} basarisiz (cikis {sonuc.returncode}).")
        return False
    return True


def main() -> int:
    ayristirici = argparse.ArgumentParser(
        description="Yillik mufredat guncellemesi"
    )
    ayristirici.add_argument("--year", default="2026-2027")
    ayristirici.add_argument(
        "--indirme-yok",
        action="store_true",
        help="Indirmeyi atla; elde duran dosyalarla yeniden uret",
    )
    args = ayristirici.parse_args()

    # Takvim dosyası olmadan devam etmek anlamsız: ara tatil haftaları
    # yanlış olursa bütün hafta numaraları kayar.
    takvim = os.path.join(BURASI, "overrides", f"{args.year}.json")
    if not os.path.exists(takvim):
        print(f"HATA: Takvim dosyasi yok: {takvim}")
        print()
        print("MEB calisma takvimi tebligle duyurulur ve ara tatil")
        print("haftalari bir kuraldan turetilemez. Once bir onceki yilin")
        print("dosyasini kopyalayip guncelleyin:")
        onceki = os.path.join(BURASI, "overrides")
        print(f"  {onceki}")
        return 1

    if not args.indirme_yok:
        # MEB'in İKİ sitesi: TYMM genel dersleri, DÖGM imam hatip ve
        # din derslerini yayımlıyor. İkisi de resmî, biri ötekini
        # kapsamıyor.
        if not calistir("1/5  TYMM planlari indiriliyor", "fetch_tymm_plans.py"):
            return 1
        if not calistir("2/5  DOGM planlari indiriliyor", "fetch_dogm_plans.py"):
            return 1

    if not calistir(
        "3/5  TYMM planlari isleniyor",
        "import_tymm_plans.py",
        "--year", args.year,
    ):
        return 1

    if not calistir(
        "3/5  DOGM planlari isleniyor",
        "import_tymm_plans.py",
        "--dir", os.path.join(KOK, "data_sources", "dogm_plans"),
        "--output", os.path.join(KOK, "data_sources", "dogm_plan_raw.json"),
        "--year", args.year,
    ):
        return 1

    if not calistir("4/5  Kaynaklar birlestiriliyor", "merge_sources.py"):
        return 1

    if not calistir(
        "5/5  Yayin paketi uretiliyor",
        "build_curriculum.py",
        "--source", os.path.join(KOK, "data_sources", "merged_raw.json"),
        "--year", args.year,
    ):
        return 1

    print()
    print("=" * 66)
    print("  TAMAM")
    print("=" * 66)
    print()
    print("Sonraki adimlar:")
    print("  1. Testler       : python scripts/maarif/test_pipeline.py")
    print("  2. Sikistirma    : dart run tool/compress_assets.dart")
    print("  3. Uygulama testi: flutter test")
    print("  4. Yayin         : flutter build apk --release")
    print()
    print("Paket APK ile dagitilir; uygulama varlik parmak izi")
    print("degistigi icin mufredati kendiliginden yeniden tohumlar.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

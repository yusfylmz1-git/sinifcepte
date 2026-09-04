#!/usr/bin/env bash
# Cihazdaki tanı kaydını okur.
#
# "Belge Hazırlanıyor" takılması yalnızca KABLO ÇIKINCA görülüyor;
# debugPrint o koşulda okunamıyor. Uygulama bu yüzden kaydı cihazdaki
# bir dosyaya yazıyor (lib/core/support/tani_log.dart).
#
# Kullanım:
#   1. Kabloyu çıkar, sorunu yeniden üret
#   2. Kabloyu tak
#   3. bash tool/tani_log_oku.sh
#
# Kaydı temizlemek için:  bash tool/tani_log_oku.sh --temizle

set -u

ADB="${ADB:-/c/Users/Okul/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
PAKET="com.sinifcepte.sinifcepte"
YOL="/data/data/$PAKET/app_flutter/tani.log"

if [ ! -x "$ADB" ]; then
  echo "adb bulunamadı: $ADB" >&2
  echo "ADB=/yol/adb.exe bash $0  şeklinde çalıştırın." >&2
  exit 1
fi

CIHAZ=$(MSYS_NO_PATHCONV=1 "$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')
if [ -z "$CIHAZ" ]; then
  echo "Bağlı cihaz yok. Kabloyu takın." >&2
  exit 1
fi

if [ "${1:-}" = "--temizle" ]; then
  MSYS_NO_PATHCONV=1 "$ADB" -s "$CIHAZ" shell "run-as $PAKET sh -c 'echo -n > $YOL'" 2>/dev/null
  echo "Kayıt temizlendi. Şimdi kabloyu çıkarıp sorunu yeniden üretin."
  exit 0
fi

echo "=============================================================="
echo " TANI KAYDI  ($CIHAZ)"
echo "=============================================================="

# run-as yalnızca debuggable APK'da çalışır. Release için uygulamanın
# kendi ekranından okumak gerekir.
CIKTI=$(MSYS_NO_PATHCONV=1 "$ADB" -s "$CIHAZ" shell "run-as $PAKET cat $YOL" 2>&1)

if echo "$CIKTI" | grep -qi "not debuggable\|unknown package\|Permission denied"; then
  echo "Kayıt okunamadı: uygulama release derlemesi olabilir."
  echo "(run-as yalnızca debuggable APK'da çalışır.)"
  echo
  echo "Debug sürüm kurmak için:"
  echo "  flutter run -d $CIHAZ --debug"
  exit 1
fi

if [ -z "$CIKTI" ]; then
  echo "(kayıt boş — uygulama henüz bir şey yazmamış)"
  exit 0
fi

echo "$CIKTI"
echo
echo "--------------------------------------------------------------"
echo "Özet:"
echo "  DONMA satırı   : $(echo "$CIKTI" | grep -c 'DONMA')"
echo "  YAVAŞ KARE     : $(echo "$CIKTI" | grep -c 'YAVAŞ KARE')"
echo "  PDF üretimi    : $(echo "$CIKTI" | grep -c 'PDF ▶')"
echo "  PDF bitti      : $(echo "$CIKTI" | grep -c 'PDF ✔')"
echo "  PDF hata       : $(echo "$CIKTI" | grep -c 'PDF ✖')"

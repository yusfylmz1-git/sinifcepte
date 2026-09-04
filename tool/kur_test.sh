#!/usr/bin/env bash
# Uygulamayı cihaza kurar — PDF testi yapılabilen biçimde.
#
# ## Neden bu betik var
#
# `flutter run` (F5) ile çalışırken PDF'ler AÇILMIYOR. Sebep ölçüldü:
#
#   `pdf` paketi 3.12.0'dan beri belgeyi ayrı izolatta kaydediyor
#   (`Isolate.run`). Dart VM servisi BAĞLIYKEN yeni izolat duraklatılmış
#   başlıyor ve devam ettirilmeyi bekliyor. Kablo takılıyken `flutter run`
#   bunu yapıyor; kablo çekilince yapan kimse kalmıyor ve izolat sonsuza
#   kadar duraklamış kalıyor. `save()` de onu beklediği için ekran
#   "Belge Hazırlanıyor"da donuyor.
#
# Ölçüm sonucu:
#
#   Release            -> PDF çalışıyor  (VM servisi yok)
#   Debug + adb install-> PDF çalışıyor  (VM servisi var, BAĞLI DEĞİL)
#   flutter run / F5   -> PDF TAKILIYOR  (VM servisi var ve BAĞLI)
#
# Bu betik ikinci yolu kullanır: debug derlemenin tüm kolaylıkları
# (loglar, assert'ler) durur ama PDF de çalışır.
#
# Kullanım:
#   bash tool/kur_test.sh            # debug (hızlı, loglar açık)
#   bash tool/kur_test.sh --release  # gerçek kullanıcı koşulu

set -eu

ADB="${ADB:-/c/Users/Okul/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
PAKET="com.sinifcepte.sinifcepte"

TUR="debug"
if [ "${1:-}" = "--release" ]; then
  TUR="release"
fi

if [ ! -x "$ADB" ]; then
  echo "adb bulunamadı: $ADB" >&2
  exit 1
fi

CIHAZ=$(MSYS_NO_PATHCONV=1 "$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')
if [ -z "$CIHAZ" ]; then
  echo "Bağlı cihaz yok. Kabloyu takın." >&2
  exit 1
fi

echo "=============================================================="
echo " $TUR derleniyor — cihaz: $CIHAZ"
echo "=============================================================="

flutter build apk --"$TUR"

APK="build/app/outputs/flutter-apk/app-$TUR.apk"
if [ ! -f "$APK" ]; then
  echo "APK bulunamadı: $APK" >&2
  exit 1
fi

echo
echo "Kuruluyor..."
# -r: veriyi koru. Temiz kurulum isteniyorsa önce elle kaldırın.
MSYS_NO_PATHCONV=1 "$ADB" -s "$CIHAZ" install -r "$APK"

echo
echo "Kuruldu. PDF testi için kabloyu çıkarabilirsiniz."
echo "NOT: 'flutter run' (F5) ile başlatırsanız PDF'ler yine takılır."

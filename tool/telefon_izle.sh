#!/usr/bin/env bash
# Telefon testinde hata izleyici.
#
# ## Neden bu betik var
#
# Telefonda bir şey ters gidince elimizde yalnız "olmadı" kalıyordu:
# Crashlytics panosu saatlerce gecikiyor, yakalanmış hatalar (SnackBar'a
# düşen, sessizce yutulan) oraya hiç gitmiyor. Uygulama ise her hatayı
# telefonun günlüğüne (logcat) yazıyor:
#
#   * `CrashReporter` → "ÇÖKME KAYDI [...]" + "ÇÖKME YIĞINI" (ilk 8 satır)
#   * depo/sağlayıcı catch blokları → "HATA DETAYI (...)"
#   * Android → "FATAL EXCEPTION", "ANR in", "has died"
#
# Bu betik o akıştan yalnız SınıfCepte'yi süzüp zaman damgasıyla dosyaya
# yazar. Testçi "KZN-5 olmadı" dediğinde o dakikanın kaydı elde olur.
# Kablo çıkıp takılırsa kendiliğinden yeniden bağlanır.
#
# Kullanım:
#   bash tool/telefon_izle.sh [kayit.log]          # izle (Ctrl+C durdurur)
#   bash tool/telefon_izle.sh --ozet [kayit.log]   # kayıttaki hatalar
#   bash tool/telefon_izle.sh --suz < ham.txt      # süzgeci dene (test)

set -u

ADB="${ADB:-/c/Users/Okul/AppData/Local/Android/sdk/platform-tools/adb.exe}"
PAKET="com.sinifcepte.sinifcepte"
VARSAYILAN="${TEMP:-/tmp}/sinifcepte_izleme.log"

# Uygulamanın kendi çıktısı (flutter etiketi) her zaman alınır; Android
# satırlarından yalnız bu pakete ait çökme/donma/süreç olayları.
suz() {
  grep --line-buffered -E \
    "[IWEF]/flutter|AndroidRuntime|FATAL EXCEPTION|ANR in $PAKET|$PAKET.*(died|crash|Crash|ANR|Force finishing)|Start proc [0-9]+:$PAKET|Fatal signal|DEBUG +:.*$PAKET"
}

# Hata sayılan satırlar (özet için). ASCII seçenekleri: Windows konsolu
# Türkçe harfi bozarsa da yakalansın.
HATA_DESENI="ÇÖKME|KAYDI|YIĞINI|YIGINI|HATA DETAYI|Hata Mesajı|Exception|Error:|Bad state|Null check|RangeError|setState\(\) called|after dispose|FATAL|ANR in|has died|Fatal signal|Unhandled|overflowed"

case "${1:-}" in
  --suz)
    suz
    exit 0
    ;;
  --ozet)
    KAYIT="${2:-$VARSAYILAN}"
    if [ ! -f "$KAYIT" ]; then
      echo "Kayıt yok: $KAYIT"
      exit 1
    fi
    echo "== $KAYIT ($(wc -l < "$KAYIT") satır)"
    echo "== Uygulama başlangıçları:"
    grep -E "Start proc [0-9]+:$PAKET" "$KAYIT" | tail -5
    echo "== Hatalar (son 60):"
    grep -E -A8 "$HATA_DESENI" "$KAYIT" | grep -v "^--$" | tail -60
    exit 0
    ;;
esac

KAYIT="${1:-$VARSAYILAN}"
echo "Kayıt: $KAYIT"
echo "Durdurmak için Ctrl+C."

while true; do
  "$ADB" wait-for-device
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') telefon bağlandı" | tee -a "$KAYIT"
  # -T 1: eski tamponu dökme, şimdiden başla. -v time: telefon saati.
  "$ADB" logcat -v time -T 1 2>/dev/null | suz >> "$KAYIT"
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') bağlantı koptu, bekleniyor" | tee -a "$KAYIT"
  sleep 2
done

# QR ile Kilit Açma — Plan

**Durum:** taslak, onay bekliyor
**Tarih:** 18 Eylül 2026

---

## İstek

Kullanıcı: *"Eğer tahtada internet varsa — ki çoğunda var, FATİH
altyapısı ile — QR ile okuma olmalı. Kimse kodla uğraşmaz."*

Haklı bir tespit: öğretmen her derste 6 hane yazmak istemiyor.

---

## Şu an neden çalışmıyor

Bilgi tek yönlü akıyor:

```
Tahta QR gösterir  ──→  Telefon okur ✓
Telefon "aç" der   ──✗  Tahtaya ulaşamıyor
```

Telefon QR'ı okuyunca *"bu meb_775214 okulunun 8/B tahtası"*
öğreniyor, ama o bilgi telefonda kalıyor. Tahtaya komut göndermek
için kanal gerekiyor ve tahtada hiçbiri yok:

| Kanal | Durum |
|---|---|
| Ağ | Tahta ağa çıkmıyor — **temel mimari karar** |
| Tahtada kamera | Yok |
| Bluetooth | Her tahta için eşleştirme gerekir |
| İnsan eli (6 hane) | ✓ şu anki yol |

---

## Üç seçenek

### A — Bulut üzerinden (tahtaya internet)

```
Telefon QR okur → buluta "8/B tahtasını aç" yazar
Tahta buluta bakar → emri görür → açılır
```

**Kazanç:** öğretmen hiç kod yazmıyor.

**Bedeli:**

| Kayıp | Ayrıntı |
|---|---|
| KVKK argümanı | "Tahta ağa çıkmaz, veri cihazda kalır" gerekçesi düşer. Hafızadaki "Seçenek A" kararıyla çelişir. |
| Çevrimdışı çalışma | İnternet kesilince tahta **hiç açılmaz**. Şu an kesilse çalışıyor. |
| Firestore maliyeti | Tahta emri görmek için yoklama yapmak zorunda. 20 tahta × 5 sn = günde ~350.000 okuma. Ücretsiz katman 50.000/gün. **Aşıyor.** |
| Gecikme | Yoklama aralığı kadar bekleme (5 sn) veya listener (maliyet daha yüksek). |

**Maliyeti düşürmenin yolu:** yoklama yerine FCM push. Ama FCM
Linux'ta desteklenmiyor — tahta Python/GTK çalıştırıyor, Flutter
değil. Ham HTTP ile FCM dinlemek mümkün değil (push, istemci SDK'sı
gerektiriyor).

**Ölçülmemiş risk:** FATİH ağı tahtanın Firestore'a erişmesine izin
veriyor mu? Filtre ve proxy var. Hiç denenmedi.

### B — Yerel ağ (bulut yok)

```
Telefon ──(okul wifi)──▸ Tahta
         doğrudan, bulut yok
```

Tahta yerel bir HTTP sunucusu açıyor; telefon QR'dan tahtanın IP'sini
okuyup doğrudan istek gönderiyor.

**Kazanç:** KVKK argümanı korunuyor (veri okuldan çıkmıyor), maliyet
sıfır, gecikme yok.

**Ölçülmemiş risk — kritik:** FATİH ağında **AP izolasyonu** yaygın.
Açıksa telefon ile tahta birbirini görmez ve bu yol hiç çalışmaz.
Bu ölçülmeden yazılan kod boşa gider.

**İkinci risk:** tahta yerel sunucu açınca aynı ağdaki herkes ona
istek gönderebilir. İmzalı istek şart (telefon TOTP'yi imzalar),
yoksa öğrenci kendi telefonundan açar.

### C — Şimdiki yolu iyileştir (kod kalır)

Öğretmen kodu kaldırıldı (bugün yapıldı) ve ekran klavyesi eklendi.
Kalan sürtünme: 6 haneyi okuyup yazmak.

**İyileştirme:** telefon kodu **panoya kopyalıyor** ve tahtada
"yapıştır" düğmesi oluyor. Ama pano telefondan tahtaya geçmiyor —
iki ayrı cihaz. Bu yol kapalı.

Gerçekçi iyileştirme: kodu **daha büyük** göstermek ve tahtada
otomatik denemek (bugün eklendi: 6 hane dolunca kendiliğinden
deniyor).

---

## Önerim: B, ama önce ÖLÇÜM

A seçeneği maliyet ve KVKK açısından pahalı; B ucuz ve kararları
korur. Ama ikisi de **ölçülmemiş bir varsayıma** dayanıyor.

### Ölçüm 1 — AP izolasyonu (bloke edici)

Okulda, FATİH ağına bağlı bir telefon ve tahtayla:

```bash
# Tahtada (Pardus):
ip addr show | grep "inet "        # tahtanın IP'si
python3 -m http.server 8080

# Telefonda tarayıcı:
http://<tahta-ip>:8080
```

**Liste görünürse** AP izolasyonu kapalı → B seçeneği mümkün.
**Görünmezse** B imkânsız, A'yı veya C'yi konuşuruz.

### Ölçüm 2 — Tahta buluta çıkabiliyor mu (A için)

```bash
# Tahtada:
curl -s -o /dev/null -w "%{http_code}" https://firestore.googleapis.com
```

`200` veya `404` → erişim var. Zaman aşımı → FATİH filtresi engelliyor.

---

## B seçeneği tasarımı (ölçüm geçerse)

### QR yükü değişimi

Şu an: `SC1:{okulId}:{tahtaId}:{nonce}:{pencere}`
Yeni: `SC2:{okulId}:{tahtaId}:{nonce}:{pencere}:{ip}:{port}`

`SC1` desteklenmeye devam ediyor — eski tahtalar bozulmuyor.

### Akış

```
1. Tahta yerel sunucu açar (127.0.0.1 değil, LAN IP)
2. QR'a kendi IP'sini yazar
3. Telefon QR'ı okur, IP'yi alır
4. Telefon POST /ac gönderir:
     { "kod": "<6 hane>", "imza": "<HMAC>" }
5. Tahta TOTP'yi doğrular → açılır
```

### Güvenlik: neden yalnızca TOTP yetmez

Aynı ağdaki biri `POST /ac` deneyebilir. Ama gönderdiği kodu
bilmiyor — TOTP secret'ı yalnızca öğretmenin telefonunda. Yani
mevcut doğrulama zaten koruyor; ek imza **gerekmiyor**.

Kaba kuvvete karşı `DenemeHizi` sayacı zaten var (5 hatalı deneme →
bekleme).

### Tahtanın yalnızca kendi ağını dinlemesi

Sunucu `0.0.0.0` yerine yalnızca yerel arayüze bağlanmalı ve
`/ac` dışında hiçbir yol sunmamalı. Tahtada HTTP sunucusu açmak yeni
bir yüzey; küçük tutulması şart.

---

## Aşamalar (ölçüm sonrası)

1. **Ölçüm** — AP izolasyonu (yukarıda). Sizin okulunuzda, gerçek
   FATİH ağında. **Bloke edici.**
2. Tahta tarafı: yerel sunucu + `/ac` uç noktası + IP'yi QR'a yazma
3. Telefon tarafı: `SC2` ayrıştırma + POST gönderme + hata yolları
4. Geri düşüş: ağ yoksa 6 hane ekranı görünmeye devam ediyor
5. Gerçek tahtada uçtan uca deneme

---

## Geri düşüş şart

Ağ çalışmadığında **6 hane yolu kalmalı**. Sebepler:

- Öğretmenin telefonunda Wi-Fi kapalı olabilir
- Misafir ağı ile tahta ağı ayrı olabilir
- AP izolasyonu bazı okullarda açık, bazılarında kapalı

Yani QR ile açma bir **kolaylık katmanı**, tek yol değil. Bu, kilidin
kendisinin de "caydırıcı katman" olarak konumlandırılmasıyla
tutarlı.

---

## Açık soru

**Tahta kimliği nasıl belirlenecek?** Şu an `postinst` tek soru
soruyor ("hangi sınıf/şube"). Yerel ağda birden fazla tahta varsa
telefon doğru tahtaya istek göndermek zorunda — QR'daki IP bunu
çözüyor, ama tahta IP'si DHCP ile değişirse QR bayatlar.

Çözüm adayı: QR her 30 saniyede yenilendiği için IP de yenilenir.
Ölçüm sonrası netleşir.

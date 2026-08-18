# 💰 Maliyet Koruması ve Bütçe Alarmı

Bu belge, faturanın kontrolden çıkmasını engelleyen **iki katmanı** anlatır.

> ⚠️ **En önemli gerçek:** Blaze (kullandıkça öde) planında Firebase
> **varsayılan harcama tavanı koymaz.** Kota aşımı sizi durdurmaz, sadece
> faturalandırır. Aşağıdaki adımlar isteğe bağlı değildir.

---

## Katman 1 — İstemci freni (kodda, hazır)

`FirestoreBudgetGuard` her cihazın günlük işlem sayısını sayar ve sınırı
aşarsa **yazmayı durdurur**.

| Ayar | Değer | Gerekçe |
| :--- | :--- | :--- |
| Günlük yazma tavanı | **500** | Gerçekçi kullanımın ~50 katı |
| Günlük okuma uyarısı | **2.000** | Engellemez, yalnızca loglar |

**Neden yalnızca yazma engelleniyor:** Okuma engellenirse uygulama
kullanılamaz hale gelir ve kullanıcı sebebini anlamaz. Yazma ise üç kat
pahalıdır ve kaçakların çoğu yazma döngüsüdür.

**Bu fren neyi yakalar:** Döngüye giren yenileme, unutulmuş dinleyici,
hatalı yeniden deneme — yani faturayı patlatan tipik kod hataları.

**Neyi yakalamaz:** Gerçek kullanıcı büyümesini. Onun için Katman 2 şart.

---

## Katman 2 — Sunucu bütçe alarmı (sizin yapmanız gereken)

### 1. Bütçe ve uyarı kurma

1. [Google Cloud Console → Billing → Budgets & alerts](https://console.cloud.google.com/billing/budgets)
2. **Create Budget**
3. Proje: `sinifcepte`
4. Tutar: başlangıç için **$25/ay** önerilir
5. Uyarı eşikleri: **%50, %90, %100**
6. E-posta bildirimini işaretleyin

Bu adım **para harcamayı durdurmaz**, yalnızca haber verir. Durdurmak için:

### 2. Kota aşımında faturalandırmayı kesme (isteğe bağlı, sert önlem)

Gerçekten sert bir tavan istiyorsanız, bütçe alarmını bir Pub/Sub
konusuna bağlayıp faturalandırmayı devre dışı bırakan bir Cloud Function
yazılır. **Uyarı:** bu, uygulamayı tamamen durdurur — veriler silinmez ama
kimse erişemez. Erken aşamada alarm yeterlidir; bu adımı ancak gerçek
kullanıcı hacmine ulaşınca değerlendirin.

### 3. App Check (kötüye kullanım koruması)

Faturayı patlatan bir diğer yol, birinin API anahtarınızla doğrudan
Firestore'a istek yağdırmasıdır. [App Check](https://firebase.google.com/docs/app-check)
yalnızca gerçek uygulamanızdan gelen istekleri kabul eder.

Kurulum sırası: önce **monitoring** modunda açın, trafiğin tamamı geçerli
görünüyorsa **enforcement**'a alın.

---

## Beklenen maliyet (maliyet planından)

| Ölçek | Aylık Firestore | Not |
| :--- | :--- | :--- |
| İlk 1.000 kullanıcı | **$0** | Spark ücretsiz katmanı |
| ~190 okul | **$0** | Optimizasyonlarla ücretsiz sınırda |
| 10M kullanıcı | **~$260** | Yedi optimizasyon uygulanmış hâliyle |
| 10M (optimizasyonsuz) | ~$2.400 | Karşılaştırma için |

Reklam geliri temkinli tahminle ~$3.500/ay; altyapı bunun **%7'si**.

---

## Uygulanan yedi optimizasyon

Bunlar şema kararlarıdır, sonradan eklenemezler:

| # | Karar | Durum |
| :-- | :--- | :--- |
| 1 | Okundu bilgisi alt dokümanda (`reads/{uid}`) | ✅ Faz 3 |
| 2 | Delta sorgu (`where updatedAt >`) | ✅ Faz 3 |
| 3 | Manifest Remote Config'de (Firestore değil) | ✅ Faz 5 |
| 4 | Snapshot listener yasağı | ✅ Faz 2 |
| 5 | Son 20 duyuruyu sınıf dokümanında toplama | ⏸️ Ertelendi |
| 6 | Token bağlantı sonrası silinir | ✅ Faz 2 |
| 7 | Toplu yazma (`WriteBatch`) | ✅ Faz 2 |

**#5 neden ertelendi:** Delta senkron zaten okumaların %90'ını sıfırlıyor.
Bu ek optimizasyon gerçek kullanım verisi görülmeden yapılırsa şemayı
gereksiz karmaşıklaştırır.

---

## Fatura beklenmedik şekilde artarsa

1. **Firebase Console → Firestore → Usage** sekmesinden hangi işlemin
   arttığına bakın (okuma mı, yazma mı).
2. Yazma arttıysa: son eklenen bir döngü veya yeniden deneme var mı?
3. Okuma arttıysa: bir yere snapshot listener eklendi mi? (`FirestoreClient`
   bunu yasaklar, ama doğrudan `db` kullanan yeni kod atlayabilir.)
4. `FirestoreBudgetGuard.summary` cihaz başına sayıyı gösterir; hata
   ayıklama sırasında konsola basılır.

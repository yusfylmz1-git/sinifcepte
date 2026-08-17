# 🔒 Firestore Güvenlik Kuralı Testleri

`firestore.rules` dosyasının **gerçekten koruduğunu** doğrulayan emülatör tabanlı testler.

Uygulama kodu doğru davransa bile kural yanlışsa veri sızar. Bu testler doğrudan kural motoruna karşı yazılmıştır: "veli başka bir velinin çocuğunu okuyabiliyor mu?", "öğretmen kendini yönetici ilan edebiliyor mu?" gibi soruları uygulama katmanını atlayarak sorar.

---

## ⚠️ Gereksinim: JDK 21 veya üzeri

`firebase-tools` 15.x, emülatör için **Java 21+** şartı koyuyor. Bu makinede şu an yalnızca **Java 8** kurulu olduğu için testler henüz çalıştırılamadı.

```
Error: firebase-tools no longer supports Java version before 21.
```

### Kurulum

En kolay yol — [Eclipse Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21) (ücretsiz, LTS):

1. Windows x64 `.msi` paketini indirip kurun.
2. Kurulumda **"Set JAVA_HOME variable"** seçeneğini işaretleyin.
3. Terminali yeniden açıp doğrulayın:

```bash
java -version   # 21.x görmelisiniz
```

> Not: Android Studio'nun `jbr` klasörü bu makinede eksik kurulmuş (`lib/jvm.cfg` yok), o yüzden kullanılamıyor.

---

## 🚀 Çalıştırma

```bash
cd test_rules
npm install     # bir kez
npm test
```

Komut Firestore emülatörünü ayağa kaldırır, testleri çalıştırır ve emülatörü kapatır. Gerçek `sinifcepte` projesine **hiç dokunmaz** — `sinifcepte-test` sahte proje kimliği kullanılır.

---

## 📋 Kapsam (34 test)

| Grup | Ne doğrulanıyor |
| :--- | :--- |
| **1. parent_tokens** | Kod okuma oturum ister; başka öğretmen kod yazamaz; veli kodu değiştiremez |
| **2. parent_links** | **Veli izolasyonu**: veli başka velinin çocuğunu okuyamaz, başkası adına bağ kuramaz |
| **3. class_rooms** | Sahiplik: yalnızca sınıf öğretmeni yazar; erişimsiz veli okuyamaz |
| **4. school_admin_requests** | **Yetki yükseltme koruması**: öğretmen kendini onaylayamaz |
| **5. content_reports** | Veli başkası adına şikâyet edemez; şikâyetleri okuyamaz; silemez |
| **6. sync/manifest** | Herkes okur, **hiçbir istemci yazamaz** (süper admin dahil) |
| **7. Kimlik şeması** | Sahiplik kimlik deseninden okunur — doküman okuması gerektirmez |

`KRİTİK:` ile başlayan testler doğrudan veri sızıntısı senaryolarıdır.

---

## 🧭 Neden bu testler önemli

Firestore kurallarının iki sinsi özelliği var:

1. **Sessizce başarısız olurlar.** Yanlış kural hata vermez; sadece veriyi açar veya kapatır. Fark edilmesi aylar sürebilir.
2. **Uygulama testleri bunları yakalamaz.** Dart tarafındaki 63 test kural motoruna hiç uğramaz.

Ayrıca bu kurallar **maliyet** kararıdır: `ownsClassRoom` ve `ownsStudent` fonksiyonları sahipliği doküman okumadan, yalnızca kimlik deseninden (`cls_{uid}_{id}`) çıkarır. `get()` kullanan bir kural her erişimde ekstra okuma faturalandırırdı.

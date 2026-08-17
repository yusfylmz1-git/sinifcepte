# 🔒 Firestore Güvenlik Kuralı Testleri

`firestore.rules` dosyasının **gerçekten koruduğunu** doğrulayan emülatör tabanlı testler.

Uygulama kodu doğru davransa bile kural yanlışsa veri sızar. Bu testler doğrudan kural motoruna karşı yazılmıştır: "veli başka bir velinin çocuğunu okuyabiliyor mu?", "öğretmen kendini yönetici ilan edebiliyor mu?" gibi soruları uygulama katmanını atlayarak sorar.

**Durum: 33/33 test geçiyor** ✅ (son çalıştırma: 18 Ağustos 2026)

---

## 🚀 Çalıştırma

```powershell
cd test_rules
.\run-tests.ps1
```

Betik JDK 21'i otomatik bulur, emülatörü ayağa kaldırır, testleri çalıştırır ve emülatörü kapatır. Gerçek `sinifcepte` projesine **hiç dokunmaz** — `sinifcepte-test` sahte proje kimliği kullanılır.

İlk çalıştırmadan önce bir kez:
```powershell
npm install
```

---

## ☕ Java gereksinimi

Firebase emülatörü **JDK 21+** ister. Bu makinede iki engel var:

1. Sistem genelinde **Java 8** kurulu.
2. Oracle'ın `java8path` kısayolu `PATH`'in başına sabitlenmiş — bu yüzden `JAVA_HOME` ayarlamak **tek başına yetmiyor**.

`run-tests.ps1` bu iki sorunu da çözer: Java 21'i `PATH`'in en başına koyar ve Java 8 girdilerini geçici olarak ayıklar. **Sisteminizdeki Java kurulumuna dokunmaz.**

Betik JDK'yı şu sırayla arar:
1. `-JdkPath` parametresi
2. Program Files altındaki olağan konumlar (Adoptium, Microsoft, Zulu)
3. Claude oturumunun indirdiği taşınabilir JDK

### Kalıcı kurulum (önerilir)

Şu an kullanılan JDK geçici bir klasörde duruyor ve silinebilir. Kalıcı çözüm için [Eclipse Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21) kurun — kurulumda **"Set JAVA_HOME variable"** seçeneğini işaretleyin. Betik onu otomatik bulacaktır.

Belirli bir JDK'yı zorlamak için:
```powershell
.\run-tests.ps1 -JdkPath "C:\Program Files\Eclipse Adoptium\jdk-21.0.5+11"
```

---

## 📋 Kapsam (33 test)

| Grup | Test | Ne doğrulanıyor |
| :--- | :--: | :--- |
| **1. parent_tokens** | 6 | Kod okuma oturum ister; başka öğretmen kod yazamaz; veli kodu değiştiremez |
| **2. parent_links** | 8 | **Veli izolasyonu**: veli başka velinin çocuğunu okuyamaz, başkası adına bağ kuramaz |
| **3. class_rooms** | 5 | Sahiplik: yalnızca sınıf öğretmeni yazar; erişimsiz veli okuyamaz |
| **4. school_admin_requests** | 6 | **Yetki yükseltme koruması**: öğretmen kendini onaylayamaz |
| **5. content_reports** | 5 | Veli başkası adına şikâyet edemez, şikâyetleri okuyamaz, silemez |
| **6. sync/manifest** | 2 | Herkes okur, **hiçbir istemci yazamaz** (süper admin dahil) |
| **7. Kimlik şeması** | 1 | Sahiplik kimlik deseninden okunur — doküman okuması gerektirmez |

`KRİTİK:` ile başlayan testler doğrudan veri sızıntısı senaryolarıdır.

### Çıktıdaki `PERMISSION_DENIED` satırları normaldir

Test çıktısında kırmızı `PERMISSION_DENIED` mesajları görürsünüz. Bunlar **hata değil, beklenen sonuçtur**: reddedilmesi gereken işlemlerin gerçekten reddedildiğini gösterirler. Asıl sonuç en alttaki `pass 33 / fail 0` satırıdır.

---

## 🧭 Neden bu testler önemli

Firestore kurallarının iki sinsi özelliği var:

1. **Sessizce başarısız olurlar.** Yanlış kural hata vermez; sadece veriyi açar veya kapatır. Fark edilmesi aylar sürebilir.
2. **Uygulama testleri bunları yakalamaz.** Dart tarafındaki 82 test kural motoruna hiç uğramaz.

Ayrıca bu kurallar **maliyet** kararıdır: `ownsClassRoom` ve `ownsStudent` fonksiyonları sahipliği doküman okumadan, yalnızca kimlik deseninden (`cls_{uid}_{id}`) çıkarır. `get()` kullanan bir kural her erişimde ekstra okuma faturalandırırdı.

---

## 🔧 Kural değiştirdiğinizde

`firestore.rules` üzerinde her değişiklikten sonra bu testleri çalıştırın. Yeni bir koleksiyon eklediyseniz testini de ekleyin — özellikle "başkasının verisini okuyabiliyor mu?" senaryosunu.

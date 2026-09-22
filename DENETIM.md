# Budgy — Yayın Denetimi

**21 Eylül 2026** · 385 test geçiyor · `flutter analyze` temiz · sürüm `1.0.0+1`

> **Kısa cevap: şu an çıkamaz.** Kod sağlam, ama beş şey yayını engelliyor.
> En ciddisi: yapay zekâ anahtarı uygulamanın içinde derleniyor.

| Konu | Durum |
|---|---|
| Testler | ✅ 385 geçiyor |
| `flutter analyze` | ✅ temiz |
| Sürüm | `1.0.0+1` |
| Yayını engelleyen | ❌ 5 madde |
| Eski tasarımda kalan ekran | ⚠️ 6 ekran |
| Mağaza evrakı | ❌ başlanmadı |

---

## 1. Yayını engelleyenler

Bunlar bitmeden gönderim yapılamaz, ya da yapılırsa uygulama gerçek
kullanıcıda bozuk çalışır.

### 1.1 Yapay zekâ anahtarı uygulamanın içinde · GÜVENLİK

`lib/core/ai/claude_client.dart:11` anahtarı `String.fromEnvironment` ile
alıyor. Bu, derleme sırasında anahtarı ikili dosyaya gömer; IPA ya da APK'yı
açan biri anahtarı okuyabilir ve senin hesabından harcama yapabilir. Fiş
tarama ve sesli girişteki ayrıştırma bu anahtarı kullanıyor.

**Çözüm:** ya çağrıyı Cloud Functions proxy'sine taşı (uygulama senin
sunucuna gider, anahtar sunucuda kalır), ya da ilk sürümü bu iki özellik
kapalı çıkar ve proxy'yi sonra ekle.

### 1.2 Firestore kuralları yayınlanmadı · KURAL

`recurring` ve `rules` koleksiyonlarının kuralları yazıldı ama hâlâ yerelde.
Gerçek kullanıcıda **tekrarlayan işlem kaydedilemez** ve **kendi otomasyon
kuralın eklenemez** — ikisi de hata verir.

```bash
cd ~/Projects/kopilka_app
firebase login --reauth
firebase deploy --only firestore:rules
```

### 1.3 Yeni kurallar test edilmemiş · KURAL

`test_rules/rules.test.mjs` içinde `recurring` ya da `rules` geçmiyor.
23 kural testi var ama hepsi eski koleksiyonlar için. Kural katmanı verinin
son savunma hattı; test edilmemiş kural, yazılmamış kuraldan biraz daha
iyidir.

**Çözüm:** her iki koleksiyon için sahibi olmayan kullanıcının okuyamadığını
ve geçersiz alanların reddedildiğini doğrulayan test ekle, sonra
`./tool/test_rules.sh`.

### 1.4 Apple Developer hesabı · HESAP

Notlarıma göre hesap henüz yok. Hesap olmadan App Store'a gönderim yapılamaz,
TestFlight de açılamaz. Yıllık 99 $. Onay birkaç gün sürebiliyor, bu yüzden
en erken başlatılacak adım bu. iOS ana ekran widget'ı da bu hesaba bağlı.

*Durum değiştiyse söyle, bu madde düşer.*

### 1.5 Kullanım Şartları ekranı yok · YASAL

Metin anahtarı `lib/core/l10n.dart` içinde duruyor ama ekran yok. Apple,
hesap açılabilen uygulamalarda kullanım şartları (EULA) istiyor. Gizlilik
politikası var, şartlar yok.

**Çözüm:** uydurma hukuk metni yazmak yerine Apple'ın standart EULA'sını
referans ver, üstüne uygulamaya özgü birkaç madde ekle.

---

## 2. Mağaza evrakı

Kod değil, form doldurma işi. Ama eksikse gönderim reddedilir.

### 2.1 Gizlilik politikası herkese açık bir adreste olmalı ⚠️

Uygulama içinde 251 satırlık gerçek bir metin var ve yapay zekâdan sekiz
yerde bahsediyor — bu iyi. Ama her iki mağaza da listeleme için **tarayıcıdan
açılabilen bir URL** istiyor. Aynı metni bir sayfaya koy.

### 2.2 Veri güvenliği formları ⚠️

Play'de "Data safety", App Store'da "Privacy Nutrition Labels". Burada dürüst
olmak şart: **fiş fotoğrafları ve sesli girişteki metin Anthropic'e gidiyor.**
Bunu beyan etmezsen ve sonradan fark edilirse uygulama kaldırılır.

### 2.3 Ekran görüntüleri yenilenmeli ⚠️

`docs/screenshots` klasöründekiler redesign öncesine ait. iPhone 6.7" ve
6.5", Play için telefon ve tablet boyutları gerekiyor.

### 2.4 Hazır olanlar ✅

Uygulama içi hesap silme çalışıyor (iki mağaza da zorunlu tutuyor),
Crashlytics kurulu, Android release imzalama yapılandırması yerinde.
Uygulama kimlikleri sabit: `co.ggtech.kopilka_app` (Android) ve
`co.ggtech.kopilkaApp` (iOS) — ilk yüklemeden sonra bir daha değişmez, ama
kullanıcı sadece "Budgy" görür.

---

## 3. Kalite açıkları

Çıkışı engellemez ama uygulamayı yarım gösterir.

| Konu | Durum |
|---|---|
| **Altı ekran hâlâ eski tasarımda** | Takvim, Hedefler, Geçmiş, Birikim, zarf detayı, eski işlem sayfası. Hepsi `context.budgy` kullanıyor, `Ex.` kullanan yok. Renkleri doğru ama yerleşimleri yeni ekranlara benzemiyor. |
| **Ölü kod** | `onboarding_screen.dart` ve `onboarding_story_screen.dart` yalnız birbirlerine ve eski bir teste bağlı. |
| **iOS ana ekran widget'ı yarım** | Swift kodu yazıldı (`ios/BudgyWidget`), kalan tek adım Xcode'da Widget Extension target'ı + App Group. Apple hesabı gerekiyor. Android widget'ı çalışıyor. |
| **Açılışta bir kare İngilizce** | Dil Firestore'dan geldiği için ilk kare varsayılanla çiziliyor. Son seçilen dili cihazda saklamak yeterli. |
| **App Check zorlaması kapalı** | Paket kurulu ama Firebase Console'dan zorlama açılmamış. |

---

## 4. Fikirler

Etkiye göre sıralı. İlk ikisi Budgy'yi rakiplerinden ayırır — çünkü ikisi de
**Türkiye'de Apple Pay olmamasının** etrafından dolaşıyor.

### 4.1 Banka bildirimlerini yakalama (Android) · EN YÜKSEK ETKİ

Banka "Kartınızdan 450,00 TL MIGROS harcaması" push'u gönderdiğinde uygulama
onu okur, tutarı ve mağazayı ayrıştırır, kategori otomasyonundan geçirir ve
onayına sunar. Kullanıcı hiçbir şey yazmaz.

`~/Projects/cebim_proto` içinde çalışan bir prototip zaten var: Kotlin
bildirim dinleyici, Türk banka listesi, uçtan uca doğrulanmış.

Bu, "harcamayı girmeyi unutuyorum" sorununu ortadan kaldırır — bütçe
uygulamalarının en büyük terk sebebi budur.

### 4.2 iOS Paylaş uzantısı · YÜKSEK ETKİ

iOS'ta bildirim okumak mümkün değil, ama banka SMS'ini seçip
**Paylaş → Budgy** demek mümkün. Metin ayrıştırılır, işlem dolu gelir.
Apple Pay olmadan Türkiye'de çalışan tek yarı-otomatik yol.

### 4.3 Kısayollar köprüsü · ORTA

Şu an Budgy dışarıdan hiç çağrılamıyor: URL şeması yok, App Intent yok.
`budgy://add?amount=450&note=Migros` desteği eklenince Eylem Düğmesi, arkaya
çift dokunma, NFC etiketi ya da Kontrol Merkezi'nden tek dokunuşla dolu giriş
ekranı açılır. Kazakistan'da Apple Pay olduğu için orada "İşlem" tetikleyicisi
de çalışır.

### 4.4 Paylaşılan cüzdan · BÜYÜK İŞ

Çift ya da ev arkadaşları aynı cüzdanı görür. Firestore'daki her koleksiyonun
alan kimliğine göre ayrılması gerekiyor — ayrı ve büyük bir iş, ama ücretli
sürüm için en mantıklı özellik.

---

## 5. Önerdiğim sıra

Ucuz ve engelleyici olanlar önce; pahalı olanlar mağaza hesabı beklerken.

1. **Firestore kurallarını yayınla** — beş dakika. Şu an tekrarlayan işlem ve otomasyon kuralı bozuk.
2. **Yeni kurallar için test yaz** — yarım gün. Veri güvenliğinin son savunma hattı.
3. **Apple Developer hesabını başlat** — onay bekleyecek, o yüzden erken başlat.
4. **AI anahtarını sunucuya taşı** — ya proxy, ya da ilk sürümde o iki özelliği kapat.
5. **Altı eski ekranı yenile** — ekran görüntülerini çekmeden önce, yoksa iki kez çekersin.
6. **Mağaza evrakı** — gizlilik URL'si, veri formları, ekran görüntüleri, açıklama.
7. **TestFlight ile kendi telefonunda kullan** — bir hafta gerçek kullanım, gönderimden önceki en iyi test.
8. **Sonra fikirler** — banka bildirimi yakalama, paylaş uzantısı.

---

*Bu denetim depodaki koddan çıkarıldı. Apple Developer hesabının durumu
notlarımdan geliyor; değiştiyse o madde düşer.*

# Budgy — Yayın Denetimi

**22 Eylül 2026** · 398 test geçiyor · 50/50 kural testi · `flutter analyze` temiz · sürüm `1.0.0+1`

> **Kısa cevap: henüz çıkamaz, ama liste kısaldı.** Kural katmanı artık
> yayında ve test edilmiş durumda. Kalan dört engelden biri güvenlik
> (yapay zekâ anahtarı), biri hesap, ikisi yazı işi.

| Konu | Durum |
|---|---|
| Testler | ✅ 398 geçiyor |
| Kural testleri | ✅ 50/50 |
| `flutter analyze` | ✅ temiz |
| Firestore kuralları | ✅ yayında (22 Eyl) |
| Hesap anonim değil | ✅ e-postaya bağlandı |
| Yayını engelleyen | ❌ 4 madde |
| Eski tasarımda kalan ekran | ⚠️ 6 ekran |
| Mağaza evrakı | ❌ başlanmadı |

---

## 0. 22 Eylül'de kapanan maddeler

### 0.1 `accounts` kuralı hiç yazılmamıştı · KRİTİKTİ

Firestore'da `match /users/{uid}` izni alt koleksiyonlara **inmez**; her
alt koleksiyonun kendi bloğu olmak zorunda. `accounts` için blok hiçbir
commit'te yoktu. Sonuç: cüzdan hem okunamıyor hem yazılamıyordu.

Görünen belirti tamamen yanıltıcıydı — takvimde gün kaydedilmiyordu ve
hiçbir hata çıkmıyordu. Sebebi `setDay`'in gün belgesiyle cüzdanı **tek
batch'te** yazması: batch atomik olduğu için cüzdan reddedilince gün
kaydı da geri alınıyordu. Aynı hata her harcama ve gelir girişini de
etkiliyordu (hepsi `_cashDelta` ile cüzdana yazıyor).

Kural eklendi, 7 test yazıldı, yayınlandı. Veri kaybı olmadı: kural
açıldıktan sonra sunucudan okunan bakiye önbellektekiyle aynıydı.

**Ders:** yeni bir koleksiyon eklendiğinde kural bloğu ve kural testi
aynı commit'te gelmeli. Kural dosyasında olmayan koleksiyon, yazılmamış
özellik demek.

### 0.2 Anonim hesap e-postaya bağlandı

`linkWithCredential` ile mevcut uid korunarak bağlandı — veri taşınmadı,
uid değişmedi. Eski bir test hesabı e-postayı işgal ettiği için önce o
auth kaydı silindi.

### 0.3 Kurallar yayınlandı ve test edildi

Eski denetimdeki 1.2 ve 1.3 maddeleri kapandı: `recurring`, `rules`,
`accounts` ve işlem düzenleme (`updateTx`) kuralları hem yayında hem
testli.

---

## 1. Yayını engelleyenler

### 1.1 Yapay zekâ anahtarı uygulamanın içinde · GÜVENLİK

`lib/core/ai/claude_client.dart:11` anahtarı `String.fromEnvironment` ile
alıyor. Bu, derleme sırasında anahtarı ikili dosyaya gömer; IPA ya da APK'yı
açan biri anahtarı okuyabilir ve senin hesabından harcama yapabilir. Fiş
tarama ve sesli girişteki ayrıştırma bu anahtarı kullanıyor.

**Çözüm:** ya çağrıyı Cloud Functions proxy'sine taşı (uygulama senin
sunucuna gider, anahtar sunucuda kalır), ya da ilk sürümü bu iki özellik
kapalı çıkar ve proxy'yi sonra ekle.

### 1.2 Doğrulama maili spam'e düşüyor · YENİ

Gerçek kullanıcıda test edildi: Gmail maili doğrudan Spam kutusuna attı.
Bir bütçe uygulamasında kayıt akışının ilk adımı bu — spam'e düşen mail,
kaydı tamamlamayan kullanıcı demek.

Sebep gönderen domain: `noreply@kopilka-b75f6.firebaseapp.com` binlerce
Firebase projesiyle ortak, itibarı paylaşılıyor. Gmail'in kendi açıklaması
"geçmişte spam olarak işaretlenen mesajlara benziyor" diyordu.

Yapıldı: proje adı `Budgy`, gönderen adı `Budgy`, konu elle yazıldı,
reply-to gerçek adres. Bunlar görünümü düzeltti, teslimatı çözmedi.

**Çözüm: özel domain.** Firebase'in kendi özelliği, Hosting gerektirmiyor,
ücretsiz. Hem gönderen adresini hem de bağlantı adresini senin domainine
taşıyor ve SPF/DKIM kayıtlarını Firebase veriyor. Adımlar §3'te.

*Not: doğrulama ve e-posta değiştirme maillerinin GÖVDESİ Firebase
tarafından kilitli (kötüye kullanım önlemi) — sadece şifre sıfırlamanınki
düzenlenebiliyor. Tamamen kendi HTML'ini istiyorsan tek yol Cloud
Functions + `generateEmailVerificationLink`.*

### 1.3 Apple Developer hesabı · HESAP

Notlarıma göre hesap henüz yok. Hesap olmadan App Store'a gönderim yapılamaz,
TestFlight de açılamaz. Yıllık 99 $. Onay birkaç gün sürebiliyor, bu yüzden
en erken başlatılacak adım bu. iOS ana ekran widget'ı da bu hesaba bağlı.

*Durum değiştiyse söyle, bu madde düşer.*

### 1.4 Kullanım Şartları ekranı yok · YASAL

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

## 3. Firebase'de yapılacaklar

Sırayla. İlki mail sorununu çözen asıl adım.

### 3.1 Özel domain — maili spam'den çıkarır

**Önce karar:** hangi alt domain? `budgy.ggtech.co` öneriyorum — `ggtech.co`
zaten senin, yeni domain almana gerek yok ve alt domain kullanmak ana
domainin mevcut mail kayıtlarına dokunmuyor.

1. Firebase Console → **Authentication → Templates** → herhangi bir şablon
   → **Customize domain**
2. Alan adını gir: `budgy.ggtech.co`
3. Firebase sana **TXT ve CNAME kayıtları** verir — bunları `ggtech.co`
   DNS'ine ekle
4. Doğrulama 24 saate kadar sürebilir; konsol "Verification complete"
   diyene kadar bekle
5. **Apply Custom Domain**

Bittiğinde gönderen `noreply@budgy.ggtech.co` olur ve doğrulama bağlantısı
da `firebaseapp.com` yerine senin adresini gösterir. SPF/DKIM hizalandığı
için Gmail artık ortak domainin itibarına bakmaz.

> Daha önce bu akış "Could not verify domain" hatası verdi — sebebi DNS
> kayıtlarının henüz eklenmemiş olması. Kayıtlar girilmeden doğrulama geçmez.

**Bana söylemen gereken:** `ggtech.co` DNS'i nerede yönetiliyor? (Cloudflare,
Google Domains, hosting paneli…) Kayıtları oraya göre adım adım yazarım.

### 3.2 Şablon dili Türkçe

**Authentication → Templates** → sol altta **Template language** → `Türkçe`.
Gövdeyi yazamıyorsun ama Firebase'in hazır Türkçe çevirisini seçebilirsin.

### 3.3 App Check zorlamasını aç

Paket kurulu ama Firebase Console'dan zorlama açılmamış. Açılmadığı sürece
veritabanına uygulaman dışından da istek atılabilir.

⚠️ Simülatörde App Check zaten çalışmıyor (`DeviceCheckProvider is not
supported on current platform`). Zorlamayı **gerçek cihazda test ettikten
sonra** aç, yoksa geliştirme simülatörü tamamen kilitlenir.

### 3.4 Blaze planı gözetimi

Proje Blaze'de (kullandıkça öde). Yayına çıkmadan önce **bütçe uyarısı**
kur — Google Cloud Console → Billing → Budgets & alerts. Kaçak bir döngü
ya da kötüye kullanım faturayı büyütmeden haber versin.

---

## 4. Kalite açıkları

Çıkışı engellemez ama uygulamayı yarım gösterir.

| Konu | Durum |
|---|---|
| **Altı ekran hâlâ eski tasarımda** | Takvim, Hedefler, Geçmiş, Birikim, zarf detayı, eski işlem sayfası. Hepsi `context.budgy` kullanıyor, `Ex.` kullanan yok. |
| **Ölü kod** | `onboarding_screen.dart` ve `onboarding_story_screen.dart` yalnız birbirlerine ve eski bir teste bağlı. |
| **iOS ana ekran widget'ı yarım** | Swift kodu yazıldı (`ios/BudgyWidget`), kalan tek adım Xcode'da Widget Extension target'ı + App Group. Apple hesabı gerekiyor. Android widget'ı çalışıyor. |
| **Açılışta bir kare İngilizce** | Dil Firestore'dan geldiği için ilk kare varsayılanla çiziliyor. Son seçilen dili cihazda saklamak yeterli. |
| **Sessiz Firestore hataları** | `accounts` olayının asıl dersi: yazma reddedildiğinde kullanıcı hiçbir şey görmüyor. Repository'lerdeki `batch.commit()` çağrıları `permission-denied`'ı yakalayıp kullanıcıya göstermeli. |

---

## 5. Önerdiğim sıra

1. **Özel domain + DNS kayıtları** — mail sorununu bitirir, DNS beklemesi olduğu için erken başlat (§3.1).
2. **Apple Developer hesabını başlat** — onay bekleyecek, o yüzden erken.
3. **AI anahtarını Cloud Functions'a taşı** — aynı Functions kurulumu ileride özel mail HTML'i için de kullanılır.
4. **Kullanım Şartları ekranı** — yarım gün.
5. **Sessiz Firestore hatalarını görünür yap** — `accounts` hatası bir daha yaşanmasın.
6. **Altı eski ekranı yenile** — ekran görüntülerini çekmeden önce, yoksa iki kez çekersin.
7. **Mağaza evrakı** — gizlilik URL'si, veri formları, ekran görüntüleri, açıklama.
8. **TestFlight ile kendi telefonunda kullan** — bir hafta gerçek kullanım, gönderimden önceki en iyi test.

---

*Bu denetim depodaki koddan ve 22 Eylül'de simülatörde alınan gerçek
loglardan çıkarıldı. Apple Developer hesabının durumu notlarımdan geliyor;
değiştiyse o madde düşer.*

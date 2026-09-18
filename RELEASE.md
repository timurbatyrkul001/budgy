# Budgy — Mağaza Yayın Rehberi

Bu dosya, kod tarafı bittikten sonra kalan **hesap ve mağaza** adımlarını
içerir. Kodla ilgili her şey hazır; aşağıdakiler senin hesaplarınla yapılacak.

---

## 0. Mevcut durum

| Konu | Durum |
|---|---|
| `flutter analyze` | ✅ temiz |
| Birim + widget testleri | ✅ 90 test geçiyor (`flutter test`) |
| Firestore kural testleri | ✅ 23 test geçiyor (`./tool/test_rules.sh`) |
| Android derleme | ✅ debug + release |
| iOS derleme | ✅ (`flutter build ios --no-codesign`) |
| Sürüm | `1.0.0+1` |
| Uygulama kimliği | Android `co.ggtech.kopilka_app` · iOS `co.ggtech.kopilkaApp` |
| Crashlytics | ✅ kurulu (debug'da kapalı) |
| App Check | ✅ kurulu (Console'dan zorlama açılmalı) |
| Android ana ekran widget'ı | ✅ çalışıyor |
| iOS ana ekran widget'ı | ⏳ Apple hesabı gerekiyor (bkz. `WIDGET_SETUP.md`) |

> **Uygulama kimliği bir daha değişmez.** İlk yüklemeden sonra hem Play hem
> App Store bunu kilitler. "kopilka" adı sadece sana görünür, kullanıcı
> "Budgy" görür.

---

## 1. Android imzalama anahtarı

Keystore **bir kez** oluşturulur ve **asla kaybedilmemelidir** — kaybedersen
uygulamayı bir daha güncelleyemezsin.

```bash
keytool -genkey -v \
  -keystore ~/budgy-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias budgy
```

Sorulan parolayı bir parola yöneticisine kaydet. Sonra
`android/key.properties` dosyasını oluştur (git'e girmez, `.gitignore`'da):

```properties
storePassword=<yukarıda girdiğin parola>
keyPassword=<yukarıda girdiğin parola>
keyAlias=budgy
storeFile=/Users/timurbatyrkul/budgy-upload-key.jks
```

Doğrula:

```bash
flutter build appbundle --release
```

`build/app/outputs/bundle/release/app-release.aab` çıkmalı. Bu dosya Play
Console'a yüklenir (APK değil, **AAB**).

**Yedekle:** `~/budgy-upload-key.jks` + parolalar. İkisi de gitmezse hesap
kurtarma süreci haftalar sürer.

---

## 2. Firebase Console ayarları

1. **Crashlytics'i etkinleştir** — Console → Crashlytics → Enable. İlk çökme
   raporu geldiğinde panel dolar.
2. **App Check** — Console → App Check:
   - Android: Play Integrity sağlayıcısını kaydet
   - iOS: App Attest / DeviceCheck kaydet
   - Debug cihazlar için: uygulamayı debug'da çalıştır, konsolda yazan debug
     token'ı Console'a ekle
   - Firestore için **zorlamayı (enforcement) en son aç** — önce birkaç gün
     "monitor" modunda izle, meşru istekler reddedilmesin.
3. **Firestore kurallarını ve indeksleri yayınla**:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

---

## 3. Google Play Console

- Hesap: $25 tek seferlik.
- 2023 sonrası açılan **bireysel** hesaplarda üretim yayınından önce
  **12 test kullanıcısıyla 14 gün kapalı test** zorunlu. Bunu erken başlat,
  takvimi o belirliyor.

**Data safety formu** — Budgy için doğru cevaplar:

| Soru | Cevap |
|---|---|
| Veri topluyor mu? | Evet |
| Kişisel bilgi | İsim, e-posta adresi (opsiyonel telefon, fotoğraf) |
| Finansal bilgi | "Diğer finansal bilgiler" — kullanıcının girdiği bütçe kayıtları |
| Uygulama etkinliği | Hayır |
| Çökme günlükleri / tanılama | Evet (Crashlytics) |
| Veri şifreleniyor mu (aktarımda)? | Evet (TLS) |
| Kullanıcı silme talep edebiliyor mu? | Evet — uygulama içi: Profil → Hesabı sil |
| Veri üçüncü tarafla paylaşılıyor mu? | Hayır |

Ayrıca **hesap silme URL'si** isteniyor (uygulama içi silme yeterli değil,
web'de de bir sayfa şart). Gizlilik politikası sayfasına bir bölüm ekle.

---

## 4. App Store Connect

- Apple Developer Program: $99/yıl.
- Xcode → Runner target → Signing & Capabilities → Team seç.
- `flutter build ipa --release` → `build/ios/ipa/*.ipa` → Transporter ile yükle.

**Privacy Nutrition Labels** — Play tablosuyla aynı içerik:

| Kategori | Toplanıyor | Kimliğe bağlı | Takip için |
|---|---|---|---|
| İletişim bilgisi (isim, e-posta) | Evet | Evet | Hayır |
| Finansal bilgi (kullanıcı girdisi) | Evet | Evet | Hayır |
| Tanımlayıcılar (kullanıcı kimliği) | Evet | Evet | Hayır |
| Tanılama (çökme verisi) | Evet | Hayır | Hayır |

**Şifreleme:** `ITSAppUsesNonExemptEncryption = false` zaten `Info.plist`'te —
yalnız standart TLS kullanıyoruz, ek beyan gerekmiyor.

**Hesap silme:** Apple, hesap oluşturan uygulamalarda uygulama içi silmeyi
zorunlu tutar. Profil → Hesabı sil hazır ve yeniden kimlik doğrulama akışı da
eklendi (`requires-recent-login` durumunda kullanıcıya parola sorulur).

---

## 5. Yayın öncesi son kontrol

```bash
flutter analyze          # temiz olmalı
flutter test             # hepsi geçmeli
./tool/test_rules.sh     # Firestore kuralları
flutter build appbundle --release
flutter build ipa --release
```

Gerçek cihazda elle dene:
- [ ] Anonim başla → gelir gir → zarflara dağıt → harcama yap
- [ ] Hesabı e-postaya bağla, verinin korunduğunu gör
- [ ] Uygulamayı kapat/aç, biyometrik kilidi dene (Android + iOS)
- [ ] Bildirim izni iste, hatırlatıcı kur, geldiğini gör
- [ ] Dili değiştir → sayı biçimi ve takvim dili değişmeli
- [ ] Hesabı sil → Firestore'da `users/{uid}` altında hiçbir şey kalmamalı
- [ ] Uçak modunda kaydetmeyi dene → kırmızı hata şeridi çıkmalı

---

## 6. Mağaza metinleri (taslak)

**Kısa açıklama (Play, 80 karakter):**
> Günlük kazancını zarflara böl, nereye gittiğini gör.

**Uzun açıklama:**
> Budgy, kazancını kâğıt zarf yöntemiyle takip etmeni sağlar. Çalıştığın
> günleri işaretle, kazandığın parayı zarflara böl (kira, market, ulaşım…),
> harcadıkça ne kaldığını gör.
>
> • Zarf bütçeleme — her kategoriye ayrı pay
> • Takvim — hangi gün ne kazandın
> • Kazanç serisi — düzenli girmeye teşvik
> • Tempo uyarısı — bütçeyi ay sonundan önce aşacaksan haber verir
> • Birikim hedefleri — tatil, araba, ne istersen
> • Döviz zarfları — canlı kurla ₺'den çevir
> • Hatırlatmalar — kira gününü kaçırma
> • Türkçe, İngilizce, Rusça · Açık ve koyu tema · Face ID / parmak izi kilidi
>
> Banka hesabına bağlanmaz. Verini satmayız.

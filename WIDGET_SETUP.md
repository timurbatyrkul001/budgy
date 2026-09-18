# Budgy Ana Ekran Widget'ı

Widget üç parçadan oluşuyor:

| Parça | Durum |
|---|---|
| Flutter köprüsü (`lib/core/widget_service.dart`) | ✅ Hazır |
| **Android** widget (`BudgyWidgetProvider` + layout) | ✅ **Çalışıyor** |
| **iOS** widget (`ios/BudgyWidget/BudgyWidget.swift`) | ⏳ Kod hazır, Xcode target'ı eksik |

Gösterdiği bilgi: 🟢 yeşil kart — Budgy + 🔥seri · "Bugün: {kazanç}" · "Kalan:
{cepte kalan}". Etiketler uygulamadan localize gönderildiği için widget da üç
dilli çalışır.

---

## Android — kurulum gerekmiyor

Her şey projede: `BudgyWidgetProvider.kt`, `res/layout/budgy_widget.xml`,
`res/xml/budgy_widget_info.xml` ve manifest'teki receiver.

Denemek için:

```bash
flutter run
```

Uygulamayı bir kez aç (veri yazılsın) → ana ekrana çık → boş alana uzun bas →
**Widget'lar** → **Budgy** → sürükleyip bırak.

---

## iOS — Apple Developer hesabı gerekiyor

Widget Extension'ın imzalanabilmesi ve **App Group** yetkilendirmesi
alabilmesi için ücretli Apple Developer hesabı şart. Hesap açıldıktan sonra:

1. Workspace'i aç (`.xcodeproj` değil!):
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **File → New → Target…** → **Widget Extension** → Next.
   - Product Name: **BudgyWidget** (bu isim `widget_service.dart` içindeki
     `iOSWidgetName` ile aynı olmalı)
   - "Include Live Activity" ve "Include Configuration App Intent" → **KAPALI**
   - Team: kendi geliştirici hesabın → Finish
   - "Activate scheme?" sorarsa **Cancel** (Runner scheme'inde kal)

3. Xcode'un oluşturduğu `BudgyWidget.swift` dosyasının içeriğini sil, yerine
   `ios/BudgyWidget/BudgyWidget.swift` içeriğini yapıştır.

4. **App Group** ekle — **iki target'a da**:
   - **Runner** target → Signing & Capabilities → + Capability → **App Groups**
     → + → `group.co.ggtech.kopilkaApp`
   - Aynısını **BudgyWidget** target'ı için tekrarla.
   - Grup adı `widget_service.dart` içindeki `appGroupId` ile **birebir** aynı
     olmalı, yoksa widget veriyi okuyamaz.

5. `flutter run` → uygulamayı bir kez aç → ana ekranda widget'ı ekle.

> `@main` için SourceKit uyarısı, dosya target'a eklenene kadar normaldir.

### O zamana kadar ne oluyor?

Hiçbir şey bozulmuyor: `BudgyWidget.push()` içindeki tüm çağrılar `try/catch`
ile sarılı, App Group yoksa sessizce no-op. iOS'ta widget görünmez, uygulama
normal çalışır.

# Budgy Ana Ekran Widget'ı — Kurulum (senin yapacağın tek native adım)

Flutter tarafı hazır: `lib/core/widget_service.dart` bugünkü kazanç / cepte kalan /
kazanç serisini App Group'a yazıyor (`root_screen`'de otomatik izleniyor).
iOS widget kodu da hazır: `ios/BudgyWidget/BudgyWidget.swift` + `Info.plist`.

Geriye tek şey kaldı: Xcode'da **Widget Extension target'ı** + **App Group** eklemek.
~2 dakika. Aşağıdaki adımları izle (istersen birlikte yaparız).

## iOS (Xcode)

1. Xcode'da projeyi aç:
   `open ios/Runner.xcworkspace`  (workspace, .xcodeproj değil!)

2. **File → New → Target…** → **Widget Extension** → Next.
   - Product Name: **BudgyWidget**  (bu isim önemli, koddaki `iOSWidgetName` ile aynı)
   - "Include Live Activity" ve "Include Configuration App Intent" → **KAPALI** (işaretleme).
   - Team: kendi geliştirici hesabın. Finish.
   - "Activate scheme?" sorarsa **Cancel** (Runner scheme'inde kal).

3. Xcode senin için `BudgyWidget/` klasörü + otomatik bir `BudgyWidget.swift` oluşturur.
   O otomatik dosyanın **içeriğini sil**, yerine benim yazdığım
   `ios/BudgyWidget/BudgyWidget.swift` içeriğini yapıştır (ya da dosyayı onunla değiştir).

4. **App Group** ekle (iki target'a da):
   - Sol panelde **Runner** target → **Signing & Capabilities** → **+ Capability** →
     **App Groups** → **+** → `group.co.ggtech.kopilkaApp`
   - Aynısını **BudgyWidget** target'ı için de yap (aynı grup adı).
   - Grup adı, `widget_service.dart` içindeki `appGroupId` ile **birebir** aynı olmalı.

5. Çalıştır:  `flutter run`  → uygulamayı bir kez aç (veri yazılsın) → ana ekrana çık →
   boş bir alana uzun bas → **+** → "Budgy" widget'ını ekle.

Not: `@main` için SourceKit uyarısı, dosya target'a eklenene kadar normaldir; eklenince kaybolur.

## Android (opsiyonel, sonra)
Android widget'ı için `AppWidgetProvider` + layout XML + manifest receiver gerekir;
Flutter tarafı zaten `androidWidgetName = 'BudgyWidgetProvider'` ile hazır. iOS bitince
istersen Android'i de ekleriz.

## Ne gösteriyor
🟢 yeşil kart: Budgy + 🔥seri · "Bugün: {kazanç}" · "Kalan: {cepte kalan}".
Üç dilli (etiketler uygulamadan localize gönderiliyor). small + medium boyut.

import AppIntents

/// Kısayollar uygulamasında ve Siri'de görünen hazır kısayollar.
///
/// `AppShortcutsProvider` derleme sırasında Xcode'un App Intents meta veri
/// işlemcisi tarafından okunur; bu yüzden gövde DÜZ bir literal kalmalı
/// (koşul, döngü, yardımcı fonksiyon yok). Kullanıcı hiçbir şey kurmadan
/// "Hey Siri, Budgy'ye harcama ekle" diyebilir ya da Kısayollar'da
/// "Add Expense" eylemini kendi otomasyonuna koyabilir (ileride: Apple Pay
/// "İşlem" tetikleyicisi → bu eylem).
///
/// Her cümle `\(.applicationName)` içermeli — Apple şartı; yoksa cümle
/// derlemede atılır. Uygulamanın ayrı tr/ru .lproj yerelleştirmesi yok
/// (yalnız Base), dolayısıyla `AppShortcuts.strings` ile dil başına cümle
/// veremiyoruz: üç dilin cümleleri aynı listede duruyor. Siri cihaz dili
/// hangisiyse o dildeki cümleleri tanır; diğerleri zararsız fazlalık.
///
/// `AppShortcut(intent:phrases:)` iOS 16 kurucusu: iOS 17 SDK bunu
/// `shortTitle`/`systemImageName` alan sürüm lehine "deprecated" işaretler
/// (yalnız uyarı). Yeni kurucu iOS 17 ister; asgari sürümümüz 15, hedef 16
/// olduğu için bilinçli olarak eskisi kullanılıyor.
@available(iOS 16.0, *)
struct BudgyShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddExpenseIntent(),
      phrases: [
        // English
        "Add expense to \(.applicationName)",
        "Add an expense in \(.applicationName)",
        "Log a spend in \(.applicationName)",
        // Türkçe
        "\(.applicationName) harcama ekle",
        "\(.applicationName) uygulamasına harcama ekle",
        "\(.applicationName) ile harcama kaydet",
        // Русский
        "Добавь расход в \(.applicationName)",
        "Добавить расход в \(.applicationName)",
        "Запиши трату в \(.applicationName)",
      ]
    )
  }

  static var shortcutTileColor: ShortcutTileColor = .teal
}

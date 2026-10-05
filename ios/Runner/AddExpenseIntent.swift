import AppIntents
import Foundation

/// "Harcama ekle" App Intent'i — Kısayollar ve Siri'den görünür.
///
/// Ana uygulama hedefinde yaşar (ayrı bir extension değil): böylece
/// `perform()` uygulamanın kendi sürecinde koşar ve Flutter'a kanalla
/// ulaşabilir. Extension'da olsaydı ortak depo + App Group gerekirdi; App
/// Group ücretli Apple hesabı ister, şimdilik yok.
///
/// Doğrulama ve metinler FLUTTER tarafında: tutar/kategori/hesap kontrolü,
/// kur dondurma ve üç dilli cevap hep orada. Burası yalnız parametreleri
/// sözlüğe koyar, köprüden geçirir, cevabı kullanıcıya gösterir. `ok: false`
/// gelirse Flutter'ın yazdığı sebep hata olarak fırlatılır — Kısayollar ve
/// Siri o metni aynen okur, "bir hata oluştu" demez.
///
/// iOS 16+: AppIntents çerçevesi daha eskide yok; uygulamanın asgari sürümü
/// 15 olduğu için tüm tipler `@available` ile işaretli. iOS 15'te bu dosya
/// derlenir ama hiçbir sembol kullanılmaz.
@available(iOS 16.0, *)
struct AddExpenseIntent: AppIntent {
  static var title: LocalizedStringResource = "Add Expense"
  static var description = IntentDescription(
    "Records an expense in Budgy. Optionally add a note, a category and the account it was paid from.",
    categoryName: "Expenses"
  )

  /// Uygulama açık değilse açılır: `perform()` Flutter'a ihtiyaç duyar ve
  /// Flutter yalnız uygulama sürecinde yaşar. Bkz. `IntentBridge`.
  static var openAppWhenRun: Bool = true

  @Parameter(
    title: "Amount",
    description: "How much was spent, in the account's currency."
  )
  var amount: Double

  @Parameter(
    title: "Note",
    description: "Merchant name or a short comment."
  )
  var note: String?

  @Parameter(
    title: "Category",
    description: "Category name as it appears in Budgy. Left empty, Budgy may pick one from the note."
  )
  var categoryName: String?

  @Parameter(
    title: "Account",
    description: "Account or card name as it appears in Budgy."
  )
  var accountName: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Add expense of \(\.$amount)") {
      \.$note
      \.$categoryName
      \.$accountName
    }
  }

  func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
    // Sözleşme: `amount` (Double, zorunlu), `note`/`categoryName`/
    // `accountName` (isteğe bağlı), `source` ("siri" | "shortcut").
    //
    // `source`: AppIntents, intent'in Siri'den mi Kısayollar'dan mı
    // geldiğini söylemez; ikisi de aynı `perform()`'a düşer. Flutter tarafı
    // bu alanı yalnız kayıt/ayrıştırma için okuyor, davranış değiştirmiyor.
    // Ayrım gerekirse ileride iki ayrı intent tipi tanımlanır.
    var args: [String: Any] = [
      "amount": amount,
      "source": "shortcut",
    ]
    if let note = trimmed(note) { args["note"] = note }
    if let category = trimmed(categoryName) { args["categoryName"] = category }
    if let account = trimmed(accountName) { args["accountName"] = account }

    let reply: IntentBridge.Reply
    do {
      reply = try await IntentBridge.shared.addExpense(args)
    } catch IntentBridge.BridgeError.timeout {
      throw AddExpenseIntentError(
        message: "Budgy didn't respond in time. Open the app once and try again."
      )
    } catch {
      throw AddExpenseIntentError(
        message: "Budgy couldn't record the expense. Open the app and try again."
      )
    }

    guard reply.ok else {
      // Flutter sebebi uygulamanın dilinde yazdı ("Kur alınamadı…",
      // "Tutar sıfırdan büyük olmalı…"): aynen kullanıcıya.
      throw AddExpenseIntentError(message: reply.message)
    }
    return .result(
      value: reply.message,
      dialog: IntentDialog(stringLiteral: reply.message)
    )
  }

  private func trimmed(_ value: String?) -> String? {
    guard let value else { return nil }
    let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? nil : t
  }
}

/// Kullanıcıya gösterilecek metni taşıyan hata. Kısayollar ve Siri
/// `localizedStringResource`'u aynen gösterir/okur.
@available(iOS 16.0, *)
struct AddExpenseIntentError: Error, CustomLocalizedStringResourceConvertible {
  let message: String

  var localizedStringResource: LocalizedStringResource {
    // Enterpolasyon: metin anahtar olarak aranmaz, olduğu gibi gösterilir.
    "\(message)"
  }
}

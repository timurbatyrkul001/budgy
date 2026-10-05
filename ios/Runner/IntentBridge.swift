import Flutter
import Foundation

/// App Intent ↔ Flutter köprüsü. Kanal adı ve sözleşme Dart tarafıyla
/// (`lib/features/intents/intent_channel.dart`) BİREBİR aynı olmalı:
///
/// * Flutter → natif: `ready` (argümansız) — Dart tarafı dinlemeye hazır.
/// * Natif → Flutter: `addExpense` (sözlük) → `{"ok": Bool, "message": String}`.
///
/// SOĞUK BAŞLATMA SORUNU: Intent uygulamayı kendisi ayağa kaldırabilir ve
/// `perform()` Flutter motoru daha Dart kodunu çalıştırmadan koşar. O anda
/// kanalı çağırsaydık cevap gelmez, intent zaman aşımına düşerdi. Çözüm:
/// istekler bir kuyruğa yazılır ve Dart `ready` dediği anda sırayla
/// Flutter'a aktarılır. Uygulama zaten açıksa kuyruk boş geçer, istek anında
/// gider. Her istek bir zaman aşımıyla korunur: Flutter hiç hazır olmazsa
/// (ör. oturum açılamadı) intent "cevap yok" diye kapanır, sonsuza kadar
/// beklemez.
///
/// Bütün durum (kanal, hazır bayrağı, kuyruk) yalnız ana iş parçacığında
/// değişir: `FlutterMethodChannel` zaten ana iş parçacığı ister, biz de
/// kilit yerine `DispatchQueue.main`'i tek kapı yapıyoruz. iOS 15'te de
/// derlenir — AppIntents'e burada hiç dokunulmuyor.
final class IntentBridge: NSObject {
  static let shared = IntentBridge()

  /// Dart tarafındaki `intentChannelName` ile aynı.
  static let channelName = "co.ggtech.budgy/intents"

  /// Flutter'ın `addExpense` cevabı.
  struct Reply {
    let ok: Bool
    /// Kullanıcıya gösterilecek hazır metin (uygulamanın dilinde).
    let message: String
  }

  enum BridgeError: Error {
    /// Zaman aşımı içinde Dart `ready` demedi ya da cevap vermedi.
    case timeout
    /// Dart tarafı kanalı dinlemiyor (ör. oturum kapandı, host söküldü).
    case notReady
    /// Kanal `FlutterError` döndürdü ya da cevap beklenen biçimde değil.
    case channelFailure(String)
  }

  private var channel: FlutterMethodChannel?
  private var isReady = false

  /// Henüz Flutter'a gitmemiş istekler (sıra korunur).
  private var queue: [(id: UUID, args: [String: Any])] = []

  /// Cevap bekleyen intent'ler. Bir continuation YALNIZ BİR KEZ
  /// sürdürülebilir; [finish] sözlükten silip sürdürür, ikinci çağrı
  /// (ör. cevap geldikten sonra zaman aşımı) sessizce yok sayılır.
  private var waiters: [UUID: CheckedContinuation<Reply, Error>] = [:]

  private override init() {
    super.init()
  }

  /// Flutter motoru kurulduğunda AppDelegate çağırır. Kanalı yaratır ve
  /// Dart'ın `ready` çağrısını dinlemeye başlar. Ana iş parçacığında
  /// çağrılmalı (AppDelegate zaten orada).
  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: IntentBridge.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "ready":
        // Sıcak yeniden başlatma (hot restart) ve host'un yeniden
        // kurulması `ready`'yi tekrar gönderir — her seferinde kuyruğu
        // boşaltmak yeterli, bayrak zaten doğru.
        self.isReady = true
        result(nil)
        self.flush()
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    // Motor yeniden kurulduysa (nadir) Dart tarafı tekrar `ready` diyecek;
    // o ana kadar yeni istekler kuyrukta bekler.
    isReady = false
  }

  /// Harcamayı Flutter'a yazdırır. Dart hazır değilse kuyruğa koyar ve
  /// hazır olunca gönderir; [timeout] saniye içinde cevap gelmezse
  /// `BridgeError.timeout` fırlatır.
  func addExpense(
    _ args: [String: Any],
    timeout: TimeInterval = 20
  ) async throws -> Reply {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        let id = UUID()
        self.waiters[id] = continuation
        self.queue.append((id: id, args: args))
        self.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
          // Hâlâ kuyruktaysa çıkar: Dart geç hazır olursa süresi geçmiş
          // isteği göndermeyelim, kullanıcı çoktan vazgeçmiş olabilir.
          self.queue.removeAll { $0.id == id }
          self.finish(id, .failure(BridgeError.timeout))
        }
      }
    }
  }

  /// Kuyruğu Flutter'a boşaltır — yalnız kanal kurulu ve Dart hazırken.
  /// Ana iş parçacığında çağrılır.
  private func flush() {
    guard isReady, let channel else { return }
    while !queue.isEmpty {
      let item = queue.removeFirst()
      channel.invokeMethod("addExpense", arguments: item.args) { [weak self] raw in
        self?.handleResult(item.id, raw)
      }
    }
  }

  /// Kanal cevabını [Reply]'a çevirir. Flutter'ın cevap geri çağrısı ana iş
  /// parçacığında gelir.
  private func handleResult(_ id: UUID, _ raw: Any?) {
    if let error = raw as? FlutterError {
      finish(id, .failure(BridgeError.channelFailure(error.message ?? error.code)))
      return
    }
    if let obj = raw as? NSObject, obj === FlutterMethodNotImplemented {
      // Dart host söküldü (oturum kapandı) ama `ready` bayrağı kaldı:
      // bir sonraki `ready`'ye kadar yeni istekler bekleyecek.
      isReady = false
      finish(id, .failure(BridgeError.notReady))
      return
    }
    guard let dict = raw as? [String: Any],
          let ok = dict["ok"] as? Bool
    else {
      finish(id, .failure(BridgeError.channelFailure("Beklenmeyen cevap biçimi")))
      return
    }
    let message = dict["message"] as? String ?? ""
    finish(id, .success(Reply(ok: ok, message: message)))
  }

  /// Bekleyen intent'i tek seferlik sürdürür. Ana iş parçacığında çağrılır.
  private func finish(_ id: UUID, _ result: Result<Reply, Error>) {
    guard let continuation = waiters.removeValue(forKey: id) else { return }
    continuation.resume(with: result)
  }
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_expense_intent.dart';

/// Natif taraftaki `IntentBridge.channelName` ile BİREBİR aynı.
const intentChannelName = 'co.ggtech.budgy/intents';

/// Kısayollar/Siri intent kanalı. Sözleşme (değişmez):
///
/// * Flutter → natif: `ready` — Dart tarafı dinlemeye hazır (host kurulunca
///   bir kez; sıcak yeniden başlatmada tekrar — natif taraf buna hazır).
/// * Natif → Flutter: `addExpense` (sözlük) → `{"ok": bool, "message": String}`.
const intentChannel = MethodChannel(intentChannelName);

/// Kanalın Dart ucu. Oturum açılmış ağacın kökünde durur (bkz. AuthGate):
/// depo `uid` ister, dolayısıyla "hazırız" demek ancak kullanıcı varken
/// doğru. Natif taraf `ready` gelene kadar istekleri kuyrukta bekletir
/// (soğuk başlatma), geldiği anda sırayla gönderir.
///
/// Android'de ve testte natif karşılık yok: `ready` çağrısı
/// [MissingPluginException] ile döner, yutulur — kanal yalnız iOS'ta
/// anlamlı, ama Dart kodu her platformda aynı kalsın.
class IntentChannelHost extends ConsumerStatefulWidget {
  const IntentChannelHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IntentChannelHost> createState() => _IntentChannelHostState();
}

class _IntentChannelHostState extends ConsumerState<IntentChannelHost> {
  /// Kanalın şu anki sahibi. Ağaç yeniden kurulurken (dil/para birimi
  /// değişince AuthGate'in anahtarı değişir) yeni host'un `initState`'i eski
  /// host'un `dispose`'undan ÖNCE koşar; eski host körlemesine
  /// `setMethodCallHandler(null)` deseydi yeninin kaydını silerdi.
  static _IntentChannelHostState? _owner;

  @override
  void initState() {
    super.initState();
    _owner = this;
    intentChannel.setMethodCallHandler(_onCall);
    unawaited(_announceReady());
  }

  @override
  void dispose() {
    if (_owner == this) {
      _owner = null;
      intentChannel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  Future<void> _announceReady() async {
    try {
      await intentChannel.invokeMethod<void>('ready');
    } on MissingPluginException {
      // Android / test: natif uç yok, sorun değil.
    } catch (_) {
      // Natif tarafın kurulmamış olması uygulamayı etkilememeli.
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'addExpense':
        return AddExpenseIntentHandler(ref).handle(call.arguments);
      default:
        throw MissingPluginException('${call.method} bu kanalda tanımlı değil');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

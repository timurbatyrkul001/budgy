import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/l10n.dart';

/// Başarısız gün yazmasını rapora düşüren kanca. Üretimde Crashlytics;
/// testler sahte bir kaydediciyle değiştirir (Firebase açılmadan
/// `FirebaseCrashlytics.instance` fırlar, hata yolu test edilemezdi).
typedef WorkDayErrorReporter = void Function(
  Object error,
  StackTrace stack,
  String reason,
);

final workDayErrorReporterProvider = Provider<WorkDayErrorReporter>((ref) {
  return (error, stack, reason) => unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: reason,
          fatal: false,
        ),
      );
});

/// Takvimde bir günü kaydeden/silen yazmayı çalıştırır; patlarsa
/// kullanıcıya [Strings.errorSaveFailed] şeridini gösterir ve hatayı
/// [workDayErrorReporterProvider] üzerinden raporlar. Dönüş: yazma
/// gerçekten bitti mi.
///
/// NEDEN `guardWrite` DEĞİL — bu yazmalar transaction:
///
/// `guardWrite` 4 saniyelik zaman aşımını "kaydedildi, sonra eşitlenir"
/// sayar; sıradan Firestore yazmaları için doğru, çünkü yerel kuyruğa girer
/// ve ağ gelince gider. Transaction ÖYLE DEĞİL: okumaları sunucudan yapar,
/// çevrimdışıyken kuyruğa girmez, birkaç denemeden sonra düpedüz hata
/// verir. Burada "sonra eşitlenecek" demek yalan olurdu — gün işaretlenmedi,
/// cüzdan değişmedi. O yüzden zaman aşımı yok: transaction'ın kendi
/// sonucunu bekleriz ve hata gelirse olduğu gibi söyleriz: kaydedilemedi,
/// bağlantını kontrol et, tekrar dene. Tekrar denemek güvenli — transaction
/// farkı sunucudaki değere göre hesaplar, çift sayma olmaz.
Future<bool> guardDayWrite(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String reason,
}) async {
  // Hata şeridinin dilini ve raporlayıcıyı await'ten ÖNCE al: ekran
  // kapanmışsa ref artık okunamaz.
  final str = ref.read(strProvider);
  final report = ref.read(workDayErrorReporterProvider);
  try {
    await action();
    return true;
  } catch (error, stack) {
    // Şerit gösteriyoruz ama hatayı yutmuyoruz: cüzdana dokunan bir yazma
    // neden başarısız oldu, raporda görünmeli.
    report(error, stack, reason);
    if (context.mounted) showErrorSnack(context, str.errorSaveFailed);
    return false;
  }
}

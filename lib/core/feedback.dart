import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';

/// Kullanıcıya kırmızı hata şeridi. Para yazan her işlemin başarısızlık
/// yolunda çağrılır — sessizce yutulan bir Firestore hatası, kullanıcının
/// "kaydettim" sanıp parasını yanlış takip etmesine yol açar.
void showErrorSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Bakiyeye dokunan bir yazma işlemini çalıştırır; hata olursa
/// [Strings.errorSaveFailed] şeridini gösterir.
///
/// Dönüş: işlem başarılıysa `true`. Çağıran taraf buna bakarak ekranı
/// kapatır — hata durumunda ekran açık kalır ve kullanıcı tekrar dener.
/// [reason] Crashlytics'te hangi işlemin patladığını ayırt etmeye yarar
/// ('addIncome', 'deleteTx'...).
Future<bool> guardWrite(
  BuildContext context,
  Strings str,
  Future<void> Function() action, {
  String reason = 'write',
}) async {
  try {
    await action();
    return true;
  } catch (error, stack) {
    // Kullanıcıya şerit gösteriyoruz ama hatayı yutmuyoruz: bakiyeye
    // dokunan bir yazma neden başarısız oldu, raporda görünmeli.
    unawaited(FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false));
    // await'ten sonra ekran kapanmış olabilir — showErrorSnack zaten
    // mounted kontrolü yapıyor, analyzer için burada da doğruluyoruz.
    if (context.mounted) showErrorSnack(context, str.errorSaveFailed);
    return false;
  }
}

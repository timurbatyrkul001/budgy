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

/// Nötr bilgi şeridi. Hata değil — kırmızı olmamalı: çevrimdışı kayıt
/// başarısızlık değil, yalnız gecikmiş onaydır.
void showInfoSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

/// Yazma işleminin sunucudan onay beklediği süre. Dolunca işlem
/// "başarılı ama eşitlenmemiş" sayılır — bkz. [guardWrite].
const _writeAckTimeout = Duration(seconds: 4);

/// Bakiyeye dokunan bir yazma işlemini çalıştırır; hata olursa
/// [Strings.errorSaveFailed] şeridini gösterir.
///
/// Dönüş: ekran kapatılabilirse `true`. Hata durumunda `false` döner,
/// ekran açık kalır ve kullanıcı tekrar dener.
/// [reason] Crashlytics'te hangi işlemin patladığını ayırt etmeye yarar
/// ('addIncome', 'deleteTx'...).
///
/// ZAMAN AŞIMI NEDEN VAR — ve neden zaman aşımı "hata" sayılmıyor:
///
/// Firestore çevrimdışıyken yazmanın Future'ı ne tamamlanır ne patlar;
/// ağ geri gelene kadar bekler. Zaman aşımı yokken kullanıcı metroda
/// "Kaydet"e basıp sonsuza kadar dönen bir düğmeye bakıyordu: ne şerit
/// çıkıyordu (hata yok ki), ne sayfa kapanıyordu.
///
/// Ama kayıt KAYBOLMUŞ değil: yerel kuyrukta duruyor, ekranlar onu
/// şimdiden gösteriyor ve ağ gelince sunucuya gidiyor. Bu yüzden zaman
/// aşımında "kaydedilemedi" demek düpedüz yalan olurdu — kullanıcı
/// yeniden girer ve işlem İKİZLENİR. Doğrusu: sayfayı kapat, kaydın
/// eşitleneceğini söyle.
Future<bool> guardWrite(
  BuildContext context,
  Strings str,
  Future<void> Function() action, {
  String reason = 'write',
}) async {
  try {
    await action().timeout(_writeAckTimeout);
    return true;
  } on TimeoutException {
    // Başarısızlık değil: kayıt yerel kuyrukta, ağ gelince gidecek.
    // Crashlytics'e de yazmıyoruz — çevrimdışı olmak bir arıza değil.
    if (context.mounted) showInfoSnack(context, str.savedOffline);
    return true;
  } catch (error, stack) {
    // Kullanıcıya şerit gösteriyoruz ama hatayı yutmuyoruz: bakiyeye
    // dokunan bir yazma neden başarısız oldu, raporda görünmeli.
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      ),
    );
    // await'ten sonra ekran kapanmış olabilir — showErrorSnack zaten
    // mounted kontrolü yapıyor, analyzer için burada da doğruluyoruz.
    if (context.mounted) showErrorSnack(context, str.errorSaveFailed);
    return false;
  }
}

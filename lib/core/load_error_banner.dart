import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show ProviderBase, ProviderException;

import 'ex_style.dart';
import 'l10n.dart';
import 'redesign_l10n.dart';

/// Veri akışı düştüğünde içeriğin ÜSTÜNE çizilen uyarı şeridi.
///
/// Neden şerit, neden tam ekran hata değil: Firestore yerel önbellek tutar.
/// Kural reddi, App Check ya da eksik dizin yüzünden akış düştüğünde
/// Riverpod önceki değeri korur (`AsyncError.copyWithPrevious`) — yani
/// kullanıcının elinde ÇOĞU ZAMAN gösterilecek veri vardır. Ekranı bir hata
/// sayfasının arkasına gizlemek, elimizdeki veriyi gizlemek olurdu. Şerit
/// içeriği örtmez: "bir şeyler ters gitti" der, eski veri altında durur.
///
/// Veri hiç gelmediyse (önbellek boş + ilk abonelik reddedildi) ekranlar
/// yine varsayılan boş hâllerini çizer; şerit o boşluğun "paran gitti"
/// değil "yüklenemedi" olduğunu söyler. Ekranların gerçek boş-durum
/// metinleri (`noOperations`, `notEnoughData`...) yalnız `hasValue`
/// doğruyken çizilmeli — bkz. [AsyncValue.hasValue].
///
/// [sources]: ekranın bağlı olduğu akışlar. Biri bile [AsyncValue.hasError]
/// ise şerit görünür; "Tekrar dene" düşen akışları [WidgetRef.invalidate]
/// ile yeniden açar. Hiçbiri düşmemişse hiçbir şey çizilmez — [padding]
/// dâhil, böylece çağıran yer boşluk hesabı yapmaz.
///
/// Hata metni İNSANCA: ham `[cloud_firestore/...]` kodu asla ekrana çıkmaz;
/// bkz. [loadErrorMessage].
class LoadErrorBanner extends ConsumerWidget {
  const LoadErrorBanner({
    super.key,
    required this.sources,
    this.padding = EdgeInsets.zero,
  });

  /// İzlenen akış sağlayıcıları. `StreamProvider<List<Tx>>` gibi somut
  /// tipler kovaryansla buraya sığar.
  final List<ProviderBase<AsyncValue<Object?>>> sources;

  /// Yalnız şerit görünürken uygulanan dış boşluk.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `isLoading`'e bakılmıyor, bilerek: Riverpod 3 düşen akışı kendisi
    // artan aralıkla 10 kez (~40 sn) yeniden açar ve bu süre boyunca durum
    // "hata + yükleniyor"dur. Oraya dönen gösterge koysak düğme neredeyse
    // hiç görünmezdi. Arka plandaki deneme tutarsa şerit kendiliğinden
    // kaybolur; tutmazsa düğme hep yerinde.
    final failed = <ProviderBase<AsyncValue<Object?>>>[];
    Object? firstError;
    for (final source in sources) {
      final state = ref.watch(source);
      if (!state.hasError) continue;
      failed.add(source);
      firstError ??= state.error;
    }
    if (failed.isEmpty) return const SizedBox.shrink();

    final str = ref.watch(strProvider);
    final rs = ref.watch(rsProvider);
    final message = loadErrorMessage(firstError!, str, rs);

    return Padding(
      padding: padding,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Material(
          color: Ex.red.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.cardRadius),
            side: BorderSide(color: Ex.red.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: Ex.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: Ex.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Düğme metnin altında, simge hizasında: 320dp'de uzun RU
                // metinle yan yana sığmıyordu.
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: TintChipButton(
                    key: kLoadErrorRetryKey,
                    label: rs.retry,
                    onTap: () {
                      for (final source in failed) {
                        ref.invalidate(source);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Testler için: şeritteki "Tekrar dene" düğmesi.
const kLoadErrorRetryKey = Key('load-error-retry');

/// Akış hatasını kullanıcıya söylenebilir bir cümleye çevirir.
///
/// Riverpod bir sağlayıcı zincirinde hatayı [ProviderException] ile sarar;
/// önce o açılır. Firestore `unavailable` (sunucuya ulaşılamadı) için
/// bağlantı metni, geri kalan her şey (kural reddi, dizin, App Check,
/// bilinmeyen) için genel metin: kullanıcının bu kodlarla yapabileceği bir
/// şey yok, "tekrar dene" tek eylemi.
String loadErrorMessage(Object error, Strings str, RS rs) {
  var cause = error;
  while (cause is ProviderException) {
    cause = cause.exception;
  }
  if (cause is FirebaseException && cause.code == 'unavailable') {
    return rs.saveErrOffline;
  }
  return str.errorGeneric;
}

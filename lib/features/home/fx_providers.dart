import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fx.dart';
import '../envelopes/budget_repository.dart';

/// Kullanıcının para birimi kodu — YALNIZ GÖSTERİM için.
///
/// Akış yüklenene kadar ve DÜŞTÜĞÜNDE 'TRY' döner: etiketler, simgeler ve
/// özetler boş kalmasın diye. Ama bu bir varsayım, dayanak değil. Bir KAYIT
/// bu değere dayanamaz: ana birimi tenge olan kullanıcıda akış düşmüşse
/// kart harcaması ₺'ye dondurulur ve o ayın toplamı kalıcı olarak yanlış
/// çıkar. Yazan taraf (hızlı giriş, Siri niyeti...) [knownCurrencyCodeProvider]
/// kullanır: değer bilinmiyorsa null alır ve yazmaz.
final currencyCodeProvider =
    Provider<String>((ref) => ref.watch(currencyProvider).value ?? 'TRY');

/// Ana birim GÜVENİLİR biçimde biliniyorsa kodu, değilse null.
///
/// null iki hâlde gelir ve ikisi de "yazma" demektir:
/// * akış henüz ilk değerini vermedi (bekle);
/// * akış düştü — Riverpod'un arka plan denemesi sürerken de
///   (`hasError` doğru kaldığı için) null kalır. Düşen akışın önbellekten
///   taşıdığı eski değer de kabul edilmez: kur dondurma gibi geri alınamaz
///   bir yazımın dayanağı "muhtemelen hâlâ öyle" olamaz.
///
/// Kur kuralıyla aynı ilke (`freezeToBase` / `FxUnavailable`): dayanak yoksa
/// uydurma değer ürettirmeyiz, reddederiz. Yeni kullanıcı için ayar belgesi
/// yokluğu HATA DEĞİL — depo onu 'TRY' varsayılanına çevirip değer olarak
/// verir ([BudgetRepository.watchCurrency]), burası onu olduğu gibi geçirir.
final knownCurrencyCodeProvider = Provider<String?>((ref) {
  final state = ref.watch(currencyProvider);
  if (state.hasError || !state.hasValue) return null;
  return state.requireValue;
});

/// [base] tabanlı kur tablosu: önbellek tazeyse o, değilse ağ; çevrimdışı
/// ve önbellek yoksa null. Ana ekran çipi ve çevirici bunu paylaşır.
final fxSnapshotProvider =
    FutureProvider.family<FxSnapshot?, String>((ref, base) => loadFxSnapshot(base));

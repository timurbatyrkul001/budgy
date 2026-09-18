import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fx.dart';
import '../envelopes/budget_repository.dart';

/// Kullanıcının para birimi kodu (yüklenene kadar TRY).
final currencyCodeProvider =
    Provider<String>((ref) => ref.watch(currencyProvider).value ?? 'TRY');

/// [base] tabanlı kur tablosu: önbellek tazeyse o, değilse ağ; çevrimdışı
/// ve önbellek yoksa null. Ana ekran çipi ve çevirici bunu paylaşır.
final fxSnapshotProvider =
    FutureProvider.family<FxSnapshot?, String>((ref, base) => loadFxSnapshot(base));

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../home/fx_providers.dart';
import 'currency_wallet_sheet.dart';

/// Döviz kumbaraları: hedef olmayan, arşivlenmemiş yabancı para zarfları
/// ("100 dolar kenara koydum").
///
/// Bunlar HESAP değil — hesap (`Account`) paranın çıktığı yerdir (Enpara,
/// Kaspi, nakit); kumbara ise kenara ayrılmış paradır. Ana ekranda
/// "Birikim" bölümünde, dönüştürücüde ve hızlı girişte kullanılır.
final accountEnvelopesProvider = Provider<List<Envelope>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  return envelopes
      .where((e) => e.currency != 'TRY' && !e.archived && !e.isGoal)
      .toList();
});

/// "+ Döviz cüzdanı ekle": sayfa → hemen Firestore'a yaz (ana para birimi ve
/// zaten açık dövizler listede yok). Sıra mevcut zarfların ardından.
Future<void> addCurrencyWallet(BuildContext context, WidgetRef ref) async {
  final exclude = {
    ref.read(currencyCodeProvider),
    for (final e in ref.read(accountEnvelopesProvider)) e.currency,
  };
  final draft = await showCurrencyWalletSheet(context, exclude: exclude);
  if (draft == null || !context.mounted) return;
  final rs = ref.read(rsProvider);
  final sortOrder = ref.read(envelopesProvider).value?.length ?? 0;
  await guardWrite(
    context,
    ref.read(strProvider),
    () => ref
        .read(budgetRepositoryProvider)
        .addCurrencyWallet(
          code: draft.code,
          name: walletNameFor(rs, draft.code),
          emoji: walletEmojiFor(draft.code),
          amount: draft.amount,
          sortOrder: sortOrder,
          note: rs.startingBalance,
        ),
    reason: 'addCurrencyWallet',
  );
}

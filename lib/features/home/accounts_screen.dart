import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_detail_screen.dart';
import '../envelopes/envelope_l10n.dart';
import '../space/currency_wallet_sheet.dart';
import '../transactions/journal_screen.dart';
import 'fx_providers.dart';

/// Hesap listesi: Nakit (cüzdan) + döviz kumbaraları (hedef olmayan,
/// arşivlenmemiş yabancı para zarfları).
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
    () => ref.read(budgetRepositoryProvider).addCurrencyWallet(
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

/// Hesaplar — dikey liste (başlıktaki cüzdan butonundan).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final cash = ref.watch(cashBalanceProvider).value ?? 0;
    final accounts = ref.watch(accountEnvelopesProvider);

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text(
              rs.accounts,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Ex.text,
              ),
            ),
            const SizedBox(height: 16),
            AccountRow(
              icon: Icons.payments_rounded,
              color: Ex.brand,
              title: rs.cash,
              amount: formatMoney(cash),
              onTap: () => _push(context, const JournalScreen()),
            ),
            for (final e in accounts) ...[
              const SizedBox(height: 10),
              AccountRow(
                emoji: e.emoji,
                color: Ex.amber,
                title: e.displayName(str),
                amount: formatMoneyIn(e.balance, e.currency),
                onTap: () =>
                    _push(context, EnvelopeDetailScreen(envelopeId: e.id)),
              ),
            ],
            const SizedBox(height: 10),
            ExCard(
              color: Colors.transparent,
              onTap: () => addCurrencyWallet(context, ref),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: Ex.mint),
                  const SizedBox(width: 12),
                  Text(rs.addCurrencyWallet,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Ex.mint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// Hesap satırı: squircle simge + ad + bakiye.
class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  final String title;
  final String amount;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: Ex.squircle(42),
            ),
            child: emoji != null
                ? Text(emoji!, style: const TextStyle(fontSize: 20))
                : Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Ex.text),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Ex.text),
          ),
        ],
      ),
    );
  }
}

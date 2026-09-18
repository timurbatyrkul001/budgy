import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/animated_bar.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../savings/add_funds_sheet.dart';
import '../transactions/convert_sheet.dart';
import 'calculate_budget_screen.dart';
import '../transactions/journal_screen.dart';
import '../transactions/new_transaction_sheet.dart';
import 'add_envelope_sheet.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_l10n.dart';
import '../../core/feedback.dart';

/// Onay dialogu: emoji + başlık + mesaj + Cancel / Action.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String emoji,
  required String title,
  required String body,
  required String actionLabel,
}) async {
  final str = ProviderScope.containerOf(context).read(strProvider);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.budgy;
      return Dialog(
        backgroundColor: c.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BudgyRadii.bigCard)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Icon(Icons.close, color: c.textMuted),
                ),
              ),
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.02 * 20,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 15, height: 1.4, color: c.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.text,
                        side: BorderSide(color: c.borderStrong),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(str.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// Один конверт: баланс + его история операций.
class EnvelopeDetailScreen extends ConsumerWidget {
  const EnvelopeDetailScreen({super.key, required this.envelopeId});

  final String envelopeId;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Envelope envelope) async {
    final str = ref.read(strProvider);
    final ok = await showConfirmDialog(
      context,
      emoji: '🗑️',
      title: str.deleteCatTitle,
      body: str.deleteCatBody,
      actionLabel: str.deleteWord,
    );
    if (ok && context.mounted) {
      final done = await guardWrite(context, str,
          () => ref.read(budgetRepositoryProvider).deleteEnvelope(envelope.id));
      if (done && context.mounted) Navigator.of(context).pop();
    }
  }

  /// Paylaş: zarfın özeti (ad + bakiye).
  Future<void> _share(WidgetRef ref, Envelope e) async {
    final str = ref.read(strProvider);
    await Share.share(
      '${e.emoji} ${e.displayName(str)}\n'
      '${formatMoneyIn(e.balance, e.currency)}',
    );
  }

  /// Dışa aktar: önce onay dialogu, sonra işlemleri CSV olarak paylaş.
  Future<void> _export(
      BuildContext context, WidgetRef ref, Envelope e) async {
    final str = ref.read(strProvider);
    final ok = await showConfirmDialog(
      context,
      emoji: '📥',
      title: str.exportTitle,
      body: str.exportBody,
      actionLabel: str.exportWord,
    );
    if (!ok) return;
    final list = ref.read(envelopeTxsProvider(e.id)).value ?? [];
    final buf = StringBuffer('date,type,amount,currency,note\n');
    for (final t in list) {
      final note = (t.note ?? '').replaceAll('"', "'");
      buf.writeln('${t.date.toIso8601String()},${t.type.name},'
          '${t.amount},${t.currency},"$note"');
    }
    await Share.share(buf.toString(), subject: '${e.displayName(str)}.csv');
  }

  /// Arşivle / arşivden çıkar → ana grid'de gizlenir/görünür.
  Future<void> _archive(
      BuildContext context, WidgetRef ref, Envelope e) async {
    await ref
        .read(budgetRepositoryProvider)
        .setArchived(e.id, !e.archived);
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final envelope =
        envelopes.where((e) => e.id == envelopeId).firstOrNull;
    final txs = ref.watch(envelopeTxsProvider(envelopeId));

    if (envelope == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    // Ana ekrandaki grid'le aynı tint indeksi (arşivsiz + hedefsiz sıra).
    final gridList =
        envelopes.where((e) => !e.archived && !e.isGoal).toList();
    final tintIndex =
        gridList.indexWhere((e) => e.id == envelopeId).clamp(0, 1 << 30);

    final target = envelope.targetAmount;
    final isForeign = envelope.currency != 'TRY';
    final spent =
        ref.watch(monthlySpentByEnvelopeProvider)[envelope.id] ?? 0;
    final hasBudget = !isForeign && target != null && target > 0;
    final over = hasBudget && spent > target;
    // İlerleme: döviz = biriken/hedef, TL bütçe = harcanan/bütçe.
    final double? share = isForeign
        ? (target != null && target > 0
            ? (envelope.balance / target).clamp(0.0, 1.0)
            : null)
        : (hasBudget ? (spent / target).clamp(0.0, 1.0) : null);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── nav header: geri · isim · ⋯ ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Row(
                children: [
                  _NavCircle(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    // Başlığa dokun → düzenle (ad/emoji/para birimi).
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => showEditEnvelopeSheet(context, envelope),
                      child: Text(
                        '${envelope.emoji}  ${envelope.displayName(str)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02 * 16,
                          color: c.text,
                        ),
                      ),
                    ),
                  ),
                  _MenuCircle(
                    items: [
                      (Icons.delete_outline, str.deleteWord,
                          () => _confirmDelete(context, ref, envelope)),
                      (Icons.ios_share, str.shareWord,
                          () => _share(ref, envelope)),
                      (
                        envelope.archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        envelope.archived
                            ? str.unarchiveWord
                            : str.archiveWord,
                        () => _archive(context, ref, envelope)
                      ),
                      (Icons.download_outlined, str.exportWord,
                          () => _export(context, ref, envelope)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                children: [
                  // ── hero kartı ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius:
                          BorderRadius.circular(BudgyRadii.bigCard),
                      boxShadow: c.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: c.envTintAt(tintIndex),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(envelope.emoji,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    envelope.displayName(str),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.02 * 19,
                                      color: c.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isForeign
                                        ? str.savingsTitle
                                        : str.spentThisMonth,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isForeign
                                        ? str.savingsTotalLabel
                                        : (hasBudget
                                            ? str.moneyLeft
                                            : str.spentThisMonth),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: c.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isForeign
                                        ? formatMoneyIn(envelope.balance,
                                            envelope.currency)
                                        : (hasBudget
                                            ? formatMoney((target - spent)
                                                .clamp(0, target)
                                                .toDouble())
                                            : formatMoney(spent)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.03 * 36,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                      color: over ? Colors.red : c.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (share != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: c.envTintAt(tintIndex),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '%${(share * 100).round()}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                    color:
                                        over ? Colors.red : c.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (share != null) ...[
                          const SizedBox(height: 16),
                          AnimatedBar(
                            value: share,
                            color: over ? Colors.red : c.accent,
                            background: c.track,
                            height: 10,
                            radius: 6,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isForeign
                                    ? formatMoneyIn(envelope.balance,
                                        envelope.currency)
                                    : '${formatMoney(spent)} ${str.spent}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: c.textMuted,
                                ),
                              ),
                              Text(
                                formatMoneyIn(target!,
                                    isForeign ? envelope.currency : 'TRY'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.01 * 15,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CalculateBudgetScreen(
                                    envelope: envelope),
                              ),
                            ),
                            child: Text(str.calculateBudget),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── işlemler başlığı ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        str.activityExpenses,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.02 * 16,
                          color: c.text,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM', str.localeCode)
                            .format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  txs.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text(
                      '${str.errorPrefix}: $e',
                      style: TextStyle(color: c.textMuted),
                    ),
                    data: (list) => list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(str.noOperations,
                                  style: TextStyle(color: c.textFaint)),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.surface,
                              border: Border.all(color: c.border),
                              borderRadius: BorderRadius.circular(
                                  BudgyRadii.card),
                              boxShadow: c.cardShadow,
                            ),
                            child: TxList(txs: list, shrinkWrap: true),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: envelope.currency != 'TRY'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => showAddFundsSheet(context, envelope),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(str.addFunds),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.borderStrong),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => showNewTransaction(context,
                              mode: TxMode.expense, envelopeId: envelopeId),
                          child: Text(str.expenseFromThis),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.borderStrong),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () =>
                              showConvertSheet(context, envelope),
                          child: Text(str.convertAction),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () => showNewTransaction(context,
                    mode: TxMode.expense, envelopeId: envelopeId),
                child: Text(str.expenseFromThis),
              ),
      ),
    );
  }
}

/// 40×40 yuvarlak nav butonu — yüzey + ince kenarlık + kart gölgesi.
class _NavCircle extends StatelessWidget {
  const _NavCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
          boxShadow: c.cardShadow,
        ),
        child: Icon(icon, size: 22, color: c.text),
      ),
    );
  }
}

class _MenuCircle extends StatelessWidget {
  const _MenuCircle({required this.items});

  /// (ikon, etiket, işlem) — Share · Archive · Export · Delete.
  final List<(IconData, String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: PopupMenuButton<int>(
        icon: Icon(Icons.more_horiz, size: 20, color: c.text),
        padding: EdgeInsets.zero,
        color: c.surface,
        elevation: 8,
        shadowColor: c.shadowColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BudgyRadii.card)),
        onSelected: (v) => items[v].$3(),
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius:
                          BorderRadius.circular(BudgyRadii.icon),
                    ),
                    child: Icon(items[i].$1, size: 19, color: c.text),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

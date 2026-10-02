import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../pro/pro_gate.dart';
import '../pro/pro_state.dart';
import 'recurring.dart';

/// Sıklık etiketi (Her gün / Her hafta...).
String recurrenceLabel(RS rs, Recurrence r) => switch (r) {
  Recurrence.none => rs.noRepeat,
  Recurrence.daily => rs.daily,
  Recurrence.weekly => rs.weekly,
  Recurrence.monthly => rs.monthly,
  Recurrence.yearly => rs.yearly,
};

/// Bekleyen kuralın açıklaması: ne oldu, ne yapmalı. Hesap sorunu
/// kullanıcının düzeltebileceği bir şey (arşivden çıkar / kuralı yenile);
/// kur sorunu değil (yalnız beklenir) — metinler bunu ayırır. Bilinmeyen
/// bir sebep (ileride eklenen) genel metne düşer, sessiz kalmaz.
String recurringHoldText(RS rs, String reason) => switch (reason) {
  RecurringRule.holdAccountMissing => rs.recurringHoldAccountMissing,
  RecurringRule.holdFxUnavailable => rs.recurringHoldFxUnavailable,
  _ => rs.recurringHoldGeneric,
};

/// Tekrarlayan işlemler — kural listesi + silme (cüzdan menüsünden).
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final rules = ref.watch(recurringRulesProvider).value ?? const [];

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        // Tekrarlayan işlemler Pro'ya kilitli: liste bulanık görünür,
        // kullanıcı kuralların orada durduğunu görür; kilit kartı paywall'a
        // götürür. kProEnabled kapalıyken (1.0) ProGate çocuğu olduğu gibi
        // çizer.
        child: ProGate(
          feature: ProFeature.automation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const BudgyBackButton(),
              Text(
                rs.recurringTitle,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Ex.text,
                ),
              ),
              const SizedBox(height: 16),
              if (rules.isEmpty)
                ExCard(
                  child: Text(
                    rs.recurringEmpty,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Ex.textSoft,
                    ),
                  ),
                ),
              for (final r in rules) ...[
                ExCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (r.isExpense ? Ex.amber : Ex.income)
                                  .withValues(alpha: 0.16),
                              borderRadius: Ex.squircle(40),
                            ),
                            child: Icon(
                              Icons.repeat_rounded,
                              size: 20,
                              color: r.isExpense ? Ex.amber : Ex.income,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${r.isExpense ? '−' : '+'}${formatMoneyIn(r.amount, r.currency)}'
                                        ' · ${recurrenceLabel(rs, r.freq)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Ex.text,
                                        ),
                                      ),
                                    ),
                                    // Kural bekliyor: ödeme yazılmadı. Satırda
                                    // küçük rozet, kartın altında açıklama —
                                    // kullanıcı "çalışıyor sanıp" ay kaybetmesin.
                                    if (r.holdReason != null) ...[
                                      const SizedBox(width: 6),
                                      _HoldBadge(label: rs.recurringHold),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (r.note != null && r.note!.isNotEmpty)
                                      r.note!,
                                    if (r.envelopeName != null) r.envelopeName!,
                                    if (r.accountName != null) r.accountName!,
                                    tpl(rs.nextTpl, {
                                      'date': DateFormat(
                                        'd MMM',
                                        str.localeCode,
                                      ).format(r.nextDate),
                                    }),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Ex.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: rs.delete,
                            onPressed: () => guardWrite(
                              context,
                              str,
                              () => ref
                                  .read(budgetRepositoryProvider)
                                  .deleteRecurringRule(r.id),
                              reason: 'deleteRecurring',
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Ex.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (r.holdReason != null) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _HoldNote(
                            key: ValueKey('hold-${r.id}'),
                            text: recurringHoldText(rs, r.holdReason!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Satır rozeti: "Beklemede" — kehribar, kısa, tek satır.
class _HoldBadge extends StatelessWidget {
  const _HoldBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Ex.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Ex.amber,
        ),
      ),
    );
  }
}

/// Kartın altındaki açıklama kutusu: ne oldu + ne yapmalı.
class _HoldNote extends StatelessWidget {
  const _HoldNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Ex.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.pause_circle_outline_rounded,
              size: 16,
              color: Ex.amber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Ex.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

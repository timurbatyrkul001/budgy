import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import 'recurring.dart';

/// Sıklık etiketi (Her gün / Her hafta...).
String recurrenceLabel(RS rs, Recurrence r) => switch (r) {
      Recurrence.none => rs.noRepeat,
      Recurrence.daily => rs.daily,
      Recurrence.weekly => rs.weekly,
      Recurrence.monthly => rs.monthly,
      Recurrence.yearly => rs.yearly,
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
                child: Text(rs.recurringEmpty,
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Ex.textSoft)),
              ),
            for (final r in rules) ...[
              ExCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (r.isExpense ? Ex.amber : Ex.income)
                            .withValues(alpha: 0.16),
                        borderRadius: Ex.squircle(40),
                      ),
                      child: Icon(Icons.repeat_rounded,
                          size: 20, color: r.isExpense ? Ex.amber : Ex.income),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.isExpense ? '−' : '+'}${formatMoneyIn(r.amount, r.currency)}'
                            ' · ${recurrenceLabel(rs, r.freq)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Ex.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (r.note != null && r.note!.isNotEmpty) r.note!,
                              if (r.envelopeName != null) r.envelopeName!,
                              tpl(rs.nextTpl, {
                                'date': DateFormat('d MMM', str.localeCode)
                                    .format(r.nextDate),
                              }),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: Ex.textMuted),
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
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Ex.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

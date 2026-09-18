import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../transactions/tx.dart';

/// Birikim ekranı: tüm döviz zarflarının toplamı + aydan aya ne kadar
/// eklendiği (gelir + döviz çevrimi). Home'daki döviz çipinden açılır.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final totals = ref.watch(foreignTotalsProvider); // {USD: 1700, ...}
    final txs = ref.watch(recentTxsProvider).value ?? [];

    // Son 6 ay.
    final now = DateTime.now();
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];

    // currency -> {yyyy-MM -> eklenen}. Döviz gelir + döviz çevrim girişi.
    final byCur = <String, Map<String, double>>{};
    for (final t in txs) {
      if (t.type != TxType.income || t.currency == 'TRY') continue;
      final key = DateFormat('yyyy-MM').format(t.date);
      (byCur[t.currency] ??= {})
          .update(key, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final currencies = totals.keys.toList()..sort();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text(str.savingsTitle),
      ),
      body: currencies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text(str.savingsEmpty,
                        style: TextStyle(color: c.textMuted)),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final cur in currencies) ...[
                  _CurrencyCard(
                    currency: cur,
                    total: totals[cur] ?? 0,
                    months: months,
                    perMonth: byCur[cur] ?? const {},
                    str: str,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.currency,
    required this.total,
    required this.months,
    required this.perMonth,
    required this.str,
  });

  final String currency;
  final double total;
  final List<DateTime> months;
  final Map<String, double> perMonth; // yyyy-MM -> eklenen
  final Strings str;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final values = [
      for (final m in months) perMonth[DateFormat('yyyy-MM').format(m)] ?? 0.0,
    ];
    final maxVal = values.fold<double>(0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(str.savingsTotalLabel,
              style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 2),
          Text(
            formatMoneyIn(total, currency),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 18),
          Text(str.savingsMonthlyTitle,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 12),
          // Bar grafik
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < months.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] > 0)
                          Text(
                            formatMoneyCompact(values[i]),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c.accent),
                          ),
                        const SizedBox(height: 4),
                        // Çubuk kalan yüksekliği oransal doldurur. Sabit
                        // piksel yüksekliğinde, üstteki tutar + alttaki ay
                        // etiketiyle birlikte 110px'i aşıp taşıyordu
                        // (sistem yazı boyutu büyütülünce daha da fazla).
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: maxVal > 0
                                ? (0.15 + 0.85 * (values[i] / maxVal))
                                    .clamp(0.15, 1.0)
                                : 0.15,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: values[i] > 0 ? c.accent : c.track,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM', str.localeCode).format(months[i]),
                          style: TextStyle(
                              fontSize: 11, color: c.textMuted),
                        ),
                      ],
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

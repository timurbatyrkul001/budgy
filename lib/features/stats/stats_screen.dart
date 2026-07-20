import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/palette.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope_l10n.dart';
import '../insights/analytics.dart';
import '../transactions/tx.dart';
import 'donut_chart.dart';

/// Операции выбранного месяца. Ключ — '2026-06'.
final monthTxsProvider =
    StreamProvider.family<List<Tx>, String>((ref, monthKey) {
  final start = DateTime.parse('$monthKey-01');
  final end = DateTime(start.year, start.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});

/// Операции за последние 6 месяцев — для сравнения с прошлым месяцем.
final recentTxsProvider = StreamProvider<List<Tx>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5);
  final end = DateTime(now.year, now.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});

/// İstatistik — "Sıcak Defter" stili: tür sekmeleri + kategori donut'u +
/// zarf kırılımı legend'i + döviz notu. ₺ işlemler; döviz çevirme hariç.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  TxType _mode = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);
    final monthTxs = ref.watch(monthTxsProvider(monthKey)).value ?? [];
    final recent = ref.watch(recentTxsProvider).value ?? [];
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final foreign = ref.watch(foreignTotalsProvider);
    final deltas = ref.watch(monthComparisonProvider);
    final emojiOf = {for (final e in envelopes) e.displayName(str): e.emoji};

    // Sadece seçili tür, gerçek ₺ işlemler (döviz çevirme hariç).
    bool match(Tx t) =>
        t.type == _mode &&
        !t.isConvert &&
        !t.isGoalFund &&
        t.currency == 'TRY';

    final total =
        monthTxs.where(match).fold<double>(0, (s, t) => s + t.amount);

    // Son 6 ay — aylık toplamlar (geçen ay karşılaştırması için).
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final byMonth = {for (final m in months) m: 0.0};
    for (final t in recent.where(match)) {
      final m = DateTime(t.date.year, t.date.month);
      if (byMonth.containsKey(m)) byMonth[m] = byMonth[m]! + t.amount;
    }
    final monthly = [for (final m in months) byMonth[m]!];
    // Geçen aya göre değişim (özet içgörüsü).
    final lastMonth = monthly.length >= 2 ? monthly[monthly.length - 2] : 0.0;
    final int? pct = lastMonth > 0
        ? ((total - lastMonth) / lastMonth * 100).round()
        : null;
    // Gider için azalma iyi; gelir için artış iyi.
    final bool good = _mode == TxType.income
        ? (pct != null && pct > 0)
        : (pct != null && pct < 0);

    // Bu ay kategori (zarf) kırılımı, azalan.
    final byEnv = <String, double>{};
    for (final t in monthTxs.where(match)) {
      final name = t.envelopeName ?? str.withoutEnvelope;
      byEnv[name] = (byEnv[name] ?? 0) + t.amount;
    }
    final cats = byEnv.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Donut'un ortasındaki alt yazı, seçili türe göre.
    final centerLabel = switch (_mode) {
      TxType.income => str.incomeTitle,
      TxType.transfer => str.transferTitle,
      _ => str.spentThisMonth,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            // ── başlık + ay çipi ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    str.reportTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.03 * 26,
                      color: c.text,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: c.cardShadow,
                  ),
                  child: Text(
                    toBeginningOfSentenceCase(
                      DateFormat('MMMM', str.localeCode).format(now),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── tür segmentleri ───────────────────────────────────────────
            _ModeTabs(
              mode: _mode,
              str: str,
              onChanged: (m) => setState(() => _mode = m),
            ),

            // ── geçen aya göre içgörü ─────────────────────────────────────
            if (pct != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (good ? c.accent : c.amber)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pct < 0
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 13,
                          color: good ? c.accentStrong : c.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${pct.abs()}% ${str.localeCode == 'tr' ? 'geçen aya göre' : (str.localeCode == 'ru' ? 'к прошлому месяцу' : 'vs last month')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: good ? c.accentStrong : c.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),

            // ── donut ─────────────────────────────────────────────────────
            Center(
              child: DonutChart(
                values: [for (final e in cats) e.value],
                colors: [for (var i = 0; i < cats.length; i++) vividAt(i)],
                centerTitle: formatMoney(total),
                centerSubtitle: centerLabel,
              ),
            ),
            const SizedBox(height: 10),

            // ── legend / kategori listesi ─────────────────────────────────
            Text(
              str.allCategoryExpenses,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02 * 16,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            if (cats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    str.noExpensesMonth,
                    style: TextStyle(fontSize: 13.5, color: c.textMuted),
                  ),
                ),
              )
            else
              for (var i = 0; i < cats.length; i++)
                _LegendRow(
                  color: vividAt(i),
                  name: cats[i].key,
                  amount: cats[i].value,
                  share: total > 0 ? cats[i].value / total : 0,
                  onTap: () => _showCategoryDetail(
                    context,
                    str,
                    emojiOf[cats[i].key] ?? '🗂️',
                    cats[i].key,
                    cats[i].value,
                    monthTxs
                        .where(match)
                        .where((t) =>
                            (t.envelopeName ?? str.withoutEnvelope) ==
                            cats[i].key)
                        .toList()
                      ..sort((a, b) => b.date.compareTo(a.date)),
                  ),
                ),

            // ── döviz zarfları notu ───────────────────────────────────────
            if (foreign.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface2,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(BudgyRadii.chip),
                ),
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded,
                        size: 18, color: c.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${str.savingsTitle}: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: c.textMuted,
                          ),
                          children: [
                            TextSpan(
                              text: [
                                for (final e in foreign.entries)
                                  formatMoneyIn(e.value, e.key),
                              ].join(' · '),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── içgörüler: bu ay vs geçen ay (zarf bazında) ───────────────
            if (deltas.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                str.insightsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.02 * 16,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(BudgyRadii.card),
                  boxShadow: c.cardShadow,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < deltas.length && i < 4; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.border),
                      _InsightRow(
                        delta: deltas[i],
                        tint: c.envTintAt(i),
                        str: str,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// İçgörü satırı: emoji tile + zarf adı + bu ay tutarı + değişim rozeti.
/// Harcamada artış = uyarı (amber), azalış = iyi (yeşil); geçen ay verisi
/// yoksa "yeni" hapı.
class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.delta,
    required this.tint,
    required this.str,
  });

  final CategoryDelta delta;
  final Color tint;
  final Strings str;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final pct = delta.pctChange;

    Widget trailing;
    if (pct == null) {
      // Geçen ay yoktu — bu ay yeni kategori.
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          str.newBadge,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: c.accentStrong,
          ),
        ),
      );
    } else {
      // Gider: artış kötü (amber), azalış iyi (yeşil), değişmedi nötr.
      final color = pct > 0
          ? c.amber
          : pct < 0
              ? c.accentStrong
              : c.textMuted;
      final label = pct > 0 ? '▲ +$pct%' : (pct < 0 ? '▼ ${pct.abs()}%' : '0%');
      trailing = Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(BudgyRadii.icon),
            ),
            child: Text(
              delta.envelope.emoji,
              style: const TextStyle(fontSize: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delta.envelope.displayName(str),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                if (pct != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    str.vsLastMonth,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(delta.thisMonth),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

/// Tür segmentleri: Harcama / Gelir / Transfer — track içinde beyaz hap.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs(
      {required this.mode, required this.str, required this.onChanged});

  final TxType mode;
  final Strings str;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final items = [
      (TxType.expense, str.expenseTitle),
      (TxType.income, str.incomeTitle),
      (TxType.transfer, str.transferTitle),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.track,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (final (m, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: m == mode ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: m == mode ? c.cardShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          m == mode ? FontWeight.w700 : FontWeight.w600,
                      color: m == mode ? c.text : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Legend satırı: renk noktası + isim + % payı + tutar (tabular).
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.share,
    required this.onTap,
  });

  final Color color;
  final String name;
  final double amount;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(share * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: c.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                formatMoney(amount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend satırına dokunma → kategorinin bu ayki işlemleri (alt sayfa).
void _showCategoryDetail(BuildContext context, Strings str, String emoji,
    String name, double total, List<Tx> txs) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CategoryDetailSheet(
      emoji: emoji,
      name: name,
      total: total,
      txs: txs,
      str: str,
    ),
  );
}

class _CategoryDetailSheet extends StatelessWidget {
  const _CategoryDetailSheet({
    required this.emoji,
    required this.name,
    required this.total,
    required this.txs,
    required this.str,
  });

  final String emoji;
  final String name;
  final double total;
  final List<Tx> txs;
  final Strings str;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final period =
        DateFormat('MMMM yyyy', str.localeCode).format(DateTime.now());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(BudgyRadii.chip),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      Text(
                        period,
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(total),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 24, color: c.border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: txs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final t = txs[i];
                  final title = (t.note != null && t.note!.trim().isNotEmpty)
                      ? t.note!
                      : name;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('d MMMM yyyy', str.localeCode)
                                    .format(t.date),
                                style: TextStyle(
                                    fontSize: 12.5, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatMoneyIn(t.amount, t.currency),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_avatar.dart';
import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../insights/analytics_month.dart';
import '../transactions/journal_screen.dart';
import '../transactions/tx.dart';

/// Analiz ("dark emerald"): kategori filtresi, ay seçici (geleceğe yok),
/// Harcama kartı (toplam + hafta kovaları), kategoriye göre liste, içgörü
/// kartları. Yalnız gerçek ₺ giderler (çevirme/hedef fonu/döviz hariç).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, this.initialMonthOffset = 0});

  /// Önizleme: 0 = bu ay, -1 = geçen ay.
  final int initialMonthOffset;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  /// recentTxsProvider son 6 ayı kapsar — geriye en fazla o kadar.
  static const _maxBack = 5;

  late DateTime _month;
  String? _categoryId; // null = tümü, '' = kategorisiz

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month + widget.initialMonthOffset.clamp(-_maxBack, 0));
  }

  DateTime get _current {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _canNext => _month.isBefore(_current);
  bool get _canPrev =>
      _month.isAfter(DateTime(_current.year, _current.month - _maxBack));

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _pickCategory(List<Tx> txs, Map<String, Envelope> envelopes,
      Strings str, RS rs) async {
    // Son 6 ayda geçen kategoriler + kategorisiz.
    final ids = <String?>{};
    for (final t in txs) {
      if (t.type == TxType.expense && !t.isConvert && !t.isGoalFund &&
          t.currency == 'TRY') {
        ids.add(t.envelopeId);
      }
    }
    final options = <(String?, Widget, String)>[
      (
        null,
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Ex.brand.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: const Icon(Icons.grid_view_rounded, size: 16, color: Ex.mint),
        ),
        rs.allCategories
      ),
      for (final id in ids)
        if (id == null)
          ('', const CategoryAvatar.none(size: 30), rs.noCategory)
        else if (envelopes[id] != null)
          (id, CategoryAvatar(envelope: envelopes[id], size: 30),
              envelopes[id]!.displayName(str)),
    ];
    final picked = await showExSheet<(String?,)>(
      context,
      SheetFrame(
        title: rs.byCategory,
        child: Column(
          children: [
            for (final (id, leading, name) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExCard(
                  onTap: () => Navigator.of(context).pop((id,)),
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: id == _categoryId ? Ex.mint : Ex.text)),
                      ),
                      if (id == _categoryId)
                        const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _categoryId = picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final txs = ref.watch(recentTxsProvider).value ?? const <Tx>[];
    final envelopes = {
      for (final e in ref.watch(envelopesProvider).value ?? const <Envelope>[])
        e.id: e,
    };
    final a = analyzeMonth(
      txs,
      _month,
      categoryId: _categoryId,
      envelopes: envelopes,
      nameOf: (e) => e.displayName(str),
      uncategorizedLabel: rs.noCategory,
    );
    final filterLabel = switch (_categoryId) {
      null => rs.allCategories,
      '' => rs.noCategory,
      final id => envelopes[id]?.displayName(str) ?? rs.allCategories,
    };
    final filterEmoji = switch (_categoryId) {
      null => null,
      '' => '❔',
      final id => envelopes[id]?.emoji,
    };
    final monthLabel = toBeginningOfSentenceCase(
        DateFormat('LLLL yyyy', str.localeCode).format(_month));
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── başlık ──────────────────────────────────────────────────
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GlassSquareButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop()),
                  ),
                Expanded(
                  child: Text(rs.analyticsTitle,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: Ex.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── kategori filtresi ───────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: _categoryId == null
                    ? Ex.surface
                    : Ex.brand.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickCategory(txs, envelopes, str, rs),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _categoryId == null ? Ex.border : Ex.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (filterEmoji != null)
                          Text(filterEmoji, style: const TextStyle(fontSize: 14))
                        else
                          const Icon(Icons.grid_view_rounded,
                              size: 15, color: Ex.textMuted),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(filterLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _categoryId == null
                                      ? Ex.textSoft
                                      : Ex.mint)),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: Ex.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ── ay seçici ───────────────────────────────────────────────
            Row(
              children: [
                _NavBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: _canPrev ? () => _shift(-1) : null),
                Expanded(
                  child: Text(monthLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Ex.text)),
                ),
                _NavBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: _canNext ? () => _shift(1) : null),
              ],
            ),
            const SizedBox(height: 14),
            // ── harcama kartı ───────────────────────────────────────────
            ExCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rs.spending,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Ex.textMuted)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatMoney(a.total),
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: Ex.text)),
                  ),
                  const SizedBox(height: 14),
                  _WeekBars(
                    buckets: a.buckets,
                    current: MonthAnalytics.currentBucket(_month, DateTime.now()),
                    daysInMonth: daysInMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (a.isEmpty)
              ExCard(
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_empty_rounded,
                        size: 20, color: Ex.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rs.notEnoughData,
                          style: const TextStyle(
                              fontSize: 14, height: 1.4, color: Ex.textSoft)),
                    ),
                  ],
                ),
              )
            else ...[
              // ── kategoriye göre ─────────────────────────────────────
              Text(rs.byCategory,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Ex.text)),
              const SizedBox(height: 10),
              ExCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, c) in a.byCategory.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Ex.border),
                      _CategoryRow(
                        stat: c,
                        envelope: c.envelopeId == null ? null : envelopes[c.envelopeId],
                        share: a.total <= 0 ? 0 : c.amount / a.total,
                        countLabel: c.count == 1
                            ? rs.oneExpense
                            : tpl(rs.expensesTpl, {'n': '${c.count}'}),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _CategoryTxsScreen(
                            month: _month,
                            categoryId: c.envelopeId ?? '',
                            title: c.name,
                            monthLabel: monthLabel,
                          ),
                        )),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // ── gelir kaynakları (gider dökümünden ayrı) ──────────
              if (a.incomeBySource.isNotEmpty) ...[
                Text(rs.incomeBySource,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Ex.text)),
                const SizedBox(height: 10),
                ExCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, c) in a.incomeBySource.indexed) ...[
                        if (i > 0) const Divider(height: 1, color: Ex.border),
                        _CategoryRow(
                          stat: c,
                          envelope: c.envelopeId == null ? null : envelopes[c.envelopeId],
                          share: a.incomeTotal <= 0 ? 0 : c.amount / a.incomeTotal,
                          countLabel: tpl(rs.entriesTpl, {'n': '${c.count}'}),
                          onTap: null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],
              // ── içgörüler ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _InsightCard(
                      label: rs.topCategory,
                      leading: CategoryAvatar(
                          envelope: a.topCategory!.envelopeId == null
                              ? null
                              : envelopes[a.topCategory!.envelopeId],
                          size: 36),
                      value: a.topCategory!.name,
                      sub: tpl(rs.shareTpl, {
                        'pct': '${(a.topCategory!.amount / a.total * 100).round()}',
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightCard(
                      label: rs.mostPurchases,
                      leading: CategoryAvatar(
                          envelope: a.mostPurchases!.envelopeId == null
                              ? null
                              : envelopes[a.mostPurchases!.envelopeId],
                          size: 36),
                      value: a.mostPurchases!.name,
                      sub: a.mostPurchases!.count == 1
                          ? rs.onePurchase
                          : tpl(rs.purchasesTpl,
                              {'n': '${a.mostPurchases!.count}'}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _InsightCard(
                      label: rs.busiestDay,
                      leading: const CategoryAvatar(emoji: '📅', tintSeed: 'day', size: 36),
                      value: toBeginningOfSentenceCase(DateFormat('EEEE', str.localeCode)
                          .format(DateTime(2024, 1, a.busiestWeekday ?? 1))),
                      sub: formatMoney(a.busiestWeekdayAmount),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InsightCard(
                      label: rs.avgPerDay,
                      leading: const CategoryAvatar(emoji: '⏱️', tintSeed: 'avg', size: 36),
                      value: formatMoney(a.avgPerDay),
                      sub: tpl(rs.daysTpl, {'n': '${a.daysCounted}'}),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Ex.iconRadius),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Ex.surface,
          borderRadius: BorderRadius.circular(Ex.iconRadius),
          border: Border.all(color: Ex.border),
        ),
        child: Icon(icon, size: 22, color: onTap == null ? Ex.textFaint : Ex.text),
      ),
    );
  }
}

/// Hafta kovaları çubuk grafiği: nane çubuklar, geçerli kova yeşil, boş
/// kovalar düz ama görünür.
class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.buckets,
    required this.current,
    required this.daysInMonth,
  });

  final List<double> buckets;
  final int? current;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    final maxV = buckets.fold<double>(0, (m, v) => v > m ? v : m);
    const chartH = 96.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, v) in buckets.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: chartH,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      height: maxV <= 0 ? 4 : (4 + (chartH - 4) * v / maxV),
                      decoration: BoxDecoration(
                        color: v <= 0
                            ? Ex.surfaceHi
                            : (i == current ? Ex.brand : Ex.mint.withValues(alpha: 0.55)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MonthAnalytics.bucketLabel(i, daysInMonth),
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                      color: i == current ? Ex.mint : Ex.textFaint),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.stat,
    required this.envelope,
    required this.share,
    required this.countLabel,
    required this.onTap,
  });

  final CategoryStat stat;
  final Envelope? envelope;
  final double share;
  final String countLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            envelope == null
                ? const CategoryAvatar.none(size: 38)
                : CategoryAvatar(envelope: envelope, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(stat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Ex.text)),
                      ),
                      const SizedBox(width: 8),
                      Text(formatMoney(stat.amount),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Ex.text)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: share.clamp(0, 1),
                            minHeight: 4,
                            backgroundColor: Ex.surfaceHi,
                            color: Ex.mint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(countLabel,
                          style: const TextStyle(fontSize: 11.5, color: Ex.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.label,
    required this.leading,
    required this.value,
    required this.sub,
  });

  final String label;
  final Widget leading;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Ex.textMuted)),
          const SizedBox(height: 10),
          leading,
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Ex.text)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Ex.mint)),
        ],
      ),
    );
  }
}

/// Bir kategorinin o aydaki işlemleri.
class _CategoryTxsScreen extends ConsumerWidget {
  const _CategoryTxsScreen({
    required this.month,
    required this.categoryId,
    required this.title,
    required this.monthLabel,
  });

  final DateTime month;
  final String categoryId; // '' = kategorisiz
  final String title;
  final String monthLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);
    final txs = (ref.watch(recentTxsProvider).value ?? const <Tx>[])
        .where((t) =>
            t.type == TxType.expense &&
            !t.isConvert &&
            !t.isGoalFund &&
            t.currency == 'TRY' &&
            t.date.year == month.year &&
            t.date.month == month.month &&
            (t.envelopeId ?? '') == categoryId)
        .toList();
    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Ex.text)),
            Text(monthLabel,
                style: const TextStyle(fontSize: 13, color: Ex.textMuted)),
            const SizedBox(height: 14),
            ExCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final (i, t) in txs.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Ex.border),
                    TxTile(tx: t, str: str),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

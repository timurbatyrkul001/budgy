import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_avatar.dart';
import '../../core/currency_catalog.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/preview.dart';
import '../../core/redesign_l10n.dart';
import '../budget/budget_period.dart';
import '../budget/budget_screen.dart';
import '../converter/converter_logic.dart';
import '../converter/converter_screen.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../settings/app_settings.dart';
import '../settings/settings_hub.dart';
import '../reminders/reminders_repository.dart';
import '../space/space.dart';
import '../stats/stats_screen.dart';
import '../transactions/ai_add_sheet.dart';
import '../transactions/category_sheet.dart';
import '../transactions/journal_screen.dart';
import '../transactions/quick_entry_screen.dart';
import '../transactions/receipt_scan.dart';
import '../transactions/tx.dart';
import 'budget_repository.dart';
import 'envelope_detail_screen.dart';
import 'envelope_l10n.dart';

/// Bu ay cüzdandan çıkan gerçek ₺ harcama: döviz çevirme, hedefe para
/// ayırma ve döviz işlemleri hariç (ana para birimi içeride 'TRY' kodudur,
/// simge ayarlardan gelir).
final monthSpentProvider = Provider<double>((ref) {
  return ref.watch(currentMonthTxsProvider).fold<double>(0, (sum, t) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) return sum;
    if (t.currency != 'TRY') return sum;
    return sum + t.amount;
  });
});

/// Bu ay kategorisiz ₺ giderler ("N işlem kategori bekliyor").
final uncategorizedTxsProvider = Provider<List<Tx>>((ref) {
  return ref
      .watch(currentMonthTxsProvider)
      .where(
        (t) =>
            t.type == TxType.expense &&
            !t.isConvert &&
            !t.isGoalFund &&
            t.currency == 'TRY' &&
            t.envelopeId == null,
      )
      .toList();
});

/// Ana ekran ("dark emerald"): üstte cüzdan çipi + kur + ikon butonlar,
/// sola yaslı "bu ay harcanan", bütçe kartı, yatay hesap kartları, son
/// hareketler, hatırlatma kartı; altta yüzen tara / + / mikrofon kapsülü.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Son kaydedilen işlem — "Kaydedildi · Geri al" çipi 4 sn görünür.
  String? _undoTxId;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    if (kPreviewHomeToast) _undoTxId = 'preview';
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _openQuickEntry() async {
    final result = await showQuickEntry(context);
    if (result == null || !mounted) return;
    _showUndo(result.lastTxId);
  }

  void _showUndo(String txId) {
    _undoTimer?.cancel();
    setState(() => _undoTxId = txId);
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _undoTxId = null);
    });
  }

  Future<void> _undo() async {
    final id = _undoTxId;
    _undoTimer?.cancel();
    setState(() => _undoTxId = null);
    if (id == null || id == 'preview') return;
    // deleteTx bakiyeyi de geri alır.
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).deleteTx(id),
      reason: 'undoQuickEntry',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bildirim zamanlayıcısı ana ekranda bir kez izlenir.
    ref.watch(reminderSchedulerProvider);
    final rs = ref.watch(rsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: ExBackground(
        glow: 0.46,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 120 + bottom),
                children: const [
                  _Header(),
                  SizedBox(height: 34),
                  _Hero(),
                  SizedBox(height: 14),
                  _SpendSparkline(),
                  SizedBox(height: 22),
                  _BudgetCard(),
                  _ReviewRow(),
                  SizedBox(height: 26),
                  _AccountsSection(),
                  SizedBox(height: 26),
                  _RecentSection(),
                  _NotificationsCard(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Dock(onAdd: _openQuickEntry),
            ),
            // Kaydedildi · Geri al — kapsülün hemen üstünde yüzen çip.
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom + 96,
              child: IgnorePointer(
                ignoring: _undoTxId == null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _undoTxId == null ? 0 : 1,
                  child: Center(
                    child: _UndoChip(
                      saved: rs.saved,
                      undo: rs.undo,
                      onUndo: _undo,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Kaydedildi · Geri al" çipi.
class _UndoChip extends StatelessWidget {
  const _UndoChip({
    required this.saved,
    required this.undo,
    required this.onUndo,
  });

  final String saved;
  final String undo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 12,
      shadowColor: Colors.black,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ex.borderHi),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Ex.income),
            const SizedBox(width: 8),
            Text(
              saved,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Ex.text,
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(
                foregroundColor: Ex.mint,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                undo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bu ayın birikimli harcaması — nane çizgi + yumuşak dolgu.
class _SpendSparkline extends ConsumerWidget {
  const _SpendSparkline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(currentMonthTxsProvider);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<double>.filled(days, 0);
    for (final t in txs) {
      if (t.type != TxType.expense || t.isConvert || t.isGoalFund) continue;
      if (t.currency != 'TRY') continue;
      daily[t.date.day - 1] += t.amount;
    }
    // Bugüne kadar birikimli; geri kalan günler çizilmez.
    final cumulative = <double>[];
    var sum = 0.0;
    for (var d = 0; d < now.day; d++) {
      sum += daily[d];
      cumulative.add(sum);
    }
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: cumulative, totalDays: days),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.totalDays});

  final List<double> values;
  final int totalDays;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.last <= 0 ? 1.0 : values.last;
    final stepX = size.width / (totalDays - 1).clamp(1, 1 << 30);
    double x(int i) => i * stepX;
    double y(double v) => size.height - (v / maxV) * (size.height - 4) - 2;

    final line = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(line)
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Ex.mint.withValues(alpha: 0.28),
            Ex.mint.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Ex.mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Bugünün noktası.
    canvas.drawCircle(
      Offset(x(values.length - 1), y(values.last)),
      3.5,
      Paint()..color = Ex.mint,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.totalDays != totalDays;
}

/// "N işlem kategori bekliyor" — kategorisiz ₺ giderler; dokun → liste →
/// kategori sayfası → işlemin kategorisi güncellenir.
class _ReviewRow extends ConsumerWidget {
  const _ReviewRow();

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final tx = await showExSheet<Tx>(
      context,
      Consumer(
        builder: (context, ref, _) {
          final items = ref.watch(uncategorizedTxsProvider);
          return SheetFrame(
            title: rs.reviewTitle,
            child: Column(
              children: [
                for (final t in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExCard(
                      onTap: () => Navigator.of(context).pop(t),
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          const CategoryAvatar.none(size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${t.note ?? rs.noCategory} · ${DateFormat('d MMM', str.localeCode).format(t.date)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Ex.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '−${formatMoney(t.amount)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Ex.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (tx == null || !context.mounted) return;
    final pick = await showCategorySheet(context);
    if (pick == null || !context.mounted) return;
    await guardWrite(
      context,
      str,
      () => ref
          .read(budgetRepositoryProvider)
          .setTxCategory(tx.id, envelopeId: pick.id, envelopeName: pick.name),
      reason: 'setTxCategory',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final items = ref.watch(uncategorizedTxsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final total = items.fold<double>(0, (s, t) => s + t.amount);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExCard(
        onTap: () => _open(context, ref),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Ex.amber.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(36),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 19,
                color: Ex.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tpl(rs.reviewTpl, {'n': '${items.length}'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: const TextStyle(fontSize: 12.5, color: Ex.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

// ── üst satır ─────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceInfoProvider);
    final code = ref.watch(currencyCodeProvider);
    // Kur çipleri: yıldızlı paralar (en fazla 2), yoksa USD/EUR.
    final chips = dashboardCurrencies(
      ref.watch(starredCurrenciesProvider),
      code,
    );
    final snap = ref.watch(fxSnapshotProvider(code)).value;
    final compactWallet = chips.length > 1;

    // Cüzdan çipi solda, kur + istatistik + hesaplar sağ kenara yaslı.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: GlassChip(
            padding: const EdgeInsets.fromLTRB(5, 0, 8, 0),
            onTap: () => _push(context, const SettingsHubScreen()),
            child: Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpaceAvatar(space: space, size: 30),
                  // İki kur çipi varken ad gizlenir — dar ekranda yer açar.
                  if (!compactWallet) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        space.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Ex.text,
                        ),
                      ),
                    ),
                  ],
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Ex.onGlowMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kur çipleri: iki çipte bayrak gizlenir; dar ekranda son çare
              // olarak küçülür (taşma yok).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in chips) ...[
                        const SizedBox(width: 8),
                        GlassChip(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onTap: () =>
                              _push(context, const CurrencyConverterScreen()),
                          child: Row(
                            children: [
                              if (!compactWallet) ...[
                                Text(
                                  flagFor(c),
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                Text(
                                  c,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Ex.onGlowMuted,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                switch (priceInMain(snap, c)) {
                                  final p? => formatRate(p),
                                  null => '—',
                                },
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Ex.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bütçe · Analiz (Hesaplar: "Tümü" ve cüzdan menüsünden).
              GlassSquareButton(
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => _push(context, const BudgetScreen()),
              ),
              const SizedBox(width: 8),
              GlassSquareButton(
                icon: Icons.bar_chart_rounded,
                onTap: () => _push(context, const StatsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── bu ay harcanan ────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final code = ref.watch(strProvider).localeCode;
    final spent = ref.watch(monthSpentProvider);
    // Bağımsız ay adı (LLLL): TR/EN büyük harfle, RU «за сентябрь» küçük.
    final month = DateFormat('LLLL', code).format(DateTime.now());
    final label = tpl(rs.spentInTpl, {
      'month': code == 'ru' ? month.toLowerCase() : _cap(month),
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Ex.onGlowMuted,
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: spent),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(v),
                style: const TextStyle(
                  fontSize: 46,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.6,
                  color: Ex.text,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── bütçe ─────────────────────────────────────────────────────────────────

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final settings = ref.watch(budgetSettingsProvider);

    if (settings == null) {
      return ExCard(
        onTap: () => _push(context, const BudgetScreen()),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ex.brand.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(40),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 21,
                color: Ex.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rs.monthlyBudget,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rs.budgetEmpty,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Ex.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TintChipButton(
                    label: rs.setBudget,
                    onTap: () => _push(context, const BudgetScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Seçili döneme göre (haftalık/aylık) harcama ve kalan gün.
    final budget = settings.amount;
    final spent = ref.watch(periodSpentProvider);
    final left = budget - spent;
    final over = left < 0;
    final daysLeft = ref.watch(budgetWindowProvider).daysLeft(DateTime.now());

    return ExCard(
      onTap: () => _push(context, const BudgetScreen()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  periodLabel(rs, settings.period),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ex.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tpl(rs.daysLeftTpl, {'n': '$daysLeft'}),
                style: const TextStyle(fontSize: 12, color: Ex.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tpl(over ? rs.overTpl : rs.leftTpl, {
              'amount': formatMoney(left.abs()),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: over ? Ex.red : Ex.text,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 1 : (spent / budget).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Ex.surfaceHi,
              color: over ? Ex.red : Ex.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tpl(rs.ofTpl, {
              'spent': formatMoney(spent),
              'total': formatMoney(budget),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Ex.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── bölüm başlığı ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Ex.text,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Ex.mint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── hesaplar (yatay) ──────────────────────────────────────────────────────

class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final cash = ref.watch(cashBalanceProvider).value ?? 0;
    final accounts = ref.watch(accountEnvelopesProvider);

    final cards = <Widget>[
      _AccountCard(
        icon: Icons.payments_rounded,
        color: Ex.brand,
        title: rs.cash,
        amount: formatMoney(cash),
        onTap: () => _push(context, const JournalScreen()),
      ),
      for (final e in accounts)
        _AccountCard(
          emoji: e.emoji,
          color: Ex.amber,
          title: e.displayName(str),
          amount: formatMoneyIn(e.balance, e.currency),
          onTap: () => _push(context, EnvelopeDetailScreen(envelopeId: e.id)),
        ),
      _AddAccountCard(onTap: () => addCurrencyWallet(context, ref)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.accounts,
          action: rs.seeAll,
          onAction: () => _push(context, const AccountsScreen()),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
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
    return SizedBox(
      width: 150,
      child: ExCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: Ex.squircle(28),
                  ),
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 14))
                      : Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Ex.textSoft,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Ex.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAccountCard extends ConsumerWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return SizedBox(
      width: 96,
      child: ExCard(
        color: Colors.transparent,
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 24, color: Ex.mint),
            const SizedBox(height: 4),
            Text(
              rs.addAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Ex.mint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── son hareketler ────────────────────────────────────────────────────────

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final txs = (ref.watch(journalProvider).value ?? const <Tx>[])
        .where((t) => !t.isGoalFund)
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.recent,
          action: txs.isEmpty ? null : rs.seeAll,
          onAction: () => _push(context, const JournalScreen()),
        ),
        if (txs.isEmpty)
          ExCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              rs.recentEmpty,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Ex.textSoft,
              ),
            ),
          )
        else
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
    );
  }
}

// ── hatırlatma kartı ──────────────────────────────────────────────────────

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    // reminderSchedulerProvider ayarı görünce planlar ve izin ister.
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).saveProfile({
        'dailyReminder': true,
        'dailyHour': 21,
      }),
      reason: 'dailyReminder',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    if (ref.watch(dailyReminderProvider).enabled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ExCard(
        onTap: () => _enable(context, ref),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ex.amber.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(40),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                size: 21,
                color: Ex.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rs.dailyReminder,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rs.dailyReminderSub,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Ex.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── alt eylem kapsülü ─────────────────────────────────────────────────────

class _Dock extends ConsumerWidget {
  const _Dock({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 34, 0, bottom + 12),
      // Altta kayan içeriği kapsülün arkasında karart.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00070A09), Color(0xF2070A09)],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: Ex.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Ex.borderHi),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                size: 46,
                color: Ex.surfaceHi,
                onTap: () => startReceiptScan(context, ref),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  size: 22,
                  color: Ex.text,
                ),
              ),
              const SizedBox(width: 26),
              _DockButton(
                size: 56,
                color: Ex.brand,
                onTap: onAdd,
                child: const Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: Ex.onBrand,
                ),
              ),
              const SizedBox(width: 26),
              _DockButton(
                size: 46,
                color: Ex.surfaceHi,
                onTap: () => showAiAdd(context),
                child: const Icon(Icons.mic_rounded, size: 22, color: Ex.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.size,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final double size;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

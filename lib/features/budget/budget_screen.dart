import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ai/budget_advisor.dart';
import '../../core/calc.dart';
import '../../core/category_avatar.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../settings/app_settings.dart';
import 'auto_split.dart';
import 'budget_period.dart';
import 'budget_ring.dart';

/// Bütçe ekranı: ayar yoksa boş durum (+ "Bütçe oluştur"), varsa dönem
/// özeti + kategori limitleri + düzenle/kaldır.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(budgetSettingsProvider);
    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: settings == null
            ? const _EmptyState()
            : _Overview(settings: settings),
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// Dönem etiketi: "Haftalık bütçe" / "Aylık bütçe".
String periodLabel(RS rs, BudgetPeriod p) =>
    p == BudgetPeriod.weekly ? rs.weeklyBudget : rs.monthlyBudget;

/// Gün adı (Pzt, Sal...) — haftalık başlangıç seçici için.
String weekdayShort(int weekday, String localeCode) =>
    DateFormat('E', localeCode).format(DateTime(2024, 1, weekday));

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BudgyBackButton(),
          const Spacer(),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Ex.brand.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(76),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 36, color: Ex.mint),
            ),
          ),
          const SizedBox(height: 18),
          Text(rs.noBudget,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Ex.text)),
          const SizedBox(height: 8),
          Text(rs.noBudgetSub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.4, color: Ex.textSoft)),
          const Spacer(),
          PrimaryButton(
            label: rs.createBudget,
            onTap: () => _push(context, const BudgetAmountStep()),
          ),
        ],
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.settings});

  final BudgetSettings settings;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final repo = ref.read(budgetRepositoryProvider);
    final envelopes = ref.read(allocatableEnvelopesProvider);
    await guardWrite(context, str, () async {
      await repo.saveProfile(BudgetSettings.cleared);
      for (final e in envelopes) {
        if (e.targetAmount != null) await repo.setTarget(e.id, null);
      }
    }, reason: 'removeBudget');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final spent = ref.watch(periodSpentProvider);
    final window = ref.watch(budgetWindowProvider);
    final byEnv = ref.watch(periodSpentByEnvelopeProvider);
    final envelopes = ref
        .watch(allocatableEnvelopesProvider)
        .where((e) => (e.targetAmount ?? 0) > 0)
        .toList();
    final left = settings.amount - spent;
    final over = left < 0;
    final daysLeft = window.daysLeft(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const BudgyBackButton(),
        Text(rs.budgetTitle,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Ex.text)),
        const SizedBox(height: 16),
        ExCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(periodLabel(rs, settings.period),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Ex.textMuted)),
                  ),
                  Text(tpl(rs.daysLeftTpl, {'n': '$daysLeft'}),
                      style:
                          const TextStyle(fontSize: 12, color: Ex.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  BudgetRing(
                    value: settings.amount <= 0 ? 0 : spent / settings.amount,
                    over: over,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tpl(over ? rs.overTpl : rs.leftTpl,
                              {'amount': formatMoney(left.abs())}),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: over ? Ex.red : Ex.text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tpl(rs.spentOfTpl, {
                            'spent': formatMoney(spent),
                            'total': formatMoney(settings.amount),
                          }),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Ex.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TintChipButton(
                      label: rs.editBudget,
                      onTap: () =>
                          _push(context, BudgetAmountStep(initial: settings)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TintChipButton(
                      label: rs.categoryBudgets,
                      onTap: () => _push(
                          context, BudgetCategoriesStep(settings: settings)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (envelopes.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(rs.categoryBudgets,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Ex.text)),
          const SizedBox(height: 10),
          for (final e in envelopes) ...[
            _CategoryProgressRow(
              envelope: e,
              name: e.displayName(str),
              spent: byEnv[e.id] ?? 0,
              limit: e.targetAmount!,
              rs: rs,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _remove(context, ref),
          child: Text(rs.removeBudget,
              style: const TextStyle(color: Ex.red, fontSize: 15)),
        ),
      ],
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.envelope,
    required this.name,
    required this.spent,
    required this.limit,
    required this.rs,
  });

  final Envelope envelope;
  final String name;
  final double spent;
  final double limit;
  final RS rs;

  @override
  Widget build(BuildContext context) {
    final over = spent > limit;
    return ExCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(envelope: envelope, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Ex.text)),
              ),
              const SizedBox(width: 8),
              Text(
                tpl(rs.spentOfTpl,
                    {'spent': formatMoney(spent), 'total': formatMoney(limit)}),
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: over ? Ex.red : Ex.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (spent / limit).clamp(0, 1),
              minHeight: 5,
              backgroundColor: Ex.surfaceHi,
              color: over ? Ex.red : Ex.mint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1) tutar adımı ────────────────────────────────────────────────────────

/// Genel bütçe tutarı: düz rakam klavyesi (limit, hesap değil), dönem
/// anahtarı (haftalık/aylık), haftalıkta hafta başı günü. "Devam" →
/// kategori adımı; kayıt orada yapılır.
class BudgetAmountStep extends ConsumerStatefulWidget {
  const BudgetAmountStep({super.key, this.initial, this.initialPeriod});

  final BudgetSettings? initial;

  /// Önizleme için başlangıç dönemi.
  final BudgetPeriod? initialPeriod;

  @override
  ConsumerState<BudgetAmountStep> createState() => _BudgetAmountStepState();
}

class _BudgetAmountStepState extends ConsumerState<BudgetAmountStep> {
  late String _expr = switch (widget.initial?.amount) {
    final a? => a % 1 == 0 ? a.toStringAsFixed(0) : a.toString(),
    null => '',
  };
  late BudgetPeriod _period =
      widget.initialPeriod ?? widget.initial?.period ?? BudgetPeriod.weekly;
  late int _weekStart = widget.initial?.weekStart ?? DateTime.monday;

  double get _amount => evalExpression(_expr);

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() => _expr = appendKey(_expr, k));
  }

  Future<void> _pickWeekStart() async {
    final rs = ref.read(rsProvider);
    final code = ref.read(strProvider).localeCode;
    final picked = await showExSheet<int>(
      context,
      SheetFrame(
        title: rs.weekStartLabel,
        child: Column(
          children: [
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExCard(
                  onTap: () => Navigator.of(context).pop(d),
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEEE', code).format(DateTime(2024, 1, d)),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: d == _weekStart ? Ex.mint : Ex.text),
                        ),
                      ),
                      if (d == _weekStart)
                        const Icon(Icons.check_rounded,
                            size: 20, color: Ex.mint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _weekStart = picked);
  }

  void _continue() {
    final settings = BudgetSettings(
      amount: _amount,
      period: _period,
      weekStart: _weekStart,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => BudgetCategoriesStep(settings: settings)));
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final txs = ref.watch(recentTxsProvider).value ?? const [];
    final days = _period == BudgetPeriod.weekly ? 7 : 30;
    final recent = totalInLastDays(txs, days);
    final decimal = str.localeCode == 'tr' || str.localeCode == 'ru' ? ',' : '.';
    final shown = (_expr.isEmpty ? '0' : _expr).replaceAll('.', decimal);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassSquareButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(rs.budgetTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Ex.text)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rs.budgetAmountHint,
                        style: const TextStyle(
                            fontSize: 15, color: Ex.textSoft)),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: shown,
                          style: const TextStyle(
                              fontSize: 54,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              color: Ex.text),
                          children: [
                            TextSpan(
                                text: ' $currencySymbol',
                                style: const TextStyle(color: Ex.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tpl(rs.lastDaysTpl,
                          {'n': '$days', 'amount': formatMoney(recent)}),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Ex.mint),
                    ),
                  ],
                ),
              ),
            ),
            // Dönem + hafta başı.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  // Dar ekranda (ve uzun çevirilerde) iki parça da esner.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _Segmented(
                        left: rs.weeklyPeriod,
                        right: rs.monthlyPeriod,
                        leftSelected: _period == BudgetPeriod.weekly,
                        onChanged: (weekly) => setState(() => _period = weekly
                            ? BudgetPeriod.weekly
                            : BudgetPeriod.monthly),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_period == BudgetPeriod.weekly)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TintChipButton(
                          label: tpl(rs.weekStartTpl, {
                            'day': weekdayShort(_weekStart, str.localeCode),
                          }),
                          onTap: _pickWeekStart,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _PlainKeypad(
              decimal: decimal,
              oneTwoThreeOnTop: ref.watch(keypadOneTwoThreeOnTopProvider),
              onKey: (k) => _key(k == decimal ? '.' : k),
              onBackspace: () => setState(() => _expr = backspace(_expr)),
              onClear: () => setState(() => _expr = ''),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 10 + bottom),
              child: Column(
                children: [
                  PrimaryButton(
                    label: rs.continueLabel,
                    onTap: _amount > 0 ? _continue : null,
                  ),
                  const SizedBox(height: 8),
                  Text(rs.skipNote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, color: Ex.textFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İki seçenekli anahtar (Haftalık | Aylık).
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool on, bool isLeft) => GestureDetector(
          onTap: () => onChanged(isLeft),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: on ? Ex.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: on ? Ex.onBrand : Ex.textSoft)),
          ),
        );
    // Sabit yükseklik yok: "y" gibi kuyruklu harfler kırpılmasın.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Ex.surface,
        borderRadius: BorderRadius.circular(Ex.iconRadius),
        border: Border.all(color: Ex.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(left, leftSelected, true),
          seg(right, !leftSelected, false),
        ],
      ),
    );
  }
}

/// Operatörsüz klavye: 7 8 9 / 4 5 6 / 1 2 3 / , 0 ⌫.
class _PlainKeypad extends StatelessWidget {
  const _PlainKeypad({
    required this.decimal,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    this.oneTwoThreeOnTop = false,
  });

  final String decimal;
  final bool oneTwoThreeOnTop;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rows = oneTwoThreeOnTop
        ? [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            [decimal, '0', '⌫'],
          ]
        : [
            ['7', '8', '9'],
            ['4', '5', '6'],
            ['1', '2', '3'],
            [decimal, '0', '⌫'],
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final (i, k) in row.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: Ex.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Ex.iconRadius),
                          side: const BorderSide(color: Ex.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: k == '⌫' ? onBackspace : () => onKey(k),
                          onLongPress: k == '⌫' ? onClear : null,
                          child: SizedBox(
                            height: 48,
                            child: Center(
                              child: k == '⌫'
                                  ? const Icon(Icons.backspace_outlined,
                                      size: 20, color: Ex.textSoft)
                                  : Text(k,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Ex.text)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 2) kategori adımı ─────────────────────────────────────────────────────

/// Kategori limitleri: "%N dağıtıldı" + kalan + çubuk; "Öner" geçmişe göre
/// dağıtır (anahtar varsa Haiku inceltir — anahtarsız da tam çalışır);
/// her harcama kategorisi için düzenlenebilir tutar. Kaydet / Atla ikisi
/// de genel bütçeyi yazar.
class BudgetCategoriesStep extends ConsumerStatefulWidget {
  const BudgetCategoriesStep({
    super.key,
    required this.settings,
    this.autoSuggest = false,
  });

  final BudgetSettings settings;

  /// Önizleme: açılışta öneriyi uygula.
  final bool autoSuggest;

  @override
  ConsumerState<BudgetCategoriesStep> createState() =>
      _BudgetCategoriesStepState();
}

class _BudgetCategoriesStepState extends ConsumerState<BudgetCategoriesStep> {
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;
  bool _suggesting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSuggest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _suggest());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(Envelope e) => _controllers.putIfAbsent(
        e.id,
        () => TextEditingController(
          text: switch (e.targetAmount) {
            final t? when t > 0 =>
              t % 1 == 0 ? t.toStringAsFixed(0) : t.toString(),
            _ => '',
          },
        )..addListener(() => setState(() {})),
      );

  double _allocated(List<Envelope> envelopes) => envelopes.fold<double>(
      0, (s, e) => s + (parseAmount(_ctrl(e).text) ?? 0));

  Future<void> _suggest() async {
    if (_suggesting) return;
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final envelopes = ref.read(allocatableEnvelopesProvider);
    final txs = ref.read(recentTxsProvider).value ?? const [];
    final ids = {for (final e in envelopes) e.id};
    final history = {
      for (final e in spentInLastDays(txs, 60).entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
    var draft = autoSplit(total: widget.settings.amount, history: history);
    if (draft.isEmpty) {
      showErrorSnack(context, rs.notEnoughData);
      return;
    }
    setState(() => _suggesting = true);
    draft = await BudgetAdvisor.refine(
      total: widget.settings.amount,
      draft: draft,
      names: {for (final e in envelopes) e.id: e.displayName(str)},
      languageCode: str.localeCode,
    );
    if (!mounted) return;
    setState(() {
      _suggesting = false;
      for (final e in envelopes) {
        final v = draft[e.id];
        _ctrl(e).text = v == null || v <= 0
            ? ''
            : (v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2));
      }
    });
  }

  Future<void> _save({required bool skipCategories}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    final envelopes = ref.read(allocatableEnvelopesProvider);
    final ok = await guardWrite(context, str, () async {
      await repo.saveProfile(widget.settings.toProfile());
      if (skipCategories) return;
      for (final e in envelopes) {
        final v = parseAmount(_ctrl(e).text);
        final current = e.targetAmount;
        if (v == current || (v == null && (current ?? 0) <= 0)) continue;
        await repo.setTarget(e.id, v);
      }
    }, reason: 'saveBudget');
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final envelopes = ref.watch(allocatableEnvelopesProvider);
    final txs = ref.watch(recentTxsProvider).value ?? const [];
    final days = widget.settings.period == BudgetPeriod.weekly ? 7 : 30;
    final recent = spentInLastDays(txs, days);
    final total = widget.settings.amount;
    final allocated = _allocated(envelopes);
    final pct = total <= 0 ? 0 : (allocated / total * 100).round();
    final left = total - allocated;
    final over = left < 0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassSquareButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(rs.categoryBudgets,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Ex.text)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  ExCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(tpl(rs.allocatedTpl, {'pct': '$pct'}),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Ex.text)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              over
                                  ? rs.overAllocated
                                  : tpl(rs.leftTpl,
                                      {'amount': formatMoney(left)}),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: over ? Ex.red : Ex.mint),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: total <= 0 ? 0 : (allocated / total).clamp(0, 1),
                            minHeight: 6,
                            backgroundColor: Ex.surfaceHi,
                            color: over ? Ex.red : Ex.brand,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(rs.suggestHint,
                            style: const TextStyle(
                                fontSize: 13, color: Ex.textMuted)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TintChipButton(
                            label: _suggesting ? '…' : rs.suggest,
                            onTap: envelopes.isEmpty ? () {} : _suggest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (envelopes.isEmpty)
                    ExCard(
                      child: Text(rs.noCategoriesYet,
                          style: const TextStyle(
                              fontSize: 14, height: 1.4, color: Ex.textSoft)),
                    ),
                  for (final e in envelopes) ...[
                    _CategoryLimitRow(
                      envelope: e,
                      name: e.displayName(str),
                      subtitle: tpl(rs.lastDaysTpl, {
                        'n': '$days',
                        'amount': formatMoney(recent[e.id] ?? 0),
                      }),
                      controller: _ctrl(e),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 10 + bottom),
              child: Column(
                children: [
                  PrimaryButton(
                    label: rs.save,
                    onTap: _saving ? null : () => _save(skipCategories: false),
                  ),
                  const SizedBox(height: 2),
                  GhostButton(
                      label: rs.skip,
                      onTap: () => _save(skipCategories: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLimitRow extends StatelessWidget {
  const _CategoryLimitRow({
    required this.envelope,
    required this.name,
    required this.subtitle,
    required this.controller,
  });

  final Envelope envelope;
  final String name;
  final String subtitle;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          CategoryAvatar(envelope: envelope, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Ex.text)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Ex.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Ex.text),
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                fillColor: Ex.surfaceHi,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                suffixText: currencySymbol,
                suffixStyle:
                    const TextStyle(fontSize: 13, color: Ex.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

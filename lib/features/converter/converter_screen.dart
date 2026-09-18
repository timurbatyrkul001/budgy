import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc.dart';
import '../../core/currency_catalog.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../settings/app_settings.dart';
import 'converter_logic.dart';
import 'currency_picker_screen.dart';

/// Döviz çevirici: satırlar (yıldız · bayrak + kod ▾ · tutar), "+" ile
/// satır (en fazla 6, en az 2), altta operatörsüz tuş takımı. Dokunulan
/// satır giriş satırıdır; yazdıkça diğerleri anında hesaplanır. Yıldız →
/// ana ekran kur çipi (en fazla 2). Katalogdan seçim cüzdan YARATMAZ.
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({
    super.key,
    this.initialRows,
    this.initialExpression = '',
  });

  /// Önizleme/test: başlangıç satırları ve tutar.
  final List<String>? initialRows;
  final String initialExpression;

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends ConsumerState<CurrencyConverterScreen> {
  List<String>? _rows;
  int _input = 0;
  late String _expr = widget.initialExpression;

  List<String> _initialRows(String main) {
    final List<String> saved =
        widget.initialRows ?? ref.read(converterRowsProvider);
    final rows = saved.where(isCatalogCurrency).toList();
    if (rows.length >= kConverterMinRows) return rows.take(kConverterMaxRows).toList();
    return [main, main == 'USD' ? 'EUR' : 'USD'];
  }

  List<String> _preferred() {
    final main = ref.read(currencyCodeProvider);
    final wallets = ref.read(accountEnvelopesProvider).map((e) => e.currency);
    return [main, ...wallets, ...ref.read(recentCurrenciesProvider)];
  }

  void _persistRows(List<String> rows) {
    // Yalnız kolaylık: bir sonraki açılışta aynı satırlar.
    ref.read(budgetRepositoryProvider).saveProfile({'converterRows': rows});
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() => _expr = appendKey(_expr, k));
  }

  void _add() {
    final rs = ref.read(rsProvider);
    final next = addRow(_rows!, _preferred());
    if (next == null) {
      showErrorSnack(context, tpl(rs.daysTpl, {'n': '$kConverterMaxRows'}));
      return;
    }
    setState(() => _rows = next);
    _persistRows(next);
  }

  void _remove(int i) {
    final next = removeRow(_rows!, i);
    if (next == null) return;
    setState(() {
      _rows = next;
      if (_input >= next.length) _input = next.length - 1;
    });
    _persistRows(next);
  }

  Future<void> _pick(int i) async {
    final rows = _rows!;
    final code = await showCurrencyPickerScreen(
      context,
      exclude: {for (final (j, c) in rows.indexed) if (j != i) c},
      selected: rows[i],
    );
    if (code == null || !mounted) return;
    final next = [...rows]..[i] = code;
    setState(() => _rows = next);
    _persistRows(next);
    final recent = pushRecent(ref.read(recentCurrenciesProvider), code);
    ref.read(budgetRepositoryProvider).saveProfile({'recentCurrencies': recent});
  }

  Future<void> _star(String code) async {
    final rs = ref.read(rsProvider);
    final next = toggleStar(ref.read(starredCurrenciesProvider), code);
    if (next == null) {
      showErrorSnack(context, rs.starLimit);
      return;
    }
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).saveProfile({'starredCurrencies': next}),
      reason: 'starCurrency',
    );
  }

  Future<void> _rowMenu(int i) async {
    final rs = ref.read(rsProvider);
    if (_rows!.length <= kConverterMinRows) return;
    final remove = await showExSheet<bool>(
      context,
      SheetFrame(
        title: catalogCurrencyName(_rows![i]),
        child: ExCard(
          onTap: () => Navigator.of(context).pop(true),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 20, color: Ex.red),
              const SizedBox(width: 12),
              Text(rs.removeRow,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Ex.red)),
            ],
          ),
        ),
      ),
    );
    if (remove == true) _remove(i);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final main = ref.watch(currencyCodeProvider);
    final rows = _rows ??= _initialRows(main);
    final snapAsync = ref.watch(fxSnapshotProvider(main));
    final snap = snapAsync.value;
    final starred = ref.watch(starredCurrenciesProvider);
    final amount = evalExpression(_expr);
    final decimal = str.localeCode == 'tr' || str.localeCode == 'ru' ? ',' : '.';
    final bottom = MediaQuery.paddingOf(context).bottom;
    final canRemove = rows.length > kConverterMinRows;

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
                    child: Text(rs.converterTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                  ),
                  GlassSquareButton(
                    icon: Icons.add_rounded,
                    onTap: rows.length >= kConverterMaxRows ? () {} : _add,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  snap == null
                      ? (snapAsync.isLoading ? '…' : rs.ratesOffline)
                      : ratesUpdatedLabel(rs, snap.fetchedAt, DateTime.now()),
                  style: TextStyle(
                      fontSize: 12,
                      color: snap == null && !snapAsync.isLoading
                          ? Ex.amber
                          : Ex.textFaint),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                children: [
                  for (final (i, code) in rows.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: ValueKey('row-$code'),
                        direction: canRemove
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        onDismissed: (_) => _remove(i),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 18),
                          decoration: BoxDecoration(
                            color: Ex.red.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(Ex.cardRadius),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Ex.red),
                        ),
                        child: _ConverterRow(
                          code: code,
                          input: i == _input,
                          starred: starred.contains(code),
                          starEnabled:
                              starred.contains(code) || starred.length < kMaxStarred,
                          amount: i == _input
                              ? null
                              : convertAmount(amount, rows[_input], code, snap),
                          expr: (_expr.isEmpty ? '0' : _expr).replaceAll('.', decimal),
                          noRates: snap == null,
                          onTap: () => setState(() => _input = i),
                          onLongPress: canRemove ? () => _rowMenu(i) : null,
                          onPick: () => _pick(i),
                          onStar: () => _star(code),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(rs.starHint,
                        style: const TextStyle(fontSize: 12, color: Ex.textFaint)),
                  ),
                ],
              ),
            ),
            _ConverterKeypad(
              decimal: decimal,
              oneTwoThreeOnTop: ref.watch(keypadOneTwoThreeOnTopProvider),
              onKey: (k) => _key(k == decimal ? '.' : k),
              onBackspace: () => setState(() => _expr = backspace(_expr)),
              onClear: () => setState(() => _expr = ''),
              bottomInset: bottom,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConverterRow extends StatelessWidget {
  const _ConverterRow({
    required this.code,
    required this.input,
    required this.starred,
    required this.starEnabled,
    required this.amount,
    required this.expr,
    required this.noRates,
    required this.onTap,
    required this.onPick,
    required this.onStar,
    this.onLongPress,
  });

  final String code;
  final bool input;
  final bool starred;
  final bool starEnabled;
  final double? amount; // giriş satırında null
  final String expr;
  final bool noRates;
  final VoidCallback onTap;
  final VoidCallback onPick;
  final VoidCallback onStar;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = input
        ? expr
        : amount == null
            ? '—'
            : formatConverted(amount!, code);
    return Material(
      color: input ? Ex.brand.withValues(alpha: 0.12) : Ex.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ex.cardRadius),
        side: BorderSide(color: input ? Ex.glassBorder : Ex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: starEnabled ? onStar : null,
                icon: Icon(
                  starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: starred
                      ? Ex.amber
                      : (starEnabled ? Ex.textMuted : Ex.textFaint),
                ),
              ),
              InkWell(
                onTap: onPick,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(flagFor(code), style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(code,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: Ex.text)),
                      const Icon(Icons.expand_more_rounded, size: 18, color: Ex.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: input ? Ex.mint : (noRates ? Ex.textFaint : Ex.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Operatörsüz tuş takımı: rakamlar, ondalık, geri (uzun basış siler).
class _ConverterKeypad extends StatelessWidget {
  const _ConverterKeypad({
    required this.decimal,
    required this.oneTwoThreeOnTop,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    required this.bottomInset,
  });

  final String decimal;
  final bool oneTwoThreeOnTop;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final digits = oneTwoThreeOnTop
        ? [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']]
        : [['7', '8', '9'], ['4', '5', '6'], ['1', '2', '3']];
    final rows = [...digits, [decimal, '0', '⌫']];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 10 + bottomInset),
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
                            height: 46,
                            child: Center(
                              child: k == '⌫'
                                  ? const Icon(Icons.backspace_outlined,
                                      size: 20, color: Ex.textSoft)
                                  : Text(k,
                                      style: const TextStyle(
                                          fontSize: 21,
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

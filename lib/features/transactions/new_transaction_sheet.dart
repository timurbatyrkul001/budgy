import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/add_envelope_sheet.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';

enum TxMode { expense, income, transfer }

/// Единый экран добавления операции: Расход / Доход / Перевод.
/// Открывается «плюсом» с главной, либо из конверта с предвыбором.
Future<void> showNewTransaction(
  BuildContext context, {
  TxMode mode = TxMode.expense,
  String? envelopeId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _NewTransactionSheet(initialMode: mode, initialEnvelopeId: envelopeId),
    ),
  );
}

class _NewTransactionSheet extends ConsumerStatefulWidget {
  const _NewTransactionSheet({
    required this.initialMode,
    this.initialEnvelopeId,
  });

  final TxMode initialMode;
  final String? initialEnvelopeId;

  @override
  ConsumerState<_NewTransactionSheet> createState() =>
      _NewTransactionSheetState();
}

/// Спец-id «из кармана» (только для расхода).
const _pocketId = '_pocket';

class _NewTransactionSheetState
    extends ConsumerState<_NewTransactionSheet>
    with SingleTickerProviderStateMixin {
  late TxMode _mode;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _envelopeId; // конверт / получатель (перевод) / источник (расход,доход)
  String? _toEnvelopeId; // получатель перевода
  late DateTime _date;
  bool _saving = false;
  bool _repeat = false; // Cashly «Repeat» — şimdilik görsel.

  // Пульс-анимация суммы при вводе.
  late final AnimationController _pop;
  int _lastLen = 0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _envelopeId = widget.initialEnvelopeId ??
        (_mode == TxMode.expense ? _pocketId : null);
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0,
      upperBound: 1,
      value: 1,
    );
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final len = _amountController.text.length;
    // Подпрыгивание только когда добавили цифру.
    if (len != _lastLen) {
      _lastLen = len;
      if (len > 0) _pop.forward(from: 0);
    }
    setState(() {});
  }

  /// Цвет свечения суммы под текущий режим.
  Color get _glow => switch (_mode) {
        TxMode.expense => context.budgy.text,
        TxMode.income => context.budgy.accent,
        TxMode.transfer => context.budgy.accentStrong,
      };

  @override
  void dispose() {
    _pop.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount => parseAmount(_amountController.text);

  bool get _canSave {
    if (_amount == null || _saving) return false;
    return switch (_mode) {
      TxMode.expense => _envelopeId != null,
      TxMode.income => _envelopeId != null,
      TxMode.transfer => _envelopeId != null &&
          _toEnvelopeId != null &&
          _envelopeId != _toEnvelopeId,
    };
  }

  Future<void> _save() async {
    final amount = _amount;
    if (amount == null) return;
    final str = ref.read(strProvider);
    final repo = ref.read(budgetRepositoryProvider);
    final envelopes = ref.read(envelopesProvider).value ?? [];
    String nameOf(String id) => envelopes
        .firstWhere((e) => e.id == id)
        .displayName(str);
    String currencyOf(String id) =>
        envelopes.firstWhere((e) => e.id == id).currency;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final date =
        isToday ? now : DateTime(_date.year, _date.month, _date.day, 12);

    setState(() => _saving = true);
    try {
      switch (_mode) {
        case TxMode.expense:
          if (_envelopeId == _pocketId) {
            await repo.addFreeExpense(
                amount: amount, note: note, date: date);
          } else {
            await repo.addExpense(
              envelopeId: _envelopeId!,
              envelopeName: nameOf(_envelopeId!),
              amount: amount,
              currency: currencyOf(_envelopeId!),
              note: note,
              date: date,
            );
          }
        case TxMode.income:
          if (_envelopeId == _pocketId) {
            // Доход в общий котёл — потом разложишь по конвертам.
            await repo.addFreeIncome(
                amount: amount, note: note, date: date);
          } else {
            await repo.addIncomeToEnvelope(
              envelopeId: _envelopeId!,
              envelopeName: nameOf(_envelopeId!),
              amount: amount,
              currency: currencyOf(_envelopeId!),
              note: note,
              date: date,
            );
          }
        case TxMode.transfer:
          await repo.transfer(
            fromId: _envelopeId!,
            fromName: nameOf(_envelopeId!),
            toId: _toEnvelopeId!,
            toName: nameOf(_toEnvelopeId!),
            amount: amount,
            note: note,
            date: date,
          );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    final envelopes = ref.watch(envelopesProvider).value ?? [];

    // Seçili zarfın para birimi → tutar simgesi ($ / ₺...).
    final activeCode = _mode == TxMode.transfer
        ? envelopes.where((e) => e.id == _toEnvelopeId).firstOrNull?.currency
        : (_envelopeId != null && _envelopeId != _pocketId
            ? envelopes.where((e) => e.id == _envelopeId).firstOrNull?.currency
            : null);
    final amountSymbol = kCurrencies[activeCode ?? 'TRY'] ?? currencySymbol;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Navbar: geri · "Add new transaction" · ...
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 15, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _NavCircle(
                      icon: Icons.chevron_left,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          str.addTxTitle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _NavCircle(icon: Icons.more_horiz, onTap: () {}),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 15, 16),
                children: [
                  // Tip sekmeleri (Expense / Income / Transfer)
                  _ModeSegmented(
                    mode: _mode,
                    str: str,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _envelopeId = m == TxMode.expense ? _pocketId : null;
                      _toEnvelopeId = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Amount kartı — büyük tutar + pulse.
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface2,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      children: [
                        Text(str.amountTitle,
                            style: TextStyle(
                                fontSize: 14, color: c.textMuted)),
                        const SizedBox(height: 2),
                        AnimatedBuilder(
                          animation: _pop,
                          builder: (context, child) {
                            final t = Curves.easeOut.transform(_pop.value);
                            final scale = 1 + 0.18 * (1 - t);
                            final hasAmount = _amount != null;
                            return Transform.scale(
                              scale: hasAmount ? scale : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: hasAmount
                                      ? [
                                          BoxShadow(
                                            color: _glow.withValues(
                                                alpha: 0.22 * (1 - t)),
                                            blurRadius: 28,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: TextField(
                            controller: _amountController,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: _amount != null ? _glow : c.text,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              isDense: true,
                              prefixText: '$amountSymbol ',
                              prefixStyle: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: c.textFaint,
                              ),
                              hintText: '0',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tarih kartı
                  _DateStepperRow(
                    date: _date,
                    str: str,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 12),
                  // Kategori / Transfer kaynak-hedef
                  if (_mode == TxMode.transfer) ...[
                    _PickerRow(
                      label: str.fromLabel,
                      value: _envelopeId,
                      envelopes: envelopes,
                      str: str,
                      allowPocket: false,
                      onPick: (id) => setState(() => _envelopeId = id),
                    ),
                    const SizedBox(height: 12),
                    _PickerRow(
                      label: str.toLabel,
                      value: _toEnvelopeId,
                      envelopes: envelopes,
                      str: str,
                      allowPocket: false,
                      exclude: _envelopeId,
                      onPick: (id) => setState(() => _toEnvelopeId = id),
                    ),
                  ] else
                    _PickerRow(
                      label: str.envelopeLabel,
                      value: _envelopeId,
                      envelopes: envelopes,
                      str: str,
                      allowPocket: true,
                      onPick: (id) => setState(() => _envelopeId = id),
                    ),
                  const SizedBox(height: 12),
                  // Note kartı
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: TextField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: str.noteHint,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Repeat kartı (görsel)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: c.surface2, shape: BoxShape.circle),
                          child: Icon(Icons.history_rounded,
                              size: 20, color: c.textMuted),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(str.repeatLabel,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                        Switch(
                          value: _repeat,
                          activeThumbColor: c.accent,
                          onChanged: (v) => setState(() => _repeat = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        disabledBackgroundColor:
                            c.accent.withValues(alpha: 0.4),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _canSave ? _save : null,
                      child: Text(_saving ? str.saving : str.save),
                    ),
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

class _ModeSegmented extends StatelessWidget {
  const _ModeSegmented({
    required this.mode,
    required this.str,
    required this.onChanged,
  });

  final TxMode mode;
  final Strings str;
  final ValueChanged<TxMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final items = [
      (TxMode.expense, str.expenseTitle),
      (TxMode.income, str.incomeTitle),
      (TxMode.transfer, str.transferTitle),
    ];
    return Row(
      children: [
        for (final (m, label) in items) ...[
          GestureDetector(
            onTap: () => onChanged(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: m == mode ? c.accent : c.surface2,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: m == mode ? FontWeight.w700 : FontWeight.w500,
                  color: m == mode ? Colors.white : c.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Строка выбора конверта: подпись + текущий конверт, по тапу — список.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.envelopes,
    required this.str,
    required this.allowPocket,
    required this.onPick,
    this.exclude,
  });

  final String label;
  final String? value;
  final List<Envelope> envelopes;
  final Strings str;
  final bool allowPocket;
  final String? exclude;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final env = value == _pocketId
        ? null
        : envelopes.where((e) => e.id == value).firstOrNull;
    final hasValue = value != null;
    final emoji = value == _pocketId ? '💸' : env?.emoji;
    final name = value == _pocketId
        ? str.withoutEnvelope
        : env?.displayName(str) ?? str.selectCategory;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: c.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => EnvelopePickerGrid(
            allowPocket: allowPocket,
            exclude: exclude,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: c.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.surface2, shape: BoxShape.circle),
                  child: Text(hasValue ? (emoji ?? '🗂️') : '🗂️',
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? name : str.selectCategory,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? c.text : c.textMuted,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: c.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Грид выбора конверта: кружки-эмодзи с подписями, поиск и «+».
/// Возвращает id конверта (или _pocketId).
class EnvelopePickerGrid extends ConsumerStatefulWidget {
  const EnvelopePickerGrid({
    super.key,
    this.allowPocket = false,
    this.exclude,
  });

  final bool allowPocket;
  final String? exclude;

  @override
  ConsumerState<EnvelopePickerGrid> createState() =>
      _EnvelopePickerGridState();
}

class _EnvelopePickerGridState extends ConsumerState<EnvelopePickerGrid> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    final all = ref.watch(envelopesProvider).value ?? [];
    final q = _query.trim().toLowerCase();
    final envelopes = [
      for (final e in all)
        if (e.id != widget.exclude &&
            (q.isEmpty || e.displayName(str).toLowerCase().contains(q)))
          e,
    ];

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            // Шапка: заголовок + кнопка добавить конверт.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      str.selectEnvelope,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      await showAddEnvelopeSheet(context, all.length);
                    },
                  ),
                ],
              ),
            ),
            // Поиск.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: str.searchHint,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                children: [
                  if (widget.allowPocket && q.isEmpty)
                    _PickerCell(
                      emoji: '💸',
                      label: str.withoutEnvelope,
                      bg: c.surface2,
                      onTap: () => Navigator.of(context).pop(_pocketId),
                    ),
                  for (final (i, env) in envelopes.indexed)
                    _PickerCell(
                      emoji: env.emoji,
                      label: env.displayName(str),
                      bg: c.envTintAt(i),
                      onTap: () => Navigator.of(context).pop(env.id),
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

class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.emoji,
    required this.label,
    required this.bg,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Cashly tarih kartı: takvim ikonu + Bugün/tarih + ‹ › adım.
class _DateStepperRow extends StatelessWidget {
  const _DateStepperRow({
    required this.date,
    required this.str,
    required this.onChanged,
  });

  final DateTime date;
  final Strings str;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;
    final label = isToday
        ? str.today
        : DateFormat('d MMMM yyyy', str.localeCode).format(date);

    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(str.dateLabel,
              style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.surface2, shape: BoxShape.circle),
                child: Icon(Icons.calendar_today_rounded,
                    size: 18, color: c.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      initial: date,
                      first: DateTime(now.year - 2),
                      last: today,
                      localeCode: str.localeCode,
                    );
                    if (picked != null) {
                      onChanged(
                          DateTime(picked.year, picked.month, picked.day));
                    }
                  },
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              _StepBtn(
                icon: Icons.chevron_left,
                onTap: () =>
                    onChanged(date.subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              _StepBtn(
                icon: Icons.chevron_right,
                onTap: isToday
                    ? null
                    : () => onChanged(date.add(const Duration(days: 1))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        child: Icon(icon,
            size: 20, color: onTap == null ? c.textFaint : c.text),
      ),
    );
  }
}

/// Navbar yuvarlak butonu (47×48), auth ekranlarındakiyle aynı.
class _NavCircle extends StatelessWidget {
  const _NavCircle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 47,
        height: 48,
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: c.text),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/palette.dart';
import '../transactions/budget_completed_screen.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_l10n.dart';

enum _Period { weekly, monthly, yearly }

/// Calculate Budget — zarfa bütçe (hedef) tutarı, periyot, tarih ve not.
/// Cashly tam-ekran formu. Save → hedef tutarı kaydedilir (ilerleme çubuğu).
class CalculateBudgetScreen extends ConsumerStatefulWidget {
  const CalculateBudgetScreen({super.key, required this.envelope});

  final Envelope envelope;

  @override
  ConsumerState<CalculateBudgetScreen> createState() =>
      _CalculateBudgetScreenState();
}

class _CalculateBudgetScreenState
    extends ConsumerState<CalculateBudgetScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  _Period? _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day);
    _end = _start;
    final t = widget.envelope.targetAmount;
    if (t != null) _amount.text = t.toStringAsFixed(0);
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _sym =>
      kCurrencies[widget.envelope.currency] ?? currencySymbol;

  String _periodLabel(Strings str) => switch (_period) {
        _Period.weekly => str.periodWeekly,
        _Period.monthly => str.periodMonthly,
        _Period.yearly => str.periodYearly,
        null => str.selectPeriod,
      };

  Future<void> _removeBudget() async {
    await ref
        .read(budgetRepositoryProvider)
        .setTarget(widget.envelope.id, null);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .setTarget(widget.envelope.id, amount);
    if (!mounted) return;
    // Bütçe hazır → kutlama ekranı → Continue ile zarf detayına dön.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // ctx = kutlama ekranının kendi context'i; eski (yok edilmiş)
        // calculate_budget context'i ile Navigator çalışmıyordu.
        builder: (ctx) => BudgetCompletedScreen(
          onContinue: () => Navigator.of(ctx).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final e = widget.envelope;
    final canSave = parseAmount(_amount.text) != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Navbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 15, 0),
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    _Circle(
                      icon: Icons.chevron_left,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFF3),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(str.calculateBudget,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Circle(icon: Icons.more_horiz, onTap: () {}),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 15, 16),
                children: [
                  Text(str.calculateBudget,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ink)),
                  const SizedBox(height: 4),
                  Text(
                    tpl(str.setAsideFor, {
                      'amount': formatMoneyIn(e.balance, e.currency),
                      'name': e.displayName(str),
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: inkMuted),
                  ),
                  const SizedBox(height: 20),
                  // Budget Name (salt-okunur)
                  _LabeledCard(
                    label: str.budgetName,
                    child: Row(
                      children: [
                        _MiniIcon(child: Text(e.emoji,
                            style: const TextStyle(fontSize: 18))),
                        const SizedBox(width: 12),
                        Text(e.displayName(str),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Budget Amount
                  _LabeledCard(
                    label: str.budgetAmount,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        prefixText: '$_sym  ',
                        hintText: '0.0',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Start / End Date
                  Row(
                    children: [
                      Expanded(
                        child: _DateCard(
                          label: str.startDate,
                          date: _start,
                          str: str,
                          onPick: (d) => setState(() => _start = d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateCard(
                          label: str.endDate,
                          date: _end,
                          str: str,
                          onPick: (d) => setState(() => _end = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Time Period
                  _LabeledCard(
                    label: str.timePeriod,
                    onTap: () => _pickPeriod(str),
                    child: Row(
                      children: [
                        _MiniIcon(
                            child: const Icon(Icons.hourglass_empty_rounded,
                                size: 18, color: inkMuted)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_periodLabel(str),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: _period == null
                                      ? Colors.grey.shade500
                                      : ink)),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            color: inkMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Note
                  _LabeledCard(
                    label: str.noteLabel,
                    child: TextField(
                      controller: _note,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: str.noteHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 15, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        disabledBackgroundColor:
                            accent.withValues(alpha: 0.4),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: canSave ? _save : null,
                      child: Text(str.save),
                    ),
                  ),
                  if (widget.envelope.targetAmount != null)
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red),
                      onPressed: _removeBudget,
                      child: Text(str.removeBudget),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPeriod(Strings str) async {
    var sel = _period ?? _Period.monthly;
    final picked = await showModalBottomSheet<_Period>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.timePeriod,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const Icon(Icons.close, color: inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final p in _Period.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _MiniIcon(
                      child: const Icon(Icons.hourglass_empty_rounded,
                          size: 18, color: inkMuted)),
                  title: Text(switch (p) {
                    _Period.weekly => str.periodWeekly,
                    _Period.monthly => str.periodMonthly,
                    _Period.yearly => str.periodYearly,
                  }),
                  trailing: Radio<_Period>(
                    value: p,
                    groupValue: sel,
                    activeColor: accent,
                    onChanged: (v) => setS(() => sel = v!),
                  ),
                  onTap: () => setS(() => sel = p),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(sel),
                  child: Text(str.chooseWord),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _period = picked);
  }
}

class _LabeledCard extends StatelessWidget {
  const _LabeledCard(
      {required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(16), child: card);
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.date,
    required this.str,
    required this.onPick,
  });

  final String label;
  final DateTime date;
  final Strings str;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final text = date == today
        ? str.today
        : DateFormat('d MMM', str.localeCode).format(date);
    return _LabeledCard(
      label: label,
      onTap: () async {
        final picked = await showAppDatePicker(
          context: context,
          initial: date,
          first: DateTime(now.year - 2),
          last: DateTime(now.year + 5),
          localeCode: str.localeCode,
        );
        if (picked != null) {
          onPick(DateTime(picked.year, picked.month, picked.day));
        }
      },
      child: Row(
        children: [
          _MiniIcon(
              child: const Icon(Icons.calendar_today_rounded,
                  size: 16, color: inkMuted)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: Color(0xFFF1F2F5), shape: BoxShape.circle),
      child: child,
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 47,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFF3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: ink),
      ),
    );
  }
}

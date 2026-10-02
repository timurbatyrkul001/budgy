import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/ex_style.dart';
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
      // Kâğıt zemin: afişle aynı krem, eski mavi-gri sabit yerine.
      backgroundColor: Ex.bg,
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
                          // Basılı hap: ikincil dolgu, krem üstünde hafif koyu.
                          color: Ex.surfaceHi,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(str.calculateBudget,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Ex.text)),
                      ),
                    ),
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
                          color: Ex.text)),
                  const SizedBox(height: 4),
                  Text(
                    tpl(str.setAsideFor, {
                      'amount': formatMoneyIn(e.balance, e.currency),
                      'name': e.displayName(str),
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Ex.textMuted),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Ex.text)),
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
                      // Tutar girişi afiş tipografisinde: mürekkep rengi,
                      // sıkı aralıklı Inter Display.
                      style: const TextStyle(
                          fontFamily: 'InterDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.04 * 18,
                          color: Ex.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        prefixText: '$_sym  ',
                        prefixStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Ex.textMuted),
                        hintText: '0.0',
                        hintStyle: const TextStyle(color: Ex.textFaint),
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
                                size: 18, color: Ex.textMuted)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_periodLabel(str),
                              style: TextStyle(
                                  fontSize: 16,
                                  color: _period == null
                                      ? Ex.textFaint
                                      : Ex.text)),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            color: Ex.textMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Note
                  _LabeledCard(
                    label: str.noteLabel,
                    child: TextField(
                      controller: _note,
                      style: const TextStyle(color: Ex.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: str.noteHint,
                        hintStyle: const TextStyle(color: Ex.textFaint),
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
                        backgroundColor: Ex.brand,
                        foregroundColor: Ex.onBrand,
                        disabledBackgroundColor:
                            Ex.brand.withValues(alpha: 0.35),
                        disabledForegroundColor:
                            Ex.onBrand.withValues(alpha: 0.6),
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
                          foregroundColor: Ex.red),
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
      backgroundColor: Ex.sheet,
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
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Ex.text)),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const Icon(Icons.close, color: Ex.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Radio.groupValue/onChanged Flutter 3.32'de kullanımdan
              // kalktı — seçim artık RadioGroup ile yönetiliyor.
              RadioGroup<_Period>(
                groupValue: sel,
                onChanged: (v) => setS(() => sel = v!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in _Period.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _MiniIcon(
                            child: const Icon(Icons.hourglass_empty_rounded,
                                size: 18, color: Ex.textMuted)),
                        title: Text(
                            switch (p) {
                              _Period.weekly => str.periodWeekly,
                              _Period.monthly => str.periodMonthly,
                              _Period.yearly => str.periodYearly,
                            },
                            style: const TextStyle(color: Ex.text)),
                        trailing: Radio<_Period>(
                          value: p,
                          activeColor: Ex.brand,
                        ),
                        onTap: () => setS(() => sel = p),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Ex.brand,
                    foregroundColor: Ex.onBrand,
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
        // Beyaz kart krem kâğıttan neredeyse ayrışmıyor; ince kenarlık
        // (ExCard'daki gibi) kartın sınırını belli ediyor.
        color: Ex.surface,
        border: Border.all(color: Ex.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Ex.textMuted)),
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
                  size: 16, color: Ex.textMuted)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Ex.text)),
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
      // İkon yuvası: beyaz kartın içinde ikincil dolgu.
      decoration: const BoxDecoration(
          color: Ex.surfaceHi, shape: BoxShape.circle),
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
          color: Ex.surfaceHi,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, color: Ex.text),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../workdays/work_days_repository.dart';

/// Доход: вводишь сумму и вручную раскидываешь по конвертам —
/// как в бумажной книжке. Сохранить можно, когда распределено всё.
///
/// Из календаря открывается с готовой суммой заработка ([initialAmount]);
/// после сохранения дни [workDayIds] помечаются распределёнными.
class AddIncomeScreen extends ConsumerStatefulWidget {
  const AddIncomeScreen({
    super.key,
    this.initialAmount,
    this.initialNote,
    this.workDayIds = const [],
    this.freeTxIds = const [],
  });

  final double? initialAmount;
  final String? initialNote;
  final List<String> workDayIds;

  /// Свободные операции (доходы в котле и расходы из кармана), учтённые
  /// в предложенной сумме — после сохранения помечаются разложенными.
  final List<String> freeTxIds;

  @override
  ConsumerState<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends ConsumerState<AddIncomeScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<String, TextEditingController> _allocControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(
          widget.initialAmount! % 1 == 0 ? 0 : 2);
    }
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(Envelope envelope) {
    return _allocControllers.putIfAbsent(envelope.id, () {
      final controller = TextEditingController();
      controller.addListener(() => setState(() {}));
      return controller;
    });
  }

  double get _amount => parseAmount(_amountController.text) ?? 0;

  Map<String, double> get _allocations => {
        for (final entry in _allocControllers.entries)
          if (parseAmount(entry.value.text) != null)
            entry.key: parseAmount(entry.value.text)!,
      };

  double get _allocated =>
      _allocations.values.fold(0, (sum, v) => sum + v);

  double get _remaining => _amount - _allocated;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).addIncome(
            amount: _amount,
            allocations: _allocations,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (widget.workDayIds.isNotEmpty) {
        await ref
            .read(workDaysRepositoryProvider)
            .markAllocated(widget.workDayIds);
      }
      if (widget.freeTxIds.isNotEmpty) {
        await ref
            .read(budgetRepositoryProvider)
            .markFreeTxsAllocated(widget.freeTxIds);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Segment rengi (export'taki çok renkli dağıtım çubukları) — sadece
  /// token'lardan, döngüsel.
  Color _segColor(BudgyColors c, int index) {
    final palette = [c.accent, c.amber, c.accentStrong];
    return palette[index % palette.length];
  }

  /// Zarfın toplam gelirden aldığı pay (0..1).
  double _fractionOf(Envelope envelope) {
    if (_amount <= 0) return 0;
    final alloc = _allocations[envelope.id] ?? 0;
    return (alloc / _amount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final canSave =
        _amount > 0 && _remaining.abs() < 0.005 && !_saving;
    final done = _remaining.abs() < 0.005;
    final over = _remaining < -0.005;
    final freeFraction =
        _amount > 0 ? (_remaining / _amount).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── başlık: kapat + ekran adı ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
              child: Row(
                children: [
                  Material(
                    color: c.surface,
                    shape: CircleBorder(side: BorderSide(color: c.border)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.close_rounded,
                            size: 20, color: c.text),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      str.incomeTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02 * 16,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── tutar hero ────────────────────────────────────────
                  Text(
                    str.incomeTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.02 * 13,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.04 * 44,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: c.text,
                    ),
                    decoration: InputDecoration(
                      hintText: curText(str.amountHint),
                      hintStyle: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.04 * 44,
                        color: c.textFaint,
                      ),
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                    decoration: InputDecoration(
                      hintText: str.incomeNoteHint,
                      hintStyle:
                          TextStyle(fontSize: 14, color: c.textFaint),
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.accent, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── yığın dağıtım çubuğu ──────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      height: 16,
                      color: c.track,
                      child: _amount <= 0
                          ? null
                          : Row(
                              children: [
                                for (var i = 0;
                                    i < envelopes.length;
                                    i++)
                                  if (_fractionOf(envelopes[i]) > 0)
                                    Expanded(
                                      flex: (_fractionOf(envelopes[i]) *
                                              1000)
                                          .round()
                                          .clamp(1, 1000),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            right: 2),
                                        color: _segColor(c, i),
                                      ),
                                    ),
                                if (freeFraction > 0)
                                  Expanded(
                                    flex: (freeFraction * 1000)
                                        .round()
                                        .clamp(1, 1000),
                                    child: Container(
                                      color: c.textFaint
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── dağıtım başlığı + durum ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        str.distribution,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.02 * 16,
                          color: c.text,
                        ),
                      ),
                      Text(
                        done
                            ? str.allDistributed
                            : tpl(str.remainingTpl,
                                {'x': formatMoney(_remaining)}),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                          color: done
                              ? c.accent
                              : (over ? Colors.red : c.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── zarf satırları ────────────────────────────────────
                  for (var i = 0; i < envelopes.length; i++) ...[
                    _AllocationRow(
                      envelope: envelopes[i],
                      controller: _controllerFor(envelopes[i]),
                      fraction: _fractionOf(envelopes[i]),
                      tint: c.envTintAt(i),
                      barColor: _segColor(c, i),
                    ),
                    const SizedBox(height: 15),
                  ],
                  if (envelopes.isEmpty)
                    Text(
                      str.createEnvelopesFirst,
                      style: TextStyle(fontSize: 14, color: c.textMuted),
                    ),

                  // ── serbest kalan kartı ───────────────────────────────
                  if (envelopes.isNotEmpty && _amount > 0)
                    CustomPaint(
                      painter: _DashedBorderPainter(
                        color: c.borderStrong,
                        radius: 16,
                      ),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: c.track,
                                borderRadius: BorderRadius.circular(
                                    BudgyRadii.icon),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                done
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: done ? c.accent : c.textMuted,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                done
                                    ? str.allDistributed
                                    : tpl(str.remainingTpl,
                                        {'x': formatMoney(_remaining)}),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: done ? c.accent : c.text,
                                ),
                              ),
                            ),
                            if (!over) ...[
                              Text(
                                '%${(freeFraction * 100).round()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: c.textMuted,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Text(
                                formatMoney(
                                    _remaining < 0 ? 0 : _remaining),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: c.text,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── onay çubuğu ───────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.tabbar,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '${str.distribution} ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: formatMoney(_allocated),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: c.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      done
                          ? str.allDistributed
                          : tpl(str.remainingTpl,
                              {'x': formatMoney(_remaining)}),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: done
                            ? c.accent
                            : (over ? Colors.red : c.text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: c.track,
                    disabledForegroundColor: c.textFaint,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.01 * 16,
                    ),
                  ),
                  child: Text(_saving ? str.saving : str.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek zarf satırı: tint ikon + isim + canlı yüzde + tutar girişi,
/// altında pay çubuğu (export'taki satır düzeni).
class _AllocationRow extends ConsumerWidget {
  const _AllocationRow({
    required this.envelope,
    required this.controller,
    required this.fraction,
    required this.tint,
    required this.barColor,
  });

  final Envelope envelope;
  final TextEditingController controller;
  final double fraction;
  final Color tint;
  final Color barColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(BudgyRadii.icon),
              ),
              alignment: Alignment.center,
              child:
                  Text(envelope.emoji, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                envelope.displayName(str),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.01 * 15,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Text(
              '%${(fraction * 100).round()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: c.textMuted,
              ),
            ),
            const SizedBox(width: 11),
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: c.text,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textFaint,
                  ),
                  filled: true,
                  fillColor: c.surface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: c.track,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kesikli çerçeve (export'taki "serbest kalsın" kartı).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(radius)));
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

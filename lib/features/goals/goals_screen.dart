import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animated_bar.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/palette.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';

const _goalEmojis = [
  '✈️', '🚗', '💻', '🏠', '📱', '🎓', '🏖️', '🎮', '⌚',
  '🚴', '🛋️', '👶', '🐶', '🎸', '📷', '🏝️', '💰',
];

/// Birikim hedefleri (Trip, araba, MacBook...). Para ekledikçe dolar.
/// Hedef parası Money left'ten ayrıdır (ayrılmış kumbara).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final goals = envelopes.where((e) => e.isGoal && !e.archived).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text(str.goalsTitle),
      ),
      body: goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 16),
                    Text(
                      str.goalsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final (i, goal) in goals.indexed) ...[
                  _GoalCard(goal: goal, colorIndex: i),
                  const SizedBox(height: 12),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
          ),
          onPressed: () => _showNewGoal(context, ref, goals.length),
          icon: const Icon(Icons.add_rounded),
          label: Text(str.newGoal.replaceFirst('+ ', '')),
        ),
      ),
    );
  }
}

void _showNewGoal(BuildContext context, WidgetRef ref, int sortOrder) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _NewGoalSheet(sortOrder: sortOrder),
  );
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.colorIndex});

  final Envelope goal;
  final int colorIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final target = goal.targetAmount ?? 0;
    final percent = (goal.progress * 100).round();
    final done = goal.balance >= target && target > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showAddMoney(context, ref, goal),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.envTintAt(colorIndex),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: c.surface, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child:
                      Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoneyIn(goal.balance, 'TRY')} / ${formatMoneyIn(target, 'TRY')}',
                        style: TextStyle(
                            fontSize: 13.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                Text('$percent%',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text)),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBar(
              value: goal.progress,
              color: vividAt(colorIndex),
              background: c.track,
            ),
            const SizedBox(height: 8),
            Text(
              done
                  ? '🎉'
                  : '${formatMoneyIn(goal.remaining, 'TRY')} ${str.goalLeft}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.budgy.surface,
        title:
            Text(tpl(str.removeGoalTitle, {'name': goal.name})),
        content: Text(str.removeGoalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(str.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(str.removeWord,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(budgetRepositoryProvider)
          .deleteGoal(goal.id, goal.balance);
    }
  }
}

void _showAddMoney(BuildContext context, WidgetRef ref, Envelope goal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddMoneySheet(goal: goal),
  );
}

class _AddMoneySheet extends ConsumerStatefulWidget {
  const _AddMoneySheet({required this.goal});
  final Envelope goal;

  @override
  ConsumerState<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<_AddMoneySheet> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).fundGoal(
            goalId: widget.goal.id,
            goalName: widget.goal.name,
            amount: amount,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final canSave = parseAmount(_amount.text) != null && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text('${widget.goal.emoji}  ${widget.goal.name}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: c.text),
            decoration: InputDecoration(
              prefixText: '₺  ',
              prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted),
              hintText: '0',
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: canSave ? _save : null,
              child: Text(_saving ? '...' : str.addFunds),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewGoalSheet extends ConsumerStatefulWidget {
  const _NewGoalSheet({required this.sortOrder});
  final int sortOrder;

  @override
  ConsumerState<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<_NewGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _emoji = _goalEmojis.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = parseAmount(_target.text);
    final name = _name.text.trim();
    if (target == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).addGoal(
            name: name,
            emoji: _emoji,
            targetAmount: target,
            sortOrder: widget.sortOrder,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final canSave = _name.text.trim().isNotEmpty &&
        parseAmount(_target.text) != null &&
        !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(str.newGoal.replaceFirst('+ ', ''),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: str.nameHint,
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _goalEmojis)
                    ChoiceChip(
                      label: Text(e, style: const TextStyle(fontSize: 20)),
                      selected: _emoji == e,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _emoji = e),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
            decoration: InputDecoration(
              prefixText: '₺  ',
              hintText: curText(str.targetAmountHint),
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: canSave ? _save : null,
              child: Text(_saving ? '...' : str.setGoal),
            ),
          ),
        ],
      ),
    );
  }
}

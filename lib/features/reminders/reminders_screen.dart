import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'reminders_repository.dart';

/// «Düzenli Giderler» panosu: aylık toplam + en yakın ödemesi başta sıralı
/// liste. Пуш приходит каждый месяц в указанные дни в 10:00.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    final reminders = ref.watch(remindersProvider);
    final items = ref.watch(recurringExpensesProvider);
    final monthlyTotal = ref.watch(recurringMonthlyTotalProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  const _BackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      str.recurringTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: reminders.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    '${str.errorPrefix}: $e',
                    style: TextStyle(color: c.textMuted),
                  ),
                ),
                data: (_) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _SummaryCard(
                      label: str.recurringMonthlyLabel,
                      total: monthlyTotal,
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 40),
                        child: Text(
                          str.remindersEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textMuted,
                            height: 1.4,
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      for (final item in items) ...[
                        _RecurringTile(item: item),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BudgyRadii.chip),
            ),
          ),
          onPressed: () => _showAddSheet(context, ref),
          child: Text(str.newReminder),
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.budgy.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddReminderSheet(),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.text),
        ),
      ),
    );
  }
}

/// Üst özet kartı: aylık düzenli gider toplamı (Rocket Money usulü manşet).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.total});

  final String label;
  final double total;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(total),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.item});

  final RecurringItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final reminder = item.reminder;

    void remove() =>
        ref.read(remindersRepositoryProvider).remove(reminder.id);

    final badgeText = item.dueNow
        ? str.dueNowLabel
        : item.daysUntil == 0
            ? str.today
            : tpl(str.dueInDaysTpl, {'n': '${item.daysUntil}'});

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BudgyRadii.card),
        ),
        onLongPress: remove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reminder.amount != null
                          ? formatMoney(reminder.amount!)
                          : '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.dueNow ? c.amberBg : c.surface2,
                      borderRadius:
                          BorderRadius.circular(BudgyRadii.chip),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: item.dueNow ? c.amber : c.textMuted,
                      ),
                    ),
                  ),
                  if (!item.dueNow) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMM', str.localeCode)
                          .format(item.nextDue),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: c.textFaint),
                onPressed: remove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() =>
      _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  int _fromDay = 1;
  int _toDay = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(remindersRepositoryProvider).add(
          name: name,
          fromDay: _fromDay,
          toDay: _toDay < _fromDay ? _fromDay : _toDay,
          amount: parseAmount(_amountController.text),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            str.newReminder.replaceFirst('+ ', ''),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.text),
            decoration: InputDecoration(hintText: str.reminderNameHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: c.text),
            decoration:
                InputDecoration(hintText: curText(str.amountOptionalHint)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(str.remindFrom,
                  style: TextStyle(fontSize: 15, color: c.text)),
              const SizedBox(width: 8),
              _DayPicker(
                value: _fromDay,
                onChanged: (v) => setState(() => _fromDay = v),
              ),
              const SizedBox(width: 8),
              Text(str.toWord,
                  style: TextStyle(fontSize: 15, color: c.text)),
              const SizedBox(width: 8),
              _DayPicker(
                value: _toDay,
                onChanged: (v) => setState(() => _toDay = v),
              ),
              const SizedBox(width: 8),
              Text(str.dayOfMonthWord,
                  style: TextStyle(fontSize: 15, color: c.text)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BudgyRadii.chip),
              ),
            ),
            onPressed: _save,
            child: Text(str.create),
          ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        dropdownColor: c.surface,
        style: TextStyle(fontSize: 15, color: c.text),
        // До 28 — чтобы напоминание не пропадало в коротких месяцах.
        items: [
          for (var day = 1; day <= 28; day++)
            DropdownMenuItem(value: day, child: Text('$day')),
        ],
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }
}

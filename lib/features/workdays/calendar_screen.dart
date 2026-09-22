import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'work_days_repository.dart';

/// Календарь рабочих дней: тап по дню — указать заработок за этот день.
/// Ячейки — «тепловая карта» заработка (heat0..heat4), сегодня — кольцо
/// акцента, внизу — закреплённая карточка «сегодня».
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final monthKey = monthKeyOf(_month);
    final workDays =
        ref.watch(monthWorkDaysProvider(monthKey)).value ?? const {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pastDays =
        workDays.entries.where((e) => !e.key.isAfter(today)).toList();
    final earned =
        pastDays.fold<double>(0, (sum, e) => sum + (e.value ?? 0));
    final forecast = workDays.entries
        .fold<double>(0, (sum, e) => sum + (e.value ?? 0));
    final plannedCount = workDays.length - pastDays.length;

    // «Сегодня»-карточка внизу — только когда показан текущий месяц.
    final showsCurrentMonth = monthKey == monthKeyOf(today);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  // Menüden push edildiğinde geri; yoksa gizli.
                  const BudgyBackButton(),
                  // ── başlık ─────────────────────────────────────────────
                  Text(
                    str.workDaysTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.03 * 26,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── ay özeti: çalışılan gün + kazanç ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: str.worked,
                          value: '${pastDays.length}',
                          unit: str.daysShort,
                          valueColor: c.text,
                          subline:
                              '${str.planned}: $plannedCount ${str.daysShort}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: str.earned,
                          value: formatMoney(earned),
                          valueColor: c.accent,
                          subline:
                              '${str.monthForecast}: ${formatMoney(forecast)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── ay gezinme ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded,
                            size: 24, color: c.textMuted),
                        onPressed: () => _shiftMonth(-1),
                      ),
                      // Ay adı esner: dar ekranda uzun aylar ("Ağustos",
                      // "Сентябрь") iki ok düğmesi arasına sığmıyordu.
                      Expanded(
                        child: Text(
                          toBeginningOfSentenceCase(
                              DateFormat('LLLL yyyy', str.localeCode)
                                  .format(_month)),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 17,
                            color: c.text,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded,
                            size: 24, color: c.textMuted),
                        onPressed: () => _shiftMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _MonthGrid(
                    month: _month,
                    workDays: workDays,
                    today: today,
                    weekdays: str.weekdaysShort,
                    onTap: (day) => _editDay(day, workDays),
                  ),
                ],
              ),
            ),

            // ── bugün kartı (sadece güncel ay görünürken) ────────────────
            if (showsCurrentMonth)
              _TodayBar(
                today: today,
                amount: workDays[today],
                isMarked: workDays.containsKey(today),
                onTap: () => _editDay(today, workDays),
              ),
          ],
        ),
      ),
    );
  }

  /// Тап по дню. Новый день — пустое поле (сумма каждый день своя,
  /// «от кассы»), без суммы не сохранить. Отмеченный — правка/снятие.
  Future<void> _editDay(
      DateTime day, Map<DateTime, double?> workDays) async {
    final c = context.budgy;
    final str = ref.read(strProvider);
    final isMarked = workDays.containsKey(day);
    final existing = workDays[day];
    final controller = TextEditingController(
      text: existing != null ? existing.toStringAsFixed(0) : '',
    );

    // StatefulBuilder tüm diyaloğu sarıyor: Save düğmesi de yazdıkça
    // yeniden çiziliyor, böylece geçersiz tutarda GÖRÜNÜR halde sönük
    // duruyor — eskiden basılıyordu ama sessizce hiçbir şey yapmıyordu.
    final result = await showDialog<_DayAction>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canSave = parseAmount(controller.text) != null;
          void save() {
            if (canSave) Navigator.of(context).pop(_DayAction.save);
          }

          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BudgyRadii.bigCard),
            ),
            title: Text(
              DateFormat('d MMMM', str.localeCode).format(day),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02 * 18,
                color: c.text,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Klavyedeki Done tuşu da kaydetsin — rakamı yazıp enter'a
              // basmak en doğal hareket, eskiden hiçbir şey yapmıyordu.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
              decoration: InputDecoration(
                hintText: curText(str.dayEarningsHint),
                hintStyle: TextStyle(
                    fontWeight: FontWeight.w500, color: c.textFaint),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.borderStrong),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: c.accent, width: 1.6),
                ),
              ),
              onChanged: (_) => setDialogState(() {}),
            ),
            actions: [
              if (isMarked)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_DayAction.remove),
                  child: Text(str.removeWord,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(str.cancel,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: c.textMuted)),
              ),
              TextButton(
                onPressed: canSave ? save : null,
                child: Text(str.save,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: canSave ? c.accent : c.textFaint)),
              ),
            ],
          );
        },
      ),
    );

    final repo = ref.read(workDaysRepositoryProvider);
    switch (result) {
      case _DayAction.save:
        await repo.setDay(day, amount: parseAmount(controller.text));
      case _DayAction.remove:
        await repo.removeDay(day);
      case null:
        break;
    }
  }
}

enum _DayAction { save, remove }

/// Üstteki özet kartı — yüzey kart + küçük etiket + büyük tabular sayı.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subline,
    this.unit,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subline;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * 24,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: valueColor,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textFaint),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.workDays,
    required this.today,
    required this.weekdays,
    required this.onTap,
  });

  final DateTime month;
  final Map<DateTime, double?> workDays;
  final DateTime today;
  final List<String> weekdays;
  final ValueChanged<DateTime> onTap;

  /// Kazanca göre ısı seviyesi (0 = boş … 4 = ayın zirvesi).
  int _heatLevel(double amount, double maxAmount) {
    if (amount <= 0 || maxAmount <= 0) return 1;
    final r = amount / maxAmount;
    if (r >= 0.999) return 4;
    if (r >= 0.66) return 3;
    if (r >= 0.33) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Понедельник — первый день недели.
    final leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;

    final maxAmount = workDays.values
        .fold<double>(0, (m, a) => (a ?? 0) > m ? (a ?? 0) : m);
    final heats = [c.heat0, c.heat1, c.heat2, c.heat3, c.heat4];

    return Column(
      children: [
        Row(
          children: [
            for (final name in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textFaint,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: leadingEmpty + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingEmpty) return const SizedBox.shrink();
            final day =
                DateTime(month.year, month.month, index - leadingEmpty + 1);
            final isWorked = workDays.containsKey(day);
            final amount = workDays[day];
            final isToday = day == today;
            final isFuture = day.isAfter(today);

            // Geçmiş/bugün: kazanç ısısı. Gelecek plan: amber. Boş: heat0.
            final level =
                isWorked && !isFuture ? _heatLevel(amount ?? 0, maxAmount) : 0;
            final Color fill;
            final Color numColor;
            final Color amountColor;
            if (isWorked && isFuture) {
              fill = c.amberBg;
              numColor = c.amber;
              amountColor = c.amber;
            } else if (isWorked) {
              fill = heats[level];
              numColor = level >= 3 ? Colors.white : c.accentInk;
              amountColor = level >= 3
                  ? Colors.white.withValues(alpha: 0.85)
                  : (level >= 2 ? c.accentInk : c.textMuted);
            } else {
              fill = c.heat0;
              numColor = c.textFaint;
              amountColor = c.textFaint;
            }

            // Bugün: accent halka (export: 0 0 0 2px bg, 0 0 0 3.5px accent).
            final ring = isToday
                ? [
                    BoxShadow(color: c.bg, spreadRadius: 2),
                    BoxShadow(color: c.accent, spreadRadius: 3.5),
                  ]
                : null;

            return InkWell(
              onTap: () => onTap(day),
              borderRadius: BorderRadius.circular(BudgyRadii.icon),
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(BudgyRadii.icon),
                  boxShadow: ring,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isWorked || isToday
                            ? FontWeight.w700
                            : (isFuture ? FontWeight.w500 : FontWeight.w600),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: !isWorked && isFuture
                            ? numColor.withValues(alpha: 0.55)
                            : numColor,
                      ),
                    ),
                    // Заработок этого дня — прямо в ячейке.
                    if (isWorked && amount != null && amount > 0) ...[
                      const SizedBox(height: 1),
                      Text(
                        formatMoneyCompact(amount),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: amountColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Altta sabit "bugün" kartı — bugünkü kazancı işaretle/düzenle.
/// Aynı gün-düzenleme akışını açar (davranış değişmedi, sadece giriş noktası).
class _TodayBar extends ConsumerWidget {
  const _TodayBar({
    required this.today,
    required this.amount,
    required this.isMarked,
    required this.onTap,
  });

  final DateTime today;
  final double? amount;
  final bool isMarked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final hasAmount = isMarked && amount != null && amount! > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: c.tabbar,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Material(
        color: c.accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${str.today.toUpperCase()} · '
                        '${DateFormat('d MMM', str.localeCode).format(today)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.02 * 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAmount
                            ? formatMoney(amount!)
                            : curText(str.dayEarningsHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.01 * 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isMarked ? Icons.edit_rounded : Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

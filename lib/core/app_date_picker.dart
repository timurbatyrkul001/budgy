import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'ex_style.dart';

/// Budgy tarih seçici (koyu, HAFTA PAZARTESİ). Material showDatePicker
/// yerine kullanılır. Başlıkta "bugün" kısayolu ([todayLabel]) — hızlı
/// girişte tarihi anında bugüne almak için.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required String localeCode,
  String? title,
  String? todayLabel,
}) {
  return showExSheet<DateTime>(
    context,
    _AppDatePicker(
      initial: initial,
      first: first,
      last: last,
      localeCode: localeCode,
      title: title,
      todayLabel: todayLabel,
    ),
  );
}

class _AppDatePicker extends StatefulWidget {
  const _AppDatePicker({
    required this.initial,
    required this.first,
    required this.last,
    required this.localeCode,
    this.title,
    this.todayLabel,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String localeCode;
  final String? title;
  final String? todayLabel;

  @override
  State<_AppDatePicker> createState() => _AppDatePickerState();
}

class _AppDatePickerState extends State<_AppDatePicker> {
  late DateTime _visible; // gösterilen ayın 1'i
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = _dateOnly(widget.initial);
    _visible = DateTime(_selected.year, _selected.month);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _enabled(DateTime d) =>
      !d.isBefore(_dateOnly(widget.first)) &&
      !d.isAfter(_dateOnly(widget.last));

  bool get _canPrev => DateTime(_visible.year, _visible.month, 1)
      .isAfter(DateTime(widget.first.year, widget.first.month, 1));
  bool get _canNext => DateTime(_visible.year, _visible.month, 1)
      .isBefore(DateTime(widget.last.year, widget.last.month, 1));

  @override
  Widget build(BuildContext context) {
    // Pazartesi-başlangıçlı kısa gün adları (Pzt, Sal...).
    final monday = DateTime(2024, 1, 1); // Pazartesi
    final dow = [
      for (var i = 0; i < 7; i++)
        DateFormat('E', widget.localeCode).format(monday.add(Duration(days: i)))
    ];

    final firstOfMonth = DateTime(_visible.year, _visible.month, 1);
    final daysInMonth = DateTime(_visible.year, _visible.month + 1, 0).day;
    final leading = (firstOfMonth.weekday - 1) % 7; // Pzt=0 ofset
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_visible.year, _visible.month, d),
    ];

    final today = _dateOnly(DateTime.now());
    final monthLabel = toBeginningOfSentenceCase(
        DateFormat('LLLL yyyy', widget.localeCode).format(_visible));

    return SheetFrame(
      title: widget.title ?? monthLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ay gezinme + "bugün" kısayolu.
          Row(
            children: [
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                onTap: _canPrev
                    ? () => setState(() =>
                        _visible = DateTime(_visible.year, _visible.month - 1))
                    : null,
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ex.text),
                ),
              ),
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _canNext
                    ? () => setState(() =>
                        _visible = DateTime(_visible.year, _visible.month + 1))
                    : null,
              ),
            ],
          ),
          if (widget.todayLabel != null && _enabled(today)) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TintChipButton(
                label: widget.todayLabel!,
                onTap: () => Navigator.of(context).pop(today),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Gün başlıkları
          Row(
            children: [
              for (final name in dow)
                Expanded(
                  child: Center(
                    child: Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Ex.textFaint),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Gün ızgarası
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final day in cells)
                if (day == null)
                  const SizedBox()
                else
                  _DayCell(
                    day: day,
                    selected: day == _selected,
                    isToday: day == today,
                    enabled: _enabled(day),
                    onTap: () => setState(() => _selected = day),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: MaterialLocalizations.of(context).okButtonLabel,
            onTap: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? Ex.textFaint
        : selected
            ? Ex.onBrand
            : Ex.text;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Ex.brand : Colors.transparent,
            borderRadius: Ex.squircle(38),
            border: isToday && !selected
                ? Border.all(color: Ex.mint, width: 1.5)
                : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Ex.iconRadius),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Ex.surfaceHi,
          borderRadius: BorderRadius.circular(Ex.iconRadius),
        ),
        child: Icon(icon,
            size: 22, color: onTap == null ? Ex.textFaint : Ex.text),
      ),
    );
  }
}

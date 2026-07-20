import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'palette.dart';

/// Uygulama temasına uygun (indigo, minimal) tarih seçici — HAFTA PAZARTESİ.
/// Material showDatePicker yerine kullanılır.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required String localeCode,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AppDatePicker(
      initial: initial,
      first: first,
      last: last,
      localeCode: localeCode,
    ),
  );
}

class _AppDatePicker extends StatefulWidget {
  const _AppDatePicker({
    required this.initial,
    required this.first,
    required this.last,
    required this.localeCode,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String localeCode;

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
      !d.isBefore(_dateOnly(widget.first)) && !d.isAfter(_dateOnly(widget.last));

  bool get _canPrev =>
      DateTime(_visible.year, _visible.month, 1)
          .isAfter(DateTime(widget.first.year, widget.first.month, 1));
  bool get _canNext =>
      DateTime(_visible.year, _visible.month, 1)
          .isBefore(DateTime(widget.last.year, widget.last.month, 1));

  @override
  Widget build(BuildContext context) {
    // Pazartesi-başlangıçlı kısa gün adları (Pzt, Sal...).
    final monday = DateTime(2024, 1, 1); // Pazartesi
    final dow = [
      for (var i = 0; i < 7; i++)
        DateFormat('E', widget.localeCode)
            .format(monday.add(Duration(days: i)))
    ];

    final firstOfMonth = DateTime(_visible.year, _visible.month, 1);
    final daysInMonth = DateTime(_visible.year, _visible.month + 1, 0).day;
    final leading = (firstOfMonth.weekday - 1) % 7; // Pzt=0 ofset
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_visible.year, _visible.month, d),
    ];

    final now = DateTime.now();
    final today = _dateOnly(now);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık: ay yıl + ‹ ›
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', widget.localeCode).format(_visible),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: _canPrev
                      ? () => setState(() => _visible =
                          DateTime(_visible.year, _visible.month - 1))
                      : null,
                ),
                const SizedBox(width: 8),
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: _canNext
                      ? () => setState(() => _visible =
                          DateTime(_visible.year, _visible.month + 1))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Gün başlıkları
            Row(
              children: [
                for (final name in dow)
                  Expanded(
                    child: Center(
                      child: Text(
                        name.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28))),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(MaterialLocalizations.of(context)
                        .cancelButtonLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28))),
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                        MaterialLocalizations.of(context).okButtonLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    Color textColor;
    if (!enabled) {
      textColor = Colors.grey.shade300;
    } else if (selected) {
      textColor = Colors.white;
    } else {
      textColor = ink;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !selected
                ? Border.all(color: accent, width: 1.5)
                : null,
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
            color: Color(0xFFF1F2F5), shape: BoxShape.circle),
        child: Icon(icon,
            size: 22, color: onTap == null ? Colors.grey.shade300 : inkMuted),
      ),
    );
  }
}

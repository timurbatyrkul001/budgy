import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/palette.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../../core/feedback.dart';

/// Zarfa doğrudan para ekleme (gelir). Birikim zarflarına önceki birikimi
/// veya yeni parayı eklemek için. Tutar zarfın para biriminde.
Future<void> showAddFundsSheet(BuildContext context, Envelope envelope) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddFundsSheet(envelope: envelope),
  );
}

class _AddFundsSheet extends ConsumerStatefulWidget {
  const _AddFundsSheet({required this.envelope});
  final Envelope envelope;

  @override
  ConsumerState<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<_AddFundsSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) return;
    final str = ref.read(strProvider);
    setState(() => _saving = true);
    final ok = await guardWrite(context, str, () {
      return ref.read(budgetRepositoryProvider).addEnvelopeIncome(
            envelopeId: widget.envelope.id,
            envelopeName: widget.envelope.displayName(str),
            amount: amount,
            currency: widget.envelope.currency,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            date: _date,
          );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final symbol = kCurrencies[widget.envelope.currency] ?? '\$';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canSave = parseAmount(_amount.text) != null && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text('${widget.envelope.emoji}  ${str.addFundsTitle}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          // Tutar (zarf birimi)
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              prefixText: '$symbol  ',
              prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500),
              hintText: '0',
              filled: true,
              fillColor: const Color(0xFFF7F6FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tarih
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                initial: _date,
                first: DateTime(now.year - 5),
                last: today,
                localeCode: str.localeCode,
              );
              if (picked != null) {
                setState(() => _date = DateTime(
                    picked.year, picked.month, picked.day));
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 18, color: inkMuted),
                  const SizedBox(width: 12),
                  Text(
                    _date == today
                        ? str.today
                        : DateFormat('d MMMM yyyy', str.localeCode)
                            .format(_date),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Not
          TextField(
            controller: _note,
            decoration: InputDecoration(
              hintText: str.noteHint,
              filled: true,
              fillColor: const Color(0xFFF7F6FB),
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
                backgroundColor: accent,
                disabledBackgroundColor: accent.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: canSave ? _save : null,
              child: Text(_saving ? '...' : str.save),
            ),
          ),
        ],
      ),
    );
  }
}

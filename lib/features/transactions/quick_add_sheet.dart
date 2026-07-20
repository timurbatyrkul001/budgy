import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope_l10n.dart';
import 'new_transaction_sheet.dart';

/// Hızlı harcama: tutar tuş takımı + kategori çipleri → 2-3 dokunuşta kaydet.
/// Elle giriş sürtünmesini azaltır. Gelir/transfer için "Detaylı giriş".
Future<void> showQuickAdd(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet();

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  String _amt = '';
  String? _envelopeId;
  bool _saving = false;

  void _tap(String d) {
    setState(() {
      if (d == '⌫') {
        if (_amt.isNotEmpty) _amt = _amt.substring(0, _amt.length - 1);
      } else if (d == '.') {
        if (!_amt.contains('.') && _amt.isNotEmpty) _amt += '.';
      } else {
        if (_amt.length >= 9) return;
        if (_amt == '0') {
          _amt = d;
        } else {
          _amt += d;
        }
      }
    });
  }

  Future<void> _save() async {
    final amount = parseAmount(_amt);
    if (amount == null || _envelopeId == null) return;
    final str = ref.read(strProvider);
    final env = (ref.read(envelopesProvider).value ?? [])
        .firstWhere((e) => e.id == _envelopeId);
    setState(() => _saving = true);
    try {
      await ref.read(budgetRepositoryProvider).addExpense(
            envelopeId: env.id,
            envelopeName: env.displayName(str),
            amount: amount,
            currency: env.currency,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    // Harcama kategorileri: TL, arşivsiz, hedef değil.
    final cats = (ref.watch(envelopesProvider).value ?? [])
        .where((e) => e.currency == 'TRY' && !e.archived && !e.isGoal)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final canSave =
        parseAmount(_amt) != null && _envelopeId != null && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(str.quickAddTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showNewTransaction(context);
                },
                child: Text(str.detailedEntry),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tutar
          Center(
            child: Text(
              _amt.isEmpty ? '₺ 0' : '₺ $_amt',
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w800, color: c.text),
            ),
          ),
          const SizedBox(height: 16),
          // Kategori çipleri
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in cats)
                ChoiceChip(
                  label: Text('${e.emoji} ${e.displayName(str)}'),
                  selected: _envelopeId == e.id,
                  showCheckmark: false,
                  selectedColor: c.accent.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _envelopeId = e.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Tuş takımı
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['.', '0', '⌫'],
          ])
            Row(
              children: [
                for (final d in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _PadKey(label: d, onTap: () => _tap(d)),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
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

class _PadKey extends StatelessWidget {
  const _PadKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Center(
            child: label == '⌫'
                ? Icon(Icons.backspace_outlined, size: 22, color: c.text)
                : Text(label,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
          ),
        ),
      ),
    );
  }
}

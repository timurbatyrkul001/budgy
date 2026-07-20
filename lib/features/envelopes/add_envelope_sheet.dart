import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_l10n.dart';

const _emojis = [
  // Ev & faturalar
  '🏠', '🏡', '🔌', '💡', '🧾', '📱', '🌐',
  // Yeme-içme
  '🍔', '🍕', '🍽️', '☕', '🍻', '🍷', '🥗', '🍫',
  // Dışarı / eğlence / date
  '🎬', '🍿', '🎮', '🎸', '🎤', '🎉', '❤️', '💑', '🌹', '🎢', '🎳',
  // Alışveriş & kişisel
  '🛍️', '👕', '👗', '👟', '💄', '💇', '⌚',
  // Sağlık & spor
  '💊', '🏥', '🦷', '💪', '⚽', '🚴',
  // Ulaşım & seyahat
  '✈️', '🚗', '⛽', '🚕', '🚌', '🏖️', '🏨',
  // Eğitim & iş
  '📚', '💻', '✏️',
  // Aile & evcil
  '🎁', '🧸', '🍼', '🐶', '🐱',
  // Para & birikim
  '💰', '💵', '🏦', '💳', '📈',
];

/// Создание нового конверта.
Future<void> showAddEnvelopeSheet(BuildContext context, int sortOrder) {
  return _show(context, sortOrder: sortOrder);
}

/// Редактирование существующего (название + эмодзи).
Future<void> showEditEnvelopeSheet(BuildContext context, Envelope envelope) {
  return _show(context, envelope: envelope);
}

Future<void> _show(BuildContext context,
    {int sortOrder = 0, Envelope? envelope}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _EnvelopeSheet(sortOrder: sortOrder, envelope: envelope),
  );
}

class _EnvelopeSheet extends ConsumerStatefulWidget {
  const _EnvelopeSheet({required this.sortOrder, this.envelope});

  final int sortOrder;
  final Envelope? envelope;

  @override
  ConsumerState<_EnvelopeSheet> createState() => _EnvelopeSheetState();
}

class _EnvelopeSheetState extends ConsumerState<_EnvelopeSheet> {
  late final _nameController = TextEditingController(
      text: widget.envelope?.displayName(ref.read(strProvider)) ?? '');
  final _emojiField = TextEditingController();
  final _emojiFocus = FocusNode();
  late String _emoji = widget.envelope?.emoji ?? _emojis.first;
  late String _currency = widget.envelope?.currency ?? 'TRY';

  bool get _isEditing => widget.envelope != null;

  @override
  void dispose() {
    _nameController.dispose();
    _emojiField.dispose();
    _emojiFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(budgetRepositoryProvider);
    if (_isEditing) {
      await repo.updateEnvelope(widget.envelope!.id,
          name: name, emoji: _emoji, currency: _currency);
    } else {
      await repo.addEnvelope(name, _emoji, widget.sortOrder,
          currency: _currency);
    }
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
            _isEditing ? str.editEnvelope : str.newEnvelope,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: str.nameHint),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          // Seçili emoji önizleme + kendi emojini yaz (telefon klavyesi).
          Row(
            children: [
              GestureDetector(
                onTap: () => _emojiFocus.requestFocus(),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.borderStrong),
                  ),
                  alignment: Alignment.center,
                  child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emojiField,
                  focusNode: _emojiFocus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22),
                  decoration: InputDecoration(hintText: str.customEmojiHint),
                  onChanged: (v) {
                    final chars = v.characters;
                    if (chars.isNotEmpty) {
                      setState(() => _emoji = chars.last);
                    }
                    _emojiField.clear();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Hazır emojiler (kısayol) → sınırlı yükseklikte kaydırılır alan.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in _emojis)
                    ChoiceChip(
                      label:
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                      selected: _emoji == emoji,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _emoji = emoji),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Para birimi seçici (₺ / $ / €).
          Text(str.currencyTitle,
              style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in kCurrencies.entries)
                ChoiceChip(
                  label: Text('${entry.value}  ${entry.key}'),
                  selected: _currency == entry.key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _currency = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(_isEditing ? str.save : str.create),
          ),
        ],
      ),
    );
  }
}

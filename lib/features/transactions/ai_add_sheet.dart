import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/ai/expense_parser.dart';
import '../../core/category_avatar.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../settings/app_settings.dart';
import '../settings/category_resolver.dart';
import 'quick_entry_screen.dart';

/// AI hızlı giriş: yaz ya da SÖYLE — "kahve 90, market 450" → hazır
/// işlemler. Sıkıcı kısmı (form doldurmayı) ortadan kaldıran ana akış;
/// klasik form "Detaylı giriş"te duruyor.
Future<void> showAiAdd(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AiAddSheet(),
  );
}

class _AiAddSheet extends ConsumerStatefulWidget {
  const _AiAddSheet();

  @override
  ConsumerState<_AiAddSheet> createState() => _AiAddSheetState();
}

class _AiAddSheetState extends ConsumerState<_AiAddSheet> {
  final _controller = TextEditingController();
  final _parser = ExpenseParser();
  final _speech = SpeechToText();

  List<ParsedItem> _items = const [];
  bool _parsing = false;
  bool _saving = false;
  bool _listening = false;

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  // ── ses ───────────────────────────────────────────────────────────────

  /// Konuşmayı cihaz üzerinde metne çevirir (ücretsiz, native STT);
  /// metin sonra normal parse yolundan geçer.
  Future<void> _toggleListening() async {
    final str = ref.read(strProvider);
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      _parse();
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _listening) {
            setState(() => _listening = false);
            _parse();
          }
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (mounted) showErrorSnack(context, str.aiVoiceUnavailable);
      return;
    }
    setState(() => _listening = true);
    // Konuşma dili: Ayarlar → Sesli giriş dili; yoksa uygulama dili.
    final localeId = ref.read(voiceLocaleProvider) ??
        voiceLocaleFor(ref.read(strProvider).localeCode);
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: localeId,
      ),
      onResult: (result) {
        _controller.text = result.recognizedWords;
      },
    );
  }

  // ── parse & save ──────────────────────────────────────────────────────

  Future<void> _parse() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final str = ref.read(strProvider);
    final envelopes = ref
        .read(allocatableEnvelopesProvider)
        .forParser((e) => e.displayName(str));

    setState(() {
      _parsing = true;
      _items = const [];
    });
    final items = await _parser.parse(
      text,
      envelopes: envelopes,
      languageCode: str.localeCode,
      resolveCategory: categoryResolverSync(ref),
    );
    if (!mounted) return;
    setState(() {
      _parsing = false;
      _items = items;
    });
    if (items.isEmpty) showErrorSnack(context, str.aiNothingFound);
  }

  Future<void> _saveAll() async {
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    setState(() => _saving = true);
    try {
      for (final item in _items) {
        if (item.kind == 'income') {
          await repo.addCashIncome(
            amount: item.amount,
            note: item.note.isEmpty ? null : item.note,
          );
        } else {
          await repo.addExpense(
            envelopeId: item.envelopeId,
            envelopeName: item.envelopeName,
            amount: item.amount,
            note: item.note.isEmpty ? null : item.note,
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showErrorSnack(context, str.errorSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(str.aiAddTitle,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showQuickEntry(context);
                },
                child: Text(str.detailedEntry),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            str.aiAddHint,
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
          const SizedBox(height: 12),

          // ── giriş satırı: metin + mikrofon ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _parse(),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: str.aiInputHint,
                    hintStyle:
                        TextStyle(fontSize: 14, color: c.textFaint),
                    filled: true,
                    fillColor: c.surface2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: c.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Mikrofon: basılıyken accent nabız rengi.
              Material(
                color: _listening ? c.accent : c.surface2,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleListening,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _listening ? Colors.white : c.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── sonuçlar ────────────────────────────────────────────────
          if (_parsing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isNotEmpty) ...[
            for (final (i, item) in _items.indexed)
              _ItemCard(
                item: item,
                onRemove: () => setState(() {
                  _items = [..._items]..removeAt(i);
                }),
              ),
            const SizedBox(height: 4),
          ],

          // ── eylem düğmesi ───────────────────────────────────────────
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
              onPressed: _saving || _parsing
                  ? null
                  : _items.isEmpty
                      ? _parse
                      : _saveAll,
              child: Text(
                _saving
                    ? '...'
                    : _items.isEmpty
                        ? str.aiParseAction
                        : tpl(str.aiSaveAllTpl, {'n': '${_items.length}'}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Çözülen tek işlemin kartı: yön simgesi + tutar + not + kategori çipi.
class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item, required this.onRemove});

  final ParsedItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final isIncome = item.kind == 'income';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (isIncome)
            Icon(Icons.arrow_downward_rounded, size: 18, color: c.accent)
          else
            switch ((ref.watch(envelopesProvider).value ?? const <Envelope>[])
                .where((e) => e.id == item.envelopeId)
                .firstOrNull) {
              final e? => CategoryAvatar(envelope: e, size: 32),
              null => const CategoryAvatar.none(size: 32),
            },
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isIncome ? '+' : '−'}${formatMoney(item.amount)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (item.note.isNotEmpty || item.envelopeName != null)
                  Text(
                    [
                      if (item.note.isNotEmpty) item.note,
                      if (item.envelopeName != null) item.envelopeName!
                      else if (!isIncome) str.withoutEnvelope,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.textMuted),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: c.textFaint),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

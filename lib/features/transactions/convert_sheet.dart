import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/fx.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../../core/feedback.dart';

/// Döviz çevir: verdiğin ₺ (kasadan/zarftan) → aldığın döviz (hedef zarf).
Future<void> showConvertSheet(BuildContext context, Envelope toEnvelope) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ConvertSheet(toEnvelope: toEnvelope),
  );
}

class _ConvertSheet extends ConsumerStatefulWidget {
  const _ConvertSheet({required this.toEnvelope});
  final Envelope toEnvelope;

  @override
  ConsumerState<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends ConsumerState<_ConvertSheet> {
  final _sent = TextEditingController();
  final _received = TextEditingController();
  bool _saving = false;
  double? _rate; // 1 ₺ kaç hedef döviz eder (TRY -> toCurrency)
  bool _loadingRate = true;

  @override
  void initState() {
    super.initState();
    _sent.addListener(_onSentChanged);
    _received.addListener(() => setState(() {}));
    _loadRate();
  }

  Future<void> _loadRate() async {
    setState(() => _loadingRate = true);
    final r = await fetchFxRate('TRY', widget.toEnvelope.currency);
    if (!mounted) return;
    setState(() {
      _rate = r;
      _loadingRate = false;
    });
    _onSentChanged(); // mevcut ₺ değerinden $'ı tazele
  }

  /// ₺ değiştikçe hedef döviz alanını güncel kura göre otomatik doldur.
  /// (Kullanıcı $ alanını elle değiştirirse, ₺'ye dokunana kadar korunur.)
  void _onSentChanged() {
    final rate = _rate;
    final sent = parseAmount(_sent.text);
    if (rate != null && sent != null) {
      final text = _formatAuto(sent * rate);
      if (_received.text != text) {
        _received.text = text;
        _received.selection = TextSelection.collapsed(offset: text.length);
      }
    }
    if (mounted) setState(() {});
  }

  String _formatAuto(double v) {
    final r = (v * 100).round() / 100;
    return r == r.roundToDouble()
        ? r.toStringAsFixed(0)
        : r.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _sent.dispose();
    _received.dispose();
    super.dispose();
  }

  bool get _canConvert =>
      parseAmount(_sent.text) != null &&
      parseAmount(_received.text) != null &&
      !_saving;

  Future<void> _convert() async {
    final sent = parseAmount(_sent.text);
    final received = parseAmount(_received.text);
    if (sent == null || received == null) return;
    final str = ref.read(strProvider);

    setState(() => _saving = true);
    try {
      // Cüzdan modeli: ₺ her zaman cüzdandan çıkar, kaynak seçimi yok.
      await ref.read(budgetRepositoryProvider).convert(
            sentAmount: sent,
            toId: widget.toEnvelope.id,
            toName: widget.toEnvelope.displayName(str),
            toCurrency: widget.toEnvelope.currency,
            receivedAmount: received,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError(str.errorSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (mounted) showErrorSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(strProvider);
    final c = context.budgy;
    final cash = ref.watch(cashBalanceProvider).value ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(str.convertTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 20),
          // Verdiğin (₺) — kaynak her zaman cüzdan.
          Text(str.giveLabel,
              style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('💸', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(str.pocketName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text(
                  formatMoneyIn(cash, 'TRY'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _AmountField(controller: _sent, symbol: '₺'),
          const SizedBox(height: 20),
          // Aldığın (döviz) — hedef sabit + tutar
          Text(str.getLabel,
              style: TextStyle(fontSize: 13, color: c.textMuted)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text('${widget.toEnvelope.emoji}  ',
                    style: const TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(widget.toEnvelope.displayName(str),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _AmountField(
            controller: _received,
            symbol: kCurrencies[widget.toEnvelope.currency] ?? '\$',
          ),
          const SizedBox(height: 10),
          _RateLine(
            rate: _rate,
            loading: _loadingRate,
            toCurrency: widget.toEnvelope.currency,
            onRefresh: _loadRate,
            str: str,
          ),
          const SizedBox(height: 24),
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
              onPressed: _canConvert ? _convert : null,
              child: Text(_saving ? '...' : str.convertAction),
            ),
          ),
        ],
        ),
      ),
    );
  }

}

/// "1 $ = 32.45 ₺ · güncel kur" + yenile. Kur yoksa elle gir uyarısı.
class _RateLine extends StatelessWidget {
  const _RateLine({
    required this.rate,
    required this.loading,
    required this.toCurrency,
    required this.onRefresh,
    required this.str,
  });

  final double? rate;
  final bool loading;
  final String toCurrency;
  final VoidCallback onRefresh;
  final Strings str;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final toSymbol = kCurrencies[toCurrency] ?? '\$';
    final style = TextStyle(fontSize: 13, color: c.textMuted);

    Widget content;
    if (loading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(str.rateHint, style: style),
        ],
      );
    } else if (rate == null || rate == 0) {
      content = Text(str.rateUnavailable,
          style: style.copyWith(color: c.amber));
    } else {
      // rate = TRY başına döviz; 1 döviz = 1/rate ₺.
      final perUnit = 1 / rate!;
      content = Text(
        '1 $toSymbol = ${formatMoneyIn(perUnit, 'TRY')} · ${str.rateHint}',
        style: style,
      );
    }

    return Row(
      children: [
        Expanded(child: content),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: loading ? null : onRefresh,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.refresh_rounded, size: 18, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.symbol});
  final TextEditingController controller;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        prefixText: '$symbol  ',
        prefixStyle: TextStyle(
            fontSize: 22,
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
    );
  }
}

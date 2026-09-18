import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';

/// Para birimi seçimi — tam ekran: sembol kutusu + ad + kod + seçili işareti.
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class CurrencyScreen extends ConsumerWidget {
  const CurrencyScreen({super.key});

  /// Para biriminin İngilizce adı (özel isim gibi, çevrilmez).
  static const _names = {
    'TRY': 'Turkish Lira',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'RUB': 'Russian Ruble',
    'KZT': 'Kazakhstani Tenge',
    'GBP': 'British Pound',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final current = ref.watch(currencyProvider).value ?? 'TRY';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
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
              ),
            ),
            const SizedBox(height: 12),
            Text(str.currencyTitle,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.5)),
            const SizedBox(height: 18),
            for (final entry in kCurrencies.entries) ...[
              _CurrencyRow(
                symbol: entry.value,
                name: _names[entry.key] ?? entry.key,
                code: entry.key,
                selected: entry.key == current,
                onTap: () {
                  ref.read(budgetRepositoryProvider).setCurrency(entry.key);
                  Navigator.of(context).maybePop();
                },
              ),
              const SizedBox(height: 11),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tek para birimi satırı: sembol kutusu + ad + kod + seçim halkası.
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.symbol,
    required this.name,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String symbol;
  final String name;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        side: selected
            ? BorderSide(color: c.accent, width: 2)
            : BorderSide(color: c.borderStrong),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.envMarket : c.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(symbol,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: selected ? c.accentStrong : c.textMuted)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    const SizedBox(height: 1),
                    Text(code,
                        style:
                            TextStyle(fontSize: 12.5, color: c.textMuted)),
                  ],
                ),
              ),
              _SelectionMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seçim halkası: seçiliyse accent zeminde beyaz tik, değilse boş çember.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.accent : null,
        border: selected ? null : Border.all(color: c.borderStrong, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}

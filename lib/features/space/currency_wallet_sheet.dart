import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import 'space.dart';

/// Eklenecek döviz cüzdanı taslağı: kod + başlangıç tutarı (0 olabilir).
class CurrencyWalletDraft {
  const CurrencyWalletDraft({required this.code, required this.amount});

  final String code;
  final double amount;
}

/// Döviz cüzdanı simgesi: dolar/euro/sterlin için kendi banknotu.
String walletEmojiFor(String code) => switch (code) {
      'USD' => '💵',
      'EUR' => '💶',
      'GBP' => '💷',
      _ => '💰',
    };

/// Döviz cüzdanı adı: "USD cüzdanı" / "USD wallet" / "Кошелёк USD".
String walletNameFor(RS rs, String code) =>
    tpl(rs.currencyWalletTpl, {'code': code});

/// "+ Döviz cüzdanı ekle" sayfası: para birimi ([exclude] dışındakiler) +
/// isteğe bağlı tutar. Kaydetme çağıranın işi (onboarding'de taslak,
/// ana ekranda Firestore).
Future<CurrencyWalletDraft?> showCurrencyWalletSheet(
  BuildContext context, {
  required Set<String> exclude,
}) =>
    showExSheet(context, _CurrencyWalletSheet(exclude: exclude));

class _CurrencyWalletSheet extends ConsumerStatefulWidget {
  const _CurrencyWalletSheet({required this.exclude});

  final Set<String> exclude;

  @override
  ConsumerState<_CurrencyWalletSheet> createState() =>
      _CurrencyWalletSheetState();
}

class _CurrencyWalletSheetState extends ConsumerState<_CurrencyWalletSheet> {
  final _amount = TextEditingController();
  String? _code;

  @override
  void initState() {
    super.initState();
    // İlk uygun para birimi ön seçili — kullanıcı tek dokunuşla geçebilsin.
    _code = kCurrencies.keys
        .where((c) => !widget.exclude.contains(c))
        .firstOrNull;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final code = await showCurrencyPicker(context,
        selected: _code ?? '', exclude: widget.exclude);
    if (code != null) setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final code = _code;
    // Başındaki "+ " başlıkta gereksiz.
    final title = rs.addCurrencyWallet.replaceFirst(RegExp(r'^\+\s*'), '');

    return SheetFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(rs.currency),
          if (code == null)
            Text(rs.ratesUnavailable,
                style: const TextStyle(color: Ex.textSoft))
          else
            CurrencyTile(code: code, selected: false, onTap: _pick),
          FieldLabel(rs.amount),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Ex.text, fontWeight: FontWeight.w700, fontSize: 18),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: code == null ? null : kCurrencies[code],
              suffixStyle: const TextStyle(color: Ex.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: rs.save,
            onTap: code == null
                ? null
                : () => Navigator.of(context).pop(CurrencyWalletDraft(
                      code: code,
                      // Boş ya da geçersiz tutar = 0 (yalnız cüzdan açılır).
                      amount: parseAmount(_amount.text) ?? 0,
                    )),
          ),
        ],
      ),
    );
  }
}

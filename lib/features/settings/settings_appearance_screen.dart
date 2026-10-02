import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../home/fx_providers.dart';
import '../profile/currency_screen.dart';
import '../profile/language_screen.dart';
import 'app_settings.dart';
import 'settings_hub.dart';
import 'voice_language_screen.dart';

/// Görünüm — hub'daki "Uygulama" bölümünün alt ekranı.
///
/// Budgy'nin nasıl göründüğü ve konuştuğu: tuş takımı düzeni, dil, para
/// birimi, sesli giriş dili. Hepsi tek kartta: dördü de "tercih" türünden,
/// hiçbiri tehlikeli değil ve her satır sağda mevcut değerini gösteriyor —
/// kullanıcı ekrana girmeden ne seçili olduğunu görür.
class SettingsAppearanceScreen extends ConsumerWidget {
  const SettingsAppearanceScreen({super.key});

  Future<void> _pickKeypad(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final onTop = ref.read(keypadOneTwoThreeOnTopProvider);
    final picked = await showExSheet<bool>(
      context,
      SheetFrame(
        title: rs.keypadLayout,
        child: Column(
          children: [
            _OptionRow(
                label: rs.keypadBottom,
                selected: !onTop,
                onTap: () => Navigator.of(context).pop(false)),
            _OptionRow(
                label: rs.keypadTop,
                selected: onTop,
                onTap: () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .saveProfile({'keypadLayout': picked ? 'top' : 'bottom'});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final language = ref.watch(languageProvider).value ?? AppLanguage.en;
    final currency = ref.watch(currencyCodeProvider);
    final keypadTop = ref.watch(keypadOneTwoThreeOnTopProvider);
    final voice = ref.watch(voiceLocaleProvider) ?? rs.voiceAppLanguage;

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.tune_rounded,
        title: rs.hubAppearance,
        body: rs.hubAppearanceBody,
      ),
      children: [
        SettingsCard(rows: [
          SettingsRow(
            icon: Icons.dialpad_rounded,
            title: rs.keypadLayout,
            value: keypadTop ? rs.keypadTop : rs.keypadBottom,
            onTap: () => _pickKeypad(context, ref),
          ),
          SettingsRow(
            icon: Icons.language_rounded,
            title: str.languageTitle,
            value: language.title,
            onTap: () => pushSettings(context, const LanguageScreen()),
          ),
          SettingsRow(
            icon: Icons.payments_rounded,
            title: str.currencyTitle,
            value: currency,
            onTap: () => pushSettings(context, const CurrencyScreen()),
          ),
          SettingsRow(
            icon: Icons.mic_rounded,
            title: rs.voiceLanguage,
            value: voice,
            onTap: () => pushSettings(context, const VoiceLanguageScreen()),
          ),
        ]),
      ],
    );
  }
}

/// Alt sayfadaki seçenek satırı (tuş takımı düzeni).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ExCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? Ex.mint : Ex.text)),
              ),
              if (selected) const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
            ],
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';

/// Dil seçimi — tam ekran: bayrak + dil adı + seçili işareti.
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  /// Dil koduna göre bayrak (çevrilmez — kimlik).
  static const _flags = {'tr': '🇹🇷', 'ru': '🇷🇺', 'en': '🇬🇧'};

  /// Dilin İngilizce adı (alt başlık; özel isim gibi, çevrilmez).
  static const _englishNames = {
    'tr': 'Turkish',
    'ru': 'Russian',
    'en': 'English',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final current = ref.watch(languageProvider).value ?? AppLanguage.en;

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
            Text(str.languageTitle,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.5)),
            const SizedBox(height: 18),
            for (final lang in AppLanguage.values) ...[
              _LanguageRow(
                flag: _flags[lang.code] ?? '🌐',
                title: lang.title,
                subtitle: _englishNames[lang.code] ?? lang.code.toUpperCase(),
                selected: lang == current,
                onTap: () {
                  ref.read(budgetRepositoryProvider).setLanguage(lang);
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

/// Tek dil satırı: bayrak + ad + İngilizce alt başlık + seçim halkası.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String flag;
  final String title;
  final String subtitle;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    const SizedBox(height: 1),
                    Text(subtitle,
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

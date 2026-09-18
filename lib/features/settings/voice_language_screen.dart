import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import 'app_settings.dart';

/// Sesli giriş dili: "Uygulama dili" (varsayılan) + cihazın STT dilleri
/// (aramalı). Seçim settings/main → voiceLocale.
class VoiceLanguageScreen extends ConsumerStatefulWidget {
  const VoiceLanguageScreen({super.key});

  @override
  ConsumerState<VoiceLanguageScreen> createState() => _VoiceLanguageScreenState();
}

class _VoiceLanguageScreenState extends ConsumerState<VoiceLanguageScreen> {
  List<LocaleName> _locales = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stt = SpeechToText();
      if (await stt.initialize()) {
        _locales = await stt.locales();
      }
    } catch (_) {
      // STT yoksa (simülatör/test) yalnız "uygulama dili" kalır.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String? localeId) =>
      ref.read(budgetRepositoryProvider).saveProfile({'voiceLocale': localeId});

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final current = ref.watch(voiceLocaleProvider);
    final q = _query.toLowerCase();
    final list = _locales
        .where((l) =>
            q.isEmpty ||
            l.name.toLowerCase().contains(q) ||
            l.localeId.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BudgyBackButton(),
                  Text(rs.voiceLanguage,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: Ex.text)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(color: Ex.text),
                    decoration: InputDecoration(
                      hintText: rs.searchLanguage,
                      prefixIcon: const Icon(Icons.search_rounded, color: Ex.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _Row(
                    title: rs.voiceAppLanguage,
                    subtitle: voiceLocaleFor(str.localeCode),
                    selected: current == null,
                    onTap: () => _set(null),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: Ex.mint)),
                    )
                  else
                    for (final l in list) ...[
                      _Row(
                        title: l.name,
                        subtitle: l.localeId,
                        selected: current == l.localeId,
                        onTap: () => _set(l.localeId),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? Ex.mint : Ex.text)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Ex.textMuted)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
        ],
      ),
    );
  }
}

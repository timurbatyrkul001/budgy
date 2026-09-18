import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/formatters.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/envelopes/budget_repository.dart';

class KopilkaApp extends ConsumerWidget {
  const KopilkaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Смена валюты меняет key — всё дерево пересобирается,
    // и каждый formatMoney подхватывает новый символ.
    final symbol = ref.watch(currencySymbolProvider);
    final lang = ref.watch(languageProvider).value ?? AppLanguage.en;
    // Sayı biçimi de dile bağlı: «1,234.5» / «1.234,5» / «1 234,5».
    moneyLocale = lang.code;

    return MaterialApp(
      title: 'Budgy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      // Yeni tasarım yalnız koyu — sistem ayarı ne olursa olsun.
      themeMode: ThemeMode.dark,
      // Material'in kendi metinleri (takvim, metin seçme menüsü, "Tamam"...)
      // uygulamanın diliyle aynı olsun.
      locale: Locale(lang.code),
      supportedLocales: [
        for (final l in AppLanguage.values) Locale(l.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: KeyedSubtree(
        // Dil ya da para birimi değişince biçimlendirilmiş her metin
        // yeniden üretilsin.
        key: ValueKey('$symbol|${lang.code}'),
        child: const AuthGate(),
      ),
    );
  }
}

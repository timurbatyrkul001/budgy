import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/formatters.dart';
import 'core/l10n.dart';
import 'core/theme.dart';
import 'core/tokens.dart';
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

    // Yüksek kontrast yalnız oturum varken okunur: [highContrastProvider]
    // repository'ye, o da uid'ye bağlı — girişten önce izlemek fırlatır.
    // Girişten önce zaten yalnız açılış ekranı var, varsayılan palet yeter.
    final signedIn = ref.watch(authStateProvider).value != null;
    final highContrast =
        signedIn && (ref.watch(highContrastProvider).value ?? false);
    final theme = _themeFor(highContrast: highContrast);

    return MaterialApp(
      title: 'Budgy',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      // Tek tema: afişin kâğıdı. Sistem ayarı ne olursa olsun aynı.
      themeMode: ThemeMode.light,
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

/// Tema iskeleti [buildTheme]'den; yalnız [BudgyColors] uzantısı ayara göre
/// seçilir. `copyWith` ile: theme.dart'taki kurucu özel ve tek paletle
/// çalışıyor, oraya parametre açmak yerine çıkan temanın uzantısını
/// değiştirmek yeterli — `context.budgy` zaten uzantıdan okuyor.
///
/// Ayırıcı rengi de palete uyar (SettingsCard ayırıcıları `Ex.border`
/// sabitiyle çizildiğinden onlar değişmez; bkz. BudgyColors.highContrast).
ThemeData _themeFor({required bool highContrast}) {
  final palette = BudgyColors.forContrast(high: highContrast);
  return buildTheme().copyWith(
    extensions: [palette],
    dividerColor: palette.border,
  );
}

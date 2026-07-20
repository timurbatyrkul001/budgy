import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return MaterialApp(
      title: 'Budgy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: KeyedSubtree(
        key: ValueKey(symbol),
        child: const AuthGate(),
      ),
    );
  }
}

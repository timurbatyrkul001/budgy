import 'package:flutter/material.dart';

import 'tokens.dart';

/// Yumuşak sayfa geçişi: fade + hafif yukarı kayma.
class _SmoothTransitions extends PageTransitionsBuilder {
  const _SmoothTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}

/// iOS'ta kenardan kaydırarak geri gitme Cupertino geçişinin içinde
/// geliyor; kendi geçişimizi koyunca o jest de gidiyordu. Yani uygulamada
/// HİÇBİR ekranda kaydırarak geri dönülemiyordu — geri düğmesi olmayan
/// bir ekran iOS kullanıcısı için kapan oluyordu.
///
/// Jesti elde tutup kendi animasyonumuzu sürdürmek Flutter'ın özel
/// (private) geri-jest kodunu kopyalamayı gerektiriyor. Onun yerine
/// iOS'ta sistemin kendi geçişini kullanıyoruz: alışıldık görünüm,
/// çalışan jest, sıfır bakım. Yumuşak geçiş Android'de kalıyor.
const _transitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: _SmoothTransitions(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);

/// Ortak tema iskeleti — [BudgyColors] token'larından hem açık hem koyu
/// için aynı biçimde kurulur.
ThemeData _build(BudgyColors c, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    // Uygulamanın tamamı afişin yazı karakterinde. Tek tek ekranlara
    // yazmak yerine burada: aksi hâlde sistem fontu (SF Pro) ile Inter
    // ekrandan ekrana karışıyordu. Kahraman rakamlar ayrıca 'InterDisplay'
    // ailesine geçiyor — o kesim büyük puntoda daha sıkı.
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.bg,
    pageTransitionsTheme: _transitions,
    extensions: [c],
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.surface,
      primary: c.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: c.text,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02 * 22,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BudgyRadii.card)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        // Yeşil üstünde koyu metin — beyaz, parlak yeşilde okunmuyordu.
        foregroundColor: const Color(0xFF04140D),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.borderStrong, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: TextStyle(color: c.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accent.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    dividerColor: c.border,
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface),
    dialogTheme: DialogThemeData(backgroundColor: c.surface),
  );
}

/// Tek tema — afiş dili: krem kâğıt, siyah mürekkep. Brightness.light
/// olmalı, yoksa Material'in kendi parçaları (takvim, menü, metin seçme)
/// koyu çizilip açık zeminde okunmaz oluyor.
ThemeData buildTheme() => _build(BudgyColors.dark, Brightness.light);

ThemeData buildDarkTheme() => buildTheme();

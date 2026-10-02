import 'package:flutter/material.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Budgy — "Sıcak Defter" tasarım sistemi.
///
/// Claude Design export'undan (Budgy—Günlük Kazanç Uygulaması) birebir
/// çıkarılan token'lar. Açık + koyu tema. Yeşil = para/büyüme (accent),
/// amber = günlük kazanç (semantik). Renkleri doğrudan sabit olarak değil,
/// [BudgyColors] ThemeExtension üzerinden okuyun ki tema değişince otomatik
/// güncellensin:
///
///   final c = Theme.of(context).extension&lt;BudgyColors&gt;()!;
///   color: c.accent
/// ────────────────────────────────────────────────────────────────────────
@immutable
class BudgyColors extends ThemeExtension<BudgyColors> {
  const BudgyColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentStrong,
    required this.accentInk,
    required this.amber,
    required this.amberBg,
    required this.border,
    required this.borderStrong,
    required this.track,
    required this.tabbar,
    required this.shadowColor,
    required this.heat0,
    required this.heat1,
    required this.heat2,
    required this.heat3,
    required this.heat4,
    required this.envKira,
    required this.envMarket,
    required this.envUlasim,
    required this.envKeyif,
    required this.envFatura,
    required this.envTatil,
    required this.envAraba,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color textMuted;
  final Color textFaint;

  final Color accent; // ana yeşil
  final Color accentStrong; // koyu yeşil (başlık/vurgu)
  final Color accentInk; // ısı-çubuğu üstündeki rakam rengi

  final Color amber; // günlük kazanç
  final Color amberBg; // "dağıtılmayı bekleyen" kart zemini

  final Color border;
  final Color borderStrong;
  final Color track; // progress bar zemini
  final Color tabbar; // alt bar (blur zemin)
  final Color shadowColor; // kart gölgesi rengi

  /// Haftalık kazanç ısı-haritası: boş → dolu.
  final Color heat0;
  final Color heat1;
  final Color heat2;
  final Color heat3;
  final Color heat4;

  /// Zarf kimlik tint'leri (kart ikon zemini).
  final Color envKira;
  final Color envMarket;
  final Color envUlasim;
  final Color envKeyif;
  final Color envFatura;
  final Color envTatil;
  final Color envAraba;

  /// Zarf tint'ini isme/indekse göre seç (yeni zarflar için döngüsel).
  List<Color> get envTints =>
      [envKira, envMarket, envUlasim, envKeyif, envFatura, envTatil, envAraba];
  Color envTintAt(int index) => envTints[index % envTints.length];

  /// Kart için standart gölge.
  List<BoxShadow> get cardShadow => [
        BoxShadow(color: shadowColor, blurRadius: 20, offset: const Offset(0, 6)),
      ];

  // ── "Dark emerald" (2026-09) ───────────────────────────────────────────
  // Uygulama artık yalnız koyu: [light] ve [dark] aynı palete işaret eder,
  // böylece `context.budgy` kullanan eski ekranlar tek tip görünür.
  static const light = dark;

  static const dark = BudgyColors(
    // Afiş dili (2026-10): krem kâğıt, siyah mürekkep, beyaz kart. Ad
    // "dark" olarak kaldı çünkü uygulama hâlâ tek temalı; değerler açık.
    bg: Color(0xFFFBFAF7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F0EA),
    text: Color(0xFF111111),
    textMuted: Color(0xFF76766F),
    textFaint: Color(0xFF9A9A94),
    accent: Color(0xFF17855D),
    // Açık zeminde vurgu metni: daha da koyu yeşil.
    accentStrong: Color(0xFF0E6B49),
    accentInk: Color(0xFF0B5540),
    amber: Color(0xFFA9700C),
    amberBg: Color(0xFFFBF1DD),
    border: Color(0xFFE7E5DE),
    borderStrong: Color(0xFFD4D1C8),
    track: Color(0xFFEDEBE4),
    tabbar: Color(0xF7FFFFFF),
    shadowColor: Color(0x14111111),
    // Isı haritası: kâğıttan markaya doğru.
    heat0: Color(0xFFF1F0EA),
    heat1: Color(0x2617855D),
    heat2: Color(0x5917855D),
    heat3: Color(0x9917855D),
    heat4: Color(0xFF17855D),
    // Kategori zeminleri: krem üstünde yumuşak pastel kâğıtlar.
    envKira: Color(0xFFE4EDF5),
    envMarket: Color(0xFFE2F0E7),
    envUlasim: Color(0xFFF6EEDC),
    envKeyif: Color(0xFFF7E6EC),
    envFatura: Color(0xFFEAE7F7),
    envTatil: Color(0xFFE0F0EC),
    envAraba: Color(0xFFE8EAEE),
  );

  @override
  BudgyColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? accent,
    Color? accentStrong,
    Color? accentInk,
    Color? amber,
    Color? amberBg,
    Color? border,
    Color? borderStrong,
    Color? track,
    Color? tabbar,
    Color? shadowColor,
    Color? heat0,
    Color? heat1,
    Color? heat2,
    Color? heat3,
    Color? heat4,
    Color? envKira,
    Color? envMarket,
    Color? envUlasim,
    Color? envKeyif,
    Color? envFatura,
    Color? envTatil,
    Color? envAraba,
  }) {
    return BudgyColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentInk: accentInk ?? this.accentInk,
      amber: amber ?? this.amber,
      amberBg: amberBg ?? this.amberBg,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      track: track ?? this.track,
      tabbar: tabbar ?? this.tabbar,
      shadowColor: shadowColor ?? this.shadowColor,
      heat0: heat0 ?? this.heat0,
      heat1: heat1 ?? this.heat1,
      heat2: heat2 ?? this.heat2,
      heat3: heat3 ?? this.heat3,
      heat4: heat4 ?? this.heat4,
      envKira: envKira ?? this.envKira,
      envMarket: envMarket ?? this.envMarket,
      envUlasim: envUlasim ?? this.envUlasim,
      envKeyif: envKeyif ?? this.envKeyif,
      envFatura: envFatura ?? this.envFatura,
      envTatil: envTatil ?? this.envTatil,
      envAraba: envAraba ?? this.envAraba,
    );
  }

  @override
  BudgyColors lerp(ThemeExtension<BudgyColors>? other, double t) {
    if (other is! BudgyColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BudgyColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textFaint: l(textFaint, other.textFaint),
      accent: l(accent, other.accent),
      accentStrong: l(accentStrong, other.accentStrong),
      accentInk: l(accentInk, other.accentInk),
      amber: l(amber, other.amber),
      amberBg: l(amberBg, other.amberBg),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      track: l(track, other.track),
      tabbar: l(tabbar, other.tabbar),
      shadowColor: l(shadowColor, other.shadowColor),
      heat0: l(heat0, other.heat0),
      heat1: l(heat1, other.heat1),
      heat2: l(heat2, other.heat2),
      heat3: l(heat3, other.heat3),
      heat4: l(heat4, other.heat4),
      envKira: l(envKira, other.envKira),
      envMarket: l(envMarket, other.envMarket),
      envUlasim: l(envUlasim, other.envUlasim),
      envKeyif: l(envKeyif, other.envKeyif),
      envFatura: l(envFatura, other.envFatura),
      envTatil: l(envTatil, other.envTatil),
      envAraba: l(envAraba, other.envAraba),
    );
  }
}

/// Kısayol: `context.budgy.accent`
extension BudgyColorsX on BuildContext {
  BudgyColors get budgy => Theme.of(this).extension<BudgyColors>()!;
}

/// Ortak yarıçap / boşluk ölçekleri (export'taki değerler).
abstract class BudgyRadii {
  static const card = 20.0;
  static const bigCard = 22.0;
  static const chip = 14.0;
  static const icon = 11.0;
  static const track = 4.0;
}

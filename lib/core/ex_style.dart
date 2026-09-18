import 'package:flutter/material.dart';

/// Budgy "dark emerald" tasarımı (2026-09): koyu zemin, üstte derin zümrüt
/// gradyan + sol üstten yeşil ışık, grafit kartlar (r20), yeşil dolgulu ana
/// buton (r16), köşeleri yumuşak kare ikon butonları (r14), squircle
/// avatarlar. Yeniden yazılan ekranlar (onboarding, ana ekran) bu sabitleri
/// ve widget'ları kullanır; eski ekranlar [BudgyColors] token'larıyla aynı
/// palete geçti.
abstract class Ex {
  static const bg = Color(0xFF070A09);
  static const surface = Color(0xFF151918);
  static const surfaceHi = Color(0xFF1F2422);
  static const sheet = Color(0xFF111413);
  static const border = Color(0xFF252B29);
  static const borderHi = Color(0xFF343B38);

  static const text = Color(0xFFFFFFFF);
  static const textSoft = Color(0xFFA7ADAA);
  static const textMuted = Color(0xFF8A918E);
  static const textFaint = Color(0xFF5B625F);

  /// Yeşil gradyan üstündeki ikincil metin.
  static const onGlowMuted = Color(0xFF9CC7B5);

  static const brand = Color(0xFF25BE86);
  static const onBrand = Color(0xFF04140D);
  static const mint = Color(0xFF7FE3B8);
  static const amber = Color(0xFFE3A94F);
  static const red = Color(0xFFFF6B6B);
  static const income = Color(0xFF4CD98A);

  static const glassFill = Color(0xCC0B2A20);
  static const glassBorder = Color(0x8025BE86);

  static const cardRadius = 20.0;
  static const buttonRadius = 16.0;
  static const iconRadius = 14.0;

  /// Squircle: kenarın ~%30'u kadar köşe.
  static BorderRadius squircle(double size) =>
      BorderRadius.circular(size * 0.3);

  /// Cüzdan renk seçenekleri — ilki marka yeşili.
  static const spaceColors = [
    Color(0xFF25BE86),
    Color(0xFF3FA9F5),
    Color(0xFF8B6CF6),
    Color(0xFFF56C9B),
    Color(0xFFFF7A59),
    Color(0xFFE3A94F),
    Color(0xFF2FC4C4),
    Color(0xFF8A918E),
  ];
}

/// Koyu zemin + üstte derin zümrüt gradyan ve SOL üstten yumuşak yeşil ışık.
class ExBackground extends StatelessWidget {
  const ExBackground({super.key, required this.child, this.glow = 0.5});

  final Widget child;

  /// Gradyanın ekran yüksekliğinin ne kadarını kapladığı.
  final double glow;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Ex.bg)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * glow,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F6E4D),
                  Color(0xFF0B4A35),
                  Color(0xFF07241A),
                  Ex.bg,
                ],
                stops: [0, 0.28, 0.62, 1],
              ),
            ),
          ),
        ),
        // Sol üstten vuran yeşil ışık — düz gradyanı canlandırır.
        Positioned(
          top: -size.height * 0.2,
          left: -size.width * 0.4,
          width: size.width * 1.3,
          height: size.height * 0.5,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x4025BE86), Color(0x0025BE86)],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// Onboarding ilerlemesi: ince, 3 parçalı çubuk (dolu = nane).
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: 4,
              decoration: BoxDecoration(
                color: i <= index ? Ex.mint : Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

BoxDecoration _glass(double radius) => BoxDecoration(
      color: Ex.glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Ex.glassBorder),
    );

/// Gradyan üstündeki köşeleri yumuşak kare "cam" ikon butonu.
class GlassSquareButton extends StatelessWidget {
  const GlassSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 21,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: _glass(Ex.iconRadius),
        child: Icon(icon, color: Ex.text, size: iconSize),
      ),
    );
  }
}

/// Gradyan üstündeki "cam" çip (cüzdan adı, kur).
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: padding,
        decoration: _glass(Ex.iconRadius),
        child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );
  }
}

/// Yeşil dolgulu ana buton (İleri, Başlayalım...).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Ex.brand,
          foregroundColor: Ex.onBrand,
          disabledBackgroundColor: Ex.brand.withValues(alpha: 0.35),
          disabledForegroundColor: Ex.onBrand.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Nane renkli metin butonu — ikincil eylem (Özelleştir, Başka para birimi).
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Ex.mint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Kart içindeki küçük yeşil-tonlu eylem çipi (Bütçe koy).
class TintChipButton extends StatelessWidget {
  const TintChipButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.brand.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Ex.mint),
          ),
        ),
      ),
    );
  }
}

/// Grafit kart.
class ExCard extends StatelessWidget {
  const ExCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Ex.surface,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ex.cardRadius),
        side: const BorderSide(color: Ex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Alt sayfa (bottom sheet) açıcı — koyu, üst köşeleri yuvarlak.
Future<T?> showExSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Ex.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}

/// Alt sayfa iskeleti: tutamak + başlık + kapat + içerik (klavyeye göre).
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.scroll = true,
  });

  final String title;
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: child,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Ex.borderHi,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: Ex.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Ex.surfaceHi,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close_rounded, size: 20, color: Ex.text),
              ),
            ],
          ),
        ),
        Flexible(
          child: scroll ? SingleChildScrollView(child: body) : body,
        ),
      ],
    );
  }
}

/// Bölüm etiketi (alt sayfalarda alan başlığı).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 18),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: Ex.textMuted),
      ),
    );
  }
}

/// Gradyanlı ekranlarda geri butonu (köşeleri yumuşak kare).
class ExBackButton extends StatelessWidget {
  const ExBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSquareButton(
      icon: Icons.arrow_back_rounded,
      size: 40,
      iconSize: 22,
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Düz zeminli eski ekranlarda geri butonu (menüden açılan Takvim,
/// İstatistik). Yalnız geri gidilebiliyorsa görünür.
class BudgyBackButton extends StatelessWidget {
  const BudgyBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Ex.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.iconRadius),
            side: const BorderSide(color: Ex.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Ex.iconRadius),
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back_rounded, size: 22, color: Ex.text),
            ),
          ),
        ),
      ),
    );
  }
}

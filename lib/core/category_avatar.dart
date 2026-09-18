import 'package:flutter/material.dart';

import '../features/envelopes/envelope.dart';
import 'category_visual.dart';
import 'ex_style.dart';

/// Tek kategori görseli — her yerde (seçici, işlem satırı, analiz, bütçe,
/// ayarlar, önizleme kartları) bu widget kullanılır; daire çizimi başka
/// yerde tekrarlanmaz.
///
/// * Katalog/preset anahtarı → renkli daire + beyaz simge.
/// * Kullanıcının kendi kategorisi → aynı daire, içinde emojisi, zemin
///   zarf id'sinden türeyen sabit ton (bkz. [envelopeTint]).
/// * Kategorisiz → soluk daire + soru işareti.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    this.envelope,
    this.catalogKey,
    this.emoji,
    this.tintSeed,
    this.size = 44,
    this.selected = false,
    this.muted = false,
  });

  /// Kategorisiz işlem/satır.
  const CategoryAvatar.none({super.key, this.size = 44})
      : envelope = null,
        catalogKey = null,
        emoji = null,
        tintSeed = null,
        selected = false,
        muted = false;

  final Envelope? envelope;
  final String? catalogKey;
  final String? emoji;

  /// Emoji için ton tohumu (zarf id yoksa).
  final String? tintSeed;
  final double size;

  /// Seçili: marka yeşili halka.
  final bool selected;

  /// Soluk (henüz eklenmemiş katalog maddesi / arşiv).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final visual = envelope != null
        ? visualForEnvelope(envelope!)
        : categoryVisual(catalogKey);
    final emojiText = envelope?.emoji ?? emoji;
    // Emojisiz kullanıcı kategorisi: adın baş harfi.
    final letter = envelope == null || envelope!.name.trim().isEmpty
        ? null
        : envelope!.name.trim().characters.first.toUpperCase();
    final isNone =
        visual == null && (emojiText == null || emojiText.isEmpty) && letter == null;
    // Kayıtlı renk her zaman önde (kullanıcı yeniden renklendirmiş olabilir).
    final stored = envelope == null ? null : envelopeColor(envelope!);

    final Color bg;
    final Widget glyph;
    if (visual != null) {
      bg = stored ?? visual.color;
      glyph = Icon(visual.icon, size: size * 0.5, color: Colors.white);
    } else if (isNone) {
      bg = Ex.surfaceHi;
      glyph = Icon(Icons.question_mark_rounded, size: size * 0.45, color: Ex.textMuted);
    } else if (emojiText == null || emojiText.isEmpty) {
      bg = stored ?? envelopeTint(tintSeed ?? letter!);
      glyph = Text(letter!,
          style: TextStyle(
              fontSize: size * 0.44, fontWeight: FontWeight.w800, color: Colors.white, height: 1));
    } else {
      bg = (stored ?? envelopeTint(tintSeed ?? emojiText)).withValues(alpha: 0.32);
      glyph = Text(emojiText, style: TextStyle(fontSize: size * 0.46, height: 1));
    }

    return Opacity(
      opacity: muted ? 0.45 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Ex.brand, width: 2.5) : null,
        ),
        child: glyph,
      ),
    );
  }
}

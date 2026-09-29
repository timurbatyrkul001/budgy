import 'package:flutter/material.dart';

/// Onboarding afişinin renkleri — TEK kaynak; `onboarding_flow.dart` ve
/// `intro_mockups.dart` buradan okur.
///
/// Onboarding pazarlama yüzü, uygulama ürün yüzü: afiş beyaz zemin + siyah
/// mürekkep kullanır ve bu ikisi `Ex` paletinde yok (uygulama koyu). Bilinçli
/// ayrım; yalnız onboarding'de geçerli. Marka yeşili (`Ex.brand`) vurgu
/// olarak kalır, kategori renkleri renk sözlüğü olduğu için aynen kullanılır.
abstract final class Poster {
  /// Kırık beyaz zemin.
  static const paper = Color(0xFFFBFAF7);

  /// Ana metin / düğme mürekkebi.
  static const ink = Color(0xFF111111);

  /// Gövde metni.
  static const inkSoft = Color(0xFF5C5C58);

  /// Yasal not, ipuçları, pasif simgeler.
  static const inkFaint = Color(0xFF9A9A94);
}

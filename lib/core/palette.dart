import 'package:flutter/material.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Budgy "beyaz afiş" paleti — eski ekranlar için geri-uyum sabitleri.
///
/// Yeni tasarım sistemi [BudgyColors] (tokens.dart) ve [Ex] (ex_style.dart)
/// üzerinden gelir. Bu dosya, henüz token'lara taşınmamış eski ekranların
/// (hedefler, bütçe hesapla, fon ekle, bakiye grafiği) krem kâğıt üstünde
/// aynı mürekkebi kullanması için var. Değerler Ex ile BİREBİR aynı tutulur:
/// burada ayrı bir ton üretmeyiz, yoksa eski ve yeni ekran arasında renk
/// kayar. Yeni/yeniden yazılan ekranlarda `context.budgy` ya da `Ex` kullanın.
///
/// Adlar bilinçli olarak korundu (çağrı yerleri değişmesin); birkaçı artık
/// anlamını mecazen taşıyor, yanlarında not var.
/// ────────────────────────────────────────────────────────────────────────

/// Marka yeşili (= Ex.brand). Buton dolgusu ve grafik çizgisi; eski #0F9E6C
/// krem üstünde ve altında beyaz yazıyla kontrastı kaybediyordu.
const accent = Color(0xFF17855D);

/// Koyu yeşil vurgu (= Ex.mint): kâğıt üstünde okunur ikincil yeşil.
const accentStrong = Color(0xFF0E6B49);

/// Günlük kazanç (= Ex.amber): açık zeminde "neon" durmasın diye koyultuldu.
const amber = Color(0xFFA9700C);

/// Mürekkep (= Ex.text).
const ink = Color(0xFF111111);

/// Adı "surface" ama krem kâğıt SAYFA zemini (= Ex.bg); kart beyazı değil.
const surface = Color(0xFFFBFAF7);

/// Gri metin (= Ex.textMuted) ve ikon kutusu zemini (= Ex.surfaceHi).
const inkMuted = Color(0xFF76766F);
const iconBg = Color(0xFFF1F0EA);

/// Zarf kartı kâğıt tint'leri — tokens'taki envKira…envAraba ile aynı
/// değer ve sıra; iki liste ayrışırsa aynı zarf iki ekranda farklı görünür.
const pastels = [
  Color(0xFFE4EDF5), // kira · mavi
  Color(0xFFE2F0E7), // market · yeşil
  Color(0xFFF6EEDC), // ulaşım · kum
  Color(0xFFF7E6EC), // keyif · pembe
  Color(0xFFEAE7F7), // fatura · lila
  Color(0xFFE0F0EC), // tatil · nane
  Color(0xFFE8EAEE), // araba · gri-mavi
];

/// Donut-grafik, legend noktası ve hedef ilerleme çubuğu için kategorik
/// palet. Adı "vivid" ama krem kâğıtta neon değil, mürekkep ağırlığında
/// tonlar: her biri Ex.bg üstünde ~4.5:1 kontrast verir, böylece aynı renk
/// hem dolgu hem etiket metni olarak kullanılabilir. Mavi/teal
/// [CategoryPalette] ile aynı değerler — kategori ve grafik aynı dili konuşsun.
const vivids = [
  Color(0xFF17855D), // yeşil (marka)
  Color(0xFFA9700C), // amber
  Color(0xFF2A6FB5), // mavi
  Color(0xFF6E5EB3), // lila
  Color(0xFFB04A7C), // gül
  Color(0xFF137A8A), // teal
];

Color pastelAt(int index) => pastels[index % pastels.length];
Color vividAt(int index) => vivids[index % vivids.length];

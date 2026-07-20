import 'package:flutter/material.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Budgy "Sıcak Defter" paleti (açık tema sabitleri).
///
/// Yeni tasarım sistemi [BudgyColors] (bkz. tokens.dart) üzerinden gelir ve
/// açık/koyu temayı destekler. Bu dosya, henüz token'lara taşınmamış eski
/// ekranların açık temada da yeni yeşil kimliği kullanması için geri-uyum
/// sağlar. Yeni/yeniden yazılan ekranlarda `context.budgy` kullanın.
/// ────────────────────────────────────────────────────────────────────────

const accent = Color(0xFF0F9E6C); // ana yeşil (para/büyüme)
const accentStrong = Color(0xFF0A6E4B); // koyu yeşil
const amber = Color(0xFFC67A17); // günlük kazanç (semantik)
const ink = Color(0xFF18211B); // koyu metin/ikon
const surface = Color(0xFFEEF2EC); // sıcak kırık-beyaz zemin

/// Gri metin ve ikon kutusu zeminleri.
const inkMuted = Color(0xFF66756B);
const iconBg = Color(0xFFF4F8F2);

/// Zarf kartı kimlik tint'leri (export'takiyle aynı sıra).
const pastels = [
  Color(0xFFDEE9F5), // kira · mavi
  Color(0xFFDCEEDD), // market · yeşil
  Color(0xFFF5E9D3), // ulaşım · kum
  Color(0xFFF6DEE7), // keyif · pembe
  Color(0xFFE7E0F4), // fatura · lila
  Color(0xFFD6ECE6), // tatil · nane
  Color(0xFFE3E7EC), // araba · gri-mavi
];

/// Donut-grafik ve legend noktaları için sıcak-defter kategorik paleti.
const vivids = [
  Color(0xFF0F9E6C), // yeşil
  Color(0xFFC67A17), // amber
  Color(0xFF3E7CB1), // mavi
  Color(0xFF7A6BB0), // lila
  Color(0xFFC05E86), // gül
  Color(0xFF4FB0A0), // teal
];

Color pastelAt(int index) => pastels[index % pastels.length];
Color vividAt(int index) => vivids[index % vivids.length];

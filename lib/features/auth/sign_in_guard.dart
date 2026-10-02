import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/redesign_l10n.dart';
import 'auth_service.dart';
import 'data_at_risk.dart';

/// Girişi "veri kaybı kapısı"ndan geçirir. Tüm giriş noktaları (giriş
/// ekranı, onboarding'in son sayfası, Ayarlar › Giriş ve güvenlik) buradan
/// geçer ki davranış her yerde aynı olsun.
///
/// Akış:
///   1. [signIn] çalışır (bağlama denemesi [AuthService] içinde).
///   2. [AccountConflict] gelirse — kimlik başka hesabın — anonim hesapta
///      kaybedilecek bir şey var mı diye bakılır ([anonymousHasData]).
///      Yoksa sormadan o hesaba girilir: boş deftere uyarı yalnız engeldir.
///   3. Varsa kullanıcıya SORULUR. "Gir" derse o hesaba geçilir; vazgeçerse
///      hiçbir şey olmaz, kullanıcı olduğu yerde anonim kalır.
///
/// Döner: `true` → giriş yapıldı (bağlandı ya da geçildi); `false` →
/// kullanıcı diyalogda vazgeçti, hiçbir şey değişmedi. Çağıran `false`'u
/// iptal gibi ele almalı — hata şeridi yok. Diğer hatalar (iptal, ağ,
/// yanlış şifre...) olduğu gibi fırlar; çağıranın mevcut
/// [classifySocialAuthError] işleyişi onlara bakar.
///
/// [hasData] test kancası: widget testinde Firestore sorgusu yerine sabit
/// cevap; null → gerçek [anonymousHasData].
Future<bool> signInGuardingData(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() signIn, {
  Future<bool> Function()? hasData,
}) async {
  try {
    await signIn();
    return true;
  } on AccountConflict catch (conflict) {
    if (!context.mounted) return false;
    final atRisk = await (hasData ?? () => anonymousHasData(ref))();
    if (!atRisk) {
      await conflict.signInAnyway();
      return true;
    }
    if (!context.mounted) return false;
    final proceed = await showAccountConflictDialog(context, ref);
    if (!proceed) return false;
    await conflict.signInAnyway();
    return true;
  }
}

/// Hesabı KESİN değiştiren girişler için kapı (e-posta + şifre).
///
/// [signInGuardingData]'dan farkı: orada önce bağlanmaya çalışılır ve
/// yalnız çakışma çıkarsa sorulur. Burada bağlama hiç denenmez (nedeni
/// [AuthService.signInWithEmail] başında yazılı), dolayısıyla çakışma
/// sinyali de gelmez — kaybedilecek bir şey varsa ÖNCEDEN sorulur.
///
/// Döner: `true` → giriş denendi; `false` → kullanıcı vazgeçti, hiçbir
/// şey değişmedi. Giriş hataları (yanlış şifre, hesap yok, ağ) olduğu
/// gibi fırlar.
Future<bool> signInSwitchingAccount(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() signIn, {
  Future<bool> Function()? hasData,
}) async {
  final atRisk = await (hasData ?? () => anonymousHasData(ref))();
  if (atRisk) {
    if (!context.mounted) return false;
    final proceed = await showAccountConflictDialog(context, ref);
    if (!proceed) return false;
  }
  await signIn();
  return true;
}

/// "Bu girişin kendi kayıtları var" diyalogu. `true` → o hesaba gir;
/// `false`/kapatma → vazgeç.
///
/// Güvenli seçenek (kayıtları koru) dolu düğme ve sağda; o hesaba geçmek
/// kırmızı metin düğmesi. Dışarı dokunarak kapatmak da "vazgeç" sayılır:
/// kazara dokunuş hiçbir şeyi kaybettirmemeli.
///
/// Metin "birleştirme" sözü VERMEZ: iki hesabı birleştirmek yapılmıyor
/// (çift kayıt, bakiye çakışması, farklı para birimleri). Söylediği tek şey
/// doğru olan: şimdilik böyle kal, sonra başka bir hesapla bağlan.
Future<bool> showAccountConflictDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final rs = ref.read(rsProvider);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Ex.surface,
      title: Text(rs.conflictTitle),
      content: Text(rs.conflictBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(rs.conflictSignIn, style: const TextStyle(color: Ex.red)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(rs.conflictKeep),
        ),
      ],
    ),
  );
  return result == true;
}

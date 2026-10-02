import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/auth_service.dart';
import '../auth/forget_password_screen.dart';
import '../auth/sign_in_guard.dart';
import 'settings_hub.dart';

/// Bağlanabilen sosyal sağlayıcılar. `password` burada yok: şifreyi bu
/// ekrandan "bağlamak" diye bir akış yok, o Hesap oluştur'un işi.
enum SignInProvider { google, apple }

/// Ekranın gösterdiği her şeyin tek kaynağı — Firebase kullanıcısının
/// ekrana lazım olan kadarı, değişmez bir fotoğraf.
///
/// Ekran [User]'ı doğrudan tutmuyor: `FirebaseAuth.instance` widget
/// testinde kurulu değil ("[core/no-app]" fırlatıyor) ve [User] sahte
/// üretilemiyor. Bu küçük sınıf hem testte elle kurulabiliyor hem de gerçek
/// uygulamada [SignInSnapshot.fromUser] ile kullanıcıdan türetiliyor. Böylece
/// ekranın tüm dalları (anonim / bağlı / e-postasız / şifresiz) Firebase
/// olmadan sınanabiliyor.
@immutable
class SignInSnapshot {
  const SignInSnapshot({
    this.providerIds = const {},
    this.email,
    this.lastSignIn,
    this.isAnonymous = true,
  });

  /// Firebase `providerData`'daki `providerId` değerleri:
  /// `google.com`, `apple.com`, `password`.
  final Set<String> providerIds;
  final String? email;
  final DateTime? lastSignIn;
  final bool isAnonymous;

  /// `currentUser` null ise (Firebase yok ya da oturum yok) anonim gibi
  /// davranılır — sahte bir "bağlı" durum göstermektense güvenli taraf.
  factory SignInSnapshot.fromUser(User? user) {
    if (user == null) return const SignInSnapshot();
    final email = user.email?.trim();
    return SignInSnapshot(
      providerIds: {for (final p in user.providerData) p.providerId},
      email: (email == null || email.isEmpty) ? null : email,
      lastSignIn: user.metadata.lastSignInTime,
      isAnonymous: user.isAnonymous,
    );
  }

  bool get hasGoogle => providerIds.contains('google.com');
  bool get hasApple => providerIds.contains('apple.com');
  bool get hasPassword => providerIds.contains('password');
}

/// Geçerli kullanıcıdan fotoğraf; Firebase kurulu değilse anonim fotoğraf.
SignInSnapshot _readSnapshot() {
  try {
    return SignInSnapshot.fromUser(FirebaseAuth.instance.currentUser);
  } catch (_) {
    return const SignInSnapshot();
  }
}

/// Bağlama sonrası taze fotoğraf: kullanıcıyı yeniden yükleyip
/// `providerData`'yı yeniden okuma.
///
/// Reload şart: link sonrası `currentUser.providerData` bazı sürümlerde
/// bir sonraki token yenilemesine kadar eski kalıyor; ekran "bağladım ama
/// hâlâ bağla diyor" görüntüsü vermemeli.
Future<SignInSnapshot> _reloadSnapshot() async {
  final user = FirebaseAuth.instance.currentUser;
  try {
    await user?.reload();
  } catch (_) {
    // Reload ağ hatasıyla düşebilir; bağlama zaten başarılı, eldeki
    // kullanıcıyla devam.
  }
  return SignInSnapshot.fromUser(FirebaseAuth.instance.currentUser);
}

/// Giriş ve güvenlik — Hesabım › Giriş ve güvenlik.
///
/// Üç blok, hepsi GERÇEK Firebase verisinden:
///   1. "Giriş yöntemleri" kartı: bağlı sağlayıcı → satır + "Bağlı";
///      bağlı olmayan Google/Apple → "…'ı bağla" eylem satırı. Altında
///      son giriş zamanı (yoksa satır yok).
///   2. "E-posta" kartı: hesabın e-postası. E-posta yoksa (anonim, gizli
///      Apple e-postası) kart hiç çizilmez.
///   3. Anonimde hero paragrafı farklı: hesabın korunmadığını söyler.
///
/// Eskiden hub'daki bu satır doğrudan şifre sıfırlama ekranına gidiyordu;
/// Google ile girmiş kullanıcı "şifre"yle karşılaşıyordu. Şimdi şifre akışı
/// yalnız `password` sağlayıcısı olanda, e-posta satırının arkasında.
///
/// [initial], [connect] ve [showApple] test kancaları: widget testinde
/// Firebase yok, platform da test makinesi. Üçü de null bırakılınca gerçek
/// kaynaklar kullanılır.
class SettingsSignInSecurityScreen extends ConsumerStatefulWidget {
  const SettingsSignInSecurityScreen({
    super.key,
    this.initial,
    this.connect,
    this.showApple,
  });

  /// Testte ekranın açılış durumu; null → `FirebaseAuth.instance`.
  final SignInSnapshot? initial;

  /// Testte bağlama akışı; null → [AuthService] + reload.
  final Future<SignInSnapshot> Function(SignInProvider provider)? connect;

  /// Apple satırı görünsün mü; null → Apple platformu mu (onboarding_save
  /// ile aynı kural: App Store şartı iOS için, Android'de Apple satırı yok).
  final bool? showApple;

  @override
  ConsumerState<SettingsSignInSecurityScreen> createState() =>
      _SettingsSignInSecurityScreenState();
}

class _SettingsSignInSecurityScreenState
    extends ConsumerState<SettingsSignInSecurityScreen> {
  late SignInSnapshot _snap;
  bool _busy = false;

  bool get _showApple =>
      widget.showApple ?? (!kIsWeb && (Platform.isIOS || Platform.isMacOS));

  @override
  void initState() {
    super.initState();
    _snap = widget.initial ?? _readSnapshot();
  }

  /// Varsayılan bağlama: [AuthService] akışı [signInGuardingData]
  /// kapısından (anonimde `link`, kimlik başka hesabınsa ve kaybedilecek
  /// kayıt varsa önce sor), ardından taze fotoğraf.
  ///
  /// Kullanıcı diyalogda vazgeçtiyse de fotoğraf yeniden okunur: hiçbir şey
  /// değişmediği için aynı anonim fotoğraf gelir, ekran olduğu gibi kalır.
  Future<SignInSnapshot> _connectWithFirebase(SignInProvider provider) async {
    await signInGuardingData(context, ref, switch (provider) {
      SignInProvider.google => AuthService.signInWithGoogle,
      SignInProvider.apple => AuthService.signInWithApple,
    });
    return _reloadSnapshot();
  }

  Future<void> _connect(SignInProvider provider) async {
    // Çift dokunuş iki sağlayıcı sayfası açmasın.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await (widget.connect ?? _connectWithFirebase)(provider);
      if (!mounted) return;
      // Ne olduysa Firebase'in dediği odur: anonimde bağlandı, üyede o
      // kimliğin hesabına geçildi, diyalogda vazgeçildiyse hiçbir şey —
      // ekran hepsini taze fotoğraftan çizer, varsayım yapmaz.
      setState(() => _snap = next);
    } catch (e) {
      if (!mounted) return;
      final rs = ref.read(rsProvider);
      // İptal hata değil: kullanıcı sağlayıcı sayfasını kapattı, ekran
      // olduğu gibi kalır. Kırmızı şerit göstermek yanlış olur.
      final message = switch (classifySocialAuthError(e)) {
        SocialAuthFailure.canceled => null,
        SocialAuthFailure.differentMethod => rs.saveErrDifferent,
        SocialAuthFailure.network => rs.saveErrOffline,
        SocialAuthFailure.notEnabled ||
        SocialAuthFailure.unknown =>
          rs.saveFailed,
      };
      if (message != null) showErrorSnack(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final snap = _snap;

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.lock_rounded,
        title: rs.hubLoginSecurity,
        // Anonim ve üye için ayrı paragraf: anonimde ekranın tek derdi
        // "hesabın korunmuyor", üyede "hangi yollarla giriyorsun".
        body: snap.isAnonymous ? rs.signinBodyAnon : rs.signinBodyMember,
      ),
      children: [
        // ── Giriş yöntemleri ────────────────────────────────────────────
        // Bağlı olanın yanındaki rozet "Bağlı" — "Birincil" DEĞİL. Firebase
        // providerData düz bir liste; hangisinin "ana" olduğu diye bir
        // bilgi yok. Olmayan bir statüyü uydurup yazmaktansa olanı yazıyoruz.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsCard(label: rs.signinMethodsLabel, rows: [
              if (snap.hasGoogle)
                SettingsRow(
                  leading: const _BrandLogo('assets/brand/google.png'),
                  title: 'Google',
                  value: rs.signinConnected,
                )
              else
                SettingsActionRow(
                  title: rs.signinConnectGoogle,
                  onTap: () => _connect(SignInProvider.google),
                ),
              // Apple satırı yalnız Apple platformlarında — bağlı olsa bile.
              // Android'de Apple ile bağlanmış hesabı GÖSTERMEK dürüst olurdu
              // ama o cihazda Apple akışı yok; bağlı satır da "bağla" satırı
              // da oraya ait değil. Bağlı Apple'ı yine de göster, bağla'yı
              // gösterme: kullanıcı neyin bağlı olduğunu bilsin.
              if (snap.hasApple)
                SettingsRow(
                  leading: const _BrandLogo('assets/brand/apple.png'),
                  title: 'Apple',
                  value: rs.signinConnected,
                )
              else if (_showApple)
                SettingsActionRow(
                  title: rs.signinConnectApple,
                  onTap: () => _connect(SignInProvider.apple),
                ),
              if (snap.hasPassword)
                SettingsRow(
                  icon: Icons.password_rounded,
                  title: rs.signinEmailPassword,
                  value: rs.signinConnected,
                ),
            ]),
            // Son giriş: metadata.lastSignInTime null ise satır yok.
            // "—" yazmak da bir bilgi iddiası; bilmediğimizi hiç söylemiyoruz.
            if (snap.lastSignIn != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 8),
                child: Text(
                  rs.signinLastTpl.replaceAll(
                    '{date}',
                    DateFormat('d MMM yyyy, HH:mm', str.localeCode)
                        .format(snap.lastSignIn!),
                  ),
                  style: const TextStyle(fontSize: 12.5, color: Ex.textMuted),
                ),
              ),
          ],
        ),

        // ── E-posta ─────────────────────────────────────────────────────
        // E-posta yoksa kart yok: anonimde ve e-postasını gizlemiş Apple
        // girişinde gösterecek adres yok, boş kart kafa karıştırır.
        //
        // Şifre sağlayıcısı YOKSA satır dokunulmaz (onTap null → ok da yok):
        // ForgetPasswordScreen şifre sıfırlama e-postası yollar, ama Google/
        // Apple ile girmiş kullanıcının şifresi yok — sıfırlanacak bir şey
        // yok. Oraya kapı açmak kullanıcıyı anlamsız bir akışa sokar.
        if (snap.email != null)
          SettingsCard(label: rs.signinEmailLabel, rows: [
            SettingsRow(
              icon: Icons.mail_rounded,
              title: snap.email!,
              subtitle: snap.hasPassword
                  ? rs.signinEmailChangePassword
                  : rs.signinEmailAccount,
              onTap: snap.hasPassword
                  ? () => pushSettings(
                        context,
                        ForgetPasswordScreen(
                            onDone: () => Navigator.of(context).maybePop()),
                      )
                  : null,
            ),
          ]),
      ],
    );
  }
}

/// Satır başındaki marka logosu — [GradientIcon] değil: Google/Apple
/// logoları marka kuralı gereği kendi renklerinde kalır, gradyana boyanmaz.
/// Apple logosu tek renk mürekkep ([Ex.text]); Google çok renkli, olduğu gibi.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    final isApple = asset.contains('apple');
    return Image.asset(asset, height: 22, color: isApple ? Ex.text : null);
  }
}

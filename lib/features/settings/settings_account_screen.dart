import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/gradient_icon.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/forget_password_screen.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';
import '../envelopes/budget_repository.dart';
import 'data_management_screen.dart';
import 'settings_hub.dart';
import 'settings_personal_details_screen.dart';

/// Geçerli kullanıcı; Firebase kurulu değilse (widget testi) null.
User? _currentUser() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

/// Hesabım — hub'daki "Hesabım" kapısının alt ekranı.
///
/// Düzen (2026-10 ikinci tur, referans düzene göre):
///   Kart A "Kimlik ve giriş": Kişisel bilgiler (ad/telefon/avatar, kendi
///     ekranı) · Giriş ve güvenlik (üyede şifre akışı; anonimde onun yerine
///     "Hesap oluştur" + "Giriş yap").
///   Kart B: tıklanmaz bilgi kartı — verinin NEREDE durduğu.
///   Kart C "Verilerin": dışa aktarma. Kart D "Tehlikeli işlemler": çıkış
///     ve silme — kırmızı satırlar en altta ve ayrı kartta, kazara
///     dokunulmasın.
///
/// Eski "Hesap bilgileri" iletişim kutusu kaybolmadı; Kişisel bilgiler
/// ekranına taşındı ([SettingsPersonalDetailsScreen]) — e-posta/üyelik
/// tarihi "kişisel" veridir, güvenlik ayarı değil.
///
/// Biyometrik giriş satırı YOK: özellik üründen tamamen kaldırıldı
/// (2026-10 kararı), bu ekrana taşınmadı.
class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final user = _currentUser();
    final anonymous = user?.isAnonymous ?? true;

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.person_rounded,
        title: rs.hubMyAccount,
        body: rs.hubAccountBody,
      ),
      children: [
        // ── Kart A: kimlik ve giriş ─────────────────────────────────────
        SettingsCard(label: rs.hubSectionIdentity, rows: [
          SettingsRow(
            icon: Icons.badge_rounded,
            title: rs.hubPersonalDetails,
            onTap: () => pushSettings(
                context, const SettingsPersonalDetailsScreen()),
          ),
          if (anonymous) ...[
            // Anonimde "Giriş ve güvenlik" anlamsız (şifre yok); onun
            // yerine iki kapı: hesap oluştur ve zaten hesabı olan için
            // giriş. İkincisi olmadan onboarding'i geçmiş biri kendi
            // hesabına dönemiyor; "Hesap oluştur" ise
            // email-already-in-use ile patlıyor.
            SettingsRow(
              icon: Icons.person_add_alt_1_rounded,
              title: str.createAccount,
              subtitle: str.createAccountHint,
              accent: true,
              onTap: () => pushSettings(
                context,
                SignUpScreen(
                    onSignedUp: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst)),
              ),
            ),
            SettingsRow(
              icon: Icons.login_rounded,
              title: str.signInTitle,
              onTap: () => pushSettings(
                context,
                SignInScreen(
                    onSignedIn: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst)),
              ),
            ),
          ] else
            SettingsRow(
              icon: Icons.lock_rounded,
              title: rs.hubLoginSecurity,
              onTap: () => pushSettings(
                context,
                ForgetPasswordScreen(
                    onDone: () => Navigator.of(context).maybePop()),
              ),
            ),
        ]),

        // ── Kart B: verin nerede duruyor ────────────────────────────────
        // DİKKAT: referans uygulamadaki "veriler bu cihazda saklanır,
        // uygulamayı silersen gider" cümlesi BİZDE YANLIŞ. Budgy verisi
        // Firestore'da, hesaba bağlı; cihaz değişse de gelir. Anonim
        // kullanıcı için ise tam tersi risk var: hesabını bağlamazsa
        // telefonla birlikte erişimi de kaybeder. Bu yüzden metin anonim/
        // üye durumuna göre DEĞİŞİR — kullanıcıya verisinin nerede durduğu
        // konusunda yanlış bilgi vermek kabul edilemez.
        _DataNoteCard(
          icon: anonymous ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
          text: anonymous ? rs.hubDataNoteAnon : rs.hubDataNoteMember,
        ),

        // ── Kart C: verilerin · Kart D: tehlikeli işlemler ──────────────
        // "Arşiv" satırı yok: uygulamada bağımsız bir arşiv ekranı yok
        // (arşiv, kategori ve kart listelerinin kendi içinde). Olmayan
        // ekrana kapı açmak yerine satırı koymadık.
        SettingsCard(label: rs.hubSectionData, rows: [
          SettingsRow(
            icon: Icons.ios_share_rounded,
            title: rs.hubExportData,
            onTap: () => pushSettings(context, const DataManagementScreen()),
          ),
        ]),
        SettingsCard(label: rs.hubSectionDanger, rows: [
          if (!anonymous)
            SettingsRow(
              icon: Icons.logout_rounded,
              title: str.signOutWord,
              danger: true,
              onTap: () => _signOut(context, ref),
            ),
          SettingsRow(
            icon: Icons.delete_rounded,
            title: str.deleteAccount,
            danger: true,
            onTap: () => _deleteAccount(context, ref),
          ),
        ]),
      ],
    );
  }

  // ── hesap yardımcıları (eski hub'dan, oradan da eski profil ekranından) ──

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ex.surface,
        title: Text(str.signOutWord),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(str.signOutWord, style: const TextStyle(color: Ex.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ex.surface,
        title: Text(str.deleteAccount),
        content: Text(str.deleteAccountBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(str.deleteAccount, style: const TextStyle(color: Ex.red))),
        ],
      ),
    );
    if (ok != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !context.mounted) return;
    // Sıra: doğrula → veriyi sil → hesabı sil (yarı silme olmasın).
    try {
      await _reauthenticateIfNeeded(context, ref, user);
    } on _ReauthCancelled {
      return;
    } catch (_) {
      if (context.mounted) showErrorSnack(context, str.deleteAccountReauthFailed);
      return;
    }
    try {
      await ref.read(budgetRepositoryProvider).deleteAccountData();
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {
      if (context.mounted) showErrorSnack(context, str.deleteAccountFailed);
      return;
    }
    await FirebaseAuth.instance.signInAnonymously();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// `requires-recent-login`: gerekiyorsa yeniden doğrulat; anonimde gerekmez.
  Future<void> _reauthenticateIfNeeded(
      BuildContext context, WidgetRef ref, User user) async {
    if (user.isAnonymous) return;
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn != null &&
        DateTime.now().difference(lastSignIn) < const Duration(minutes: 5)) {
      return;
    }
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) {
      await user.reauthenticateWithProvider(GoogleAuthProvider());
    } else if (providers.contains('apple.com')) {
      await user.reauthenticateWithProvider(AppleAuthProvider());
    } else if (providers.contains('password')) {
      if (!context.mounted) throw const _ReauthCancelled();
      final password = await _askPassword(context, ref);
      if (password == null) throw const _ReauthCancelled();
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }
  }

  Future<String?> _askPassword(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Ex.surface,
          title: Text(str.confirmPasswordTitle),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(hintText: str.passwordHint),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(str.cancel)),
            TextButton(
              onPressed: () {
                final text = controller.text;
                Navigator.of(ctx).pop(text.isEmpty ? null : text);
              },
              child: Text(str.verifyDone),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

/// Tıklanmaz bilgi kartı: bulut ikonu + kısa not.
///
/// [SettingsRow] değil, çünkü satır dokunulabilir görünür (ok, ink);
/// burada dokunacak bir şey yok, not okunup geçilsin. İkon başlığa hizalı
/// (üstte), metin 2-3 satır sarar.
class _DataNoteCard extends StatelessWidget {
  const _DataNoteCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 34,
              height: 34,
              child: Center(child: GradientIcon(icon, size: 28))),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              // Metnin ilk satırı ikonun dikey ortasıyla aynı hizada dursun.
              padding: const EdgeInsets.only(top: 7),
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.4, color: Ex.textSoft)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReauthCancelled implements Exception {
  const _ReauthCancelled();
}

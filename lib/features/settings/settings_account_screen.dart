import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/gradient_icon.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/sign_in_screen.dart';
import '../auth/sign_up_screen.dart';
import '../envelopes/budget_repository.dart';
import 'data_management_screen.dart';
import 'settings_hub.dart';
import 'settings_personal_details_screen.dart';
import 'settings_signin_security_screen.dart';

/// Hesap ekranının Firebase Auth'a dokunan eylemleri. Varsayılanlar gerçek
/// Firebase; widget testinde (Firebase kurulu değil) sahteleriyle
/// değiştiriliyor — çıkış/silme yolları ancak böyle sınanabiliyor.
class AccountActions {
  const AccountActions({
    this.currentUser = _defaultCurrentUser,
    this.signInAnonymously = _defaultSignInAnonymously,
  });

  /// Geçerli kullanıcı; oturum yoksa null.
  final User? Function() currentUser;

  /// Anonim oturum aç. Üye oturumu varsa onu kapatıp anonimle değiştirir;
  /// ağ yoksa FIRLATIR ve mevcut oturuma dokunmaz.
  final Future<void> Function() signInAnonymously;

  /// Firebase kurulu değilse (widget testi) null.
  static User? _defaultCurrentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultSignInAnonymously() =>
      FirebaseAuth.instance.signInAnonymously();
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
class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({
    super.key,
    this.actions = const AccountActions(),
  });

  /// Test kancası; varsayılan gerçek Firebase.
  final AccountActions actions;

  @override
  ConsumerState<SettingsAccountScreen> createState() =>
      _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  /// Çıkış ya da silme sürüyor. Silme binlerce belgeyi tek tek siler,
  /// saniyeler alır; bu sürede satıra yeniden dokunulabiliyordu — ikinci
  /// bir diyalog, ikinci bir silme. Meşgulken iki tehlikeli satır da
  /// kilitli, silme satırında dönen gösterge var.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final user = widget.actions.currentUser();
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
            // Doğrudan şifre sıfırlamaya DEĞİL, tam ekrana: Google/Apple ile
            // girmiş kullanıcının şifresi yok, "şifre" ekranı ona anlamsızdı.
            // Şifre akışı artık o ekranın içinde, yalnız şifresi olana.
            SettingsRow(
              icon: Icons.lock_rounded,
              title: rs.hubLoginSecurity,
              onTap: () => pushSettings(
                  context, const SettingsSignInSecurityScreen()),
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
              onTap: _busy ? null : _signOut,
            ),
          SettingsRow(
            icon: Icons.delete_rounded,
            title: str.deleteAccount,
            danger: true,
            trailing: _busy ? const _BusyDot() : null,
            onTap: _busy ? null : _deleteAccount,
          ),
        ]),
      ],
    );
  }

  // ── hesap yardımcıları (eski hub'dan, oradan da eski profil ekranından) ──

  Future<void> _signOut() async {
    if (_busy) return;
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
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      // `signOut()` ÇAĞRILMIYOR. Eskiden önce signOut (yerel, hep başarılı),
      // sonra signInAnonymously (ağ ister) geliyordu: ağ yokken ikincisi
      // yakalanmadan düşüyor, oturum çoktan kapanmış oluyor ve AuthGate
      // düğmesiz açılış ekranını çiziyordu — tek çıkış uygulamayı yeniden
      // başlatmaktı. `signInAnonymously` üye oturumunu zaten kendisi
      // kapatıp anonimle değiştirir; ağ yoksa fırlatır ve HİÇBİR ŞEY
      // değişmez: kullanıcı hesabında kalır, aşağıda nedenini görür.
      await widget.actions.signInAnonymously();
    } catch (_) {
      if (mounted) showErrorSnack(context, str.signOutFailed);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
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
    if (ok != true || !mounted) return;
    final user = widget.actions.currentUser();
    if (user == null) return;
    setState(() => _busy = true);
    try {
      // Sıra: doğrula → veriyi sil → hesabı sil (yarı silme olmasın).
      try {
        await _reauthenticateIfNeeded(user);
      } on _ReauthCancelled {
        return;
      } catch (_) {
        if (mounted) showErrorSnack(context, str.deleteAccountReauthFailed);
        return;
      }
      try {
        await ref.read(budgetRepositoryProvider).deleteAccountData();
        await user.delete();
      } catch (_) {
        if (mounted) showErrorSnack(context, str.deleteAccountFailed);
        return;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Burada anonim oturum AÇILMIYOR. `delete()` oturumu kapatır, akış
    // null yayar ve AuthGate kendisi yeniden anonim girer; ağ yoksa orada
    // "Tekrar dene" düğmeli hata ekranı çıkar. Eskiden buradaki yakalanmayan
    // `signInAnonymously` ağ yokken kullanıcıyı düğmesiz açılış ekranına
    // kilitliyordu.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// `requires-recent-login`: gerekiyorsa yeniden doğrulat; anonimde gerekmez.
  Future<void> _reauthenticateIfNeeded(User user) async {
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
      if (!mounted) throw const _ReauthCancelled();
      final password = await _askPassword();
      if (password == null) throw const _ReauthCancelled();
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    }
  }

  Future<String?> _askPassword() async {
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

/// Silme sürerken satırın sağında dönen küçük gösterge (ok yerine).
class _BusyDot extends StatelessWidget {
  const _BusyDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Ex.red),
    );
  }
}

class _ReauthCancelled implements Exception {
  const _ReauthCancelled();
}

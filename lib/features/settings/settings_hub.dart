import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/brand.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/complete_profile_screen.dart';
import '../auth/forget_password_screen.dart';
import '../auth/sign_up_screen.dart';
import '../automation/automation_screen.dart';
import '../categories/categories_screen.dart';
import '../envelopes/budget_repository.dart';
import '../goals/goals_screen.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../profile/contact_screen.dart';
import '../profile/currency_screen.dart';
import '../profile/help_screen.dart';
import '../profile/language_screen.dart';
import '../profile/notification_preferences_screen.dart';
import '../profile/privacy_policy_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reminders/reminders_screen.dart';
import '../space/space.dart';
import '../tags/tags_screen.dart';
import '../workdays/calendar_screen.dart';
import 'app_settings.dart';
import 'data_management_screen.dart';
import 'voice_language_screen.dart';

/// Geçerli kullanıcı; Firebase kurulu değilse (widget testi) null.
User? _currentUser() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

/// Uygulama sürümü (package_info) — testte/önizlemede boş kalabilir.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

/// Ayarlar merkezi — cüzdan çipinden açılan tam ekran: cüzdan başlığı,
/// Yönet · Uygulama · Hesap · Yardım bölümleri, altta Hakkında.
/// Tek bir ayar yüzeyi: eski profil ekranının satırları buraya taşındı.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key, this.initialScroll = 0});

  /// Önizleme: açılışta kaydırılmış konum (ekran görüntüsü için).
  final double initialScroll;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _editSpace(BuildContext context, WidgetRef ref) async {
    final code = ref.read(currencyCodeProvider);
    final result = await showSpaceEditor(context,
        initial: ref.read(spaceInfoProvider), currency: code);
    if (result == null || !context.mounted) return;
    final repo = ref.read(budgetRepositoryProvider);
    await guardWrite(context, ref.read(strProvider), () async {
      await repo.saveProfile(result.info.toProfile());
      if (result.currency != code) await repo.setCurrency(result.currency);
    }, reason: 'saveSpace');
  }

  Future<void> _pickKeypad(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final onTop = ref.read(keypadOneTwoThreeOnTopProvider);
    final picked = await showExSheet<bool>(
      context,
      SheetFrame(
        title: rs.keypadLayout,
        child: Column(
          children: [
            _OptionRow(
                label: rs.keypadBottom,
                selected: !onTop,
                onTap: () => Navigator.of(context).pop(false)),
            _OptionRow(
                label: rs.keypadTop,
                selected: onTop,
                onTap: () => Navigator.of(context).pop(true)),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .saveProfile({'keypadLayout': picked ? 'top' : 'bottom'});
  }

  Future<void> _toggleBiometric(
      BuildContext context, WidgetRef ref, bool v) async {
    final str = ref.read(strProvider);
    if (v) {
      try {
        // biometricOnly:false → Face ID yoksa cihaz passcode'una düşer.
        final ok = await LocalAuthentication().authenticate(
          localizedReason: str.lockTitle,
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!ok) return;
      } catch (_) {
        if (context.mounted) showErrorSnack(context, str.biometricUnavailable);
        return;
      }
    }
    await ref.read(budgetRepositoryProvider).saveProfile({'biometric': v});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final space = ref.watch(spaceInfoProvider);
    final user = _currentUser();
    final anonymous = user?.isAnonymous ?? true;
    final language = ref.watch(languageProvider).value ?? AppLanguage.en;
    final currency = ref.watch(currencyCodeProvider);
    final categoryCount = ref.watch(categoryCountProvider);
    final keypadTop = ref.watch(keypadOneTwoThreeOnTopProvider);
    final voice = ref.watch(voiceLocaleProvider) ?? rs.voiceAppLanguage;
    final version = ref.watch(appVersionProvider).value ?? '';

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          controller: ScrollController(initialScrollOffset: initialScroll),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // ── başlık ──────────────────────────────────────────────────
            Row(
              children: [
                GlassSquareButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Text(rs.settings,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  SpaceAvatar(space: space, size: 84),
                  const SizedBox(height: 12),
                  Text(space.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Ex.text)),
                  const SizedBox(height: 2),
                  Text(rs.spaceSubtitle,
                      style: const TextStyle(fontSize: 13.5, color: Ex.textMuted)),
                  const SizedBox(height: 12),
                  TintChipButton(
                    label: rs.customizeWallet,
                    onTap: () => _editSpace(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // ── Yönet ───────────────────────────────────────────────────
            _Section(title: rs.manage, rows: [
              _HubRow(
                icon: Icons.wallet_rounded,
                title: rs.accounts,
                onTap: () => _push(context, const AccountsScreen()),
              ),
              _HubRow(
                icon: Icons.grid_view_rounded,
                title: rs.categories,
                value: '$categoryCount',
                onTap: () => _push(context, const CategoriesScreen()),
              ),
              _HubRow(
                icon: Icons.repeat_rounded,
                title: rs.recurringTitle,
                onTap: () => _push(context, const RecurringScreen()),
              ),
              _HubRow(
                icon: Icons.tag_rounded,
                title: rs.tags,
                onTap: () => _push(context, const TagsScreen()),
              ),
              _HubRow(
                icon: Icons.auto_fix_high_rounded,
                title: rs.automation,
                onTap: () => _push(context, const AutomationScreen()),
              ),
              _HubRow(
                icon: Icons.calendar_month_rounded,
                title: rs.calendar,
                onTap: () => _push(context, const CalendarScreen()),
              ),
              _HubRow(
                icon: Icons.flag_rounded,
                title: rs.goals,
                onTap: () => _push(context, const GoalsScreen()),
              ),
              _HubRow(
                icon: Icons.notifications_active_outlined,
                title: rs.paymentReminders,
                onTap: () => _push(context, const RemindersScreen()),
              ),
            ]),
            const SizedBox(height: 18),

            // ── Uygulama ────────────────────────────────────────────────
            _Section(title: rs.appSection, rows: [
              _HubRow(
                icon: Icons.dialpad_rounded,
                title: rs.keypadLayout,
                value: keypadTop ? rs.keypadTop : rs.keypadBottom,
                onTap: () => _pickKeypad(context, ref),
              ),
              _HubRow(
                icon: Icons.mic_rounded,
                title: rs.voiceLanguage,
                value: voice,
                onTap: () => _push(context, const VoiceLanguageScreen()),
              ),
              _HubRow(
                icon: Icons.language_rounded,
                title: str.languageTitle,
                value: language.title,
                onTap: () => _push(context, const LanguageScreen()),
              ),
              _HubRow(
                icon: Icons.payments_outlined,
                title: str.currencyTitle,
                value: currency,
                onTap: () => _push(context, const CurrencyScreen()),
              ),
              _HubRow(
                icon: Icons.notifications_none_rounded,
                title: str.notificationPreferences,
                onTap: () => _push(context, const NotificationPreferencesScreen()),
              ),
              _HubRow(
                icon: Icons.fingerprint_rounded,
                title: str.biometricAuth,
                trailing: Switch(
                  value: ref.watch(biometricEnabledProvider),
                  activeThumbColor: Ex.brand,
                  onChanged: (v) => _toggleBiometric(context, ref, v),
                ),
              ),
              _HubRow(
                icon: Icons.storage_rounded,
                title: rs.dataManagement,
                onTap: () => _push(context, const DataManagementScreen()),
              ),
            ]),
            const SizedBox(height: 18),

            // ── Hesap ───────────────────────────────────────────────────
            _Section(title: rs.accountSection, rows: [
              if (anonymous)
                _HubRow(
                  icon: Icons.person_add_alt_1_rounded,
                  title: str.createAccount,
                  subtitle: str.createAccountHint,
                  accent: true,
                  onTap: () => _push(
                    context,
                    SignUpScreen(
                        onSignedUp: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst)),
                  ),
                ),
              _HubRow(
                icon: Icons.badge_outlined,
                title: str.personalInfo,
                onTap: () => _push(
                  context,
                  CompleteProfileScreen(
                      onComplete: () => Navigator.of(context).maybePop()),
                ),
              ),
              _HubRow(
                icon: Icons.account_circle_outlined,
                title: str.accountInformation,
                subtitle: anonymous ? str.anonymousTitle : user?.email,
                onTap: () => _accountInfo(context, ref, str, user),
              ),
              if (!anonymous)
                _HubRow(
                  icon: Icons.lock_outline_rounded,
                  title: str.passwordSecurity,
                  onTap: () => _push(
                    context,
                    ForgetPasswordScreen(
                        onDone: () => Navigator.of(context).maybePop()),
                  ),
                ),
              if (!anonymous)
                _HubRow(
                  icon: Icons.logout_rounded,
                  title: str.signOutWord,
                  onTap: () => _signOut(context, ref),
                ),
              _HubRow(
                icon: Icons.delete_outline_rounded,
                title: str.deleteAccount,
                danger: true,
                onTap: () => _deleteAccount(context, ref),
              ),
            ]),
            const SizedBox(height: 18),

            // ── Yardım ──────────────────────────────────────────────────
            _Section(title: rs.helpSection, rows: [
              _HubRow(
                icon: Icons.help_outline_rounded,
                title: str.faqs,
                onTap: () => _push(context, const HelpScreen()),
              ),
              _HubRow(
                icon: Icons.support_agent_rounded,
                title: str.helpCenter,
                onTap: () => _push(context, const ContactScreen()),
              ),
              _HubRow(
                icon: Icons.privacy_tip_outlined,
                title: rs.privacyPolicy,
                onTap: () => _push(context, const PrivacyPolicyScreen()),
              ),
            ]),
            const SizedBox(height: 28),

            // ── Hakkında ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  const BudgyWordmark(iconSize: 34, fontSize: 22, gap: 10),
                  if (version.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(tpl(rs.versionTpl, {'v': version}),
                        style: const TextStyle(fontSize: 12.5, color: Ex.textFaint)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── hesap yardımcıları (eski profil ekranından) ───────────────────────

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

  Future<void> _accountInfo(
      BuildContext context, WidgetRef ref, Strings str, User? user) async {
    final loc = str.localeCode;
    String lbl(String tr, String en, String ru) =>
        loc == 'tr' ? tr : (loc == 'ru' ? ru : en);
    final profile = ref.read(profileProvider).value ?? const {};
    final name = (profile['name'] as String?)?.trim() ?? '';
    final anon = user?.isAnonymous ?? true;
    final created = user?.metadata.creationTime;
    final rows = <(String, String)>[
      if (name.isNotEmpty) (lbl('İsim', 'Name', 'Имя'), name),
      (str.emailLabel, anon ? '—' : (user?.email ?? '—')),
      (
        lbl('Hesap', 'Account', 'Аккаунт'),
        anon ? lbl('Anonim', 'Anonymous', 'Анонимный') : lbl('E-posta', 'Email', 'Email')
      ),
      if (created != null)
        (lbl('Üyelik', 'Member since', 'С нами с'),
            DateFormat('d MMM yyyy', loc).format(created)),
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ex.surface,
        title: Text(str.accountInformation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(k, style: const TextStyle(color: Ex.textMuted))),
                    Expanded(
                      child: Text(v,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Ex.text)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(str.cancel)),
        ],
      ),
    );
  }
}

class _ReauthCancelled implements Exception {
  const _ReauthCancelled();
}

/// Bölüm: küçük etiket + gruplu kart (satırlar ince çizgiyle ayrık).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Ex.textMuted)),
        ),
        ExCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Column(
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Ex.border),
                r,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Ex.red : (accent ? Ex.mint : Ex.text);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: danger
                    ? Ex.red.withValues(alpha: 0.14)
                    : Ex.brand.withValues(alpha: accent ? 0.22 : 0.12),
                borderRadius: Ex.squircle(34),
              ),
              child: Icon(icon, size: 18, color: danger ? Ex.red : Ex.mint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: color)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Ex.textMuted)),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Ex.textMuted)),
              ),
            ],
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ExCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? Ex.mint : Ex.text)),
              ),
              if (selected) const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
            ],
          ),
        ),
      );
}

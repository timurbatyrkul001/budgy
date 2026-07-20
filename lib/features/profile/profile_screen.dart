import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../auth/complete_profile_screen.dart';
import '../auth/forget_password_screen.dart';
import '../auth/sign_up_screen.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/onboarding_story_screen.dart';
import '../reminders/reminders_screen.dart';
import '../transactions/journal_screen.dart';
import 'contact_screen.dart';
import 'currency_screen.dart';
import 'help_screen.dart';
import 'language_screen.dart';
import 'notification_preferences_screen.dart';

/// Profil — Budgy "Sıcak Defter": avatar + gruplu ayar bölümleri.
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _toggleBiometric(BuildContext context, bool v) async {
    final str = ref.read(strProvider);
    if (v) {
      try {
        // biometricOnly:false → Face ID yoksa cihaz passcode'una düşer
        // (kullanıcı kilitli kalmaz; Face ID için cihazda passcode şart).
        final ok = await LocalAuthentication().authenticate(
          localizedReason: str.lockTitle,
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (!ok) return;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(str.biometricUnavailable)),
          );
        }
        return;
      }
    }
    await ref.read(budgetRepositoryProvider).saveProfile({'biometric': v});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final language = ref.watch(languageProvider).value ?? AppLanguage.en;
    final user = FirebaseAuth.instance.currentUser;
    final profile = ref.watch(profileProvider).value ?? const {};
    final name = (profile['name'] as String?)?.trim() ?? '';
    final photo = profile['photo'] as String?;
    final displayName = name.isNotEmpty
        ? name
        : (user?.email ?? str.anonymousTitle);
    final currency =
        '${ref.watch(currencyProvider).value ?? 'TRY'} · ${ref.watch(currencySymbolProvider)}';
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final themeLabel = switch (themeMode) {
      ThemeMode.light => str.themeLight,
      ThemeMode.dark => str.themeDark,
      ThemeMode.system => str.themeSystem,
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (Navigator.of(context).canPop()) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: c.surface,
                  shape: CircleBorder(side: BorderSide(color: c.border)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: c.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(str.yourProfileTitle,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(str.profileSubtitle,
                style: TextStyle(fontSize: 14, color: c.textMuted)),
            const SizedBox(height: 24),
            // Avatar (dokun → fotoğraf yükle)
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _pickPhoto(context),
                    onLongPress: () => _removePhoto(context),
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle),
                          child: photo != null
                              ? Image.memory(base64Decode(photo),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover)
                              : name.isNotEmpty
                                  ? Text(
                                      _initials(name),
                                      style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          color: c.accent),
                                    )
                                  : Icon(Icons.person_rounded,
                                      color: c.accent, size: 48),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.bg, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(displayName,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: c.text)),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ??
                        (user != null
                            ? 'ID: ${user.uid.substring(0, 10)}…'
                            : ''),
                    style: TextStyle(fontSize: 14, color: c.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Anonimse: hesabını e-postaya bağla (veri korunur).
            if (user?.isAnonymous ?? false) ...[
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SignUpScreen(
                        onSignedUp: () => Navigator.of(context)
                            .popUntil((r) => r.isFirst)),
                  ),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: c.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(str.createAccount,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(str.createAccountHint,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Account settings
            _Section(title: str.accountSettings, rows: [
              _Row(
                icon: Icons.account_circle_outlined,
                title: str.accountInformation,
                onTap: () => _accountInfo(context, str, user),
              ),
              _Row(
                icon: Icons.badge_outlined,
                title: str.personalInfo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompleteProfileScreen(
                        onComplete: () => Navigator.of(context).maybePop()),
                  ),
                ),
              ),
              _Row(
                icon: Icons.notifications_none_rounded,
                title: str.notificationPreferences,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          const NotificationPreferencesScreen()),
                ),
              ),
              _Row(
                icon: Icons.language_rounded,
                title: str.languageTitle,
                value: language.title,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                ),
              ),
              _Row(
                icon: Icons.payments_outlined,
                title: str.currencyTitle,
                value: currency,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CurrencyScreen()),
                ),
              ),
              _Row(
                icon: Icons.brightness_6_outlined,
                title: str.appearanceTitle,
                value: themeLabel,
                onTap: () => _pickTheme(context, ref, themeMode),
              ),
            ]),
            const SizedBox(height: 20),
            // Security
            _Section(title: str.securitySection, rows: [
              _Row(
                icon: Icons.lock_outline_rounded,
                title: str.passwordSecurity,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ForgetPasswordScreen(
                        onDone: () => Navigator.of(context).maybePop()),
                  ),
                ),
              ),
              _Row(
                icon: Icons.fingerprint_rounded,
                title: str.biometricAuth,
                trailing: Switch(
                  value: ref.watch(biometricEnabledProvider),
                  activeThumbColor: c.accent,
                  onChanged: (v) => _toggleBiometric(context, v),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            // Other
            _Section(title: str.otherSection, rows: [
              _Row(
                icon: Icons.help_outline_rounded,
                title: str.faqs,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              _Row(
                icon: Icons.support_agent_rounded,
                title: str.helpCenter,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                ),
              ),
              _Row(
                icon: Icons.settings_outlined,
                title: str.settingsWord,
                onTap: () => _settingsSheet(context, str),
              ),
              _Row(
                icon: Icons.logout_rounded,
                title: str.signOutWord,
                onTap: () => _signOut(context, ref),
              ),
            ]),
            const SizedBox(height: 16),
            // Hesap silme (App Store / Play zorunlu)
            InkWell(
              onTap: () => _deleteAccount(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                  boxShadow: c.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(str.deleteAccount,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.red)),
                    ),
                    Icon(Icons.chevron_right, color: c.textFaint),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final second = parts.length > 1 ? parts[1].substring(0, 1) : '';
    return (first + second).toUpperCase();
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    await ref
        .read(budgetRepositoryProvider)
        .saveProfile({'photo': base64Encode(bytes)});
  }

  Future<void> _removePhoto(BuildContext context) async {
    final str = ref.read(strProvider);
    final has = (ref.read(profileProvider).value ?? const {})['photo'] != null;
    if (!has) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.budgy.surface,
        title: Text(str.removeWord),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(str.removeWord,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(budgetRepositoryProvider)
          .saveProfile({'photo': null});
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.budgy.surface,
        title: Text(str.deleteAccount),
        content: Text(str.deleteAccountBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(str.deleteAccount,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(budgetRepositoryProvider).deleteAccountData();
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
    await FirebaseAuth.instance.signInAnonymously();
  }

  /// Settings → ek özellikler (History, Intro, Hatırlatıcılar).
  Future<void> _settingsSheet(BuildContext context, Strings str) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.budgy.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.receipt_long_rounded, color: ctx.budgy.accent),
              title: Text(str.historyTitle),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const JournalScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.autorenew_rounded,
                  color: ctx.budgy.accent),
              title: Text(str.recurringTitle),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RemindersScreen()));
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.auto_awesome_outlined, color: ctx.budgy.accent),
              title: const Text('Intro'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const OnboardingStoryScreen(preview: true)));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accountInfo(
      BuildContext context, Strings str, User? user) async {
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
        lbl('Doğrulandı', 'Verified', 'Подтверждён'),
        (user?.emailVerified ?? false)
            ? lbl('Evet ✓', 'Yes ✓', 'Да ✓')
            : lbl('Hayır', 'No', 'Нет')
      ),
      (
        lbl('Hesap', 'Account', 'Аккаунт'),
        anon
            ? lbl('Anonim', 'Anonymous', 'Анонимный')
            : lbl('E-posta', 'Email', 'Email')
      ),
      if (created != null)
        (
          lbl('Üyelik', 'Member since', 'С нами с'),
          DateFormat('d MMM yyyy', loc).format(created)
        ),
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.budgy.surface,
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
                      width: 120,
                      child: Text(k,
                          style: TextStyle(color: ctx.budgy.textMuted)),
                    ),
                    Expanded(
                      child: Text(v,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ctx.budgy.text)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(str.cancel)),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.budgy.surface,
        title: Text(str.signOutWord),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(str.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(str.signOutWord,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) async {
    final str = ref.read(strProvider);
    final options = <(ThemeMode, String, IconData)>[
      (ThemeMode.system, str.themeSystem, Icons.brightness_auto_rounded),
      (ThemeMode.light, str.themeLight, Icons.light_mode_rounded),
      (ThemeMode.dark, str.themeDark, Icons.dark_mode_rounded),
    ];
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: context.budgy.surface,
        title: Text(str.appearanceTitle),
        children: [
          for (final (mode, label, icon) in options)
            ListTile(
              leading: Icon(icon, color: context.budgy.accent),
              title: Text(label),
              trailing: mode == current
                  ? Icon(Icons.check_rounded, color: context.budgy.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      await ref.read(budgetRepositoryProvider).setThemeMode(selected);
    }
  }

}

/// Başlık + gruplu kart (satırlar ince çizgiyle ayrık) — export'taki
/// section deseni: küçük text-faint etiket + border'lı surface kart.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: c.textFaint)),
        ),
        const SizedBox(height: 9),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.border),
            boxShadow: c.cardShadow,
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 61),
                    child: Divider(height: 1, color: c.border),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tek ayar satırı: köşeli ikon kutusu + başlık + değer/chevron veya trailing.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: c.accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text)),
            ),
            if (value != null) ...[
              Text(value!,
                  style: TextStyle(fontSize: 14, color: c.textMuted)),
              const SizedBox(width: 6),
            ],
            trailing ?? Icon(Icons.chevron_right, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

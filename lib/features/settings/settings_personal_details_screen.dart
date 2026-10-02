import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/complete_profile_screen.dart';
import '../envelopes/budget_repository.dart';
import '../space/space.dart';
import 'settings_edit_avatar_screen.dart';
import 'settings_edit_name_screen.dart';
import 'settings_hub.dart';

/// Geçerli kullanıcı; Firebase kurulu değilse (widget testi) null.
User? _currentUser() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

/// Kişisel bilgiler — Hesabım › Kişisel bilgiler.
///
/// Kart 1: büyük cüzdan avatarı + ad + gri ikinci satır; en altta "Avatarı
///   düzenle" → [SettingsEditAvatarScreen] (renk + simge). Eskiden buradan
///   genel cüzdan sheet'i ([showSpaceEditor]: ad, simge, renk, para birimi)
///   açılıyordu; avatar için para birimi ve cüzdan adı fazlalıktı, ayrı
///   ekrana indi. Bu kapı eskiden hub'ın ilk satırındaydı; hub'da iki
///   kimlik girişi (cüzdan + hesap) kafa karıştırıyordu, buraya indi.
/// Kart 2: profilde GERÇEKTEN olan alanlar — `name` ve `phone`. Ad artık
///   kendi ekranında ([SettingsEditNameScreen]); telefon hâlâ
///   [CompleteProfileScreen]'de — orada doğrulama/biçim mantığıyla
///   birlikte duruyor, tek alan için onu kopyalamadık. Doğum günü,
///   cinsiyet gibi alanlar profilde yok; olmayan alana satır koymadık.
/// Kart 3: "Hesap bilgileri" iletişim kutusu (ad, e-posta, hesap türü,
///   üyelik tarihi) — eski Hesabım ekranından taşındı.
///
/// Üstte hero yerine sade başlık: kullanıcı iki kat derine indi, burada
/// açıklama paragrafı değil doğrudan veri bekliyor.
class SettingsPersonalDetailsScreen extends ConsumerWidget {
  const SettingsPersonalDetailsScreen({super.key});

  void _editAvatar(BuildContext context) =>
      pushSettings(context, const SettingsEditAvatarScreen());

  void _editName(BuildContext context) =>
      pushSettings(context, const SettingsEditNameScreen());

  /// Telefon: eski ortak form — telefon mantığı orada, ayrı ekran yok.
  void _editPhone(BuildContext context) => pushSettings(
    context,
    CompleteProfileScreen(onComplete: () => Navigator.of(context).maybePop()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final space = ref.watch(spaceInfoProvider);
    final profile = ref.watch(profileProvider).value ?? const {};
    final name = (profile['name'] as String?)?.trim() ?? '';
    final phone = (profile['phone'] as String?)?.trim() ?? '';
    final user = _currentUser();
    final anonymous = user?.isAnonymous ?? true;
    final email = user?.email?.trim() ?? '';

    // Avatar altındaki ad: kullanıcı adını yazdıysa o; yoksa cüzdan adı
    // (varsayılan "Personal") — boş başlık bırakmamak için. İkinci satır:
    // üyede e-posta, anonimde "Anonim hesap"; cüzdan adı zaten düzenleyicide.
    final headline = name.isNotEmpty ? name : space.name;
    final subline = anonymous
        ? str.anonymousTitle
        : (email.isNotEmpty ? email : space.name);

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const BudgyBackButton(),
            const SizedBox(height: 8),
            Text(
              rs.hubPersonalDetails,
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
                height: 1.1,
                color: Ex.text,
              ),
            ),
            const SizedBox(height: 18),

            // ── Kart 1: avatar ──────────────────────────────────────────
            ExCard(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 2),
              child: Column(
                children: [
                  SpaceAvatar(space: space, size: 84),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'InterDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Ex.textMuted),
                  ),
                  const SizedBox(height: 16),
                  // Ayırıcı tam genişlik: üstündeki blok ortalı, ikon
                  // sütunu yok — "ikonun bittiği yer" kuralı burada yok.
                  const Divider(height: 1, color: Ex.border),
                  SettingsRow(
                    icon: Icons.palette_rounded,
                    title: rs.hubEditAvatar,
                    onTap: () => _editAvatar(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Kart 2: profil alanları (yalnız var olanlar) ────────────
            // Ad kendi ekranına gider; telefon hâlâ eski ortak formda.
            SettingsCard(
              rows: [
                SettingsRow(
                  icon: Icons.person_rounded,
                  title: str.fullNameLabel,
                  value: name.isEmpty ? rs.hubNotSet : name,
                  onTap: () => _editName(context),
                ),
                SettingsRow(
                  icon: Icons.phone_rounded,
                  title: str.phoneLabel,
                  value: phone.isEmpty ? rs.hubNotSet : phone,
                  onTap: () => _editPhone(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Kart 3: hesap bilgileri (iletişim kutusu) ───────────────
            SettingsCard(
              rows: [
                SettingsRow(
                  icon: Icons.account_circle_rounded,
                  title: str.accountInformation,
                  subtitle: anonymous ? str.anonymousTitle : email,
                  onTap: () => _accountInfo(context, ref, str, user, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Eski Hesabım ekranından taşındı: ad, e-posta, hesap türü, üyelik.
  Future<void> _accountInfo(
    BuildContext context,
    WidgetRef ref,
    Strings str,
    User? user,
    String name,
  ) async {
    final loc = str.localeCode;
    String lbl(String tr, String en, String ru) =>
        loc == 'tr' ? tr : (loc == 'ru' ? ru : en);
    final anon = user?.isAnonymous ?? true;
    final created = user?.metadata.creationTime;
    final rows = <(String, String)>[
      if (name.isNotEmpty) (lbl('İsim', 'Name', 'Имя'), name),
      (str.emailLabel, anon ? '—' : (user?.email ?? '—')),
      (
        lbl('Hesap', 'Account', 'Аккаунт'),
        anon
            ? lbl('Anonim', 'Anonymous', 'Анонимный')
            : lbl('E-posta', 'Email', 'Email'),
      ),
      if (created != null)
        (
          lbl('Üyelik', 'Member since', 'С нами с'),
          DateFormat('d MMM yyyy', loc).format(created),
        ),
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
                      child: Text(
                        k,
                        style: const TextStyle(color: Ex.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Ex.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(str.cancel),
          ),
        ],
      ),
    );
  }
}

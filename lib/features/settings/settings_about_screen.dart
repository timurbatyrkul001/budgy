import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/redesign_l10n.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/terms_of_use_screen.dart';
import 'data_management_screen.dart';
import 'settings_hub.dart';

/// Hakkında — yasal metinler, veri yönetimi ve sürüm.
///
/// Veri yönetimi burada, çünkü "verimi dışa aktar / sıfırla" kullanıcı için
/// gizlilik politikasının yanında aranan bir şey; görünüm ayarı değil.
/// Sürüm tıklanmaz bir satır: eskiden hub'ın en altında soluk yazıydı,
/// destek yazışmasında "hangi sürüm?" sorusuna kolay bulunsun diye satır oldu.
class SettingsAboutScreen extends ConsumerWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final version = ref.watch(appVersionProvider).value ?? '';

    return SettingsPage(
      hero: SettingsHero(
        icon: Icons.info_rounded,
        title: rs.hubAbout,
        body: rs.hubAboutBody,
      ),
      children: [
        SettingsCard(rows: [
          SettingsRow(
            icon: Icons.privacy_tip_rounded,
            title: rs.privacyPolicy,
            onTap: () => pushSettings(context, const PrivacyPolicyScreen()),
          ),
          // Apple, abonelik satan uygulamalarda paywall'dan bu ekrana
          // bağlantı zorunlu tutuyor; ayrıca burada da erişilebilir.
          SettingsRow(
            icon: Icons.gavel_rounded,
            title: rs.termsTitle,
            onTap: () => pushSettings(context, const TermsOfUseScreen()),
          ),
        ]),
        SettingsCard(rows: [
          SettingsRow(
            icon: Icons.storage_rounded,
            title: rs.dataManagement,
            onTap: () => pushSettings(context, const DataManagementScreen()),
          ),
          SettingsRow(
            icon: Icons.tag_rounded,
            title: rs.hubVersion,
            // package_info testte boş döner; "—" ile satır boş kalmasın.
            value: version.isEmpty ? '—' : version,
          ),
        ]),
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Center(
            child: BudgyWordmark(iconSize: 34, fontSize: 22, gap: 10),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';

/// Yardım Merkezi: iletişim/destek (SSS'ten farklı — soru-cevap değil).
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final loc = str.localeCode;
    String t(String tr, String en, String ru) =>
        loc == 'tr' ? tr : (loc == 'ru' ? ru : en);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık çubuğu: dairesel geri butonu + ortalanmış başlık.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Row(
                children: [
                  _BackButton(),
                  Expanded(
                    child: Text(
                      str.helpCenter,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: c.text),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Bir sorun mu var? Yardımcı olalım.',
                              'Got a problem? We\'re here to help.',
                              'Возникла проблема? Мы поможем.'),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: c.text),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t('Aşağıdaki e-postadan bize yaz, en kısa sürede dönelim.',
                              'Email us below and we\'ll get back to you soon.',
                              'Напиши нам на почту ниже — ответим как можно скорее.'),
                          style: TextStyle(
                              fontSize: 14, height: 1.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // E-posta kartı (kopyala)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.border),
                      boxShadow: c.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: c.envMarket,
                              borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.mail_outline_rounded,
                              size: 19, color: c.accentStrong),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text('timurbatyrkul@ggtech.co',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.text)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                                text: 'timurbatyrkul@ggtech.co'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(t('Kopyalandı', 'Copied',
                                      'Скопировано'))),
                            );
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: c.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10)),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(t('Kopyala', 'Copy', 'Копировать')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // SSS'e ve gizliliğe kısayol
                  _LinkRow(
                    icon: Icons.help_outline_rounded,
                    label: str.faqs,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _LinkRow(
                    icon: Icons.privacy_tip_outlined,
                    label: str.confidentialityPolicy,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text('Budgy v1.0',
                        style: TextStyle(fontSize: 13, color: c.textFaint)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kısayol satırı: tint'li ikon kutusu + başlık + chevron (surface kart).
class _LinkRow extends StatelessWidget {
  const _LinkRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 19, color: c.accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: c.text)),
              ),
              Icon(Icons.chevron_right, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dairesel geri butonu — surface zemin + border (tasarımdaki başlık deseni).
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
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
    );
  }
}

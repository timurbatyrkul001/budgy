import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../auth/forget_password_screen.dart';
import '../envelopes/budget_repository.dart';
import '../reminders/reminders_repository.dart';
import '../reminders/reminders_screen.dart';
import 'privacy_policy_screen.dart';

/// Notification Preferences — bildirim ayarları, şifre değiştir, gizlilik.
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: geri butonu + ortalanmış başlık.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Material(
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
                  Expanded(
                    child: Center(
                      child: Text(
                        str.notificationPreferences,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: c.text),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _SectionLabel(str.dailyReminderLabel),
                  const SizedBox(height: 9),
                  const _DailyReminderTile(),
                  const SizedBox(height: 20),
                  _SectionLabel(str.settingsWord),
                  const SizedBox(height: 9),
                  _Group(rows: [
                    _Row(
                      icon: Icons.notifications_active_outlined,
                      title: str.notificationSettings,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RemindersScreen()),
                      ),
                    ),
                    _Row(
                      icon: Icons.lock_reset_rounded,
                      title: str.changePassword,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ForgetPasswordScreen(
                              onDone: () => Navigator.of(context).maybePop()),
                        ),
                      ),
                    ),
                    _Row(
                      icon: Icons.privacy_tip_outlined,
                      title: str.confidentialityPolicy,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen()),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük büyük-harfli bölüm etiketi (export'taki text-faint desen).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: c.textFaint)),
    );
  }
}

/// Günlük "harcama girdin mi?" hatırlatması: aç/kapa + saat.
class _DailyReminderTile extends ConsumerWidget {
  const _DailyReminderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final daily = ref.watch(dailyReminderProvider);

    Future<void> save(Map<String, dynamic> m) =>
        ref.read(budgetRepositoryProvider).saveProfile(m);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.notifications_active_outlined,
                      size: 18, color: c.accent),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str.dailyReminderLabel,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(str.dailyReminderBody,
                          style:
                              TextStyle(fontSize: 12.5, color: c.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: daily.enabled,
                  activeThumbColor: c.accent,
                  onChanged: (v) => save({
                    'dailyReminder': v,
                    if (v) 'dailyHour': daily.hour,
                  }),
                ),
              ],
            ),
          ),
          if (daily.enabled) ...[
            Divider(height: 1, color: c.border),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: daily.hour, minute: 0),
                );
                if (picked != null) save({'dailyHour': picked.hour});
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 20, color: c.textMuted),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${daily.hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.accent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, color: c.textFaint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gruplu kart: satırlar ince çizgiyle ayrık (surface + border + gölge).
class _Group extends StatelessWidget {
  const _Group({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
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
    );
  }
}

/// Tek ayar satırı: köşeli ikon kutusu + başlık + chevron.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

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
            Icon(Icons.chevron_right, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

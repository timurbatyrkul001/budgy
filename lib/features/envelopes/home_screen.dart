import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/animated_bar.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';

import '../insights/analytics.dart';
import '../profile/profile_screen.dart';
import '../savings/savings_screen.dart';
import '../reminders/reminders_repository.dart';
import '../transactions/add_income_screen.dart';
import '../transactions/journal_screen.dart';
import '../workdays/work_days_repository.dart';
import 'add_envelope_sheet.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_detail_screen.dart';
import 'envelope_l10n.dart';

String _greeting(Strings str) {
  final hour = DateTime.now().hour;
  if (hour < 6) return str.goodNight;
  if (hour < 12) return str.goodMorning;
  if (hour < 18) return str.goodAfternoon;
  return str.goodEvening;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final envelopes = ref.watch(envelopesProvider);
    final foreign = ref.watch(foreignTotalsProvider);
    final str = ref.watch(strProvider);
    final profile = ref.watch(profileProvider).value ?? const {};
    final photo = profile['photo'] as String?;
    final name = (profile['name'] as String?)?.trim() ?? '';

    final inEnvelopes = ref.watch(totalBalanceProvider);
    final days = ref.watch(unallocatedWorkDaysProvider).value ?? [];
    final freeExp = ref.watch(unallocatedFreeExpensesProvider).value ?? [];
    final freeInc = ref.watch(unallocatedFreeIncomeProvider).value ?? [];

    // Dağıtılmayı bekleyen = işaretlenmiş ama zarfa konmamış günlük kazanç +
    // котёл'daki serbest gelir.
    final toDistribute = days.fold<double>(0, (s, d) => s + (d.amount ?? 0)) +
        freeInc.fold<double>(0, (s, e) => s + e.amount);
    // Cepte kalan = zarflar + bekleyen − serbest harcamalar.
    final pocket = inEnvelopes +
        toDistribute -
        freeExp.fold<double>(0, (s, e) => s + e.amount);

    ref.watch(reminderSchedulerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: envelopes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${str.errorPrefix}: $e')),
          data: (allEnvelopes) {
            final list =
                allEnvelopes.where((e) => !e.archived && !e.isGoal).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: [
                // ── selamlama ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('d MMMM, EEEE', str.localeCode)
                                .format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name.isNotEmpty
                                ? '${_greeting(str)}, ${name.split(' ').first}'
                                : _greeting(str),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.03 * 26,
                              color: c.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _push(context, const ProfileScreen()),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.envMarket,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.borderStrong),
                        ),
                        child: photo != null
                            ? Image.memory(base64Decode(photo),
                                width: 44, height: 44, fit: BoxFit.cover)
                            : Text(
                                name.isNotEmpty
                                    ? name.characters.first.toUpperCase()
                                    : '🙂',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: c.accentStrong,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── dağıtılmayı bekleyen / cepte kalan ────────────────────
                if (toDistribute > 0)
                  _DistributeCard(
                    amount: toDistribute,
                    onTap: () => _push(
                      context,
                      AddIncomeScreen(
                        initialAmount: toDistribute,
                        workDayIds: days.map((d) => d.id).toList(),
                        freeTxIds: freeInc.map((e) => e.id).toList(),
                      ),
                    ),
                  )
                else
                  _PocketCard(amount: pocket),
                const SizedBox(height: 18),

                // ── döviz çipleri (varsa) ─────────────────────────────────
                if (foreign.isNotEmpty) ...[
                  _ForeignChips(foreign: foreign),
                  const SizedBox(height: 18),
                ],

                // ── haftalık kazanç şeridi ────────────────────────────────
                const _WeekStrip(),
                const SizedBox(height: 12),

                // ── kazanç serisi çipi ────────────────────────────────────
                const _StreakChip(),
                const SizedBox(height: 22),

                // ── tempo uyarısı (bütçe aşım riski) ─────────────────────
                const _PaceBanner(),

                // ── zarflar ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      str.envelopesTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.02 * 16,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.02,
                  ),
                  itemCount: list.length + 1,
                  itemBuilder: (context, index) {
                    final card = index == list.length
                        ? _AddEnvelopeCard(nextSortOrder: list.length)
                        : _EnvelopeCard(
                            envelope: list[index], colorIndex: index);
                    return EntranceFade(delayIndex: index, child: card);
                  },
                ),
                const SizedBox(height: 26),
                const _RecentTransactions(),
              ],
            );
          },
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

/// Amber "dağıtılmayı bekleyen" kartı — bugünkü kazancı zarflara böl.
class _DistributeCard extends ConsumerWidget {
  const _DistributeCard({required this.amount, required this.onTap});

  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: c.amberBg,
        border: Border.all(color: c.amber),
        borderRadius: BorderRadius.circular(BudgyRadii.bigCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: c.amber, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  str.waitingToDistribute.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.01 * 13,
                    color: c.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => Text(
              formatMoney(value),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.03 * 36,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            str.waitingSubtitle,
            style: TextStyle(
                fontSize: 13.5, height: 1.35, color: c.textMuted),
          ),
          const SizedBox(height: 14),
          Material(
            color: c.amber,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  str.distributeToEnvelopes,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.01 * 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bekleyen para yokken sakin yeşil özet kartı — cepte kalan.
class _PocketCard extends ConsumerWidget {
  const _PocketCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BudgyRadii.bigCard),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  str.moneyLeft.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.01 * 13,
                    color: c.accentStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: amount),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => Text(
              formatMoney(value),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.03 * 36,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            str.allDistributed,
            style: TextStyle(fontSize: 13.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Döviz zarflarının toplam çipleri → Birikim ekranı.
class _ForeignChips extends StatelessWidget {
  const _ForeignChips({required this.foreign});

  final Map<String, double> foreign;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SavingsScreen()),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final entry in foreign.entries)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                formatMoneyIn(entry.value, entry.key),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.accentStrong,
                ),
              ),
            ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.accentStrong),
        ],
      ),
    );
  }
}

/// Bu haftanın günlük kazanç ısı-çubukları (Pzt–Paz), bugün vurgulu.
class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final earned = ref.watch(allWorkDaysProvider).value ?? [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (i) => monday.add(Duration(days: i)));
    final byDay = <DateTime, double>{
      for (final d in earned)
        DateTime(d.date.year, d.date.month, d.date.day): (d.amount ?? 0),
    };
    final amounts = week.map((d) => byDay[d] ?? 0.0).toList();
    final total = amounts.fold<double>(0, (s, a) => s + a);
    final maxA = amounts.fold<double>(0, (m, a) => a > m ? a : m);

    Color heat(double a) {
      if (a <= 0) return c.heat0;
      if (maxA <= 0) return c.heat1;
      final r = a / maxA;
      if (r >= 0.999) return c.heat4;
      if (r >= 0.66) return c.heat3;
      if (r >= 0.33) return c.heat2;
      return c.heat1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              str.thisWeekEarnings,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * 16,
                color: c.text,
              ),
            ),
            Text(
              formatMoney(total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: _DayBar(
                  label: DateFormat('EEE', str.localeCode)
                      .format(week[i]),
                  amount: amounts[i],
                  color: heat(amounts[i]),
                  isToday: week[i] == today,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.amount,
    required this.color,
    required this.isToday,
  });

  final String label;
  final double amount;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final filled = amount > 0;
    // Bugün ise accent halka.
    final ring = isToday
        ? [
            BoxShadow(color: c.bg, spreadRadius: 2.5),
            BoxShadow(color: c.accent, spreadRadius: 4.5),
          ]
        : null;
    return Column(
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: ring,
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            filled ? formatMoneyCompact(amount) : '—',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: filled ? c.accentInk : c.textFaint,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? c.accent
                : (filled ? c.textMuted : c.textFaint),
          ),
        ),
      ],
    );
  }
}

/// Kazanç serisi çipi — haftalık şeridin altında ince amber pill.
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final streak = ref.watch(earningStreakProvider);
    final earnedToday = ref.watch(earnedTodayProvider);
    final active = streak > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: active ? c.amberBg : c.surface2,
        borderRadius: BorderRadius.circular(BudgyRadii.chip),
        border: Border.all(
          color: active ? c.amber.withValues(alpha: 0.45) : c.border,
        ),
      ),
      child: Row(
        children: [
          if (active)
            const Text('🔥', style: TextStyle(fontSize: 16))
          else
            Icon(Icons.local_fire_department_outlined,
                size: 18, color: c.textFaint),
          const SizedBox(width: 9),
          Expanded(
            child: active
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str.streakTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      if (!earnedToday) ...[
                        const SizedBox(height: 2),
                        Text(
                          str.streakKeepGoing,
                          style:
                              TextStyle(fontSize: 11.5, color: c.textMuted),
                        ),
                      ],
                    ],
                  )
                : Text(
                    str.streakStart,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
          ),
          if (active) ...[
            const SizedBox(width: 8),
            Text(
              tpl(str.streakDaysTpl, {'n': '$streak'}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: c.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tempo uyarısı — bütçesini aşması beklenen zarf varsa ince amber banner.
class _PaceBanner extends ConsumerWidget {
  const _PaceBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final count = ref.watch(overPaceCountProvider);
    if (count == 0) return const SizedBox.shrink();

    // paceProvider en riskliden başa sıralı — banner ona götürsün.
    final riskiest = ref
        .watch(paceProvider)
        .firstWhere((p) => p.willExceed)
        .envelope;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: c.amberBg,
        borderRadius: BorderRadius.circular(BudgyRadii.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(BudgyRadii.chip),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EnvelopeDetailScreen(envelopeId: riskiest.id),
            ),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BudgyRadii.chip),
              border: Border.all(color: c.amber.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: c.amber),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tpl(str.paceOverTpl, {'n': '$count'}),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.amber,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.amber),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zarf kartı — yeni "Sıcak Defter" stili (yüzey kart + tint ikon + ilerleme).
class _EnvelopeCard extends ConsumerWidget {
  const _EnvelopeCard({required this.envelope, required this.colorIndex});

  final Envelope envelope;
  final int colorIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final isForeign = envelope.currency != 'TRY';
    final spent = ref.watch(monthlySpentByEnvelopeProvider)[envelope.id] ?? 0;
    final budget = envelope.targetAmount;
    final hasBudget = !isForeign && budget != null && budget > 0;
    final over = hasBudget && spent > budget;
    final remaining = hasBudget ? (budget - spent).clamp(0, budget) : 0.0;
    // Tempoya göre ay sonunda aşması beklenen zarfın barı amber olsun.
    final willExceed = hasBudget &&
        ref
            .watch(paceProvider)
            .any((p) => p.envelope.id == envelope.id && p.willExceed);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(BudgyRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EnvelopeDetailScreen(envelopeId: envelope.id),
          ),
        ),
        onLongPress: () => showEditEnvelopeSheet(context, envelope),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BudgyRadii.card),
            border: Border.all(color: c.border),
            boxShadow: c.cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.envTintAt(colorIndex),
                      borderRadius:
                          BorderRadius.circular(BudgyRadii.icon),
                    ),
                    alignment: Alignment.center,
                    child: Text(envelope.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          envelope.displayName(str),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.01 * 14,
                            color: c.text,
                          ),
                        ),
                        Text(
                          isForeign ? str.savingsTitle : str.spentThisMonth,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isForeign)
                Text(
                  formatMoneyIn(envelope.balance, envelope.currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * 20,
                    color: c.text,
                  ),
                )
              else if (hasBudget) ...[
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: formatMoney(remaining.toDouble()),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.02 * 20,
                          color: over ? Colors.red : c.text,
                        ),
                      ),
                      TextSpan(
                        text: '  ${str.goalLeft}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBar(
                  value: (spent / budget).clamp(0, 1),
                  color: over
                      ? Colors.red
                      : (willExceed ? c.amber : c.accent),
                  background: c.track,
                  height: 6,
                  radius: 4,
                ),
                const SizedBox(height: 7),
                Text(
                  '${formatMoney(spent)} · ${formatMoneyIn(budget, 'TRY')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textFaint),
                ),
              ] else
                Text(
                  formatMoney(spent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * 20,
                    color: c.text,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddEnvelopeCard extends ConsumerWidget {
  const _AddEnvelopeCard({required this.nextSortOrder});

  final int nextSortOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(BudgyRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(BudgyRadii.card),
        onTap: () => showAddEnvelopeSheet(context, nextSortOrder),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(BudgyRadii.card),
            border: Border.all(color: c.borderStrong),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 26, color: c.textMuted),
              const SizedBox(height: 6),
              Text(
                ref.watch(strProvider).newEnvelope,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Son işlemler — token'lara uygun kart.
class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final txs = ref.watch(journalProvider).value ?? [];
    final visible = txs.where((t) => !t.isGoalFund).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final recent = visible.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              str.recentTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * 16,
                color: c.text,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              ),
              child: Text(
                str.seeAll,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(BudgyRadii.card),
            border: Border.all(color: c.border),
            boxShadow: c.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final tx in recent) TxTile(tx: tx, str: str),
            ],
          ),
        ),
      ],
    );
  }
}

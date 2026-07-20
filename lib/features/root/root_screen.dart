import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../../core/widget_service.dart';
import '../envelopes/home_screen.dart';
import '../goals/goals_screen.dart';
import '../stats/stats_screen.dart';
import '../transactions/quick_add_sheet.dart';
import '../workdays/calendar_screen.dart';

/// Kök + özel alt bar: Ana · Takvim · [+] · Hedefler · İstatistik.
/// Ortadaki yeşil FAB yeni işlem açar. Profil, ana ekrandaki avatardan.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    // Ana ekran widget'ını güncel tut (App Group yoksa güvenle no-op).
    ref.watch(widgetSyncProvider);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          CalendarScreen(),
          GoalsScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.tabbar,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _Tab(
                  icon: Icons.home_rounded,
                  label: str.tabHome,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _Tab(
                  icon: Icons.calendar_month_rounded,
                  label: str.tabCalendar,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                // Ortadaki yeni-işlem FAB'ı.
                SizedBox(
                  width: 66,
                  child: Center(
                    child: Material(
                      color: c.accent,
                      shape: const CircleBorder(),
                      elevation: 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => showQuickAdd(context),
                        child: const SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.add_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                _Tab(
                  icon: Icons.flag_rounded,
                  label: str.tabGoals,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _Tab(
                  icon: Icons.bar_chart_rounded,
                  label: str.tabAnalytics,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final color = selected ? c.accent : c.textFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

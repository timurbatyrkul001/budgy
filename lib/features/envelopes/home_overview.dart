import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../../core/tokens.dart';
import '../accounts/account.dart';
import '../accounts/account_editor_sheet.dart' show accountMoney;
import '../accounts/accounts_repository.dart';
import '../accounts/accounts_screen.dart';
import '../accounts/bank_catalog.dart';
import '../home/fx_providers.dart';
import '../settings/settings_hub.dart';
import '../space/space.dart';
import '../stats/stats_screen.dart';
import '../transactions/journal_screen.dart';
import '../transactions/tx.dart';
import 'home_period.dart';
import 'home_screen.dart' show profileNameProvider;

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Ay adı ("Ekim"); başka yıldaysa yılıyla ("Aralık 2025").
String _monthName(DateTime m, String code) {
  final now = DateTime.now();
  final name = _cap(DateFormat('LLLL', code).format(m));
  return m.year == now.year ? name : '$name ${m.year}';
}

String _signed(double v) => v > 0
    ? '+${formatMoney(v)}'
    : v < 0
    ? '−${formatMoney(-v)}'
    : formatMoney(0);

/// Mürekkep kart üstünde okunan yeşil/amber: kâğıt paletinin koyu tonları
/// (#17855D, #A9700C) siyah zeminde kayboluyordu.
const _inkGreen = Color(0xFF6FD3A1);
const _inkAmber = Color(0xFFF2B54A);

/// Hesap kutucuğunun simge rengi: nakit marka yeşili; kartta kullanıcının
/// seçtiği vurgu → renk indeksi → bankanın kimlik rengi → amber.
Color homeAccountTint(Account a) {
  if (a.kind == AccountKind.cash) return Ex.brand;
  if (a.accentColor case final argb?) return Color(argb);
  if (a.colorIndex case final i?) {
    return Ex.spaceColors[i % Ex.spaceColors.length];
  }
  return bankByName(a.name)?.color ?? Ex.amber;
}

IconData homeAccountIcon(Account a) => switch (a.kind) {
  AccountKind.cash => Icons.payments_rounded,
  AccountKind.card => Icons.credit_card_rounded,
  AccountKind.bank => Icons.account_balance_rounded,
};

// ── kahraman kart: dönem + net + gelir/gider + birikim oranı ─────────────

/// Afişin mürekkep bloğu. Seçili ayın NET akışı (gelir − gider) büyük,
/// altında gelir ↙ / gider ↗ ve gelirin ne kadarının kaldığını gösteren
/// çubuk. Ay oklarla değişir; grafik ve özet kartları da aynı ayı izler.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final o = ref.watch(homeOverviewProvider);
    // Selam yerine şu an elde olan para: ad zaten üst çipte yazıyor.
    final balance = ref.watch(accountsTotalProvider);
    final balanceText = balance == null ? '—' : formatMoney(balance);

    return Semantics(
      container: true,
      label:
          '${rs.homeBalance} $balanceText, ${rs.homeNet} ${_signed(o.net)}, '
          '${formatMoney(o.income)} / ${formatMoney(o.expense)}',
      child: Material(
        color: Ex.text,
        borderRadius: BorderRadius.circular(Ex.cardRadius + 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _push(context, const JournalScreen()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      // Bakiye → hesaplar sayfası (her hesap kendi biriminde).
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => showAccountsOverview(context),
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rs.homeBalance,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Ex.bg.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  balanceText,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontFamily: 'InterDisplay',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: Ex.bg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PeriodSwitcher(str: str, rs: rs),
                  ],
                ),
                const SizedBox(height: 18),
                ExcludeSemantics(
                  child: Text(
                    rs.homeNet,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Ex.bg.withValues(alpha: 0.62),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: o.net),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _signed(v),
                          style: const TextStyle(
                            fontFamily: 'InterDisplay',
                            fontSize: 44,
                            height: 0.96,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2.1,
                            color: Ex.bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ExcludeSemantics(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _Flow(
                        icon: Icons.south_west_rounded,
                        color: _inkGreen,
                        text: formatMoney(o.income),
                      ),
                      _Flow(
                        icon: Icons.north_east_rounded,
                        color: _inkAmber,
                        text: formatMoney(o.expense),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _SavedBar(rate: o.savedRate, rs: rs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Ex.bg,
          ),
        ),
      ],
    );
  }
}

/// Birikim oranı çubuğu: gelirin kalan payı yeşil; gider geliri aştıysa
/// çubuk amber dolar ve metin aşımı söyler. Gelir yoksa çubuk boş, metin
/// "gelir yok" — oran uydurulmaz.
class _SavedBar extends StatelessWidget {
  const _SavedBar({required this.rate, required this.rs});

  final double? rate;
  final RS rs;

  @override
  Widget build(BuildContext context) {
    final r = rate;
    final over = r != null && r < 0;
    final fill = r == null ? 0.0 : (over ? 1.0 : r.clamp(0.0, 1.0));
    final label = switch (r) {
      null => rs.homeNoIncome,
      < 0 => tpl(rs.homeOverTpl, {'n': '${(-r * 100).round()}'}),
      _ => tpl(rs.homeSavedTpl, {'n': '${(r * 100).round()}'}),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 5,
              backgroundColor: Ex.bg.withValues(alpha: 0.14),
              color: over ? _inkAmber : _inkGreen,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: r == null
                ? Ex.bg.withValues(alpha: 0.55)
                : (over ? _inkAmber : _inkGreen),
          ),
        ),
      ],
    );
  }
}

/// ‹ Bu ay › — son 6 ay içinde gezinme. Sınırda ok soluk ve basılmaz.
class _PeriodSwitcher extends ConsumerWidget {
  const _PeriodSwitcher({required this.str, required this.rs});

  final Strings str;
  final RS rs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(homeMonthOffsetProvider);
    final notifier = ref.read(homeMonthOffsetProvider.notifier);
    final month = ref.watch(homeOverviewProvider).month;
    final label = offset == 0
        ? str.periodThisMonth
        : _monthName(month, str.localeCode);

    Widget arrow(IconData icon, String tip, bool enabled, int delta) =>
        Semantics(
          button: true,
          enabled: enabled,
          label: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => notifier.shift(delta) : null,
            child: SizedBox(
              width: 32,
              height: 34,
              child: Icon(
                icon,
                size: 20,
                color: Ex.bg.withValues(alpha: enabled ? 0.9 : 0.25),
              ),
            ),
          ),
        );

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Ex.bg.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(
            Icons.chevron_left_rounded,
            rs.homePrevMonth,
            offset > HomeMonthOffset.minOffset,
            -1,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              label,
              key: ValueKey(label),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Ex.bg,
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, rs.homeNextMonth, offset < 0, 1),
        ],
      ),
    );
  }
}

// ── birikimli harcama grafiği ─────────────────────────────────────────────

/// Seçili ayın gün gün birikimli harcaması (dolu çizgi) ve önceki ayın
/// aynı eğrisi (kesik çizgi). Ayın neresinde, geçen aya göre önde mi
/// geride mi — tek bakışta.
class HomeTrendCard extends ConsumerWidget {
  const HomeTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final code = ref.watch(strProvider).localeCode;
    final o = ref.watch(homeOverviewProvider);
    final prev = o.prevCumulative;
    final prevTotal = prev == null || prev.isEmpty ? 0.0 : prev.last;
    if (o.expense <= 0 && prevTotal <= 0) return const SizedBox.shrink();

    final prevMonth = DateTime(o.month.year, o.month.month - 1);
    // Efsanede önceki ayın TAMAMI: kesik çizginin vardığı yerle aynı rakam.
    // Eskiden "aynı gün" değeri yazıyordu; Ekim'in 6'sında Eylül "0 ₺"
    // görünüp çizgi 34k'ya çıkınca kullanıcı grafiği yanlış sandı.
    final prevFull = prev == null || prev.isEmpty ? null : prev.last;

    return ExCard(
      onTap: () => _push(context, const StatsScreen()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rs.homeTrendTitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Ex.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(o.expense),
            style: const TextStyle(
              fontFamily: 'InterDisplay',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: Ex.text,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendPainter(
                current: o.cumulative,
                prev: prev,
                totalDays: o.daysInMonth,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in [1, 8, 15, 22, o.daysInMonth])
                Text(
                  '$d',
                  style: const TextStyle(fontSize: 11, color: Ex.textFaint),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Legend(
                dashed: false,
                text:
                    '${_monthName(o.month, code)} · ${formatMoney(o.expense)}',
              ),
              if (prevFull != null)
                _Legend(
                  dashed: true,
                  text:
                      '${_monthName(prevMonth, code)} · ${formatMoney(prevFull)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.dashed, required this.text});

  final bool dashed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 2,
          child: dashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(width: 3, height: 2, color: Ex.textFaint),
                  ],
                )
              : const ColoredBox(color: Ex.mint),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Ex.textSoft),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.current,
    required this.prev,
    required this.totalDays,
  });

  final List<double> current;
  final List<double>? prev;
  final int totalDays;

  @override
  void paint(Canvas canvas, Size size) {
    final p = prev;
    final maxV = math.max(
      math.max(
        current.isEmpty ? 0.0 : current.last,
        p == null || p.isEmpty ? 0.0 : p.last,
      ),
      1.0,
    );
    final stepX = size.width / math.max(totalDays - 1, 1);
    double x(int i) => i * stepX;
    double y(double v) => size.height - (v / maxV) * (size.height - 6) - 3;

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = Ex.border
        ..strokeWidth = 1,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (p != null && p.isNotEmpty) {
      final path = Path()..moveTo(x(0), y(p[0]));
      for (var i = 1; i < p.length; i++) {
        path.lineTo(x(i), y(p[i]));
      }
      final dash = Paint()
        ..color = Ex.textFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 8) {
          canvas.drawPath(metric.extractPath(d, d + 4), dash);
        }
      }
    }

    if (current.isNotEmpty) {
      final line = Path()..moveTo(x(0), y(current[0]));
      for (var i = 1; i < current.length; i++) {
        line.lineTo(x(i), y(current[i]));
      }
      final fill = Path.from(line)
        ..lineTo(x(current.length - 1), size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Ex.mint.withValues(alpha: 0.14),
              Ex.mint.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = Ex.mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final end = Offset(x(current.length - 1), y(current.last));
      canvas.drawCircle(end, 5, Paint()..color = Ex.surface);
      canvas.drawCircle(end, 3.5, Paint()..color = Ex.mint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.current != current || old.prev != prev || old.totalDays != totalDays;
}

// ── özet kartları ─────────────────────────────────────────────────────────

/// Üç küçük kart: eğilim (önceki ayın aynı gününe göre), günlük ortalama,
/// en büyük harcama. Dokununca analiz ekranı.
class HomeInsightsRow extends ConsumerWidget {
  const HomeInsightsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final main = ref.watch(currencyCodeProvider);
    final o = ref.watch(homeOverviewProvider);
    if (o.expense <= 0) return const SizedBox.shrink();

    final t = o.trend;
    final largest = o.largest;
    void open() => _push(context, const StatsScreen());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _InsightTile(
              title: rs.homeTrendCard,
              value: t == null
                  ? '—'
                  : '${t > 0
                        ? '+'
                        : t < 0
                        ? '−'
                        : ''}${(t.abs() * 100).round()}%',
              valueColor: t == null
                  ? Ex.textMuted
                  : t > 0
                  ? Ex.amber
                  : Ex.mint,
              icon: t == null
                  ? null
                  : t > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              sub: t == null ? rs.homeNoCompare : rs.homeVsPrev,
              onTap: open,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InsightTile(
              title: rs.avgPerDay,
              // Ortalamada kuruş gürültü: "1,763.33" yerine "1,763".
              value: formatMoney(o.avgPerDay.roundToDouble()),
              sub: _monthName(o.month, str.localeCode),
              onTap: open,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InsightTile(
              title: rs.homeLargest,
              value: largest == null ? '—' : formatMoney(largest.baseOr(main)),
              sub: largest == null
                  ? ''
                  : largest.note ?? largest.envelopeName ?? str.expenseWord,
              onTap: open,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.title,
    required this.value,
    required this.sub,
    required this.onTap,
    this.valueColor = Ex.text,
    this.icon,
  });

  final String title;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final Color valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Ex.textSoft,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, size: 16, color: valueColor),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.2,
              color: Ex.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── üst çip: kullanıcı ─────────────────────────────────────────────────────

/// Sol üst çip: avatar + ad soyad → ayarlar. Ad yoksa cüzdan adı.
/// [compact]: sağda iki kur çipi varken ad gizlenir, yalnız avatar kalır.
class HomeAccountsChip extends ConsumerWidget {
  const HomeAccountsChip({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceInfoProvider);
    final name = ref.watch(profileNameProvider) ?? space.name;

    return GlassChip(
      padding: const EdgeInsets.fromLTRB(5, 0, 8, 0),
      onTap: () => _push(context, const SettingsHubScreen()),
      child: Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SpaceAvatar(space: space, size: 30),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Ex.text,
                  ),
                ),
              ),
            ],
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: Ex.onGlowMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hesaplar sayfası: toplam + her hesap kendi biriminde + yönetim/ayarlar.
Future<void> showAccountsOverview(BuildContext context) {
  return showExSheet<void>(
    context,
    Consumer(
      builder: (sheetCtx, ref, _) {
        final rs = ref.watch(rsProvider);
        final total = ref.watch(accountsTotalProvider);
        final accounts =
            (ref.watch(accountsProvider).value ?? const <Account>[])
                .where((a) => !a.archived)
                .toList();
        void go(Widget screen) {
          Navigator.of(sheetCtx).pop();
          _push(context, screen);
        }

        return SheetFrame(
          title: rs.homeAllAccounts,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                total == null ? '—' : formatMoney(total),
                style: const TextStyle(
                  fontFamily: 'InterDisplay',
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                  color: Ex.text,
                ),
              ),
              if (total == null && accounts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  rs.homeRatesMissing,
                  style: const TextStyle(fontSize: 13, color: Ex.textMuted),
                ),
              ],
              const SizedBox(height: 16),
              if (accounts.isNotEmpty)
                ExCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final (i, a) in accounts.indexed) ...[
                        if (i > 0) const Divider(height: 1, color: Ex.border),
                        _AccountRow(account: a, rs: rs),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: rs.homeManageAccounts,
                onTap: () => go(const ManageAccountsScreen()),
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: rs.homeSettings,
                onTap: () => go(const SettingsHubScreen()),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.rs});

  final Account account;
  final RS rs;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final tint = homeAccountTint(a);
    final hasEmoji = a.emoji.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: Ex.squircle(34),
            ),
            child: hasEmoji
                ? Text(a.emoji, style: const TextStyle(fontSize: 16))
                : Icon(homeAccountIcon(a), size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              a.isCash && a.name.trim().isEmpty ? rs.cash : a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Ex.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            accountMoney(a.balance, a.currency),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Ex.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── son hareketler: gün grubu ─────────────────────────────────────────────

/// Gün başlığı ("Pzt, 5 Ekim · Bugün" + günün net akışı) ve o günün
/// satırları tek kartta.
class RecentDayGroup extends ConsumerWidget {
  const RecentDayGroup({super.key, required this.day});

  final RecentDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rel = day.day == today
        ? str.today
        : day.day == today.subtract(const Duration(days: 1))
        ? str.yesterday
        : null;
    final date = _cap(
      DateFormat('EEE, d MMMM', str.localeCode).format(day.day),
    );
    final head = rel == null ? date : '$date · $rel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  head,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ex.textMuted,
                  ),
                ),
              ),
              if (day.net != 0)
                Text(
                  _signed(day.net),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: day.net > 0 ? Ex.income : Ex.textMuted,
                  ),
                ),
            ],
          ),
        ),
        ExCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              for (final (i, e) in day.entries.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Ex.border),
                if (e.into case final into?)
                  _ConvertPairTile(out: e.tx, into: into, str: str)
                else
                  TxTile(tx: e.tx, str: str),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Döviz çevirmenin iki bacağı tek satırda: "Nakit → Dolar birikimi",
/// sağda çıkan ve giren tutar alt alta. Dokunma çıkan bacağın sayfasını
/// açar; silme grubu birlikte siler.
class _ConvertPairTile extends ConsumerWidget {
  const _ConvertPairTile({
    required this.out,
    required this.into,
    required this.str,
  });

  final Tx out;
  final Tx into;
  final Strings str;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final from =
        accountLabelOf(out, ref.watch(accountLabelsProvider)) ?? out.currency;
    final to = into.envelopeName ?? into.currency;
    return InkWell(
      onTap: () => TxTile.showActionsFor(context, ref, out, str),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.envFatura,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_horiz_rounded, size: 20, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$from → $to',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    str.convertTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '−${formatMoneyIn(out.amount, out.currency)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Ex.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${formatMoneyIn(into.amount, into.currency)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Ex.income,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

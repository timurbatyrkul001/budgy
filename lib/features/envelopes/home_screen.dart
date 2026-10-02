import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_avatar.dart';
import '../../core/currency_catalog.dart';
import '../../core/ex_style.dart';
import '../../core/motion.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../budget/budget_period.dart';
import '../budget/budget_screen.dart';
import '../converter/converter_logic.dart';
import '../converter/converter_screen.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../settings/app_settings.dart';
import '../settings/settings_hub.dart';
import '../reminders/reminders_repository.dart';
import '../root/bottom_tab_bar.dart';
import '../space/space.dart';
import '../stats/stats_screen.dart';
import '../transactions/category_sheet.dart';
import '../transactions/journal_screen.dart';
import '../transactions/tx.dart';
import 'budget_repository.dart';
import 'envelope_detail_screen.dart';
import 'envelope_l10n.dart';

/// Bu ay cüzdandan çıkan gerçek ₺ harcama: döviz çevirme, hedefe para
/// ayırma ve döviz işlemleri hariç (ana para birimi içeride 'TRY' kodudur,
/// simge ayarlardan gelir).
/// Karşılamada kullanılacak ilk ad; yoksa null (adsız selam).
///
/// Giriş yapılmış hesabın görünen adından gelir. Cüzdan adını ("Cüzdanım")
/// kullanmıyoruz — o bir mekân adı, kişi adı değil.
///
/// Sağlayıcıya alınmasının sebebi: `FirebaseAuth.instance`'ı doğrudan
/// widget içinde çağırmak, Firebase başlatılmayan widget testlerinde
/// "[core/no-app]" fırlatıyordu. Burada hem override edilebiliyor hem de
/// yakalanıyor — karşılama kartı bir selam yüzünden çökmemeli.
final greetingNameProvider = Provider<String?>((ref) {
  try {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(RegExp(r'\s+')).first;
  } catch (_) {
    return null;
  }
});

final monthSpentProvider = Provider<double>((ref) {
  return ref.watch(currentMonthTxsProvider).fold<double>(0, (sum, t) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) return sum;
    if (t.currency != 'TRY') return sum;
    return sum + t.amount;
  });
});

/// Bu ay kategorisiz ₺ giderler ("N işlem kategori bekliyor").
final uncategorizedTxsProvider = Provider<List<Tx>>((ref) {
  return ref
      .watch(currentMonthTxsProvider)
      .where(
        (t) =>
            t.type == TxType.expense &&
            !t.isConvert &&
            !t.isGoalFund &&
            t.currency == 'TRY' &&
            t.envelopeId == null,
      )
      .toList();
});

/// Ana ekran (kâğıt zemin): üstte cüzdan çipi + kur + ikon butonlar,
/// sola yaslı "bu ay harcanan", bütçe kartı, yatay hesap kartları, son
/// hareketler, hatırlatma kartı. Alt sekme çubuğu ve "+" kök ekranda
/// (root_screen); bu ekran yalnız listesinin altına çubuk payı bırakır.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bildirim zamanlayıcısı ana ekranda bir kez izlenir.
    ref.watch(reminderSchedulerProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: ExBackground(
        glow: 0.46,
        child: SafeArea(
          bottom: false,
          child: ListView(
            // Alt pay: yüzen sekme çubuğu + güvenli alan; son kart çubuğun
            // arkasına girmesin.
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              kBottomTabBarInset + 16 + bottom,
            ),
            // Bölümler ilk gösterimde 35 ms arayla solup yukarı kayarak
            // gelir; başlık sabit kalır. Yeniden kurulum tekrar oynatmaz.
            children: [
              const _Header(),
              const SizedBox(height: 34),
              const _Hero().enterUp(context, index: 0),
              const SizedBox(height: 14),
              const _SpendSparkline().enterUp(context, index: 1),
              const SizedBox(height: 22),
              const _BudgetCard().enterUp(context, index: 2),
              const _ReviewRow().enterUp(context, index: 3),
              const SizedBox(height: 26),
              const _AccountsSection().enterUp(context, index: 4),
              const SizedBox(height: 26),
              const _RecentSection().enterUp(context, index: 5),
              const _NotificationsCard().enterUp(context, index: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bu ayın birikimli harcaması — nane çizgi + yumuşak dolgu.
class _SpendSparkline extends ConsumerWidget {
  const _SpendSparkline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(currentMonthTxsProvider);
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final daily = List<double>.filled(days, 0);
    for (final t in txs) {
      if (t.type != TxType.expense || t.isConvert || t.isGoalFund) continue;
      if (t.currency != 'TRY') continue;
      daily[t.date.day - 1] += t.amount;
    }
    // Bugüne kadar birikimli; geri kalan günler çizilmez.
    final cumulative = <double>[];
    var sum = 0.0;
    for (var d = 0; d < now.day; d++) {
      sum += daily[d];
      cumulative.add(sum);
    }
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values: cumulative, totalDays: days),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.totalDays});

  final List<double> values;
  final int totalDays;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.last <= 0 ? 1.0 : values.last;
    final stepX = size.width / (totalDays - 1).clamp(1, 1 << 30);
    double x(int i) => i * stepX;
    double y(double v) => size.height - (v / maxV) * (size.height - 4) - 2;

    final line = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(line)
      ..lineTo(x(values.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Vurgu yeşili koyulaşınca eski %28 dolgu beyaz kartta boyalı
          // bir blok gibi duruyordu; çizginin altında hafif bir soluk kalsın.
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
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Bugünün noktası.
    canvas.drawCircle(
      Offset(x(values.length - 1), y(values.last)),
      3.5,
      Paint()..color = Ex.mint,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.totalDays != totalDays;
}

/// "N işlem kategori bekliyor" — kategorisiz ₺ giderler; dokun → liste →
/// kategori sayfası → işlemin kategorisi güncellenir.
class _ReviewRow extends ConsumerWidget {
  const _ReviewRow();

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final tx = await showExSheet<Tx>(
      context,
      Consumer(
        builder: (context, ref, _) {
          final items = ref.watch(uncategorizedTxsProvider);
          return SheetFrame(
            title: rs.reviewTitle,
            child: Column(
              children: [
                for (final t in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExCard(
                      onTap: () => Navigator.of(context).pop(t),
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        children: [
                          const CategoryAvatar.none(size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${t.note ?? rs.noCategory} · ${DateFormat('d MMM', str.localeCode).format(t.date)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Ex.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '−${formatMoney(t.amount)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Ex.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (tx == null || !context.mounted) return;
    final pick = await showCategorySheet(context);
    if (pick == null || !context.mounted) return;
    await guardWrite(
      context,
      str,
      () => ref
          .read(budgetRepositoryProvider)
          .setTxCategory(tx.id, envelopeId: pick.id, envelopeName: pick.name),
      reason: 'setTxCategory',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final items = ref.watch(uncategorizedTxsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final total = items.fold<double>(0, (s, t) => s + t.amount);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExCard(
        onTap: () => _open(context, ref),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Ex.amber.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(36),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 19,
                color: Ex.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tpl(rs.reviewTpl, {'n': '${items.length}'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  Text(
                    formatMoney(total),
                    style: const TextStyle(fontSize: 12.5, color: Ex.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

// ── üst satır ─────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceInfoProvider);
    final code = ref.watch(currencyCodeProvider);
    // Kur çipleri: yıldızlı paralar (en fazla 2), yoksa USD/EUR.
    final chips = dashboardCurrencies(
      ref.watch(starredCurrenciesProvider),
      code,
    );
    final snap = ref.watch(fxSnapshotProvider(code)).value;
    final compactWallet = chips.length > 1;

    // Cüzdan çipi solda, kur + istatistik + hesaplar sağ kenara yaslı.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: GlassChip(
            padding: const EdgeInsets.fromLTRB(5, 0, 8, 0),
            onTap: () => _push(context, const SettingsHubScreen()),
            child: Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SpaceAvatar(space: space, size: 30),
                  // İki kur çipi varken ad gizlenir — dar ekranda yer açar.
                  if (!compactWallet) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        space.name,
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
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kur çipleri: iki çipte bayrak gizlenir; dar ekranda son çare
              // olarak küçülür (taşma yok).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in chips) ...[
                        const SizedBox(width: 8),
                        GlassChip(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          onTap: () =>
                              _push(context, const CurrencyConverterScreen()),
                          child: Row(
                            children: [
                              if (!compactWallet) ...[
                                Text(
                                  flagFor(c),
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                Text(
                                  c,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Ex.onGlowMuted,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                switch (priceInMain(snap, c)) {
                                  final p? => formatRate(p),
                                  null => '—',
                                },
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Ex.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bütçe · Analiz (Hesaplar: "Tümü" ve cüzdan menüsünden).
              GlassSquareButton(
                icon: Icons.account_balance_wallet_rounded,
                onTap: () => _push(context, const BudgetScreen()),
              ),
              const SizedBox(width: 8),
              GlassSquareButton(
                icon: Icons.bar_chart_rounded,
                onTap: () => _push(context, const StatsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── bu ay harcanan ────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final code = ref.watch(strProvider).localeCode;
    final spent = ref.watch(monthSpentProvider);
    // Bağımsız ay adı (LLLL): TR/EN büyük harfle, RU «за сентябрь» küçük.
    final month = DateFormat('LLLL', code).format(DateTime.now());
    final label = tpl(rs.spentInTpl, {
      'month': code == 'ru' ? month.toLowerCase() : _cap(month),
    });

    final first = ref.watch(greetingNameProvider);
    final greeting = first == null
        ? rs.heroGreetingPlain
        : tpl(rs.heroGreetingTpl, {'name': first});

    return Semantics(
      container: true,
      button: true,
      label: '$greeting $label ${formatMoney(spent)}',
      child: Material(
        // Afişin mürekkebi: kâğıt zeminde en güçlü kontrast ve ekranın
        // sahibi olan tek blok. Referanstaki siyah karşılama kartının işi.
        color: Ex.text,
        borderRadius: BorderRadius.circular(Ex.cardRadius + 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _push(context, const JournalScreen()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'InterDisplay',
                            fontSize: 24,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                            color: Ex.bg,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            // Kâğıt rengi, kısılmış: başlıkla yarışmasın.
                            color: Ex.bg.withValues(alpha: 0.62),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: spent),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatMoney(v),
                                // Afişteki başlıklarla aynı ses: Display
                                // kesimi, en kalın ağırlık, sıkı aralık.
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Yuvarlak ok: kartın tamamı tıklanabilir ama dokunulabilir
                // bir şey olduğunu görsel olarak da söylüyor.
                ExcludeSemantics(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Ex.bg.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: Ex.bg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── bütçe ─────────────────────────────────────────────────────────────────

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final settings = ref.watch(budgetSettingsProvider);

    if (settings == null) {
      return ExCard(
        onTap: () => _push(context, const BudgetScreen()),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ex.brand.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(40),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 21,
                color: Ex.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rs.monthlyBudget,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rs.budgetEmpty,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Ex.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TintChipButton(
                    label: rs.setBudget,
                    onTap: () => _push(context, const BudgetScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Seçili döneme göre (haftalık/aylık) harcama ve kalan gün.
    final budget = settings.amount;
    final spent = ref.watch(periodSpentProvider);
    final left = budget - spent;
    final over = left < 0;
    final daysLeft = ref.watch(budgetWindowProvider).daysLeft(DateTime.now());

    return ExCard(
      onTap: () => _push(context, const BudgetScreen()),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  periodLabel(rs, settings.period),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Ex.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tpl(rs.daysLeftTpl, {'n': '$daysLeft'}),
                style: const TextStyle(fontSize: 12, color: Ex.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tpl(over ? rs.overTpl : rs.leftTpl, {
              'amount': formatMoney(left.abs()),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: over ? Ex.red : Ex.text,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 1 : (spent / budget).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Ex.surfaceHi,
              color: over ? Ex.red : Ex.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tpl(rs.ofTpl, {
              'spent': formatMoney(spent),
              'total': formatMoney(budget),
            }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Ex.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── bölüm başlığı ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Ex.text,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Ex.mint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── hesaplar (yatay) ──────────────────────────────────────────────────────

class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final cash = ref.watch(cashBalanceProvider).value ?? 0;
    final accounts = ref.watch(accountEnvelopesProvider);

    final cards = <Widget>[
      _AccountCard(
        icon: Icons.payments_rounded,
        color: Ex.brand,
        title: rs.cash,
        amount: formatMoney(cash),
        onTap: () => _push(context, const JournalScreen()),
      ),
      for (final e in accounts)
        _AccountCard(
          emoji: e.emoji,
          color: Ex.amber,
          title: e.displayName(str),
          amount: formatMoneyIn(e.balance, e.currency),
          onTap: () => _push(context, EnvelopeDetailScreen(envelopeId: e.id)),
        ),
      _AddAccountCard(onTap: () => addCurrencyWallet(context, ref)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.accounts,
          action: rs.seeAll,
          onAction: () => _push(context, const AccountsScreen()),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  final String title;
  final String amount;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: ExCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: Ex.squircle(28),
                  ),
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 14))
                      : Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Ex.textSoft,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Ex.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAccountCard extends ConsumerWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return SizedBox(
      width: 96,
      child: ExCard(
        color: Colors.transparent,
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 24, color: Ex.mint),
            const SizedBox(height: 4),
            Text(
              rs.addAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Ex.mint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── son hareketler ────────────────────────────────────────────────────────

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final txs = (ref.watch(journalProvider).value ?? const <Tx>[])
        .where((t) => !t.isGoalFund)
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.recent,
          action: txs.isEmpty ? null : rs.seeAll,
          onAction: () => _push(context, const JournalScreen()),
        ),
        if (txs.isEmpty)
          ExCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              rs.recentEmpty,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Ex.textSoft,
              ),
            ),
          )
        else
          ExCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final (i, t) in txs.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: Ex.border),
                  TxTile(tx: t, str: str),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── hatırlatma kartı ──────────────────────────────────────────────────────

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    // reminderSchedulerProvider ayarı görünce planlar ve izin ister.
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).saveProfile({
        'dailyReminder': true,
        'dailyHour': 21,
      }),
      reason: 'dailyReminder',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    if (ref.watch(dailyReminderProvider).enabled) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ExCard(
        onTap: () => _enable(context, ref),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Ex.amber.withValues(alpha: 0.16),
                borderRadius: Ex.squircle(40),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                size: 21,
                color: Ex.amber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rs.dailyReminder,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rs.dailyReminderSub,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Ex.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
          ],
        ),
      ),
    );
  }
}

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
import '../../core/load_error_banner.dart';
import '../../core/redesign_l10n.dart';
import '../accounts/account.dart';
import '../accounts/account_editor_sheet.dart'
    show accountMoney, showAccountEditor;
import '../accounts/accounts_repository.dart';
import '../accounts/accounts_screen.dart';
import '../budget/budget_screen.dart';
import '../converter/converter_logic.dart';
import '../converter/converter_screen.dart';
import '../goals/goals_screen.dart';
import '../home/fx_providers.dart';
import '../settings/app_settings.dart';
import '../reminders/reminders_repository.dart';
import '../root/bottom_tab_bar.dart';
import '../space/currency_wallets.dart';
import '../stats/stats_screen.dart';
import '../transactions/category_sheet.dart';
import '../transactions/journal_screen.dart';
import '../transactions/tx.dart';
import 'budget_repository.dart';
import 'envelope.dart';
import 'envelope_detail_screen.dart';
import 'envelope_l10n.dart';
import 'home_overview.dart';
import 'home_period.dart';

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

/// Üst çipte görünen ad soyad: profildeki ad (kayıt/kişisel bilgiler
/// ekranı oraya yazar), yoksa giriş sağlayıcısının görünen adı.
final profileNameProvider = Provider<String?>((ref) {
  final n = (ref.watch(profileProvider).value?['name'] as String?)?.trim();
  if (n != null && n.isNotEmpty) return n;
  try {
    final d = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return d == null || d.isEmpty ? null : d;
  } catch (_) {
    return null;
  }
});

/// Bu ay harcanan, ANA PARA BİRİMİNDE.
///
/// Eskiden burada `if (t.currency != 'TRY') return sum;` vardı: döviz
/// kartlarından yapılan her harcama toplamın DIŞINDA kalıyordu. Aynı
/// ekranda bütçe kartı (`periodSpentProvider`) aynı harcamaları doğru
/// sayınca, ana ekranda iki ayrı "bu ay harcanan" çıkıyordu — üstte
/// "0 ₺", hemen altta "591 ₺". Artık ikisi de `baseOr` kullanıyor,
/// yani dondurulmuş kuru olan kayıt ana birime çevrilmiş hâliyle,
/// kuru olmayan eski kayıt ise 0 olarak sayılıyor.
final monthSpentProvider = Provider<double>((ref) {
  final main = ref.watch(currencyCodeProvider);
  return ref.watch(currentMonthTxsProvider).fold<double>(0, (sum, t) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) return sum;
    return sum + t.baseOr(main);
  });
});

/// Bu ay kategorisiz giderler ("N işlem kategori bekliyor").
///
/// Burada da `t.currency == 'TRY'` süzgeci vardı — `monthSpentProvider`'daki
/// hatanın aynısı: döviz kartından yapılmış kategorisiz bir harcama
/// sayılmıyordu, yani kullanıcı "kategori bekleyen işlem yok" görüp o
/// harcamayı hiç kategorilemiyordu. Para birimi burada alakasız: kategorisi
/// olmayan her gider kategori bekliyor.
final uncategorizedTxsProvider = Provider<List<Tx>>((ref) {
  return ref
      .watch(currentMonthTxsProvider)
      .where(
        (t) =>
            t.type == TxType.expense &&
            !t.isConvert &&
            !t.isGoalFund &&
            t.envelopeId == null,
      )
      .toList();
});

/// Ana ekran (kâğıt zemin): üstte cüzdan çipi + kur + ikon butonlar,
/// sola yaslı "bu ay harcanan", bütçe kartı, yatay hesap kartları (kartlar +
/// nakit), varsa birikim şeridi (döviz kumbaraları + hedefler), son
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
              // Akışlardan biri düştüyse (kural, App Check, dizin) başlığın
              // hemen altında uyarı şeridi: aşağıdaki sıfırlar ve boş kartlar
              // "paran gitti" değil "yüklenemedi" okunsun. Düşmemişse hiç
              // çizilmez. Ana ekranın okuduğu her akış burada listeli.
              LoadErrorBanner(
                sources: [
                  recentTxsProvider,
                  journalProvider,
                  accountsProvider,
                  cashBalanceProvider,
                  envelopesProvider,
                ],
                padding: const EdgeInsets.only(top: 18),
              ),
              const SizedBox(height: 34),
              const HomeHero().enterUp(context, index: 0),
              const SizedBox(height: 12),
              const HomeTrendCard().enterUp(context, index: 1),
              const SizedBox(height: 8),
              const HomeInsightsRow().enterUp(context, index: 1),
              const _ReviewRow().enterUp(context, index: 3),
              const SizedBox(height: 26),
              const _AccountsSection().enterUp(context, index: 4),
              // Kumbara/hedef yoksa kendini çizmez; üst boşluğu kendi taşır.
              const _SavingsSection().enterUp(context, index: 5),
              const SizedBox(height: 26),
              const _RecentSection().enterUp(context, index: 6),
              const _NotificationsCard().enterUp(context, index: 7),
            ],
          ),
        ),
      ),
    );
  }
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
        Flexible(child: HomeAccountsChip(compact: compactWallet)),
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

// ── bölüm başlığı ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.action,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// Testler için: aynı ekranda birden çok "Tümü" olabilir.
  final Key? actionKey;

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
              key: actionKey,
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

/// Test kancaları: ana ekranda iki "Tümü" ve iki "+" var (hesaplar ve
/// birikim); metinle değil anahtarla ayırt edilir.
const kHomeAccountsSeeAllKey = ValueKey('home-accounts-see-all');
const kHomeAccountsAddKey = ValueKey('home-accounts-add');
const kHomeSavingsSeeAllKey = ValueKey('home-savings-see-all');
const kHomeSavingsAddKey = ValueKey('home-savings-add');

/// Hesaplar şeridi: kartlar + nakit (`Account`), her biri KENDİ biriminde.
///
/// Eskiden burada döviz kumbaraları (`accountEnvelopesProvider`) duruyordu;
/// kullanıcı Enpara kartını ekleyip ana ekranda göremiyordu — kartlar yalnız
/// ayarlarda ve harcama girerken görünüyordu. Kumbaralar artık aşağıdaki
/// "Birikim" bölümünde ([_SavingsSection]); burası paranın ÇIKTIĞI yerler.
///
/// Nakdin birimi `accountsProvider` içinde ana birime çekilir
/// (`Account.withMainCurrency`); burada ikinci bir kural yok. Liste boşsa
/// (ilk açılış, `accounts/cash` belgesi henüz yazılmadı) sentetik nakit
/// kartı: bakiye `cashBalanceProvider`'dan, birim ana birimden — kullanıcı
/// hesap kurmadan da cebindekini görsün.
///
/// Dokunma hesap yönetimi ekranını açar (günlük hesaba göre süzülü değil):
/// `JournalScreen` dışarıdan süzgeç almıyor ve o dosya bu işin sınırları
/// dışında.
class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final main = ref.watch(currencyCodeProvider);
    final cashFallback = ref.watch(cashBalanceProvider).value ?? 0;

    final list = accounts.isNotEmpty
        ? accounts
        : [
            Account(
              id: Account.cashId,
              name: '',
              currency: main,
              kind: AccountKind.cash,
              balance: cashFallback,
            ),
          ];

    void openManage() => _push(context, const ManageAccountsScreen());

    final cards = <Widget>[
      for (final a in list)
        _AccountCard(
          key: ValueKey('home-account-${a.id}'),
          icon: homeAccountIcon(a),
          emoji: a.emoji,
          color: homeAccountTint(a),
          title: a.isCash && a.name.trim().isEmpty ? rs.cash : a.name,
          // `formatMoneyIn` değil: o yalnız kumbara birimlerini (USD/EUR...)
          // tanır, manat/dolar kartı ₺ ile yazılırdı. Hesap ekranlarıyla
          // aynı biçimleyici.
          amount: accountMoney(a.balance, a.currency),
          onTap: openManage,
        ),
      _AddCard(
        key: kHomeAccountsAddKey,
        label: rs.addAccount,
        onTap: () => showAccountEditor(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.accounts,
          action: rs.seeAll,
          actionKey: kHomeAccountsSeeAllKey,
          onAction: openManage,
        ),
        _CardStrip(cards: cards),
      ],
    );
  }
}

// ── birikim (yatay) ───────────────────────────────────────────────────────

/// Birikim: döviz kumbaraları (`accountEnvelopesProvider`) + hedefler.
/// Kenara AYRILMIŞ para; harcama yapılan hesaplardan (yukarıdaki şerit)
/// bilinçli olarak ayrı.
///
/// İkisi de yoksa bölüm HİÇ çizilmez — ana ekranda boş bölüm gürültü.
/// Üst boşluk bölümün kendi içinde: gizliyken arkasında boşluk kalmasın.
///
/// Kumbaralar kategori ekranında görünmez (`currency == 'TRY'` süzer);
/// bu bölüm gizliyken onlara ve "+ döviz cüzdanı"na giden kalıcı yol
/// [GoalsScreen] (ayarlar › Hedefler; hesap yönetimindeki yön levhası) —
/// bölüm boşken orası tek kapı, bunu kırma.
class _SavingsSection extends ConsumerWidget {
  const _SavingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final wallets = ref.watch(accountEnvelopesProvider);
    final goals =
        (ref.watch(envelopesProvider).value ?? const <Envelope>[])
            .where((e) => e.isGoal && !e.archived)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (wallets.isEmpty && goals.isEmpty) return const SizedBox.shrink();

    final cards = <Widget>[
      for (final w in wallets)
        _AccountCard(
          key: ValueKey('home-wallet-${w.id}'),
          emoji: w.emoji,
          icon: Icons.savings_rounded,
          color: Ex.amber,
          title: w.displayName(str),
          amount: formatMoneyIn(w.balance, w.currency),
          onTap: () => _push(context, EnvelopeDetailScreen(envelopeId: w.id)),
        ),
      for (final g in goals)
        _AccountCard(
          key: ValueKey('home-goal-${g.id}'),
          emoji: g.emoji,
          icon: Icons.flag_rounded,
          color: Ex.mint,
          title: g.displayName(str),
          amount: formatMoneyIn(g.balance, g.currency),
          // Hedefin kumbaradan farkı: ince ilerleme çizgisi.
          progress: g.targetAmount == null ? null : g.progress,
          onTap: () => _push(context, EnvelopeDetailScreen(envelopeId: g.id)),
        ),
      _AddCard(
        key: kHomeSavingsAddKey,
        label: rs.addSavingsWallet,
        width: 110,
        onTap: () => addCurrencyWallet(context, ref),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: str.savingsTitle,
            action: rs.seeAll,
            actionKey: kHomeSavingsSeeAllKey,
            onAction: () => _push(context, const GoalsScreen()),
          ),
          _CardStrip(cards: cards),
        ],
      ),
    );
  }
}

/// Yatay kutucuk şeridi — hesaplar ve birikim aynı yüksekliği paylaşır.
class _CardStrip extends StatelessWidget {
  const _CardStrip({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}

/// Kompakt kutucuk: simge/emoji + ad üstte, tutar altta. Hesap da kumbara da
/// hedef de aynı kalıp; [emoji] boşsa [icon] çizilir, [progress] verilirse
/// tutarın altına ince çizgi gelir.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    super.key,
    required this.title,
    required this.amount,
    required this.color,
    required this.onTap,
    this.icon,
    this.emoji,
    this.progress,
  });

  final String title;
  final String amount;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final String? emoji;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final showEmoji = emoji != null && emoji!.trim().isNotEmpty;
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
                  child: showEmoji
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
            if (progress case final p?) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 3,
                  backgroundColor: Ex.surfaceHi,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Şeridin sonundaki "+" kutucuğu. [label] iki satıra sığabilir
/// ("Валютный кошелёк"); hesaplarda tek kelime ("Ekle").
class _AddCard extends StatelessWidget {
  const _AddCard({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 96,
  });

  final String label;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ExCard(
        color: Colors.transparent,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 24, color: Ex.mint),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.15,
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
    final journal = ref.watch(journalProvider);
    // "Henüz hareket yok" yalnız akış gerçekten boş liste verdiyse. Veri
    // hiç gelmediyse (yükleniyor ya da düştü) bölüm çizilmez — düşme hâlini
    // üstteki [LoadErrorBanner] anlatıyor; sahte bir "boş" kart onunla
    // çelişirdi.
    if (!journal.hasValue) return const SizedBox.shrink();
    // Günlere bölünmüş, çevirme bacakları tek satırda (bkz. [groupRecent]).
    final days = groupRecent(
      journal.value ?? const <Tx>[],
      main: ref.watch(currencyCodeProvider),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: rs.recent,
          action: days.isEmpty ? null : rs.seeAll,
          onAction: () => _push(context, const JournalScreen()),
        ),
        if (days.isEmpty)
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
          for (final (i, d) in days.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            RecentDayGroup(day: d),
          ],
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

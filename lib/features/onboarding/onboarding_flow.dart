import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/currency_info.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../auth/sign_in_screen.dart';
import '../envelopes/budget_repository.dart';
import '../space/currency_wallet_sheet.dart';
import '../space/space.dart';

/// 3 adımlı onboarding: karşılama → para birimi → cüzdan adı.
/// Sonunda para birimi + cüzdan + hazır kategoriler yazılır ve
/// `onboardingDone` işaretlenir; auth kapısı ana ekrana geçer.
///
/// [preview] (yalnız `--dart-define=PREVIEW_ONBOARDING=true`): hiçbir şey
/// yazmaz, son buton sadece geri döner — ekran görüntüsü almak için.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, this.preview = false, this.initialStep = 0});

  final bool preview;

  /// Başlangıç adımı (0-2) — önizlemede belirli bir adımı açmak için.
  final int initialStep;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late int _page = widget.initialStep.clamp(0, 2);
  bool _forward = true;
  bool _saving = false;
  late String _currency;
  SpaceInfo? _draft;

  /// Ana cüzdanın başlangıç tutarı (boş = 0) ve ek döviz cüzdanları —
  /// "Başlayalım"a kadar yalnız yerel taslak.
  final _mainAmount = TextEditingController();
  final _extras = <CurrencyWalletDraft>[];

  @override
  void initState() {
    super.initState();
    _currency =
        currencyForRegion(PlatformDispatcher.instance.locale.countryCode);
    // Önizleme doğrudan cüzdan adımında açılırsa dolu hâlini göster
    // (ekran görüntüsü için); veri yazılmaz.
    if (widget.preview && widget.initialStep == 2) {
      _mainAmount.text = '12500';
      _extras.addAll(const [
        CurrencyWalletDraft(code: 'USD', amount: 500),
        CurrencyWalletDraft(code: 'EUR', amount: 120),
      ]);
    }
  }

  @override
  void dispose() {
    _mainAmount.dispose();
    super.dispose();
  }

  /// Ana para birimi değişince aynı koddaki ek cüzdan anlamsızlaşır.
  void _setCurrency(String code) => setState(() {
        _currency = code;
        _extras.removeWhere((e) => e.code == code);
      });

  Future<void> _addExtra() async {
    final draft = await showCurrencyWalletSheet(context,
        exclude: {_currency, for (final e in _extras) e.code});
    if (draft != null) setState(() => _extras.add(draft));
  }

  /// Taslak cüzdan: dil değişirse varsayılan ad da değişsin diye tembel.
  SpaceInfo _space(RS rs) => _draft ??= SpaceInfo(
        name: rs.defaultWalletName,
        color: Ex.spaceColors.first.toARGB32(),
      );

  void _go(int page) => setState(() {
        _forward = page > _page;
        _page = page;
      });

  Future<void> _changeCurrency() async {
    final code = await showCurrencyPicker(context, selected: _currency);
    if (code != null) _setCurrency(code);
  }

  Future<void> _customize(RS rs) async {
    final result = await showSpaceEditor(context,
        initial: _space(rs), currency: _currency);
    if (result != null) {
      setState(() => _draft = result.info);
      _setCurrency(result.currency);
    }
  }

  void _signIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignInScreen(
          // Mevcut hesapta onboarding zaten bitmiş — auth kapısı ana
          // ekrana kendisi geçer; biz sadece köke dönüyoruz.
          onSignedIn: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  Future<void> _start(RS rs) async {
    if (_saving) return;
    if (widget.preview) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _saving = true);
    // Repo'yu ÖNCE al: yazma sırasında auth kapısı bu widget'ı değiştirebilir,
    // sonra ref okumak güvenli olmaz.
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    final hasEnvelopes = ref.read(envelopesProvider).value?.isNotEmpty ?? false;
    final space = _space(rs);
    try {
      await repo.setCurrency(_currency);
      await repo.saveProfile(space.toProfile());
      // Harcama kategorileri hâlâ gerekli (gider sınıflandırma) — sessizce
      // hazır seti oluştur.
      if (!hasEnvelopes) {
        await repo.addEnvelopes([
          for (final p in presetEnvelopes)
            (
              key: p.key,
              emoji: p.emoji,
              name: str.presetNames[p.key] ?? p.key,
            ),
        ]);
      }
      // Başlangıç bakiyesi: ₺ cüzdana gelir; dövizler ayrı kumbara zarfı.
      final mainAmount = parseAmount(_mainAmount.text) ?? 0;
      if (mainAmount > 0) {
        await repo.addCashIncome(amount: mainAmount, note: rs.startingBalance);
      }
      // Sıra numarası mevcut/hazır zarfların ardından devam eder.
      var sortOrder = hasEnvelopes
          ? (ref.read(envelopesProvider).value?.length ?? 0)
          : presetEnvelopes.length;
      for (final e in _extras) {
        await repo.addCurrencyWallet(
          code: e.code,
          name: walletNameFor(rs, e.code),
          emoji: walletEmojiFor(e.code),
          amount: e.amount,
          sortOrder: sortOrder++,
          note: rs.startingBalance,
        );
      }
      await repo.setOnboardingDone();
    } catch (_) {
      if (mounted) {
        showErrorSnack(context, str.errorSaveFailed);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final pages = [
      _WelcomePage(rs: rs, onNext: () => _go(1), onSignIn: _signIn),
      _CurrencyPage(
        rs: rs,
        code: _currency,
        onChange: _changeCurrency,
        onUse: () => _go(2),
      ),
      _WalletPage(
        rs: rs,
        space: _space(rs),
        currency: _currency,
        amount: _mainAmount,
        extras: _extras,
        onAddExtra: _addExtra,
        onRemoveExtra: (i) => setState(() => _extras.removeAt(i)),
        onCustomize: () => _customize(rs),
        onStart: _saving ? null : () => _start(rs),
      ),
    ];

    return Scaffold(
      body: ExBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Üst şerit: geri (2-3. adım) + 3 parçalı ilerleme çubuğu.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _page > 0
                            ? Padding(
                                key: const ValueKey('back'),
                                padding: const EdgeInsets.only(right: 14),
                                child:
                                    ExBackButton(onTap: () => _go(_page - 1)),
                              )
                            : const SizedBox.shrink(key: ValueKey('none')),
                      ),
                      Expanded(child: StepBar(count: 3, index: _page)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final incoming = child.key == ValueKey(_page);
                    final dx = (incoming == _forward) ? 0.08 : -0.08;
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: pages[_page],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük ekranda taşmadan yerleşen dikey düzen: içerik sığarsa Spacer'lar
/// boşluğu paylaşır, sığmazsa kayar.
class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sola yaslı başlık + alt başlık.
class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle, {this.big = false});

  final String title;
  final String subtitle;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: big ? 36 : 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: big ? -1.2 : -0.7,
            color: Ex.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(
              fontSize: 16, height: 1.4, color: Ex.onGlowMuted),
        ),
      ],
    );
  }
}

// ── 1) Karşılama ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.rs,
    required this.onNext,
    required this.onSignIn,
  });

  final RS rs;
  final VoidCallback onNext;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return _FillScroll(
      children: [
        const SizedBox(height: 28),
        const Align(
          alignment: Alignment.centerLeft,
          child: BudgyIcon(size: 56, radiusFactor: 0.3),
        ),
        const SizedBox(height: 24),
        _Title(rs.onbTitle, rs.onbSubtitle, big: true),
        const Spacer(),
        const SizedBox(height: 28),
        ExCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _Feature(
                  icon: Icons.mic_rounded, color: Ex.mint, text: rs.featVoice),
              const Divider(height: 1, color: Ex.border),
              _Feature(
                  icon: Icons.currency_exchange_rounded,
                  color: const Color(0xFF6FB6FF),
                  text: rs.featCurrency),
              const Divider(height: 1, color: Ex.border),
              _Feature(
                  icon: Icons.cloud_done_rounded,
                  color: Ex.amber,
                  text: rs.featCloud),
              const Divider(height: 1, color: Ex.border),
              _Feature(
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFC79BFF),
                  text: rs.featNoSignup),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: rs.next, onTap: onNext),
        const SizedBox(height: 4),
        GhostButton(label: rs.haveAccount, onTap: onSignIn),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Ex.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2) Para birimi ───────────────────────────────────────────────────────

class _CurrencyPage extends StatelessWidget {
  const _CurrencyPage({
    required this.rs,
    required this.code,
    required this.onChange,
    required this.onUse,
  });

  final RS rs;
  final String code;
  final VoidCallback onChange;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return _FillScroll(
      children: [
        const SizedBox(height: 28),
        _Title(rs.currencyTitle, rs.currencySubtitle),
        const SizedBox(height: 32),
        const Spacer(),
        CurrencyTile(code: code, selected: true, large: true),
        const Spacer(flex: 2),
        const SizedBox(height: 20),
        PrimaryButton(
            label: tpl(rs.continueWithTpl, {'code': code}), onTap: onUse),
        const SizedBox(height: 4),
        GhostButton(label: rs.chooseAnother, onTap: onChange),
      ],
    );
  }
}

// ── 3) Cüzdan ────────────────────────────────────────────────────────────

class _WalletPage extends StatelessWidget {
  const _WalletPage({
    required this.rs,
    required this.space,
    required this.currency,
    required this.amount,
    required this.extras,
    required this.onAddExtra,
    required this.onRemoveExtra,
    required this.onCustomize,
    required this.onStart,
  });

  final RS rs;
  final SpaceInfo space;
  final String currency;
  final TextEditingController amount;
  final List<CurrencyWalletDraft> extras;
  final VoidCallback onAddExtra;
  final ValueChanged<int> onRemoveExtra;
  final VoidCallback onCustomize;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return _FillScroll(
      children: [
        const SizedBox(height: 28),
        _Title(rs.walletTitle, rs.walletSubtitle),
        const SizedBox(height: 24),
        // Ana cüzdan: kimlik satırı + başlangıç tutarı.
        ExCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onCustomize,
                child: Row(
                  children: [
                    SpaceAvatar(space: space, size: 52),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: Ex.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Ex.surfaceHi,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${currencyFlag(currency)}  $currency',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Ex.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_rounded,
                        size: 20, color: Ex.textMuted),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: Ex.border),
              ),
              Text(rs.startingAmount,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Ex.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Ex.text, fontWeight: FontWeight.w800, fontSize: 20),
                decoration: InputDecoration(
                  hintText: '0',
                  fillColor: Ex.surfaceHi,
                  suffixText: kCurrencies[currency] ?? currency,
                  suffixStyle:
                      const TextStyle(color: Ex.textMuted, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Ek döviz cüzdanları.
        Text(rs.otherCurrencies,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Ex.text)),
        const SizedBox(height: 4),
        Text(rs.otherCurrenciesHint,
            style: const TextStyle(
                fontSize: 13, height: 1.35, color: Ex.textMuted)),
        const SizedBox(height: 10),
        for (final (i, e) in extras.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExtraRow(draft: e, onRemove: () => onRemoveExtra(i)),
          ),
        GhostButton(label: rs.addCurrencyWallet, onTap: onAddExtra),
        const Spacer(),
        const SizedBox(height: 16),
        PrimaryButton(label: rs.letsGo, onTap: onStart),
        const SizedBox(height: 4),
        GhostButton(label: rs.customize, onTap: onCustomize),
      ],
    );
  }
}

/// Taslaktaki ek döviz cüzdanı satırı: bayrak + ad + tutar + kaldır.
class _ExtraRow extends StatelessWidget {
  const _ExtraRow({required this.draft, required this.onRemove});

  final CurrencyWalletDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ExCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Text(currencyFlag(draft.code), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currencyName(draft.code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Ex.text),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoneyIn(draft.amount, draft.code),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Ex.mint),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20, color: Ex.textFaint),
          ),
        ],
      ),
    );
  }
}

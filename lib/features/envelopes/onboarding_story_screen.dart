import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../auth/sign_in_screen.dart';
import 'budget_repository.dart';
import 'onboarding_screen.dart';

/// Стори-онбординг в стиле "Sıcak Defter": фон c.bg, app-mockup
/// иллюстрация сверху, крупный заголовок по центру, точки прогресса,
/// accent-кнопка с glow. Skip — текст сверху справа.
class OnboardingStoryScreen extends ConsumerStatefulWidget {
  const OnboardingStoryScreen({super.key, this.preview = false});

  final bool preview;

  @override
  ConsumerState<OnboardingStoryScreen> createState() =>
      _OnboardingStoryScreenState();
}

class _OnboardingStoryScreenState
    extends ConsumerState<OnboardingStoryScreen> {
  final _controller = PageController();
  int _page = 0;
  // Фазы онбординга по порядку.
  _Phase _phase = _Phase.splash;
  // Конверты, выбранные в этой сессии (для экрана обзора).
  List<({String emoji, String name})> _created = const [];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _phase == _Phase.splash) {
        setState(() => _phase = _Phase.slides);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int total) {
    if (_page < total - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _toCategory();
    }
  }

  // После слайдов — выбор конвертов (в preview просто закрываемся).
  void _toCategory() {
    if (widget.preview) {
      Navigator.of(context).pop();
    } else {
      setState(() => _phase = _Phase.category);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.splash) return const _SplashLogo();
    if (_phase == _Phase.category) {
      return OnboardingScreen(
        onDone: (created) => setState(() {
          _created = created;
          _phase = created.isEmpty ? _Phase.welcome : _Phase.review;
        }),
      );
    }
    if (_phase == _Phase.review) {
      return _ReviewScreen(
        envelopes: _created,
        onContinue: () => setState(() => _phase = _Phase.welcome),
      );
    }
    if (_phase == _Phase.welcome) {
      return _WelcomeScreen(
        onStart: () =>
            ref.read(budgetRepositoryProvider).setOnboardingDone(),
      );
    }

    final c = context.budgy;
    final str = ref.watch(strProvider);
    final story = str.onbStory;
    final total = story.length;
    final isLast = _page == total - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // "Atla" — сверху справа, как в макете.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 0),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: c.textMuted,
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _toCategory,
                    child: Text(str.skip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _StoryPage(
                  index: index,
                  title: story[index].title,
                  subtitle: story[index].subtitle,
                ),
              ),
            ),
            // Прогресс: önizlemede sadece slaytlar; tam akışta + welcome/seçim.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: OnboardingProgress(
                segments: widget.preview ? total : total + 3,
                filledUpTo: _page,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 4, 30, 20),
              child: _PrimaryButton(
                label: isLast
                    ? (widget.preview
                        ? MaterialLocalizations.of(context).okButtonLabel
                        : str.onbStart)
                    : str.onbContinue,
                onPressed: () => _next(total),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Phase { splash, slides, category, review, welcome }

/// Точки прогресса онбординга: активная ([filledUpTo]) — широкая «пилюля»
/// в accent, остальные — маленькие точки в цвете трека (идиома `_Dots`).
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.segments,
    required this.filledUpTo,
  });

  final int segments;
  final int filledUpTo;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < segments; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == filledUpTo ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == filledUpTo ? c.accent : c.track,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i != segments - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

/// Primary-кнопка "Sıcak Defter": accent-заливка, белый текст,
/// мягкий glow (идиома из onboarding_screen).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Финальный экран онбординга: монета + «Welcome to Budgy» + кнопка входа.
class _WelcomeScreen extends ConsumerWidget {
  const _WelcomeScreen({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    // Контент-блок ровно по макету: 344×453, top 180 / left 16 /
    // right 15 / bottom 179 на экране 375×812.
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned(
            top: 180,
            left: 16,
            right: 15,
            // bottom sabit değil: içerik verilen boşluklara göre uzar,
            // böylece taşma (overflow) olmaz.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BudgyWordmark(iconSize: 28, fontSize: 20, gap: 8),
                const SizedBox(height: 14),
                Text(
                  str.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                // welcomeSubtitle = «Get a daily overview...»
                Text(
                  str.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: c.textMuted),
                ),
                // ↓ İstenen boşluk: subtitle ile sign-up butonları arası = 32
                const SizedBox(height: 32),
                _SocialButton(
                  label: str.signUpApple,
                  leading:
                      Image.asset('assets/brand/apple.png', height: 22),
                  onTap: onStart,
                ),
                // Butonlar arası = 8
                const SizedBox(height: 8),
                _SocialButton(
                  label: str.continueGoogle,
                  leading:
                      Image.asset('assets/brand/google.png', height: 22),
                  onTap: onStart,
                ),
                const SizedBox(height: 8),
                _SocialButton(
                  label: str.continueFacebook,
                  leading:
                      Image.asset('assets/brand/facebook.png', height: 22),
                  onTap: onStart,
                ),
                // Facebook ↓ "or sign up with" arası = 24
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: c.borderStrong)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        str.orSignUpWith,
                        style:
                            TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ),
                    Expanded(child: Divider(color: c.borderStrong)),
                  ],
                ),
                // "or sign up with" ↓ Login = 24
                const SizedBox(height: 24),
                _PrimaryButton(
                  label: str.loginMyAccount,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SignInScreen(onSignedIn: onStart),
                    ),
                  ),
                ),
                // Login ↓ Terms = 100
                const SizedBox(height: 100),
                Text(
                  str.termsNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5, height: 1.35, color: c.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Обзор выбранных конвертов («seçtiklerin»): сетка кружков в тинтах
/// конвертов с accent-кольцом, подтверждение перед Welcome.
class _ReviewScreen extends ConsumerWidget {
  const _ReviewScreen({required this.envelopes, required this.onContinue});

  /// Только выбранные в этой сессии конверты (без старых).
  final List<({String emoji, String name})> envelopes;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    str.reviewTitle,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    str.reviewSubtitle,
                    style: TextStyle(
                        fontSize: 15, color: c.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemCount: envelopes.length,
                itemBuilder: (context, index) {
                  final env = envelopes[index];
                  return Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: c.envTintAt(index),
                          shape: BoxShape.circle,
                          border: Border.all(color: c.accent, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(env.emoji,
                            style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        env.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: OnboardingProgress(
                  segments: str.onbStory.length + 3,
                  filledUpTo: str.onbStory.length + 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 20),
              child: _PrimaryButton(
                label: str.onbContinue,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопка соц-входа: карточка surface с рамкой, иконка слева.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          backgroundColor: c.surface,
          side: BorderSide(color: c.borderStrong),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash-логотип: монета + «Budgy» по центру (как заставка Cashly).
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Scaffold(
      backgroundColor: c.bg,
      body: const Center(
        child: BudgyWordmark(iconSize: 56, fontSize: 34),
      ),
    );
  }
}

/// Один слайд: app-mockup иллюстрация по центру сверху,
/// заголовок + текст по центру снизу (по макету OnboardingScreen).
class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  final int index;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          const Spacer(flex: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: _StoryMockup(index: index),
          ),
          const Spacer(flex: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: c.text,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.45,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// App-mockup иллюстрация слайда (вместо 3D PNG): мини-виджеты
/// приложения в токенах — kazanç-пилюля, зарф-карточки, kumbara.
class _StoryMockup extends ConsumerWidget {
  const _StoryMockup({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    switch (index % 3) {
      // 1) Gelirini gir: kazanç-пилюля + мини-неделя из календаря.
      case 0:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EarnPill(label: str.earned, amount: 1250),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(18),
                boxShadow: c.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    str.thisWeekEarnings,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final heats = [
                      c.heat3,
                      c.heat4,
                      c.heat1,
                      c.heat4,
                      c.heat2,
                      c.heat0,
                      c.heat0,
                    ];
                    return Row(
                      children: [
                        for (final (i, heat) in heats.indexed) ...[
                          if (i != 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 26,
                              decoration: BoxDecoration(
                                color: heat,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      // 2) Zarflara böl: пилюля → ветки → три зарф-карточки (как в макете).
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EarnPill(label: str.earned, amount: 1250),
            const SizedBox(height: 10),
            CustomPaint(
              size: const Size(120, 46),
              painter: _BranchPainter(c.accent),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, spec) in const [
                  (envIndex: 0, amount: 500.0),
                  (envIndex: 1, amount: 300.0),
                  (envIndex: 2, amount: 150.0),
                ].indexed) ...[
                  if (i != 0) const SizedBox(width: 12),
                  Expanded(
                    child: _MiniEnvCard(
                      emoji: presetEnvelopes[spec.envIndex].emoji,
                      name: str.presetNames[
                              presetEnvelopes[spec.envIndex].key] ??
                          presetEnvelopes[spec.envIndex].key,
                      amount: spec.amount,
                      tint: c.envTintAt(spec.envIndex),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      // 3) Biriktir & hedef koy: kumbara-карточка с прогрессом к цели.
      default:
        final savings = presetEnvelopes[8]; // 'savings' 💰
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(18),
            boxShadow: c.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.envTintAt(8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(savings.emoji,
                        style: const TextStyle(fontSize: 19)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    str.presetNames[savings.key] ?? savings.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 65,
                        child: ColoredBox(color: c.accent),
                      ),
                      Expanded(
                        flex: 35,
                        child: ColoredBox(color: c.track),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatMoney(6500),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.accent,
                    ),
                  ),
                  Text(
                    formatMoney(10000),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textFaint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

/// Amber «kazanç» пилюля: точка + подпись + сумма (по макету).
class _EarnPill extends StatelessWidget {
  const _EarnPill({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: c.amberBg,
        border: Border.all(color: c.amber),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: c.amber, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.amber,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoney(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Мини-карточка конверта из макета: тинт-иконка, имя, сумма.
class _MiniEnvCard extends StatelessWidget {
  const _MiniEnvCard({
    required this.emoji,
    required this.name,
    required this.amount,
    required this.tint,
  });

  final String emoji;
  final String name;
  final double amount;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: c.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: c.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ветвление «пилюля → зарфы» из макета (SVG-пути, масштаб 120×46).
class _BranchPainter extends CustomPainter {
  const _BranchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 46;

    final soft = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final branches = Path()
      ..moveTo(60 * sx, 2 * sy)
      ..lineTo(60 * sx, 12 * sy)
      ..moveTo(60 * sx, 12 * sy)
      ..cubicTo(60 * sx, 24 * sy, 22 * sx, 22 * sy, 22 * sx, 40 * sy)
      ..moveTo(60 * sx, 12 * sy)
      ..cubicTo(60 * sx, 24 * sy, 98 * sx, 22 * sy, 98 * sx, 40 * sy)
      ..moveTo(60 * sx, 12 * sy)
      ..lineTo(60 * sx, 38 * sy);
    canvas.drawPath(branches, soft);

    final arrows = Path()
      ..moveTo(22 * sx, 34 * sy)
      ..lineTo(22 * sx, 40 * sy)
      ..lineTo(16 * sx, 38 * sy)
      ..moveTo(60 * sx, 32 * sy)
      ..lineTo(60 * sx, 38 * sy)
      ..moveTo(104 * sx, 34 * sy)
      ..lineTo(104 * sx, 40 * sy)
      ..lineTo(110 * sx, 38 * sy);
    canvas.drawPath(arrows, solid);
  }

  @override
  bool shouldRepaint(_BranchPainter oldDelegate) =>
      oldDelegate.color != color;
}

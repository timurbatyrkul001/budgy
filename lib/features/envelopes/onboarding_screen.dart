import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import 'budget_repository.dart';

/// Выбор стартовых конвертов: сетка кружков-эмодзи в тинтах "Sıcak Defter",
/// выбранные — в зелёном кольце. Skip — текст сверху справа (как в макете).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Вызывается после выбора конвертов со списком созданных в этой
  /// сессии (emoji + имя) — экран обзора показывает только их.
  /// Пустой список (skip) → сразу Welcome. Если null — завершает онбординг.
  final void Function(List<({String emoji, String name})> created)? onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Set<int>? _selected;
  bool _saving = false;

  Future<void> _finish({required bool create}) async {
    final str = ref.read(strProvider);
    final selected = _selected ?? <int>{};
    setState(() => _saving = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final picked = [
        for (final (index, item) in presetEnvelopes.indexed)
          if (selected.contains(index))
            (
              key: item.key,
              emoji: item.emoji,
              name: str.presetNames[item.key] ?? item.key,
            ),
      ];
      if (create && picked.isNotEmpty) {
        await repo.addEnvelopes(picked);
      }
      // Список для экрана обзора — только созданные в этой сессии.
      final created = create
          ? [for (final p in picked) (emoji: p.emoji, name: p.name)]
          : <({String emoji, String name})>[];
      if (widget.onDone != null) {
        widget.onDone!(created);
      } else {
        await repo.setOnboardingDone();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final suggestions = presetEnvelopes;
    // Пусто по умолчанию — пользователь сам выбирает конверты.
    final selected = _selected ?? <int>{};

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    onPressed:
                        _saving ? null : () => _finish(create: false),
                    child: Text(str.skip),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 4, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    str.onbSelectTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    str.onboardSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: c.textMuted, height: 1.45),
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
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  final isSelected = selected.contains(index);
                  return GestureDetector(
                    onTap: () => setState(() {
                      final next = {...selected};
                      isSelected
                          ? next.remove(index)
                          : next.add(index);
                      _selected = next;
                    }),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.envTintAt(index),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? c.accent
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(item.emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          str.presetNames[item.key] ?? item.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? c.accent : c.text,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Прогресс-точки: активна фаза выбора конвертов.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _Dots(
                count: str.onbStory.length + 3,
                index: str.onbStory.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 20),
              child: Container(
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
                    disabledBackgroundColor:
                        c.accent.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _saving || selected.isEmpty
                      ? null
                      : () => _finish(create: true),
                  child: Text(tpl(str.createEnvelopesTpl,
                      {'n': '${selected.length}'})),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Прогресс-точки онбординга: активная — широкая «пилюля» в accent,
/// остальные — маленькие точки в цвете трека.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index ? c.accent : c.track,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (i != count - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

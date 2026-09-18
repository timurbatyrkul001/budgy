import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency_catalog.dart';
import '../../core/ex_style.dart';
import '../../core/fx.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../settings/app_settings.dart';
import 'converter_logic.dart';

/// "Güncellendi: X önce" metni (çevirici + seçici).
String ratesUpdatedLabel(RS rs, DateTime fetchedAt, DateTime now) {
  final ago = updatedAgo(fetchedAt, now);
  final when = switch (ago.unit) {
    'now' => rs.justNow,
    'minutes' => tpl(rs.minutesAgoTpl, {'n': '${ago.n}'}),
    'hours' => tpl(rs.hoursAgoTpl, {'n': '${ago.n}'}),
    _ => tpl(rs.daysAgoTpl, {'n': '${ago.n}'}),
  };
  return tpl(rs.ratesUpdatedTpl, {'when': when});
}

/// Tam ekran para birimi seçici: arama, "Önerilen" (ana para, cüzdanlar,
/// son kullanılanlar), A-Z bölümleri + sağda harf şeridi. Seçilen kodu
/// döndürür. [exclude]: başka satırların paraları.
Future<String?> showCurrencyPickerScreen(BuildContext context,
        {required Set<String> exclude, String? selected}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CurrencyPickerScreen(exclude: exclude, selected: selected),
    ));

class CurrencyPickerScreen extends ConsumerStatefulWidget {
  const CurrencyPickerScreen({
    super.key,
    this.exclude = const {},
    this.selected,
    this.initialScroll = 0,
  });

  final Set<String> exclude;
  final String? selected;

  /// Önizleme: açılışta kaydırılmış konum.
  final double initialScroll;

  @override
  ConsumerState<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends ConsumerState<CurrencyPickerScreen> {
  static const _rowH = 54.0;
  static const _headerH = 34.0;

  late final _scroll = ScrollController(initialScrollOffset: widget.initialScroll);
  String _query = '';

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Bölüm başlangıç ofsetleri (satırlar sabit yükseklikte → kesin atlama).
  Map<String, double> _offsets(List<PickerSection> sections) {
    final m = <String, double>{};
    var y = 0.0;
    for (final s in sections) {
      m[s.label] = y;
      y += _headerH + s.codes.length * _rowH;
    }
    return m;
  }

  void _jump(String letter, Map<String, double> offsets) {
    final y = offsets[letter];
    if (y == null || !_scroll.hasClients) return;
    _scroll.jumpTo(y.clamp(0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final main = ref.watch(currencyCodeProvider);
    final wallets = ref.watch(accountEnvelopesProvider).map((e) => e.currency);
    final recent = ref.watch(recentCurrenciesProvider);
    final snap = ref.watch(fxSnapshotProvider(main)).value;
    final sections = pickerSections(
      query: _query,
      exclude: widget.exclude,
      suggested: [main, ...wallets, ...recent],
    );
    final offsets = _offsets(sections);
    final letters = [
      for (final s in sections)
        if (s.label != 'suggested') s.label,
    ];

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GlassSquareButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(rs.selectCurrency,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Ex.text),
                decoration: InputDecoration(
                  hintText: rs.searchCurrency,
                  prefixIcon: const Icon(Icons.search_rounded, color: Ex.textMuted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  snap == null
                      ? rs.ratesOffline
                      : ratesUpdatedLabel(rs, snap.fetchedAt, DateTime.now()),
                  style: const TextStyle(fontSize: 12, color: Ex.textFaint),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 34, 24),
                    itemCount: sections.fold<int>(0, (n, s) => n + 1 + s.codes.length),
                    itemBuilder: (context, i) {
                      var idx = i;
                      for (final s in sections) {
                        if (idx == 0) {
                          return SizedBox(
                            height: _headerH,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6, left: 4),
                                child: Text(
                                  s.label == 'suggested' ? rs.suggested : s.label,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Ex.textMuted),
                                ),
                              ),
                            ),
                          );
                        }
                        idx--;
                        if (idx < s.codes.length) {
                          final code = s.codes[idx];
                          return SizedBox(
                            height: _rowH,
                            child: _CurrencyRow(
                              code: code,
                              selected: code == widget.selected,
                              onTap: () => Navigator.of(context).pop(code),
                            ),
                          );
                        }
                        idx -= s.codes.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  // A-Z şeridi: harfe dokun/kaydır → bölüme atla.
                  if (letters.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: _IndexStrip(
                        letters: letters,
                        onLetter: (l) => _jump(l, offsets),
                      ),
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

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ExCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        child: Row(
          children: [
            Text(flagFor(code), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              child: Text(code,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? Ex.mint : Ex.textMuted)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(catalogCurrencyName(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? Ex.mint : Ex.text)),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18, color: Ex.mint),
          ],
        ),
      ),
    );
  }
}

class _IndexStrip extends StatelessWidget {
  const _IndexStrip({required this.letters, required this.onLetter});

  final List<String> letters;
  final ValueChanged<String> onLetter;

  void _hit(Offset local, double height) {
    if (letters.isEmpty) return;
    final i = (local.dy / height * letters.length).floor().clamp(0, letters.length - 1);
    onLetter(letters[i]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _hit(d.localPosition, box.maxHeight),
        onVerticalDragUpdate: (d) => _hit(d.localPosition, box.maxHeight),
        child: SizedBox(
          width: 22,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final l in letters)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Ex.mint)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

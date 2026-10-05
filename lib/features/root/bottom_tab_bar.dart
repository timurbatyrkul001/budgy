import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/motion.dart';
import '../../core/redesign_l10n.dart';
import '../pro/pro_gate.dart';
import '../pro/pro_state.dart';
import '../transactions/ai_add_sheet.dart';
import '../transactions/quick_entry_screen.dart';
import '../transactions/receipt_scan.dart';

/// Kök ekranın sekmeleri. Sıra [IndexedStack] indeksiyle aynı.
enum RootTab { home, journal, calendar }

/// Çubuğun güvenli alan ÜSTÜNDE kapladığı yükseklik (kapsül 64 + alt pay
/// 12 + nefes payı). Sekmeli ekranlar listelerinin altına
/// `kBottomTabBarInset + MediaQuery.paddingOf(context).bottom` bırakır;
/// yoksa son satır kapsülün arkasında kalır.
const kBottomTabBarInset = 96.0;

/// "+" düğmesinin anahtarı: ana ekranda başka `Icons.add_rounded` da var
/// (hesap ekle kartı), testler ikonla değil anahtarla bulsun.
const kBottomTabAddKey = ValueKey('bottom-tab-add');

/// Kapsülün ve "+" dairesinin ortak gölgesi. Kâğıt üstünde gölge mürekkebin
/// soluk hâli: tam siyah, yüzdürmek yerine eziyordu.
const _barShadow = [
  BoxShadow(color: Color(0x1A111111), blurRadius: 24, offset: Offset(0, 8)),
];

/// Alt sekme çubuğu: solda beyaz kapsül içinde üç sekme, sağda kapsülün
/// DIŞINDA siyah "+" dairesi. "+" bir sekme değil, bir eylemdir — bu yüzden
/// kapsülün dışında, mürekkep renginde durur.
///
/// [visible] false olunca çubuk aşağı kayıp solar (okurken yol açar);
/// kararı kök ekran kaydırma bildirimlerinden verir, çubuk yalnız çizer.
class BottomTabBar extends ConsumerWidget {
  const BottomTabBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onAdd,
    this.visible = true,
  });

  final RootTab current;
  final ValueChanged<RootTab> onSelect;
  final VoidCallback onAdd;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Hareket azaltmada süre sıfır: ImplicitlyAnimatedWidget sıfır sürede
    // hedefe anında atlar, ticker askıda kalmaz.
    final d = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return IgnorePointer(
      // Gizliyken dokunuş yutulmasın: çubuk ekranın altına kaydı, altındaki
      // liste satırı dokunulabilir olmalı.
      ignoring: !visible,
      child: AnimatedSlide(
        // 1.5 yükseklik: gölge dâhil ekrandan tamamen çıksın.
        offset: visible ? Offset.zero : const Offset(0, 1.5),
        duration: d,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: d,
          curve: Curves.easeOut,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Ex.surface,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Ex.border),
                      boxShadow: _barShadow,
                    ),
                    child: Stack(
                      children: [
                        // Vurgu TEK ve kayıyor. Her sekmenin kendi yastığı
                        // olsaydı biri sönerken öteki yanardı — göz bunu
                        // "yanıp sönme" olarak okuyor, "geçiş" olarak değil.
                        Positioned.fill(
                          child: AnimatedAlign(
                            alignment: Alignment(_highlightX(current), 0),
                            duration: d,
                            curve: Curves.easeOutCubic,
                            child: FractionallySizedBox(
                              widthFactor: 1 / RootTab.values.length,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Ex.brand.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _TabItem(
                              tab: RootTab.home,
                              icon: Icons.home_rounded,
                              label: rs.tabHome,
                              current: current,
                              onSelect: onSelect,
                              duration: d,
                            ),
                            _TabItem(
                              tab: RootTab.journal,
                              icon: Icons.receipt_long_rounded,
                              label: rs.tabJournal,
                              current: current,
                              onSelect: onSelect,
                              duration: d,
                            ),
                            _TabItem(
                              tab: RootTab.calendar,
                              icon: Icons.calendar_month_rounded,
                              label: rs.tabCalendar,
                              current: current,
                              onSelect: onSelect,
                              duration: d,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: rs.addSheetTitle,
                  // Kapsülle AYNI yüzey: beyaz zemin, aynı kenarlık, aynı
                  // gölge. Siyah daire denendi — kâğıt tasarımda tek siyah
                  // leke gibi duruyordu ve çubuktan kopuyordu. Artık ikisi
                  // aynı kâğıdın iki parçası, "+" yalnız biçimiyle ayrılıyor.
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _barShadow,
                    ),
                    child: PressScale(
                      color: Ex.surface,
                      shape: const CircleBorder(
                        side: BorderSide(color: Ex.border),
                      ),
                      onTap: onAdd,
                      // Anahtar iç kutuda: PressScale'in ölçek dönüşümü hit
                      // test yoluna girmiyor, testlerin tap'i dıştaki anahtarı
                      // "vurulmadı" sayıyordu.
                      child: const SizedBox(
                        key: kBottomTabAddKey,
                        width: 56,
                        height: 56,
                        child: Icon(
                          Icons.add_rounded,
                          size: 30,
                          color: Ex.text,
                        ),
                      ),
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
}

/// Kayan vurgunun yatay hizası: ilk sekme -1, son sekme +1, aradakiler
/// eşit aralıklı. [Alignment] bu aralığı kendi genişliğine göre çözdüğü
/// için sekme sayısı değişirse de doğru kalır.
double _highlightX(RootTab tab) {
  final last = RootTab.values.length - 1;
  return last == 0 ? 0 : (tab.index / last) * 2 - 1;
}

/// Tek sekme: üstte ikon, altta 11px etiket. Yastık burada DEĞİL — kapsülün
/// altında kayan tek vurgu var; sekme yalnız ikon ve etiketi çiziyor.
///
/// Renk anında değişmiyor: vurgu kayarken ikon ve etiket de mürekkepten
/// yeşile geçiyor. İkisi aynı sürede olunca hareket tek parça okunuyor.
///
/// Etiket [FittedBox] ile küçülür — 320dp'de üç sekme + "+" için kalan
/// genişlik dar, "Календарь" gibi uzun etiketler kesilmesin.
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.current,
    required this.onSelect,
    required this.duration,
  });

  final RootTab tab;
  final IconData icon;
  final String label;
  final RootTab current;
  final ValueChanged<RootTab> onSelect;

  /// Kayan vurguyla AYNI süre; kök widget'tan geliyor.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final active = tab == current;
    final color = active ? Ex.brand : Ex.textMuted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(tab),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: duration,
                    curve: Curves.easeOut,
                    builder: (context, value, _) =>
                        Icon(icon, size: 24, color: value ?? color),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: color,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── "+" seçim sayfası ─────────────────────────────────────────────────────

/// "+" → "Ne yapmak istiyorsun?" sayfası: 2×2 kart. Elle gider / elle gelir
/// / fiş tara (Pro) / sesle ekle (Pro).
///
/// 1.0'da AI kapalı ([kAiEnabled] false, bkz. pro_state.dart): ikinci sıra
/// hiç çizilmez, sayfa tek sıra iki kart olarak kalır; [_AddChoice.scan] ve
/// [_AddChoice.voice] dallarına ulaşan yol yok. Dallar 1.1 için duruyor.
///
/// Elle girişten kayıt dönerse [onSaved] son işlemin kimliğiyle çağrılır;
/// kök ekran "Kaydedildi · Geri al" çipini bununla gösterir.
///
/// Sayfa önce KAPANIR, eylem sonra başlar: hızlı giriş tam ekran bir rota,
/// sayfanın üstüne açılıp dönünce sayfa hâlâ orada dursa iki kez kapatmak
/// gerekirdi. [context] ve [ref] bu yüzden çağıranın (kök ekranın) olmalı,
/// sayfanınki değil — sayfa kapanınca onunki ölür.
Future<void> showAddSheet(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<String> onSaved,
}) async {
  final rs = ref.read(rsProvider);
  final choice = await showExSheet<_AddChoice>(
    context,
    SheetFrame(title: rs.addSheetTitle, child: const _AddGrid()),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _AddChoice.expense:
      final result = await showQuickEntry(context);
      if (result != null) onSaved(result.lastTxId);
    case _AddChoice.income:
      // Hızlı giriş ekranı "başlangıç türü" parametresi sunmuyor; gelir
      // moduna geçişi yalnız `autoSheet: 'incomeCategory'` yapıyor (gelir
      // modu + kaynak kategorisi seçici). Gelir girişinde ilk adım zaten
      // kaynağı seçmek olduğu için akış doğal duruyor; ekran bir
      // `initialMode` kazanınca burası ona geçmeli.
      final result = await showQuickEntry(context, autoSheet: 'incomeCategory');
      if (result != null) onSaved(result.lastTxId);
    case _AddChoice.scan:
      // Fiş tarama ve sesli giriş Pro: kartlar herkese görünür (gizlenen
      // özellik satılamaz), Pro değilse rozet taşır ve basınca paywall
      // açılır. AI çağrısı Pro olmadan hiç yapılmaz.
      // kProEnabled kapalıyken (1.0) requirePro herkes için geçer; bkz.
      // pro_state.dart.
      if (!await requirePro(context, ref, ProFeature.aiEntry)) return;
      if (context.mounted) await startReceiptScan(context, ref);
    case _AddChoice.voice:
      if (!await requirePro(context, ref, ProFeature.aiEntry)) return;
      if (context.mounted) await showAiAdd(context);
  }
}

enum _AddChoice { expense, income, scan, voice }

class _AddGrid extends ConsumerWidget {
  const _AddGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _AddCard(
                icon: Icons.remove_circle_outline_rounded,
                label: rs.addExpenseManual,
                onTap: () => Navigator.of(context).pop(_AddChoice.expense),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AddCard(
                icon: Icons.add_circle_outline_rounded,
                label: rs.addIncomeManual,
                onTap: () => Navigator.of(context).pop(_AddChoice.income),
              ),
            ),
          ],
        ),
        // 1.0: AI kapalı — fiş tara / sesle ekle sırası hiç çizilmez; iki
        // kartlık tek sıra tasarımın kendisi gibi durur, delikli ızgara
        // değil. Bkz. pro_state.dart, kAiEnabled.
        if (kAiEnabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AddCard(
                  icon: Icons.document_scanner_outlined,
                  label: rs.addScanReceipt,
                  onTap: () => Navigator.of(context).pop(_AddChoice.scan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AddCard(
                  icon: Icons.mic_rounded,
                  label: rs.addByVoice,
                  onTap: () => Navigator.of(context).pop(_AddChoice.voice),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Seçim kartı: ikon üstte, iki satır etiket altta.
///
/// Pro rozeti bilinçli olarak YOK: dört kart aynı görünüyor, kilidi olan
/// ikisine basınca paywall açılıyor. Rozet listeyi kalabalıklaştırıyordu.
/// (1.0'da yalnız iki kart var — kAiEnabled; görünüm aynı.)
class _AddCard extends StatelessWidget {
  const _AddCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.surfaceHi,
      borderRadius: BorderRadius.circular(Ex.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Ex.surface,
                  borderRadius: Ex.squircle(44),
                  border: Border.all(color: Ex.border),
                ),
                child: Icon(icon, size: 22, color: Ex.text),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Ex.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "Kaydedildi · Geri al" çipi ───────────────────────────────────────────

/// Hızlı girişten dönüşte çubuğun hemen üstünde yüzen çip. Ana ekrandan
/// buraya taşındı: tetikleyen "+" artık kök ekranda, çip de konumunu
/// çubuğa göre alıyor.
class SavedUndoChip extends StatelessWidget {
  const SavedUndoChip({
    super.key,
    required this.saved,
    required this.undo,
    required this.onUndo,
  });

  final String saved;
  final String undo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 12,
      // Tam siyah gölge açık zeminde çipi ağırlaştırıyor; mürekkebin düşük
      // alfalı hâli kâğıttan yumuşakça kaldırır.
      shadowColor: Ex.text.withValues(alpha: 0.35),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Ex.borderHi),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Ex.income),
            const SizedBox(width: 8),
            Text(
              saved,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Ex.text,
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(
                foregroundColor: Ex.mint,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                undo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

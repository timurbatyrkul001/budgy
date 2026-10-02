import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pro/paywall_sheet.dart';
import '../pro/pro_state.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/motion.dart';
import '../../core/preview.dart';
import '../../core/redesign_l10n.dart';
import '../../core/widget_service.dart';
import '../envelopes/budget_repository.dart';
import '../budget/budget_period.dart';
import '../budget/budget_screen.dart';
import '../automation/automation_screen.dart';
import '../recurring/recurring_screen.dart';
import '../categories/categories_screen.dart';
import '../../core/l10n.dart';
import '../transactions/journal_screen.dart';
import '../home/preview_home.dart';
import '../envelopes/add_envelope_sheet.dart';
import '../converter/converter_screen.dart';
import '../converter/currency_picker_screen.dart';
import '../envelopes/home_screen.dart';
import '../settings/data_management_screen.dart';
import '../settings/settings_hub.dart';
import '../space/space.dart';
import '../stats/stats_screen.dart';
import '../transactions/quick_entry_screen.dart';
import '../workdays/calendar_screen.dart';
import 'bottom_tab_bar.dart';

/// Kök ekran: üç sekme (Ana sayfa / Harcamalar / Takvim) + sağ altta "+".
/// Sekmeler [IndexedStack]'te yaşar: geçişte kaydırma konumu ve yüklenmiş
/// veri korunur. Çubuk aşağı kaydırınca gizlenir, yukarı kaydırınca döner;
/// kaydırma bildirimleri burada dinlenir ki hangi sekme kaydırırsa
/// kaydırsın tek bir karar yeri olsun.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  RootTab _tab = RootTab.home;

  /// Çubuk görünür mü (kaydırma yönüne göre).
  bool _barVisible = true;

  /// Kullanıcının son kaydırma yönü. [UserScrollNotification] yalnız yön
  /// DEĞİŞİNCE gelir; parmak en üstten tek hamlede aşağı inerken "reverse"
  /// pixels=0'da gelir ve bir daha gelmez. Yönü saklayıp her
  /// [ScrollUpdateNotification]'da yeniden değerlendiriyoruz, yoksa o
  /// hamlede çubuk hiç gizlenmezdi.
  ScrollDirection _direction = ScrollDirection.idle;

  /// Son kaydedilen işlem — "Kaydedildi · Geri al" çipi 4 sn görünür.
  String? _undoTxId;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    if (kPreviewHomeToast) _undoTxId = 'preview';
    // Debug önizlemesi: "+" ekranını (ve istenen alt sayfayı) otomatik aç.
    if (kPreviewQuickEntry) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showQuickEntry(
          context,
          initialExpression: kPreviewQuickEntryAmount,
          autoSheet: kPreviewQuickEntrySheet.isEmpty
              ? null
              : kPreviewQuickEntrySheet,
        ),
      );
    }
    // PREVIEW_PAYWALL: açılışta paywall'ı aç. Bayrak preview.dart'ta tanımlı
    // ve belgeliydi ama hiçbir yerde tüketilmiyordu — yani hiçbir şey yapmıyordu.
    if (kPreviewPaywall) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => showPaywall(context, ProFeature.analytics),
      );
    }
    // PREVIEW_TX: örnek kaynaklı gelirin detay sayfası ya da düzenleme ekranı.
    if (kPreviewTx.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tx = previewIncomeTx();
        if (kPreviewTx == 'edit') {
          showQuickEntryEdit(context, tx);
        } else {
          TxTile.showActionsFor(context, ref, tx, ref.read(strProvider));
        }
      });
    }
    final preview = switch (kPreviewBudget) {
      'empty' => const BudgetScreen(),
      'amount' => const BudgetAmountStep(initialPeriod: BudgetPeriod.weekly),
      'amountMonthly' => const BudgetAmountStep(
        initialPeriod: BudgetPeriod.monthly,
      ),
      'categories' => const BudgetCategoriesStep(
        settings: BudgetSettings(amount: 15000, period: BudgetPeriod.monthly),
        autoSuggest: true,
      ),
      _ => switch (kPreviewConverter) {
        'two' => const CurrencyConverterScreen(
          initialRows: ['USD', 'TRY'],
          initialExpression: '100',
        ),
        'four' => const CurrencyConverterScreen(
          initialRows: ['USD', 'TRY', 'EUR', 'KZT'],
          initialExpression: '250',
        ),
        'picker' => const CurrencyPickerScreen(exclude: {'TRY'}),
        'pickerScrolled' => const CurrencyPickerScreen(
          exclude: {'TRY'},
          initialScroll: 1500,
        ),
        _ => switch (kPreviewSettings) {
          'hub' => const SettingsHubScreen(),
          'hubScrolled' => const SettingsHubScreen(initialScroll: 620),
          'categories' => const CategoriesScreen(),
          'automation' => const AutomationScreen(),
          'recurring' => const RecurringScreen(),
          'automationCat' => const RuleKeywordsScreen(
            title: 'Groceries',
            catalogKey: 'groceries',
          ),
          'calendar' => const CalendarScreen(),
          'data' => const DataManagementScreen(),
          'newCategory' => const EnvelopeEditorScreen(sortOrder: 0),
          'newCategoryFilled' => const EnvelopeEditorScreen(
            sortOrder: 0,
            previewName: 'Kahvaltı',
            previewEmoji: '🥐',
            previewColorIndex: 1,
            previewSection: 'everyday',
          ),
          'sectionPicker' => const EnvelopeEditorScreen(
            sortOrder: 0,
            previewName: 'Kahvaltı',
            autoOpenSection: true,
          ),
          _ =>
            kPreviewAnalytics
                ? StatsScreen(initialMonthOffset: kPreviewAnalyticsOffset)
                : null,
        },
      },
    };
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => preview)),
      );
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  // ── sekme + çubuk ──────────────────────────────────────────────────────

  void _selectTab(RootTab tab) {
    if (tab == _tab && _barVisible) return;
    // Sekme değişince çubuk her zaman görünür: yeni sekmenin kaydırma
    // geçmişi eskisininkiyle ilgisiz.
    setState(() {
      _tab = tab;
      _barVisible = true;
    });
  }

  void _setBar(bool visible) {
    if (_barVisible == visible) return;
    setState(() => _barVisible = visible);
  }

  /// Yön + konumdan görünürlük kararı. Dikey olmayan kaydırmalar (ana
  /// ekranın yatay hesap listesi) sayılmaz.
  void _evaluate(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    // En üstteyken her zaman görünür — hangi yönde olursa olsun.
    if (metrics.pixels <= 0) {
      _setBar(true);
      return;
    }
    switch (_direction) {
      case ScrollDirection.reverse:
        // İçerik yukarı kayıyor = kullanıcı okumaya devam ediyor → yol aç.
        _setBar(false);
      case ScrollDirection.forward:
        _setBar(true);
      case ScrollDirection.idle:
        // Durağan: mevcut hâl kalır.
        break;
    }
  }

  bool _onUserScroll(UserScrollNotification n) {
    // Yatay listenin yönü saklanmasın: sonraki dikey güncellemeler yanlış
    // yönle değerlendirilirdi.
    if (n.metrics.axis != Axis.vertical) return false;
    _direction = n.direction;
    _evaluate(n.metrics);
    return false;
  }

  bool _onScrollUpdate(ScrollUpdateNotification n) {
    _evaluate(n.metrics);
    return false;
  }

  // ── kaydedildi · geri al ───────────────────────────────────────────────

  void _showUndo(String txId) {
    _undoTimer?.cancel();
    setState(() => _undoTxId = txId);
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _undoTxId = null);
    });
  }

  Future<void> _undo() async {
    final id = _undoTxId;
    _undoTimer?.cancel();
    setState(() => _undoTxId = null);
    if (id == null || id == 'preview') return;
    // deleteTx bakiyeyi de geri alır.
    await guardWrite(
      context,
      ref.read(strProvider),
      () => ref.read(budgetRepositoryProvider).deleteTx(id),
      reason: 'undoQuickEntry',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ana ekran widget'ını güncel tut (App Group yoksa güvenle no-op).
    ref.watch(widgetSyncProvider);
    // Vadesi gelen tekrarlayan işlemleri açılışta işle (yetişme).
    // Tekrarlayan işlemler Pro: abonelik yokken (ya da bittiğinde) kurallar
    // sessizce durur, işlem üretmez. Hak sahipliği akışı geç gelirse
    // isProProvider değişir, bu build yeniden çalışır ve yetişme o an olur.
    // kProEnabled kapalıyken (1.0) proUnlockedProvider herkes için true:
    // kurallar herkeste üretilir — yoksa tekrarlar sessizce dururdu.
    if (ref.watch(proUnlockedProvider)) {
      ref.watch(recurringMaterializerProvider);
    }
    // Eski varsayılan cüzdan adını ("Cüzdanım") yeni varsayılana taşı.
    ref.watch(spaceNameMigrationProvider);

    final rs = ref.watch(rsProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ex.bg,
      body: Stack(
        children: [
          // İki dinleyici: yön değişimi (UserScroll) ve her kaydırma adımı
          // (ScrollUpdate, "en üstte mi" kontrolü için). İkisi de bildirimi
          // yutmaz (false) — ekranların kendi dinleyicileri varsa çalışsın.
          NotificationListener<ScrollUpdateNotification>(
            onNotification: _onScrollUpdate,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: IndexedStack(
                index: _tab.index,
                children: const [
                  HomeScreen(),
                  JournalScreen(embedded: true),
                  CalendarScreen(embedded: true),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomTabBar(
              current: _tab,
              visible: _barVisible,
              onSelect: _selectTab,
              onAdd: () => showAddSheet(context, ref, onSaved: _showUndo),
            ),
          ),
          // Kaydedildi · Geri al — çubuğun hemen üstünde yüzen çip.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + kBottomTabBarInset,
            child: IgnorePointer(
              ignoring: _undoTxId == null,
              child: Center(
                child: SavedUndoChip(
                  saved: rs.saved,
                  undo: rs.undo,
                  onUndo: _undo,
                ),
              ).reveal(context, visible: _undoTxId != null),
            ),
          ),
        ],
      ),
    );
  }
}

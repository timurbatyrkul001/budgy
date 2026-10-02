import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/category_avatar.dart';
import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../../core/tokens.dart';
import '../accounts/account.dart';
import '../accounts/accounts_repository.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../root/bottom_tab_bar.dart';
import '../workdays/work_days_repository.dart';
import 'journal_filter.dart';
import 'quick_entry_screen.dart';
import 'tx.dart';
import '../../core/feedback.dart';

/// History of Spending — Cashly: tür sekmeleri + arama + sırala/filtre +
/// tarihli liste.
///
/// [embedded] true: kök ekranın "Harcamalar" sekmesinde yaşıyor — geri
/// düğmesi yok, listenin altında yüzen sekme çubuğu payı var. Varsayılan
/// false ki başka yerlerden (hesaplar, ana ekran kartları) push edilen
/// mevcut çağrılar olduğu gibi çalışsın.
///
/// [now]: dönem filtresinin "bugün"ü. Yalnız test için — "Bu ay" ile
/// "30 gün" farkı ancak sabit bir tarihle deterministik sınanabiliyor.
/// Üretimde null bırakılır, `DateTime.now()` kullanılır.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, this.embedded = false, this.now});

  final bool embedded;
  final DateTime? now;

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  TxType _mode = TxType.expense;
  final _search = TextEditingController();
  JournalSort _sort = JournalSort.def;
  JournalFilter _filter = JournalFilter.none;

  /// Filtre düğmesi vurgulu mu: filtre VEYA varsayılan dışı sıralama.
  /// Yalnız filtreye baksaydı kullanıcı listenin neden "tuhaf" sırada
  /// olduğunu anlayamazdı.
  bool get _queryActive => _filter.isActive || !_sort.isDefault;

  /// Tür sekmesine göre ham liste (çevrim ve hedef fonu hariç) — hem ekran
  /// hem de "Hesapsız" çipinin var olup olmayacağı buradan türer.
  List<Tx> _baseList(List<Tx> all, List<WorkDay> workDays, Strings str) {
    // Gelir sekmesinde Takvim maaş günlerini de göster (salt-okunur, id 'wd_').
    final workTxs = _mode == TxType.income
        ? [
            for (final w in workDays)
              Tx(
                id: 'wd_${w.id}',
                type: TxType.income,
                amount: w.amount!,
                date: w.date,
                note: str.workEarning,
              ),
          ]
        : const <Tx>[];
    return [
      for (final t in [...all, ...workTxs])
        if (t.type == _mode && !t.isConvert && !t.isGoalFund) t,
    ];
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final all = ref.watch(journalFullProvider).value ?? [];
    final workDays = ref.watch(allWorkDaysProvider).value ?? const <WorkDay>[];
    final mainCurrency = ref.watch(currencyProvider).value ?? 'TRY';
    // Hesaplar burada WATCH edilir, alt sayfa açılırken read değil: Riverpod 3
    // dinleyicisi olmayan akışı askıya alır, `read` hep "yükleniyor" görürdü.
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final q = _search.text.trim().toLowerCase();

    final filtered =
        applyJournalFilter(
          _baseList(all, workDays, str),
          _filter,
          now: widget.now ?? DateTime.now(),
        ).where((t) {
          if (q.isEmpty) return true;
          final hay = '${t.note ?? ''} ${t.envelopeName ?? ''}'.toLowerCase();
          return hay.contains(q);
        });
    final list = sortJournal(filtered, _sort, mainCurrency: mainCurrency);

    final embedded = widget.embedded;
    // Sekmedeyken liste yüzen çubuğun altından geçer: alt güvenli alanı
    // ekranın kendisi değil, listenin alt payı karşılar.
    final bottomInset = embedded
        ? kBottomTabBarInset + MediaQuery.paddingOf(context).bottom
        : 0.0;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: !embedded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Push edildiğinde geri; sekmedeyken gidilecek "geri" yok.
                  if (!embedded) const BudgyBackButton(),
                  Text(
                    str.historyTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    str.reportSubtitle,
                    style: TextStyle(fontSize: 14, color: c.textMuted),
                  ),
                  const SizedBox(height: 20),
                  _HistoryTabs(
                    mode: _mode,
                    str: str,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: InputDecoration(
                            hintText: str.searchHistory,
                            prefixIcon: Icon(Icons.search, color: c.textMuted),
                            filled: true,
                            fillColor: c.surface,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _openFilter(accounts),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _queryActive ? c.accent : c.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: _queryActive ? Ex.onBrand : c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        str.noOperations,
                        style: TextStyle(color: c.textFaint),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
                      children: _grouped(list, str),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarihe göre başlık + her işlem yüzey kartı.
  ///
  /// Başlıklar YALNIZ tarihe göre sıralamada çıkar. Tutara veya kategoriye
  /// göre sıralanınca liste tarih sırasında değil: "her gün değişince
  /// başlık" kuralı o sırada neredeyse her satırın üstüne bir başlık koyar
  /// ve aynı tarih birkaç kez tekrar eder — doğru ama okunaksız. O iki
  /// sıralamada tarih, kartın içinde küçük bir satır olarak duruyor.
  List<Widget> _grouped(List<Tx> list, Strings str) {
    final c = context.budgy;
    final byDate = _sort.key == JournalSortKey.date;
    final items = <Widget>[];
    DateTime? day;
    for (final tx in list) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (byDate && d != day) {
        day = d;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              DateFormat('dd MMM yyyy', str.localeCode).format(tx.date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
        );
      }
      items.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: byDate
              ? TxTile(tx: tx, str: str)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy',
                          str.localeCode,
                        ).format(tx.date),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                    TxTile(tx: tx, str: str),
                  ],
                ),
        ),
      );
    }
    return items;
  }

  /// Sırala & Filtrele alt sayfası. Proje standardı `showExSheet` +
  /// `SheetFrame` (tutamak, başlık, kapat, klavye payı hazır) — eski el
  /// yapımı `showModalBottomSheet` iskeleti gitti. Sağlayıcılar BURADA
  /// okunup sayfaya düz veri olarak verilir: modal rota, ekranın
  /// ProviderScope'unun dışında kurulabilir.
  Future<void> _openFilter(List<Account> accounts) async {
    final str = ref.read(strProvider);
    final rs = ref.read(rsProvider);
    final envelopes = ref.read(envelopesProvider).value ?? [];
    final cats = {for (final e in envelopes) e.displayName(str)}.toList();
    final base = _baseList(
      ref.read(journalFullProvider).value ?? [],
      ref.read(allWorkDaysProvider).value ?? const [],
      str,
    );
    // "Hesapsız" çipi yalnız bu sekmede gerçekten hesapsız kayıt varsa —
    // yoksa boş çip anlamsız. Diğer filtrelerden ÖNCEki listeye bakılır ki
    // dönem/kategori daraltınca çip kaybolup geri gelmesin.
    final hasNoAccount = base.any((t) => t.accountId == null);

    final result = await showExSheet<JournalQuery>(
      context,
      JournalSortFilterSheet(
        str: str,
        initial: JournalQuery(sort: _sort, filter: _filter),
        categories: cats,
        showAccounts: showAccountSection(accounts),
        accountChips: buildAccountChips(
          accounts: accounts,
          hasNoAccountTxs: hasNoAccount,
          str: str,
          cashLabel: rs.cash,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _sort = result.sort;
      _filter = result.filter;
    });
  }
}

/// Tür sekmeleri (Expense / Income / Transfer).
class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs({
    required this.mode,
    required this.str,
    required this.onChanged,
  });

  final TxType mode;
  final Strings str;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final items = [
      (TxType.expense, str.expenseTitle),
      (TxType.income, str.incomeTitle),
      (TxType.transfer, str.transferTitle),
    ];
    // Segmentler kalan genişliği eşit paylaşır — sabit genişlikte bırakılınca
    // dar ekranlarda (320dp) satır taşıyor ve "Transfer" görünmez oluyordu.
    return Row(
      children: [
        for (final (index, (m, label)) in items.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: m == mode ? c.accent : c.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: m == mode ? FontWeight.w700 : FontWeight.w500,
                    color: m == mode ? Ex.onBrand : c.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TxList extends ConsumerWidget {
  const TxList({super.key, required this.txs, this.shrinkWrap = false});

  final List<Tx> txs;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final items = <Widget>[];
    DateTime? currentDay;
    for (final tx in txs) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (day != currentDay) {
        currentDay = day;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Text(
              formatDay(tx.date, str),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.textMuted,
              ),
            ),
          ),
        );
      }
      items.add(TxTile(tx: tx, str: str));
    }
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: items,
    );
  }
}

class TxTile extends ConsumerWidget {
  const TxTile({super.key, required this.tx, required this.str});

  final Tx tx;
  final Strings str;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.budgy.surface,
        title: Text(str.deleteTxTitle),
        content: Text(str.deleteTxBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(str.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Ex.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(str.deleteWord),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guardWrite(
        context,
        str,
        () => ref.read(budgetRepositoryProvider).deleteTx(tx.id),
      );
    }
  }

  /// Gelir, bir gelir KAYNAĞI (₺ kategori zarfı) ile etiketli mi? Döviz
  /// cüzdanına gelen para değil — orada envelopeId cüzdanın kendisidir.
  static bool _incomeHasSource(Tx tx, Map<String, Envelope> envById) =>
      tx.type == TxType.income &&
      tx.currency == 'TRY' &&
      envById[tx.envelopeId]?.currency == 'TRY';

  static String _titleOf(Tx tx, Strings str, bool hasSource) =>
      switch (tx.type) {
        TxType.income =>
          tx.note ?? (hasSource ? tx.envelopeName : null) ?? str.incomeWord,
        TxType.expense => tx.note ?? tx.envelopeName ?? str.expenseWord,
        TxType.transfer => '${tx.fromName} → ${tx.envelopeName}',
      };

  /// Düzenlenebilir mi: çevrim bacağı, hedef fonu, transfer ve takvim
  /// maaş günleri (wd_) hayır.
  bool get _editable =>
      !tx.isConvert &&
      !tx.isGoalFund &&
      tx.type != TxType.transfer &&
      !tx.id.startsWith('wd_');

  /// Önizleme/harici çağrı: işlem sayfasını aç.
  static void showActionsFor(
    BuildContext context,
    WidgetRef ref,
    Tx tx,
    Strings str,
  ) => TxTile(tx: tx, str: str)._showActions(context, ref);

  /// İşleme dokununca: detay + Düzenle + Sil.
  void _showActions(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final rs = ref.read(rsProvider);
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.type == TxType.transfer;
    final envById = {
      for (final e in ref.read(envelopesProvider).value ?? const <Envelope>[])
        e.id: e,
    };
    final title = _titleOf(tx, str, _incomeHasSource(tx, envById));
    final sign = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '−';
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.track,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'd MMMM yyyy',
                            str.localeCode,
                          ).format(tx.date),
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tutar: afiş tipografisi; gelir yeşil, gider mürekkep.
                  Text(
                    '$sign${formatMoneyIn(tx.amount, tx.currency)}',
                    style: TextStyle(
                      fontFamily: 'InterDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isIncome ? Ex.income : Ex.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_editable) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Ex.onBrand,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      if (!context.mounted) return;
                      showQuickEntryEdit(context, tx);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(rs.edit),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    // Material kırmızısı krem kâğıtta çiğ duruyordu; paletin
                    // kırmızısı hem tint hem metin için.
                    backgroundColor: Ex.red.withValues(alpha: 0.12),
                    foregroundColor: Ex.red,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    if (!context.mounted) return;
                    await guardWrite(
                      context,
                      str,
                      () => ref.read(budgetRepositoryProvider).deleteTx(tx.id),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(str.deleteWord),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.type == TxType.transfer;
    final envById = {
      for (final e in ref.watch(envelopesProvider).value ?? const <Envelope>[])
        e.id: e,
    };
    final hasSource = _incomeHasSource(tx, envById);
    // Üst satır (isim) + alt satır (kategori / kaynak) — Cashly stili.
    final title = _titleOf(tx, str, hasSource);
    // Döviz çevirme → "Döviz" etiketi (Income/Expense değil).
    final subtitle = tx.isConvert
        ? str.convertTitle
        : switch (tx.type) {
            TxType.income =>
              tx.note != null && hasSource ? tx.envelopeName! : str.incomeWord,
            TxType.expense =>
              tx.note != null
                  ? (tx.envelopeName ?? str.expenseWord)
                  : str.expenseWord,
            TxType.transfer => str.transferTitle,
          };

    final accentColor = tx.isConvert
        ? c.accent
        : isIncome
        ? c.accent
        : isTransfer
        ? c.accent
        : c.text;

    // Takvim maaş günleri (id 'wd_') salt-okunur: silinmez/düzenlenmez.
    final readOnly = tx.id.startsWith('wd_');
    return InkWell(
      onTap: readOnly ? null : () => _showActions(context, ref),
      onLongPress: readOnly ? null : () => _confirmDelete(context, ref),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Gider: kategori görseli (kategorisizse soru işareti); kaynaklı
            // gelir: kaynağın görseli; diğer gelir / çevirme / transfer: yön.
            if (tx.type == TxType.expense && !tx.isConvert)
              switch (tx.envelopeId) {
                final id? when envById[id] != null => CategoryAvatar(
                  envelope: envById[id],
                  size: 44,
                ),
                _ => const CategoryAvatar.none(size: 44),
              }
            else if (hasSource)
              CategoryAvatar(envelope: envById[tx.envelopeId], size: 44)
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isIncome ? c.envMarket : c.envFatura,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tx.isConvert || isTransfer
                      ? Icons.swap_horiz_rounded
                      : Icons.south_west_rounded,
                  size: 20,
                  color: accentColor,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isIncome
                  ? '+'
                  : isTransfer
                  ? ''
                  : '−'}${formatMoneyIn(tx.amount, tx.currency)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                // Gelir: semantik gelir yeşili (açık zemin için koyultulmuş);
                // gider nötr mürekkep — listede kırmızı gürültü istemiyoruz.
                color: isIncome ? Ex.income : Ex.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

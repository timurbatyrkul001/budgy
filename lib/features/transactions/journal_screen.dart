import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/category_avatar.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../workdays/work_days_repository.dart';
import 'tx.dart';
import '../../core/feedback.dart';

/// History of Spending — Cashly: tür sekmeleri + arama + filtre + tarihli liste.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  TxType _mode = TxType.expense;
  final _search = TextEditingController();
  Set<String> _filterCats = {};
  DateTime? _filterDate;

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
    final q = _search.text.trim().toLowerCase();

    // Gelir sekmesinde Takvim maaş günlerini de göster (salt-okunur, id 'wd_').
    final workTxs = _mode == TxType.income
        ? [
            for (final w in ref.watch(allWorkDaysProvider).value ?? const [])
              Tx(
                id: 'wd_${w.id}',
                type: TxType.income,
                amount: w.amount!,
                date: w.date,
                note: str.workEarning,
              ),
          ]
        : const <Tx>[];

    final list = [...all, ...workTxs].where((t) {
      if (t.type != _mode || t.isConvert || t.isGoalFund) return false;
      if (_filterCats.isNotEmpty &&
          !_filterCats.contains(t.envelopeName)) {
        return false;
      }
      if (_filterDate != null) {
        final d = _filterDate!;
        if (t.date.year != d.year ||
            t.date.month != d.month ||
            t.date.day != d.day) {
          return false;
        }
      }
      if (q.isNotEmpty) {
        final hay = '${t.note ?? ''} ${t.envelopeName ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str.historyTitle,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(str.reportSubtitle,
                      style: TextStyle(fontSize: 14, color: c.textMuted)),
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
                            prefixIcon: Icon(Icons.search,
                                color: c.textMuted),
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
                        onTap: _openFilter,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (_filterCats.isNotEmpty ||
                                    _filterDate != null)
                                ? c.accent
                                : c.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: (_filterCats.isNotEmpty ||
                                      _filterDate != null)
                                  ? Colors.white
                                  : c.text),
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
                      child: Text(str.noOperations,
                          style: TextStyle(color: c.textFaint)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: _grouped(list, str),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarihe göre başlık + her işlem yüzey kartı.
  List<Widget> _grouped(List<Tx> list, Strings str) {
    final c = context.budgy;
    final items = <Widget>[];
    DateTime? day;
    for (final tx in list) {
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (d != day) {
        day = d;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            DateFormat('dd MMM yyyy', str.localeCode).format(tx.date),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textMuted),
          ),
        ));
      }
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: TxTile(tx: tx, str: str),
      ));
    }
    return items;
  }

  Future<void> _openFilter() async {
    final c = context.budgy;
    final str = ref.read(strProvider);
    final envelopes = ref.read(envelopesProvider).value ?? [];
    final cats = {for (final e in envelopes) e.displayName(str)}.toList();
    var tempCats = {..._filterCats};
    var tempDate = _filterDate;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(str.filterTitle,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: c.text)),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Icon(Icons.close, color: c.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(str.categoriesLabel,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final cat in cats)
                    GestureDetector(
                      onTap: () => setS(() => tempCats.contains(cat)
                          ? tempCats.remove(cat)
                          : tempCats.add(cat)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: tempCats.contains(cat)
                              ? c.accent
                              : c.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: tempCats.contains(cat)
                                  ? c.accent
                                  : c.borderStrong),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                                fontSize: 14,
                                color: tempCats.contains(cat)
                                    ? Colors.white
                                    : c.text)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Date
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showAppDatePicker(
                    context: ctx,
                    initial: tempDate ?? now,
                    first: DateTime(now.year - 3),
                    last: DateTime(now.year + 1),
                    localeCode: str.localeCode,
                  );
                  if (picked != null) setS(() => tempDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str.dateLabel,
                          style: TextStyle(
                              fontSize: 13, color: c.textMuted)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: Icon(Icons.calendar_today_rounded,
                                size: 16, color: c.accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tempDate == null
                                  ? str.dateLabel
                                  : DateFormat('d MMM yyyy', str.localeCode)
                                      .format(tempDate!),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.text),
                            ),
                          ),
                          if (tempDate != null)
                            GestureDetector(
                              onTap: () => setS(() => tempDate = null),
                              child:
                                  Icon(Icons.close, color: c.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(str.applyFilter),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _filterCats = tempCats;
        _filterDate = tempDate;
      });
    }
  }
}

/// Tür sekmeleri (Expense / Income / Transfer).
class _HistoryTabs extends StatelessWidget {
  const _HistoryTabs(
      {required this.mode, required this.str, required this.onChanged});

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
                    horizontal: 10, vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: m == mode ? c.accent : c.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          m == mode ? FontWeight.w700 : FontWeight.w500,
                      color: m == mode ? Colors.white : c.textMuted,
                    )),
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
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            formatDay(tx.date, str),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
        ));
      }
      items.add(TxTile(tx: tx, str: str));
    }
    return ListView(
      shrinkWrap: shrinkWrap,
      physics:
          shrinkWrap ? const NeverScrollableScrollPhysics() : null,
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(str.deleteWord),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guardWrite(context, str,
          () => ref.read(budgetRepositoryProvider).deleteTx(tx.id));
    }
  }

  /// İşleme dokununca: detay + Sil (yanlış girilen işlemi kaldırmak için).
  void _showActions(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final isIncome = tx.type == TxType.income;
    final isTransfer = tx.type == TxType.transfer;
    final title = switch (tx.type) {
      TxType.income => tx.note ?? str.incomeWord,
      TxType.expense => tx.note ?? tx.envelopeName ?? str.expenseWord,
      TxType.transfer => '${tx.fromName} → ${tx.envelopeName}',
    };
    final sign = isIncome ? '+' : isTransfer ? '' : '−';
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
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMMM yyyy', str.localeCode)
                              .format(tx.date),
                          style: TextStyle(
                              fontSize: 13, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$sign${formatMoneyIn(tx.amount, tx.currency)}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: c.text)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetCtx).pop();
                    if (!context.mounted) return;
                    await guardWrite(context, str,
                        () => ref.read(budgetRepositoryProvider).deleteTx(tx.id));
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
    // Üst satır (isim) + alt satır (kategori) — Cashly stili.
    final title = switch (tx.type) {
      TxType.income => tx.note ?? str.incomeWord,
      TxType.expense => tx.note ?? tx.envelopeName ?? str.expenseWord,
      TxType.transfer => '${tx.fromName} → ${tx.envelopeName}',
    };
    // Döviz çevirme → "Döviz" etiketi (Income/Expense değil).
    final subtitle = tx.isConvert
        ? str.convertTitle
        : switch (tx.type) {
            TxType.income => str.incomeWord,
            TxType.expense => tx.note != null
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

    final envById = {
      for (final e in ref.watch(envelopesProvider).value ?? const <Envelope>[])
        e.id: e,
    };
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
          // Gider: kategori görseli (kategorisizse soru işareti); gelir /
          // çevirme / transfer: yön simgesi.
          if (tx.type == TxType.expense && !tx.isConvert)
            switch (tx.envelopeId) {
              final id? when envById[id] != null =>
                CategoryAvatar(envelope: envById[id], size: 44),
              _ => const CategoryAvatar.none(size: 44),
            }
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
                      color: c.text),
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
            '${isIncome ? '+' : isTransfer ? '' : '−'}${formatMoneyIn(tx.amount, tx.currency)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isIncome ? c.accent : c.text,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/redesign_l10n.dart';
import '../accounts/account.dart';
import '../accounts/accounts_repository.dart';
import '../converter/converter_logic.dart';
import '../home/fx_providers.dart';
import '../recurring/recurring.dart';
import '../transactions/tx.dart';
import 'budget_repository.dart';

// ── seçili ay ─────────────────────────────────────────────────────────────

/// Ana ekran özetinin ayı: 0 = bu ay, -1 = geçen ay … [minOffset].
///
/// Sınır [recentTxsProvider]'ın penceresinden geliyor (son 6 ay): daha
/// gerisine gitseydik o ayın işlemleri hiç yüklenmemiş olurdu ve kart
/// "0 ₺ harcadın" diye yalan söylerdi.
final homeMonthOffsetProvider = NotifierProvider<HomeMonthOffset, int>(
  HomeMonthOffset.new,
);

class HomeMonthOffset extends Notifier<int> {
  static const minOffset = -5;

  @override
  int build() => 0;

  void shift(int delta) => state = (state + delta).clamp(minOffset, 0);
}

// ── dönem özeti ───────────────────────────────────────────────────────────

/// Bir ayın gelir/gider özeti ve birikimli harcama eğrisi — saf hesap.
///
/// Tutarların hepsi ana birimde ([Tx.baseOr]); döviz çevirme ve hedefe para
/// ayırma gerçek gelir/gider değil, ikisi de dışarıda (analiz ekranıyla aynı
/// kural, bkz. `analyzeMonth`).
class PeriodOverview {
  const PeriodOverview({
    required this.month,
    required this.income,
    required this.expense,
    required this.daysInMonth,
    required this.daysCounted,
    required this.cumulative,
    required this.prevCumulative,
    required this.largest,
  });

  final DateTime month;
  final double income;
  final double expense;
  final int daysInMonth;

  /// Geçerli ayda bugüne kadarki gün, geçmiş ayda ayın tamamı.
  final int daysCounted;

  /// Gün gün birikimli gider; uzunluğu [daysCounted].
  final List<double> cumulative;

  /// Önceki ayın TAMAMININ birikimli gideri; pencere dışındaysa null.
  final List<double>? prevCumulative;

  /// Dönemin en büyük gideri.
  final Tx? largest;

  double get net => income - expense;

  double get avgPerDay => daysCounted == 0 ? 0 : expense / daysCounted;

  /// Gelirin ne kadarı kaldı (0..1, aşımda negatif); gelir yoksa null —
  /// sıfıra bölüp "%−∞" yazmaktansa hiç yazmamak.
  double? get savedRate => income <= 0 ? null : (income - expense) / income;

  /// Önceki ayın AYNI GÜNÜNE göre harcama değişimi (0.12 = %12 fazla).
  ///
  /// Ayın 5'inde bu ayı geçen ayın tamamıyla kıyaslamak her ayı "çok
  /// tasarruflu" gösterirdi; aynı güne kadar olan kısımla kıyaslanıyor.
  /// Önceki ay o güne kadar sıfırsa ya da pencere dışındaysa null.
  double? get trend {
    final prev = prevCumulative;
    if (prev == null || prev.isEmpty || daysCounted == 0) return null;
    final base = prev[(daysCounted - 1).clamp(0, prev.length - 1)];
    if (base <= 0) return null;
    return (expense - base) / base;
  }
}

bool _isRealExpense(Tx t) =>
    t.type == TxType.expense && !t.isConvert && !t.isGoalFund;

bool _isRealIncome(Tx t) =>
    t.type == TxType.income && !t.isConvert && !t.isGoalFund;

bool _inMonth(Tx t, DateTime m) =>
    t.date.year == m.year && t.date.month == m.month;

List<double> _cumulative(Iterable<Tx> expenses, int days, String main) {
  final daily = List<double>.filled(days, 0);
  for (final t in expenses) {
    daily[t.date.day - 1] += t.baseOr(main);
  }
  var sum = 0.0;
  return [for (final d in daily) sum += d];
}

/// [txs]'ten [month] için özet. [hasPrev] false ise önceki ayın verisi
/// yüklenmemiş sayılır ([prevCumulative] null).
PeriodOverview buildOverview(
  List<Tx> txs, {
  required DateTime month,
  required String main,
  required DateTime now,
  bool hasPrev = true,
}) {
  final m = DateTime(month.year, month.month);
  final days = DateTime(m.year, m.month + 1, 0).day;
  final isCurrent = m.year == now.year && m.month == now.month;
  final counted = isCurrent ? now.day : days;

  var income = 0.0;
  final expenses = <Tx>[];
  for (final t in txs) {
    if (!_inMonth(t, m)) continue;
    if (_isRealIncome(t)) income += t.baseOr(main);
    if (_isRealExpense(t)) expenses.add(t);
  }
  final full = _cumulative(expenses, days, main);
  final cumulative = full.sublist(0, counted);

  List<double>? prev;
  if (hasPrev) {
    final pm = DateTime(m.year, m.month - 1);
    final pDays = DateTime(pm.year, pm.month + 1, 0).day;
    prev = _cumulative(
      txs.where((t) => _inMonth(t, pm) && _isRealExpense(t)),
      pDays,
      main,
    );
  }

  Tx? largest;
  for (final t in expenses) {
    if (largest == null || t.baseOr(main) > largest.baseOr(main)) largest = t;
  }

  return PeriodOverview(
    month: m,
    income: income,
    expense: cumulative.isEmpty ? 0 : cumulative.last,
    daysInMonth: days,
    daysCounted: counted,
    cumulative: cumulative,
    prevCumulative: prev,
    largest: largest,
  );
}

final homeOverviewProvider = Provider<PeriodOverview>((ref) {
  final offset = ref.watch(homeMonthOffsetProvider);
  final txs = ref.watch(recentTxsProvider).value ?? const <Tx>[];
  final main = ref.watch(currencyCodeProvider);
  final now = DateTime.now();
  return buildOverview(
    txs,
    month: DateTime(now.year, now.month + offset),
    main: main,
    now: now,
    hasPrev: offset > HomeMonthOffset.minOffset,
  );
});

// ── son hareketler: gün grupları ──────────────────────────────────────────

/// Listede tek satır: işlem, ya da döviz çevirmenin iki bacağı
/// ([out] çıkan gider, [into] giren gelir).
class RecentEntry {
  const RecentEntry(this.tx, {this.into});

  /// Tekil işlem ya da çevirmenin ÇIKAN bacağı.
  final Tx tx;

  /// Çevirmenin GİREN bacağı; tekil satırda null.
  final Tx? into;

  bool get isConvertPair => into != null;
}

class RecentDay {
  const RecentDay(this.day, this.entries, this.net);

  final DateTime day;
  final List<RecentEntry> entries;

  /// Günün net akışı (gelir − gider), ana birimde; çevirme ve transfer
  /// para yer değiştirmesi olduğu için sayılmaz.
  final double net;
}

/// Yeni→eski sıralı [txs]'i günlere böler, çevirme bacaklarını eşler ve
/// en çok [maxEntries] satır bırakır. Hedefe para ayırma gösterilmez
/// (hedef kartı kaydını tutuyor).
List<RecentDay> groupRecent(
  List<Tx> txs, {
  required String main,
  int maxEntries = 8,
}) {
  final byGroup = <String, List<Tx>>{};
  for (final t in txs) {
    if (t.groupId case final g?) (byGroup[g] ??= []).add(t);
  }

  final entries = <RecentEntry>[];
  final seenGroups = <String>{};
  for (final t in txs) {
    if (t.isGoalFund) continue;
    final g = t.groupId;
    if (t.isConvert && g != null) {
      if (!seenGroups.add(g)) continue;
      final legs = byGroup[g]!;
      final out = legs.where((l) => l.type == TxType.expense).firstOrNull;
      final into = legs.where((l) => l.type == TxType.income).firstOrNull;
      // Bacaklardan biri pencereye girmediyse tek satır olarak kalsın.
      entries.add(
        out != null && into != null
            ? RecentEntry(out, into: into)
            : RecentEntry(t),
      );
    } else {
      entries.add(RecentEntry(t));
    }
    if (entries.length >= maxEntries) break;
  }

  final days = <RecentDay>[];
  DateTime? current;
  var bucket = <RecentEntry>[];
  var net = 0.0;
  void flush() {
    if (current case final d?) days.add(RecentDay(d, bucket, net));
  }

  for (final e in entries) {
    final d = DateTime(e.tx.date.year, e.tx.date.month, e.tx.date.day);
    if (current != d) {
      flush();
      current = d;
      bucket = [];
      net = 0;
    }
    bucket.add(e);
    final t = e.tx;
    if (_isRealIncome(t)) net += t.baseOr(main);
    if (_isRealExpense(t)) net -= t.baseOr(main);
  }
  flush();
  return days;
}

// ── işlem satırı yardımcıları ─────────────────────────────────────────────

/// İşlemin hesap adı: kimlik → ad. Kimliksiz eski kayıt ana cüzdana
/// (nakit) aittir. Hesaplar yüklenmediyse null — satır adı uydurmaz.
final accountLabelsProvider = Provider<Map<String, String>?>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  if (accounts == null) return null;
  final rs = ref.watch(rsProvider);
  return {
    for (final a in accounts)
      a.id: a.isCash && a.name.trim().isEmpty ? rs.cash : a.name,
    // Liste boşken (ilk açılış) nakit yine de adlansın.
    if (!accounts.any((a) => a.isCash)) Account.cashId: rs.cash,
  };
});

String? accountLabelOf(Tx t, Map<String, String>? labels) {
  if (labels == null) return null;
  return labels[t.accountId ?? Account.cashId];
}

/// Tekrarlayan kurallardan doğmuş işlemleri tanımak için imza.
///
/// İşlem belgesi kuralın kimliğini taşımıyor; tür + tutar + kategori + not
/// birlikte kuralla aynıysa o kuralın ürünü sayılır. Kural silinince
/// işaret de kalkar — ki doğru: artık tekrarlamıyor.
String _recurringSig(
  String type,
  double amount,
  String? envelopeId,
  String? note,
) =>
    '$type|${amount.toStringAsFixed(2)}|${envelopeId ?? ''}|${note?.trim() ?? ''}';

final recurringSignaturesProvider = Provider<Set<String>>((ref) {
  final rules =
      ref.watch(recurringRulesProvider).value ?? const <RecurringRule>[];
  return {
    for (final r in rules)
      _recurringSig(r.type, r.amount, r.envelopeId, r.note),
  };
});

bool isRecurringTx(Tx t, Set<String> signatures) =>
    signatures.isNotEmpty &&
    t.type != TxType.transfer &&
    signatures.contains(
      _recurringSig(t.type.name, t.amount, t.envelopeId, t.note),
    );

// ── toplam bakiye ─────────────────────────────────────────────────────────

/// Tüm (arşivlenmemiş) hesapların ana birimdeki toplamı, BUGÜNÜN kuruyla.
///
/// Burada güncel kur doğru olan: bu bir geçmiş kaydı değil, "şu an elimde
/// ne var" sorusu. Bir döviz hesabının kuru yoksa toplam null — eksik
/// toplamı tam gibi göstermiyoruz.
final accountsTotalProvider = Provider<double?>((ref) {
  final main = ref.watch(currencyCodeProvider);
  final accounts = ref.watch(accountsProvider).value;
  if (accounts == null) return null;
  final active = accounts.where((a) => !a.archived).toList();
  if (active.isEmpty) return ref.watch(cashBalanceProvider).value;
  final needsFx = active.any((a) => a.currency != main && a.balance != 0);
  final snap = needsFx ? ref.watch(fxSnapshotProvider(main)).value : null;
  var sum = 0.0;
  for (final a in active) {
    if (a.currency == main) {
      sum += a.balance;
      continue;
    }
    if (a.balance == 0) continue;
    final p = priceInMain(snap, a.currency);
    if (p == null) return null;
    sum += a.balance * p;
  }
  return sum;
});

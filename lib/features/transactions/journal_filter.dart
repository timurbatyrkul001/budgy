import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/tokens.dart';
import '../accounts/account.dart';
import 'tx.dart';

// ─────────────────────────────────────────────────────────────────────────
// Saf mantık: sıralama + filtre. Widget'tan bağımsız ki testlenebilsin.
// ─────────────────────────────────────────────────────────────────────────

/// Geçmiş listesinin sıralama anahtarı.
enum JournalSortKey { date, amount, category }

/// Dönem ön ayarları. [day] = tek bir gün (eski "tarih" filtresi).
enum JournalPeriod { all, thisMonth, last30, day }

/// "Hesapsız" çipinin kimliği: eski kayıtlarda `accountId` yok, bunları
/// gerçek bir hesap kimliğiyle karıştırmamak için ayrı bir nöbetçi değer.
const kJournalNoAccount = '__no_account__';

/// Sıralama durumu. Varsayılan: tarihe göre, yeniden eskiye.
class JournalSort {
  const JournalSort({
    this.key = JournalSortKey.date,
    this.descending = true,
  });

  final JournalSortKey key;
  final bool descending;

  static const def = JournalSort();

  bool get isDefault => key == def.key && descending == def.descending;

  /// Satıra dokunma: aynı anahtarsa yönü çevirir, farklıysa o anahtara
  /// geçer ve doğal yönünü alır (tarih/tutar azalan, kategori A→Z).
  JournalSort tapped(JournalSortKey k) {
    if (k == key) return JournalSort(key: key, descending: !descending);
    return JournalSort(key: k, descending: k != JournalSortKey.category);
  }
}

/// Filtre durumu. Boş küme / `all` / null = kısıt yok.
class JournalFilter {
  const JournalFilter({
    this.categories = const {},
    this.period = JournalPeriod.all,
    this.day,
    this.accountId,
  });

  /// Seçili kategori adları (zarfın görünen adı; `Tx.envelopeName` ile aynı).
  final Set<String> categories;
  final JournalPeriod period;

  /// Yalnız [period] == [JournalPeriod.day] iken anlamlı.
  final DateTime? day;

  /// null = tüm hesaplar; [kJournalNoAccount] = yalnız hesapsız kayıtlar.
  final String? accountId;

  static const none = JournalFilter();

  bool get isActive =>
      categories.isNotEmpty ||
      (period != JournalPeriod.all && !(period == JournalPeriod.day && day == null)) ||
      accountId != null;

  JournalFilter copyWith({
    Set<String>? categories,
    JournalPeriod? period,
    DateTime? Function()? day,
    String? Function()? accountId,
  }) {
    return JournalFilter(
      categories: categories ?? this.categories,
      period: period ?? this.period,
      day: day != null ? day() : this.day,
      accountId: accountId != null ? accountId() : this.accountId,
    );
  }
}

/// Listenin sorgusu: sıralama + filtre birlikte — alt sayfa bunu döndürür.
class JournalQuery {
  const JournalQuery({required this.sort, required this.filter});

  final JournalSort sort;
  final JournalFilter filter;
}

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// [period] bu kaydı kapsıyor mu? [now] dışarıdan gelir ki testte "bugün"
/// sabitlenebilsin.
bool journalPeriodMatches(Tx t, JournalFilter f, DateTime now) {
  switch (f.period) {
    case JournalPeriod.all:
      return true;
    case JournalPeriod.thisMonth:
      // Takvim ayı — "son 30 gün" DEĞİL. Ayın 1'inden sonuna.
      return t.date.year == now.year && t.date.month == now.month;
    case JournalPeriod.last30:
      // Bugün dahil 30 takvim günü: bugün − 29 günün başından itibaren.
      final from = _dayStart(now).subtract(const Duration(days: 29));
      return !t.date.isBefore(from);
    case JournalPeriod.day:
      final d = f.day;
      if (d == null) return true;
      return t.date.year == d.year &&
          t.date.month == d.month &&
          t.date.day == d.day;
  }
}

/// Filtreyi uygular. Tür (gider/gelir/transfer) ve arama burada DEĞİL —
/// onlar ekranın kendi işi; burası yalnız alt sayfadaki kısıtlar.
List<Tx> applyJournalFilter(
  Iterable<Tx> txs,
  JournalFilter f, {
  required DateTime now,
}) {
  return txs.where((t) {
    if (f.categories.isNotEmpty && !f.categories.contains(t.envelopeName)) {
      return false;
    }
    if (!journalPeriodMatches(t, f, now)) return false;
    final acc = f.accountId;
    if (acc != null) {
      if (acc == kJournalNoAccount) {
        if (t.accountId != null) return false;
      } else if (t.accountId != acc) {
        return false;
      }
    }
    return true;
  }).toList();
}

/// Kategori adı karşılaştırma için: boş/null → null (listenin sonuna).
String? _categoryKey(Tx t) {
  final n = t.envelopeName?.trim();
  if (n == null || n.isEmpty) return null;
  return n.toLowerCase();
}

/// Eşitlikte sabit ikincil anahtar: tarih (yeniden eskiye), sonra id.
/// Bunsuz aynı tutarlı/kategorili kayıtlar her yeniden kurulumda yer
/// değiştirirdi.
int _tieBreak(Tx a, Tx b) {
  final byDate = b.date.compareTo(a.date);
  if (byDate != 0) return byDate;
  return a.id.compareTo(b.id);
}

/// Sıralar; yeni liste döndürür. Tutar karşılaştırması ana para birimine
/// çevrilmiş tutarla ([Tx.baseOr]) — analitiğin geri kalanıyla aynı kural.
List<Tx> sortJournal(
  Iterable<Tx> txs,
  JournalSort sort, {
  required String mainCurrency,
}) {
  final list = txs.toList();
  final dir = sort.descending ? -1 : 1;
  switch (sort.key) {
    case JournalSortKey.date:
      list.sort((a, b) {
        final c = a.date.compareTo(b.date) * dir;
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    case JournalSortKey.amount:
      list.sort((a, b) {
        final c = a.baseOr(mainCurrency).compareTo(b.baseOr(mainCurrency)) * dir;
        return c != 0 ? c : _tieBreak(a, b);
      });
    case JournalSortKey.category:
      list.sort((a, b) {
        final ka = _categoryKey(a);
        final kb = _categoryKey(b);
        // Kategorisizler iki yönde de SONA: yön çarpanından önce ele alınır,
        // yoksa artan sıralamada boş ad en başa fırlardı.
        if (ka == null && kb == null) return _tieBreak(a, b);
        if (ka == null) return 1;
        if (kb == null) return -1;
        final c = ka.compareTo(kb) * dir;
        return c != 0 ? c : _tieBreak(a, b);
      });
  }
  return list;
}

// ─────────────────────────────────────────────────────────────────────────
// Alt sayfa: "Sırala ve Filtrele".
// ─────────────────────────────────────────────────────────────────────────

/// Alt sayfadaki hesap çipi için veri: `null` kimlik = "Tümü".
class JournalAccountChip {
  const JournalAccountChip({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String? id;
  final String label;
  final IconData icon;
}

IconData _accountIcon(Account a) => switch (a.kind) {
      AccountKind.cash => Icons.payments_outlined,
      AccountKind.card => Icons.credit_card_rounded,
      AccountKind.bank => Icons.account_balance_outlined,
    };

/// Hesap çiplerini kurar. Arşivliler dışarıda; "Hesapsız" çipi yalnız
/// [hasNoAccountTxs] iken. [cashLabel]: adı boş eski `cash` belgesi için.
List<JournalAccountChip> buildAccountChips({
  required List<Account> accounts,
  required bool hasNoAccountTxs,
  required Strings str,
  required String cashLabel,
}) {
  final visible = accounts.where((a) => !a.archived).toList();
  return [
    JournalAccountChip(
        id: null, label: str.filterAll, icon: Icons.all_inclusive_rounded),
    for (final a in visible)
      JournalAccountChip(
        id: a.id,
        label: a.name.trim().isEmpty ? cashLabel : a.name,
        icon: _accountIcon(a),
      ),
    if (hasNoAccountTxs)
      JournalAccountChip(
        id: kJournalNoAccount,
        label: str.filterNoAccount,
        icon: Icons.help_outline_rounded,
      ),
  ];
}

/// Hesap bölümü çizilsin mi: tek (ya da sıfır) hesapta tek bir "Tümü"
/// çipi gürültüden ibaret.
bool showAccountSection(List<Account> accounts) =>
    accounts.where((a) => !a.archived).length >= 2;

/// Sırala & Filtrele alt sayfası. Sağlayıcı okumaz — hesaplar, kategoriler
/// ve dil dışarıdan verilir; böylece modal rotanın ProviderScope'u ne olursa
/// olsun aynı veriyi görür.
class JournalSortFilterSheet extends StatefulWidget {
  const JournalSortFilterSheet({
    super.key,
    required this.str,
    required this.initial,
    required this.categories,
    required this.accountChips,
    required this.showAccounts,
  });

  final Strings str;
  final JournalQuery initial;
  final List<String> categories;
  final List<JournalAccountChip> accountChips;
  final bool showAccounts;

  @override
  State<JournalSortFilterSheet> createState() => _JournalSortFilterSheetState();
}

class _JournalSortFilterSheetState extends State<JournalSortFilterSheet> {
  late JournalSort _sort = widget.initial.sort;
  late JournalFilter _filter = widget.initial.filter;

  Strings get str => widget.str;

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initial: _filter.day ?? now,
      first: DateTime(now.year - 3),
      last: DateTime(now.year + 1),
      localeCode: str.localeCode,
    );
    if (picked == null || !mounted) return;
    setState(() => _filter =
        _filter.copyWith(period: JournalPeriod.day, day: () => picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final day = _filter.day;
    final dayLabel = day == null
        ? str.periodPickDay
        : DateFormat('d MMM yyyy', str.localeCode).format(day);

    return SheetFrame(
      title: str.sortFilterTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: c.border),
          _SectionLabel(str.sortByLabel),
          _SortGroup(
            sort: _sort,
            str: str,
            onTap: (k) => setState(() => _sort = _sort.tapped(k)),
          ),
          if (widget.showAccounts) ...[
            _SectionLabel(str.accountLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in widget.accountChips)
                  _FilterChip(
                    label: chip.label,
                    icon: chip.icon,
                    selected: _filter.accountId == chip.id,
                    onTap: () => setState(() => _filter =
                        _filter.copyWith(accountId: () => chip.id)),
                  ),
              ],
            ),
          ],
          _SectionLabel(str.periodLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (p, label, icon) in [
                (JournalPeriod.all, str.periodAllTime,
                    Icons.all_inclusive_rounded),
                (JournalPeriod.thisMonth, str.periodThisMonth,
                    Icons.calendar_month_outlined),
                (JournalPeriod.last30, str.periodLast30,
                    Icons.history_rounded),
              ])
                _FilterChip(
                  label: label,
                  icon: icon,
                  selected: _filter.period == p,
                  onTap: () => setState(() => _filter =
                      _filter.copyWith(period: p, day: () => null)),
                ),
              // Tek gün: çip seçili günü yazar, dokununca takvim açılır
              // (seçiliyken de — günü değiştirmek için).
              _FilterChip(
                label: dayLabel,
                icon: Icons.today_rounded,
                selected: _filter.period == JournalPeriod.day && day != null,
                onTap: _pickDay,
              ),
            ],
          ),
          if (widget.categories.isNotEmpty) ...[
            _SectionLabel(str.categoriesLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in widget.categories)
                  _FilterChip(
                    label: cat,
                    selected: _filter.categories.contains(cat),
                    onTap: () => setState(() {
                      final next = {..._filter.categories};
                      next.contains(cat) ? next.remove(cat) : next.add(cat);
                      _filter = _filter.copyWith(categories: next);
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Ex.onBrand,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => Navigator.of(context)
                  .pop(JournalQuery(sort: _sort, filter: _filter)),
              child: Text(str.applyFilter),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm rubriği: küçük, gri, BÜYÜK HARF.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c.textMuted,
        ),
      ),
    );
  }
}

/// Sıralama satırları: tek yuvarlak kap, ince ayırıcılar. Seçili satır
/// hafif yeşil, metni/simgesi vurgulu, sağında yön oku. Ok YALNIZ seçili
/// satırda — yönü ayrıca bir anahtar yok, satıra tekrar dokunmak çevirir.
class _SortGroup extends StatelessWidget {
  const _SortGroup(
      {required this.sort, required this.str, required this.onTap});

  final JournalSort sort;
  final Strings str;
  final ValueChanged<JournalSortKey> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final instant = reduceMotion(context);
    final rows = [
      (JournalSortKey.date, str.sortDate, Icons.calendar_today_rounded),
      (JournalSortKey.amount, str.sortAmount, Icons.payments_outlined),
      (JournalSortKey.category, str.sortCategory, Icons.label_outline_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, (key, label, icon)) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, color: c.border),
            _SortRow(
              label: label,
              icon: icon,
              selected: sort.key == key,
              descending: sort.descending,
              instant: instant,
              str: str,
              onTap: () => onTap(key),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.descending,
    required this.instant,
    required this.str,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool descending;
  final bool instant;
  final Strings str;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final fg = selected ? c.accentStrong : c.text;
    return Semantics(
      selected: selected,
      button: true,
      // Ekran okuyucu yönü de duysun — görsel ok tek ipucu olmasın.
      hint: selected ? (descending ? str.sortDescending : str.sortAscending) : null,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: instant ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          color: selected ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withValues(alpha: 0.18)
                      : c.surface2,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  descending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18,
                  color: fg,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtre çipi: seçili = mürekkep dolgu + beyaz metin; değilse beyaz +
/// çerçeve. [icon] isteğe bağlı (kategori çiplerinde yok).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final instant = reduceMotion(context);
    final fg = selected ? Ex.onBrand : c.text;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: instant ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.text : c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? c.text : c.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              // Dar ekranda (320dp) uzun hesap adı Wrap'i taşırmasın.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
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

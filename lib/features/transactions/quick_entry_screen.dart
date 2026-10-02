import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_date_picker.dart';
import '../../core/calc.dart';
import '../../core/category_avatar.dart';
import '../../core/currency_info.dart';
import '../../core/ex_style.dart';
import '../../core/motion.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/fx.dart';
import '../../core/fx_freeze.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../accounts/account.dart';
import '../accounts/account_editor_sheet.dart';
import '../accounts/account_picker.dart';
import '../accounts/account_suggestion.dart';
import '../accounts/accounts_repository.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../home/accounts_screen.dart';
import '../home/fx_providers.dart';
import '../pro/pro_gate.dart';
import '../pro/pro_state.dart';
import '../recurring/recurring.dart';
import '../recurring/recurring_screen.dart';
import '../settings/app_settings.dart';
import '../settings/category_resolver.dart';
import 'category_sheet.dart';
import 'tx.dart';

/// Hızlı giriş sonucu: son kaydedilen işlem (geri almak için) + adet.
class QuickEntryResult {
  const QuickEntryResult({required this.lastTxId, required this.count});

  final String lastTxId;
  final int count;
}

enum QuickMode { expense, income }

/// "+" ekranı: hesap makinesi klavyesi, gider/gelir, hesap (nakit ya da
/// döviz cüzdanı), tarih / tekrar / not çipleri, kategori. Kayıt
/// [QuickEntryResult] ile döner; ana ekran "Kaydedildi · Geri al" gösterir.
///
/// [initialExpression] / [autoSheet] yalnız debug önizlemesi için
/// (bkz. core/preview.dart).
Future<QuickEntryResult?> showQuickEntry(
  BuildContext context, {
  String initialExpression = '',
  String? autoSheet,
}) {
  return Navigator.of(context).push<QuickEntryResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuickEntryScreen(
        initialExpression: initialExpression,
        autoSheet: autoSheet,
      ),
    ),
  );
}

/// Var olan işlemi düzenle: ekran tutar/tür/hesap/kategori/tarih/notla
/// dolu açılır, Kaydet AYNI belgeyi günceller (yeni kayıt yok). Tekrar
/// kuralı buradan düzenlenmez. Kaydedildiyse true döner.
Future<bool?> showQuickEntryEdit(BuildContext context, Tx tx) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => QuickEntryScreen(editing: tx),
    ),
  );
}

class QuickEntryScreen extends ConsumerStatefulWidget {
  const QuickEntryScreen({
    super.key,
    this.initialExpression = '',
    this.autoSheet,
    this.editing,
  });

  final String initialExpression;
  final String? autoSheet;

  /// Düzenlenen işlem (null = yeni kayıt).
  final Tx? editing;

  @override
  ConsumerState<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends ConsumerState<QuickEntryScreen> {
  QuickMode _mode = QuickMode.expense;
  Envelope? _wallet; // null = nakit cüzdan
  late String _expr = widget.initialExpression;
  late DateTime _date = _today();
  Recurrence _recurrence = Recurrence.none;
  String _note = '';
  CategoryPick? _category;
  bool _multi = false;
  int _savedCount = 0;
  String? _lastTxId;
  bool _saving = false;

  /// Kullanıcının ELLE seçtiği hesap. null = hiç dokunmadı, form öneriyle
  /// gider (bkz. [_currentAccount]). Ayrı bir bool yerine id tutuyoruz:
  /// "elle seçildi mi" ve "hangisi" tek alanda, ikisi tutarsız olamaz.
  String? _pickedAccountId;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isEditing => widget.editing != null;

  /// Tutarı klavye ifadesine çevir: 450 → "450", 12.5 → "12.5".
  static String _exprFor(double amount) {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    var s = amount.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.editing;
    if (tx != null) {
      // Ön doldurma: hesap (döviz cüzdanı) ve kategori mevcut zarflardan.
      final all = ref.read(envelopesProvider).value ?? const <Envelope>[];
      final env = all.where((e) => e.id == tx.envelopeId).firstOrNull;
      final str = ref.read(strProvider);
      _mode = tx.type == TxType.income ? QuickMode.income : QuickMode.expense;
      _expr = _exprFor(tx.amount);
      _date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      _note = tx.note ?? '';
      // Zarf akışı henüz gelmediyse işlemdeki denormalize ad yeter.
      // Hesaba bağlı kayıtta döviz kodu KARTIN birimidir, zarfın değil:
      // orada envelopeId harcama kategorisi/gelir kaynağıdır, "cüzdan"
      // değil. Manat kartı kaydını döviz zarfı sanıp kategoriyi yutmayalım.
      if (tx.accountId == null && tx.currency != 'TRY') {
        _wallet =
            env ??
            (tx.envelopeId == null
                ? null
                : Envelope(
                    id: tx.envelopeId!,
                    name: tx.envelopeName ?? tx.currency,
                    emoji: '',
                    balance: 0,
                    sortOrder: 0,
                    currency: tx.currency,
                  ));
      } else if (tx.envelopeId != null) {
        _category = CategoryPick(
          id: tx.envelopeId!,
          name: env?.displayName(str) ?? tx.envelopeName ?? '',
          emoji: env?.emoji ?? '',
          catalogKey: env?.presetKey,
        );
      }
    }
    final sheet = widget.autoSheet;
    if (sheet != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => switch (sheet) {
          'category' => _pickCategory(),
          'categoryScrolled' => _pickCategory(initialScroll: 900),
          'incomeCategory' => () {
            setState(() => _mode = QuickMode.income);
            _pickCategory();
          }(),
          'recurrence' => _pickRecurrence(),
          'date' => _pickDate(),
          _ => null,
        },
      );
    }
  }

  double get _amount => evalExpression(_expr);

  /// Kategori yalnız nakit hesapta anlamlı: giderde harcama kategorisi,
  /// gelirde kaynak (maaş, hediye…). Döviz cüzdanında hedef cüzdanın kendisi.
  bool get _categoryApplies => _wallet == null;

  /// Düzenlenen kaydın bağlı olduğu hesap — liste yüklendiyse ve hesap
  /// hâlâ listedeyse. Eski (hesapsız) kayıtta ve arşivlenmiş hesapta null.
  Account? _editingAccount(List<Account> accounts) {
    final id = widget.editing?.accountId;
    if (id == null) return null;
    return accounts.where((a) => a.id == id).firstOrNull;
  }

  /// Düzenlenen kayıt hesaba bağlıysa o hesabın birimi; yoksa null.
  /// Hesap listede olmasa bile (arşivlenmiş) tutar o birimde gösterilmeli.
  String? get _editingAccountCurrency =>
      widget.editing?.accountId == null ? null : widget.editing?.currency;

  /// Hesap (kart) seçimi nakit yolundayken devrede — yeni gider, yeni gelir
  /// ve düzenleme. Üçü de aynı çipi kullanır; gelirde para hesaba GİRER,
  /// giderde ÇIKAR, düzenlemede eski etki geri alınıp yenisi uygulanır
  /// (depo tarafı: addExpense / addCashIncome / updateTx).
  ///
  /// * Döviz zarfı (eski "cüzdan") seçiliyse para o zarftan düşer; hesap
  ///   kavramı oraya karışmaz.
  /// * İki hesaptan azı varsa seçecek şey yok: akış hesaplardan ÖNCEKİ
  ///   hâliyle birebir aynı kalır, depo yeni alanları hiç görmez. Kart
  ///   eklememiş kullanıcı için hiçbir şey değişmemeli. Tek istisna:
  ///   düzenlenen kayıt zaten bir hesaba bağlıysa çip görünür — değiştirecek
  ///   ikinci hesap olmasa da "nereden" bilgisi gösterilir ve bağ korunur.
  bool _accountsApply(List<Account> accounts) =>
      _wallet == null &&
      (accounts.length >= 2 || _editingAccount(accounts) != null);

  /// Formun şu anki hesabı: kullanıcı dokunduysa onun seçimi (liste hâlâ
  /// içeriyorsa), düzenlemede kaydın kendi hesabı, yeni kayıtta kategori +
  /// geçmişe göre öneri.
  ///
  /// Saklanan bir "seçili hesap" alanı yok, her build'de türetiliyor:
  /// böylece kategori değişince öneri kendiliğinden yenilenir, elle seçim
  /// ise [_pickedAccountId] dolu olduğu sürece önerinin önüne geçer — iki
  /// kaynağı senkron tutmaya çalışan setState zinciri gerekmez.
  Account? _currentAccount(List<Account> accounts, List<Tx> recent) {
    if (!_accountsApply(accounts)) return null;
    final picked = _pickedAccountId;
    if (picked != null) {
      final match = accounts.where((a) => a.id == picked).firstOrNull;
      if (match != null) return match;
    }
    // Düzenlemede öneri YOK: kullanıcı dokunmadıysa kaydın kendi hesabı
    // kalır. Eski (hesapsız) kayda öneriyle kart iliştirmek, "sadece tutarı
    // düzelttim" diyen kullanıcının parasını sessizce nakitten karta
    // taşırdı — eski kayıt eskisi gibi düzenlenmeli.
    if (_isEditing) return _editingAccount(accounts);
    final id = suggestAccount(
      accounts: accounts,
      recent: recent,
      categoryId: _category?.id,
    );
    return accounts.where((a) => a.id == id).firstOrNull;
  }

  // ── tuşlar ────────────────────────────────────────────────────────────

  void _key(String k) {
    HapticFeedback.selectionClick();
    setState(() => _expr = appendKey(_expr, k));
  }

  void _back() {
    HapticFeedback.selectionClick();
    setState(() => _expr = backspace(_expr));
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() => _expr = '');
  }

  // ── sayfalar ──────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initial: _date,
      first: DateTime(now.year - 5),
      last: DateTime(now.year + 2, 12, 31),
      localeCode: str.localeCode,
      title: rs.dateTitle,
      todayLabel: rs.today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickRecurrence() async {
    // Tekrarlayan işlem kuralı Pro: düğme görünür kalır, Pro değilse
    // sıklık sayfası yerine paywall açılır (Tekrarlayan ekranıyla aynı kilit).
    // kProEnabled kapalıyken (1.0) requirePro doğrudan geçer.
    if (!await requirePro(context, ref, ProFeature.automation)) return;
    if (!mounted) return;
    final rs = ref.read(rsProvider);
    final picked = await showExSheet<Recurrence>(
      context,
      SheetFrame(
        title: rs.repeat,
        child: Column(
          children: [
            for (final r in Recurrence.values)
              _OptionRow(
                label: recurrenceLabel(rs, r),
                selected: r == _recurrence,
                onTap: () => Navigator.of(context).pop(r),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _recurrence = picked);
  }

  Future<void> _editNote() async {
    final rs = ref.read(rsProvider);
    final text = await showExSheet<String>(
      context,
      _NoteSheet(initial: _note, hint: rs.noteHint, title: rs.note),
    );
    if (text != null) setState(() => _note = text.trim());
  }

  Future<void> _pickCategory({double initialScroll = 0}) async {
    final pick = await showCategorySheet(
      context,
      selectedId: _category?.id,
      initialScroll: initialScroll,
      income: _mode == QuickMode.income,
    );
    if (pick != null) setState(() => _category = pick);
  }

  Future<void> _pickAccount() async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final code = ref.read(currencyCodeProvider);
    final wallets = ref.read(accountEnvelopesProvider);
    final picked = await showExSheet<Object>(
      context,
      SheetFrame(
        title: rs.account,
        child: Column(
          children: [
            _OptionRow(
              label: '${currencyFlag(code)}  ${rs.cash} · $code',
              selected: _wallet == null,
              onTap: () => Navigator.of(context).pop('cash'),
            ),
            for (final w in wallets)
              _OptionRow(
                label:
                    '${currencyFlag(w.currency)}  ${w.displayName(str)} · ${w.currency}',
                selected: _wallet?.id == w.id,
                onTap: () => Navigator.of(context).pop(w),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _wallet = picked is Envelope ? picked : null;
      if (!_categoryApplies) _category = null;
    });
  }

  /// Kart çipi: hangi hesaptan? Seçim [_pickedAccountId]'ye yazılır ve
  /// bundan sonra öneri onu ezmez.
  Future<void> _pickCard(List<Account> accounts, Account current) async {
    final rs = ref.read(rsProvider);
    final main = ref.read(currencyCodeProvider);
    final id = await showAccountPicker(
      context,
      selectedId: current.id,
      accounts: accounts,
      // Gelirde para hesaba GİRER: "hangi hesaptan" sorusu yanlış olurdu.
      title: _mode == QuickMode.income
          ? rs.accountToTitle
          : rs.accountFromTitle,
      addLabel: rs.accountAdd,
      // Sheet önce kapanır, sonra bu çağrılır; editör formun üstüne açılır.
      onAddAccount: () => showAccountEditor(context),
      // Yabancı kartta kullanıcı kurun uygulanacağını baştan bilsin.
      warning: current.currency == main
          ? null
          : tpl(rs.accountFxNoteTpl, {'from': current.currency, 'to': main}),
    );
    if (id != null) setState(() => _pickedAccountId = id);
  }

  /// [from] birimindeki [amount]'u ana birime DONDURUR; kur yoksa null.
  ///
  /// Kur tablosu [fxSnapshotProvider] ile asenkron gelir. `.value` değil
  /// `.future` bekliyoruz: ilk açılışta (önbellek boş, ağ yavaş) tablo
  /// henüz yüklenmemiş olabilir; "yüklenmedi"yi "kur yok" sanıp kullanıcıyı
  /// boşuna geri çevirmeyelim. Tablo gelmezse (çevrimdışı + önbellek yok)
  /// ya da çift tabloda yoksa null.
  ///
  /// NEDEN KURSUZ KAYDETMİYORUZ: `Tx.baseAmount` bir kez yazılır, bir daha
  /// değişmez. 0 ya da uydurma bir kurla kaydedersek o ayın toplamı kalıcı
  /// yanlış olur; kaydetmemek yanlış kaydetmekten ucuz — form dolu kalır,
  /// kullanıcı birazdan tekrar dener.
  Future<({double baseAmount, String baseCurrency, double rate})?> _freezeFor({
    required double amount,
    required String from,
  }) async {
    final main = ref.read(currencyCodeProvider);
    try {
      // Aynı birimde çevrim yok; ağa hiç çıkmıyoruz ki tek birimli kart
      // sahibi çevrimdışıyken de kaydedebilsin. `freezeToBase` aynı birimde
      // tabloya bakmaz, imzası istediği için boş tablo veriyoruz.
      final fx = from == main
          ? FxSnapshot(base: main, rates: const {}, fetchedAt: DateTime.now())
          : await ref.read(fxSnapshotProvider(main).future);
      if (fx == null) return null;
      final frozen = freezeToBase(amount: amount, from: from, to: main, fx: fx);
      return (
        baseAmount: frozen.baseAmount,
        baseCurrency: main,
        rate: frozen.rate,
      );
    } on FxUnavailable {
      return null;
    } catch (_) {
      // Kur yükleyicisinin beklenmedik hatası da "kur yok" demektir;
      // kullanıcıya aynı mesaj, kayıt yine yapılmaz.
      return null;
    }
  }

  /// Düzenlemede para tarafı (hesap, tutar, birim) DEĞİŞMEDİYSE kayıttaki
  /// dondurulmuş kur olduğu gibi kalır: yalnız notu/tarihi/kategoriyi
  /// düzelten kullanıcı geçmiş kuru bugünkünün üstüne yazmamalı (geçmişi
  /// oynatmak tam da kaçındığımız şey) ve bunun için ağa çıkması da
  /// gerekmemeli. Değiştiyse null: bu yeni bir olgu kaydıdır, kur
  /// [_freezeFor] ile yeniden dondurulur. Ana birim değiştiyse de null —
  /// eski çevrim artık başka birime.
  ({double baseAmount, String baseCurrency, double rate})? _frozenToKeep({
    required Tx? editing,
    required String accountId,
    required double amount,
    required String currency,
  }) {
    if (editing == null) return null;
    final base = editing.baseAmount;
    final baseCurrency = editing.baseCurrency;
    final rate = editing.fxRate;
    if (base == null || baseCurrency == null || rate == null) return null;
    if (editing.accountId != accountId ||
        editing.amount != amount ||
        editing.currency != currency) {
      return null;
    }
    if (baseCurrency != ref.read(currencyCodeProvider)) return null;
    return (baseAmount: base, baseCurrency: baseCurrency, rate: rate);
  }

  /// "…" menüsü: hesap makinesi / çoklu giriş.
  /// Gider-gelir seçimi artık panelin üstünde görünür anahtar.
  Future<void> _menu() async {
    final rs = ref.read(rsProvider);
    final picked = await showExSheet<bool>(
      context,
      SheetFrame(
        title: rs.quickEntryTitle,
        child: Column(
          children: [
            _OptionRow(
              icon: Icons.calculate_outlined,
              label: rs.calculatorMode,
              selected: !_multi,
              onTap: () => Navigator.of(context).pop(false),
            ),
            _OptionRow(
              icon: Icons.playlist_add_rounded,
              label: rs.multiMode,
              selected: _multi,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _multi = picked);
  }

  // ── kayıt ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final amount = _amount;
    if (amount <= 0 || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final str = ref.read(strProvider);
    final note = _note.isEmpty ? null : _note;
    // Bugünse şimdiki saat (sıralama doğal kalsın); geçmiş günse öğlen.
    final date = _date == _today()
        ? DateTime.now()
        : DateTime(_date.year, _date.month, _date.day, 12);
    final wallet = _wallet;
    final isExpense = _mode == QuickMode.expense;
    final editing = widget.editing;
    final account = _currentAccount(
      ref.read(accountsProvider).value ?? const <Account>[],
      ref.read(recentTxsProvider).value ?? const <Tx>[],
    );
    // Hesap kimliği: formdaki seçim; düzenlemede seçim yoksa kaydın kendi
    // hesabı — liste henüz gelmemiş ya da hesap arşivlenmiş olsa bile bağ
    // kopmaz, yoksa kayıt sessizce nakde taşınırdı. Döviz zarfına geçildiyse
    // bağ kalkar: para artık zarftan çıkıyor.
    final accountId =
        account?.id ?? (wallet == null ? editing?.accountId : null);
    // İşlemin birimi SEÇİLİ HESABIN birimi (manat kartından manat çıkar);
    // hesap listede yoksa kayıttaki birim; hesap yoksa eski kural: döviz
    // zarfının birimi ya da ₺.
    final String currency;
    if (account != null) {
      currency = account.currency;
    } else if (accountId != null) {
      currency = editing!.currency;
    } else {
      currency = wallet?.currency ?? 'TRY';
    }
    // Kategori: giderde harcama kategorisi, gelirde kaynak etiketi.
    var envelopeId = wallet?.id ?? _category?.id;
    var envelopeName = wallet?.displayName(str) ?? _category?.name;
    // Kategori seçilmediyse nottaki anahtar kelimeler seçsin (otomasyon);
    // kullanıcının seçtiği kategori asla ezilmez.
    // Kategori otomasyonu Pro: Pro değilse çözümleme HİÇ çağrılmaz, sessizce
    // atlanır — kullanıcı kategoriyi elle seçer. Düğmesi olmayan bir özellik
    // için paywall açmak kaydı bölerdi; satış noktası Otomasyon ekranı.
    // kProEnabled kapalıyken (1.0) proUnlockedProvider herkes için true:
    // kural herkeste çalışır.
    if (isExpense &&
        wallet == null &&
        envelopeId == null &&
        note != null &&
        ref.read(proUnlockedProvider)) {
      final auto = await resolveCategoryFromText(ref, note);
      if (auto != null) {
        envelopeId = auto.id;
        envelopeName = auto.name;
      }
      if (!mounted) return;
    }

    // Hesaplı kayıtta kuru YAZMADAN ÖNCE dondur — yeni gider, yeni gelir ve
    // düzenleme için aynı kural, aynı [_freezeFor]. Düzenlemede para tarafı
    // değişmediyse kayıttaki kur korunur ([_frozenToKeep]); değiştiyse bu
    // yeni bir olgu kaydıdır, bugünün kuruyla yeniden dondurulur. Kur yoksa
    // hiç yazmıyoruz: guardWrite'a girmeden dönüyoruz ki Crashlytics'e
    // "yazma hatası" diye düşmesin — bu bir hata değil, bilinçli ret. Form
    // olduğu gibi kalır.
    ({double baseAmount, String baseCurrency, double rate})? frozen;
    if (accountId != null) {
      frozen =
          _frozenToKeep(
            editing: editing,
            accountId: accountId,
            amount: amount,
            currency: currency,
          ) ??
          await _freezeFor(amount: amount, from: currency);
      if (!mounted) return;
      if (frozen == null) {
        final rs = ref.read(rsProvider);
        showErrorSnack(
          context,
          editing != null
              ? rs.fxFreezeUnavailableEdit
              : isExpense
              ? rs.fxFreezeUnavailable
              : rs.fxFreezeUnavailableIncome,
        );
        setState(() => _saving = false);
        return;
      }
    }

    if (editing != null) {
      // Yerinde güncelle: eski etki geri alınır, yenisi uygulanır (tek parti).
      // Hesap alanları da gider: kart değiştiyse depo eskisine iade edip
      // yenisinden düşer; hesap yoksa (eski kayıt) dördü null, eski yol.
      final ok = await guardWrite(context, str, () async {
        await repo.updateTx(
          editing.id,
          type: isExpense ? TxType.expense : TxType.income,
          amount: amount,
          currency: currency,
          date: date,
          envelopeId: envelopeId,
          envelopeName: envelopeName,
          note: note,
          accountId: accountId,
          baseAmount: frozen?.baseAmount,
          baseCurrency: frozen?.baseCurrency,
          fxRate: frozen?.rate,
        );
      }, reason: 'editTx');
      if (!mounted) return;
      if (!ok) {
        setState(() => _saving = false);
        return;
      }
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
      return;
    }

    String? id;
    final ok = await guardWrite(context, str, () async {
      if (isExpense) {
        id = await repo.addExpense(
          envelopeId: envelopeId,
          envelopeName: envelopeName,
          amount: amount,
          currency: currency,
          note: note,
          date: date,
          // Hesap yoksa dördü de null: depo eski tek-kasa yolunda kalır.
          accountId: account?.id,
          baseAmount: frozen?.baseAmount,
          baseCurrency: frozen?.baseCurrency,
          fxRate: frozen?.rate,
        );
      } else if (wallet == null) {
        id = await repo.addCashIncome(
          amount: amount,
          note: note,
          date: date,
          envelopeId: envelopeId,
          envelopeName: envelopeName,
          // Giderle aynı sözleşme: hesap yoksa hepsi null, eski nakit yolu.
          // Hesap varsa para o karta girer ve kur gelirde de donar.
          currency: currency,
          accountId: account?.id,
          baseAmount: frozen?.baseAmount,
          baseCurrency: frozen?.baseCurrency,
          fxRate: frozen?.rate,
        );
      } else {
        id = await repo.addEnvelopeIncome(
          envelopeId: wallet.id,
          envelopeName: envelopeName!,
          amount: amount,
          currency: currency,
          note: note,
          date: date,
        );
      }
      if (_recurrence != Recurrence.none) {
        await repo.addRecurringRule(
          amount: amount,
          type: isExpense ? 'expense' : 'income',
          currency: currency,
          freq: _recurrence,
          firstDate: _date,
          envelopeId: envelopeId,
          envelopeName: envelopeName,
          note: note,
        );
      }
    }, reason: 'quickEntry');
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    HapticFeedback.lightImpact();
    if (_multi) {
      setState(() {
        _saving = false;
        _savedCount++;
        _lastTxId = id;
        _expr = '';
        _note = '';
        _category = null;
        _recurrence = Recurrence.none;
      });
      return;
    }
    Navigator.of(context).pop(QuickEntryResult(lastTxId: id!, count: 1));
  }

  void _close() {
    if (_isEditing) {
      Navigator.of(context).pop(null);
      return;
    }
    final last = _lastTxId;
    Navigator.of(context).pop(
      last == null
          ? null
          : QuickEntryResult(lastTxId: last, count: _savedCount),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final code = ref.watch(currencyCodeProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final recent = ref.watch(recentTxsProvider).value ?? const <Tx>[];
    final account = _currentAccount(accounts, recent);
    // Tutarın yanındaki simge girilen paranın birimi: manat kartı seçiliyse
    // ₼ görünmeli, yoksa kullanıcı ₺ sanıp yanlış rakam girer.
    final accountCode =
        account?.currency ??
        _wallet?.currency ??
        _editingAccountCurrency ??
        code;
    final symbol = kCurrencies[accountCode] ?? accountCode;
    final canSave = _amount > 0 && !_saving;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Ex.bg,
        body: ExBackground(
          glow: 0.5,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── üst satır ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GlassSquareButton(
                        icon: Icons.close_rounded,
                        onTap: _close,
                      ),
                      const Spacer(),
                      GlassChip(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        onTap: _pickAccount,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currencyFlag(accountCode),
                              style: const TextStyle(fontSize: 21, height: 1),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontSize: 21,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Ex.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isEditing)
                        // Esnek: para birimi çipi 3 harfli kodla (AZN, KZT)
                        // genişleyince ve büyük yazı ölçeğinde rozet yer
                        // açmalı — satır taşacağına rozet kısalır; çip
                        // dokunulabilir olan, rozet yalnız bilgi.
                        Flexible(
                          child: GlassChip(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onTap: () {},
                            child: Flexible(
                              child: Text(
                                rs.editingLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Ex.mint,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        GlassSquareButton(
                          icon: Icons.more_horiz_rounded,
                          onTap: _menu,
                        ),
                    ],
                  ),
                ),

                // ── panel: tutar · tarih/tekrar/not · klavye ────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Ex.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Ex.border),
                      ),
                      child: Column(
                        children: [
                          // Gider / Gelir görünür anahtar: gelir girmek tek
                          // dokunuş olsun diye menüde saklı değil.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                            child: _ModeSwitch(
                              mode: _mode,
                              expense: rs.expense,
                              income: rs.income,
                              onChanged: (m) => setState(() {
                                // Gider ve gelir kümeleri ayrı: seçim sıfırlanır.
                                if (m != _mode) _category = null;
                                _mode = m;
                              }),
                            ),
                          ),
                          // Tutar panelin ortasında durur.
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_multi && _savedCount > 0) ...[
                                    TintChipButton(
                                      label: tpl(rs.savedCountTpl, {
                                        'n': '$_savedCount',
                                      }),
                                      onTap: () {},
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _AmountDisplay(
                                    expr: _expr,
                                    symbol: symbol,
                                    localeCode: str.localeCode,
                                  ),
                                  if (hasOperator(_expr)) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '= ${formatMoneyIn(_amount, accountCode)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Ex.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Hangi karttan / hangi karta? Tek kompakt çip;
                          // gider, gelir ve düzenlemede (bkz. _accountsApply).
                          // Kendi satırında: tarih satırına sıkışsaydı 320dp'de
                          // ad kesilirdi.
                          if (account != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AccountChip(
                                  key: const ValueKey('quick-entry-account'),
                                  account: account,
                                  // Tek hesapta (düzenlenen kaydın kendi
                                  // hesabı) değiştirecek bir şey yok; çip
                                  // yalnız "nereden" bilgisini gösterir.
                                  onTap: accounts.length >= 2
                                      ? () => _pickCard(accounts, account)
                                      : () {},
                                ),
                              ),
                            ),
                          // Tarih solda; tekrar yanında, not en sağda.
                          // Açılışta solup yukarı kayar (tuş takımı değil).
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: Row(
                              children: [
                                Flexible(
                                  child: _MetaChip(
                                    icon: Icons.calendar_today_rounded,
                                    label: _date == _today()
                                        ? rs.today
                                        : DateFormat(
                                            'd MMM',
                                            str.localeCode,
                                          ).format(_date),
                                    active: _date != _today(),
                                    onTap: _pickDate,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Tekrar kuralı düzenlemede yok (kural bu ekrandan değişmez).
                                if (!_isEditing)
                                  _RoundIconButton(
                                    icon: Icons.repeat_rounded,
                                    active: _recurrence != Recurrence.none,
                                    onTap: _pickRecurrence,
                                  ),
                                const Spacer(),
                                _RoundIconButton(
                                  icon: Icons.sticky_note_2_outlined,
                                  active: _note.isNotEmpty,
                                  onTap: _editNote,
                                ),
                              ],
                            ),
                          ).enterUp(context, index: 0, dy: 8),

                          _Keypad(
                            decimal: _decimalFor(str.localeCode),
                            oneTwoThreeOnTop: ref.watch(
                              keypadOneTwoThreeOnTopProvider,
                            ),
                            onKey: _key,
                            onBackspace: _back,
                            onClear: _clear,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── alt satır: kategori + kaydet ────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
                  child: Row(
                    children: [
                      if (_categoryApplies)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _CategoryPill(
                              pick: _category,
                              placeholder: rs.pickCategory,
                              onTap: _pickCategory,
                              onClear: _category == null
                                  ? null
                                  : () => setState(() => _category = null),
                            ).enterUp(context, index: 1, dy: 8),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      // Yükseklik SizedBox ile değil stille veriliyor: Row
                      // esnek olmayan çocuğa sınırsız genişlik verdiği için
                      // SizedBox(height:) sarmalayıcısı düzeni bozuyordu.
                      FilledButton(
                        onPressed: canSave ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Ex.brand,
                          foregroundColor: Ex.onBrand,
                          disabledBackgroundColor: Ex.surfaceHi,
                          disabledForegroundColor: Ex.textFaint,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(rs.save),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _decimalFor(String localeCode) =>
      localeCode == 'tr' || localeCode == 'ru' ? ',' : '.';
}

// ── parçalar ──────────────────────────────────────────────────────────────

/// Panelin alt satırındaki yuvarlak ikon butonu (tekrar, not).
/// Etkinse yeşil tint — bir değer seçilmiş olduğu oradan anlaşılır.
/// Gider / Gelir anahtarı — panelin üstünde, tam genişlikte iki parça.
/// Seçili taraf gelirde nane, giderde açık yüzey; gelir girmek tek dokunuş.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.expense,
    required this.income,
    required this.onChanged,
  });

  final QuickMode mode;
  final String expense;
  final String income;
  final ValueChanged<QuickMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(QuickMode m, String label, IconData icon) {
      final on = m == mode;
      final fill = m == QuickMode.income ? Ex.brand : Ex.surfaceHi;
      final ink = m == QuickMode.income ? Ex.onBrand : Ex.text;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? fill : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: on ? ink : Ex.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: on ? ink : Ex.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Ex.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ex.border),
      ),
      child: Row(
        children: [
          seg(QuickMode.expense, expense, Icons.arrow_upward_rounded),
          seg(QuickMode.income, income, Icons.arrow_downward_rounded),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Ex.brand.withValues(alpha: 0.18) : Ex.surfaceHi,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: active ? Ex.mint : Ex.textSoft),
        ),
      ),
    );
  }
}

/// Büyük tutar: her rakam alttan kayarak gelir (roll-in).
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.expr,
    required this.symbol,
    required this.localeCode,
  });

  final String expr;
  final String symbol;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final decimal = localeCode == 'tr' || localeCode == 'ru' ? ',' : '.';
    final shown = (expr.isEmpty ? '0' : expr).replaceAll('.', decimal);
    final chars = shown.split('');
    // Ekranın para kahramanı: afiş tipografisi — InterDisplay Black, sıkı
    // aralık, dar satır. Onboarding afişindeki rakamlarla aynı ses.
    const style = TextStyle(
      fontFamily: 'InterDisplay',
      fontSize: 56,
      height: 1.0,
      fontWeight: FontWeight.w900,
      letterSpacing: -2.6,
      color: Ex.text,
    );
    // Tutar panelin ortasında (referans ekrandaki gibi).
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Anahtar konum+karakter: yeni eklenen ya da değişen karakter
            // yeni bir _RollInChar olur ve girişini oynatır; yerinde kalan
            // rakamlar durumunu korur, tekrar oynamaz.
            for (final (i, ch) in chars.indexed)
              _RollInChar(
                key: ValueKey('$i:$ch'),
                char: ch,
                style: isOperator(ch)
                    ? style.copyWith(color: Ex.mint, fontSize: 40)
                    : style,
              ),
            const SizedBox(width: 10),
            Text(symbol, style: style.copyWith(color: Ex.onGlowMuted)),
          ],
        ),
      ),
    );
  }
}

/// Etiketli küçük çip (Bugün · Tekrar yok · Not).
/// Tek karakter: ekrana ilk girdiğinde alttan kayarak ve belirerek gelir.
///
/// AnimatedSwitcher yalnız çocuğu DEĞİŞİNCE animasyon yapar; satıra yeni
/// eklenen bir switcher ilk çocuğunu animasyonsuz gösterir. Bu yüzden eskiden
/// sadece ilk rakam ("0"ın yerine geçen) kayıyordu. Burada giriş animasyonu
/// her karakterin kendi initState'inde başlar — her rakam aynı şekilde gelir.
class _RollInChar extends StatefulWidget {
  const _RollInChar({super.key, required this.char, required this.style});

  final String char;
  final TextStyle style;

  @override
  State<_RollInChar> createState() => _RollInCharState();
}

class _RollInCharState extends State<_RollInChar>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(_curve),
        child: Text(widget.char, style: widget.style),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Ex.brand.withValues(alpha: 0.16) : Ex.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? Ex.glassBorder : Ex.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: active ? Ex.mint : Ex.textMuted),
              const SizedBox(width: 6),
              // Esnek: çip dar bir alana konduğunda metin kısalır.
              // Sabit genişlik (maxWidth) taşmaya yol açıyordu.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Ex.mint : Ex.textSoft,
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

/// Seçili kategori / "Kategori seç" pill'i.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.pick,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final CategoryPick? pick;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = pick;
    return Material(
      color: p == null ? Ex.surface : Ex.brand.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: EdgeInsets.fromLTRB(
            p == null ? 12 : 8,
            0,
            p == null ? 12 : 4,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p == null ? Ex.border : Ex.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p == null)
                const Icon(
                  Icons.grid_view_rounded,
                  size: 15,
                  color: Ex.textMuted,
                )
              else
                CategoryAvatar(
                  catalogKey: p.catalogKey,
                  emoji: p.emoji,
                  tintSeed: p.id,
                  size: 22,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  p?.name ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p == null ? Ex.textSoft : Ex.mint,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Ex.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hesap makinesi klavyesi: köşeleri yumuşak kare tuşlar, operatörler nane.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.decimal,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    this.oneTwoThreeOnTop = false,
  });

  final String decimal;

  /// Ayarlar → Tuş takımı düzeni: 1-2-3 üstte (telefon) / altta (hesap mak.).
  final bool oneTwoThreeOnTop;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rows = oneTwoThreeOnTop
        ? [
            ['1', '2', '3', '÷'],
            ['4', '5', '6', '×'],
            ['7', '8', '9', '−'],
            [decimal, '0', '⌫', '+'],
          ]
        : [
            ['7', '8', '9', '÷'],
            ['4', '5', '6', '×'],
            ['1', '2', '3', '−'],
            [decimal, '0', '⌫', '+'],
          ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final (i, k) in row.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Key(
                        label: k,
                        operator: isOperator(k),
                        onTap: k == '⌫'
                            ? onBackspace
                            : () => onKey(k == decimal ? '.' : k),
                        onLongPress: k == '⌫' ? onClear : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.operator,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool operator;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: operator ? Ex.brand.withValues(alpha: 0.14) : Ex.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ex.iconRadius),
        side: BorderSide(color: operator ? Ex.glassBorder : Ex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 50,
          child: Center(
            child: label == '⌫'
                ? const Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: Ex.textSoft,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: operator ? 24 : 22,
                      fontWeight: FontWeight.w700,
                      color: operator ? Ex.mint : Ex.text,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Alt sayfa satırı: ikon (isteğe bağlı) + etiket + seçili tik.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? Ex.mint : Ex.textMuted),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? Ex.mint : Ex.text,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 20, color: Ex.mint),
          ],
        ),
      ),
    );
  }
}

/// Not sayfası: klavye üstünde tek alan; #etiketler nane renkte.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({
    required this.initial,
    required this.hint,
    required this.title,
  });

  final String initial;
  final String hint;
  final String title;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final _ctrl = _TagController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v),
            style: const TextStyle(color: Ex.text, fontSize: 16),
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: MaterialLocalizations.of(context).okButtonLabel,
            onTap: () => Navigator.of(context).pop(_ctrl.text),
          ),
        ],
      ),
    );
  }
}

/// "#etiket" parçalarını nane renkte boyar; metin düz kalır.
class _TagController extends TextEditingController {
  _TagController({super.text});

  static final _tag = RegExp(r'#[\p{L}\p{N}_]+', unicode: true);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _tag.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(color: Ex.mint, fontWeight: FontWeight.w700),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}

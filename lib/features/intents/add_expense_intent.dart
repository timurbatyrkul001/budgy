import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// [ProviderListenable] ana kütüphaneden değil misc'ten dışa açılıyor.
import 'package:flutter_riverpod/misc.dart';

import '../../core/category_rules.dart';
import '../../core/category_visual.dart';
import '../../core/formatters.dart';
import '../../core/fx.dart';
import '../../core/fx_freeze.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../accounts/account.dart';
import '../accounts/account_suggestion.dart';
import '../accounts/accounts_repository.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../home/fx_providers.dart';
import '../pro/pro_state.dart';
import '../settings/category_resolver.dart';
import '../transactions/tx.dart';

/// Natif taraftan (`addExpense`) gelen istek — kanal sözleşmesinin Dart
/// karşılığı. Sözleşme `IntentBridge.swift` ile ortak ve DEĞİŞMEZ:
///
/// * `amount` (double, zorunlu, > 0)
/// * `note` (String?, mağaza adı / yorum)
/// * `categoryName` (String?)
/// * `accountName` (String?)
/// * `source` (String, zorunlu: `siri` | `shortcut`)
class AddExpenseIntentRequest {
  const AddExpenseIntentRequest({
    required this.amount,
    required this.source,
    this.note,
    this.categoryName,
    this.accountName,
  });

  final double amount;
  final String source;
  final String? note;
  final String? categoryName;
  final String? accountName;

  static const sources = {'siri', 'shortcut'};

  /// Kanal argümanını ayrıştırır; biçim bozuksa null. Tutarın işareti
  /// burada DENETLENMEZ — o ayrı bir kullanıcı mesajı ister (bkz.
  /// [AddExpenseIntentHandler.handle]); burası yalnız "okunabildi mi".
  static AddExpenseIntentRequest? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final amount = raw['amount'];
    if (amount is! num) return null;
    final source = raw['source'];
    if (source is! String || !sources.contains(source)) return null;
    return AddExpenseIntentRequest(
      amount: amount.toDouble(),
      source: source,
      note: _clean(raw['note']),
      categoryName: _clean(raw['categoryName']),
      accountName: _clean(raw['accountName']),
    );
  }

  /// Boş/boşluk metin null sayılır: Kısayollar boş alanı "" gönderebilir.
  static String? _clean(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}

/// Natife dönen cevap: `{"ok": bool, "message": String}`. [message] her
/// iki durumda da kullanıcıya gösterilecek HAZIR metin (uygulama dilinde);
/// `ok: false` iken neyin olmadığını söyler, "hata" demez.
class IntentReply {
  const IntentReply.ok(this.message) : ok = true;
  const IntentReply.fail(this.message) : ok = false;

  final bool ok;
  final String message;

  Map<String, Object?> toMap() => {'ok': ok, 'message': message};
}

/// Kısayollar/Siri'den gelen "harcama ekle" isteğini hızlı girişle AYNI
/// yoldan yazar: aynı depo metodu ([BudgetRepository.addExpense]), aynı
/// hesap kuralları, aynı kur dondurma. Ekran yok; kullanıcıya dönen tek şey
/// [IntentReply.message].
///
/// İlkeler:
/// * **Sessiz tahmin yok.** Kategori/hesap adı tutmadıysa kayıt yine
///   yapılır (kategorisiz / varsayılan hesaba) ama mesaj bunu açıkça söyler.
/// * **Kur yoksa yazma yok.** Yabancı birimli hesapta kur dondurulamıyorsa
///   `ok: false` + [RS.fxFreezeUnavailable]; uydurma kurla kayıt YASAK
///   (bkz. `fx_freeze.dart`).
/// * **Veri gelmeden karar yok.** Soğuk başlatmada zarf/hesap akışları
///   henüz boş olabilir; ilk değerleri bekleriz ki "kategori bulunamadı"
///   demek yerine gerçekten bakmış olalım.
class AddExpenseIntentHandler {
  AddExpenseIntentHandler(this.ref);

  /// `WidgetRef`: [categoryResolverSync] ve [resolveCategoryFromText] bunu
  /// istiyor; host zaten bir widget (bkz. intent_channel.dart).
  final WidgetRef ref;

  /// Akışların ilk değerini bu kadar bekleriz; gelmezse eldeki (muhtemelen
  /// boş) değerle devam. Firestore önbellekten anında yayar, bu sınır yalnız
  /// "önbellek yok + çevrimdışı" gibi uçlar için.
  static const _dataTimeout = Duration(seconds: 10);

  /// `guardWrite` ile aynı eşik (core/feedback.dart): Firestore çevrimdışı
  /// yazmayı sunucu onayına kadar bekletir; kayıt yerel kuyrukta güvende,
  /// kullanıcıyı bekletmeyiz.
  static const _writeAckTimeout = Duration(seconds: 4);

  Future<Map<String, Object?>> handle(Object? rawArgs) async {
    // Dil ayarı da bir akıştır: soğuk başlatmada henüz gelmemişse cevap
    // İngilizce çıkardı. Önce dili bekle, sonra metin seç.
    await _first(languageProvider, languageProvider.future, AppLanguage.en);
    final rs = ref.read(rsProvider);
    final req = AddExpenseIntentRequest.tryParse(rawArgs);
    if (req == null) return IntentReply.fail(rs.intentBadRequest).toMap();
    if (!req.amount.isFinite || req.amount <= 0) {
      return IntentReply.fail(rs.intentInvalidAmount).toMap();
    }
    final reply = await _record(req, rs);
    return reply.toMap();
  }

  Future<IntentReply> _record(AddExpenseIntentRequest req, RS rs) async {
    final str = ref.read(strProvider);
    final repo = ref.read(budgetRepositoryProvider);

    // Soğuk başlatma: akışlar ilk değerini vermeden listeler boş görünür.
    final envelopes = await _first(
      envelopesProvider,
      envelopesProvider.future,
      const <Envelope>[],
    );
    final accountsRaw = await _first(
      accountsProvider,
      accountsProvider.future,
      const <Account>[],
    );
    final recent = await _first(
      recentTxsProvider,
      recentTxsProvider.future,
      const <Tx>[],
    );
    await _first(currencyProvider, currencyProvider.future, 'TRY');
    final main = ref.read(currencyCodeProvider);
    // Nakit TANIM GEREĞİ ana birimde (hızlı girişle aynı garanti).
    final accounts = [for (final a in accountsRaw) a.withMainCurrency(main)];

    // ── kategori ──────────────────────────────────────────────────────────
    ({String id, String name})? category;
    var categoryMissed = false;
    if (req.categoryName != null) {
      category = _matchCategory(req.categoryName!, envelopes, str);
      categoryMissed = category == null;
    }
    // Ad verilmedi ya da tutmadı: nottaki anahtar kelimeler seçsin — hızlı
    // girişle aynı otomasyon, aynı Pro kapısı. Kullanıcının verdiği ad
    // tutmuşsa buraya girilmez, seçimi ezilmez.
    if (category == null &&
        req.note != null &&
        ref.read(proUnlockedProvider)) {
      category = await resolveCategoryFromText(ref, req.note!);
    }

    // ── hesap ─────────────────────────────────────────────────────────────
    // Hızlı girişteki `_accountsApply` kuralı: iki hesaptan azı varsa hesap
    // kavramı devrede değil, eski tek-kasa yolu (depo yeni alanları görmez).
    final accountsApply = accounts.length >= 2;
    Account? account;
    var accountMissed = false;
    if (req.accountName != null) {
      final matched = _matchAccount(req.accountName!, accounts, rs);
      accountMissed = matched == null;
      if (matched != null && accountsApply) account = matched;
    }
    if (account == null && accountsApply) {
      // Ad yok ya da tutmadı: kategori + geçmişe göre öneri — formun da
      // önceden seçtiği hesap. Kullanıcı mesajdan hangisi olduğunu görür.
      final id = suggestAccount(
        accounts: accounts,
        recent: recent,
        categoryId: category?.id,
      );
      account = accounts.where((a) => a.id == id).firstOrNull;
    }

    // İşlemin birimi seçili hesabın birimi; hesap yolu kapalıysa eski kural:
    // ana cüzdan kodu (bkz. Tx.legacyMainCode).
    final currency = account?.currency ?? 'TRY';
    // Gösterimde ise gerçek birim: eski yolda tutar ana birimdedir.
    final shownCurrency = account?.currency ?? main;

    // ── kur: yazmadan ÖNCE dondur ─────────────────────────────────────────
    ({double baseAmount, double rate})? frozen;
    if (account != null) {
      frozen = await _freeze(amount: req.amount, from: currency, to: main);
      if (frozen == null) return IntentReply.fail(rs.fxFreezeUnavailable);
    }

    // ── yaz ───────────────────────────────────────────────────────────────
    var offline = false;
    try {
      await repo
          .addExpense(
            envelopeId: category?.id,
            envelopeName: category?.name,
            amount: req.amount,
            currency: currency,
            note: req.note,
            date: DateTime.now(),
            accountId: account?.id,
            baseAmount: frozen?.baseAmount,
            baseCurrency: frozen == null ? null : main,
            fxRate: frozen?.rate,
          )
          .timeout(_writeAckTimeout);
    } on TimeoutException {
      // Başarısızlık değil: kayıt yerel kuyrukta, ağ gelince gider.
      offline = true;
    } catch (error, stack) {
      _report(error, stack);
      return IntentReply.fail(str.errorSaveFailed);
    }

    // ── cevap ─────────────────────────────────────────────────────────────
    // Tablo dışı birimde (`kCurrencies`) `formatMoneyIn` ana simgeye düşer;
    // sesli okunan bir cevapta "12 ₺" yerine "12 AZN" doğru olan.
    final amountText = kCurrencies.containsKey(shownCurrency)
        ? formatMoneyIn(req.amount, shownCurrency)
        : '${formatNumber(req.amount)} $shownCurrency';
    final parts = <String>[
      category == null
          ? tpl(rs.intentSavedNoCategoryTpl, {'amount': amountText})
          : tpl(rs.intentSavedTpl, {
              'amount': amountText,
              'category': category.name,
            }),
      if (categoryMissed)
        tpl(rs.intentCategoryMissTpl, {'name': req.categoryName!}),
      if (accountMissed)
        tpl(rs.intentAccountMissTpl, {
          'name': req.accountName!,
          'account':
              account == null ? rs.cash : _accountLabel(account, rs),
        }),
      if (offline) str.savedOffline,
    ];
    return IntentReply.ok(parts.join(' '));
  }

  /// Akışın ilk değeri; zaten gelmişse anında, hiç gelmezse [fallback].
  ///
  /// Riverpod 3'te DİNLEYİCİSİ OLMAYAN sağlayıcı veri üretmez: `ref.read`
  /// onu kurar ama `AsyncLoading`'de bırakır, `.future` da hiç dolmaz. UI
  /// zaten izliyorsa sorun yok; soğuk başlatmada henüz kimse izlemiyor
  /// olabilir (ör. hesap listesi ana ekran kurulana kadar). Bekleme boyunca
  /// geçici bir dinleyici tutup sonra kapatıyoruz.
  Future<T> _first<T>(
    ProviderListenable<AsyncValue<T>> provider,
    ProviderListenable<Future<T>> future,
    T fallback,
  ) async {
    final sub = ref.listenManual(provider, (_, _) {});
    try {
      return await ref.read(future).timeout(_dataTimeout);
    } catch (_) {
      return ref.read(provider).value ?? fallback;
    } finally {
      sub.close();
    }
  }

  /// Ada göre kategori: önce zarf adıyla (gösterilen ad ya da ham ad, büyük/
  /// küçük harf ve Türkçe karakter duyarsız) tam eşleşme; yoksa otomasyon
  /// kuralları ("market" → Gıda) — yalnız VAR OLAN zarflara, yaratmaz.
  /// Hedefler ve gelir etiketleri harcama kategorisi değildir, elenir.
  ({String id, String name})? _matchCategory(
    String name,
    List<Envelope> envelopes,
    Strings str,
  ) {
    final wanted = normalizeText(name);
    if (wanted.isEmpty) return null;
    for (final e in envelopes) {
      if (e.archived || e.isGoal || isIncomeEnvelope(e)) continue;
      final shown = e.displayName(str);
      if (normalizeText(shown) == wanted || normalizeText(e.name) == wanted) {
        return (id: e.id, name: shown);
      }
    }
    return categoryResolverSync(ref)(name);
  }

  /// Ada göre hesap (büyük/küçük harf ve Türkçe karakter duyarsız). Adsız
  /// nakit hesabı uygulamada [RS.cash] etiketiyle görünür; kullanıcı onu
  /// söylerse o da tutar.
  Account? _matchAccount(String name, List<Account> accounts, RS rs) {
    final wanted = normalizeText(name);
    if (wanted.isEmpty) return null;
    for (final a in accounts) {
      if (a.archived) continue;
      if (normalizeText(_accountLabel(a, rs)) == wanted) return a;
    }
    return null;
  }

  static String _accountLabel(Account a, RS rs) =>
      a.name.trim().isEmpty && a.isCash ? rs.cash : a.name;

  /// Hızlı girişteki `_freezeFor` ile aynı: aynı birimde ağa çıkılmaz; kur
  /// tablosu `.future` ile beklenir ("yüklenmedi" ≠ "kur yok"); tablo yok
  /// ya da çift yoksa null → çağıran YAZMAZ.
  Future<({double baseAmount, double rate})?> _freeze({
    required double amount,
    required String from,
    required String to,
  }) async {
    try {
      final fx = from == to
          ? FxSnapshot(base: to, rates: const {}, fetchedAt: DateTime.now())
          : await _first(
              fxSnapshotProvider(to),
              fxSnapshotProvider(to).future,
              null,
            );
      if (fx == null) return null;
      return freezeToBase(amount: amount, from: from, to: to, fx: fx);
    } on FxUnavailable {
      return null;
    } catch (_) {
      // Kur yükleyicisinin beklenmedik hatası da "kur yok" demektir.
      return null;
    }
  }

  /// Yazma hatasını rapora düşür; Crashlytics kurulu değilse (test) sessiz.
  static void _report(Object error, StackTrace stack) {
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'intentAddExpense',
          fatal: false,
        ),
      );
    } catch (_) {
      debugPrint('intentAddExpense: $error');
    }
  }
}

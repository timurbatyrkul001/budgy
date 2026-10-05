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
/// * **Dayanak yoksa yazma yok.** Hesap listesi, ana birim ya da (kategori
///   istenmişse) kategori listesi gelmediyse — akış DÜŞTÜ ya da
///   [dataTimeout] içinde ilk değerini vermedi — `ok: false` ile ret.
///   Eskiden `?? []` / `?? 'TRY'` boşluğu dolduruyor ve kayıt yine
///   yazılıyordu: iki kartlı kullanıcının harcaması nakitten, tenge
///   kullanıcısınınki ₺'ye dondurulmuş. Ekranda bunu gören bir şerit var;
///   burada ekran yok — Siri "kaydettim" derdi ve kimse fark etmezdi.
///   "Yükleniyor" ile "düştü" AYRI: ilki beklenir (soğuk başlatma olağan),
///   ikincisinde beklemek anlamsız, reddedilir. Hızlı girişle aynı kural
///   (`_sourcesReady`), ana birim için aynı kaynak
///   ([knownCurrencyCodeProvider]). Yeni kullanıcının BOŞ hesap listesi ve
///   varsayılan ₺'si birer değerdir, hata değil — eski tek-kasa yolu onlar
///   için aynen çalışır.
class AddExpenseIntentHandler {
  AddExpenseIntentHandler(this.ref, {this.dataTimeout = _defaultDataTimeout});

  /// `WidgetRef`: [categoryResolverSync] ve [resolveCategoryFromText] bunu
  /// istiyor; host zaten bir widget (bkz. intent_channel.dart).
  final WidgetRef ref;

  /// Akışların ilk değerini bu kadar bekleriz. Dayanak akışları (hesap, ana
  /// birim, kategori) bu sürede gelmezse kayıt REDDEDİLİR; yardımcı akışlar
  /// (dil, geçmiş) eldeki değerle devam eder. Firestore önbellekten anında
  /// yayar, bu sınır yalnız "önbellek yok + çevrimdışı" gibi uçlar için.
  /// Akışlar aynı anda beklenir, dolayısıyla toplam bekleme de bu kadar —
  /// natif köprü 20 sn'de vazgeçiyor (`IntentBridge.addExpense`), cevabımız
  /// ondan önce varmalı ki kullanıcı bizim metnimizi duysun.
  /// Testler kısaltabilir ([dataTimeout]).
  static const _defaultDataTimeout = Duration(seconds: 10);
  final Duration dataTimeout;

  /// `guardWrite` ile aynı eşik (core/feedback.dart): Firestore çevrimdışı
  /// yazmayı sunucu onayına kadar bekletir; kayıt yerel kuyrukta güvende,
  /// kullanıcıyı bekletmeyiz.
  static const _writeAckTimeout = Duration(seconds: 4);

  Future<Map<String, Object?>> handle(Object? rawArgs) async {
    final req = AddExpenseIntentRequest.tryParse(rawArgs);
    final valid = req != null && req.amount.isFinite && req.amount > 0;
    // Dil ayarı da bir akıştır: soğuk başlatmada henüz gelmemişse cevap
    // İngilizce çıkardı. Dil ile dayanak akışları AYNI ANDA beklenir —
    // ardışık bekleseydik zaman aşımları toplanır, natif köprü bizden önce
    // vazgeçer ve kullanıcı bizim metnimizi değil onun genel metnini duyardı.
    // Dil düşerse İngilizce: bu bir mesaj dili, kaydın dayanağı değil.
    final language = _first(languageProvider, AppLanguage.en);
    final sources = valid ? _loadSources(req) : null;
    await language;
    final rs = ref.read(rsProvider);
    if (req == null) return IntentReply.fail(rs.intentBadRequest).toMap();
    if (!valid) return IntentReply.fail(rs.intentInvalidAmount).toMap();
    final reply = await _record(req, await sources!, rs);
    return reply.toMap();
  }

  /// Kaydın dayanaklarını ve yardımcı akışları birlikte bekler. Dayanaklar
  /// null gelebilir — "düştü ya da gelmedi" demektir, çağıran o zaman
  /// YAZMAZ. Kategori listesi yalnız kategori kullanılacaksa dayanaktır
  /// (ad verilmiş ya da nottan otomasyon çalışacak); yoksa hiç beklenmez —
  /// sade "250 lira harcadım" kategoriler yüzünden reddedilmesin.
  Future<_Sources> _loadSources(AddExpenseIntentRequest req) async {
    final wantsCategory = req.categoryName != null ||
        (req.note != null && ref.read(proUnlockedProvider));
    final (accounts, _, envelopes, recent) = await (
      _known(accountsProvider),
      _settle(currencyProvider),
      wantsCategory
          ? _known(envelopesProvider)
          : Future<List<Envelope>?>.value(const <Envelope>[]),
      // Geçmiş yalnız hesap ÖNERİSİNİN sinyali; gelmezse öneri "listedeki
      // ilk hesap"a düşer — hızlı giriş de böyle (`.value ?? []`). Dayanak
      // değil: seçilen hesap yine gerçek listeden çıkar.
      _first(recentTxsProvider, const <Tx>[]),
    ).wait;
    return _Sources(
      accounts: accounts,
      // Ana birim yazan tarafların ortak kaynağından: yüklenmediyse ya da
      // düştüyse (önbellekten eski değer taşısa bile) null.
      main: ref.read(knownCurrencyCodeProvider),
      envelopes: envelopes,
      recent: recent,
    );
  }

  Future<IntentReply> _record(
    AddExpenseIntentRequest req,
    _Sources sources,
    RS rs,
  ) async {
    final str = ref.read(strProvider);
    final repo = ref.read(budgetRepositoryProvider);

    // ── dayanaklar: biri yoksa YAZMA ─────────────────────────────────────
    // Sıra: önce hesap, sonra birim, sonra kategori — kullanıcı tek bir
    // neden duyar, en temel olanı.
    final accountsRaw = sources.accounts;
    if (accountsRaw == null) {
      return IntentReply.fail(rs.intentAccountsUnavailable);
    }
    final main = sources.main;
    if (main == null) return IntentReply.fail(rs.intentCurrencyUnavailable);
    final envelopes = sources.envelopes;
    if (envelopes == null) {
      return IntentReply.fail(rs.intentCategoriesUnavailable);
    }
    final recent = sources.recent;
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
    // ana cüzdan kodu. Bu bir birim VARSAYIMI değil, "tutar ana birimde"
    // anlamına gelen sabit işaret (bkz. Tx.legacyMainCode / Tx.baseOr) —
    // yeni kullanıcı için de aynı yol, aynı değer.
    final currency = account?.currency ?? Tx.legacyMainCode;
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

  /// Akışın "yüklendi ya da düştü" dediği İLK durumu; [dataTimeout] içinde
  /// ikisi de olmazsa o anki (hâlâ yükleniyor) durum. Karar vermez,
  /// çağıran durumun `hasValue` / `hasError`'ına bakar.
  ///
  /// Neden `.future` değil: Riverpod 3 düşen akışı kendisi yeniden dener
  /// (200 ms'den 6,4 sn'ye katlanan aralıklarla, 10 kez — toplam ~40 sn) ve
  /// bu süre boyunca durum `AsyncError` değil, hatası dolu bir
  /// `AsyncLoading`dır (`hasError` doğru, `retrying`); `.future` o süre
  /// boyunca DOLMAZ. Onu bekleseydik "düştü" ancak zaman aşımında anlaşılır,
  /// kullanıcı reddi 10 sn sonra duyardı. Durumu dinleyince düşme anında
  /// görülür: Firestore'un akış hataları (yetki, oturum) yeniden denemeyle
  /// geçmez, beklemenin anlamı yok. "Yükleniyor" ise beklenir — soğuk
  /// başlatmada olağan.
  ///
  /// Riverpod 3'te DİNLEYİCİSİ OLMAYAN sağlayıcı veri üretmez: `ref.read`
  /// onu kurar ama `AsyncLoading`'de bırakır. UI zaten izliyorsa sorun yok;
  /// soğuk başlatmada henüz kimse izlemiyor olabilir (ör. hesap listesi ana
  /// ekran kurulana kadar). Bekleme boyunca geçici bir dinleyici tutup
  /// sonra kapatıyoruz.
  Future<AsyncValue<T>> _settle<T>(
    ProviderListenable<AsyncValue<T>> provider,
  ) async {
    final done = Completer<AsyncValue<T>>();
    final sub = ref.listenManual<AsyncValue<T>>(
      provider,
      (_, next) {
        if (!done.isCompleted && (next.hasValue || next.hasError)) {
          done.complete(next);
        }
      },
      fireImmediately: true,
    );
    final deadline = Timer(dataTimeout, () {
      if (!done.isCompleted) done.complete(ref.read(provider));
    });
    try {
      return await done.future;
    } finally {
      deadline.cancel();
      sub.close();
    }
  }

  /// DAYANAK akışları için — [_settle] + hızlı girişin `_ready` kuralı:
  /// değer yalnız GERÇEKTEN geldiyse; düştüyse (önbellekten eski değer
  /// taşısa bile) ya da süresinde gelmediyse null → çağıran YAZMAZ. Boş
  /// liste bir değerdir — yeni kullanıcı buradan geçer.
  Future<T?> _known<T>(ProviderListenable<AsyncValue<T>> provider) async {
    final state = await _settle(provider);
    if (state.hasError || !state.hasValue) return null;
    return state.requireValue;
  }

  /// YARDIMCI akışlar için (dil, geçmiş, kur tablosu): ilk değer; düşmüşse
  /// ya da süresinde gelmezse eldeki değer, o da yoksa [fallback]. Kaydın
  /// dayanakları için DEĞİL — onlar [_known] ile beklenir ve boşluk
  /// doldurmaz.
  Future<T> _first<T>(
    ProviderListenable<AsyncValue<T>> provider,
    T fallback,
  ) async {
    final state = await _settle(provider);
    return state.value ?? fallback;
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
          : await _first(fxSnapshotProvider(to), null);
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

/// [AddExpenseIntentHandler._loadSources] sonucu. null alan = o dayanak
/// yok (akış düştü ya da süresinde gelmedi) → kayıt yazılmaz. [recent]
/// dayanak değil, boş gelebilir.
class _Sources {
  const _Sources({
    required this.accounts,
    required this.main,
    required this.envelopes,
    required this.recent,
  });

  final List<Account>? accounts;
  final String? main;
  final List<Envelope>? envelopes;
  final List<Tx> recent;
}

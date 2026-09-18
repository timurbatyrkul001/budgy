import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../auth/auth_gate.dart';
import '../recurring/recurring.dart';
import '../transactions/tx.dart';
import 'envelope.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(
    FirebaseFirestore.instance,
    ref.watch(uidProvider),
  );
});

/// Поток конвертов, отсортированных по порядку.
final envelopesProvider = StreamProvider<List<Envelope>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchEnvelopes();
});

/// Ana ekranda görünen zarflar: arşivlenmemiş, hedef olmayan.
final activeEnvelopesProvider = Provider<List<Envelope>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  return envelopes.where((e) => !e.archived && !e.isGoal).toList();
});

/// ₺ gelirin dağıtılabileceği zarflar: aktif + para birimi TRY.
/// Döviz zarfına ₺ yazmak bakiyeyi bozar, hedefler ayrı kumbara.
final allocatableEnvelopesProvider = Provider<List<Envelope>>((ref) {
  return ref
      .watch(activeEnvelopesProvider)
      .where((e) => e.currency == 'TRY')
      .toList();
});

/// Cüzdan bakiyesi — "Cepte kalan"ın TEK kaynağı (accounts/cash).
final cashBalanceProvider = StreamProvider<double>((ref) {
  return ref.watch(budgetRepositoryProvider).watchCashBalance();
});

/// Eski modelden cüzdana tek seferlik göç. RootScreen'e girmeden tamamlanır
/// ki ana ekran hiç yanlış bakiye göstermesin.
final walletMigrationProvider = FutureProvider<void>((ref) {
  return ref.watch(budgetRepositoryProvider).migrateToWallet();
});

/// Yabancı para birimi bazında toplamlar: {'USD': 120, 'EUR': 30}.
final foreignTotalsProvider = Provider<Map<String, double>>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  final totals = <String, double>{};
  for (final e in envelopes
      .where((e) => e.currency != 'TRY' && !e.archived && !e.isGoal)) {
    totals[e.currency] = (totals[e.currency] ?? 0) + e.balance;
  }
  return totals;
});

/// Показан ли онбординг (выбор стартовых конвертов).
final onboardingDoneProvider = StreamProvider<bool>((ref) {
  return ref.watch(budgetRepositoryProvider).watchOnboardingDone();
});

/// Код валюты из настроек ('TRY', 'USD'...). До входа — TRY.
final currencyProvider = StreamProvider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value('TRY');
  return ref.watch(budgetRepositoryProvider).watchCurrency();
});

/// Seçili tema modu (Ayarlar → Görünüm). Girişten önce sistem.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(ThemeMode.system);
  return ref.watch(budgetRepositoryProvider).watchThemeMode();
});

ThemeMode _themeModeFromCode(String? code) => switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Символ валюты. Побочно обновляет глобальный [currencySymbol],
/// которым пользуется formatMoney по всему приложению.
final currencySymbolProvider = Provider<String>((ref) {
  final code = ref.watch(currencyProvider).value ?? 'TRY';
  final symbol = kCurrencies[code] ?? '₺';
  currencySymbol = symbol;
  return symbol;
});

/// Profil bilgileri (isim, foto, telefon...). Girişten önce boş.
final profileProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const {});
  return ref.watch(budgetRepositoryProvider).watchProfile();
});

/// Face ID / parmak izi kilidi açık mı? (settings/main → biometric)
final biometricEnabledProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).value?['biometric'] == true;
});

/// Журнал: последние операции, новые сверху. Ana ekrandaki "son işlemler"
/// için — kısa liste. Hesaplamalarda KULLANMA: [limit] yüzünden eksik olur,
/// bunun yerine tarih aralıklı [recentTxsProvider] / [monthTxsProvider].
final journalProvider = StreamProvider<List<Tx>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchTransactions();
});

/// Tekrarlayan işlem kuralları (yönetim ekranı).
final recurringRulesProvider = StreamProvider<List<RecurringRule>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchRecurringRules();
});

/// Açılışta vadesi gelen tekrarları işler — RootScreen bir kez izler.
final recurringMaterializerProvider = FutureProvider<int>((ref) {
  return ref.watch(budgetRepositoryProvider).materializeRecurring();
});

/// Geçmiş ekranı (arama + filtre) için daha geniş pencere.
final journalFullProvider = StreamProvider<List<Tx>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchTransactions(limit: 1000);
});

/// Belirli bir ayın işlemleri. Anahtar '2026-06' biçiminde.
final monthTxsProvider =
    StreamProvider.family<List<Tx>, String>((ref, monthKey) {
  final start = DateTime.parse('$monthKey-01');
  final end = DateTime(start.year, start.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});

/// Son 6 ayın işlemleri — tüm ay bazlı hesapların TEK kaynağı.
/// Adet limiti yok: tarih aralığıyla sınırlı, bu yüzden "bu ay harcanan"
/// gibi toplamlar işlem sayısı arttıkça sessizce yanlışlanmaz.
final recentTxsProvider = StreamProvider<List<Tx>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5);
  final end = DateTime(now.year, now.month + 1);
  return ref.watch(budgetRepositoryProvider).watchTxsBetween(start, end);
});

/// Bu ayın işlemleri — [recentTxsProvider]'dan türer (ekstra dinleyici yok).
final currentMonthTxsProvider = Provider<List<Tx>>((ref) {
  final txs = ref.watch(recentTxsProvider).value ?? const [];
  final now = DateTime.now();
  return txs
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .toList();
});

/// Операции одного конверта.
final envelopeTxsProvider =
    StreamProvider.family<List<Tx>, String>((ref, envelopeId) {
  return ref
      .watch(budgetRepositoryProvider)
      .watchTransactions(envelopeId: envelopeId);
});

/// Bu ayki zarf-bazlı ₺ harcama: envelopeId -> toplam.
/// Döviz çevrimi, hedefe para ayırma ve TRY-dışı işlemler hariç — zarf kartı
/// "bu ay harcanan"ı ve bütçe/tempo hesapları bunun üstünde çalışır.
final monthlySpentByEnvelopeProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(currentMonthTxsProvider);
  final map = <String, double>{};
  for (final t in txs) {
    if (t.type != TxType.expense || t.isConvert || t.isGoalFund) continue;
    if (t.currency != 'TRY') continue;
    final id = t.envelopeId;
    if (id == null) continue;
    map[id] = (map[id] ?? 0) + t.amount;
  }
  return map;
});

/// Все данные лежат под users/{uid}/... — у каждого пользователя свой кошелёк.
///
/// **Cüzdan modeli (2026-09 pivotu):** para tek bir kasada — `accounts/cash`
/// belgesinde saklanan gerçek bakiye — yaşar. Gelir doğrudan cüzdana girer,
/// gider cüzdandan çıkar; zarflar artık para TUTMAZ, harcama anında seçilen
/// kategori + aylık bütçe limitidir. İstisnalar bakiye tutmaya devam eder:
/// birikim hedefleri (goal) ve döviz zarfları — onlar kumbara.
class BudgetRepository {
  BudgetRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  /// Uzantılar (ör. kategori otomasyonu) için: aynı kullanıcı ağacı.
  FirebaseFirestore get db => _db;
  String get uid => _uid;

  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _db.collection('users').doc(_uid).collection('envelopes');

  /// Cüzdan: kullanıcının nakit kasası. Tek hesap — ileride banka/kart gibi
  /// hesaplar eklenirse bu koleksiyon genişler.
  DocumentReference<Map<String, dynamic>> get _cash =>
      _db.collection('users').doc(_uid).collection('accounts').doc('cash');

  /// Cüzdan bakiyesini [batch] içinde değiştirir. `set+merge`: belge henüz
  /// yoksa da çalışır (increment eksik belgede alanı delta ile başlatır).
  void _cashDelta(WriteBatch batch, double delta) {
    if (delta == 0) return;
    batch.set(_cash, {'balance': FieldValue.increment(delta)},
        SetOptions(merge: true));
  }

  Stream<double> watchCashBalance() => _cash.snapshots().map(
      (doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0);

  /// Eski "türetilmiş cep" modelinden cüzdan modeline TEK SEFERLİK geçiş.
  ///
  /// `accounts/cash` yoksa eski formülle hesaplar ve yazar:
  /// ₺ zarf bakiyeleri + dağıtılmamış gün kazançları + dağıtılmamış serbest
  /// gelir − dağıtılmamış serbest gider. Serbest kayıtlar `allocated:true`
  /// işaretlenir ki bir daha sayılmasınlar. Çalışma günleri işaretlenmez:
  /// yeni kural (bkz. WorkDaysRepository.setDay) her günün mevcut tutarını
  /// "zaten sayılmış" kabul edip yalnız FARKI uygular — bu, göç öncesi ve
  /// sonrası günler için aynı şekilde doğrudur.
  Future<void> migrateToWallet() async {
    final cashSnap = await _cash.get();
    if (cashSnap.exists) return;

    var balance = 0.0;

    final envs = await _envelopes.get();
    for (final doc in envs.docs) {
      final d = doc.data();
      if ((d['currency'] as String? ?? 'TRY') != 'TRY') continue;
      if (d['goal'] == true) continue;
      balance += (d['balance'] as num?)?.toDouble() ?? 0;
    }

    final workDays =
        await _db.collection('users').doc(_uid).collection('workDays').get();
    for (final doc in workDays.docs) {
      if (doc.data()['allocated'] == true) continue;
      balance += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }

    final batch = _db.batch();
    final freeTxs = await _txs.where('free', isEqualTo: true).get();
    for (final doc in freeTxs.docs) {
      final d = doc.data();
      if (d['allocated'] == true) continue;
      final amount = (d['amount'] as num?)?.toDouble() ?? 0;
      balance += d['type'] == TxType.income.name ? amount : -amount;
      batch.update(doc.reference, {'allocated': true});
    }

    batch.set(_cash, {
      'name': 'wallet',
      'currency': 'TRY',
      'balance': balance,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> get _txs =>
      _db.collection('users').doc(_uid).collection('transactions');

  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('users').doc(_uid).collection('settings').doc('main');

  Stream<bool> watchOnboardingDone() => _settings
      .snapshots()
      .map((doc) => doc.data()?['onboardingDone'] == true);

  Future<void> setOnboardingDone() =>
      _settings.set({'onboardingDone': true}, SetOptions(merge: true));

  Stream<AppLanguage> watchLanguage() => _settings.snapshots().map(
      (doc) => AppLanguage.fromCode(doc.data()?['language'] as String?));

  Future<void> setLanguage(AppLanguage lang) =>
      _settings.set({'language': lang.code}, SetOptions(merge: true));

  Stream<String> watchCurrency() => _settings
      .snapshots()
      .map((doc) => doc.data()?['currency'] as String? ?? 'TRY');

  Future<void> setCurrency(String code) =>
      _settings.set({'currency': code}, SetOptions(merge: true));

  /// Tema modu: 'system' | 'light' | 'dark'. Varsayılan sistem.
  Stream<ThemeMode> watchThemeMode() => _settings.snapshots().map(
        (doc) => _themeModeFromCode(doc.data()?['themeMode'] as String?),
      );

  Future<void> setThemeMode(ThemeMode mode) =>
      _settings.set({'themeMode': mode.name}, SetOptions(merge: true));

  /// Profil bilgileri (isim, foto, telefon...) settings/main içinde.
  Stream<Map<String, dynamic>> watchProfile() =>
      _settings.snapshots().map((doc) => doc.data() ?? const {});

  /// Profil alanlarını kaydet (merge — diğer ayarlar korunur).
  Future<void> saveProfile(Map<String, dynamic> data) =>
      _settings.set(data, SetOptions(merge: true));

  /// Стартовый набор конвертов из онбординга — одним батчем.
  Future<void> addEnvelopes(
      List<({String key, String emoji, String name})> items) {
    final batch = _db.batch();
    for (final (index, item) in items.indexed) {
      batch.set(_envelopes.doc(), {
        'name': item.name,
        'emoji': item.emoji,
        'preset': item.key,
        'balance': 0,
        'sortOrder': index,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  Stream<List<Envelope>> watchEnvelopes() => _envelopes
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) => snap.docs.map(Envelope.fromDoc).toList());

  /// Операции с [start] (включительно) до [end] (не включительно) — для статистики.
  Stream<List<Tx>> watchTxsBetween(DateTime start, DateTime end) {
    return _txs
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Tx.fromDoc).toList());
  }

  Stream<List<Tx>> watchTransactions({String? envelopeId, int limit = 200}) {
    if (envelopeId != null) {
      // Sıralama SUNUCUDA: limit'li sorguda istemci tarafında sıralamak
      // "en yeni [limit] işlem" garantisi vermez — sunucu rastgele bir
      // alt küme döndürüp sonra sıralanırdı. Bileşik indeks için bkz.
      // firestore.indexes.json (envelopeIds + date DESC).
      return _txs
          .where('envelopeIds', arrayContains: envelopeId)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(Tx.fromDoc).toList());
    }
    return _txs
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Tx.fromDoc).toList());
  }

  Future<void> addEnvelope(
    String name,
    String emoji,
    int sortOrder, {
    String currency = 'TRY',
    String? section,
    int? colorIndex,
  }) {
    return _envelopes.add({
      'name': name,
      'emoji': emoji,
      'balance': 0,
      'sortOrder': sortOrder,
      'currency': currency,
      'section': section,
      'color': colorIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ad/emoji/renk/bölüm düzenleme. Para birimine DOKUNMAZ (döviz
  /// cüzdanları da buradan düzenlenir). [dropPreset]: ad değiştiyse zarf
  /// "kendi" olur — dil değişince kullanıcının adı ezilmesin.
  Future<void> updateEnvelope(
    String id, {
    required String name,
    required String emoji,
    String? section,
    int? colorIndex,
    bool dropPreset = false,
  }) {
    return _envelopes.doc(id).update({
      'name': name,
      'emoji': emoji,
      'section': section,
      'color': colorIndex,
      if (dropPreset) 'preset': FieldValue.delete(),
    });
  }

  /// Цель конверта. null — убрать с экрана «Цели».
  Future<void> setTarget(String id, double? amount) {
    return _envelopes.doc(id).update({'targetAmount': amount});
  }

  /// Birikim hedefi oluştur (Trip, araba...). Ayrı kumbara: Money left'ten
  /// hariç, Goals sekmesinde. v1 ₺ — para ayırma TRY pocket'ı düşürür.
  Future<void> addGoal({
    required String name,
    required String emoji,
    required double targetAmount,
    required int sortOrder,
  }) {
    return _envelopes.add({
      'name': name,
      'emoji': emoji,
      'balance': 0,
      'sortOrder': sortOrder,
      'currency': 'TRY',
      'targetAmount': targetAmount,
      'goal': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hedefe para ayır: cüzdandan düşer, hedef bakiyesi artar.
  /// Geçmiş/donut'a "harcama" olarak girmez (goalFund işareti).
  Future<void> fundGoal({
    required String goalId,
    required String goalName,
    required double amount,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.expense.name,
      'amount': amount,
      'date': Timestamp.fromDate(DateTime.now()),
      'note': goalName,
      'envelopeIds': <String>[],
      'currency': 'TRY',
      'goalFund': true,
      // Kayıt silinirse hedef bakiyesi de geri alınabilsin diye.
      'goalId': goalId,
    });
    _cashDelta(batch, -amount);
    batch.update(_envelopes.doc(goalId),
        {'balance': FieldValue.increment(amount)});
    return batch.commit();
  }

  /// Hedefi sil: biriken para cüzdana geri döner, sonra hedef silinir.
  /// (Ayırılan para kaybolmasın.)
  Future<void> deleteGoal(String goalId, double balance) async {
    final batch = _db.batch();
    if (balance > 0) {
      batch.set(_txs.doc(), {
        'type': TxType.income.name,
        'amount': balance,
        'date': Timestamp.fromDate(DateTime.now()),
        'note': null,
        'envelopeIds': <String>[],
        'currency': 'TRY',
        'goalFund': true,
      });
      _cashDelta(batch, balance);
    }
    batch.delete(_envelopes.doc(goalId));
    await batch.commit();
  }

  /// Arşivle / arşivden çıkar — ana grid'de gizlenir/görünür.
  Future<void> setArchived(String id, bool archived) {
    return _envelopes.doc(id).update({'archived': archived});
  }

  /// Hesap silme: kullanıcının TÜM verisini sil (App Store/Play zorunlu).
  /// Auth hesabı çağıran tarafta silinir.
  Future<void> deleteAccountData() async {
    final user = _db.collection('users').doc(_uid);
    // Kullanıcının TÜM alt koleksiyonları — biri unutulursa "hesabımı sil"
    // dendikten sonra o veri Firestore'da kalır (mağaza kuralı ihlali).
    for (final coll in [
      'envelopes',
      'transactions',
      'workDays',
      'reminders',
      'accounts',
      'recurring',
      'rules',
    ]) {
      final snap = await user.collection(coll).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final doc in snap.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    // settings/main + settings/automation (otomasyon kapatmaları).
    final settingsDocs = await user.collection('settings').get();
    for (final doc in settingsDocs.docs) {
      await doc.reference.delete();
    }
  }

  /// Döviz çevirme: ₺ cüzdandan düşer, alınan döviz hedef kumbaraya girer.
  /// İki bacak tek `groupId` altında — biri silinirse ikisi birlikte
  /// silinir, bakiyeler bozulmaz. convert:true → gerçek harcama sayılmaz.
  Future<void> convert({
    required double sentAmount,
    required String toId,
    required String toName,
    required String toCurrency,
    required double receivedAmount,
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    final d = date ?? DateTime.now();
    final n = note ?? 'Döviz';
    final groupId = _txs.doc().id;

    batch.set(_txs.doc(), {
      'type': TxType.expense.name,
      'amount': sentAmount,
      'date': Timestamp.fromDate(d),
      'note': n,
      'envelopeIds': <String>[],
      'currency': 'TRY',
      'convert': true,
      'groupId': groupId,
    });
    _cashDelta(batch, -sentAmount);

    batch.set(_txs.doc(), {
      'type': TxType.income.name,
      'amount': receivedAmount,
      'date': Timestamp.fromDate(d),
      'note': n,
      'envelopeId': toId,
      'envelopeName': toName,
      'envelopeIds': [toId],
      'currency': toCurrency,
      'convert': true,
      'groupId': groupId,
    });
    batch.update(_envelopes.doc(toId),
        {'balance': FieldValue.increment(receivedAmount)});
    return batch.commit();
  }

  /// Katalogdan kategori: preset anahtarıyla yaratılır ki dil değişince
  /// adı çevrilsin ve aynı madde ikinci kez oluşmasın. Id döndürür.
  Future<String> addPresetEnvelope({
    required String key,
    required String name,
    required String emoji,
    required int sortOrder,
  }) async {
    final doc = _envelopes.doc();
    await doc.set({
      'name': name,
      'emoji': emoji,
      'preset': key,
      'balance': 0,
      'sortOrder': sortOrder,
      'currency': 'TRY',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Döviz cüzdanı (USD/EUR... kumbara zarfı) oluştur — TEK batch: zarf
  /// belgesi + [amount] > 0 ise başlangıç bakiyesi gelir işlemi olarak
  /// (aynı alanlar [addEnvelopeIncome] ile). Onboarding ve Hesaplar'daki
  /// "+ Döviz cüzdanı ekle" buradan geçer. Yeni zarfın id'sini döndürür.
  Future<String> addCurrencyWallet({
    required String code,
    required String name,
    required String emoji,
    required double amount,
    required int sortOrder,
    String? note,
  }) async {
    final batch = _db.batch();
    final doc = _envelopes.doc();
    batch.set(doc, {
      'name': name,
      'emoji': emoji,
      'balance': amount > 0 ? amount : 0,
      'sortOrder': sortOrder,
      'currency': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (amount > 0) {
      batch.set(_txs.doc(), {
        'type': TxType.income.name,
        'amount': amount,
        'date': Timestamp.fromDate(DateTime.now()),
        'note': note,
        'envelopeId': doc.id,
        'envelopeName': name,
        'envelopeIds': [doc.id],
        'currency': code,
      });
    }
    await batch.commit();
    return doc.id;
  }

  /// Zarfa doğrudan para ekle (gelir): bakiyeyi artırır. Birikim zarflarına
  /// ($ vb.) önceki birikimi/yeni parayı eklemek için. convert YOK — gerçek
  /// gelir; birikim ekranında aylık döküme sayılır.
  Future<String> addEnvelopeIncome({
    required String envelopeId,
    required String envelopeName,
    required double amount,
    required String currency,
    String? note,
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final doc = _txs.doc();
    _writeEnvelopeIncome(batch, doc,
        envelopeId: envelopeId,
        envelopeName: envelopeName,
        amount: amount,
        currency: currency,
        note: note,
        date: date ?? DateTime.now());
    await batch.commit();
    return doc.id;
  }

  void _writeEnvelopeIncome(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> doc, {
    required String envelopeId,
    required String envelopeName,
    required double amount,
    required String currency,
    required DateTime date,
    String? note,
  }) {
    batch.set(doc, {
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'envelopeId': envelopeId,
      'envelopeName': envelopeName,
      'envelopeIds': [envelopeId],
      'currency': currency,
    });
    batch.update(_envelopes.doc(envelopeId),
        {'balance': FieldValue.increment(amount)});
  }

  /// İşlemi sil ve para etkisini geri al.
  ///
  /// Cüzdan modeli kuralları (işlemin `currency` alanına göre):
  /// * ₺ gider → cüzdana geri ekle; ₺ gelir → cüzdandan düş. Bu kural eski
  ///   (göç öncesi) işlemler için de doğrudur: onların etkisi zarf
  ///   bakiyeleri üzerinden göç toplamına, yani bugünkü cüzdana aktı.
  /// * Döviz işlemi → ilgili kumbara zarfının bakiyesini geri al.
  /// * `goalFund` → hedef bakiyesini de ters çevir (goalId üzerinden).
  /// * `convert` → aynı `groupId`'li TÜM bacaklar birlikte silinir,
  ///   yoksa tek bacak kalır ve bakiyeler kalıcı bozulur.
  Future<void> deleteTx(String txId) async {
    final ref = _txs.doc(txId);
    final snap = await ref.get();
    if (!snap.exists) return;

    // Aynı gruba ait tüm belgeleri topla (çevrimin tüm bacakları).
    final groupId = snap.data()?['groupId'] as String?;
    final docs = <DocumentSnapshot<Map<String, dynamic>>>[snap];
    if (groupId != null) {
      final siblings = await _txs.where('groupId', isEqualTo: groupId).get();
      docs
        ..clear()
        ..addAll(siblings.docs);
      if (docs.every((doc) => doc.id != txId)) docs.add(snap);
    }

    var cashDelta = 0.0;
    final envDeltas = <String, double>{};
    void env(String? id, double delta) {
      if (id == null || delta == 0) return;
      envDeltas[id] = (envDeltas[id] ?? 0) + delta;
    }

    for (final doc in docs) {
      final d = doc.data()!;
      final type = d['type'] as String?;
      final amount = (d['amount'] as num?)?.toDouble() ?? 0;
      final currency = d['currency'] as String? ?? 'TRY';
      final sign = type == TxType.expense.name
          ? 1.0
          : type == TxType.income.name
              ? -1.0
              : 0.0; // eski transfer kayıtları: cüzdanı etkilemez

      if (sign == 0) continue;
      if (currency == 'TRY') {
        cashDelta += sign * amount;
      } else {
        // Döviz: kumbara bakiyesi cüzdanla AYNI işaret kuralına uyar —
        // gider silinince para kumbaraya geri döner (+), gelir silinince
        // eklenen tutar geri alınır (−).
        env(d['envelopeId'] as String?, sign * amount);
      }
      // Hedef fonu: hedef bakiyesi cüzdanın tersine hareket etmişti.
      final goalId = d['goalId'] as String?;
      if (d['goalFund'] == true && goalId != null) {
        env(goalId, -sign * amount);
      }
    }

    final batch = _db.batch();
    _cashDelta(batch, cashDelta);
    for (final entry in envDeltas.entries) {
      final envSnap = await _envelopes.doc(entry.key).get();
      if (envSnap.exists) {
        batch.update(_envelopes.doc(entry.key),
            {'balance': FieldValue.increment(entry.value)});
      }
    }
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// История операций остаётся в журнале (имя конверта денормализовано).
  Future<void> deleteEnvelope(String id) {
    return _envelopes.doc(id).delete();
  }

  /// Расход. ₺ — из кошелька, конверт лишь помечает категорию (бюджеты и
  /// статистика читают эту метку из транзакций). Döviz-конверт — кумбара:
  /// трата в валюте уменьшает её баланс, кошелёк не трогается.
  Future<String> addExpense({
    String? envelopeId,
    String? envelopeName,
    required double amount,
    String currency = 'TRY',
    String? note,
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final doc = _txs.doc();
    _writeExpense(batch, doc,
        envelopeId: envelopeId,
        envelopeName: envelopeName,
        amount: amount,
        currency: currency,
        note: note,
        date: date ?? DateTime.now());
    await batch.commit();
    return doc.id;
  }

  void _writeExpense(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> doc, {
    required double amount,
    required String currency,
    required DateTime date,
    String? envelopeId,
    String? envelopeName,
    String? note,
  }) {
    batch.set(doc, {
      'type': TxType.expense.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'envelopeId': ?envelopeId,
      'envelopeName': ?envelopeName,
      'envelopeIds': [?envelopeId],
      'currency': currency,
    });
    if (currency == 'TRY') {
      _cashDelta(batch, -amount);
    } else if (envelopeId != null) {
      batch.update(_envelopes.doc(envelopeId), {
        'balance': FieldValue.increment(-amount),
      });
    }
  }

  /// Доход в кошелёк — единственный путь для ₺-дохода в новой модели.
  Future<String> addCashIncome({
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final batch = _db.batch();
    final doc = _txs.doc();
    _writeCashIncome(batch, doc,
        amount: amount, note: note, date: date ?? DateTime.now());
    await batch.commit();
    return doc.id;
  }

  void _writeCashIncome(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> doc, {
    required double amount,
    required DateTime date,
    String? note,
  }) {
    batch.set(doc, {
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
      'envelopeIds': <String>[],
      'currency': 'TRY',
    });
    _cashDelta(batch, amount);
  }

  /// Kategorisiz (ya da yanlış kategorili) ₺ giderin kategorisini değiştir.
  /// Yalnız etiket alanları değişir — tutar/tür sabit (kural katmanı da
  /// bunu zorlar); cüzdan bakiyesi etkilenmez.
  Future<void> setTxCategory(
    String txId, {
    required String envelopeId,
    required String envelopeName,
  }) {
    return _txs.doc(txId).update({
      'envelopeId': envelopeId,
      'envelopeName': envelopeName,
      'envelopeIds': [envelopeId],
    });
  }

  // ── tekrarlayan işlemler ──────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _recurring =>
      _db.collection('users').doc(_uid).collection('recurring');

  Stream<List<RecurringRule>> watchRecurringRules() => _recurring
      .orderBy('nextDate')
      .snapshots()
      .map((snap) => snap.docs.map(RecurringRule.fromDoc).toList());

  Future<void> deleteRecurringRule(String id) => _recurring.doc(id).delete();

  /// Kural yaz: ilk işlem normal yoldan kaydedildikten SONRA çağrılır;
  /// [nextDate] ilk tekrar (bkz. [nextOccurrence]).
  Future<String> addRecurringRule({
    required double amount,
    required String type,
    required String currency,
    required Recurrence freq,
    required DateTime firstDate,
    String? envelopeId,
    String? envelopeName,
    String? note,
  }) async {
    final doc = _recurring.doc();
    await doc.set({
      'amount': amount,
      'type': type,
      'currency': currency,
      'freq': freq.name,
      'nextDate': Timestamp.fromDate(
          nextOccurrence(firstDate, freq, anchorDay: firstDate.day)),
      'anchorDay': firstDate.day,
      'envelopeId': ?envelopeId,
      'envelopeName': ?envelopeName,
      'note': ?note,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Vadesi gelen tekrarları bugüne kadar işler (yetişme). Her tekrar TEK
  /// batch: işlem + bakiye + kuralın nextDate'i — yarıda kalsa da aynı
  /// tekrar iki kez yazılmaz. İşlenen tekrar sayısını döndürür.
  Future<int> materializeRecurring({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final snap = await _recurring
        .where('nextDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
        .get();
    var posted = 0;
    for (final doc in snap.docs) {
      var rule = RecurringRule.fromDoc(doc);
      var next = rule.nextDate;
      // Güvenlik sınırı: çok eski bir kural yüzlerce işlem üretmesin.
      var guard = 0;
      while (!next.isAfter(endOfToday) && guard++ < 400) {
        final batch = _db.batch();
        final txDoc = _txs.doc();
        _writeRule(batch, txDoc, rule, next);
        final after = nextOccurrence(next, rule.freq, anchorDay: rule.anchorDay);
        batch.update(doc.reference, {'nextDate': Timestamp.fromDate(after)});
        await batch.commit();
        posted++;
        next = after;
        rule = RecurringRule(
          id: rule.id,
          amount: rule.amount,
          type: rule.type,
          currency: rule.currency,
          freq: rule.freq,
          nextDate: after,
          anchorDay: rule.anchorDay,
          envelopeId: rule.envelopeId,
          envelopeName: rule.envelopeName,
          note: rule.note,
        );
      }
    }
    return posted;
  }

  /// Kuralı, hızlı girişle aynı yazma yollarından işleme çevirir.
  void _writeRule(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> doc,
    RecurringRule rule,
    DateTime date,
  ) {
    if (rule.isExpense) {
      _writeExpense(batch, doc,
          envelopeId: rule.envelopeId,
          envelopeName: rule.envelopeName,
          amount: rule.amount,
          currency: rule.currency,
          note: rule.note,
          date: date);
    } else if (rule.currency == 'TRY' || rule.envelopeId == null) {
      _writeCashIncome(batch, doc,
          amount: rule.amount, note: rule.note, date: date);
    } else {
      _writeEnvelopeIncome(batch, doc,
          envelopeId: rule.envelopeId!,
          envelopeName: rule.envelopeName ?? rule.currency,
          amount: rule.amount,
          currency: rule.currency,
          note: rule.note,
          date: date);
    }
  }
}

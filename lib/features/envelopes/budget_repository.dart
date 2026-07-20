import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../auth/auth_gate.dart';
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

/// Общий баланс по всем конвертам.
/// Ana ₺ toplam: yalnız TRY zarfları (yabancı para ayrı gösterilir).
final totalBalanceProvider = Provider<double>((ref) {
  final envelopes = ref.watch(envelopesProvider).value ?? [];
  return envelopes
      .where((e) => e.currency == 'TRY' && !e.archived && !e.isGoal)
      .fold(0, (total, e) => total + e.balance);
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

/// Свободные расходы («из кармана»), не учтённые в распределении.
final unallocatedFreeExpensesProvider =
    StreamProvider<List<({String id, double amount})>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchUnallocatedFreeExpenses();
});

/// Свободные доходы («в котле»), ещё не разложенные по конвертам.
final unallocatedFreeIncomeProvider =
    StreamProvider<List<({String id, double amount})>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchUnallocatedFreeIncome();
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

/// Журнал: последние операции, новые сверху.
final journalProvider = StreamProvider<List<Tx>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchTransactions();
});

/// Операции одного конверта.
final envelopeTxsProvider =
    StreamProvider.family<List<Tx>, String>((ref, envelopeId) {
  return ref
      .watch(budgetRepositoryProvider)
      .watchTransactions(envelopeId: envelopeId);
});

/// Bu ayki zarf-bazlı harcama: envelopeId -> toplam (gider, çevrim hariç).
/// "Kategori" görünümü için: zarf kartı "bu ay harcanan"ı gösterir.
final monthlySpentByEnvelopeProvider = Provider<Map<String, double>>((ref) {
  final txs = ref.watch(journalProvider).value ?? [];
  final now = DateTime.now();
  final map = <String, double>{};
  for (final t in txs) {
    if (t.type != TxType.expense || t.isConvert) continue;
    if (t.date.year != now.year || t.date.month != now.month) continue;
    final id = t.envelopeId;
    if (id == null) continue;
    map[id] = (map[id] ?? 0) + t.amount;
  }
  return map;
});

/// Все данные лежат под users/{uid}/... — у каждого пользователя свой кошелёк.
class BudgetRepository {
  BudgetRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _db.collection('users').doc(_uid).collection('envelopes');

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
      // arrayContains + orderBy → Firestore composite index ister.
      // Index gerektirmesin diye: filtre sunucuda, sıralama client'ta.
      return _txs
          .where('envelopeIds', arrayContains: envelopeId)
          .limit(limit)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(Tx.fromDoc).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
    }
    return _txs
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Tx.fromDoc).toList());
  }

  Future<void> addEnvelope(String name, String emoji, int sortOrder,
      {String currency = 'TRY'}) {
    return _envelopes.add({
      'name': name,
      'emoji': emoji,
      'balance': 0,
      'sortOrder': sortOrder,
      'currency': currency,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Правка имени делает конверт «своим» — снимаем preset,
  /// чтобы смена языка не перетёрла имя пользователя.
  Future<void> updateEnvelope(String id,
      {required String name,
      required String emoji,
      String currency = 'TRY'}) {
    return _envelopes.doc(id).update({
      'name': name,
      'emoji': emoji,
      'currency': currency,
      'preset': FieldValue.delete(),
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

  /// Hedefe para ayır: Money left'ten düşer (serbest gider, goalFund), hedef
  /// bakiyesi artar. Geçmiş/donut'a "harcama" olarak girmez.
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
      'free': true,
      'allocated': false,
      'currency': 'TRY',
      'goalFund': true,
    });
    batch.update(_envelopes.doc(goalId),
        {'balance': FieldValue.increment(amount)});
    return batch.commit();
  }

  /// Hedefi sil: biriken parayı Money left'e geri ver (serbest gelir), sonra
  /// hedefi sil. (Ayırılan para kaybolmasın.)
  Future<void> deleteGoal(String goalId, double balance) async {
    final batch = _db.batch();
    if (balance > 0) {
      batch.set(_txs.doc(), {
        'type': TxType.income.name,
        'amount': balance,
        'date': Timestamp.fromDate(DateTime.now()),
        'note': null,
        'envelopeIds': <String>[],
        'free': true,
        'allocated': false,
        'currency': 'TRY',
        'goalFund': true,
      });
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
    for (final coll in ['envelopes', 'transactions', 'workDays']) {
      final snap = await user.collection(coll).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final doc in snap.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _settings.delete();
  }

  /// Доход в конкретный конверт (подарок, продажа) — не из календаря.
  Future<void> addIncomeToEnvelope({
    required String envelopeId,
    required String envelopeName,
    required double amount,
    String currency = 'TRY',
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'envelopeId': envelopeId,
      'envelopeName': envelopeName,
      'envelopeIds': [envelopeId],
      'currency': currency,
    });
    batch.update(_envelopes.doc(envelopeId), {
      'balance': FieldValue.increment(amount),
    });
    return batch.commit();
  }

  /// Döviz çevirme: verilen ₺ kasadan/zarftan düşer, alınan döviz hedef
  /// zarfa eklenir. Farklı para birimleri olduğu için iki ayrı tutar.
  /// [fromId] null → kasadan (serbest gider).
  Future<void> convert({
    String? fromId,
    String? fromName,
    double? fromBalance, // zarf bakiyesi; yetmezse aşan kısım Kasa'dan
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
    // ₺ tarafı: çıkış. convert:true → gerçek harcama sayılmaz.
    // Kasa çıkışı = serbest gider (allocated:false), "dağıtılacak"dan düşer.
    void writeKasaOut(double amount) {
      batch.set(_txs.doc(), {
        'type': TxType.expense.name,
        'amount': amount,
        'date': Timestamp.fromDate(d),
        'note': n,
        'envelopeIds': <String>[],
        'free': true,
        'allocated': false,
        'currency': 'TRY',
        'convert': true,
      });
    }

    // Zarf çıkışı = zarf bakiyesinden düşer.
    void writeEnvOut(double amount) {
      batch.set(_txs.doc(), {
        'type': TxType.expense.name,
        'amount': amount,
        'date': Timestamp.fromDate(d),
        'note': n,
        'envelopeId': fromId,
        'envelopeName': fromName,
        'envelopeIds': [fromId!],
        'currency': 'TRY',
        'convert': true,
      });
      batch.update(_envelopes.doc(fromId),
          {'balance': FieldValue.increment(-amount)});
    }

    if (fromId == null) {
      writeKasaOut(sentAmount);
    } else {
      // Zarfta olan kadarını zarftan al, aşan kısmı Kasa'dan.
      final fromEnv = (fromBalance ?? sentAmount).clamp(0.0, sentAmount);
      if (fromEnv > 0) writeEnvOut(fromEnv);
      final overflow = sentAmount - fromEnv;
      if (overflow > 0) writeKasaOut(overflow);
    }
    // Döviz tarafı: hedef zarfa gelir (hedefin para biriminde).
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
    });
    batch.update(_envelopes.doc(toId),
        {'balance': FieldValue.increment(receivedAmount)});
    return batch.commit();
  }

  /// Перевод между конвертами: из одного вычитаем, в другой добавляем.
  Future<void> transfer({
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required double amount,
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.transfer.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'fromName': fromName,
      'envelopeName': toName,
      'envelopeIds': [fromId, toId],
    });
    batch.update(_envelopes.doc(fromId),
        {'balance': FieldValue.increment(-amount)});
    batch.update(_envelopes.doc(toId),
        {'balance': FieldValue.increment(amount)});
    return batch.commit();
  }

  /// Расход без конверта — «из кармана»: пишется в журнал и уменьшает
  /// нераспределённый заработок, балансы конвертов не трогает.
  Future<void> addFreeExpense({
    required double amount,
    String? note,
    DateTime? date,
  }) {
    return _txs.add({
      'type': TxType.expense.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'envelopeIds': <String>[],
      'free': true,
      // false, пока заработок этих денег не «разложен» через баннер.
      'allocated': false,
    });
  }

  /// Zarfa doğrudan para ekle (gelir): bakiyeyi artırır. Birikim zarflarına
  /// ($ vb.) önceki birikimi/yeni parayı eklemek için. convert YOK — gerçek
  /// gelir; birikim ekranında aylık döküme sayılır.
  Future<void> addEnvelopeIncome({
    required String envelopeId,
    required String envelopeName,
    required double amount,
    required String currency,
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'envelopeId': envelopeId,
      'envelopeName': envelopeName,
      'envelopeIds': [envelopeId],
      'currency': currency,
    });
    batch.update(_envelopes.doc(envelopeId),
        {'balance': FieldValue.increment(amount)});
    return batch.commit();
  }

  /// Доход в общий котёл (не в конкретный конверт): увеличивает
  /// нераспределённую сумму, потом раскладывается по конвертам.
  Future<void> addFreeIncome({
    required double amount,
    String? note,
    DateTime? date,
  }) {
    return _txs.add({
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'envelopeIds': <String>[],
      'free': true,
      'allocated': false,
    });
  }

  /// Нераспределённые свободные доходы («в котле»).
  Stream<List<({String id, double amount})>> watchUnallocatedFreeIncome() {
    return _txs
        .where('free', isEqualTo: true)
        .where('type', isEqualTo: TxType.income.name)
        .where('allocated', isEqualTo: false)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                (
                  id: doc.id,
                  amount: (doc.data()['amount'] as num).toDouble(),
                ),
            ]);
  }

  /// Свободные расходы, ещё не вычтенные из баннера распределения.
  Stream<List<({String id, double amount})>> watchUnallocatedFreeExpenses() {
    return _txs
        .where('free', isEqualTo: true)
        .where('type', isEqualTo: TxType.expense.name)
        .where('allocated', isEqualTo: false)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                (
                  id: doc.id,
                  amount: (doc.data()['amount'] as num).toDouble(),
                ),
            ]);
  }

  /// İşlemi sil ve bakiye etkisini geri al. Silinmiş zarflar atlanır.
  /// Gider → zarfa geri ekle; gelir → zarftan düş; transfer → ikisini ters
  /// çevir. Serbest (Kasa) işlemlerde bakiye türetildiği için sadece silinir.
  Future<void> deleteTx(String txId) async {
    final ref = _txs.doc(txId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final type = d['type'] as String?;
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    final free = d['free'] == true;

    // Geri alınacak zarf bakiyeleri: id -> delta.
    final deltas = <String, double>{};
    void add(String? id, double delta) {
      if (id == null || delta == 0) return;
      deltas[id] = (deltas[id] ?? 0) + delta;
    }

    if (type == TxType.expense.name) {
      if (!free) add(d['envelopeId'] as String?, amount); // gideri geri ekle
    } else if (type == TxType.income.name) {
      final alloc = d['allocations'] as Map<String, dynamic>?;
      if (alloc != null && alloc.isNotEmpty) {
        alloc.forEach((k, v) => add(k, -(v as num).toDouble()));
      } else if (!free) {
        add(d['envelopeId'] as String?, -amount); // geliri geri al
      }
    } else if (type == TxType.transfer.name) {
      final ids = (d['envelopeIds'] as List?)?.cast<String>() ?? const [];
      if (ids.length == 2) {
        add(ids[0], amount); // kaynağa geri
        add(ids[1], -amount); // hedeften geri al
      }
    }

    final batch = _db.batch();
    for (final entry in deltas.entries) {
      final envSnap = await _envelopes.doc(entry.key).get();
      if (envSnap.exists) {
        batch.update(_envelopes.doc(entry.key),
            {'balance': FieldValue.increment(entry.value)});
      }
    }
    batch.delete(ref);
    await batch.commit();
  }

  /// Пометить свободные операции (доходы/расходы) учтёнными после
  /// распределения по конвертам.
  Future<void> markFreeTxsAllocated(List<String> ids) {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_txs.doc(id), {'allocated': true});
    }
    return batch.commit();
  }

  /// История операций остаётся в журнале (имя конверта денормализовано).
  Future<void> deleteEnvelope(String id) {
    return _envelopes.doc(id).delete();
  }

  /// Чистка дублей конвертов (артефакт повторного онбординга при отладке):
  /// группируем по preset-ключу либо имени+эмодзи, оставляем «лучший»
  /// (с балансом / целью / меньшим sortOrder), удаляем ПУСТЫЕ копии.
  /// Возвращает число удалённых.
  Future<int> dedupeEnvelopes(List<Envelope> all) async {
    final byKey = <String, List<Envelope>>{};
    for (final e in all) {
      final key = e.presetKey ?? '${e.name}|${e.emoji}';
      byKey.putIfAbsent(key, () => []).add(e);
    }
    var deleted = 0;
    final batch = _db.batch();
    for (final group in byKey.values) {
      if (group.length < 2) continue;
      group.sort((a, b) {
        final byBal = b.balance.compareTo(a.balance);
        if (byBal != 0) return byBal;
        final byTarget = (b.targetAmount ?? 0).compareTo(a.targetAmount ?? 0);
        if (byTarget != 0) return byTarget;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      // Оставляем первый (лучший), пустые дубли — на удаление.
      for (final e in group.skip(1)) {
        if (e.balance == 0 && e.targetAmount == null) {
          batch.delete(_envelopes.doc(e.id));
          deleted++;
        }
      }
    }
    if (deleted > 0) await batch.commit();
    return deleted;
  }

  /// Доход: одна запись в журнале + инкремент баланса каждого конверта.
  /// Batch — чтобы балансы и журнал не разъехались.
  Future<void> addIncome({
    required double amount,
    required Map<String, double> allocations,
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.income.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'allocations': allocations,
      'envelopeIds': allocations.keys.toList(),
    });
    allocations.forEach((envelopeId, value) {
      batch.update(_envelopes.doc(envelopeId), {
        'balance': FieldValue.increment(value),
      });
    });
    return batch.commit();
  }

  /// Расход: запись в журнале + декремент баланса конверта.
  Future<void> addExpense({
    required String envelopeId,
    required String envelopeName,
    required double amount,
    String currency = 'TRY',
    String? note,
    DateTime? date,
  }) {
    final batch = _db.batch();
    batch.set(_txs.doc(), {
      'type': TxType.expense.name,
      'amount': amount,
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'note': note,
      'envelopeId': envelopeId,
      'envelopeName': envelopeName,
      'envelopeIds': [envelopeId],
      'currency': currency,
    });
    batch.update(_envelopes.doc(envelopeId), {
      'balance': FieldValue.increment(-amount),
    });
    return batch.commit();
  }
}

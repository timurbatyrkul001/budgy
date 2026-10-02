import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_gate.dart';
import 'account.dart';

/// `BudgetRepository` ile aynı desen: aynı Firestore örneği + aynı uid
/// sağlayıcısı. Testler bunu `AccountsRepository(fakeDb, uid)` ile ezer.
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(FirebaseFirestore.instance, ref.watch(uidProvider));
});

/// Aktif (arşivlenmemiş) hesaplar, sıralı. Eski kurulumlardaki tek `cash`
/// belgesi de burada görünür — bkz. [AccountsRepository.watchAccounts].
final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountsRepositoryProvider).watchAccounts();
});

/// Hızlı girişte önceden seçili hesap: listenin ilki. Liste boşsa
/// (ilk açılış, `cash` belgesi henüz yazılmadı) sentetik nakit — kullanıcı
/// hiç hesap kurmadan da harcama girebilsin; eski kod zaten `accounts/cash`
/// belgesini ilk yazımda `set+merge` ile oluşturuyor.
final defaultAccountProvider = Provider<Account>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  if (accounts.isNotEmpty) return accounts.first;
  return const Account(
    id: Account.cashId,
    name: '',
    currency: 'TRY',
    kind: AccountKind.cash,
    balance: 0,
  );
});

/// `users/{uid}/accounts` üzerinde CRUD. Bakiye HAREKETLERİ burada değil:
/// gelir/gider yazan taraf (BudgetRepository) işlemle birlikte tek batch'te
/// `balance`'ı artırıp azaltır; buradaki [setBalance] yalnız kullanıcının
/// "bakiyemi düzelt" etmesi için.
class AccountsRepository {
  AccountsRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _db.collection('users').doc(_uid).collection('accounts');

  /// Arşivlenmemiş hesaplar, `sortOrder`'a göre.
  ///
  /// Filtre ve sıralama bilerek İSTEMCİDE: Firestore'da `orderBy('sortOrder')`
  /// ve `where('archived', isNotEqualTo: true)` o alanı HİÇ taşımayan
  /// belgeleri sonuçtan düşürür. Eski kurulumlardaki `accounts/cash`
  /// belgesinde yalnız `balance` var — sunucu tarafı sorgu onu görünmez
  /// yapardı ve kullanıcı cüzdanını kaybetmiş sanırdı. Koleksiyon küçük
  /// (birkaç hesap), istemcide sıralamanın maliyeti yok.
  Stream<List<Account>> watchAccounts() => _accounts.snapshots().map(
    (snap) => _sorted(snap.docs.map(Account.fromDoc).where((a) => !a.archived)),
  );

  static List<Account> _sorted(Iterable<Account> accounts) {
    final list = accounts.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        // Eşitlikte nakit öne: eski `cash` belgesinin sortOrder'ı yok (0),
        // yeni eklenenler max+1 aldığı için zaten çakışmaz; çakışırsa
        // deterministik kalsın.
        if (a.isCash != b.isCash) return a.isCash ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  /// Yeni hesap. `sortOrder` verilmezse mevcutların (arşivliler dahil)
  /// sonuna eklenir — arşivden geri gelen bir hesap yenisiyle çakışmasın.
  /// Belge id'sini döndürür.
  Future<String> add({
    required String name,
    required String currency,
    required AccountKind kind,
    double balance = 0,
    String emoji = '',
    int? colorIndex,
    String? last4,
    int? sortOrder,
  }) async {
    final order = sortOrder ?? await _nextSortOrder();
    final doc = _accounts.doc();
    await doc.set({
      ...Account(
        id: doc.id,
        name: name,
        currency: currency,
        kind: kind,
        balance: balance,
        emoji: emoji,
        colorIndex: colorIndex,
        last4: last4,
        sortOrder: order,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<int> _nextSortOrder() async {
    final snap = await _accounts.get();
    var max = -1;
    for (final doc in snap.docs) {
      final v = (doc.data()['sortOrder'] as num?)?.toInt() ?? 0;
      if (v > max) max = v;
    }
    return max + 1;
  }

  /// Ad / emoji / renk / son 4 hane. Para birimine DOKUNMAZ: birimi
  /// değiştirmek mevcut bakiyeyi ve işlemleri anlamsız kılar.
  Future<void> rename(
    String id, {
    required String name,
    String? emoji,
    int? colorIndex,
    String? last4,
  }) {
    // `cash` belgesi eski kurulumda olmayabilir; `set+merge` ile hem
    // güncelleme hem ilk yazım aynı yoldan geçer.
    return _accounts.doc(id).set({
      'name': name,
      'emoji': ?emoji,
      'colorIndex': ?colorIndex,
      'last4': ?last4,
    }, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection('users').doc(_uid).collection('transactions');

  /// Bu hesaba bağlı işlem SAYISI (`transactions.accountId == id`).
  ///
  /// Bool değil sayı dönüyor: ekran "Bu kartta 3 işlem var — silmek yerine
  /// kaldır" diyebilsin. Kullanıcı neden silemediğini bir rakamla anlar;
  /// "silinemez" tek başına kafa karıştırır. Firestore `count()` toplaması
  /// belgeleri indirmeden sunucuda sayar — geçmişi kalabalık bir hesapta
  /// bile tek küçük yanıt.
  Future<int> transactionCount(String accountId) async {
    final snap = await _transactions
        .where('accountId', isEqualTo: accountId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Hesabı TAMAMEN siler — yalnız hiç işlemi yoksa.
  ///
  /// NEDEN KOŞULLU: işlemler `accountId` ile bu belgeye bağlı. Belge gidince
  /// geçmişteki kayıtlar artık olmayan bir karta işaret eder, toplamlar ile
  /// hesap listesi birbirini tutmaz. Finansal kayıtta sahipsiz işlem kabul
  /// edilemez; kullanılmış kart silinmez, [archive] ile kaldırılır. Yanlış
  /// eklenmiş (hiç kullanılmamış) kart ise iz bırakmadan gidebilir.
  ///
  /// Nakit ([Account.cashId]) hiç silinemez: eski yazma yolları hesap
  /// seçmeden doğrudan `accounts/cash`'e yazıyor (bkz. [archive]); belge
  /// yoksa ilk yazımda sıfırdan yeniden doğar ve bakiye kaybolur.
  ///
  /// Kontrol istemcide, sunucu kuralı değil: bu uygulamada tek yazar
  /// kullanıcının kendisi; sayım ile silme arasına başka bir cihazdan işlem
  /// girmesi pratikte olmaz, olursa da [BudgetRepository] o işlemi yazarken
  /// hesap belgesini `update` ettiği için orada patlar, sessizce bozulmaz.
  Future<void> delete(String id) async {
    if (id == Account.cashId) {
      throw StateError(
        'Nakit hesabı silinemez: eski kod doğrudan accounts/cash '
        'belgesine yazıyor.',
      );
    }
    final count = await transactionCount(id);
    if (count != 0) {
      throw StateError(
        'Hesap silinemez: $count işlem bu hesaba bağlı. '
        'Arşivle (archive) kullan.',
      );
    }
    await _accounts.doc(id).delete();
  }

  /// Arşivle / arşivden çıkar. İşlemi olan hesap için tek yol budur:
  /// işlemler `accountId` ile bu belgeye bağlı, belge gidince geçmiş
  /// "bilinmeyen hesap"a düşer. Hiç işlemi olmayan hesap [delete] ile
  /// tamamen de silinebilir.
  ///
  /// Nakit ([Account.cashId]) ARŞİVLENEMEZ → [StateError]. Sebep: eski
  /// yazma yolları (`BudgetRepository._cashDelta`, göç, hedef fonu...)
  /// hesap seçmeden doğrudan `accounts/cash`'e yazıyor; bu hesap listeden
  /// düşerse o hareketler görünmez bir yere akar ve "Cepte kalan" ile
  /// hesap toplamları birbirini tutmaz.
  Future<void> archive(String id, {bool archived = true}) {
    if (id == Account.cashId && archived) {
      throw StateError(
        'Nakit hesabı arşivlenemez: eski kod doğrudan '
        'accounts/cash belgesine yazıyor.',
      );
    }
    return _accounts.doc(id).set({
      'archived': archived,
    }, SetOptions(merge: true));
  }

  /// Verilen sıradaki id'lere 0..n `sortOrder` yazar — tek batch, yarım
  /// kalmış sıralama olmasın.
  Future<void> reorder(List<String> orderedIds) {
    final batch = _db.batch();
    for (final (index, id) in orderedIds.indexed) {
      batch.set(_accounts.doc(id), {
        'sortOrder': index,
      }, SetOptions(merge: true));
    }
    return batch.commit();
  }

  /// Bakiyeyi mutlak değere ayarla ("gerçek bakiyem bu"). Kuruşa
  /// yuvarlanır — `calc.dart` ile aynı kural, double kuyruğu belgeye
  /// yazılmasın. İşlem kaydı oluşturmaz; fark işlemi istenirse çağıran
  /// taraf ayrıca yazar.
  Future<void> setBalance(String id, double balance) {
    final rounded = (balance * 100).roundToDouble() / 100;
    return _accounts.doc(id).set({'balance': rounded}, SetOptions(merge: true));
  }
}

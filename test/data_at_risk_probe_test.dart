import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/auth/data_at_risk.dart';

import 'support/harness.dart';

/// Bellekte cevap yokken Firestore'a sorulan "kaybedilecek bir şey var mı"
/// sorgusu. Hazır kategoriler ve boş cüzdan "veri" değildir; tek bir işlem,
/// elle açılmış tek bir zarf ya da sıfır olmayan bakiye "veri"dir.
void main() {
  late FakeFirebaseFirestore db;
  late DataAtRiskProbe probe;

  setUp(() {
    db = FakeFirebaseFirestore();
    probe = DataAtRiskProbe(db, testUid);
  });

  Future<void> addPreset(String id) => db
      .doc('users/$testUid/envelopes/$id')
      .set({'name': 'Market', 'emoji': '🛒', 'preset': id, 'balance': 0});

  test('tertemiz hesap → yok', () async {
    expect(await probe.hasData(), isFalse);
  });

  test('yalnız onboarding hazır kategorileri → yok', () async {
    await addPreset('food');
    await addPreset('transport');
    expect(await probe.hasData(), isFalse);
  });

  test('bir işlem → var', () async {
    await addPreset('food');
    await db
        .doc('users/$testUid/transactions/t1')
        .set({'type': 'expense', 'amount': 50});
    expect(await probe.hasData(), isTrue);
  });

  test('elle açılmış kategori (preset yok) → var', () async {
    await addPreset('food');
    await db
        .doc('users/$testUid/envelopes/custom')
        .set({'name': 'Kedi maması', 'emoji': '🐱', 'balance': 0});
    expect(await probe.hasData(), isTrue);
  });

  test('sıfır olmayan nakit bakiye → var; sıfır → yok', () async {
    await db.doc('users/$testUid/accounts/cash').set({'balance': 0});
    expect(await probe.hasData(), isFalse);
    await db.doc('users/$testUid/accounts/cash').set({'balance': 1250.5});
    expect(await probe.hasData(), isTrue);
  });

  test('bellekte bilinen parçalar atlanır', () async {
    await db
        .doc('users/$testUid/transactions/t1')
        .set({'type': 'expense', 'amount': 50});
    // İşlemler bellekte "boş" diye biliniyor olsaydı sorgulanmazdı; geri
    // kalan ikisi de boş → yok.
    expect(await probe.hasData(checkTransactions: false), isFalse);
    expect(await probe.hasData(), isTrue);
  });
}

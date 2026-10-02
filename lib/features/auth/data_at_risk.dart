import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';

/// Anonim hesapta "kaybedilecek bir şey" var mı?
///
/// Başka bir hesaba geçmeden önce sorulan tek soru bu. Cevap dürüst olmalı:
/// uygulamayı az önce kurmuş, hiçbir şey yazmamış birine uyarı göstermek
/// yalnız engel olur; iki haftalık defteri olan birine göstermemek ise o
/// defteri kaybettirir.
///
/// "Veri" sayılanlar — hepsi kullanıcının KENDİ yazdığı şeyler:
///   • en az bir işlem (başlangıç bakiyesi de bir gelir işlemi olarak
///     yazıldığı için buraya girer);
///   • onboarding'in hazır setinden olmayan bir kategori/zarf/cüzdan
///     (`preset` alanı boş olanlar: elle açılan kategori, hedef, döviz
///     cüzdanı);
///   • sıfır olmayan nakit bakiye (işlem yokken olmaz ama eski cüzdan
///     göçünden kalan bakiyeyi de saymak istiyoruz).
///
/// Para birimi, tema, dil, profil adı sayılmaz: bunlar bir dakikada yeniden
/// seçilir, "kayıt" değildir. Hazır kategoriler de sayılmaz — onboarding
/// her hesapta aynı seti kurar.
///
/// Ucuz olmalı: önce bellekteki akışlara bakılır (ana ekran zaten
/// dinliyor, sıfır maliyet). Yalnız henüz yüklenmemiş olan parça için
/// Firestore'a gidilir ve o da en küçük sorguyla ([DataAtRiskProbe]).
Future<bool> anonymousHasData(WidgetRef ref) async {
  final txs = ref.read(journalProvider).value;
  final envelopes = ref.read(envelopesProvider).value;
  final cash = ref.read(cashBalanceProvider).value;

  if (txs != null && txs.isNotEmpty) return true;
  if (envelopes != null && hasCustomEnvelope(envelopes)) return true;
  if (cash != null && cash != 0) return true;
  // Üçü de yüklü ve üçü de boş: kesin cevap, ağa gitmeye gerek yok.
  if (txs != null && envelopes != null && cash != null) return false;

  final repo = ref.read(budgetRepositoryProvider);
  return DataAtRiskProbe(repo.db, repo.uid).hasData(
    checkTransactions: txs == null,
    checkEnvelopes: envelopes == null,
    checkCash: cash == null,
  );
}

/// Hazır setten olmayan en az bir zarf var mı?
bool hasCustomEnvelope(List<Envelope> envelopes) =>
    envelopes.any((e) => e.presetKey == null);

/// Bellekte cevap yokken Firestore'a sorulan en küçük sorular.
///
/// `BudgetRepository`'ye konmadı: o dosya zarf katmanının; burası giriş
/// akışının tek kullanımlık ihtiyacı. Repository'nin açık `db`/`uid`
/// kapıları tam bu tür uzantılar için var.
class DataAtRiskProbe {
  const DataAtRiskProbe(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(_uid);

  Future<bool> hasData({
    bool checkTransactions = true,
    bool checkEnvelopes = true,
    bool checkCash = true,
  }) async {
    // Önce işlemler: en olası "evet" cevabı buradan gelir ve tek belgelik
    // sorgu. Sırayla gidiliyor; ilk "evet"te durulur.
    if (checkTransactions) {
      final snap = await _user.collection('transactions').limit(1).get();
      if (snap.docs.isNotEmpty) return true;
    }
    if (checkEnvelopes) {
      // Firestore "alanı OLMAYAN belge" filtresi bilmiyor (`isNull` yalnız
      // açıkça null yazılmışı bulur); koleksiyon küçük (onlarca belge),
      // tamamını okuyup bakmak en ucuzu.
      final snap = await _user.collection('envelopes').get();
      if (snap.docs.any((d) => d.data()['preset'] == null)) return true;
    }
    if (checkCash) {
      final cash = await _user.collection('accounts').doc('cash').get();
      final balance = (cash.data()?['balance'] as num?)?.toDouble() ?? 0;
      if (balance != 0) return true;
    }
    return false;
  }
}

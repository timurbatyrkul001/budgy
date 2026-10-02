import '../transactions/tx.dart';
import 'account.dart';

/// Yeni işlem için "muhtemelen bu karttan" tahmini.
///
/// AMAÇ: Kullanıcı her harcamada kart seçmek zorunda kalmasın. Çoğu insan
/// birkaç kartla yaşıyor ve her birini belli yerlerde kullanıyor: market
/// hep Enpara'dan, Bakü'deki kahve hep Kapital'den. Bu kalıbı geçmişten
/// okuyup formu önceden dolduruyoruz; kullanıcı yalnız istisnada dokunur.
///
/// SAF FONKSİYON: Firestore, provider, saat yok. Çağıran taraf listeleri
/// verir, biz bir `id` döneriz. Böylece her kural tek başına test edilir ve
/// ekran kodu değişince algoritma bozulmaz.
///
/// Öncelik sırası — her kural bir öncekinden ZAYIF sinyal:
///
/// 1. **Bu kategoride en son kullanılan hesap.** "Markete hep Enpara'dan
///    ödüyorum" en güçlü kalıp: kategori + hesap eşleşmesi kişiseldir ve
///    kullanıcı onu bir kez bozmuşsa (bu ay marketi Garanti'den ödedi)
///    muhtemelen bilerek bozmuştur — EN SON seçim, sıklıktan daha doğru.
/// 2. **Son 30 günde en çok kullanılan hesap.** Kategori yoksa ya da bu
///    kategoride hiç harcama yapılmamışsa "genel favori"ye düşeriz. Pencere
///    30 gün: kart değiştiren biri (eski kart iptal, yeni kart geldi) bir ay
///    sonra eski kartı artık önerilmiş görmesin. Beraberlikte daha yakın
///    zamanda kullanılan kazanır — deterministik olsun diye.
/// 3. **Listedeki ilk hesap.** Hiç geçmiş yoksa (ilk gün) kullanıcının
///    sıraladığı ilk kart; `accountsProvider` zaten `sortOrder`'a göre
///    veriyor, nakit genelde başta.
///
/// GÜVENLİK: Yalnız [accounts] içinde olan ve arşivlenmemiş hesaplar
/// önerilir. Geçmişte çok kullanılmış ama sonra arşivlenmiş/silinmiş bir
/// kartın id'sini döndürseydik form "bilinmeyen hesap"a düşerdi ve yazma
/// yolu görünmez bir belgeye para akıtırdı.
///
/// [recent] yeniden eskiye sıralı beklenir ama buna GÜVENMİYORUZ: tarihe
/// kendimiz bakıyoruz. Sıra bozuk gelse de sonuç aynı.
String? suggestAccount({
  required List<Account> accounts,
  required List<Tx> recent,
  String? categoryId,
  DateTime? now,
}) {
  // Önerilebilir kümesi: listede olan + arşivsiz.
  final valid = <String>{
    for (final a in accounts)
      if (!a.archived) a.id,
  };
  if (valid.isEmpty) return null;

  // Yalnız gerçek harcamalar sinyal sayılır. Gelir "hangi karttan
  // harcadım"ı söylemez (maaş Garanti'ye yatar ama harcama Enpara'dan
  // çıkar); döviz çevirme de alışkanlık değil, muhasebe hareketi.
  final spends = recent.where(
    (t) =>
        t.type == TxType.expense &&
        !t.isConvert &&
        t.accountId != null &&
        valid.contains(t.accountId),
  );

  // ── Kural 1: bu kategoride en son kullanılan ─────────────────────────
  if (categoryId != null) {
    Tx? latest;
    for (final t in spends) {
      if (t.envelopeId != categoryId) continue;
      if (latest == null || t.date.isAfter(latest.date)) latest = t;
    }
    if (latest != null) return latest.accountId;
  }

  // ── Kural 2: son 30 günde en sık kullanılan ──────────────────────────
  final clock = now ?? DateTime.now();
  final since = clock.subtract(const Duration(days: 30));
  final count = <String, int>{};
  final lastUse = <String, DateTime>{};
  for (final t in spends) {
    // Gelecek tarihli (planlı) işlemler de sayılır; 30 günden eskiler
    // sayılmaz. Pencerenin tek ucu var: geçmiş.
    if (t.date.isBefore(since)) continue;
    final id = t.accountId!;
    count[id] = (count[id] ?? 0) + 1;
    final prev = lastUse[id];
    if (prev == null || t.date.isAfter(prev)) lastUse[id] = t.date;
  }
  if (count.isNotEmpty) {
    String? best;
    for (final id in count.keys) {
      if (best == null) {
        best = id;
        continue;
      }
      final byCount = count[id]!.compareTo(count[best]!);
      // Sayı eşitse daha yakın zamanda kullanılan öne geçer.
      if (byCount > 0 ||
          (byCount == 0 && lastUse[id]!.isAfter(lastUse[best]!))) {
        best = id;
      }
    }
    return best;
  }

  // ── Kural 3: listedeki ilk (arşivsiz) hesap ──────────────────────────
  for (final a in accounts) {
    if (!a.archived) return a.id;
  }
  return null;
}

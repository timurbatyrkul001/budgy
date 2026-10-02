import 'fx.dart';

/// İstenen kur çiftinin [FxSnapshot] içinde bulunmaması.
///
/// Çağıran taraf bunu yakalayıp kullanıcıya "kur alınamadı, sonra tekrar
/// dene" demeli. İşlemi kursuz kaydetmek (baseAmount = null) ya da tahmini
/// bir kur uydurmak seçenek DEĞİL: `Tx.baseAmount` bir kez yazılır ve bir
/// daha değişmez, yanlış dondurulan tutar ay toplamını kalıcı bozar.
class FxUnavailable implements Exception {
  const FxUnavailable(this.from, this.to);

  final String from;
  final String to;

  @override
  String toString() => 'FxUnavailable($from→$to)';
}

/// [amount]'u ([from] biriminde) [to] birimine o anki [fx] tablosuyla
/// çevirir ve KAYDA HAZIR değerleri döndürür: `baseAmount` 2 haneye
/// yuvarlanmış, `rate` ham.
///
/// Döndürülen `rate` = 1 [from] kaç [to] — `Tx.fxRate` ile aynı anlam.
///
/// Yuvarlama kuralı:
/// * `baseAmount` kuruşa yuvarlanır — bakiye aritmetiği `+`/`-` ile
///   yürüyor (bkz. `BudgetRepository._cashDelta`, `calc.dart`), double
///   kuyrukları (0.1 + 0.2) toplamlara sızmasın.
/// * `rate` yuvarlanMAZ — kur bir kayıt/denetim bilgisidir, kullanıcıya
///   "1 ₼ = 1,97 ₺ üzerinden" diye gösterilir; yuvarlanmış kur ile
///   baseAmount'u geri hesaplamak zaten kuruş sapması verir, ham kuru
///   saklamak en azından aslını korur.
///
/// Kur bulunamazsa [FxUnavailable] fırlatır — sessizce 0 ya da 1 döndürmez.
({double baseAmount, double rate}) freezeToBase({
  required double amount,
  required String from,
  required String to,
  required FxSnapshot fx,
}) {
  // Aynı birim: kur yok, çevrim yok. Yine de yuvarlıyoruz ki iki yoldan
  // (aynı birim / farklı birim) gelen baseAmount aynı hassasiyette olsun.
  if (from == to) return (baseAmount: _toCents(amount), rate: 1);

  final rate = _crossRate(fx, from: from, to: to);
  if (rate == null) throw FxUnavailable(from, to);
  return (baseAmount: _toCents(amount * rate), rate: rate);
}

/// Snapshot'tan 1 [from] kaç [to] hesaplar. Tablo tek tabana göre
/// (`rates[X]` = 1 base kaç X), bu yüzden üç durum var:
///
/// * base == from → doğrudan `rates[to]`
/// * base == to   → `1 / rates[from]`
/// * ikisi de değil → çapraz: `rates[to] / rates[from]`
///   (1 from = 1/rates[from] base = rates[to]/rates[from] to)
///
/// Eksik, sıfır ya da sonlu olmayan değerlerde null — sıfıra bölme ya da
/// 0 kur, "kur yok" demektir; sayı gibi davranmamalı.
double? _crossRate(FxSnapshot fx, {required String from, required String to}) {
  double? valid(double? v) => (v == null || v <= 0 || !v.isFinite) ? null : v;

  // Tablonun kendi tabanı her zaman 1'dir; kaynak bunu bazen listeye
  // koymuyor, biz tamamlıyoruz.
  double? rateOf(String code) => code == fx.base ? 1.0 : valid(fx.rates[code]);

  final toRate = rateOf(to);
  final fromRate = rateOf(from);
  if (toRate == null || fromRate == null) return null;
  return toRate / fromRate;
}

/// Kuruşa yuvarla — `calc.dart` ile aynı kural.
double _toCents(double v) => (v * 100).roundToDouble() / 100;

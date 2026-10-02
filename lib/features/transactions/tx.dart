import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { income, expense, transfer }

/// Операция: доход (распределён по конвертам) или расход (из одного конверта).
class Tx {
  const Tx({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.allocations = const {},
    this.envelopeId,
    this.envelopeName,
    this.fromName,
    this.currency = 'TRY',
    this.isConvert = false,
    this.isGoalFund = false,
    this.accountId,
    this.baseAmount,
    this.baseCurrency,
    this.fxRate,
  });

  final String id;
  final TxType type;
  final double amount;
  final DateTime date;
  final String? note;

  /// İşlemin para birimi (zarfın birimi). Varsayılan ₺.
  final String currency;

  /// Döviz çevirme işlemi mi? Gerçek harcama değil — donut/istatistikten
  /// hariç tutulur, satırda «Döviz» olarak gösterilir.
  final bool isConvert;

  /// Birikim hedefine para ayırma mı? Money left'ten düşer ama gerçek harcama
  /// sayılmaz — donut/istatistik/geçmişten hariç (hedef kartı kaydı tutar).
  final bool isGoalFund;

  /// Для дохода: envelopeId -> сумма, положенная в этот конверт.
  final Map<String, double> allocations;

  /// Для расхода: из какого конверта потрачено.
  final String? envelopeId;

  /// Имя конверта на момент операции (денормализовано для журнала).
  /// Для перевода — конверт-получатель.
  final String? envelopeName;

  /// Для перевода — конверт-источник.
  final String? fromName;

  /// Paranın çıktığı/girdiği hesap (`users/{uid}/accounts/{id}`). Eski
  /// işlemlerde yok — okunurken nakit sayılır.
  final String? accountId;

  /// [amount]'un ana para birimine çevrilmiş hâli. **İşlem kaydedilirken
  /// o günün kuruyla hesaplanır ve bir daha DEĞİŞMEZ.**
  ///
  /// Dondurulmasının sebebi: güncel kurla her açılışta yeniden çevirseydik
  /// manat dalgalandıkça geçen ayın toplamı da değişirdi. Geçmişi oynayan
  /// bir bütçe kaydı işe yaramaz.
  ///
  /// [currency] ana birimle aynıysa [amount] ile eşittir. Eski işlemlerde
  /// null — o zaman okuyan taraf [amount]'a düşer (hepsi ₺ idi).
  final double? baseAmount;

  /// [baseAmount] hangi para biriminde. Kullanıcı ana para birimini sonradan
  /// değiştirirse eski kayıtların neye göre çevrildiği kaybolmasın diye
  /// işlemle birlikte saklanır.
  final String? baseCurrency;

  /// Kullanılan kur (1 [currency] kaç [baseCurrency]). Kullanıcıya
  /// "1 ₼ = 1,97 ₺ üzerinden" diye göstermek ve denetlemek için.
  final double? fxRate;

  /// Analizlerde kullanılacak tutar — her zaman ana para biriminde.
  ///
  /// Sıra:
  /// 1. Dondurulmuş [baseAmount] varsa o. Yeni kayıtların hepsinde var.
  /// 2. Hesaplar öncesinden kalma ana cüzdan kaydıysa [amount]. O dönemde
  ///    tüm para tek kasadaydı ve `currency` alanına kullanıcının seçtiği
  ///    birim değil, "ana birim" anlamında sabit [legacyMainCode] yazılıyordu.
  ///    [accountId] yokluğu + bu kod, kaydın o döneme ait olduğunun işareti;
  ///    tutar zaten ana birimde. Bu dalı atlayıp `currency == mainCurrency`
  ///    karşılaştırması yapsaydık, ana birimini USD yapmış bir kullanıcının
  ///    bütün geçmişi sıfırlanırdı.
  /// 3. İşlemin birimi ana birimle aynıysa [amount].
  /// 4. Geri kalan: 0 — çevrilmemiş yabancı para kaydı. Bugünün kuruyla
  ///    çevirmek geçmişi oynatır, ham tutarı toplamak düpedüz yanlış olur;
  ///    yanlış rakamdansa eksik rakam.
  double baseOr(String mainCurrency) {
    final frozen = baseAmount;
    if (frozen != null) return frozen;
    if (accountId == null && currency == legacyMainCode) return amount;
    return currency == mainCurrency ? amount : 0;
  }

  /// Hesaplar gelmeden önce ana cüzdan işlemlerine yazılan sabit kod.
  /// Gerçek bir para birimi seçimi değil — o dönemde ana birimin kodu
  /// her zaman buydu, yalnız gösterilen simge değişiyordu.
  static const legacyMainCode = 'TRY';

  factory Tx.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Tx(
      id: doc.id,
      type: TxType.values.byName(data['type'] as String),
      amount: (data['amount'] as num).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] as String?,
      allocations: (data['allocations'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      envelopeId: data['envelopeId'] as String?,
      envelopeName: data['envelopeName'] as String?,
      fromName: data['fromName'] as String?,
      currency: data['currency'] as String? ?? 'TRY',
      isConvert: data['convert'] == true,
      isGoalFund: data['goalFund'] == true,
      accountId: data['accountId'] as String?,
      baseAmount: (data['baseAmount'] as num?)?.toDouble(),
      baseCurrency: data['baseCurrency'] as String?,
      fxRate: (data['fxRate'] as num?)?.toDouble(),
    );
  }
}

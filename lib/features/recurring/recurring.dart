import 'package:cloud_firestore/cloud_firestore.dart';

/// Tekrar sıklığı. `none` yalnız UI'da (kural yazılmaz).
enum Recurrence { none, daily, weekly, monthly, yearly }

/// Bir sonraki tekrar tarihi. Aylık/yıllıkta gün ay sonuna kırpılır:
/// 31 Ocak → 28/29 Şubat. Kırpılan kural sonraki aylarda tekrar 31'e
/// dönmez; bunun için [anchorDay] verilir (kuralın orijinal günü).
DateTime nextOccurrence(DateTime from, Recurrence freq, {int? anchorDay}) {
  final d = DateTime(from.year, from.month, from.day);
  switch (freq) {
    case Recurrence.none:
      return d;
    case Recurrence.daily:
      return d.add(const Duration(days: 1));
    case Recurrence.weekly:
      return d.add(const Duration(days: 7));
    case Recurrence.monthly:
      return _clampDay(d.year, d.month + 1, anchorDay ?? d.day);
    case Recurrence.yearly:
      return _clampDay(d.year + 1, d.month, anchorDay ?? d.day);
  }
}

DateTime _clampDay(int year, int month, int day) {
  final norm = DateTime(year, month); // ay taşmasını normalize eder
  final last = DateTime(norm.year, norm.month + 1, 0).day;
  return DateTime(norm.year, norm.month, day > last ? last : day);
}

/// users/{uid}/recurring belgesi: kaydedilen ilk işlemin kopyası +
/// sıklık + sıradaki tarih. Uygulama açılışında vadesi gelenler işlenir.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.amount,
    required this.type,
    required this.currency,
    required this.freq,
    required this.nextDate,
    required this.anchorDay,
    this.envelopeId,
    this.envelopeName,
    this.note,
    this.accountId,
    this.accountName,
    this.holdReason,
  });

  final String id;
  final double amount;

  /// 'expense' | 'income'
  final String type;

  /// Hesapsız (eski) kuralda: 'TRY' = nakit cüzdan; başka kod = döviz
  /// cüzdanı (envelopeId zorunlu). Hesaba bağlı kuralda hesabın birimi —
  /// yalnız liste satırında göstermek için; işleme yazılırken hesabın O
  /// ANKİ birimi esastır (nakit ana birimi izler).
  final String currency;
  final Recurrence freq;
  final DateTime nextDate;

  /// Kuralın orijinal günü (aylık/yıllıkta ay sonu kırpması için).
  final int anchorDay;
  final String? envelopeId;
  final String? envelopeName;
  final String? note;

  /// Paranın çıktığı/girdiği hesap (`users/{uid}/accounts/{id}`). Hesaplar
  /// gelmeden önce yazılmış kurallarda yok — o kurallar eskisi gibi tek
  /// kasa (nakit / döviz zarfı) yolundan işlenir, davranışları DEĞİŞMEZ.
  /// Dolu kural, işlemi elle aynı karttan girilmiş gibi yazar: `accountId`,
  /// hesabın kendi biriminde bakiye düşümü, dondurulmuş kur.
  final String? accountId;

  /// Hesabın adı, liste satırı için denormalize (zarf adı gibi).
  final String? accountName;

  /// Materyalizasyon bu kuralı neden ATLADI (null = sorun yok).
  /// [holdAccountMissing] | [holdFxUnavailable]. `nextDate` ilerletilmez;
  /// engel kalkınca (hesap arşivden çıktı, kur geldi) bir sonraki açılış
  /// biriken tekrarları yetişerek yazar — ödeme sessizce kaybolmaz.
  final String? holdReason;

  /// Kuralın hesabı silinmiş ya da arşivlenmiş.
  static const holdAccountMissing = 'accountMissing';

  /// Hesabın birimi ana birimden farklı ve o an kur yok (çevrimdışı).
  static const holdFxUnavailable = 'fxUnavailable';

  bool get isExpense => type == 'expense';

  factory RecurringRule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return RecurringRule(
      id: doc.id,
      amount: (d['amount'] as num).toDouble(),
      type: d['type'] as String? ?? 'expense',
      currency: d['currency'] as String? ?? 'TRY',
      freq: Recurrence.values.firstWhere(
        (f) => f.name == d['freq'],
        orElse: () => Recurrence.monthly,
      ),
      nextDate: (d['nextDate'] as Timestamp).toDate(),
      anchorDay: (d['anchorDay'] as num?)?.toInt() ??
          (d['nextDate'] as Timestamp).toDate().day,
      envelopeId: d['envelopeId'] as String?,
      envelopeName: d['envelopeName'] as String?,
      note: d['note'] as String?,
      accountId: d['accountId'] as String?,
      accountName: d['accountName'] as String?,
      holdReason: d['holdReason'] as String?,
    );
  }

  RecurringRule copyWith({DateTime? nextDate, String? holdReason}) =>
      RecurringRule(
        id: id,
        amount: amount,
        type: type,
        currency: currency,
        freq: freq,
        nextDate: nextDate ?? this.nextDate,
        anchorDay: anchorDay,
        envelopeId: envelopeId,
        envelopeName: envelopeName,
        note: note,
        accountId: accountId,
        accountName: accountName,
        holdReason: holdReason ?? this.holdReason,
      );
}

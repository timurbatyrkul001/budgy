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
    );
  }
}

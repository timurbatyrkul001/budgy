import 'package:cloud_firestore/cloud_firestore.dart';

/// Конверт — копилка под конкретную цель (аренда, еда, путешествия...).
class Envelope {
  const Envelope({
    required this.id,
    required this.name,
    required this.emoji,
    required this.balance,
    required this.sortOrder,
    this.currency = 'TRY',
    this.archived = false,
    this.targetAmount,
    this.presetKey,
    this.isGoal = false,
  });

  final String id;
  final String name;
  final String emoji;
  final double balance;
  final int sortOrder;

  /// Para birimi kodu (TRY/USD/EUR...). Varsayılan ₺.
  final String currency;

  /// Arşivlenmiş mi? Arşivdekiler ana grid'de gizlenir.
  final bool archived;

  /// Ключ стартового конверта из онбординга ('rent', 'food'...).
  /// Такие конверты показываются с именем из текущего языка.
  final String? presetKey;

  /// Целевая сумма. Hedef (isGoal) için: birikim hedefi. Harcama kategorisi
  /// için: aylık bütçe limiti.
  final double? targetAmount;

  /// Birikim hedefi mi? (Trip, araba...) — harcama kategorisi değil, ayrı bir
  /// kumbara. Money left'ten hariç, Goals sekmesinde gösterilir.
  final bool isGoal;

  double get progress => targetAmount == null || targetAmount! <= 0
      ? 0
      : (balance / targetAmount!).clamp(0, 1);

  /// Hedefe kalan: hedef − biriken.
  double get remaining =>
      targetAmount == null ? 0 : (targetAmount! - balance).clamp(0, targetAmount!);

  factory Envelope.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Envelope(
      id: doc.id,
      name: data['name'] as String,
      emoji: data['emoji'] as String? ?? '💰',
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      sortOrder: data['sortOrder'] as int? ?? 0,
      currency: data['currency'] as String? ?? 'TRY',
      archived: data['archived'] == true,
      targetAmount: (data['targetAmount'] as num?)?.toDouble(),
      presetKey: data['preset'] as String?,
      isGoal: data['goal'] == true,
    );
  }
}

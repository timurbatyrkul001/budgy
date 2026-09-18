/// Bütçeyi kategorilere geçmiş harcama payına göre dağıtır.
///
/// [history]: kategori → son 60 günlük harcama. Paylar orana göre, tutarlar
/// [step]'e yuvarlanır (varsayılan: toplam ≥ 1000 ise 10, değilse 1);
/// yuvarlama artığı en büyük kategoriye eklenir ki toplam [total]'ı tutsun.
/// Geçmiş yoksa boş harita (öneri yapılamaz).
Map<String, double> autoSplit({
  required double total,
  required Map<String, double> history,
  double? step,
}) {
  final positive = {
    for (final e in history.entries)
      if (e.value > 0) e.key: e.value,
  };
  if (total <= 0 || positive.isEmpty) return const {};
  final sum = positive.values.fold<double>(0, (a, b) => a + b);
  final unit = step ?? (total >= 1000 ? 10.0 : 1.0);

  final result = <String, double>{};
  var allocated = 0.0;
  for (final e in positive.entries) {
    final raw = total * e.value / sum;
    final rounded = (raw / unit).round() * unit;
    result[e.key] = rounded;
    allocated += rounded;
  }
  // Artığı en büyük kategoriye ver (negatif de olabilir → düş).
  final largest =
      positive.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  result[largest] = (result[largest]! + (total - allocated)).clamp(0, total);
  return result;
}

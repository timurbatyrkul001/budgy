import '../features/transactions/tx.dart';

final _tagRe = RegExp(r'#([\p{L}\p{N}_]+)', unicode: true);

/// Metindeki #etiketler (küçük harfe indirgenmiş, sırayla, tekrarsız).
List<String> tagsIn(String? text) {
  if (text == null || text.isEmpty) return const [];
  final seen = <String>{};
  return [
    for (final m in _tagRe.allMatches(text))
      if (seen.add(m.group(1)!.toLowerCase())) m.group(1)!.toLowerCase(),
  ];
}

/// İşlem notlarındaki etiketler → kullanım sayısı (çoktan aza, sonra ada
/// göre). Etiketler ayrı bir yerde saklanmaz; notlardan türetilir.
Map<String, int> extractTags(Iterable<Tx> txs) {
  final counts = <String, int>{};
  for (final t in txs) {
    for (final tag in tagsIn(t.note)) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return {for (final e in entries) e.key: e.value};
}

import 'claude_client.dart';

/// Kategori bütçesi önerisini (geçmişe göre hesaplanmış dağılımı) Claude
/// Haiku ile inceltir: toplamı korur, kategori adlarına göre makul
/// düzeltmeler yapar. Anahtar yoksa ya da çağrı başarısızsa [draft]
/// olduğu gibi döner — buton anahtarsız da tam çalışır.
class BudgetAdvisor {
  static bool get available => ClaudeClient.available;

  static Future<Map<String, double>> refine({
    required double total,
    required Map<String, double> draft,
    required Map<String, String> names,
    required String languageCode,
  }) async {
    if (!available || draft.isEmpty) return draft;
    try {
      final input = await ClaudeClient.callTool(
        toolName: 'set_category_budgets',
        toolDescription: 'Kategori bütçelerini belirle',
        inputSchema: {
          'type': 'object',
          'properties': {
            'items': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {'type': 'string'},
                  'amount': {'type': 'number'},
                },
                'required': ['id', 'amount'],
              },
            },
          },
          'required': ['items'],
        },
        content: [
          {
            'type': 'text',
            'text': 'Aylık/haftalık kişisel bütçe: toplam $total. '
                'Aşağıdaki taslak, kullanıcının son 60 günlük harcama '
                'payından üretildi. Kategori adlarına bakarak makul '
                'düzeltmeler yap (zorunlu giderleri kısma, keyfî olanları '
                'hafifçe kırp), toplam AYNI kalsın, her kategori için '
                'id\'yi birebir kullan, tutarları 10\'a yuvarla. '
                'Dil: $languageCode.\n\n'
                '${[
              for (final e in draft.entries)
                '${e.key} (${names[e.key] ?? e.key}): ${e.value}'
            ].join('\n')}',
          },
        ],
      );
      final items = (input['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final result = <String, double>{};
      for (final it in items) {
        final id = it['id'] as String?;
        final amount = (it['amount'] as num?)?.toDouble();
        if (id == null || amount == null || !draft.containsKey(id)) continue;
        result[id] = amount < 0 ? 0 : amount;
      }
      // Eksik kategori ya da bozuk toplam → taslağa dön.
      if (result.length != draft.length) return draft;
      final sum = result.values.fold<double>(0, (a, b) => a + b);
      if ((sum - total).abs() > total * 0.02) return draft;
      return result;
    } catch (_) {
      return draft;
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import '../../features/envelopes/envelope.dart';
import 'claude_client.dart';

/// Doğal dilden ya da fişten çözülmüş tek bir işlem.
class ParsedItem {
  const ParsedItem({
    required this.kind,
    required this.amount,
    required this.note,
    this.envelopeId,
    this.envelopeName,
  });

  /// 'expense' | 'income'
  final String kind;
  final double amount;

  /// Kısa açıklama ("kahve", "market alışverişi"...).
  final String note;

  /// Kullanıcının zarflarından eşleşen kategori (yalnız gider için).
  final String? envelopeId;
  final String? envelopeName;

  ParsedItem copyWith({String? envelopeId, String? envelopeName}) =>
      ParsedItem(
        kind: kind,
        amount: amount,
        note: note,
        envelopeId: envelopeId ?? this.envelopeId,
        envelopeName: envelopeName ?? this.envelopeName,
      );
}

/// API anahtarı yokken görüntü çözümü istendi.
class AiUnavailable implements Exception {
  const AiUnavailable();
}

/// Serbest metni ("kahve 90, market 450, 2000 kazandım") ve fiş
/// fotoğrafını işlemlere çevirir.
///
/// İki motor:
///  * **AI (Haiku)** — ana yol: her ifadeyi anlar, birden çok işlemi ayırır,
///    kategoriyi kullanıcının KENDİ zarf adlarıyla eşler. Anahtar derlemede
///    verilir: `--dart-define=ANTHROPIC_API_KEY=sk-...`
///  * **Regex** — anahtar/ağ yoksa: "not tutar" kalıbındaki tek işlemi çözer.
///    Görüntü için anlamsız; fişte AI yoksa [AiUnavailable] fırlar.
///
/// PROD NOTU: yayında anahtar istemciye gömülmez — çağrı Cloud Functions
/// proxy'sine taşınacak. --dart-define yalnız geliştirme kolaylığı.
class ExpenseParser {
  static bool get aiAvailable => ClaudeClient.available;

  /// [envelopes] — aktif ₺ zarflar; AI kategoriyi bunların adlarıyla eşler.
  Future<List<ParsedItem>> parse(
    String text, {
    required List<({String id, String name})> envelopes,
    String languageCode = 'tr',
    ({String id, String name})? Function(String text)? resolveCategory,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return const [];
    if (aiAvailable) {
      try {
        return await _callAi(
          [
            {
              'type': 'text',
              'text': 'Kullanıcının serbest metnini para işlemlerine çevir. '
                  'Birden fazla işlem olabilir. Sayılar Türkçe biçimde '
                  'olabilir (1.250,50 = 1250.50). Dil: $languageCode.\n'
                  '${_categoryLine(envelopes)}\n\n'
                  'Metin: $cleaned',
            },
          ],
          envelopes,
        );
      } catch (_) {
        // Ağ/limit hatası → regex'e düş; kullanıcı en azından tutarı alır.
      }
    }
    return _parseWithRegex(cleaned, envelopes, resolveCategory);
  }

  /// Fiş fotoğrafı → TEK gider: tutar = ödenen son toplam, not = mağaza,
  /// kategori = listeden birebir ad ya da boş. Anahtar yoksa [AiUnavailable].
  Future<List<ParsedItem>> parseReceipt(
    Uint8List bytes, {
    required String mediaType,
    required List<({String id, String name})> envelopes,
    String languageCode = 'tr',
  }) {
    if (!aiAvailable) throw const AiUnavailable();
    return _callAi(
      [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mediaType,
            'data': base64Encode(bytes),
          },
        },
        {
          'type': 'text',
          'text': 'Bu bir alışveriş fişinin fotoğrafı. TEK bir gider olarak '
              'kaydet: tutar = gerçekten ödenen son toplam (ara toplam, '
              'vergi satırı ya da para üstü değil), not = mağaza/işletme adı, '
              'kategori = alınanlara en uygun olan. Fiş değilse ya da toplam '
              'okunamıyorsa boş liste döndür. Kullanıcı dili: $languageCode.\n'
              '${_categoryLine(envelopes)}',
        },
      ],
      envelopes,
    );
  }

  static String _categoryLine(List<({String id, String name})> envelopes) =>
      'Kategori listesi (gider için, adı BİREBİR kullan ya da boş bırak): '
      '${envelopes.map((e) => e.name).join(', ')}';

  // ── AI ────────────────────────────────────────────────────────────────

  /// Ortak çağrı: zorunlu `record_transactions` aracıyla yapılandırılmış
  /// çıktı; metin ve görüntü aynı yoldan geçer (bkz. [ClaudeClient]).
  Future<List<ParsedItem>> _callAi(
    List<Map<String, Object?>> content,
    List<({String id, String name})> envelopes,
  ) async {
    final schema = {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'kind': {
                'type': 'string',
                'enum': ['expense', 'income'],
              },
              'amount': {'type': 'number'},
              'note': {
                'type': 'string',
                'description':
                    'Kısa açıklama, kullanıcının dilinde (örn. "kahve")',
              },
              'category': {
                'type': 'string',
                'description': 'Kategori listesinden BİREBİR bir ad, '
                    'ya da uymuyorsa boş string',
              },
            },
            'required': ['kind', 'amount', 'note', 'category'],
          },
        },
      },
      'required': ['items'],
    };

    final input = await ClaudeClient.callTool(
      content: content,
      toolName: 'record_transactions',
      toolDescription: 'Çözülen işlemleri kaydet',
      inputSchema: schema,
    );
    final items =
        (input['items'] as List? ?? const []).cast<Map<String, dynamic>>();

    return [
      for (final item in items)
        if ((item['amount'] as num?) != null && (item['amount'] as num) > 0)
          _withEnvelope(
            ParsedItem(
              kind: item['kind'] == 'income' ? 'income' : 'expense',
              amount: (item['amount'] as num).toDouble(),
              note: (item['note'] as String?)?.trim() ?? '',
            ),
            item['category'] as String? ?? '',
            envelopes,
          ),
    ];
  }

  /// AI'ın verdiği kategori adını gerçek zarfa bağlar (büyük/küçük harf
  /// duyarsız). Uymuyorsa kategorisiz kalır — "Diğer" olarak kaydedilir.
  ParsedItem _withEnvelope(
    ParsedItem item,
    String category,
    List<({String id, String name})> envelopes,
  ) {
    if (item.kind != 'expense' || category.isEmpty) return item;
    final match = envelopes
        .where((e) => e.name.toLowerCase() == category.toLowerCase())
        .firstOrNull;
    if (match == null) return item;
    return item.copyWith(envelopeId: match.id, envelopeName: match.name);
  }

  // ── Regex-фолбэк ──────────────────────────────────────────────────────

  static final _amountRe = RegExp(r'([\d.]+(?:,\d{1,2})?)');

  /// Tek işlem: metindeki İLK sayı tutar, kalan kelimeler not. Kazanç
  /// sözcükleri geçiyorsa gelir sayılır. Zarf adı metinde geçiyorsa eşle.
  List<ParsedItem> _parseWithRegex(
    String text,
    List<({String id, String name})> envelopes, [
    ({String id, String name})? Function(String text)? resolveCategory,
  ]) {
    final match = _amountRe.firstMatch(text);
    if (match == null) return const [];
    final amount = double.tryParse(
          match.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;
    if (amount <= 0) return const [];

    final note = text
        .replaceFirst(match.group(0)!, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final lower = text.toLowerCase();
    final isIncome = ['kazandım', 'kazanç', 'gelir', 'maaş', 'aldım para']
        .any(lower.contains);

    var item = ParsedItem(
      kind: isIncome ? 'income' : 'expense',
      amount: amount,
      note: note,
    );
    if (!isIncome) {
      final env = envelopes
          .where((e) => lower.contains(e.name.toLowerCase()))
          .firstOrNull;
      if (env != null) {
        item = item.copyWith(envelopeId: env.id, envelopeName: env.name);
      } else {
        // Kategori otomasyonu: nottaki işletme adı (a101, netflix...) kategori seçsin.
        final auto = resolveCategory?.call(text);
        if (auto != null) {
          item = item.copyWith(envelopeId: auto.id, envelopeName: auto.name);
        }
      }
    }
    return [item];
  }
}

/// [Envelope] listesini parser'ın beklediği hafif kayda çevirir.
extension EnvelopesForParser on List<Envelope> {
  List<({String id, String name})> forParser(String Function(Envelope) name) =>
      [for (final e in this) (id: e.id, name: name(e))];
}

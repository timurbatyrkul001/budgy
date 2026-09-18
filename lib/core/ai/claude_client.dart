import 'dart:convert';
import 'dart:io';

/// Anthropic Messages API'ye tek çağrı: zorunlu bir araçla (tool_choice)
/// yapılandırılmış çıktı alır ve aracın `input`'unu döndürür.
///
/// Anahtar derlemede verilir: `--dart-define=ANTHROPIC_API_KEY=sk-...`.
/// PROD NOTU: yayında anahtar istemciye gömülmez — çağrı Cloud Functions
/// proxy'sine taşınacak.
class ClaudeClient {
  static const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const model = 'claude-haiku-4-5';

  static bool get available => apiKey.isNotEmpty;

  /// [content]: kullanıcı mesajı blokları (text/image). Hata → fırlatır.
  static Future<Map<String, dynamic>> callTool({
    required List<Map<String, Object?>> content,
    required String toolName,
    required String toolDescription,
    required Map<String, Object?> inputSchema,
    int maxTokens = 1024,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .postUrl(Uri.parse('https://api.anthropic.com/v1/messages'));
      request.headers
        ..set('content-type', 'application/json; charset=utf-8')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', '2023-06-01');
      // UTF-8 bayt olarak yaz: request.write() Latin-1 kodlar ve "ş/ı/ğ"
      // gibi karakterlerde çağrı patlar.
      request.add(utf8.encode(jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'tools': [
          {
            'name': toolName,
            'description': toolDescription,
            'input_schema': inputSchema,
          }
        ],
        'tool_choice': {'type': 'tool', 'name': toolName},
        'messages': [
          {'role': 'user', 'content': content},
        ],
      })));
      final response =
          await request.close().timeout(const Duration(seconds: 45));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('API ${response.statusCode}');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['content'] as List)
          .firstWhere((c) => c['type'] == 'tool_use')['input']
          as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

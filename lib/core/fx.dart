import 'dart:convert';
import 'dart:io';

/// Canlı döviz kuru: 1 [from] kaç [to] eder.
/// Ücretsiz, anahtarsız kaynak (open.er-api.com). Hata olursa null döner —
/// çağıran taraf elle girişe düşer.
Future<double?> fetchFxRate(String from, String to) async {
  if (from == to) return 1;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final uri = Uri.parse('https://open.er-api.com/v6/latest/$from');
    final req = await client.getUrl(uri);
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final rates = data['rates'];
    if (rates is Map && rates[to] is num) {
      return (rates[to] as num).toDouble();
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

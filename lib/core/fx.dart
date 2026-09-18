import 'dart:convert';
import 'dart:io';

/// Bir tabana göre kur tablosu + alındığı an. Kaynak (open.er-api.com)
/// günde yaklaşık bir kez yenilenir — "canlı" değil, "güncellendi: X önce".
class FxSnapshot {
  const FxSnapshot({
    required this.base,
    required this.rates,
    required this.fetchedAt,
  });

  final String base;

  /// rates['USD'] = 1 [base] kaç USD.
  final Map<String, double> rates;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
        'base': base,
        'rates': rates,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  static FxSnapshot? fromJson(Map<String, dynamic> j) {
    final rates = j['rates'];
    final at = DateTime.tryParse(j['fetchedAt'] as String? ?? '');
    if (rates is! Map || at == null) return null;
    return FxSnapshot(
      base: j['base'] as String? ?? 'USD',
      rates: {
        for (final e in rates.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      },
      fetchedAt: at,
    );
  }
}

/// Bir tabana göre tüm kurlar (ağdan). Hata olursa null.
Future<Map<String, double>?> fetchFxRates(String base) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req =
        await client.getUrl(Uri.parse('https://open.er-api.com/v6/latest/$base'));
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final body = await resp.transform(utf8.decoder).join();
    final rates = (jsonDecode(body) as Map<String, dynamic>)['rates'];
    if (rates is! Map) return null;
    return {
      for (final e in rates.entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
    };
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Kur önbelleği: bellek + dosya (iOS: uygulama konteynerinin Caches
/// klasörü; diğerleri: sistem geçici dizini — eklenti gerektirmez).
/// Çevrimdışıyken eski tablo + zaman damgası gösterilir; hiç yoksa null.
class FxCache {
  FxCache._();

  static final _memory = <String, FxSnapshot>{};

  /// Testler geçici bir klasör verir.
  static Directory? directoryOverride;

  /// Bu kadar tazeyse ağa çıkılmaz (kaynak günde ~1 kez yenilenir).
  static const freshFor = Duration(hours: 6);

  static Directory _dir() {
    if (directoryOverride != null) return directoryOverride!;
    final home = Platform.environment['HOME'];
    if (Platform.isIOS && home != null) {
      return Directory('$home/Library/Caches');
    }
    return Directory.systemTemp;
  }

  static File _file(String base) => File('${_dir().path}/budgy_fx_$base.json');

  static Future<FxSnapshot?> read(String base) async {
    final m = _memory[base];
    if (m != null) return m;
    try {
      final f = _file(base);
      if (!await f.exists()) return null;
      final snap = FxSnapshot.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      if (snap != null) _memory[base] = snap;
      return snap;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(FxSnapshot snap) async {
    _memory[snap.base] = snap;
    try {
      final f = _file(snap.base);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(snap.toJson()));
    } catch (_) {
      // Disk yazılamadı: bellek önbelleği yeter.
    }
  }

  static void clearMemory() => _memory.clear();
}

/// Önbellek tazeyse onu, değilse ağdan yenisini; ağ yoksa eski önbelleği
/// (varsa) döndürür. [fetch] testlerde sahte kaynak için.
Future<FxSnapshot?> loadFxSnapshot(
  String base, {
  DateTime? now,
  Future<Map<String, double>?> Function(String base)? fetch,
}) async {
  final n = now ?? DateTime.now();
  final cached = await FxCache.read(base);
  if (cached != null && n.difference(cached.fetchedAt) < FxCache.freshFor) {
    return cached;
  }
  final rates = await (fetch ?? fetchFxRates)(base);
  if (rates == null || rates.isEmpty) return cached;
  final snap = FxSnapshot(base: base, rates: rates, fetchedAt: n);
  await FxCache.write(snap);
  return snap;
}

/// Canlı döviz kuru: 1 [from] kaç [to] eder (çevrim akışı). Hata → null.
Future<double?> fetchFxRate(String from, String to) async {
  if (from == to) return 1;
  final snap = await loadFxSnapshot(from);
  return snap?.rates[to];
}

/// "Güncellendi" etiketi için göreli süre: (birim, sayı).
/// birim: 'now' | 'minutes' | 'hours' | 'days'.
({String unit, int n}) updatedAgo(DateTime fetchedAt, DateTime now) {
  final d = now.difference(fetchedAt);
  if (d.inMinutes < 1) return (unit: 'now', n: 0);
  if (d.inHours < 1) return (unit: 'minutes', n: d.inMinutes);
  if (d.inDays < 1) return (unit: 'hours', n: d.inHours);
  return (unit: 'days', n: d.inDays);
}

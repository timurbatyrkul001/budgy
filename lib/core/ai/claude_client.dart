import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Sunucudaki `aiCall` fonksiyonunun tanıdığı işlem türleri. Adlar
/// Firestore'daki aylık sayaç alanlarıyla birebir aynı
/// (`users/{uid}/usage/{yyyy-MM}` → scan / parse / advice); sınırlar
/// `functions/src/limits.ts` içinde.
enum AiOp { scan, parse, advice }

/// Giriş yapılmamışken AI istendi (fonksiyon yalnız kimliği doğrulanmış
/// kullanıcıyı kabul eder).
class AiUnavailable implements Exception {
  const AiUnavailable();
}

/// Bu ayki hak bitti: sunucu `resource-exhausted` döndürdü.
/// [resetsAt] sayacın sıfırlanacağı an (UTC ay başı), sunucu gönderdiyse.
class AiLimitReached implements Exception {
  const AiLimitReached({
    required this.op,
    this.limit,
    this.used,
    this.resetsAt,
  });

  final AiOp op;
  final int? limit;
  final int? used;
  final DateTime? resetsAt;

  @override
  String toString() => 'AiLimitReached($op, $used/$limit)';
}

/// Ağ ya da sunucu tarafı geçici hata (Anthropic'e ulaşılamadı, zaman
/// aşımı, fonksiyon hatası). [code] callable hata kodu.
class AiNetworkError implements Exception {
  const AiNetworkError(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'AiNetworkError($code${message == null ? '' : ': $message'})';
}

/// Anthropic'e tek çağrı — ama telefondan değil, `aiCall` Cloud Function'ı
/// üzerinden. Anahtar cihazda yok: sunucu Secret Manager'dan okur, modeli
/// ve token tavanını kendisi sabitler, her başarılı çağrıyı kullanıcının
/// aylık sayacına işler.
///
/// Zorunlu bir araçla (tool_choice) yapılandırılmış çıktı alır ve aracın
/// `input`'unu döndürür; çağıranlar için sözleşme eskisiyle aynı.
class ClaudeClient {
  /// Callable fonksiyon adı (functions/src/index.ts → `aiCall`).
  static const functionName = 'aiCall';

  /// Fonksiyonun yayınlandığı bölge; sunucudaki `REGION` ile aynı olmalı.
  static const region = 'europe-west1';

  /// Sunucu isteği yalnız giriş yapmış kullanıcıdan kabul eder (anonim
  /// oturum da sayılır). Firebase başlatılmamışsa (birim testleri) false.
  static bool get available {
    try {
      if (Firebase.apps.isEmpty) return false;
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// [content]: kullanıcı mesajı blokları (text/image).
  ///
  /// Fırlatır: [AiUnavailable] (giriş yok), [AiLimitReached] (aylık hak
  /// bitti), [AiNetworkError] (ağ/sunucu hatası).
  static Future<Map<String, dynamic>> callTool({
    required AiOp op,
    required List<Map<String, Object?>> content,
    required String toolName,
    required String toolDescription,
    required Map<String, Object?> inputSchema,
  }) async {
    if (!available) throw const AiUnavailable();

    final callable = FirebaseFunctions.instanceFor(region: region)
        .httpsCallable(
          functionName,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );

    try {
      final result = await callable.call<Object?>({
        'op': op.name,
        'content': content,
        'tool': {
          'name': toolName,
          'description': toolDescription,
          'input_schema': inputSchema,
        },
      });
      // Platform kanalı iç içe haritaları Map<Object?, Object?> olarak
      // verir; JSON turuyla Map<String, dynamic>'e normalize ediyoruz ki
      // çağıranların `.cast<Map<String, dynamic>>()`'i patlamasın.
      final data = jsonDecode(jsonEncode(result.data));
      if (data is! Map<String, dynamic>) {
        throw const AiNetworkError('internal', 'Beklenmeyen yanıt biçimi');
      }
      final input = data['input'];
      return input is Map<String, dynamic> ? input : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw _mapError(e, op);
    }
  }

  /// Callable hata kodunu çağıranın ayırt edebileceği istisnaya çevirir.
  static Exception _mapError(FirebaseFunctionsException e, AiOp op) {
    switch (e.code) {
      case 'resource-exhausted':
        final details = e.details is Map
            ? Map<String, dynamic>.from(e.details as Map)
            : const <String, dynamic>{};
        return AiLimitReached(
          op: op,
          limit: (details['limit'] as num?)?.toInt(),
          used: (details['used'] as num?)?.toInt(),
          resetsAt: DateTime.tryParse(details['resetsAt'] as String? ?? ''),
        );
      case 'unauthenticated':
        return const AiUnavailable();
      default:
        // unavailable, deadline-exceeded, internal, invalid-argument...
        return AiNetworkError(e.code, e.message);
    }
  }
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/transactions/ai_add_sheet.dart';

import '../support/harness.dart';

/// Sesli giriş dürüst konuşur: izin reddi "bu cihazda kullanılamıyor"
/// DEĞİL — cihaz sağlam, ayara gitmeli. Tanıma sırasındaki hata da artık
/// sessizce yutulmuyor; sebebi söyleniyor.
///
/// 1.0'da AI KAPALI (pro_state.dart, kAiEnabled): [showAiAdd] hiçbir şey
/// yapmadan döner ve arayüzde bu sayfaya giden yol yok. Burası bayrağı
/// atlayıp sayfanın kendisini ([showAiAddSheet]) sınıyor — kod 1.1 için
/// duruyor ve çürümemeli. Kapalı kapının testi ai_hidden_test.dart'ta.
/// AI geri gelince [showAiAdd] üzerinden açılan hâle dönülebilir.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  // ── saf eşleme ────────────────────────────────────────────────────────

  group('voiceErrorMessage', () {
    test('izin: iOS ve Android ayrı yol; cihaz metni değil', () {
      for (final str in [Strings.tr, Strings.en, Strings.ru]) {
        final ios = voiceErrorMessage(
          str,
          'error_permission',
          hasText: false,
          platform: TargetPlatform.iOS,
        );
        final android = voiceErrorMessage(
          str,
          'error_permission',
          hasText: false,
          platform: TargetPlatform.android,
        );
        expect(ios, str.aiVoicePermission);
        expect(android, str.aiVoicePermissionAndroid);
        expect(ios, isNot(str.aiVoiceUnavailable));
        expect(ios, isNot(android));
      }
    });

    test('hiçbir şey duyulmadı: metin yoksa söyle, varsa sus', () {
      final str = Strings.tr;
      expect(
        voiceErrorMessage(str, 'error_no_match', hasText: false),
        str.aiVoiceNothingHeard,
      );
      expect(
        voiceErrorMessage(str, 'error_speech_timeout', hasText: false),
        str.aiVoiceNothingHeard,
      );
      expect(voiceErrorMessage(str, 'error_no_match', hasText: true), isNull);
    });

    test('ağ, dil, iptal, bilinmeyen', () {
      final str = Strings.en;
      expect(
        voiceErrorMessage(str, 'error_network', hasText: false),
        str.aiVoiceNetwork,
      );
      expect(
        voiceErrorMessage(str, 'error_server', hasText: false),
        str.aiVoiceNetwork,
      );
      expect(
        voiceErrorMessage(str, 'error_language_not_supported', hasText: false),
        str.aiVoiceLanguage,
      );
      expect(
        voiceErrorMessage(str, 'error_request_cancelled', hasText: false),
        isNull,
      );
      expect(
        voiceErrorMessage(str, 'error_unknown (7)', hasText: false),
        str.aiVoiceFailed,
      );
      expect(
        {
          str.aiVoiceNetwork,
          str.aiVoiceLanguage,
          str.aiVoiceFailed,
          str.aiVoiceNothingHeard,
          str.aiVoicePermission,
          str.aiVoiceUnavailable,
        }.length,
        6,
      );
    });
  });

  // ── akış ──────────────────────────────────────────────────────────────

  Future<void> openSheet(
    WidgetTester tester,
    VoiceInput voice, {
    AppLanguage language = AppLanguage.tr,
  }) async {
    await pumpBudgyScreen(
      tester,
      Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              // Bayrak kapısı olmadan: 1.0'da showAiAdd hiç açmaz.
              onPressed: () => showAiAddSheet(context),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
      db: FakeFirebaseFirestore(),
      language: language,
      extraOverrides: [voiceInputProvider.overrideWithValue(voice)],
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('izin reddi → ayar yolu (Android), cihaz metni değil', (
    tester,
  ) async {
    await openSheet(tester, _FakeVoice(available: false, permission: false));
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoicePermissionAndroid), findsOneWidget);
    expect(find.text(Strings.tr.aiVoiceUnavailable), findsNothing);
  });

  testWidgets('izin reddi → iOS ayar yolu', (tester) async {
    // Platform bayrağı test bitmeden geri alınmalı (addTearDown geç).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await openSheet(
        tester,
        _FakeVoice(available: false, permission: false),
      );
      await tapMic(tester);
      expect(find.text(Strings.tr.aiVoicePermission), findsOneWidget);
      expect(find.text(Strings.tr.aiVoiceUnavailable), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('izin var ama tanıma yok → gerçekten "bu cihazda yok"', (
    tester,
  ) async {
    await openSheet(tester, _FakeVoice(available: false, permission: true));
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoiceUnavailable), findsOneWidget);
    expect(find.text(Strings.tr.aiVoicePermissionAndroid), findsNothing);
  });

  testWidgets('dinlerken ağ hatası → söylenir, mikrofon söner', (
    tester,
  ) async {
    await openSheet(tester, _FakeVoice(errorOnListen: 'error_network'));
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoiceNetwork), findsOneWidget);
    // Dinleme durdu: durdur simgesi değil mikrofon görünür.
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  testWidgets('hiçbir şey duyulmadı → "yaklaş" metni', (tester) async {
    await openSheet(tester, _FakeVoice(errorOnListen: 'error_no_match'));
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoiceNothingHeard), findsOneWidget);
  });

  testWidgets('metin alındıktan sonra sustu → şikâyet yok, metin çözümlenir', (
    tester,
  ) async {
    await openSheet(
      tester,
      _FakeVoice(words: 'kahve 90', errorOnListen: 'error_no_match'),
    );
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoiceNothingHeard), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    // Regex yolu: "kahve 90" → bir gider kartı.
    expect(find.text('kahve 90'), findsOneWidget);
    expect(find.textContaining('90'), findsWidgets);
  });

  testWidgets('dil desteklenmiyor → ayar yolu', (tester) async {
    await openSheet(
      tester,
      _FakeVoice(errorOnListen: 'error_language_not_supported'),
    );
    await tapMic(tester);
    expect(find.text(Strings.tr.aiVoiceLanguage), findsOneWidget);
  });

  // ── üç dil: metinler şeritte taşmaz (SnackBar sarar) ─────────────────
  for (final lang in AppLanguage.values) {
    testWidgets('${lang.code}: izin metni dar ekranda taşmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 800) * 3;
      await openSheet(
        tester,
        _FakeVoice(available: false, permission: false),
        language: lang,
      );
      await tapMic(tester);
      expect(tester.takeException(), isNull);
      final str = switch (lang) {
        AppLanguage.en => Strings.en,
        AppLanguage.tr => Strings.tr,
        AppLanguage.ru => Strings.ru,
      };
      expect(find.text(str.aiVoicePermissionAndroid), findsOneWidget);
    });
  }
}

/// Sahte sesli giriş: izin/erişilebilirlik sabit; dinleme başlayınca
/// isteğe bağlı önce metin, sonra hata üretir.
class _FakeVoice implements VoiceInput {
  _FakeVoice({
    this.available = true,
    this.permission = true,
    this.words,
    this.errorOnListen,
  });

  final bool available;
  final bool permission;
  final String? words;
  final String? errorOnListen;

  void Function(String)? _onError;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String errorCode) onError,
  }) async {
    _onError = onError;
    return available;
  }

  @override
  Future<bool> get hasPermission async => permission;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words) onResult,
  }) async {
    if (words != null) onResult(words!);
    if (errorOnListen != null) _onError?.call(errorOnListen!);
  }

  @override
  Future<void> stop() async {}
}

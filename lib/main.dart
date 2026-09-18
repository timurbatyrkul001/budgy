import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/l10n.dart';
import 'features/home/preview_home.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Çökme raporlama. Debug'da kapalı: geliştirirken oluşan hatalar
  // gerçek kullanıcı çökmelerinin arasına karışmasın.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

  // Flutter framework hataları (build/layout/paint).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crashlytics.recordFlutterFatalError(details);
  };
  // Framework dışı, yakalanmamış asenkron hatalar.
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  await _activateAppCheck();

  // Desteklenen üç dilin tarih verisi (DateFormat(..., localeCode) için).
  for (final lang in AppLanguage.values) {
    await initializeDateFormatting(lang.code);
  }

  // Debug önizlemesi: örnek veriyle ana ekran (bkz. preview_home.dart).
  runApp(kPreviewHome
      ? previewHomeScope(child: const KopilkaApp())
      : const ProviderScope(child: KopilkaApp()));
}

/// App Check: Firestore'a yalnız gerçek Budgy kurulumlarından istek
/// gelmesini sağlar (çalınmış API anahtarıyla veri çekilmesini engeller).
///
/// Debug'da sahte (debug) sağlayıcı kullanılır; konsolda debug token'ı
/// kaydetmen gerekir. Yapılandırma eksikse uygulama ÇALIŞMAYA DEVAM eder —
/// App Check zorlaması Firebase Console'dan açılana kadar isteğe bağlıdır.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      // App Attest Firebase'in önerdiği sağlayıcı; iOS 14 altı cihazlarda
      // (min hedefimiz 15 olsa da) Device Check'e düşer.
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (error, stack) {
    // Ağ yok / proje yapılandırılmamış: uygulamayı açılışta düşürme.
    await FirebaseCrashlytics.instance
        .recordError(error, stack, reason: 'appCheck', fatal: false);
  }
}

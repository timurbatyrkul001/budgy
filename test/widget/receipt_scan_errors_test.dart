import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/ai/expense_parser.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/transactions/receipt_scan.dart';

import '../support/harness.dart';

/// Fiş tarama dürüst konuşur: kamera/fotoğraf izni reddi "fiş okunamadı"
/// DEĞİL; AI hakkı bitti / ağ yok / giriş yok da değil. Her hâlin kendi
/// metni var, yalnız bilinmeyen hata genel metne düşer.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  // 1×1 saydam PNG — Image.memory gerçek bir görsel çözebilsin.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  // ── saf eşlemeler ─────────────────────────────────────────────────────

  group('pickerErrorMessage', () {
    PlatformException pe(String code) => PlatformException(code: code);

    test('kamera reddi: iOS ve Android ayrı ayar yolu', () {
      for (final rs in [RS.tr, RS.en, RS.ru]) {
        expect(
          pickerErrorMessage(
            rs,
            pe('camera_access_denied'),
            ImageSource.camera,
            platform: TargetPlatform.iOS,
          ),
          rs.cameraDenied,
        );
        expect(
          pickerErrorMessage(
            rs,
            pe('camera_access_denied'),
            ImageSource.camera,
            platform: TargetPlatform.android,
          ),
          rs.cameraDeniedAndroid,
        );
        expect(rs.cameraDenied, isNot(rs.scanFailed));
        expect(rs.cameraDenied, isNot(rs.cameraDeniedAndroid));
      }
    });

    test('fotoğraf reddi, kısıtlama, kamerasız cihaz: hepsi farklı', () {
      final rs = RS.tr;
      final texts = {
        'photo_access_denied': rs.photosDenied,
        'photo_access_restricted': rs.photosRestricted,
        'camera_access_restricted': rs.cameraRestricted,
        'no_available_camera': rs.cameraUnavailable,
      };
      for (final e in texts.entries) {
        expect(
          pickerErrorMessage(
            rs,
            pe(e.key),
            ImageSource.gallery,
            platform: TargetPlatform.iOS,
          ),
          e.value,
        );
        expect(e.value, isNot(rs.scanFailed));
      }
      expect(texts.values.toSet().length, texts.length);
    });

    test('bilinmeyen hata → genel metin', () {
      expect(
        pickerErrorMessage(RS.tr, pe('weird'), ImageSource.camera),
        RS.tr.scanFailed,
      );
      expect(
        pickerErrorMessage(RS.tr, StateError('x'), ImageSource.camera),
        RS.tr.scanFailed,
      );
    });
  });

  group('receiptErrorMessage', () {
    test('hak bitti: unutulmuş aiLimitReached metni kullanılır', () {
      for (final rs in [RS.tr, RS.en, RS.ru]) {
        expect(
          receiptErrorMessage(
            rs,
            const AiLimitReached(op: AiOp.scan),
            'tr',
          ),
          rs.aiLimitReached,
        );
      }
    });

    test('hak bitti + sıfırlanma tarihi: tarih metinde', () {
      final resetsAt = DateTime.utc(2026, 11, 1);
      final msg = receiptErrorMessage(
        RS.tr,
        AiLimitReached(op: AiOp.scan, resetsAt: resetsAt),
        'tr',
      );
      expect(msg, contains('1 Kasım'));
      expect(msg, isNot(contains('{date}')));
      final ru = receiptErrorMessage(
        RS.ru,
        AiLimitReached(op: AiOp.scan, resetsAt: resetsAt),
        'ru',
      );
      expect(ru, contains('1 ноября'));
    });

    test('ağ hatası / giriş yok / bilinmeyen: üç ayrı metin', () {
      final rs = RS.en;
      final net = receiptErrorMessage(rs, const AiNetworkError('unavailable'), 'en');
      final auth = receiptErrorMessage(rs, const AiUnavailable(), 'en');
      final other = receiptErrorMessage(rs, StateError('x'), 'en');
      expect(net, rs.aiNetworkError);
      expect(auth, rs.aiKeyMissing);
      expect(other, rs.scanFailed);
      expect({net, auth, other, rs.aiLimitReached}.length, 4);
    });
  });

  // ── akış ──────────────────────────────────────────────────────────────

  Future<void> pumpScan(
    WidgetTester tester, {
    required ImagePicker picker,
    ExpenseParser? parser,
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) => pumpBudgyScreen(
    tester,
    Scaffold(
      body: Center(
        child: Consumer(
          builder: (context, ref, _) {
            // Gerçek uygulamada kök ekran dil sağlayıcısını canlı tutar;
            // burada da öyle olsun ki `ref.read(rsProvider)` güncel dili
            // versin (yoksa akış ilk okumada İngilizce'ye düşer).
            ref.watch(rsProvider);
            return TextButton(
              onPressed: () => pickAndScanReceipt(context, ref),
              child: const Text('aç'),
            );
          },
        ),
      ),
    ),
    db: FakeFirebaseFirestore(),
    language: language,
    logicalSize: Size(width, 800),
    extraOverrides: [
      imagePickerProvider.overrideWithValue(picker),
      if (parser != null) receiptParserProvider.overrideWithValue(parser),
    ],
  );

  Future<void> choose(WidgetTester tester, String source) async {
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(source));
    await tester.pumpAndSettle();
  }

  group('fotoğraf seçimi', () {
    testWidgets('kamera izni reddi → ayar yolu, "fiş okunamadı" değil', (
      tester,
    ) async {
      await pumpScan(
        tester,
        picker: _FakePicker(error: PlatformException(code: 'camera_access_denied')),
      );
      await choose(tester, RS.tr.camera);
      // Testte platform Android sayılır.
      expect(find.text(RS.tr.cameraDeniedAndroid), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
    });

    testWidgets('iOS: kamera izni reddi iOS ayar yolunu söyler', (
      tester,
    ) async {
      // Platform bayrağı test bitmeden geri alınmalı (addTearDown geç).
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpScan(
          tester,
          picker: _FakePicker(
            error: PlatformException(code: 'camera_access_denied'),
          ),
        );
        await choose(tester, RS.tr.camera);
        expect(find.text(RS.tr.cameraDenied), findsOneWidget);
        expect(find.text(RS.tr.cameraDeniedAndroid), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('fotoğraf izni reddi → kendi metni', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpScan(
          tester,
          picker: _FakePicker(
            error: PlatformException(code: 'photo_access_denied'),
          ),
        );
        await choose(tester, RS.tr.gallery);
        expect(find.text(RS.tr.photosDenied), findsOneWidget);
        expect(find.text(RS.tr.scanFailed), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('kamerasız cihaz → galeriye yönlendirir', (tester) async {
      await pumpScan(
        tester,
        picker: _FakePicker(error: PlatformException(code: 'no_available_camera')),
      );
      await choose(tester, RS.tr.camera);
      expect(find.text(RS.tr.cameraUnavailable), findsOneWidget);
    });

    testWidgets('bilinmeyen seçici hatası → eski genel metin', (
      tester,
    ) async {
      await pumpScan(tester, picker: _FakePicker(error: StateError('boom')));
      await choose(tester, RS.tr.camera);
      expect(find.text(RS.tr.scanFailed), findsOneWidget);
    });

    testWidgets('vazgeçti (null) → hiçbir şey söylenmez', (tester) async {
      await pumpScan(tester, picker: _FakePicker());
      await choose(tester, RS.tr.camera);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('AI okuma', () {
    final file = XFile.fromData(Uint8List.fromList(png), path: 'fis.png');

    Future<void> scanWith(
      WidgetTester tester,
      ExpenseParser parser, {
      AppLanguage language = AppLanguage.tr,
      double width = 360,
    }) async {
      await pumpScan(
        tester,
        picker: _FakePicker(file: file),
        parser: parser,
        language: language,
        width: width,
      );
      await choose(tester, RS.of(language.code).gallery);
    }

    testWidgets('hak bitti → aiLimitReached; yeniden çekmeye çağırmaz', (
      tester,
    ) async {
      await scanWith(
        tester,
        _FakeParser(error: const AiLimitReached(op: AiOp.scan)),
      );
      expect(find.text(RS.tr.aiLimitReached), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
      expect(find.text(RS.tr.scanNoTotal), findsNothing);
    });

    testWidgets('hak bitti + tarih → tarihli metin', (tester) async {
      await scanWith(
        tester,
        _FakeParser(
          error: AiLimitReached(
            op: AiOp.scan,
            resetsAt: DateTime.utc(2026, 11, 1),
          ),
        ),
      );
      expect(find.textContaining('1 Kasım'), findsOneWidget);
      expect(find.text(RS.tr.aiLimitReached), findsNothing);
    });

    testWidgets('ağ yok → aiNetworkError', (tester) async {
      await scanWith(
        tester,
        _FakeParser(error: const AiNetworkError('unavailable')),
      );
      expect(find.text(RS.tr.aiNetworkError), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
    });

    testWidgets('giriş yok → aiKeyMissing', (tester) async {
      await scanWith(tester, _FakeParser(error: const AiUnavailable()));
      expect(find.text(RS.tr.aiKeyMissing), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
    });

    testWidgets('AI toplam bulamadı (boş liste) → "fişin tamamı karede"', (
      tester,
    ) async {
      await scanWith(tester, _FakeParser());
      expect(find.text(RS.tr.scanNoTotal), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
    });

    testWidgets('bilinmeyen hata → eski genel metin', (tester) async {
      await scanWith(tester, _FakeParser(error: StateError('boom')));
      expect(find.text(RS.tr.scanFailed), findsOneWidget);
    });

    testWidgets('başarılı okuma → hata metni yok, kaydet düğmesi açık', (
      tester,
    ) async {
      await scanWith(
        tester,
        _FakeParser(
          items: const [
            ParsedItem(kind: 'expense', amount: 149.9, note: 'Migros'),
          ],
        ),
      );
      expect(find.text(RS.tr.scanNoTotal), findsNothing);
      expect(find.text(RS.tr.scanFailed), findsNothing);
      // Kart: "Migros · Zarfsız" — not ve kategori birlikte.
      expect(find.textContaining('Migros'), findsOneWidget);
    });

    // ── dar ekran × dil: en uzun hata metni sayfada taşmıyor ────────────
    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets('${width.toInt()}dp · ${lang.code}: hata sayfası taşmaz', (
          tester,
        ) async {
          await scanWith(
            tester,
            _FakeParser(
              error: AiLimitReached(
                op: AiOp.scan,
                resetsAt: DateTime.utc(2026, 11, 1),
              ),
            ),
            language: lang,
            width: width,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(SnackBar), findsNothing);

          // Boş sonuç metni de (en uzun kırmızı metin) sığmalı.
          await tester.tap(find.byIcon(Icons.close_rounded).first,
              warnIfMissed: false);
          await tester.pumpAndSettle();
          await pumpScan(
            tester,
            picker: _FakePicker(file: file),
            parser: _FakeParser(),
            language: lang,
            width: width,
          );
          await choose(tester, RS.of(lang.code).gallery);
          expect(tester.takeException(), isNull);
          expect(find.text(RS.of(lang.code).scanNoTotal), findsOneWidget);
        });
      }
    }
  });
}

/// Sahte fotoğraf seçici: ya fırlatır, ya dosya döner, ya null (vazgeçti).
class _FakePicker extends ImagePicker {
  _FakePicker({this.error, this.file});

  final Object? error;
  final XFile? file;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (error != null) throw error!;
    return file;
  }
}

/// Sahte fiş okuyucu: ya fırlatır, ya verilen listeyi döner.
class _FakeParser extends ExpenseParser {
  _FakeParser({this.error, this.items = const []});

  final Object? error;
  final List<ParsedItem> items;

  @override
  Future<List<ParsedItem>> parseReceipt(
    Uint8List bytes, {
    required String mediaType,
    required List<({String id, String name})> envelopes,
    String languageCode = 'tr',
  }) async {
    if (error != null) throw error!;
    return items;
  }
}

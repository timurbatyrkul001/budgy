import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/image_picking.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/settings/settings_edit_avatar_screen.dart';
import 'package:kopilka_app/features/settings/settings_personal_details_screen.dart';
import 'package:kopilka_app/features/space/space.dart';
import 'package:kopilka_app/features/space/space_photo.dart';

import '../support/harness.dart';

/// Avatar fotoğrafı: kalem DOĞRUDAN galeriyi açar (kaynak sayfası yok,
/// kamera yok); seçilen fotoğraf küçültülüp base64 olarak profil belgesine
/// (`spacePhoto`) yazılır ve her avatar noktasında çizilir. Sınırı aşan
/// fotoğraf yazılmaz; izin reddi kendi metnini alır; çöp kutusu fotoğrafı
/// da kaldırır; fotoğrafı olmayan eski görünümü aynen görür.
///
/// Bu akış AI bayrağından ([kAiEnabled]) bağımsız — burada bayrak hiç
/// okunmaz ve AI kapalıyken de geçmeli.
void main() {
  const settingsPath = 'users/$testUid/settings/main';

  Future<Map<String, dynamic>> readSettings(FakeFirebaseFirestore db) async =>
      (await db.doc(settingsPath).get()).data() ?? const {};

  FilledButton saveButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        ),
      );

  // 1×1 saydam PNG — gerçek, çözülebilir bir görsel.
  final tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );
  final tinyB64 = base64Encode(tinyPng);

  final preview = find.byKey(const ValueKey('editAvatar.preview'));
  final styleButton = find.byKey(const ValueKey('editAvatar.style'));
  final blue = Ex.spaceColors[1].toARGB32();
  final profile = {
    'spaceName': 'Ev',
    'spaceColor': blue,
    'spaceIcon': 'home',
  };

  SpaceInfo previewSpace(WidgetTester tester) =>
      tester.widget<SpaceAvatar>(preview).space;

  Future<void> pumpAvatar(
    WidgetTester tester, {
    required _FakePicker picker,
    FakeFirebaseFirestore? db,
    Map<String, dynamic>? profile,
    AppLanguage language = AppLanguage.tr,
    double width = 360,
  }) => pumpBudgyScreen(
    tester,
    const SettingsEditAvatarScreen(),
    db: db ?? FakeFirebaseFirestore(),
    language: language,
    profile: profile ?? const {},
    logicalSize: Size(width, 800),
    extraOverrides: [imagePickerProvider.overrideWithValue(picker)],
  );

  Future<void> tapPencil(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
  }

  // ── saf: sıkıştırma ve sınır ─────────────────────────────────────────

  group('encodeSpacePhoto', () {
    test('sınırlar: 256 px, 50 KB base64', () {
      expect(kSpacePhotoSide, lessThanOrEqualTo(256));
      expect(kSpacePhotoMaxChars, 50 * 1024);
    });

    testWidgets('küçük görsel olduğu gibi döner', (tester) async {
      await tester.runAsync(() async {
        expect(await encodeSpacePhoto(tinyPng), tinyB64);
      });
    });

    testWidgets('sınırı aşan ama çözülemeyen veri → null (yazılmaz)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final junk = Uint8List.fromList(
          List.generate(60 * 1024, (i) => (i * 31) & 0xff),
        );
        expect(base64Encode(junk).length, greaterThan(kSpacePhotoMaxChars));
        expect(await encodeSpacePhoto(junk), isNull);
      });
    });

    testWidgets('sınırı aşan gerçek görsel küçültülerek sığdırılır', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Gürültü PNG sıkışmaz: 256×256 ≈ 190 KB → base64 sınırın çok üstü.
        final noisy = await _noisePng(256, 256);
        expect(base64Encode(noisy).length, greaterThan(kSpacePhotoMaxChars));
        final out = await encodeSpacePhoto(noisy);
        expect(out, isNotNull);
        expect(out!.length, lessThanOrEqualTo(kSpacePhotoMaxChars));
        // Sonuç hâlâ çözülebilir bir görsel ve oran korunmuş (kare).
        final codec = await ui.instantiateImageCodec(base64Decode(out));
        final frame = await codec.getNextFrame();
        expect(frame.image.width, frame.image.height);
        expect(frame.image.width, lessThan(256));
      });
    });

    testWidgets('dikdörtgen görselde oran korunur', (tester) async {
      await tester.runAsync(() async {
        final noisy = await _noisePng(256, 128);
        final out = await encodeSpacePhoto(noisy);
        expect(out, isNotNull);
        final codec = await ui.instantiateImageCodec(base64Decode(out!));
        final frame = await codec.getNextFrame();
        expect(frame.image.width, frame.image.height * 2);
      });
    });
  });

  group('decodeSpacePhoto', () {
    test('boş → null; bozuk → null; aynı metin → aynı bayt nesnesi', () {
      expect(decodeSpacePhoto(''), isNull);
      expect(decodeSpacePhoto('%%%not base64%%%'), isNull);
      final a = decodeSpacePhoto(tinyB64);
      final b = decodeSpacePhoto(String.fromCharCodes(tinyB64.codeUnits));
      expect(a, isNotNull);
      expect(identical(a, b), isTrue, reason: 'Image.memory önbelleği için');
      expect(a, tinyPng);
    });

    test('SpaceInfo: profil ↔ model, copyWith, fromProfile', () {
      final info = SpaceInfo.fromProfile({
        ...profile,
        'spacePhoto': tinyB64,
      }, RS.tr);
      expect(info.photo, tinyB64);
      expect(info.photoBytes, tinyPng);
      expect(info.toProfile()['spacePhoto'], tinyB64);
      expect(info.copyWith(photo: '').photo, '');
      expect(info.copyWith(icon: 'star').photo, tinyB64);
      // Alan yoksa (eski kullanıcı) fotoğraf yok.
      final old = SpaceInfo.fromProfile(profile, RS.tr);
      expect(old.photo, '');
      expect(old.photoBytes, isNull);
    });
  });

  group('pickerErrorMessage', () {
    test('fallback verilince bilinmeyen hata "fiş okunamadı" olmaz', () {
      for (final rs in [RS.tr, RS.en, RS.ru]) {
        final msg = pickerErrorMessage(
          rs,
          StateError('x'),
          ImageSource.gallery,
          fallback: rs.editAvatarPhotoFailed,
        );
        expect(msg, rs.editAvatarPhotoFailed);
        expect(msg, isNot(rs.scanFailed));
        // Tanınan kodlar fallback'ten etkilenmez.
        expect(
          pickerErrorMessage(
            rs,
            PlatformException(code: 'photo_access_denied'),
            ImageSource.gallery,
            platform: TargetPlatform.iOS,
            fallback: rs.editAvatarPhotoFailed,
          ),
          rs.photosDenied,
        );
      }
    });
  });

  // ── çizim: SpaceAvatar ────────────────────────────────────────────────

  group('SpaceAvatar', () {
    Future<void> pumpAvatarWidget(WidgetTester tester, SpaceInfo space) =>
        tester.pumpWidget(
          MaterialApp(
            home: Center(child: SpaceAvatar(space: space, size: 40)),
          ),
        );

    testWidgets('fotoğraf yokken eski görünüm: renk zemin + simge', (
      tester,
    ) async {
      await pumpAvatarWidget(
        tester,
        SpaceInfo(name: 'Ev', color: blue, icon: 'home'),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(kSpaceIcons['home']!), findsOneWidget);
    });

    testWidgets('fotoğraf yok, simge yok → baş harf', (tester) async {
      await pumpAvatarWidget(tester, SpaceInfo(name: 'Ev', color: blue));
      expect(find.byType(Image), findsNothing);
      expect(find.text('E'), findsOneWidget);
    });

    testWidgets('fotoğraf varken simge ve harf yerine görsel; cover + kırpma', (
      tester,
    ) async {
      await pumpAvatarWidget(
        tester,
        SpaceInfo(name: 'Ev', color: blue, icon: 'home', photo: tinyB64),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover, reason: 'esnemez, doldurur');
      expect(image.width, 40);
      expect(image.height, 40);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byIcon(kSpaceIcons['home']!), findsNothing);
      expect(find.text('E'), findsNothing);
    });

    testWidgets('bozuk base64 → sessizce simgeye düşer', (tester) async {
      await pumpAvatarWidget(
        tester,
        SpaceInfo(name: 'Ev', color: blue, icon: 'home', photo: '***'),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(kSpaceIcons['home']!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kişisel bilgiler başlığı fotoğrafı gösterir', (tester) async {
      await pumpBudgyScreen(
        tester,
        const SettingsPersonalDetailsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        profile: {...profile, 'spacePhoto': tinyB64},
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(SpaceAvatar), matching: find.byType(Image)),
        findsOneWidget,
      );
    });
  });

  // ── akış: avatar ekranı ───────────────────────────────────────────────

  group('kalem → galeri', () {
    testWidgets('kalem doğrudan galeriyi açar; kaynak sayfası yok', (
      tester,
    ) async {
      final picker = _FakePicker();
      await pumpAvatar(tester, picker: picker, profile: profile);
      await tapPencil(tester);
      expect(picker.calls, hasLength(1));
      final call = picker.calls.single;
      expect(call.source, ImageSource.gallery);
      expect(call.maxWidth, lessThanOrEqualTo(256));
      expect(call.maxHeight, lessThanOrEqualTo(256));
      expect(call.imageQuality, isNotNull);
      expect(call.imageQuality, lessThan(100));
      // Arada "kamera / galeri" sayfası açılmadı.
      expect(find.text(RS.tr.camera), findsNothing);
      expect(find.text(RS.tr.gallery), findsNothing);
      expect(find.text(RS.tr.scanTitle), findsNothing);
    });

    testWidgets('seçilen fotoğraf önizlemeye düşer, Kaydet yazar', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpAvatar(
        tester,
        picker: _FakePicker(file: XFile.fromData(tinyPng, path: 'a.png')),
        db: db,
        profile: profile,
      );
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
      await tapPencil(tester);
      expect(previewSpace(tester).photo, tinyB64);
      expect(
        find.descendant(of: preview, matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        (await readSettings(db)).containsKey('spacePhoto'),
        isFalse,
        reason: 'Kaydet basılmadan yazılmaz',
      );
      expect(saveButton(tester, RS.tr.save).onPressed, isNotNull);
      await tester.tap(find.text(RS.tr.save));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spacePhoto'], tinyB64);
      expect(data['spaceColor'], blue, reason: 'renk korunur');
      expect(data['spaceIcon'], 'home', reason: 'simge korunur');
      expect(data.containsKey('spaceName'), isFalse);
    });

    testWidgets('aynı fotoğraf zaten kayıtlıysa Kaydet sönük kalır', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        picker: _FakePicker(file: XFile.fromData(tinyPng, path: 'a.png')),
        profile: {...profile, 'spacePhoto': tinyB64},
      );
      await tapPencil(tester);
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
    });

    testWidgets('çok büyük fotoğraf yazılmaz; sebebi söylenir', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      final junk = Uint8List.fromList(
        List.generate(60 * 1024, (i) => (i * 31) & 0xff),
      );
      await pumpAvatar(
        tester,
        picker: _FakePicker(file: XFile.fromData(junk, path: 'big.png')),
        db: db,
        profile: profile,
      );
      await tapPencil(tester);
      expect(find.text(RS.tr.editAvatarPhotoTooBig), findsOneWidget);
      expect(previewSpace(tester).photo, '');
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
      expect(await readSettings(db), isEmpty);
    });

    testWidgets('iOS: fotoğraf izni reddi → iOS ayar yolu, genel metin değil', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpAvatar(
          tester,
          picker: _FakePicker(
            error: PlatformException(code: 'photo_access_denied'),
          ),
          profile: profile,
        );
        await tapPencil(tester);
        expect(find.text(RS.tr.photosDenied), findsOneWidget);
        expect(find.text(RS.tr.photosDeniedAndroid), findsNothing);
        expect(find.text(RS.tr.scanFailed), findsNothing);
        expect(find.text(RS.tr.editAvatarPhotoFailed), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android: fotoğraf izni reddi → Android ayar yolu', (
      tester,
    ) async {
      // Testte platform Android sayılır.
      await pumpAvatar(
        tester,
        picker: _FakePicker(
          error: PlatformException(code: 'photo_access_denied'),
        ),
        profile: profile,
      );
      await tapPencil(tester);
      expect(find.text(RS.tr.photosDeniedAndroid), findsOneWidget);
    });

    testWidgets('ebeveyn kısıtı → kendi metni', (tester) async {
      await pumpAvatar(
        tester,
        picker: _FakePicker(
          error: PlatformException(code: 'photo_access_restricted'),
        ),
        profile: profile,
      );
      await tapPencil(tester);
      expect(find.text(RS.tr.photosRestricted), findsOneWidget);
    });

    testWidgets('bilinmeyen seçici hatası → "fotoğraf alınamadı", fiş değil', (
      tester,
    ) async {
      await pumpAvatar(
        tester,
        picker: _FakePicker(error: StateError('boom')),
        profile: profile,
      );
      await tapPencil(tester);
      expect(find.text(RS.tr.editAvatarPhotoFailed), findsOneWidget);
      expect(find.text(RS.tr.scanFailed), findsNothing);
    });

    testWidgets('vazgeçti (null) → hiçbir şey değişmez', (tester) async {
      await pumpAvatar(tester, picker: _FakePicker(), profile: profile);
      await tapPencil(tester);
      expect(find.byType(SnackBar), findsNothing);
      expect(previewSpace(tester).photo, '');
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
    });
  });

  group('fotoğraf ile birlikte', () {
    testWidgets('çöp kutusu fotoğrafı da kaldırır ve hemen yazar', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpAvatar(
        tester,
        picker: _FakePicker(),
        db: db,
        profile: {...profile, 'spacePhoto': tinyB64},
      );
      await tester.pumpAndSettle();
      expect(previewSpace(tester).photo, tinyB64);
      await tester.tap(find.byIcon(Icons.delete_rounded));
      await tester.pumpAndSettle();
      // Diyalog fotoğrafın da gideceğini söyler.
      expect(find.text(RS.tr.editAvatarResetBodyPhoto), findsOneWidget);
      expect(find.text(RS.tr.editAvatarResetBody), findsNothing);
      await tester.tap(find.text(RS.tr.editAvatarResetConfirm));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spacePhoto'], '');
      expect(data['spaceIcon'], '');
      expect(data['spaceColor'], SettingsEditAvatarScreen.defaultColor);
      expect(previewSpace(tester).photo, '');
      expect(
        find.descendant(of: preview, matching: find.byType(Image)),
        findsNothing,
      );
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
    });

    testWidgets('fotoğraf yokken sıfırlama diyaloğu eski metni gösterir', (
      tester,
    ) async {
      await pumpAvatar(tester, picker: _FakePicker(), profile: profile);
      await tester.tap(find.byIcon(Icons.delete_rounded));
      await tester.pumpAndSettle();
      expect(find.text(RS.tr.editAvatarResetBody), findsOneWidget);
      expect(find.text(RS.tr.editAvatarResetBodyPhoto), findsNothing);
    });

    testWidgets('renk + simge hâlâ seçilebilir; seçim fotoğrafı düşürür', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpAvatar(
        tester,
        picker: _FakePicker(),
        db: db,
        profile: {...profile, 'spacePhoto': tinyB64},
      );
      await tester.pumpAndSettle();
      await tester.tap(styleButton);
      await tester.pumpAndSettle();
      expect(find.text(RS.tr.editAvatarPickTitle), findsOneWidget);
      await tester.tap(find.byIcon(kSpaceIcons['star']!));
      await tester.pump();
      expect(previewSpace(tester).icon, 'star');
      expect(previewSpace(tester).photo, '', reason: 'simge görünsün diye');
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: preview, matching: find.byType(Image)),
        findsNothing,
      );
      expect(saveButton(tester, RS.tr.save).onPressed, isNotNull);
      await tester.tap(find.text(RS.tr.save));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spacePhoto'], '');
      expect(data['spaceIcon'], 'star');
    });

    testWidgets('fotoğraftan sonra renk seçmek de fotoğrafı düşürür', (
      tester,
    ) async {
      final purple = Ex.spaceColors[2].toARGB32();
      await pumpAvatar(
        tester,
        picker: _FakePicker(file: XFile.fromData(tinyPng, path: 'a.png')),
        profile: profile,
      );
      await tapPencil(tester);
      expect(previewSpace(tester).photo, tinyB64);
      await tester.tap(styleButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('editAvatar.color.$purple')));
      await tester.pump();
      expect(previewSpace(tester).color, purple);
      expect(previewSpace(tester).photo, '');
    });
  });

  // ── yerleşim: 320/360 dp × TR/EN/RU, fotoğraf varken ─────────────────
  group('yerleşim', () {
    for (final width in [320.0, 360.0]) {
      for (final lang in AppLanguage.values) {
        testWidgets('${width.toInt()}dp · ${lang.code}: fotoğraflı ekran taşmaz', (
          tester,
        ) async {
          final junk = Uint8List.fromList(
            List.generate(60 * 1024, (i) => (i * 31) & 0xff),
          );
          await pumpAvatar(
            tester,
            picker: _FakePicker(file: XFile.fromData(junk, path: 'big.png')),
            profile: {...profile, 'spacePhoto': tinyB64},
            language: lang,
            width: width,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('editAvatar.style')), findsOneWidget);
          // En uzun hata şeridi sığsın.
          await tapPencil(tester);
          expect(tester.takeException(), isNull);
          expect(
            find.text(RS.of(lang.code).editAvatarPhotoTooBig),
            findsOneWidget,
          );
          // Fotoğraflı sıfırlama diyaloğu (en uzun metin) sığsın.
          await tester.tap(find.byIcon(Icons.delete_rounded));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(RS.of(lang.code).editAvatarResetBodyPhoto),
            findsOneWidget,
          );
        });
      }
    }
  });
}

/// Sahte fotoğraf seçici: ya fırlatır, ya dosya döner, ya null (vazgeçti);
/// her çağrının parametrelerini kaydeder (kaynak, boyut, kalite).
class _FakePicker extends ImagePicker {
  _FakePicker({this.error, this.file});

  final Object? error;
  final XFile? file;
  final calls = <_PickCall>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add(_PickCall(source, maxWidth, maxHeight, imageQuality));
    if (error != null) throw error!;
    return file;
  }
}

class _PickCall {
  const _PickCall(this.source, this.maxWidth, this.maxHeight, this.imageQuality);
  final ImageSource source;
  final double? maxWidth;
  final double? maxHeight;
  final int? imageQuality;
}

/// Rastgele piksellerden PNG — sıkışmaz, boyut sınırını aşmak için.
Future<Uint8List> _noisePng(int w, int h) async {
  final rnd = Random(7);
  final pixels = Uint8List(w * h * 4);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = (i % 4 == 3) ? 0xff : rnd.nextInt(256);
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

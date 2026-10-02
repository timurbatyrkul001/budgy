import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/core/redesign_l10n.dart';
import 'package:kopilka_app/features/settings/settings_edit_avatar_screen.dart';
import 'package:kopilka_app/features/settings/settings_edit_name_screen.dart';
import 'package:kopilka_app/features/settings/settings_personal_details_screen.dart';
import 'package:kopilka_app/features/space/space.dart';

import '../support/harness.dart';

/// Kişisel bilgiler › Ad / Avatar düzenleme ekranları.
///
/// Profil [profileProvider] ile sabit besleniyor (harness); yazmalar sahte
/// Firestore'daki `users/<uid>/settings/main` belgesinden okunur — ekranın
/// yeniden çizilmesine değil, gerçekten ne yazıldığına bakıyoruz.
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

  // ── Ad ─────────────────────────────────────────────────────────────────
  group('ad', () {
    final firstField = find.byKey(const ValueKey('editName.first'));
    final lastField = find.byKey(const ValueKey('editName.last'));

    test('splitName / joinName: ilk boşluktan böler, boşları atlar', () {
      expect(SettingsEditNameScreen.splitName('Ali Veli Can'), (
        'Ali',
        'Veli Can',
      ));
      expect(SettingsEditNameScreen.splitName('Ali'), ('Ali', ''));
      expect(SettingsEditNameScreen.splitName('  Ali   Veli '), (
        'Ali',
        'Veli',
      ));
      expect(SettingsEditNameScreen.splitName(''), ('', ''));
      expect(SettingsEditNameScreen.splitName('   '), ('', ''));
      expect(SettingsEditNameScreen.joinName('Ali', 'Veli'), 'Ali Veli');
      expect(SettingsEditNameScreen.joinName('Ali', ''), 'Ali');
      expect(SettingsEditNameScreen.joinName('', 'Veli'), 'Veli');
      expect(SettingsEditNameScreen.joinName(' ', ' '), '');
    });

    testWidgets('mevcut ad iki alana bölünmüş açılır; Kaydet pasif', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const SettingsEditNameScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        profile: const {'name': 'Timur Batyrkul'},
      );
      final rs = RS.tr;
      expect(find.text(rs.editNameTitle), findsOneWidget);
      expect(find.text(rs.editNameFirst), findsOneWidget);
      expect(find.text(rs.editNameLast), findsOneWidget);
      expect(tester.widget<TextField>(firstField).controller!.text, 'Timur');
      expect(tester.widget<TextField>(lastField).controller!.text, 'Batyrkul');
      expect(
        saveButton(tester, rs.save).onPressed,
        isNull,
        reason: 'değişiklik yokken Kaydet pasif',
      );
    });

    testWidgets(
      'düzenleyince Kaydet açılır ve birleşik ad Firestore\'a yazılır',
      (tester) async {
        final db = FakeFirebaseFirestore();
        await pumpBudgyScreen(
          tester,
          const SettingsEditNameScreen(),
          db: db,
          language: AppLanguage.tr,
          profile: const {'name': 'Timur Batyrkul'},
        );
        final rs = RS.tr;
        await tester.enterText(lastField, 'Batyrkulov');
        await tester.pump();
        expect(saveButton(tester, rs.save).onPressed, isNotNull);
        await tester.tap(find.text(rs.save));
        await tester.pumpAndSettle();
        expect((await readSettings(db))['name'], 'Timur Batyrkulov');
      },
    );

    testWidgets('aynı değere geri yazınca Kaydet yeniden söner', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const SettingsEditNameScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.en,
        profile: const {'name': 'Timur Batyrkul'},
      );
      await tester.enterText(firstField, 'Timurx');
      await tester.pump();
      expect(saveButton(tester, RS.en.save).onPressed, isNotNull);
      await tester.enterText(firstField, 'Timur');
      await tester.pump();
      expect(saveButton(tester, RS.en.save).onPressed, isNull);
    });

    testWidgets('tek kelimelik ad: soyad boş, soyad eklenince birleşir', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditNameScreen(),
        db: db,
        language: AppLanguage.en,
        profile: const {'name': 'Timur'},
      );
      expect(tester.widget<TextField>(firstField).controller!.text, 'Timur');
      expect(tester.widget<TextField>(lastField).controller!.text, '');
      expect(saveButton(tester, RS.en.save).onPressed, isNull);
      await tester.enterText(lastField, 'Batyrkul');
      await tester.pump();
      await tester.tap(find.text(RS.en.save));
      await tester.pumpAndSettle();
      expect((await readSettings(db))['name'], 'Timur Batyrkul');
    });

    testWidgets('boş ad kaydedilebilir', (tester) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditNameScreen(),
        db: db,
        language: AppLanguage.ru,
        profile: const {'name': 'Timur Batyrkul'},
      );
      await tester.enterText(firstField, '');
      await tester.enterText(lastField, '');
      await tester.pump();
      expect(saveButton(tester, RS.ru.save).onPressed, isNotNull);
      await tester.tap(find.text(RS.ru.save));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data.containsKey('name'), isTrue);
      expect(data['name'], '');
    });

    testWidgets('profilde ad yoksa iki alan boş açılır', (tester) async {
      await pumpBudgyScreen(
        tester,
        const SettingsEditNameScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
      );
      expect(tester.widget<TextField>(firstField).controller!.text, '');
      expect(tester.widget<TextField>(lastField).controller!.text, '');
      expect(saveButton(tester, RS.tr.save).onPressed, isNull);
    });
  });

  // ── Avatar ─────────────────────────────────────────────────────────────
  group('avatar', () {
    final preview = find.byKey(const ValueKey('editAvatar.preview'));
    final blue = Ex.spaceColors[1].toARGB32();
    final purple = Ex.spaceColors[2].toARGB32();
    final profile = {
      'spaceName': 'Ev',
      'spaceColor': blue,
      'spaceIcon': 'home',
    };

    SpaceInfo previewSpace(WidgetTester tester) =>
        tester.widget<SpaceAvatar>(preview).space;

    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('büyük avatar mevcut renk ve simgeyi gösterir; Kaydet pasif', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        profile: profile,
      );
      final rs = RS.tr;
      expect(find.text(rs.editAvatarTitle), findsOneWidget);
      expect(previewSpace(tester).color, blue);
      expect(previewSpace(tester).icon, 'home');
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
      expect(saveButton(tester, rs.save).onPressed, isNull);
    });

    testWidgets('renk seçimi büyük avatarı hemen değiştirir, henüz yazmaz', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: db,
        language: AppLanguage.tr,
        profile: profile,
      );
      await openPicker(tester);
      expect(find.text(RS.tr.editAvatarPickTitle), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('editAvatar.color.$purple')));
      await tester.pump();
      expect(
        previewSpace(tester).color,
        purple,
        reason: 'sheet açıkken bile arkadaki avatar güncellenir',
      );
      await closeSheet(tester);
      expect(previewSpace(tester).color, purple);
      expect(previewSpace(tester).icon, 'home', reason: 'simge dokunulmadı');
      expect(
        (await readSettings(db)).containsKey('spaceColor'),
        isFalse,
        reason: 'Kaydet basılmadan Firestore\'a yazılmaz',
      );
      expect(saveButton(tester, RS.tr.save).onPressed, isNotNull);
    });

    testWidgets('Kaydet iki alanı yazar, cüzdan adına dokunmaz', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: db,
        language: AppLanguage.en,
        profile: profile,
      );
      await openPicker(tester);
      await tester.tap(find.byKey(ValueKey('editAvatar.color.$purple')));
      await tester.pump();
      // Simge: "star" seçeneği.
      await tester.tap(find.byIcon(kSpaceIcons['star']!));
      await tester.pump();
      await closeSheet(tester);
      await tester.tap(find.text(RS.en.save));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spaceColor'], purple);
      expect(data['spaceIcon'], 'star');
      expect(data.containsKey('spaceName'), isFalse);
      expect(data.containsKey('name'), isFalse);
    });

    testWidgets('"baş harf" seçeneği simgeyi kaldırır', (tester) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: db,
        language: AppLanguage.tr,
        profile: profile,
      );
      await openPicker(tester);
      // Baş harf seçeneği cüzdan adının ilk harfini gösterir ("E").
      await tester.tap(find.text('E'));
      await tester.pump();
      expect(previewSpace(tester).icon, '');
      await closeSheet(tester);
      await tester.tap(find.text(RS.tr.save));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spaceIcon'], '');
      expect(data['spaceColor'], blue);
    });

    testWidgets('çöp kutusu onay sorar; onaylanınca varsayılana yazar', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: db,
        language: AppLanguage.tr,
        profile: profile,
      );
      final rs = RS.tr;
      await tester.tap(find.byIcon(Icons.delete_rounded));
      await tester.pumpAndSettle();
      expect(find.text(rs.editAvatarResetTitle), findsOneWidget);
      expect(find.text(rs.editAvatarResetBody), findsOneWidget);
      expect(
        (await readSettings(db)).containsKey('spaceColor'),
        isFalse,
        reason: 'diyalog açıkken henüz yazılmaz',
      );
      await tester.tap(find.text(rs.editAvatarResetConfirm));
      await tester.pumpAndSettle();
      final data = await readSettings(db);
      expect(data['spaceColor'], SettingsEditAvatarScreen.defaultColor);
      expect(data['spaceIcon'], '');
      expect(data.containsKey('spaceName'), isFalse);
      // Ekran açık kalır, avatar varsayılanı gösterir, Kaydet söner.
      expect(find.text(rs.editAvatarTitle), findsOneWidget);
      expect(previewSpace(tester).color, SettingsEditAvatarScreen.defaultColor);
      expect(previewSpace(tester).icon, '');
      expect(saveButton(tester, rs.save).onPressed, isNull);
    });

    testWidgets('çöp kutusunda vazgeçince hiçbir şey değişmez', (tester) async {
      final db = FakeFirebaseFirestore();
      await pumpBudgyScreen(
        tester,
        const SettingsEditAvatarScreen(),
        db: db,
        language: AppLanguage.en,
        profile: profile,
      );
      await tester.tap(find.byIcon(Icons.delete_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.en.cancel));
      await tester.pumpAndSettle();
      expect(find.text(RS.en.editAvatarResetTitle), findsNothing);
      expect(await readSettings(db), isEmpty);
      expect(previewSpace(tester).color, blue);
      expect(previewSpace(tester).icon, 'home');
      expect(saveButton(tester, RS.en.save).onPressed, isNull);
    });

    testWidgets('kişisel bilgiler satırları yeni ekranları açar', (
      tester,
    ) async {
      await pumpBudgyScreen(
        tester,
        const SettingsPersonalDetailsScreen(),
        db: FakeFirebaseFirestore(),
        language: AppLanguage.tr,
        profile: const {'name': 'Timur Batyrkul'},
      );
      final rs = RS.tr;
      await tester.tap(find.text(rs.hubEditAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsEditAvatarScreen), findsOneWidget);
      expect(
        find.text(rs.customizeWallet),
        findsNothing,
        reason: 'eski cüzdan sheet\'i artık açılmıyor',
      );
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      // Ad hem kartın başlığında hem satır değerinde yazıyor; satırı
      // etiketinden ("Ad soyad") yakalıyoruz.
      await tester.tap(find.text(Strings.tr.fullNameLabel));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsEditNameScreen), findsOneWidget);
      expect(find.text(rs.editNameTitle), findsOneWidget);
    });
  });

  // ── fotoğraf vaadi yok ─────────────────────────────────────────────────
  // Storage bağlı değil; ekran ve seçici ne metinle ne ikonla fotoğraf,
  // galeri ya da kamera ima etmemeli.
  group('fotoğraf yok', () {
    const banned = [
      'foto',
      'photo',
      'galeri',
      'gallery',
      'kamera',
      'camera',
      'фото',
      'галере',
      'камер',
    ];
    const bannedIcons = [
      Icons.camera_alt_rounded,
      Icons.camera_alt,
      Icons.photo_camera_rounded,
      Icons.photo_camera,
      Icons.photo_library_rounded,
      Icons.photo_library,
      Icons.add_a_photo_rounded,
      Icons.add_a_photo,
      Icons.image_rounded,
      Icons.image,
    ];

    for (final lang in AppLanguage.values) {
      testWidgets('avatar ekranı + seçici · ${lang.code}', (tester) async {
        await pumpBudgyScreen(
          tester,
          const SettingsEditAvatarScreen(),
          db: FakeFirebaseFirestore(),
          language: lang,
        );
        await tester.tap(find.byIcon(Icons.edit_rounded));
        await tester.pumpAndSettle();
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map(
              (t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase(),
            )
            .join('\n');
        for (final word in banned) {
          expect(texts.contains(word), isFalse, reason: '"$word" geçmemeli');
        }
        for (final icon in bannedIcons) {
          expect(find.byIcon(icon), findsNothing);
        }
        // Dil dosyasındaki metinler de temiz (ekranda görünmeyen diyalog
        // dahil).
        final rs = RS.of(lang.code);
        for (final s in [
          rs.editAvatarBody,
          rs.editAvatarPickTitle,
          rs.editAvatarResetTitle,
          rs.editAvatarResetBody,
          rs.editAvatarLetter,
        ]) {
          for (final word in banned) {
            expect(
              s.toLowerCase().contains(word),
              isFalse,
              reason: '"$s" içinde "$word" olmamalı',
            );
          }
        }
      });
    }
  });

  // ── yerleşim ───────────────────────────────────────────────────────────
  group('yerleşim', () {
    final screens = <String, Widget>{
      'Ad': const SettingsEditNameScreen(),
      'Avatar': const SettingsEditAvatarScreen(),
    };
    for (final width in [320.0, 360.0]) {
      for (final entry in screens.entries) {
        for (final lang in AppLanguage.values) {
          testWidgets(
            '${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
            (tester) async {
              await pumpBudgyScreen(
                tester,
                entry.value,
                db: FakeFirebaseFirestore(),
                language: lang,
                logicalSize: Size(width, 800),
                profile: const {
                  'name': 'Александра Константинопольская',
                  'spaceName': 'Kişisel',
                },
              );
              expect(tester.takeException(), isNull);
              if (entry.value is SettingsEditAvatarScreen) {
                // Seçici sheet'i ve sıfırlama diyaloğu da dar ekranda sığsın.
                await tester.tap(find.byIcon(Icons.edit_rounded));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await tester.tap(find.byIcon(Icons.close_rounded));
                await tester.pumpAndSettle();
                await tester.tap(find.byIcon(Icons.delete_rounded));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            },
          );
        }
      }
    }
  });
}

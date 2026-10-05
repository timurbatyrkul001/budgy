import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kopilka_app/core/ex_style.dart';
import 'package:kopilka_app/core/l10n.dart';
import 'package:kopilka_app/features/categories/categories_screen.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/envelopes/home_screen.dart';
import 'package:kopilka_app/features/goals/goals_screen.dart';
import 'package:kopilka_app/features/profile/contact_screen.dart';
import 'package:kopilka_app/features/profile/currency_screen.dart';
import 'package:kopilka_app/features/profile/help_screen.dart';
import 'package:kopilka_app/features/profile/language_screen.dart';
import 'package:kopilka_app/features/profile/privacy_policy_screen.dart';
import 'package:kopilka_app/features/profile/terms_of_use_screen.dart';
import 'package:kopilka_app/features/stats/stats_screen.dart';
import 'package:kopilka_app/features/transactions/journal_screen.dart';
import 'package:kopilka_app/features/transactions/tx.dart';
import 'package:kopilka_app/features/workdays/calendar_screen.dart';
import 'package:kopilka_app/features/workdays/work_days_repository.dart';

import '../support/harness.dart';

/// Ekranı `home` olarak değil, boş bir sayfanın ÜSTÜNE itilmiş bir route
/// olarak açar.
///
/// [BudgyBackButton] geri gidilecek yer yoksa kendini gizliyor; ekran
/// doğrudan `home` olarak pump edilirse başlık satırı gerçek hâlinden daha
/// geniş ölçülür ve dar ekrandaki taşma gözden kaçar. Her zaman menüden
/// itilen ekranlar bu sarmalayıcıyla sınanır.
class _PushOnStart extends StatefulWidget {
  const _PushOnStart(this.screen);

  final Widget screen;

  @override
  State<_PushOnStart> createState() => _PushOnStartState();
}

class _PushOnStartState extends State<_PushOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => MediaQuery(
            // Harness'teki ayarla aynı: giriş animasyonları anında biter.
            data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
            child: widget.screen,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

/// Ekranların dar telefonlarda taşmadığını doğrular.
///
/// Flutter, bir RenderFlex taştığında testi düşürür — yani bu dosya
/// "sarı-siyah şerit" hatalarını (gerçek cihazda kesilmiş içerik) mağazaya
/// çıkmadan yakalar. En dar yaygın ekran 320dp (iPhone SE 1. nesil),
/// ardından 360dp (birçok Android) geliyor.
void main() {
  setUpAll(() async {
    for (final lang in AppLanguage.values) {
      await initializeDateFormatting(lang.code);
    }
  });

  /// Dolu bir kullanıcı: uzun isimli zarflar, bütçeler, döviz, hedefler —
  /// metnin en çok yer kapladığı hâl.
  final envelopes = <Envelope>[
    testEnvelope(
      id: 'e1',
      name: 'Market ve Temel Gıda',
      balance: 4500,
      targetAmount: 8000,
    ),
    testEnvelope(
      id: 'e2',
      name: 'Ulaşım',
      emoji: '🚗',
      balance: 1200,
      targetAmount: 1500,
      sortOrder: 1,
    ),
    testEnvelope(
      id: 'usd',
      name: 'Dolar Birikimi',
      emoji: '💵',
      balance: 1750,
      currency: 'USD',
      sortOrder: 2,
    ),
    testEnvelope(
      id: 'goal',
      name: 'Yaz Tatili Fonu',
      emoji: '✈️',
      balance: 12500,
      targetAmount: 40000,
      isGoal: true,
      sortOrder: 3,
    ),
  ];

  final now = DateTime.now();
  final transactions = <Tx>[
    Tx(
      id: 't1',
      type: TxType.expense,
      amount: 1234.56,
      date: now,
      envelopeId: 'e1',
      envelopeName: 'Market ve Temel Gıda',
      note: 'Haftalık büyük alışveriş ve temizlik',
    ),
    Tx(
      id: 't2',
      type: TxType.income,
      amount: 25000,
      date: now.subtract(const Duration(days: 1)),
      allocations: const {'e1': 15000, 'e2': 10000},
    ),
    Tx(
      id: 't3',
      type: TxType.transfer,
      amount: 500,
      date: now.subtract(const Duration(days: 2)),
      fromName: 'Market ve Temel Gıda',
      envelopeName: 'Ulaşım',
    ),
    Tx(
      id: 't4',
      type: TxType.income,
      amount: 250,
      date: now.subtract(const Duration(days: 3)),
      envelopeId: 'usd',
      envelopeName: 'Dolar Birikimi',
      currency: 'USD',
      isConvert: true,
    ),
  ];

  final workDays = <WorkDay>[
    for (var i = 0; i < 7; i++)
      WorkDay(
        id: 'd$i',
        date: DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i)),
        amount: 1750 + i * 125,
      ),
  ];

  final screens = <String, Widget>{
    'Ana ekran': const HomeScreen(),
    'Takvim': const CalendarScreen(),
    'Hedefler': const GoalsScreen(),
    'İstatistik': const StatsScreen(),
    'Geçmiş': const JournalScreen(),
  };

  /// Menüden/ayarlardan itilerek açılan ekranlar: başlık satırında ortak
  /// geri düğmesi ([BudgyBackButton]) görünür hâlde ölçülür.
  final pushedScreens = <String, Widget>{
    'Hedefler (itilmiş)': const GoalsScreen(),
    'Kategoriler': const CategoriesScreen(),
    'Dil': const LanguageScreen(),
    'Para birimi': const CurrencyScreen(),
    'SSS': const HelpScreen(),
    'Gizlilik': const PrivacyPolicyScreen(),
    'Yardım Merkezi': const ContactScreen(),
    'Kullanım koşulları': const TermsOfUseScreen(),
  };

  // 320dp: iPhone SE (1. nesil) · 360dp: en yaygın Android genişliği.
  for (final width in [320.0, 360.0]) {
    for (final entry in pushedScreens.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets(
          '${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
            final db = FakeFirebaseFirestore();
            for (final e in envelopes) {
              await seedEnvelope(db, e);
            }
            await pumpBudgyScreen(
              tester,
              _PushOnStart(entry.value),
              db: db,
              envelopes: envelopes,
              transactions: transactions,
              workDays: workDays,
              language: lang,
              logicalSize: Size(width, 800),
            );
            expect(tester.takeException(), isNull);
            // Üç ayrı "geri" biçimi yerine tek ortak düğme: ekran gerçekten
            // itilmiş olduğundan düğme görünür olmalı.
            expect(find.byType(BudgyBackButton), findsOneWidget);
            expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
            expect(find.byIcon(Icons.arrow_back_ios_new_rounded),
                findsNothing);
            // Material AppBar hiçbir ekranda kalmadı (Hedefler dahil).
            expect(find.byType(AppBar), findsNothing);
          },
        );
      }
    }

    for (final entry in screens.entries) {
      for (final lang in AppLanguage.values) {
        testWidgets(
          '${entry.key} · ${width.toInt()}dp · ${lang.code} taşmıyor',
          (tester) async {
            final db = FakeFirebaseFirestore();
            for (final e in envelopes) {
              await seedEnvelope(db, e);
            }
            await pumpBudgyScreen(
              tester,
              entry.value,
              db: db,
              envelopes: envelopes,
              transactions: transactions,
              workDays: workDays,
              language: lang,
              logicalSize: Size(width, 800),
            );
            // pumpAndSettle taşma olursa zaten fırlatır; yine de ekranın
            // gerçekten kurulduğunu doğrulayalım.
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

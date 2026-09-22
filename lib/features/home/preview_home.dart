import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preview.dart';
import '../settings/app_settings.dart';
import '../space/space.dart';

import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../reminders/reminders_repository.dart';
import '../transactions/tx.dart';
import '../workdays/work_days_repository.dart';

/// Ana ekranı Firestore'a hiç dokunmadan örnek veriyle açar (ekran
/// görüntüsü / tasarım kontrolü): `flutter run --dart-define=PREVIEW_HOME=true`.
/// Yalnız debug. Kök ProviderScope'a verilir — türetilmiş provider'lar
/// (bu ay harcanan, hesaplar...) iç içe scope'ta override'ı görmez.
const kPreviewHome = kDebugMode && bool.fromEnvironment('PREVIEW_HOME');

/// Kök ProviderScope — örnek veri override'larıyla.
Widget previewHomeScope({required Widget child}) {
  final now = DateTime.now();
  final envelopes = <Envelope>[
    const Envelope(
        id: 'p1', name: 'Market', emoji: '🍔', balance: 0, sortOrder: 0,
        presetKey: 'food'),
    const Envelope(
        id: 'p2', name: 'Ulaşım', emoji: '🚗', balance: 0, sortOrder: 1,
        presetKey: 'transport'),
    // Kullanıcı kategorisi, bölümü seçilmiş (seçicide bölüm kartına girer).
    const Envelope(
        id: 'p5', name: 'Kahvaltı', emoji: '', balance: 0, sortOrder: 4,
        section: 'everyday', colorIndex: 1),
    // Gelir kaynağı (katalog: salary).
    const Envelope(
        id: 'p6', name: 'Maaş', emoji: '💼', balance: 0, sortOrder: 5,
        presetKey: 'salary'),
    const Envelope(
        id: 'p3', name: 'Dolar', emoji: '💵', balance: 1750, sortOrder: 2,
        currency: 'USD'),
    const Envelope(
        id: 'p4', name: 'Euro', emoji: '💶', balance: 420, sortOrder: 3,
        currency: 'EUR'),
  ];
  final txs = <Tx>[
    Tx(
        id: 't1',
        type: TxType.expense,
        amount: 1240.5,
        date: now,
        envelopeId: 'p1',
        envelopeName: 'Market',
        note: 'Haftalık alışveriş'),
    Tx(
        id: 't2',
        type: TxType.expense,
        amount: 320,
        date: now.subtract(const Duration(hours: 5)),
        envelopeId: 'p2',
        envelopeName: 'Ulaşım',
        note: 'Taksi'),
    // Kaynaklı gelir: Maaş (gelir kategorisi p6) — notsuz, başlık kaynak adı.
    Tx(
        id: 't3',
        type: TxType.income,
        amount: 25000,
        date: now.subtract(const Duration(days: 1)),
        envelopeId: 'p6',
        envelopeName: 'Maaş'),
    Tx(
        id: 't4',
        type: TxType.expense,
        amount: 4850,
        date: now.subtract(const Duration(days: 2)),
        envelopeId: 'p1',
        envelopeName: 'Market'),
    Tx(
        id: 't6',
        type: TxType.expense,
        amount: 640,
        date: now.subtract(const Duration(hours: 2)),
        note: 'Kargo'),
    Tx(
        id: 't5',
        type: TxType.expense,
        amount: 189.9,
        date: now.subtract(const Duration(days: 3)),
        envelopeId: 'p2',
        envelopeName: 'Ulaşım',
        note: 'Metro'),
  ];
  return ProviderScope(overrides: [
    onboardingDoneProvider.overrideWith((ref) => Stream.value(true)),
    walletMigrationProvider.overrideWith((ref) async {}),
    recurringMaterializerProvider.overrideWith((ref) async => 0),
    spaceNameMigrationProvider.overrideWith((ref) async {}),
    userRulesProvider.overrideWith((ref) => Stream.value(const [])),
    disabledBuiltinsProvider.overrideWith((ref) => Stream.value(const {})),
    recurringRulesProvider.overrideWith((ref) => Stream.value(const [])),
    envelopesProvider.overrideWith((ref) => Stream.value(envelopes)),
    journalProvider.overrideWith((ref) => Stream.value(txs)),
    journalFullProvider.overrideWith((ref) => Stream.value(txs)),
    recentTxsProvider.overrideWith((ref) => Stream.value(txs)),
    cashBalanceProvider.overrideWith((ref) => Stream.value(18420)),
    allWorkDaysProvider.overrideWith((ref) => Stream.value(const [])),
    remindersProvider.overrideWith((ref) => Stream.value(const [])),
    reminderSchedulerProvider.overrideWithValue(null),
    profileProvider.overrideWith((ref) => Stream.value({
          'spaceName': 'Personal',
          // Eski alan — göçün çalıştığını da gösterir.
          if (kPreviewBudget != 'empty') 'monthlyBudget': 15000,
          if (kPreviewStarred) 'starredCurrencies': ['EUR'],
        })),
  ], child: child);
}

/// PREVIEW_TX için örnek işlem (ana ekrandaki kaynaklı gelir 't3').
Tx previewIncomeTx() => Tx(
      id: 't3',
      type: TxType.income,
      amount: 25000,
      date: DateTime.now().subtract(const Duration(days: 1)),
      envelopeId: 'p6',
      envelopeName: 'Maaş',
    );

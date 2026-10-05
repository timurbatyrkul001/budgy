import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/envelopes/budget_repository.dart';
import 'package:kopilka_app/features/home/fx_providers.dart';

/// Ana birim: gösterim için `currencyCodeProvider` boşluğu ₺ ile doldurur,
/// yazma için [knownCurrencyCodeProvider] doldurmaz — bilinmiyorsa null.
void main() {
  ProviderContainer container(Stream<String> currency) {
    final c = ProviderContainer(
      overrides: [currencyProvider.overrideWith((ref) => currency)],
    );
    addTearDown(c.dispose);
    c.listen(currencyProvider, (_, _) {});
    c.listen(knownCurrencyCodeProvider, (_, _) {});
    c.listen(currencyCodeProvider, (_, _) {});
    return c;
  }

  test('değer geldi → kod', () async {
    final c = container(Stream.value('KZT'));
    await c.read(currencyProvider.future);
    expect(c.read(knownCurrencyCodeProvider), 'KZT');
    expect(c.read(currencyCodeProvider), 'KZT');
  });

  test('henüz gelmedi → null (gösterim ₺ der, yazma bekler)', () async {
    final pending = StreamController<String>();
    addTearDown(pending.close);
    final c = container(pending.stream);
    expect(c.read(knownCurrencyCodeProvider), isNull);
    expect(c.read(currencyCodeProvider), 'TRY');
  });

  test('düştü → null; gösterim yine ₺ ama bu bir dayanak değil', () async {
    final c = container(Stream.error(StateError('settings okunamadı')));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(currencyProvider).hasError, isTrue);
    expect(c.read(knownCurrencyCodeProvider), isNull);
    expect(c.read(currencyCodeProvider), 'TRY');
  });

  test('önbellekteki eski değer + hata → yine null', () async {
    Stream<String> cachedThenFailed() async* {
      yield 'KZT';
      throw StateError('sonra düştü');
    }

    final c = container(cachedThenFailed());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final state = c.read(currencyProvider);
    expect(state.hasError, isTrue);
    expect(state.hasValue, isTrue, reason: 'Riverpod eski değeri korur');
    expect(c.read(knownCurrencyCodeProvider), isNull);
  });
}

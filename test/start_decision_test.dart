import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/features/auth/auth_gate.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';

import 'support/harness.dart';

/// Açılış kararı: "yükleniyor", "hata" ve "gerçekten boş" üç ayrı şey.
///
/// Eski kural `done.value != true && (envelopes.value?.isEmpty ?? true)`
/// hatada da null gördüğü için yıllık kullanıcıyı onboarding'e düşürüyordu.
void main() {
  final envelope = testEnvelope(id: 'e1');
  final err = AsyncError<bool>(Exception('permission-denied'), StackTrace.empty);
  final envErr = AsyncError<List<Envelope>>(
    Exception('permission-denied'),
    StackTrace.empty,
  );
  final migErr = AsyncError<void>(Exception('boom'), StackTrace.empty);
  const migOk = AsyncData<void>(null);

  group('decideStart', () {
    test('yeni kullanıcı: geçilmemiş + hiç zarf yok → onboarding', () {
      expect(
        decideStart(
          done: const AsyncData(false),
          envelopes: const AsyncData([]),
          migration: migOk,
        ),
        StartDecision.onboarding,
      );
    });

    test('onboarding geçilmiş → ana ekran (zarf olmasa da)', () {
      expect(
        decideStart(
          done: const AsyncData(true),
          envelopes: const AsyncData([]),
          migration: migOk,
        ),
        StartDecision.home,
      );
    });

    test('bayrak yok ama zarf var (eski hesap) → ana ekran', () {
      expect(
        decideStart(
          done: const AsyncData(false),
          envelopes: AsyncData([envelope]),
          migration: migOk,
        ),
        StartDecision.home,
      );
    });

    test('herhangi biri yükleniyor → açılış ekranı', () {
      expect(
        decideStart(
          done: const AsyncLoading(),
          envelopes: const AsyncData([]),
          migration: migOk,
        ),
        StartDecision.loading,
      );
      expect(
        decideStart(
          done: const AsyncData(false),
          envelopes: const AsyncLoading(),
          migration: migOk,
        ),
        StartDecision.loading,
      );
      expect(
        decideStart(
          done: const AsyncData(false),
          envelopes: const AsyncData([]),
          migration: const AsyncLoading(),
        ),
        StartDecision.loading,
      );
    });

    test('onboarding bayrağı akışı düştü → HATA, onboarding değil', () {
      expect(
        decideStart(
          done: err,
          envelopes: const AsyncData([]),
          migration: migOk,
        ),
        StartDecision.error,
      );
    });

    test('zarf akışı düştü → hata (bayrak okunabilse bile)', () {
      expect(
        decideStart(done: const AsyncData(false), envelopes: envErr, migration: migOk),
        StartDecision.error,
      );
      expect(
        decideStart(done: const AsyncData(true), envelopes: envErr, migration: migOk),
        StartDecision.error,
      );
    });

    test('ikisi de düştü (kural / App Check) → hata', () {
      expect(
        decideStart(done: err, envelopes: envErr, migration: migOk),
        StartDecision.error,
      );
    });

    test('cüzdan göçü düştü → hata', () {
      expect(
        decideStart(
          done: const AsyncData(true),
          envelopes: AsyncData([envelope]),
          migration: migErr,
        ),
        StartDecision.error,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/ai/expense_parser.dart';

/// Parser'ın regex-fолбэк yolu (testte API anahtarı yok — AI devre dışı).
/// AI yolu aynı [ParsedItem] sözleşmesini üretir; şema zorlaması
/// (tool_choice) yüzünden ayrıca birim testine gerek yok.
void main() {
  final parser = ExpenseParser();
  const envelopes = [
    (id: 'e1', name: 'Market'),
    (id: 'e2', name: 'Kafe'),
  ];

  test('AI anahtarı testte kapalı — fолбэк çalışmalı', () {
    expect(ExpenseParser.aiAvailable, isFalse);
  });

  test('"kahve 90" → 90₺ gider, not "kahve"', () async {
    final items = await parser.parse('kahve 90', envelopes: envelopes);
    expect(items, hasLength(1));
    expect(items.single.kind, 'expense');
    expect(items.single.amount, 90);
    expect(items.single.note, 'kahve');
  });

  test('türkçe biçim: "market 1.250,50"', () async {
    final items = await parser.parse('market 1.250,50', envelopes: envelopes);
    expect(items.single.amount, 1250.50);
  });

  test('zarf adı metinde geçiyorsa kategori eşleşir', () async {
    final items = await parser.parse('market 450', envelopes: envelopes);
    expect(items.single.envelopeId, 'e1');
    expect(items.single.envelopeName, 'Market');
  });

  test('kazanç sözcüğü geliri işaretler ve kategori almaz', () async {
    final items =
        await parser.parse('bugün 2000 kazandım', envelopes: envelopes);
    expect(items.single.kind, 'income');
    expect(items.single.amount, 2000);
    expect(items.single.envelopeId, isNull);
  });

  test('tutarsız metin boş liste döner', () async {
    final items = await parser.parse('hiç para yok', envelopes: envelopes);
    expect(items, isEmpty);
  });

  test('boş metin boş liste döner', () async {
    expect(await parser.parse('   ', envelopes: envelopes), isEmpty);
  });
}

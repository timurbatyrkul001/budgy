import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/category_rules.dart';
import 'package:kopilka_app/core/csv_export.dart';
import 'package:kopilka_app/core/tags.dart';
import 'package:kopilka_app/features/envelopes/envelope.dart';
import 'package:kopilka_app/features/space/space.dart';
import 'package:kopilka_app/features/transactions/tx.dart';

/// Ayarlar merkezi mantığı: varsayılan ad göçü, etiket çıkarımı, kategori
/// otomasyonu eşleşmesi ve CSV dışa aktarma.
void main() {
  group('migratedSpaceName', () {
    test('boş ya da eski varsayılan → yeni varsayılan', () {
      expect(migratedSpaceName(null, 'Personal'), 'Personal');
      expect(migratedSpaceName('', 'Kişisel'), 'Kişisel');
      expect(migratedSpaceName('My wallet', 'Personal'), 'Personal');
      expect(migratedSpaceName('Cüzdanım', 'Kişisel'), 'Kişisel');
      expect(migratedSpaceName('Мой кошелёк', 'Личное'), 'Личное');
    });

    test('kullanıcının kendi adı korunur; zaten yeniyse yazılmaz', () {
      expect(migratedSpaceName('Timur\'un cüzdanı', 'Kişisel'), isNull);
      expect(migratedSpaceName('Personal', 'Personal'), isNull);
    });
  });

  group('tags', () {
    Tx tx(String id, String? note) => Tx(
        id: id, type: TxType.expense, amount: 1, date: DateTime(2026), note: note);

    test('notlardan #etiketleri sayar, küçük harfe indirger', () {
      final tags = extractTags([
        tx('1', 'Market #Ev #market'),
        tx('2', 'kahve #ev'),
        tx('3', null),
        tx('4', 'no tags here'),
        tx('5', '#tatil #ev #ev'),
      ]);
      expect(tags, {'ev': 3, 'market': 1, 'tatil': 1});
      expect(tags.keys.first, 'ev', reason: 'çoktan aza');
    });

    test('Unicode etiketler ve alt çizgi', () {
      expect(tagsIn('#kırtasiye #işe_gidiş #2026'), ['kırtasiye', 'işe_gidiş', '2026']);
    });
  });

  group('matchCategory', () {
    test('yerleşik kural, büyük/küçük ve aksan duyarsız', () {
      expect(matchCategory('ŞOK market')!.catalogKey, 'groceries');
      expect(matchCategory('Sok Market')!.catalogKey, 'groceries');
      expect(matchCategory('NETFLIX aylık')!.catalogKey, 'streaming');
      expect(matchCategory('Türk Telekom fatura')!.catalogKey, 'internet');
      expect(matchCategory('Petrol Ofisi')!.catalogKey, 'fuel');
    });

    test('eşleşme yoksa null; boş metin null', () {
      expect(matchCategory('kitapçıdan defter'), isNotNull); // education: kitap
      expect(matchCategory('bilinmeyen şey'), isNull);
      expect(matchCategory(''), isNull);
      expect(matchCategory(null), isNull);
    });

    test('kullanıcı kuralı yerleşikten önce gelir', () {
      const rules = [
        UserRule(id: 'r1', keyword: 'migros', envelopeId: 'e9', envelopeName: 'Ev'),
      ];
      final m = matchCategory('Migros alışverişi', userRules: rules)!;
      expect(m.envelopeId, 'e9');
      expect(m.catalogKey, isNull);
    });

    test('kapatılan yerleşik kelime atlanır, diğerleri çalışır', () {
      expect(matchCategory('a101', disabledBuiltins: {'a101'}), isNull);
      expect(matchCategory('a101 ve bim', disabledBuiltins: {'a101'})!.keyword, 'bim');
      expect(matchCategory('A101', disabledBuiltins: {'A101'}), isNull,
          reason: 'kapatma listesi de normalize edilir');
    });

    test('yerleşik sayısı ve normalize', () {
      expect(builtinRuleCount(), greaterThan(150));
      expect(normalizeText('İSKİ  Çağrı'), 'iski cagri');
    });
  });

  group('buildTransactionsCsv', () {
    test('başlık, sıralama, tırnaklama, hesap sütunu', () {
      final envelopes = {
        'm': const Envelope(id: 'm', name: 'Market', emoji: '🛒', balance: 0, sortOrder: 0),
        'usd': const Envelope(id: 'usd', name: 'USD cüzdanı', emoji: '💵', balance: 0,
            sortOrder: 1, currency: 'USD'),
      };
      final csv = buildTransactionsCsv(
        [
          Tx(id: '1', type: TxType.expense, amount: 12.5, date: DateTime(2026, 9, 1, 9, 30),
              envelopeId: 'm', note: 'süt, ekmek'),
          Tx(id: '2', type: TxType.income, amount: 100, date: DateTime(2026, 9, 2, 10),
              envelopeId: 'usd', currency: 'USD', note: 'He said "hi"'),
          Tx(id: '3', type: TxType.expense, amount: 5, date: DateTime(2026, 9, 3),
              isConvert: true),
        ],
        envelopes: envelopes,
        mainCurrency: 'TRY',
        nameOf: (e) => e.name,
        cashLabel: 'Nakit',
      );
      final lines = csv.trim().split('\n');
      expect(lines.first, 'date,type,amount,currency,category,note,account');
      expect(lines[1], '2026-09-03 00:00,convert,5.00,TRY,,,Nakit');
      expect(lines[2], '2026-09-02 10:00,income,100.00,USD,,"He said ""hi""",USD cüzdanı');
      expect(lines[3], '2026-09-01 09:30,expense,12.50,TRY,Market,"süt, ekmek",Nakit');
    });
  });
}

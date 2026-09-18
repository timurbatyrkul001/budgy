import 'package:intl/intl.dart';

import '../features/envelopes/envelope.dart';
import '../features/transactions/tx.dart';

/// İşlemleri CSV'ye çevirir (Veri yönetimi → Dışa aktar). Sütunlar sabit
/// ve İngilizce başlıklı ki tablo programları ve başka uygulamalar okusun.
/// Hesap: ₺ işlemler "Cash", döviz işlemleri ilgili cüzdan zarfının adı.
String buildTransactionsCsv(
  Iterable<Tx> txs, {
  required Map<String, Envelope> envelopes,
  required String mainCurrency,
  required String Function(Envelope) nameOf,
  String cashLabel = 'Cash',
}) {
  final buf = StringBuffer()
    ..writeln('date,type,amount,currency,category,note,account');
  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  final sorted = txs.toList()..sort((a, b) => b.date.compareTo(a.date));
  for (final t in sorted) {
    final type = t.isConvert
        ? 'convert'
        : t.isGoalFund
            ? 'goal'
            : t.type.name;
    final currency = t.currency == 'TRY' ? mainCurrency : t.currency;
    final env = t.envelopeId == null ? null : envelopes[t.envelopeId];
    final isWallet = t.currency != 'TRY' && env != null;
    final category = isWallet ? '' : (env != null ? nameOf(env) : (t.envelopeName ?? ''));
    final account = isWallet ? nameOf(env) : cashLabel;
    buf.writeln([
      fmt.format(t.date),
      type,
      t.amount.toStringAsFixed(2),
      currency,
      category,
      t.note ?? '',
      account,
    ].map(_csvCell).join(','));
  }
  return buf.toString();
}

/// Virgül, tırnak ve satır sonu içeren hücreler tırnaklanır.
String _csvCell(String v) {
  if (!v.contains(',') && !v.contains('"') && !v.contains('\n')) return v;
  return '"${v.replaceAll('"', '""')}"';
}

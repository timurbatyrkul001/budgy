import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/csv_export.dart';
import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_l10n.dart';
import '../home/fx_providers.dart';
import '../transactions/tx.dart';

/// Veri yönetimi: CSV dışa aktarma (paylaş) ve "Tüm verileri sil"
/// (çift onay → deleteAccountData; hesap kalır).
class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final str = ref.read(strProvider);
    final rs = ref.read(rsProvider);
    try {
      final txs = ref.read(journalFullProvider).value ?? const <Tx>[];
      final envelopes = {
        for (final e in ref.read(envelopesProvider).value ?? const <Envelope>[])
          e.id: e,
      };
      final csv = buildTransactionsCsv(
        txs,
        envelopes: envelopes,
        mainCurrency: ref.read(currencyCodeProvider),
        nameOf: (e) => e.displayName(str),
        cashLabel: rs.cash,
      );
      final dir = await Directory.systemTemp.createTemp('budgy');
      final file = File('${dir.path}/budgy-transactions.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
    } catch (_) {
      if (mounted) showErrorSnack(context, str.errorSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String text) async {
    final str = ref.read(strProvider);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Ex.surface,
            content: Text(text, style: const TextStyle(color: Ex.text)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(str.cancel)),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(str.deleteWord, style: const TextStyle(color: Ex.red))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteAll() async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    // Çift onay: geri dönüşü yok.
    if (!await _confirm(rs.deleteAllDataConfirm)) return;
    if (!mounted || !await _confirm(rs.deleteAllDataConfirm2)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await guardWrite(
      context,
      str,
      () => ref.read(budgetRepositoryProvider).deleteAccountData(),
      reason: 'deleteAllData',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(rs.deleteAllDone)));
      // Veri gidince auth kapısı onboarding'e döner; köke çıkalım.
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text(rs.dataManagement,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Ex.text)),
            const SizedBox(height: 16),
            ExCard(
              onTap: _busy ? null : _export,
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Ex.brand.withValues(alpha: 0.16),
                      borderRadius: Ex.squircle(40),
                    ),
                    child: const Icon(Icons.ios_share_rounded, size: 20, color: Ex.mint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rs.exportCsv,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: Ex.text)),
                        const SizedBox(height: 3),
                        Text(rs.exportCsvHint,
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.35, color: Ex.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ExCard(
              onTap: _busy ? null : _deleteAll,
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Ex.red.withValues(alpha: 0.14),
                      borderRadius: Ex.squircle(40),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, size: 21, color: Ex.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rs.deleteAllData,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: Ex.red)),
                        const SizedBox(height: 3),
                        Text(rs.deleteAllDataHint,
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.35, color: Ex.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Ex.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

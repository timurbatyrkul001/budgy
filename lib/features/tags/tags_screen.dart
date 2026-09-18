import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../../core/tags.dart';
import '../envelopes/budget_repository.dart';
import '../transactions/journal_screen.dart';
import '../transactions/tx.dart';

/// Etiketler — notlardaki #etiketler (salt okunur): etiket + kullanım
/// sayısı; dokun → o etiketin işlemleri.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final txs = ref.watch(journalFullProvider).value ?? const <Tx>[];
    final tags = extractTags(txs);

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text(rs.tags,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Ex.text)),
            const SizedBox(height: 16),
            if (tags.isEmpty)
              ExCard(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Ex.brand.withValues(alpha: 0.16),
                        borderRadius: Ex.squircle(60),
                      ),
                      child: const Icon(Icons.tag_rounded, size: 28, color: Ex.mint),
                    ),
                    const SizedBox(height: 14),
                    Text(rs.tagsEmpty,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                    const SizedBox(height: 6),
                    Text(rs.tagsHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.4, color: Ex.textSoft)),
                  ],
                ),
              )
            else
              ExCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, e) in tags.entries.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Ex.border),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _TagTxsScreen(tag: e.key),
                        )),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.tag_rounded, size: 18, color: Ex.mint),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(e.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Ex.text)),
                              ),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Ex.textMuted)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Ex.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TagTxsScreen extends ConsumerWidget {
  const _TagTxsScreen({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final str = ref.watch(strProvider);
    final txs = (ref.watch(journalFullProvider).value ?? const <Tx>[])
        .where((t) => tagsIn(t.note).contains(tag))
        .toList();
    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BudgyBackButton(),
            Text('#$tag',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Ex.mint)),
            const SizedBox(height: 14),
            ExCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final (i, t) in txs.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: Ex.border),
                    TxTile(tx: t, str: str),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animated_bar.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/ex_style.dart';
import '../../core/redesign_l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope.dart';
import '../envelopes/envelope_detail_screen.dart';
import '../envelopes/envelope_l10n.dart';
import '../space/currency_wallets.dart';
import '../../core/feedback.dart';

const _goalEmojis = [
  '✈️', '🚗', '💻', '🏠', '📱', '🎓', '🏖️', '🎮', '⌚',
  '🚴', '🛋️', '👶', '🐶', '🎸', '📷', '🏝️', '💰',
];

/// Alt düğme: "+ Döviz cüzdanı ekle" (testler bununla bulur).
const kGoalsAddWalletKey = ValueKey('goals-add-wallet');

/// Birikim ekranı: döviz cüzdanları + birikim hedefleri (Trip, araba,
/// MacBook...). Ana ekrandaki "Birikim" bölümünün "Tümü"sü buraya gelir;
/// o bölüm ikisi de yokken HİÇ çizilmediği için döviz cüzdanı açmanın
/// onboarding sonrası tek kalıcı kapısı bu ekrandır (ayarlar › Hedefler ve
/// hesap yönetimindeki yön levhası buraya getirir). Cüzdanlar da burada
/// listelenir; yoksa kullanıcı cüzdan ekler ve ekranda hiçbir şey
/// değişmezdi.
///
/// Hedef parası Money left'ten ayrıdır (ayrılmış kumbara).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final rs = ref.watch(rsProvider);
    final envelopes = ref.watch(envelopesProvider).value ?? [];
    final goals = envelopes.where((e) => e.isGoal && !e.archived).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final wallets = [...ref.watch(accountEnvelopesProvider)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık: Material AppBar yerine diğer ekranlardaki desen
            // (Kategoriler ile aynı) — ortak geri düğmesi + kalın başlık.
            // BudgyBackButton altına 12 px boşluk koyuyor; başlık aynı hizada
            // dursun diye o da aynı boşluğu alır.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const BudgyBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        str.goalsTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                          color: c.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: goals.isEmpty && wallets.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎯', style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 16),
                            Text(
                              str.goalsEmpty,
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: c.textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        // Cüzdan varken iki grup alt başlıkla ayrılır; yalnız
                        // hedef varken ekran başlığı yeter (eski görünüm).
                        if (wallets.isNotEmpty) ...[
                          _GroupLabel(rs.walletsSection),
                          for (final w in wallets) ...[
                            _WalletTile(wallet: w),
                            const SizedBox(height: 10),
                          ],
                          if (goals.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _GroupLabel(str.goalsTitle),
                          ],
                        ],
                        for (final (i, goal) in goals.indexed) ...[
                          _GoalCard(goal: goal, colorIndex: i),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Ex.onBrand,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () => _showNewGoal(context, ref, goals.length),
              icon: const Icon(Icons.add_rounded),
              label: Text(str.newGoal.replaceFirst('+ ', '')),
            ),
            const SizedBox(height: 4),
            // İkincil eylem: döviz cüzdanı. Kaydetme `addCurrencyWallet`'ta
            // (ana ekrandaki "+" ile aynı yol).
            GhostButton(
              key: kGoalsAddWalletKey,
              label: rs.addCurrencyWallet,
              onTap: () => addCurrencyWallet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grup alt başlığı (Döviz cüzdanları / Hedefler).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: context.budgy.textMuted,
        ),
      ),
    );
  }
}

/// Döviz cüzdanı satırı: simge + ad + bakiye kendi biriminde. Dokunma zarf
/// detayına gider (ana ekrandaki kutucukla aynı). Hedef kartından kasten
/// sade: cüzdanın ilerlemesi yok, yalnız bakiyesi var.
class _WalletTile extends ConsumerWidget {
  const _WalletTile({required this.wallet});

  final Envelope wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    return InkWell(
      key: ValueKey('goals-wallet-${wallet.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EnvelopeDetailScreen(envelopeId: wallet.id),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(color: c.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(wallet.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                wallet.displayName(str),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMoneyIn(wallet.balance, wallet.currency),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.04 * 17,
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showNewGoal(BuildContext context, WidgetRef ref, int sortOrder) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _NewGoalSheet(sortOrder: sortOrder),
  );
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.colorIndex});

  final Envelope goal;
  final int colorIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final target = goal.targetAmount ?? 0;
    final percent = (goal.progress * 100).round();
    final done = goal.balance >= target && target > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showAddMoney(context, ref, goal),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.envTintAt(colorIndex),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: c.surface, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child:
                      Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatMoneyIn(goal.balance, 'TRY')} / ${formatMoneyIn(target, 'TRY')}',
                        style: TextStyle(
                            fontSize: 13.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                // Yüzde: pastel kart üstünde mürekkep, afiş tipografisi.
                Text('$percent%',
                    style: TextStyle(
                        fontFamily: 'InterDisplay',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.04 * 20,
                        color: c.text)),
              ],
            ),
            const SizedBox(height: 14),
            // Çubuk: eski canlı palet (vivids) pastel kâğıtta cırtlak
            // duruyordu; dolu = marka yeşili, boş = beyaz (kart zaten
            // pastel olduğu için surfaceHi kaybolurdu).
            AnimatedBar(
              value: goal.progress,
              color: Ex.brand,
              background: Ex.surface,
            ),
            const SizedBox(height: 8),
            Text(
              done
                  ? '🎉'
                  : '${formatMoneyIn(goal.remaining, 'TRY')} ${str.goalLeft}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.budgy.surface,
        title:
            Text(tpl(str.removeGoalTitle, {'name': goal.name})),
        content: Text(str.removeGoalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(str.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(str.removeWord,
                style: const TextStyle(color: Ex.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(budgetRepositoryProvider)
          .deleteGoal(goal.id, goal.balance);
    }
  }
}

void _showAddMoney(BuildContext context, WidgetRef ref, Envelope goal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.budgy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AddMoneySheet(goal: goal),
  );
}

class _AddMoneySheet extends ConsumerStatefulWidget {
  const _AddMoneySheet({required this.goal});
  final Envelope goal;

  @override
  ConsumerState<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<_AddMoneySheet> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) return;
    final str = ref.read(strProvider);
    setState(() => _saving = true);
    final ok = await guardWrite(context, str, () {
      return ref.read(budgetRepositoryProvider).fundGoal(
            goalId: widget.goal.id,
            goalName: widget.goal.name,
            amount: amount,
          );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final canSave = parseAmount(_amount.text) != null && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text('${widget.goal.emoji}  ${widget.goal.name}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            // Tutar girişi: afiş tipografisi (Inter Display Black).
            style: TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.04 * 26,
                color: c.text),
            decoration: InputDecoration(
              prefixText: '₺  ',
              prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted),
              hintText: '0',
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Ex.onBrand,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: canSave ? _save : null,
              child: Text(_saving ? '...' : str.addFunds),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewGoalSheet extends ConsumerStatefulWidget {
  const _NewGoalSheet({required this.sortOrder});
  final int sortOrder;

  @override
  ConsumerState<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<_NewGoalSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  String _emoji = _goalEmojis.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = parseAmount(_target.text);
    final name = _name.text.trim();
    if (target == null || name.isEmpty) return;
    final str = ref.read(strProvider);
    setState(() => _saving = true);
    final ok = await guardWrite(context, str, () {
      return ref.read(budgetRepositoryProvider).addGoal(
            name: name,
            emoji: _emoji,
            targetAmount: target,
            sortOrder: widget.sortOrder,
          );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final canSave = _name.text.trim().isNotEmpty &&
        parseAmount(_target.text) != null &&
        !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(str.newGoal.replaceFirst('+ ', ''),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: str.nameHint,
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _goalEmojis)
                    ChoiceChip(
                      label: Text(e, style: const TextStyle(fontSize: 20)),
                      selected: _emoji == e,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _emoji = e),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: c.text),
            decoration: InputDecoration(
              prefixText: '₺  ',
              hintText: curText(str.targetAmountHint),
              filled: true,
              fillColor: c.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Ex.onBrand,
                disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: canSave ? _save : null,
              child: Text(_saving ? '...' : str.setGoal),
            ),
          ),
        ],
      ),
    );
  }
}

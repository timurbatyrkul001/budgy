import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import 'account.dart';
import 'account_card.dart';
import 'account_editor_sheet.dart';
import 'accounts_repository.dart';

/// Hesap yönetimi: kartlar dikey liste hâlinde, her biri kendi bakiyesiyle.
///
/// Adı `AccountsScreen` değil, tarihsel sebeple: eskiden
/// `lib/features/home/accounts_screen.dart` aynı adla döviz-kumbarası
/// listesini taşıyordu ve ana ekran onu import ediyordu. O ekran kaldırıldı
/// (kumbaralar ana ekrandaki "Birikim" bölümüne, sağlayıcı
/// `space/currency_wallets.dart`'a taşındı); çakışma kalmadı, ad yalnız
/// çağıran yerleri (ayarlar, ana ekran, testler) kıpırdatmamak için duruyor.
///
/// NEDEN ÜSTTE TOPLAM YOK: Hesaplar farklı para birimlerinde (₺ maaş, ₼
/// harcama). "Toplam varlık" için hepsini tek birime çevirmek gerekir; ama
/// uygulamada kur dondurma İŞLEM bazlı (her işlem kendi günündeki kurla
/// kayıtlı), bakiye bazlı değil. Bakiyeyi bugünkü kurla çevirip tek sayı
/// basmak, geçmiş işlemlerin donmuş kurlarıyla çelişen ve her gün kendiliğinden
/// oynayan bir rakam üretirdi. Bu yüzden üstte yalnız başlık + hesap sayısı
/// var; her hesap kendi biriminde okunur.
class ManageAccountsScreen extends ConsumerWidget {
  const ManageAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final cards = accounts.where((a) => !a.isCash).toList();

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BudgyBackButton(),
                  Text(
                    rs.accountsTitle,
                    style: const TextStyle(
                      fontFamily: 'InterDisplay',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      height: 1.05,
                      color: Ex.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tpl(rs.accountCountTpl, {'n': '${accounts.length}'}),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Ex.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Kart genişliği: kenar boşlukları düşülmüş ekran; tablette
                  // devasa olmasın diye tavan var. Liste tam genişlik kalır
                  // (sürükleme alanı), kart ortalanır.
                  final cardWidth =
                      (constraints.maxWidth - 40).clamp(200.0, 400.0);
                  return _AccountList(
                    accounts: accounts,
                    cards: cards,
                    cardWidth: cardWidth,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: rs.accountAdd,
                onTap: () => showAccountEditor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sürükle-bırak liste. Nakit de sıralanabilir (kullanıcı nakdi en alta
/// atmak isteyebilir); depo `reorder` hepsine yeni `sortOrder` yazar.
class _AccountList extends ConsumerWidget {
  const _AccountList({
    required this.accounts,
    required this.cards,
    required this.cardWidth,
  });

  final List<Account> accounts;
  final List<Account> cards;
  final double cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      // Sürüklenen kartın altındaki yeşil Material gölgesi kâğıtta yabancı
      // duruyor; şeffaf yüzey + hafif büyütme yeterli ipucu.
      proxyDecorator: (child, _, animation) => AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Transform.scale(
          scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
          child: Material(color: Colors.transparent, child: child),
        ),
        child: child,
      ),
      itemCount: accounts.length,
      // Boş durum + sıralama ipucu listenin altında; sürüklenemez (footer).
      footer: cards.isEmpty
          ? _EmptyState(onAdd: () => showAccountEditor(context))
          : (accounts.length > 1
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    rs.accountReorderHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Ex.textFaint),
                  ),
                )
              : null),
      onReorder: (oldIndex, newIndex) {
        // Flutter sözleşmesi: öğe aşağı taşınırken newIndex bir fazla gelir.
        if (newIndex > oldIndex) newIndex -= 1;
        final ids = accounts.map((a) => a.id).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        guardWrite(
          context,
          str,
          () => ref.read(accountsRepositoryProvider).reorder(ids),
          reason: 'reorderAccounts',
        );
      },
      itemBuilder: (context, i) => _AccountTile(
        key: ValueKey(accounts[i].id),
        account: accounts[i],
        cardWidth: cardWidth,
      ),
    );
  }
}

/// Tek hesap: kart + altında bakiye (kendi biriminde) + menü.
///
/// Uzun basma SÜRÜKLEMEYE ayrıldı (`ReorderableListView` mobilde öğeyi uzun
/// basınca kaldırır); menü için satır sonundaki "⋯" var. Aynı jeste iki iş
/// yüklemek ikisini de güvenilmez yapardı.
class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    super.key,
    required this.account,
    required this.cardWidth,
  });

  final Account account;
  final double cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountCard(
                account: account,
                width: cardWidth,
                onTap: () => _openMenu(context, ref),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rs.accountBalance,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Ex.textMuted,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            accountMoney(account.balance, account.currency),
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'InterDisplay',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: Ex.text,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('menu-${account.id}'),
                    onPressed: () => _openMenu(context, ref),
                    style: IconButton.styleFrom(
                      backgroundColor: Ex.surfaceHi,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.more_horiz_rounded,
                        size: 20, color: Ex.text),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menü yalnız SEÇİMİ döndürür; işi burada yapıyoruz. Sebep: menü sayfası
  /// Navigator'ın altında kurulur, bu kartın scope'unda değil — depoyu ve
  /// düzenleyiciyi oradan açmak yanlış container'a düşerdi. Seçim geri
  /// gelince hem `ref` hem `context` doğru yerde.
  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final repo = ref.read(accountsRepositoryProvider);
    final title = account.name.trim().isEmpty ? rs.cash : account.name;

    // Menü açılmadan ÖNCE işlem sayısı: "Tamamen sil" satırı bu sayıya göre
    // aktif ya da soluk çizilir. Nakit için sormuyoruz, zaten satır yok.
    // Sayım alınamazsa (çevrimdışı — `count()` sunucu ister) `null`: menü
    // silmeyi hiç sunmaz. Doğrulanmamış bir "0" ile silme vaat etmek yerine
    // seçeneği saklamak daha dürüst; depo zaten ikinci kez kontrol ediyor.
    int? txCount;
    if (!account.isCash) {
      try {
        txCount = await repo.transactionCount(account.id);
      } catch (_) {
        txCount = null;
      }
    }
    if (!context.mounted) return;

    final action = await showAccountMenu(
      context,
      account,
      title: title,
      txCount: txCount,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case AccountMenuAction.rename:
        await showAccountEditor(context, existing: account);
      case AccountMenuAction.delete:
        final confirmed = await _confirmDelete(context, rs, title);
        if (!confirmed || !context.mounted) return;
        final ok = await guardWrite(
          context,
          str,
          () => repo.delete(account.id),
          reason: 'deleteAccount',
        );
        if (!ok || !context.mounted) return;
        // Silme GERİ ALINAMAZ — belge gitti, "geri al" sunacak bir şey yok.
        // Arşivdeki gibi bir düğme koymak yalan bir güvence olurdu; yalnız
        // bilgi veriyoruz. Onay diyaloğu zaten "geri alınamaz" dedi.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(tpl(rs.accountDeletedTpl, {'name': title})),
          ),
        );
      case AccountMenuAction.archive:
        final ok = await guardWrite(
          context,
          str,
          () => repo.archive(account.id),
          reason: 'archiveAccount',
        );
        if (!ok || !context.mounted) return;
        // Arşiv geri alınabilir — silme değil; şeritten tek dokunuş.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(tpl(rs.accountArchivedTpl, {'name': title})),
            action: SnackBarAction(
              label: rs.undo,
              onPressed: () => repo.archive(account.id, archived: false),
            ),
          ),
        );
    }
  }

  /// Silme onayı: başlık + "{name} kalıcı olarak kaldırılacak" + "Bu geri
  /// alınamaz" + İptal / Sil. `journal_screen.dart`'taki işlem silme
  /// diyaloğuyla aynı iskelet — kullanıcı aynı tehlikeyi aynı biçimde görsün.
  Future<bool> _confirmDelete(
    BuildContext context,
    RS rs,
    String title,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('account-delete-dialog'),
        backgroundColor: Ex.surface,
        title: Text(rs.accountDeleteConfirmTitle),
        content: Text(
          '${tpl(rs.accountDeleteConfirmBodyTpl, {'name': title})}\n'
          '${rs.accountDeleteIrreversible}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(rs.accountDeleteCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Ex.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(rs.accountDeleteButton),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

/// Menüden dönen seçim.
enum AccountMenuAction { rename, archive, delete }

/// Hesap menüsü: Yeniden adlandır / Arşivle / Tamamen sil.
///
/// Nakit için ne arşiv ne silme çizilir — depo ikisinde de `StateError`
/// atıyor (eski kod `accounts/cash`'e doğrudan yazıyor); gri bir seçenek
/// bile "neden olmuyor?" sorusu doğurur, nakit için bunun bir cevabı yok.
///
/// [txCount] hesaba bağlı işlem sayısı: 0 → silme aktif; >0 → silme SOLUK
/// ve altında "{n} işlem var" notu; `null` (sayım alınamadı) → satır yok.
///
/// Yalnız seçimi döndürür, yazma yapmaz (bkz. `_AccountTile._openMenu`).
Future<AccountMenuAction?> showAccountMenu(
  BuildContext context,
  Account account, {
  required String title,
  int? txCount,
}) {
  // Bkz. showAccountEditor: modal, çağıranın scope'unu görsün (metinler).
  final container = ProviderScope.containerOf(context);
  return showExSheet<AccountMenuAction>(
    context,
    UncontrolledProviderScope(
      container: container,
      child: _AccountMenu(account: account, title: title, txCount: txCount),
    ),
  );
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({
    required this.account,
    required this.title,
    required this.txCount,
  });

  final Account account;
  final String title;
  final int? txCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final count = txCount;

    return SheetFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuRow(
            icon: Icons.edit_rounded,
            label: rs.accountRename,
            onTap: () => Navigator.of(context).pop(AccountMenuAction.rename),
          ),
          if (!account.isCash) ...[
            const SizedBox(height: 8),
            _MenuRow(
              icon: Icons.archive_outlined,
              label: rs.accountArchive,
              note: rs.accountArchiveNote,
              onTap: () =>
                  Navigator.of(context).pop(AccountMenuAction.archive),
            ),
            // SOLUK, GİZLİ DEĞİL: işlemi olan kartta satırı saklasaydık
            // kullanıcı "bu kartta neden sil yok, ötekinde var?" diye
            // kalırdı. Soluk satır + "{n} işlem var — kaldır" notu, kuralı
            // tam ihtiyaç anında öğretir ve doğru eyleme (arşiv) yönlendirir.
            // Nakitten farkı: nakit için kullanıcının yapabileceği bir şey
            // yok, burada var (kaldır). Sayım alınamadıysa satır yok —
            // ne aktif ne soluk hâli dürüstçe açıklayabiliriz.
            if (count != null) ...[
              const SizedBox(height: 8),
              _MenuRow(
                key: ValueKey('delete-${account.id}'),
                icon: Icons.delete_outline_rounded,
                label: rs.accountDelete,
                note: count == 0
                    ? rs.accountDeleteNote
                    : tpl(rs.accountHasTxTpl, {'n': '$count'}),
                danger: true,
                enabled: count == 0,
                onTap: () =>
                    Navigator.of(context).pop(AccountMenuAction.delete),
              ),
            ],
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? note;
  final VoidCallback onTap;

  /// Kırmızı metin/ikon — yıkıcı eylem (silme).
  final bool danger;

  /// `false` → soluk ve dokunulamaz; satır görünür kalır ki `note` kullanıcıya
  /// NEDEN'i anlatsın.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? Ex.red : Ex.text;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ExCard(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note!,
                        style: const TextStyle(
                            fontSize: 12, color: Ex.textMuted),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Ex.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Hiç kart yokken (yalnız nakit): çağrı kartı. Kart ekleme düğmesi ekranın
/// altında zaten var; bu kart "neden ekleyeyim"i söyler ve kendisi de açar.
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return ExCard(
      onTap: onAdd,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Ex.brand.withValues(alpha: 0.12),
              borderRadius: Ex.squircle(44),
            ),
            child: const Icon(Icons.credit_card_rounded, color: Ex.brand),
          ),
          const SizedBox(height: 14),
          Text(
            rs.accountEmptyTitle,
            style: const TextStyle(
              fontFamily: 'InterDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: Ex.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rs.accountEmptyBody,
            style: const TextStyle(
                fontSize: 14, height: 1.4, color: Ex.textSoft),
          ),
        ],
      ),
    );
  }
}

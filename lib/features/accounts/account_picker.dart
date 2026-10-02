import 'package:flutter/material.dart';

import '../../core/ex_style.dart';
import 'account.dart';
import 'account_card.dart';
import 'bank_catalog.dart';

/// İşlem formunda "hangi karttan?" şeridi: yatay kayan [AccountCard]'lar,
/// seçili olan halkalı.
///
/// NEDEN TEK HESAPTA HİÇ ÇİZİLMİYOR: Seçilecek bir şey yoksa seçici de
/// olmamalı. Tek kartlı (ya da yalnız nakitli) kullanıcıya "Enpara" yazan
/// koca bir kart göstermek formu uzatır, "bir şey mi seçmem gerekiyor?"
/// diye düşündürür ve hiçbir bilgi vermez — para zaten o tek hesaptan
/// çıkacak. Çağıran taraf `selectedId`'yi yine o hesaba kurar; biz sadece
/// görünmeyiz. Böylece hesap eklemeyen kullanıcı için işlem akışı eskisiyle
/// birebir aynı kalır.
///
/// NEDEN KART, LİSTE DEĞİL: Kartlar renkle tanınır (bkz. `bank_catalog`
/// başı) — mor = Enpara, kırmızı = Kaspi. Bir satır listede adı okumak
/// gerekir; şeritte göz rengi yakalar, başparmak kaydırır. İşlem girişi
/// günde birkaç kez yapılan bir şey, saniyeler burada önemli.
///
/// Metin içermez: para birimi uyarısı dahil tüm yazılar dışarıdan gelir
/// (`warning`) — çeviri tek yerde (`RS`) kalsın.
class AccountPicker extends StatefulWidget {
  const AccountPicker({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.warning,
    this.cardWidth = 168,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  /// Gösterilecek hesaplar (sıralı, arşivsiz — `accountsProvider` çıktısı).
  final List<Account> accounts;

  /// Halkalı kart. Listede yoksa hiçbiri halkalı çizilmez.
  final String? selectedId;

  /// Kullanıcı başka karta dokundu. Zaten seçili karta dokunmak çağırmaz.
  final ValueChanged<String> onChanged;

  /// Şeridin altındaki küçük not (ör. "Bu kart ₼ ile çalışıyor, ana para
  /// biriminiz ₺"). Metni çağıran verir; null ise satır hiç yok.
  final String? warning;

  /// Kart dış genişliği (halka dahil). 168 → 320dp ekranda ~1.8 kart
  /// görünür; ikinci kartın yarısı "kaydırılabilir" ipucu verir.
  final double cardWidth;

  /// Şeridin kenar boşluğu — form sayfasının kenar boşluğuyla hizalansın.
  final EdgeInsets padding;

  /// Kartlar arası boşluk.
  static const gap = 10.0;

  @override
  State<AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<AccountPicker> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Seçili kart ekran dışındaysa (ör. 5. kart öneri olarak geldi) şerit
    // o karttan başlasın; kullanıcı "hangisi seçili?" diye kaydırmasın.
    // Bir kart solda kısmen görünsün diye tam başlangıca değil, yarım kart
    // geriye hizalanır.
    final index = widget.accounts.indexWhere((a) => a.id == widget.selectedId);
    final step = widget.cardWidth + AccountPicker.gap;
    final offset = index <= 0 ? 0.0 : index * step - widget.cardWidth / 2;
    _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;
    if (accounts.length < 2) return const SizedBox.shrink();

    // Yükseklik karttan türer: ListView yatayda kendi yüksekliğini
    // çocuktan alamaz, biz vermeliyiz.
    final probe = AccountCard(account: accounts.first, width: widget.cardWidth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: probe.height,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            // Halka büyümesi (scale 1.03) kenarda kırpılmasın.
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: AccountPicker.gap),
            itemBuilder: (context, i) {
              final a = accounts[i];
              final selected = a.id == widget.selectedId;
              return AccountCard(
                key: ValueKey('account-card-${a.id}'),
                account: a,
                width: widget.cardWidth,
                selected: selected,
                onTap: selected ? null : () => widget.onChanged(a.id),
              );
            },
          ),
        ),
        if (widget.warning != null)
          Padding(
            padding: widget.padding.copyWith(top: 8, bottom: 0),
            child: _WarningNote(text: widget.warning!),
          ),
      ],
    );
  }
}

/// Şerit altındaki para birimi notu: amber nokta + küçük gri metin.
/// Hata değil, bilgi — kırmızı kullanmadık; yabancı kartla harcamak
/// meşru bir durum, kullanıcı yalnız kurun uygulanacağını bilsin.
class _WarningNote extends StatelessWidget {
  const _WarningNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, right: 8),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Ex.amber,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Ex.textSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Kompakt varyant: tek satırlık düğme — renk noktası + hesap adı + para
/// birimi + ok. İşlem ekleme sayfasında tam şerit sığmıyorsa (klavye açık,
/// hızlı giriş sheet'i) bunu koyup dokununca [showAccountPicker] açılır.
///
/// Renk noktası kartın marka rengi: şeritteki kartla aynı rengi görünce
/// kullanıcı ikisini eşleştirir. Nakit için marka yeşili (`cash` kaydı).
class AccountChip extends StatelessWidget {
  const AccountChip({
    super.key,
    required this.account,
    required this.onTap,
    this.brand,
  });

  final Account account;
  final VoidCallback onTap;

  /// Verilmezse addan tahmin edilir; tutmazsa nötr "Diğer banka".
  final BankBrand? brand;

  @override
  Widget build(BuildContext context) {
    final b = brand ??
        (account.kind == AccountKind.cash
            ? bankByKey('cash')!
            : bankByName(account.name) ?? bankByKey('other')!);
    final name = account.name.trim().isEmpty ? b.name : account.name;
    final currency = account.currency.toUpperCase();

    return Semantics(
      container: true,
      button: true,
      label: '$name, $currency',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Ex.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.iconRadius),
            side: const BorderSide(color: Ex.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: b.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Uzun ad ("Enpara Maaş Hesabım") çipi taşırmasın.
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Ex.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currency,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Ex.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Ex.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hesap seçme alt sayfası. Seçilen hesabın id'siyle döner; kapatılırsa
/// null.
///
/// Sheet'te dikey liste var, yatay şerit değil: sheet zaten dikey akar ve
/// burada amaç hızlı bakış değil, hepsini görüp birini seçmek. Her satırda
/// küçük bir kart minyatürü duruyor ki şeritle aynı renk dili kalsın.
///
/// "+ Kart ekle" satırı [onAddAccount] verilmişse görünür. Dokununca
/// ÖNCE sheet kapanır (null döner), SONRA callback çağrılır: editör sheet'in
/// üstüne değil, formun üstüne açılsın; editör kapanınca kullanıcı formu
/// görsün, eski seçiciyi değil. Editörü biz açmıyoruz — o başka modülde.
///
/// Tüm metinler parametre: [title] sheet başlığı, [addLabel] ekleme satırı.
Future<String?> showAccountPicker(
  BuildContext context, {
  required String? selectedId,
  required List<Account> accounts,
  required String title,
  String? addLabel,
  VoidCallback? onAddAccount,
  String? warning,
}) async {
  final result = await showExSheet<_PickerResult>(
    context,
    _AccountPickerSheet(
      accounts: accounts,
      selectedId: selectedId,
      title: title,
      addLabel: addLabel,
      showAdd: onAddAccount != null && addLabel != null,
      warning: warning,
    ),
  );
  if (result == null) return null;
  if (result.addRequested) {
    onAddAccount?.call();
    return null;
  }
  return result.accountId;
}

/// Sheet'in dönüşü: ya bir hesap ya da "ekle" isteği. İkisini tek `String?`
/// ile ayırt edemezdik — null hem "kapandı" hem "ekle" olurdu.
class _PickerResult {
  const _PickerResult.account(this.accountId) : addRequested = false;
  const _PickerResult.add()
      : accountId = null,
        addRequested = true;

  final String? accountId;
  final bool addRequested;
}

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.accounts,
    required this.selectedId,
    required this.title,
    required this.addLabel,
    required this.showAdd,
    required this.warning,
  });

  final List<Account> accounts;
  final String? selectedId;
  final String title;
  final String? addLabel;
  final bool showAdd;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in accounts)
            _AccountRow(
              key: ValueKey('account-row-${a.id}'),
              account: a,
              selected: a.id == selectedId,
              onTap: () =>
                  Navigator.of(context).pop(_PickerResult.account(a.id)),
            ),
          if (showAdd)
            _AddRow(
              label: addLabel!,
              onTap: () => Navigator.of(context).pop(const _PickerResult.add()),
            ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _WarningNote(text: warning!),
            ),
        ],
      ),
    );
  }
}

/// Sheet satırı: kart minyatürü + ad + para birimi + seçili tiki.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = account.kind == AccountKind.cash
        ? bankByKey('cash')!
        : bankByName(account.name) ?? bankByKey('other')!;
    final name = account.name.trim().isEmpty ? b.name : account.name;
    final currency = account.currency.toUpperCase();

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$name, $currency',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? Ex.surfaceHi : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Minyatür etkileşimsiz: dokunma satırın kendisinde.
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: AccountCard(account: account, width: 64),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Ex.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currency,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Ex.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tik alanı her satırda ayrılır: seçim değişince metin
                  // kaymasın.
                  SizedBox(
                    width: 22,
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 22, color: Ex.text)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ Kart ekle" satırı — kesik çizgili boş kart minyatürü + etiket.
class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Minyatürle aynı boy (AccountCard width 64 → yükseklik orandan).
    const w = 64.0;
    final probe = const AccountCard(
      account: Account(
        id: '',
        name: '',
        currency: '',
        kind: AccountKind.card,
        balance: 0,
      ),
      width: w,
    );

    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: w,
                    height: probe.height,
                    child: Center(
                      child: Container(
                        width: probe.cardWidth,
                        height: probe.cardWidth / AccountCard.aspectRatio,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Ex.borderHi),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 18, color: Ex.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Ex.mint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

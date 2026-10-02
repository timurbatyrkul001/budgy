import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import 'account.dart';
import 'account_card.dart';
import 'accounts_repository.dart';
import 'bank_catalog.dart';

/// Para birimi simgesi. `kCurrencies` tablosunda AZN yok (manat), ama
/// Azerbaycan kartı bu özelliğin çıkış sebebi; tabloya buradan dokunmadan
/// eksikleri tamamlıyoruz. Bilinmeyen kod simge yerine kodun kendisiyle
/// yazılır ("150 XYZ") — boş kalmasın.
String accountCurrencySymbol(String code) =>
    kCurrencies[code] ?? const {'AZN': '₼'}[code] ?? code;

/// Tutarı HESABIN KENDİ biriminde yazar: "1.500,5 ₺", "50 ₼".
/// `formatMoney` uygulamanın ana birimini basar; burada o yanlış olurdu.
String accountMoney(double amount, String currency) =>
    '${formatNumber(amount)} ${accountCurrencySymbol(currency)}';

/// Ülke kodu → bayrak emojisi. Bayrak için ikon paketi gerekmiyor;
/// bölgesel gösterge çiftleri her platformda metin olarak çiziliyor.
String flagFor(String code) => switch (code) {
      'TR' => '🇹🇷',
      'AZ' => '🇦🇿',
      'KZ' => '🇰🇿',
      'RU' => '🇷🇺',
      _ => '🏳️',
    };

/// Ülke adı — kullanıcının dilinde. Katalogdaki kod ISO-2, ad bizde.
String countryNameFor(RS rs, String code) => switch (code) {
      'TR' => rs.accountCountryTR,
      'AZ' => rs.accountCountryAZ,
      'KZ' => rs.accountCountryKZ,
      'RU' => rs.accountCountryRU,
      _ => code,
    };

/// Kart ekleme / düzenleme sayfası.
///
/// [existing] verilirse düzenleme modu: yalnız ad değişir, para birimi
/// kilitli (depo da `rename` ile birime dokunmuyor — bkz.
/// `AccountsRepository.rename`). Yeni kartta akış: ülke → banka → ad +
/// birim + başlangıç bakiyesi.
///
/// Kaydetme sayfanın içinde (çağıranın değil): hem liste ekranı hem ileride
/// başka giriş noktaları aynı sayfayı açıp aynı yazma yolunu kullansın.
/// Dönüş: kaydedildiyse `true`, kapatıldıysa `null`.
Future<bool?> showAccountEditor(BuildContext context, {Account? existing}) {
  // Modal sayfa Navigator'ın altında kurulur, çağıranın ProviderScope'unun
  // değil. Uygulamada tek kök scope olduğu için fark etmez; testte ekran
  // sahte depoyla iç içe bir scope'a sarıldığında sayfa onu göremezdi.
  // Çağıranın container'ını açıkça taşıyoruz.
  final container = ProviderScope.containerOf(context);
  return showExSheet<bool>(
    context,
    UncontrolledProviderScope(
      container: container,
      child: _AccountEditorSheet(existing: existing),
    ),
  );
}

class _AccountEditorSheet extends ConsumerStatefulWidget {
  const _AccountEditorSheet({this.existing});

  final Account? existing;

  @override
  ConsumerState<_AccountEditorSheet> createState() =>
      _AccountEditorSheetState();
}

class _AccountEditorSheetState extends ConsumerState<_AccountEditorSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();

  String? _country;
  BankBrand? _bank;
  String _currency = 'TRY';

  /// Kullanıcı ada elle dokundu mu. Dokunmadıysa banka değişince ad da
  /// bankanın adına döner; dokunduysa ("Enpara maaş") korunur.
  bool _nameTouched = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _currency = e.currency;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _pickCountry(String code) {
    if (_country == code) return;
    setState(() {
      _country = code;
      // Ülke değişince önceki ülkenin bankası anlamsız; seçim sıfırlanır.
      _bank = null;
      _currency = currencyForCountry(code);
      if (!_nameTouched) _name.clear();
    });
  }

  void _pickBank(BankBrand b) {
    setState(() {
      _bank = b;
      // Para birimi ülkeden (banksForCountry genel kayıtları o ülkenin
      // birimine çeviriyor). Kullanıcı aşağıdan değiştirebilir.
      _currency = b.currency;
      if (!_nameTouched) {
        // "Diğer banka" için ad boş kalsın: kullanıcı bankasını yazsın,
        // yoksa kartta "Diğer banka" diye bir ad kalır.
        _name.text = b.key == 'other' ? '' : b.name;
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(accountsRepositoryProvider);
    final str = ref.read(strProvider);
    final existing = widget.existing;
    final ok = await guardWrite(
      context,
      str,
      () => existing != null
          ? repo.rename(existing.id, name: name)
          : repo.add(
              name: name,
              currency: _currency,
              kind: AccountKind.card,
              // Boş ya da geçersiz tutar = 0: kart sıfırdan açılır.
              balance: parseAmount(_balance.text) ?? 0,
            ),
      reason: existing != null ? 'renameAccount' : 'addAccount',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final canSave = _name.text.trim().isNotEmpty &&
        (_isEdit || _bank != null) &&
        !_saving;

    return SheetFrame(
      title: _isEdit ? rs.accountEditTitle : rs.accountNewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit) ...[
            // Düzenlemede kart önizlemesi: ad değiştikçe marka tahmini de
            // (`bankByName`) canlı değişir — kullanıcı sonucu görsün.
            Center(
              child: AccountCard(
                account: widget.existing!.copyWith(name: _name.text),
                width: 220,
              ),
            ),
          ] else ...[
            FieldLabel(rs.accountCountry),
            _CountryPicker(selected: _country, onPick: _pickCountry),
            if (_country != null) ...[
              FieldLabel(rs.accountBank),
              _BankGrid(
                country: _country!,
                selected: _bank,
                currency: _currency,
                onPick: _pickBank,
              ),
            ],
          ],
          if (_isEdit || _bank != null) ...[
            FieldLabel(rs.name),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style:
                  const TextStyle(color: Ex.text, fontWeight: FontWeight.w600),
              decoration: InputDecoration(hintText: rs.accountNameHint),
              onChanged: (_) => setState(() => _nameTouched = true),
            ),
            FieldLabel(rs.currency),
            if (_isEdit)
              _LockedCurrency(code: _currency, note: rs.accountCurrencyLocked)
            else ...[
              _CurrencyChips(
                selected: _currency,
                // Ülkenin birimi başta; tabloda yoksa (AZN) yine de listede.
                codes: {
                  currencyForCountry(_country!),
                  ...kCurrencies.keys,
                }.toList(),
                onPick: (c) => setState(() => _currency = c),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  rs.accountCurrencyAuto,
                  style: const TextStyle(fontSize: 12, color: Ex.textMuted),
                ),
              ),
              FieldLabel(rs.accountStartingBalance),
              TextField(
                controller: _balance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                    color: Ex.text, fontWeight: FontWeight.w700, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: accountCurrencySymbol(_currency),
                  suffixStyle: const TextStyle(color: Ex.textMuted),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: rs.save, onTap: canSave ? _save : null),
        ],
      ),
    );
  }
}

/// Ülke çipleri: bayrak + ad. Yatay sığmazsa alt satıra sarar (320dp'de
/// "Kazakistan" ile dört çip tek satıra sığmıyor).
class _CountryPicker extends ConsumerWidget {
  const _CountryPicker({required this.selected, required this.onPick});

  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final code in kBankCountries)
          _Chip(
            label: '${flagFor(code)} ${countryNameFor(rs, code)}',
            selected: code == selected,
            onTap: () => onPick(code),
          ),
      ],
    );
  }
}

/// Seçilen ülkenin bankaları, iki sütun kart önizlemesi hâlinde.
///
/// Nakit katalogda var ama burada YOK: nakit hesabı zaten sabit `cash`
/// belgesi, ikinci bir "nakit kartı" iki yere para yazdırırdı.
class _BankGrid extends ConsumerWidget {
  const _BankGrid({
    required this.country,
    required this.selected,
    required this.currency,
    required this.onPick,
  });

  final String country;
  final BankBrand? selected;
  final String currency;
  final ValueChanged<BankBrand> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final banks = banksForCountry(country).where((b) => b.key != 'cash');

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final tile = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final b in banks)
              AccountCard(
                key: ValueKey('bank-${b.key}'),
                account: Account(
                  id: 'preview-${b.key}',
                  name: '',
                  currency: b == selected ? currency : b.currency,
                  kind: AccountKind.card,
                  balance: 0,
                ),
                // Katalogdaki "Diğer banka" adı Türkçe; kart üstünde
                // kullanıcının dilinde yazsın. Rengi ve anahtarı aynı.
                brand: b.key == 'other'
                    ? BankBrand(
                        key: b.key,
                        name: rs.accountOtherBank,
                        color: b.color,
                        country: b.country,
                        currency: b.currency,
                      )
                    : b,
                width: tile,
                selected: b.key == selected?.key,
                onTap: () => onPick(b),
              ),
          ],
        );
      },
    );
  }
}

/// Para birimi çipleri — simge + kod. Onboarding'deki büyük seçici yerine
/// küçük çipler: kart sayfasında birim ikincil bir karar, ülke zaten doğru
/// birimi getiriyor.
class _CurrencyChips extends StatelessWidget {
  const _CurrencyChips({
    required this.selected,
    required this.codes,
    required this.onPick,
  });

  final String selected;
  final List<String> codes;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in codes)
          _Chip(
            label: '${accountCurrencySymbol(c)} $c',
            selected: c == selected,
            onTap: () => onPick(c),
          ),
      ],
    );
  }
}

/// Düzenlemede kilitli birim: kod + kilit simgesi + neden kilitli olduğu.
class _LockedCurrency extends StatelessWidget {
  const _LockedCurrency({required this.code, required this.note});

  final String code;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Chip(
              label: '${accountCurrencySymbol(code)} $code',
              selected: true,
              onTap: null,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.lock_rounded, size: 16, color: Ex.textMuted),
          ],
        ),
        const SizedBox(height: 8),
        Text(note, style: const TextStyle(fontSize: 12, color: Ex.textMuted)),
      ],
    );
  }
}

/// Seçim çipi: seçiliyken mürekkep dolgu + beyaz yazı, değilken kâğıt.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Ex.text : Ex.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? Ex.text : Ex.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Ex.surface : Ex.text,
            ),
          ),
        ),
      ),
    );
  }
}

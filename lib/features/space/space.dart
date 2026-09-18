import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency_info.dart';
import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';

/// Cüzdan ("space") görünümü: ad, renk, simge. settings/main içinde
/// `spaceName` / `spaceColor` / `spaceIcon` alanlarında durur; eski
/// kullanıcılarda alanlar yok → varsayılanlar (marka yeşili, "Cüzdanım").
class SpaceInfo {
  const SpaceInfo({required this.name, required this.color, this.icon = ''});

  final String name;

  /// ARGB tam sayı (Firestore'a doğrudan yazılır).
  final int color;

  /// [kSpaceIcons] anahtarı; boşsa adın ilk harfi gösterilir.
  final String icon;

  Color get colorValue => Color(color);

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

  IconData? get iconData => kSpaceIcons[icon];

  SpaceInfo copyWith({String? name, int? color, String? icon}) => SpaceInfo(
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
      );

  Map<String, dynamic> toProfile() =>
      {'spaceName': name, 'spaceColor': color, 'spaceIcon': icon};

  static SpaceInfo fromProfile(Map<String, dynamic> p, RS rs) {
    final name = (p['spaceName'] as String?)?.trim();
    return SpaceInfo(
      name: name == null || name.isEmpty ? rs.defaultWalletName : name,
      color: (p['spaceColor'] as num?)?.toInt() ?? Ex.spaceColors.first.toARGB32(),
      icon: p['spaceIcon'] as String? ?? '',
    );
  }
}

/// Eski varsayılan adlar — göçte yeni varsayılana çevrilir; kullanıcının
/// kendi yazdığı ad asla değiştirilmez.
const kLegacyWalletNames = {'My wallet', 'Cüzdanım', 'Мой кошелёк'};

/// Göç: ad boşsa ya da eski varsayılanlardan biriyse yeni varsayılan
/// ([newDefault]) yazılmalı → onu döndürür; aksi halde null (dokunma).
String? migratedSpaceName(String? current, String newDefault) {
  final c = current?.trim() ?? '';
  if (c.isEmpty || kLegacyWalletNames.contains(c)) {
    return c == newDefault ? null : newDefault;
  }
  return null;
}

/// Açılışta bir kez: eski varsayılan cüzdan adını yeni varsayılana taşır.
final spaceNameMigrationProvider = FutureProvider<void>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final rs = ref.read(rsProvider);
  final next = migratedSpaceName(profile['spaceName'] as String?, rs.defaultWalletName);
  if (next != null) {
    await ref.read(budgetRepositoryProvider).saveProfile({'spaceName': next});
  }
});

/// Seçilebilir cüzdan simgeleri (anahtar Firestore'da saklanır).
const kSpaceIcons = <String, IconData>{
  'wallet': Icons.account_balance_wallet_rounded,
  'home': Icons.home_rounded,
  'cart': Icons.shopping_bag_rounded,
  'work': Icons.work_rounded,
  'heart': Icons.favorite_rounded,
  'star': Icons.star_rounded,
  'plane': Icons.flight_rounded,
  'car': Icons.directions_car_rounded,
};

/// Mevcut cüzdan bilgisi — profil + dil değişince güncellenir.
final spaceInfoProvider = Provider<SpaceInfo>((ref) {
  final profile = ref.watch(profileProvider).value ?? const {};
  return SpaceInfo.fromProfile(profile, ref.watch(rsProvider));
});

/// Squircle avatar: seçilen renk zemin, üstünde simge ya da baş harf.
class SpaceAvatar extends StatelessWidget {
  const SpaceAvatar({super.key, required this.space, this.size = 40});

  final SpaceInfo space;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = space.iconData;
    final onColor = _onColor(space.colorValue);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: space.colorValue,
        borderRadius: Ex.squircle(size),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.5, color: onColor)
          : Text(
              space.initial,
              style: TextStyle(
                fontSize: size * 0.44,
                fontWeight: FontWeight.w800,
                color: onColor,
                height: 1,
              ),
            ),
    );
  }

  /// Açık renk zeminde koyu, koyu zeminde beyaz simge.
  static Color _onColor(Color bg) =>
      bg.computeLuminance() > 0.45 ? Ex.onBrand : Colors.white;
}

/// Cüzdan düzenleyici: ad, simge, renk, para birimi. Kaydetme çağıranın
/// işi — onboarding'de taslak, ana ekranda Firestore.
Future<({SpaceInfo info, String currency})?> showSpaceEditor(
  BuildContext context, {
  required SpaceInfo initial,
  required String currency,
}) =>
    showExSheet(context, _SpaceEditor(initial: initial, currency: currency));

class _SpaceEditor extends ConsumerStatefulWidget {
  const _SpaceEditor({required this.initial, required this.currency});

  final SpaceInfo initial;
  final String currency;

  @override
  ConsumerState<_SpaceEditor> createState() => _SpaceEditorState();
}

class _SpaceEditorState extends ConsumerState<_SpaceEditor> {
  late final _name = TextEditingController(text: widget.initial.name);
  late SpaceInfo _space = widget.initial;
  late String _currency = widget.currency;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final code = await showCurrencyPicker(context, selected: _currency);
    if (code != null) setState(() => _currency = code);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final canSave = _name.text.trim().isNotEmpty;

    return SheetFrame(
      title: rs.customizeWallet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: SpaceAvatar(space: _space, size: 72)),
          FieldLabel(rs.name),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Ex.text, fontWeight: FontWeight.w600),
            onChanged: (v) => setState(() => _space = _space.copyWith(name: v)),
          ),
          FieldLabel(rs.icon),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _IconOption(
                selected: _space.icon.isEmpty,
                onTap: () => setState(() => _space = _space.copyWith(icon: '')),
                child: Text(_space.initial,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              for (final e in kSpaceIcons.entries)
                _IconOption(
                  selected: _space.icon == e.key,
                  onTap: () =>
                      setState(() => _space = _space.copyWith(icon: e.key)),
                  child: Icon(e.value, size: 22),
                ),
            ],
          ),
          FieldLabel(rs.color),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in Ex.spaceColors)
                GestureDetector(
                  onTap: () => setState(
                      () => _space = _space.copyWith(color: c.toARGB32())),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: Ex.squircle(38),
                      border: _space.color == c.toARGB32()
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          FieldLabel(rs.currency),
          CurrencyTile(code: _currency, selected: false, onTap: _pickCurrency),
          const SizedBox(height: 24),
          PrimaryButton(
            label: rs.save,
            onTap: canSave
                ? () => Navigator.of(context).pop((
                      info: _space.copyWith(name: _name.text.trim()),
                      currency: _currency,
                    ))
                : null,
          ),
        ],
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Ex.brand : Ex.surfaceHi,
          borderRadius: Ex.squircle(46),
        ),
        child: IconTheme(
          data: IconThemeData(color: selected ? Ex.onBrand : Ex.text),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: selected ? Ex.onBrand : Ex.text),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── para birimi seçici ────────────────────────────────────────────────────

/// Aramalı para birimi seçici. Seçilen kodu döndürür. [exclude]: listede
/// gösterilmeyecek kodlar (ana para birimi, zaten eklenmiş cüzdanlar).
Future<String?> showCurrencyPicker(
  BuildContext context, {
  required String selected,
  Set<String> exclude = const {},
}) =>
    showExSheet<String>(
        context, _CurrencyPicker(selected: selected, exclude: exclude));

class _CurrencyPicker extends ConsumerStatefulWidget {
  const _CurrencyPicker({required this.selected, required this.exclude});

  final String selected;
  final Set<String> exclude;

  @override
  ConsumerState<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends ConsumerState<_CurrencyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final q = _query.trim().toLowerCase();
    final codes = kCurrencies.keys
        .where((c) => !widget.exclude.contains(c))
        .where((c) =>
            q.isEmpty ||
            c.toLowerCase().contains(q) ||
            currencyName(c).toLowerCase().contains(q))
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: SheetFrame(
        title: rs.currency,
        scroll: false,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Ex.text),
              decoration: InputDecoration(
                hintText: rs.searchCurrency,
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Ex.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: codes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => CurrencyTile(
                  code: codes[i],
                  selected: codes[i] == widget.selected,
                  onTap: () => Navigator.of(context).pop(codes[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Para birimi satırı: simge squircle + ad + "bayrak kod" + (seçiliyse) tik.
class CurrencyTile extends StatelessWidget {
  const CurrencyTile({
    super.key,
    required this.code,
    required this.selected,
    this.onTap,
    this.large = false,
  });

  final String code;
  final bool selected;
  final VoidCallback? onTap;

  /// Onboarding'deki büyük kart.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final badge = large ? 56.0 : 42.0;
    return ExCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 14, vertical: large ? 18 : 12),
      child: Row(
        children: [
          Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Ex.brand.withValues(alpha: 0.16),
              borderRadius: Ex.squircle(badge),
            ),
            child: Text(
              kCurrencies[code] ?? code,
              style: TextStyle(
                fontSize: large ? 26 : 20,
                fontWeight: FontWeight.w800,
                color: Ex.mint,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: large ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currencyName(code),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: large ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: Ex.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${currencyFlag(code)}  $code',
                  style: TextStyle(
                      fontSize: large ? 15 : 13, color: Ex.textMuted),
                ),
              ],
            ),
          ),
          if (selected) const RingCheck(),
        ],
      ),
    );
  }
}

/// Nane halka içinde tik.
class RingCheck extends StatelessWidget {
  const RingCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Ex.mint, width: 2),
      ),
      child: const Icon(Icons.check_rounded, size: 16, color: Ex.mint),
    );
  }
}

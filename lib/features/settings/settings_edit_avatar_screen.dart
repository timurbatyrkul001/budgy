import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../space/space.dart';

/// Avatar düzenleme — Hesabım › Kişisel bilgiler › Avatarı düzenle.
///
/// Üstte geri, ortada "Avatar", sağda KIRMIZI yuvarlak çöp kutusu
/// (varsayılana sıfırla). Ortada büyük avatar; sağ üst köşesinde kalem.
/// En altta tam genişlik "Kaydet".
///
/// Bu uygulamada avatar = cüzdan rengi + simge (ya da baş harf), profildeki
/// `spaceColor` / `spaceIcon` alanları. FOTOĞRAF YÜKLEME YOK: Firebase
/// Storage bağlı değil, görsel seçme paketi de yok. Bu yüzden kalem
/// galeriyi değil renk + simge seçicisini açar; ekranda ne kamera ikonu ne
/// de "fotoğraf" sözü var — olmayan bir şeyi vaat etmiyoruz. Fotoğraf
/// gelirse ayrı bir karar: Storage + kurallar + sıkıştırma + silme hakkı.
///
/// Cüzdan ADI burada düzenlenmez — o ayrı bir kavram; kaydederken yalnız
/// iki alan yazılır, `spaceName`'e dokunulmaz.
class SettingsEditAvatarScreen extends ConsumerStatefulWidget {
  const SettingsEditAvatarScreen({super.key});

  /// Varsayılan görünüm: ilk palet rengi (marka yeşili) + simge yok →
  /// baş harf. [SpaceInfo.fromProfile]'ın alan yokken ürettiğiyle aynı.
  static int get defaultColor => Ex.spaceColors.first.toARGB32();

  @override
  ConsumerState<SettingsEditAvatarScreen> createState() =>
      _SettingsEditAvatarScreenState();
}

class _SettingsEditAvatarScreenState
    extends ConsumerState<SettingsEditAvatarScreen> {
  /// Kayıtlı hâl — "değişti mi" kıyası bunun üstünden.
  SpaceInfo _initial = SpaceInfo(
    name: '',
    color: SettingsEditAvatarScreen.defaultColor,
  );

  /// Ekrandaki taslak; seçici her dokunuşta bunu günceller, büyük avatar
  /// anında yansıtır. Firestore'a yalnız Kaydet'te gider.
  SpaceInfo _draft = SpaceInfo(
    name: '',
    color: SettingsEditAvatarScreen.defaultColor,
  );

  /// Taslak profilin İLK gelen değeriyle bir kez kurulur. initState'te
  /// [spaceInfoProvider] okumuyoruz: profil akışı henüz yayın yapmamışsa
  /// o sağlayıcı sessizce varsayılanı verir ve ekran kullanıcının gerçek
  /// rengini değil yeşili gösterirdi.
  bool _seeded = false;
  bool _busy = false;

  bool get _dirty =>
      _draft.color != _initial.color || _draft.icon != _initial.icon;

  Future<void> _pick() async {
    await showExSheet<void>(
      context,
      _AvatarPicker(
        initial: _draft,
        // Seçici kendi taslağını tutar ve her dokunuşta bize bildirir;
        // sheet kapanınca seçim kaybolmaz, ayrıca "Tamam" düğmesi gerekmez.
        onChanged: (s) => setState(() => _draft = s),
      ),
    );
  }

  /// Çöp kutusu: onay → varsayılana döndür ve HEMEN yaz. Kullanıcı zaten
  /// bir diyalog onayladı; üstüne bir de Kaydet istemek aynı şeyi iki kez
  /// sormak olurdu. Ekran açık kalır — isterse yeni bir renk seçer.
  Future<void> _reset() async {
    final rs = ref.read(rsProvider);
    final str = ref.read(strProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ex.surface,
        title: Text(rs.editAvatarResetTitle),
        content: Text(
          rs.editAvatarResetBody,
          style: const TextStyle(height: 1.35, color: Ex.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(str.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              rs.editAvatarResetConfirm,
              style: const TextStyle(color: Ex.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reset = _draft.copyWith(
      color: SettingsEditAvatarScreen.defaultColor,
      icon: '',
    );
    await _write(reset, reason: 'resetAvatar', close: false);
  }

  Future<void> _save() => _write(_draft, reason: 'saveAvatar', close: true);

  Future<void> _write(
    SpaceInfo next, {
    required String reason,
    required bool close,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(budgetRepositoryProvider);
    final ok = await guardWrite(
      context,
      ref.read(strProvider),
      () =>
          repo.saveProfile({'spaceColor': next.color, 'spaceIcon': next.icon}),
      reason: reason,
    );
    if (!mounted) return;
    if (ok && close) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _busy = false;
      if (ok) {
        // Sıfırlama yazıldı: artık kayıtlı hâl bu; Kaydet söner.
        _initial = next;
        _draft = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final profile = ref.watch(profileProvider);
    if (!_seeded && profile.hasValue) {
      _initial = SpaceInfo.fromProfile(profile.value ?? const {}, rs);
      _draft = _initial;
      _seeded = true;
    }

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // ── başlık: geri · "Avatar" · çöp kutusu ─────────────────
              Row(
                children: [
                  // Geri yoksa (test, kök rota) sağdaki düğmeyle simetri
                  // bozulmasın diye 40'lık boşluk.
                  if (Navigator.of(context).canPop())
                    const _TopBack()
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      rs.editAvatarTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Ex.text,
                      ),
                    ),
                  ),
                  _ResetButton(onTap: _busy ? null : _reset),
                ],
              ),

              // ── büyük avatar + kalem ─────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BigAvatar(space: _draft, onEdit: _busy ? null : _pick),
                        const SizedBox(height: 22),
                        Text(
                          rs.editAvatarBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: Ex.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Kaydet ───────────────────────────────────────────────
              // Mürekkep rengi, yeşil değil: referans düzen siyah; yeşil bu
              // dilde "para" demek, avatar kaydı para eylemi değil.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _dirty && !_busy ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Ex.text,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Ex.surfaceHi,
                    disabledForegroundColor: Ex.textFaint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Ex.buttonRadius),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    rs.save,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlık satırı için geri düğmesi — [BudgyBackButton] altına 12 px boşluk
/// koyuyor ve bu satırda ortadaki başlıkla hizayı bozuyor; aynı görünüm,
/// boşluksuz.
class _TopBack extends StatelessWidget {
  const _TopBack();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ex.iconRadius),
        side: const BorderSide(color: Ex.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ex.iconRadius),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, size: 22, color: Ex.text),
        ),
      ),
    );
  }
}

/// Kırmızı yuvarlak çöp kutusu: tek tehlikeli eylem, düz kırmızı — süs
/// yok, gradyan yok ([SettingsRow.danger] ile aynı kural).
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ex.red,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.delete_rounded, size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

/// ~200 px avatar, beyaz halka içinde; sağ üstte küçük kalem.
///
/// Şekil [SpaceAvatar]'ın squircle'ı — uygulamanın her yerinde cüzdan
/// böyle çiziliyor; burada daireye çevirirsek kullanıcı kaydettiğinde
/// kartta başka bir şekil görür ve "kaydedilmedi" sanır.
class _BigAvatar extends StatelessWidget {
  const _BigAvatar({required this.space, required this.onEdit});

  final SpaceInfo space;
  final VoidCallback? onEdit;

  static const _size = 200.0;
  static const _ring = 8.0;

  @override
  Widget build(BuildContext context) {
    const outer = _size + _ring * 2;
    return SizedBox(
      width: outer + 8,
      height: outer + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(_ring),
              decoration: BoxDecoration(
                color: Ex.surface,
                borderRadius: Ex.squircle(outer),
                border: Border.all(color: Ex.border),
              ),
              child: SpaceAvatar(
                key: const ValueKey('editAvatar.preview'),
                space: space,
                size: _size,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Material(
              color: Ex.surface,
              shape: const CircleBorder(side: BorderSide(color: Ex.border)),
              elevation: 2,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEdit,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.edit_rounded, size: 20, color: Ex.text),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── renk + simge seçici (alt sayfa) ───────────────────────────────────────

/// Kalemin açtığı sheet: simge ızgarası (ilk seçenek "baş harf") + renk
/// paleti. Seçim anında [onChanged] ile ekrana yansır; sheet'in kendi
/// Kaydet'i yok — asıl kayıt ekranın altındaki düğmede.
class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker({required this.initial, required this.onChanged});

  final SpaceInfo initial;
  final ValueChanged<SpaceInfo> onChanged;

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  late SpaceInfo _space = widget.initial;

  void _set(SpaceInfo next) {
    setState(() => _space = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    return SheetFrame(
      title: rs.editAvatarPickTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(rs.icon),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Option(
                selected: _space.icon.isEmpty,
                onTap: () => _set(_space.copyWith(icon: '')),
                semanticLabel: rs.editAvatarLetter,
                child: Text(
                  _space.initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final e in kSpaceIcons.entries)
                _Option(
                  selected: _space.icon == e.key,
                  onTap: () => _set(_space.copyWith(icon: e.key)),
                  semanticLabel: e.key,
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
                  key: ValueKey('editAvatar.color.${c.toARGB32()}'),
                  onTap: () => _set(_space.copyWith(color: c.toARGB32())),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: Ex.squircle(38),
                      // Seçili halka mürekkep rengi: beyaz sayfada beyaz
                      // halka görünmez.
                      border: _space.color == c.toARGB32()
                          ? Border.all(color: Ex.text, width: 3)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
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
      ),
    );
  }
}

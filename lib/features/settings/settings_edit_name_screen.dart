import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';

/// Ad düzenleme — Hesabım › Kişisel bilgiler › Ad soyad.
///
/// Üstte geri + sağda "Kaydet" (değişiklik yoksa pasif), büyük başlık, gri
/// açıklama, ardından etiketi ÜSTTE iki beyaz alan: Ad ve Soyad.
///
/// Profilde tek alan var: `name`. Ekranda iki alan gösteriyoruz ama veriyi
/// ikiye bölmüyoruz — mevcut kullanıcıların belgesinde ad zaten tek dize
/// olarak duruyor ("Timur Batyrkul"); onu `firstName`/`lastName` diye iki
/// alana ayırmak göç gerektirir, kartlar/selamlama/dışa aktarma gibi her
/// okuyucu da değişir. Form uğruna şema değiştirmek orantısız: açılışta
/// ilk boşluktan böl, kaydederken tek boşlukla birleştir — yeterli.
///
/// Boş ad kaydedilebilir: kullanıcı adını silmek isteyebilir; o zaman
/// profil kartı eskisi gibi cüzdan adını gösterir.
class SettingsEditNameScreen extends ConsumerStatefulWidget {
  const SettingsEditNameScreen({super.key});

  /// `name` → (ad, soyad). İlk boşluktan böler; "Ali Veli Can" → ("Ali",
  /// "Veli Can"). Tek kelime → soyad boş. Boş → ikisi de boş.
  static (String, String) splitName(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return ('', '');
    return (parts.first, parts.skip(1).join(' '));
  }

  /// (ad, soyad) → `name`. Boş parçalar atlanır ki "Ali" + "" → "Ali"
  /// olsun, "Ali " değil.
  static String joinName(String first, String last) =>
      [first.trim(), last.trim()].where((p) => p.isNotEmpty).join(' ');

  @override
  ConsumerState<SettingsEditNameScreen> createState() =>
      _SettingsEditNameScreenState();
}

class _SettingsEditNameScreenState
    extends ConsumerState<SettingsEditNameScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();

  /// Karşılaştırma tabanı: ham profil değeri DEĞİL, böl-birleştir'den
  /// geçmiş hâli. Aksi hâlde çift boşluklu eski bir ad ("Ali  Veli")
  /// hiç dokunulmadan "değişti" sayılır ve Kaydet boşuna yanardı.
  String _initial = '';

  /// Alanlar profilin İLK gelen değeriyle bir kez doldurulur. initState'te
  /// okumuyoruz: [profileProvider] bir akış, ekran açıldığı anda henüz
  /// yayın yapmamış olabilir (testte her zaman öyle) — o zaman alanlar boş
  /// açılır ve kullanıcının adı "silinmiş" görünürdü.
  bool _seeded = false;
  bool _saving = false;

  void _seed(Map<String, dynamic> profile) {
    final (first, last) = SettingsEditNameScreen.splitName(
      profile['name'] as String? ?? '',
    );
    _first.text = first;
    _last.text = last;
    _initial = SettingsEditNameScreen.joinName(first, last);
    _seeded = true;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  String get _joined =>
      SettingsEditNameScreen.joinName(_first.text, _last.text);

  bool get _dirty => _joined != _initial;

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    final repo = ref.read(budgetRepositoryProvider);
    final ok = await guardWrite(
      context,
      ref.read(strProvider),
      () => repo.saveProfile({'name': _joined}),
      reason: 'saveName',
    );
    if (!mounted) return;
    // Hata olursa ekran açık kalır; şerit zaten gösterildi, kullanıcı
    // tekrar dener.
    if (ok) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ref.watch(rsProvider);
    final profile = ref.watch(profileProvider);
    if (!_seeded && profile.hasValue) _seed(profile.value ?? const {});

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                const BudgyBackButton(),
                const Spacer(),
                // BudgyBackButton altına 12 boşluk koyuyor; aynı hizada
                // dursun diye Kaydet de aynı boşluğu alır.
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HeaderSaveButton(
                    label: rs.save,
                    onTap: _dirty && !_saving ? _save : null,
                  ),
                ),
              ],
            ),
            Text(
              rs.editNameTitle,
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
                height: 1.1,
                color: Ex.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rs.editNameBody,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: Ex.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            FieldLabel(rs.editNameFirst),
            TextField(
              key: const ValueKey('editName.first'),
              controller: _first,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              style: const TextStyle(
                color: Ex.text,
                fontWeight: FontWeight.w600,
              ),
              // Her tuşta setState: Kaydet'in pasif/aktif durumu anında
              // izlesin — değer işlenmiyor, yalnız _dirty yeniden okunuyor.
              onChanged: (_) => setState(() {}),
            ),
            FieldLabel(rs.editNameLast),
            TextField(
              key: const ValueKey('editName.last'),
              controller: _last,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.familyName],
              style: const TextStyle(
                color: Ex.text,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Başlık satırındaki küçük "Kaydet" hapı. Mürekkep zemin, beyaz yazı;
/// pasifken soluk dolgu — "burada bir düğme var ama şu an yapacak bir şey
/// yok" mesajını vermek için gizlenmiyor, soluyor.
class _HeaderSaveButton extends StatelessWidget {
  const _HeaderSaveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Ex.text,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Ex.surfaceHi,
          disabledForegroundColor: Ex.textFaint,
          // Tema FilledButton'a tam genişlik (Size.fromHeight) veriyor;
          // başlık satırındaki hap kendi içeriği kadar olmalı.
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ex.iconRadius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

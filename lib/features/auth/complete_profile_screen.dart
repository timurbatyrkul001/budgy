import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';
import '../envelopes/budget_repository.dart';

/// Заполнение профиля после OTP: имя, телефон, пол, дата рождения, адрес.
/// Görsel dil: Budgy "Sıcak Defter" token'ları (açık + koyu tema).
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _dialCode = '+1';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Mevcut profili önceden doldur (düzenleme).
    final p = ref.read(profileProvider).value ?? const {};
    _name.text = (p['name'] as String?) ?? '';
    final phone = p['phone'] as String?;
    if (phone != null && phone.contains(' ')) {
      _dialCode = phone.split(' ').first;
      _phone.text = phone.split(' ').sublist(1).join(' ');
    } else if (phone != null) {
      _phone.text = phone;
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);
    final phone = _phone.text.trim();
    await ref.read(budgetRepositoryProvider).saveProfile({
      'name': _name.text.trim(),
      'phone': phone.isEmpty ? null : '$_dialCode $phone',
    });
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);

    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Geri butonu (yalnızca navigasyon; tasarımda sade başlık).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Text(
                    str.navCompleteProfile,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    str.profileSubtitle,
                    style: TextStyle(
                        fontSize: 15, height: 1.4, color: c.textMuted),
                  ),
                  const SizedBox(height: 20),
                  // Dekoratif avatar: isim yazıldıkça baş harf güncellenir.
                  Center(
                    child: ListenableBuilder(
                      listenable: _name,
                      builder: (context, _) {
                        final t = _name.text.trim();
                        return Container(
                          width: 92,
                          height: 92,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: t.isEmpty
                              ? Icon(Icons.person_rounded,
                                  color: c.accent, size: 44)
                              : Text(
                                  t.characters.first.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: c.accentStrong,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledField(
                    label: str.fullNameLabel,
                    hint: str.fullNameHint,
                    controller: _name,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  _PhoneField(
                    label: str.phoneLabel,
                    hint: str.phoneHint,
                    controller: _phone,
                    dialCode: _dialCode,
                    onPickCode: _pickDialCode,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            c.accent.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      onPressed: _saving ? null : _saveAndContinue,
                      child: Text(_saving ? '...' : str.continueButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDialCode() async {
    const codes = ['+1', '+7', '+44', '+90', '+49', '+33'];
    final c = context.budgy;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final code in codes)
              ListTile(
                leading: Text(flagFor(code),
                    style: const TextStyle(fontSize: 22)),
                title: Text(code, style: TextStyle(color: c.text)),
                onTap: () => Navigator.of(context).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _dialCode = picked);
  }
}

/// Флаг-эмодзи по коду страны.
String flagFor(String dialCode) => switch (dialCode) {
      '+1' => '🇺🇸',
      '+7' => '🇷🇺',
      '+44' => '🇬🇧',
      '+90' => '🇹🇷',
      '+49' => '🇩🇪',
      '+33' => '🇫🇷',
      _ => '🏳️',
    };

/// Etiketli metin alanı: surface zemin + ince kenarlık (token'lı).
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: c.textFaint),
            filled: true,
            fillColor: c.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.borderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Поле телефона: код страны (чип) + номер.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.dialCode,
    required this.onPickCode,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String dialCode;
  final VoidCallback onPickCode;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted)),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.borderStrong),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onPickCode,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                  child: Row(
                    children: [
                      // 20×20 ülke bayrağı
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: Text(flagFor(dialCode),
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(dialCode,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.text)),
                      Icon(Icons.expand_more_rounded,
                          size: 18, color: c.textMuted),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 15, color: c.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        TextStyle(fontSize: 15, color: c.textFaint),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 18, color: c.text),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';

/// SSS — açılır/kapanır soru kartları (FaqScreen tasarımı).
/// İçerik dile göre (l10n'i şişirmemek için ekran içinde).
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  int? _expanded = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final faqs = _faqs(str.localeCode);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık çubuğu: dairesel geri butonu + ortalanmış başlık.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
              child: Row(
                children: [
                  _BackButton(),
                  Expanded(
                    child: Text(
                      str.faqs,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: c.text),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  for (var i = 0; i < faqs.length; i++) ...[
                    _FaqCard(
                      question: faqs[i].$1,
                      answer: faqs[i].$2,
                      expanded: _expanded == i,
                      onTap: () => setState(
                          () => _expanded = _expanded == i ? null : i),
                    ),
                    const SizedBox(height: 11),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(String, String)> _faqs(String locale) => switch (locale) {
        'tr' => const [
            (
              'Üstteki "Kalan para" ne demek?',
              'Maaşından (Takvim) tüm harcamalarını çıkarınca cebinde kalan para. Her harcama girdiğinde otomatik düşer.'
            ),
            (
              'Maaşımı nasıl girerim?',
              'Calendar sekmesine git, çalıştığın günlere kazancını yaz. Girdiğin tutarlar "Kalan para"ya eklenir.'
            ),
            (
              'Harcamayı nasıl eklerim?',
              'Ana ekrandaki + butonuna bas, tutarı yaz, kategoriyi seç, Kaydet. Detaylı giriş için "Detaylı giriş".'
            ),
            (
              'Kategoriye bütçe nasıl koyarım?',
              'Kategoriyi aç → "Calculate Budget" → aylık limit gir. Kartta "harcanan / bütçe" çubuğu görünür. Kaldırmak için aynı yerde "Bütçeyi kaldır".'
            ),
            (
              'Dolar nasıl biriktiririm?',
              'Savings (\$) zarfını aç → "Para ekle" ile doğrudan ekle, ya da "Çevir" ile ₺\'den dolara çevir (güncel kur otomatik gelir).'
            ),
            (
              'Hedef (araba, tatil) nasıl koyarım?',
              'Goals sekmesi → "+ Hedef" → isim + tutar. Hedefe "Para ekle" dedikçe çubuk dolar; ayrılan para Kalan para\'dan düşer.'
            ),
            (
              'Yanlış girdiğim işlemi nasıl silerim?',
              'İşleme dokun → açılan kutuda "Sil". Bakiyeler otomatik düzeltilir.'
            ),
            (
              'Verilerim güvende mi?',
              'Evet. Veriler Firebase\'de senin hesabına bağlı; şifren geri döndürülemez şekilde şifrelenir (hash). Face ID/passcode kilidini Profil → Güvenlik\'ten açabilirsin.'
            ),
          ],
        'ru' => const [
            (
              'Что значит «Остаток» сверху?',
              'Это деньги, оставшиеся после вычета всех расходов из дохода (Календарь). Уменьшается при каждом расходе.'
            ),
            (
              'Как внести доход?',
              'Открой вкладку Calendar и впиши заработок по рабочим дням. Суммы добавятся к «Остатку».'
            ),
            (
              'Как добавить расход?',
              'Кнопка + на главном экране → сумма → категория → Сохранить. Для деталей — «Подробный ввод».'
            ),
            (
              'Как задать бюджет категории?',
              'Открой категорию → «Calculate Budget» → месячный лимит. На карточке появится «потрачено / бюджет».'
            ),
            (
              'Как копить в долларах?',
              'Открой конверт Savings (\$) → «Пополнить» напрямую, или «Обменять» ₺ в доллары (курс подставляется).'
            ),
            (
              'Как поставить цель (машина, отпуск)?',
              'Вкладка Goals → «+ Цель» → название и сумма. Пополняешь цель — полоса растёт, деньги уходят из «Остатка».'
            ),
            (
              'Как удалить ошибочную операцию?',
              'Нажми на операцию → «Удалить». Балансы пересчитаются автоматически.'
            ),
            (
              'Мои данные в безопасности?',
              'Да. Данные в Firebase под твоим аккаунтом; пароль хранится в виде необратимого хэша. Блокировку Face ID включи в Профиль → Безопасность.'
            ),
          ],
        _ => const [
            (
              'What does "Money left" mean?',
              'The money left after subtracting all expenses from your income (Calendar). It drops with every expense you log.'
            ),
            (
              'How do I enter my income?',
              'Go to the Calendar tab and enter earnings on the days you worked. Those amounts add to "Money left".'
            ),
            (
              'How do I add an expense?',
              'Tap + on the home screen, enter the amount, pick a category, Save. Use "More options" for income/transfer.'
            ),
            (
              'How do I set a category budget?',
              'Open a category → "Calculate Budget" → enter a monthly limit. The card shows a "spent / budget" bar. Remove it with "Remove budget".'
            ),
            (
              'How do I save in dollars?',
              'Open the Savings (\$) envelope → "Add funds" directly, or "Convert" ₺ to dollars (live rate is filled in).'
            ),
            (
              'How do I set a goal (car, trip)?',
              'Goals tab → "+ Goal" → name and amount. Add money to it and the bar fills; the set-aside amount leaves "Money left".'
            ),
            (
              'How do I delete a wrong transaction?',
              'Tap the transaction → "Delete". Balances update automatically.'
            ),
            (
              'Is my data safe?',
              'Yes. Data lives in Firebase under your account; your password is stored as an irreversible hash. Enable the Face ID lock in Profile → Security.'
            ),
          ],
      };
}

/// Tek SSS kartı: soru + (+/−) rozeti; açıkken accent çerçeve ve cevap.
class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: expanded ? c.accent : c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                              color: c.text)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: expanded
                            ? c.accent.withValues(alpha: 0.14)
                            : c.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        expanded ? Icons.remove_rounded : Icons.add_rounded,
                        size: 16,
                        color: expanded ? c.accent : c.textMuted,
                      ),
                    ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 11),
                  Text(answer,
                      style: TextStyle(
                          fontSize: 13.5, height: 1.55, color: c.textMuted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dairesel geri butonu — surface zemin + border (tasarımdaki başlık deseni).
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.budgy;
    return Material(
      color: c.surface,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: c.text),
        ),
      ),
    );
  }
}

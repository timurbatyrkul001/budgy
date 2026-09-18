import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tokens.dart';

/// Gizlilik politikası — uygulama içi (store için ayrıca URL'de barındırılmalı).
/// Tüm renkler [BudgyColors] token'larından gelir (açık + koyu tema).
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  List<(String, String)> _sections(String locale) => switch (locale) {
        'tr' => const [
            (
              'Topladığımız veriler',
              'Budgy, girdiğin finansal bilgileri saklar: çalışma günleri, '
                  'gelir, gider, transfer, zarflar, bütçeler ve hedefler. '
                  'Ayrıca profil bilgilerin (isim, e-posta, opsiyonel telefon '
                  've fotoğraf) ile hesabını tanımlayan kimlik tutulur.',
            ),
            (
              'Verini nasıl kullanırız',
              'Verin yalnızca uygulamanın özelliklerini sağlamak için '
                  '(bütçeni takip etmek) kullanılır. Verini satmayız ve '
                  'reklam için kullanmayız.',
            ),
            (
              'Depolama ve güvenlik',
              'Verin Google Firebase (Cloud Firestore) üzerinde tutulur ve '
                  'yalnızca kendi hesabınla erişilebilir. Şifren geri '
                  'döndürülemez şekilde şifrelenir (hash); aktarım TLS ile '
                  'şifrelidir. Banka hesabına bağlanmayız.',
            ),
            (
              'Paylaşım',
              'Kişisel verini üçüncü taraflarla paylaşmayız. Sadece uygulamayı '
                  'çalıştıran bulut altyapı sağlayıcısı (Google Firebase) '
                  'kullanılır.',
            ),
            (
              'Çökme raporları',
              'Uygulama beklenmedik şekilde kapanırsa, hatayı düzeltebilmek '
                  'için Google Firebase Crashlytics\'e teknik bir rapor '
                  'gönderilir: cihaz modeli, işletim sistemi sürümü ve hatanın '
                  'oluştuğu kod satırları. Bu raporlar finansal verini '
                  'içermez.',
            ),
            (
              'Döviz kurları',
              'Döviz çevirme ekranını açtığında güncel kuru almak için '
                  'open.er-api.com adresine istek gönderilir. Bu isteğe hiçbir '
                  'kişisel veri ya da tutar eklenmez.',
            ),
            (
              'Haklarin',
              'Hesabını ve tüm verini istediğin an silebilirsin: '
                  'Profil → Hesabı sil. Bu işlem kalıcıdır.',
            ),
            (
              'İletişim',
              'Gizlilikle ilgili soruların için Yardım Merkezi\'ndeki '
                  'e-postadan bize yazabilirsin.',
            ),
          ],
        'ru' => const [
            (
              'Какие данные мы собираем',
              'Budgy хранит введённую тобой финансовую информацию: рабочие '
                  'дни, доходы, расходы, переводы, конверты, бюджеты и цели. '
                  'Также хранятся данные профиля (имя, email, по желанию '
                  'телефон и фото) и идентификатор аккаунта.',
            ),
            (
              'Как мы используем данные',
              'Данные используются только для работы приложения (учёт '
                  'бюджета). Мы не продаём данные и не используем их для '
                  'рекламы.',
            ),
            (
              'Хранение и безопасность',
              'Данные хранятся в Google Firebase (Cloud Firestore) и доступны '
                  'только твоему аккаунту. Пароль хранится в виде необратимого '
                  'хэша; передача шифруется по TLS. Мы не подключаемся к '
                  'банковскому счёту.',
            ),
            (
              'Передача третьим лицам',
              'Мы не передаём персональные данные третьим лицам, кроме '
                  'облачного провайдера (Google Firebase), необходимого для '
                  'работы приложения.',
            ),
            (
              'Отчёты о сбоях',
              'Если приложение неожиданно закроется, в Google Firebase '
                  'Crashlytics отправляется технический отчёт: модель '
                  'устройства, версия ОС и строки кода, где произошла ошибка. '
                  'Финансовые данные в такие отчёты не попадают.',
            ),
            (
              'Курсы валют',
              'При открытии экрана обмена валюты приложение запрашивает '
                  'актуальный курс с open.er-api.com. Никакие персональные '
                  'данные или суммы в этот запрос не добавляются.',
            ),
            (
              'Твои права',
              'Ты можешь удалить аккаунт и все данные в любой момент: '
                  'Профиль → Удалить аккаунт. Действие необратимо.',
            ),
            (
              'Контакты',
              'По вопросам конфиденциальности напиши нам на email из раздела '
                  '«Центр помощи».',
            ),
          ],
        _ => const [
            (
              'Data we collect',
              'Budgy stores the financial information you enter — work days, '
                  'earnings, incomes, expenses, transfers, envelopes and '
                  'budgets. We also store your profile (name, email, optional '
                  'phone and photo) and an account identifier.',
            ),
            (
              'How we use your data',
              'Your data is used only to provide the app\'s features '
                  '(tracking your budget). We do not sell your data and do not '
                  'use it for advertising.',
            ),
            (
              'Storage & security',
              'Your data is stored on Google Firebase (Cloud Firestore) and is '
                  'accessible only by your own account. Your password is stored '
                  'as an irreversible hash; transfer is encrypted with TLS. We '
                  'do not connect to your bank account.',
            ),
            (
              'Sharing',
              'We do not share your personal data with third parties, except '
                  'the cloud infrastructure provider (Google Firebase) needed '
                  'to run the app.',
            ),
            (
              'Crash reports',
              'If the app closes unexpectedly, a technical report is sent to '
                  'Google Firebase Crashlytics so we can fix it: device model, '
                  'OS version and the lines of code where the error occurred. '
                  'These reports contain no financial data.',
            ),
            (
              'Exchange rates',
              'When you open the currency conversion screen, the app requests '
                  'the current rate from open.er-api.com. No personal data or '
                  'amounts are included in that request.',
            ),
            (
              'Your rights',
              'You can delete your account and all your data at any time from '
                  'Profile → Delete account. This action is permanent.',
            ),
            (
              'Contact',
              'For privacy questions, write to us at the email in the Help '
                  'Center.',
            ),
          ],
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.budgy;
    final str = ref.watch(strProvider);
    final sections = _sections(str.localeCode);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Başlık çubuğu: dairesel geri butonu + ortalanmış başlık.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  _BackButton(),
                  Expanded(
                    child: Text(
                      str.confidentialityPolicy,
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
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    Text('${i + 1}. ${sections[i].$1}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: c.text)),
                    const SizedBox(height: 7),
                    Text(sections[i].$2,
                        style: TextStyle(
                            fontSize: 14, height: 1.6, color: c.textMuted)),
                    if (i != sections.length - 1) const SizedBox(height: 20),
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

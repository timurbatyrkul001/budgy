import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';

/// Kullanım Şartları (EULA) — uygulama içi.
///
/// Apple, abonelik satan uygulamalarda paywall'da bu ekrana bağlantı
/// ZORUNLU tutuyor; Pro aboneliği bu ekran olmadan onaylanmaz. Gizlilik
/// politikasıyla kardeş ekran, ama bu yeni tasarım (`Ex.`) kullanıyor —
/// privacy_policy_screen henüz eski token'larda, göç listesinde.
///
/// Metin hukukçu onayından geçmedi: Apple'ın standart EULA'sının üstüne
/// uygulamaya özgü maddeler (abonelik, yapay zekâ, finansal tavsiye
/// olmaması) eklenmiş hâli. Yayından önce gözden geçirilmeli.
class TermsOfUseScreen extends ConsumerWidget {
  const TermsOfUseScreen({super.key});

  List<(String, String)> _sections(String locale) => switch (locale) {
        'tr' => const [
            (
              'Kabul',
              'Budgy\'yi kullanarak bu şartları kabul etmiş olursun. Kabul '
                  'etmiyorsan uygulamayı kullanma. Hesap açtığında bu şartlar '
                  'seninle aramızdaki sözleşme yerine geçer.',
            ),
            (
              'Budgy ne yapar, ne yapmaz',
              'Budgy kişisel bir bütçe takip aracıdır: girdiğin gelir ve '
                  'giderleri saklar, toplar ve sana gösterir. '
                  'Budgy bir banka değildir, paranı tutmaz, ödeme yapmaz ve '
                  'banka hesabına bağlanmaz. Gösterdiği hiçbir sayı, grafik '
                  'ya da öneri FİNANSAL TAVSİYE DEĞİLDİR. Para kararlarını '
                  'kendi sorumluluğunda verirsin.',
            ),
            (
              'Hesabın',
              'Hesabını açarken doğru bilgi vermen gerekir. Şifrenin '
                  'güvenliğinden sen sorumlusun; hesabınla yapılan işlemler '
                  'sana aittir. 13 yaşından küçüksen Budgy\'yi kullanamazsın. '
                  'Hesabını ve tüm verini istediğin an silebilirsin: '
                  'Ayarlar → Hesabı sil. Bu işlem geri alınamaz.',
            ),
            (
              'Pro aboneliği',
              'Bazı özellikler (ayrıntılı analiz, bütçe takibi, fiş tarama ve '
                  'sesli giriş) ücretli Pro aboneliğine dahildir. Abonelik '
                  'dönem sonunda OTOMATİK YENİLENİR; yenilemeyi dönem '
                  'bitiminden en az 24 saat önce iptal etmezsen ücret tekrar '
                  'alınır.\n\n'
                  'Ödeme, abonelik yönetimi ve iptal tamamen App Store ya da '
                  'Google Play üzerinden yürür — biz kart bilgini görmeyiz ve '
                  'saklamayız. İptal için: iPhone\'da Ayarlar → Apple Kimliğin '
                  '→ Abonelikler, Android\'de Play Store → Abonelikler.\n\n'
                  'İade talepleri de mağazaya yapılır; iade politikası '
                  'Apple ve Google\'ın kurallarına tabidir. Ücretsiz deneme '
                  'sunulduğunda, deneme bitmeden iptal etmezsen ücretli '
                  'döneme geçersin.',
            ),
            (
              'Yapay zekâ özellikleri',
              'Fiş tarama ve sesli giriş, girdiğin görsel ya da metni '
                  'işlenmek üzere Anthropic\'e gönderir. Bu özellikleri '
                  'kullanman, bu aktarımı kabul ettiğin anlamına gelir; '
                  'kullanmazsan hiçbir veri gönderilmez.\n\n'
                  'Yapay zekâ hata yapabilir: tutarı, tarihi ya da kategoriyi '
                  'yanlış okuyabilir. Kaydetmeden önce sonucu kontrol etmek '
                  'senin sorumluluğundadır.',
            ),
            (
              'Uygun kullanım',
              'Budgy\'yi yasa dışı bir amaçla kullanamaz, kodunu tersine '
                  'mühendislikle çözmeye çalışamaz, servislerimize otomatik '
                  'yük bindiremez ve başkasının hesabına erişmeye '
                  'çalışamazsın.',
            ),
            (
              'Verin',
              'Verini nasıl topladığımız, sakladığımız ve koruduğumuz '
                  'Gizlilik Politikası\'nda anlatılıyor — Ayarlar → Gizlilik '
                  'Politikası. Bu şartların ayrılmaz parçasıdır.',
            ),
            (
              'Sorumluluk sınırı',
              'Budgy "olduğu gibi" sunulur. Kesintisiz ya da hatasız '
                  'çalışacağını garanti etmiyoruz. Uygulamadaki bir hesaplama '
                  'hatası, veri kaybı ya da hizmet kesintisi yüzünden '
                  'uğrayacağın dolaylı zararlardan sorumlu değiliz. '
                  'Sorumluluğumuz her hâlükârda son 12 ayda bize ödediğin '
                  'tutarla sınırlıdır.\n\n'
                  'Finansal kayıtlarının yedeğini almanı öneririz: '
                  'Ayarlar → Veri yönetimi → CSV dışa aktar.',
            ),
            (
              'Değişiklikler ve fesih',
              'Bu şartları değiştirebiliriz; önemli bir değişiklikte '
                  'uygulama içinde haber veririz. Değişiklikten sonra '
                  'kullanmaya devam etmen yeni şartları kabul ettiğin '
                  'anlamına gelir. Şartları ihlal edersen hesabını '
                  'kapatabiliriz.',
            ),
            (
              'İletişim',
              'Sorularını Ayarlar → Yardım Merkezi\'ndeki e-posta adresine '
                  'yazabilirsin.',
            ),
          ],
        'ru' => const [
            (
              'Согласие',
              'Пользуясь Budgy, ты принимаешь эти условия. Если не '
                  'согласен — не используй приложение. При создании аккаунта '
                  'эти условия заменяют договор между нами.',
            ),
            (
              'Что Budgy делает и чего не делает',
              'Budgy — личный инструмент учёта бюджета: хранит введённые '
                  'доходы и расходы, считает и показывает их. '
                  'Budgy не банк: не хранит твои деньги, не проводит платежи '
                  'и не подключается к банковскому счёту. Ни одна цифра, '
                  'диаграмма или подсказка НЕ ЯВЛЯЕТСЯ ФИНАНСОВЫМ СОВЕТОМ. '
                  'Решения о деньгах ты принимаешь под свою ответственность.',
            ),
            (
              'Твой аккаунт',
              'При регистрации нужно указывать достоверные данные. За '
                  'сохранность пароля отвечаешь ты; действия в твоём аккаунте '
                  'считаются твоими. Budgy нельзя пользоваться, если тебе '
                  'меньше 13 лет. Аккаунт и все данные можно удалить в любой '
                  'момент: Настройки → Удалить аккаунт. Это необратимо.',
            ),
            (
              'Подписка Pro',
              'Часть функций (подробная аналитика, бюджеты, сканирование '
                  'чеков и голосовой ввод) входит в платную подписку Pro. '
                  'Подписка ПРОДЛЕВАЕТСЯ АВТОМАТИЧЕСКИ; если не отменить её '
                  'минимум за 24 часа до конца периода, спишется снова.\n\n'
                  'Оплата, управление и отмена целиком проходят через App '
                  'Store или Google Play — мы не видим и не храним данные '
                  'карты. Отмена: на iPhone Настройки → Apple ID → Подписки, '
                  'на Android Play Store → Подписки.\n\n'
                  'Возвраты тоже запрашиваются в магазине и подчиняются '
                  'правилам Apple и Google. Если есть бесплатный пробный '
                  'период и ты не отменишь его до конца, начнётся платный.',
            ),
            (
              'Функции с искусственным интеллектом',
              'Сканирование чеков и голосовой ввод отправляют введённое '
                  'изображение или текст на обработку в Anthropic. '
                  'Использование этих функций означает согласие на передачу; '
                  'если ими не пользоваться, ничего не отправляется.\n\n'
                  'ИИ может ошибиться: неверно распознать сумму, дату или '
                  'категорию. Проверять результат перед сохранением — твоя '
                  'ответственность.',
            ),
            (
              'Допустимое использование',
              'Нельзя использовать Budgy в противозаконных целях, '
                  'декомпилировать код, создавать автоматическую нагрузку на '
                  'наши сервисы и пытаться получить доступ к чужому аккаунту.',
            ),
            (
              'Твои данные',
              'Как мы собираем, храним и защищаем данные, описано в Политике '
                  'конфиденциальности — Настройки → Политика '
                  'конфиденциальности. Она является неотъемлемой частью этих '
                  'условий.',
            ),
            (
              'Ограничение ответственности',
              'Budgy предоставляется «как есть». Мы не гарантируем работу без '
                  'перебоев и ошибок. Мы не отвечаем за косвенный ущерб из-за '
                  'ошибки в расчётах, потери данных или перерыва в работе. '
                  'Наша ответственность в любом случае ограничена суммой, '
                  'уплаченной нам за последние 12 месяцев.\n\n'
                  'Рекомендуем делать резервные копии: Настройки → Управление '
                  'данными → Экспорт CSV.',
            ),
            (
              'Изменения и прекращение',
              'Мы можем менять эти условия; о существенных изменениях '
                  'сообщим в приложении. Продолжая пользоваться после '
                  'изменений, ты принимаешь новую редакцию. При нарушении '
                  'условий мы можем закрыть аккаунт.',
            ),
            (
              'Связь',
              'Вопросы можно отправить на адрес из раздела Настройки → Центр '
                  'помощи.',
            ),
          ],
        _ => const [
            (
              'Acceptance',
              'By using Budgy you accept these terms. If you do not agree, do '
                  'not use the app. When you create an account, these terms '
                  'form the agreement between us.',
            ),
            (
              'What Budgy does and does not do',
              'Budgy is a personal budgeting tool: it stores the income and '
                  'expenses you enter, adds them up and shows them back to '
                  'you. Budgy is not a bank — it does not hold your money, '
                  'make payments, or connect to your bank account. No number, '
                  'chart or suggestion it shows is FINANCIAL ADVICE. Money '
                  'decisions are yours and yours alone.',
            ),
            (
              'Your account',
              'You must give accurate information when you sign up. You are '
                  'responsible for keeping your password safe; activity under '
                  'your account is treated as yours. You may not use Budgy if '
                  'you are under 13. You can delete your account and all your '
                  'data at any time: Settings → Delete account. This cannot '
                  'be undone.',
            ),
            (
              'Pro subscription',
              'Some features (detailed analytics, budget tracking, receipt '
                  'scanning and voice entry) are part of the paid Pro '
                  'subscription. Subscriptions RENEW AUTOMATICALLY; unless you '
                  'cancel at least 24 hours before the period ends, you will '
                  'be charged again.\n\n'
                  'Payment, subscription management and cancellation run '
                  'entirely through the App Store or Google Play — we never '
                  'see or store your card details. To cancel: on iPhone, '
                  'Settings → your Apple Account → Subscriptions; on Android, '
                  'Play Store → Subscriptions.\n\n'
                  'Refunds are requested from the store and follow Apple\'s '
                  'and Google\'s policies. Where a free trial is offered, you '
                  'move to the paid period unless you cancel before the trial '
                  'ends.',
            ),
            (
              'AI features',
              'Receipt scanning and voice entry send the image or text you '
                  'provide to Anthropic for processing. Using these features '
                  'means you accept that transfer; if you do not use them, '
                  'nothing is sent.\n\n'
                  'AI can get things wrong — it may misread an amount, a date '
                  'or a category. Checking the result before saving is your '
                  'responsibility.',
            ),
            (
              'Acceptable use',
              'You may not use Budgy for unlawful purposes, reverse engineer '
                  'it, place automated load on our services, or attempt to '
                  'access anyone else\'s account.',
            ),
            (
              'Your data',
              'How we collect, store and protect your data is described in '
                  'the Privacy Policy — Settings → Privacy policy. It forms '
                  'part of these terms.',
            ),
            (
              'Limitation of liability',
              'Budgy is provided "as is". We do not guarantee it will run '
                  'without interruption or error. We are not liable for '
                  'indirect losses arising from a calculation error, data '
                  'loss or service interruption. Our liability is in any case '
                  'limited to what you paid us over the past 12 months.\n\n'
                  'We recommend keeping your own backup: Settings → Data '
                  'management → Export CSV.',
            ),
            (
              'Changes and termination',
              'We may change these terms; we will tell you in the app when a '
                  'change is significant. Continuing to use Budgy after a '
                  'change means you accept the new version. We may close your '
                  'account if you break these terms.',
            ),
            (
              'Contact',
              'Send questions to the email address in Settings → Help Center.',
            ),
          ],
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final sections = _sections(str.localeCode);

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Diğer profil ekranlarıyla aynı geri düğmesi. BudgyBackButton
            // altına 12 px boşluk koyuyor; başlık aynı hizada dursun diye o da
            // aynı boşluğu alır, satırın kendi alt boşluğu sıfırlandı.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Row(
                children: [
                  const BudgyBackButton(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        rs.termsTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Ex.text),
                      ),
                    ),
                  ),
                  // Geri düğmesiyle aynı genişlikte boşluk: başlık tam ortada.
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                children: [
                  Text(rs.termsUpdated,
                      style: const TextStyle(
                          fontSize: 13, color: Ex.textFaint)),
                  const SizedBox(height: 18),
                  for (var i = 0; i < sections.length; i++) ...[
                    Text('${i + 1}. ${sections[i].$1}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Ex.text)),
                    const SizedBox(height: 7),
                    Text(sections[i].$2,
                        style: const TextStyle(
                            fontSize: 14, height: 1.6, color: Ex.textMuted)),
                    if (i != sections.length - 1) const SizedBox(height: 22),
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

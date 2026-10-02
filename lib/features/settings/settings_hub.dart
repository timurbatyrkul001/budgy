import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/gradient_icon.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../accounts/accounts_screen.dart';
import '../automation/automation_screen.dart';
import '../categories/categories_screen.dart';
import '../goals/goals_screen.dart';
import '../pro/paywall_sheet.dart';
import '../pro/pro_state.dart';
import '../profile/contact_screen.dart';
import '../profile/notification_preferences_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reminders/reminders_screen.dart';
import '../workdays/calendar_screen.dart';
import 'settings_about_screen.dart';
import 'settings_account_screen.dart';
import 'settings_appearance_screen.dart';

/// Uygulama sürümü (package_info) — testte/önizlemede boş kalabilir.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

/// Ayarlar merkezi — cüzdan çipinden açılan tam ekran.
///
/// 2026-10 yeniden yapı: eskiden 25 satır tek listede, dört bölüm başlığıyla
/// akıyordu ve bunaltıcıydı. Şimdi bölüm BAŞLIĞI yok; gruplama kısa beyaz
/// kartlar ve aralarındaki boşlukla anlatılıyor. Hesap, görünüm ve yasal
/// satırlar kendi alt ekranlarına indi ([SettingsAccountScreen],
/// [SettingsAppearanceScreen], [SettingsAboutScreen]); ana ekranda yalnız
/// giriş kapıları kaldı. Üstte Pro tanıtım kartı.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key, this.initialScroll = 0});

  /// Önizleme: açılışta kaydırılmış konum (ekran görüntüsü için).
  final double initialScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(rsProvider);
    final str = ref.watch(strProvider);
    final categoryCount = ref.watch(categoryCountProvider);
    final isPro = ref.watch(isProProvider);

    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          controller: ScrollController(initialScrollOffset: initialScroll),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // ── başlık ──────────────────────────────────────────────────
            Row(
              children: [
                GlassSquareButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Text(rs.settings,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: Ex.text)),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 18),

            // ── Pro tanıtımı ────────────────────────────────────────────
            // Kullanıcı zaten Pro ise kart HİÇ çizilmez: sahip olduğu şeyi
            // ona satmaya çalışmak hem güven kırar hem de ekranın en değerli
            // yerini (ilk görünen alan) boşa harcar. Pro olan için burada
            // gösterilecek bir şey yok — abonelik yönetimi mağazanın işi.
            if (!isPro) ...[
              _ProCard(
                rs: rs,
                onUpgrade: () => showPaywall(context, ProFeature.analytics),
                // Satın alım geri yükleme RevenueCat ile gelecek; paywall'ın
                // satın alma düğmesiyle aynı dürüst mesajı veriyoruz — sessiz
                // bir düğme "bozuk" sanılır.
                onRestore: () => showErrorSnack(context, rs.paywallSoon),
              ),
              const SizedBox(height: 14),
            ],

            // ── Kart 1: kişisel ─────────────────────────────────────────
            // Cüzdan (avatar + ad) satırı artık burada DEĞİL: cüzdan
            // düzenleyici Hesabım › Kişisel bilgiler ekranına taşındı
            // ([SettingsPersonalDetailsScreen]). Hub'da iki "kimlik" girişi
            // (cüzdan + hesap) yan yana durunca kullanıcı hangisine
            // dokunacağını bilemiyordu; tek kapı "Hesabım".
            SettingsCard(rows: [
              SettingsRow(
                icon: Icons.person_rounded,
                title: rs.hubMyAccount,
                onTap: () => pushSettings(context, const SettingsAccountScreen()),
              ),
              SettingsRow(
                icon: Icons.notifications_rounded,
                title: rs.hubNotifications,
                onTap: () => pushSettings(
                    context, const NotificationPreferencesScreen()),
              ),
              SettingsRow(
                icon: Icons.tune_rounded,
                title: rs.hubAppearance,
                onTap: () =>
                    pushSettings(context, const SettingsAppearanceScreen()),
              ),
            ]),
            const SizedBox(height: 14),

            // ── Kart 2: para ────────────────────────────────────────────
            SettingsCard(rows: [
              // Eski "Hesaplar" (döviz kumbaraları, home/accounts_screen) ile
              // "Hesaplarım" (kart yönetimi, accounts/accounts_screen) tek
              // satırda birleşti. Hedef KART YÖNETİMİ: ayarlardan beklenen şey
              // hesap ekleyip düzenlemek, bakiye bakmak değil. Döviz
              // kumbaraları kaybolmadı — ana ekrandaki "Hesaplar › Tümünü
              // gör" zaten o listeyi açıyor; ayarlarda ikinci bir kapı
              // fazlalıktı.
              SettingsRow(
                icon: Icons.credit_card_rounded,
                title: rs.accounts,
                onTap: () => pushSettings(context, const ManageAccountsScreen()),
              ),
              SettingsRow(
                icon: Icons.grid_view_rounded,
                title: rs.categories,
                value: '$categoryCount',
                onTap: () => pushSettings(context, const CategoriesScreen()),
              ),
              SettingsRow(
                icon: Icons.calendar_month_rounded,
                title: rs.calendar,
                onTap: () => pushSettings(context, const CalendarScreen()),
              ),
            ]),
            const SizedBox(height: 14),

            // ── Kart 3: otomasyon ───────────────────────────────────────
            SettingsCard(rows: [
              SettingsRow(
                icon: Icons.repeat_rounded,
                title: rs.recurringTitle,
                onTap: () => pushSettings(context, const RecurringScreen()),
              ),
              SettingsRow(
                icon: Icons.auto_fix_high_rounded,
                title: rs.automation,
                onTap: () => pushSettings(context, const AutomationScreen()),
              ),
              SettingsRow(
                icon: Icons.flag_rounded,
                title: rs.goals,
                onTap: () => pushSettings(context, const GoalsScreen()),
              ),
              SettingsRow(
                icon: Icons.notifications_active_rounded,
                title: rs.paymentReminders,
                onTap: () => pushSettings(context, const RemindersScreen()),
              ),
            ]),
            const SizedBox(height: 14),

            // ── Kart 4: destek ve yasal ─────────────────────────────────
            SettingsCard(rows: [
              // SSS + Yardım Merkezi tek satırda. Yardım Merkezi (iletişim)
              // zaten içinde SSS'e kısayol taşıyor; SSS'in içinde iletişim
              // yok. Bu yüzden kapı iletişim ekranı — her ikisine de tek
              // dokunuşla ulaşılıyor.
              SettingsRow(
                icon: Icons.help_rounded,
                title: rs.hubHelp,
                subtitle: '${str.faqs} · ${str.helpCenter}',
                onTap: () => pushSettings(context, const ContactScreen()),
              ),
              SettingsRow(
                icon: Icons.info_rounded,
                title: rs.hubAbout,
                onTap: () => pushSettings(context, const SettingsAboutScreen()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Ayarlar içinden alt ekran açar — hub ve üç alt ekran aynı geçişi kullansın.
void pushSettings(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

// ── Pro tanıtım kartı ──────────────────────────────────────────────────────

/// Koyu zeminli Pro kartı: başlık, bir cümle, beyaz düğme, altta geri yükleme.
///
/// Zemin mürekkep rengi ([Ex.text]) — kâğıt üstündeki tek koyu blok olduğu
/// için gözün ilk gittiği yer. Yeşil kullanılmadı: yeşil bu dilde "para ve
/// eylem", kartın tamamını yeşile boyamak düğmeyi silikleştirirdi.
class _ProCard extends StatelessWidget {
  const _ProCard({
    required this.rs,
    required this.onUpgrade,
    required this.onRestore,
  });

  final RS rs;
  final VoidCallback onUpgrade;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    // "{restore}" şablonu: tıklanabilir parça cümlenin neresindeyse oraya
    // konur; TR/EN/RU'da sonda ama bu varsayıma dayanmıyoruz.
    final parts = rs.hubProRestoreTpl.split('{restore}');
    final before = parts.first;
    final after = parts.length > 1 ? parts[1] : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Ex.text,
        borderRadius: BorderRadius.circular(Ex.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rs.hubProTitle,
              style: const TextStyle(
                  fontFamily: 'InterDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.1,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(rs.hubProBody,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.35, color: Color(0xB3FFFFFF))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Ex.text,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Ex.buttonRadius)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: Text(rs.hubProCta,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                if (before.isNotEmpty)
                  Text(before,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0x99FFFFFF))),
                // InkWell yerine GestureDetector: koyu zeminde mürekkep
                // dalgası beyaz leke gibi görünüyor.
                GestureDetector(
                  onTap: onRestore,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(rs.hubProRestore,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            color: Colors.white)),
                  ),
                ),
                if (after.isNotEmpty)
                  Text(after,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0x99FFFFFF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paylaşılan ayar bileşenleri ────────────────────────────────────────────
// Hub ve üç alt ekran aynı kart/satır/kahraman bloğunu kullanır; kopyala-
// yapıştır olmasın diye kamuya açık.

/// İkon sütunu genişliği + boşluk: ayırıcı çizgi tam buradan başlar ki
/// "ikonun bittiği yerden" kuralı tutsun.
const _kRowIconWidth = 34.0;
const _kRowIconGap = 12.0;

/// Beyaz kart: satırlar ince çizgiyle ayrık, çizgi ikonun bittiği yerden.
///
/// Bölüm başlığı YOK — gruplama kartın kendisiyle ve kartlar arası boşlukla
/// anlatılır. Eski `_Section` küçük gri etiket taşıyordu; kalabalık ekranda
/// o etiketler birer satır daha gibi okunuyordu.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, this.label, required this.rows});

  /// Kartın ÜSTÜNDE küçük gri etiket ("Kimlik ve giriş", "Verilerin").
  ///
  /// Yalnız alt ekranlar verir: orada gruplar adlandırılıyor. Hub'da
  /// verilmez — hub'da bölüm başlığı olmaması bilinçli karar, kalabalık
  /// ekranda etiketler birer satır daha gibi okunuyordu.
  final String? label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final card = ExCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0)
              const Divider(
                  height: 1,
                  color: Ex.border,
                  indent: _kRowIconWidth + _kRowIconGap),
            r,
          ],
        ],
      ),
    );
    if (label == null || label!.isEmpty) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Soldan 4: etiket kart kenarlığıyla değil, içindeki metinle
          // hizalansın — kenarlıkla aynı hizada "dışarıda" duruyordu.
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label!,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Ex.textMuted)),
        ),
        card,
      ],
    );
  }
}

/// Ayar satırı: 28 px gradyan ikon, 17 px etiket, sağda değer/ok/anahtar.
///
/// İkon soluk kutusuz, doğrudan beyaz kartın üstünde ([GradientIcon] kararı:
/// kutu içindeki küçük ikonda gradyan okunmuyordu). [danger] satırlar
/// ([Ex.red]) düz renk: uyarı rengi süslenmez, aksi hâlde "çıkış yap" de
/// yeşil bir eylem gibi davet eder.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.description,
    this.value,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.danger = false,
  }) : assert(icon != null || leading != null, 'icon ya da leading gerekli');

  /// Gradyanla çizilecek Material ikonu.
  final IconData? icon;

  /// İkon yerine özel öncü (cüzdan avatarı). Verilirse [icon] yok sayılır.
  final Widget? leading;
  final String title;

  /// Tek satır, kesilir — e-posta, "Anonim hesap" gibi kısa ek bilgi.
  final String? subtitle;

  /// Başlığın altında ÇOK SATIRLI açıklama (bildirim türünün ne yaptığı
  /// gibi 2-4 satır). [subtitle]'dan farkı: sarar, kesilmez; sağdaki
  /// anahtarla birlikte "ayar + açıklama + anahtar" satırını kurar.
  final String? description;

  /// Sağda soluk değer (dil, para birimi, sayı).
  final String? value;

  /// Sağda ok yerine kendi bileşeni (anahtar).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Davet satırı (hesap oluştur) — yeşil etiket.
  final bool accent;

  /// Tehlikeli eylem — kırmızı etiket ve DÜZ kırmızı ikon.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Ex.red : (accent ? Ex.mint : Ex.text);
    final Widget lead = leading ??
        (danger
            ? Icon(icon, size: 28, color: Ex.red)
            : GradientIcon(icon!, size: 28));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          // Uzun açıklamalı satırda ikon ve ok ortaya değil başlığa
          // hizalanır; aksi hâlde 4 satırlık metnin ortasında asılı kalır.
          crossAxisAlignment: description == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: _kRowIconWidth,
                height: _kRowIconWidth,
                child: Center(child: lead)),
            const SizedBox(width: _kRowIconGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: color)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Ex.textMuted)),
                    ),
                  if (description != null && description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(description!,
                          style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: Ex.textSoft)),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Ex.textMuted)),
              ),
            ],
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right_rounded, color: Ex.textFaint),
              ),
          ],
        ),
      ),
    );
  }
}

/// İkonsuz eylem satırı: metin vurgu renginde ([Ex.mint]), sağda ok yok.
///
/// "Tümünü aç", "Bildirim ayarlarına git" gibi kartın SONUNDAKİ tek eylem
/// için. Normal [SettingsRow] ikon zorunlu tutar; burada ikon olsaydı eylem
/// diğer ayar satırlarından ayırt edilemezdi. Metin ikon sütununun bittiği
/// yerden başlar ki ayırıcı çizgiyle hizası bozulmasın.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final VoidCallback onTap;

  /// Kırmızı eylem (kartın sonunda "Tümünü sil" gibi) — yine düz renk.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            const SizedBox(width: _kRowIconWidth + _kRowIconGap),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: danger ? Ex.red : Ex.mint)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt ekran başı: yuvarlak kare rozet içinde gradyan ikon, başlık, paragraf.
///
/// Kullanıcı hub'dan "Hesabım" deyip geldi; buradaki paragraf ekranın neyi
/// kapsadığını tek bakışta söyler — satırları tek tek okumadan "aradığım
/// burada mı" sorusunu yanıtlasın diye.
class SettingsHero extends StatelessWidget {
  const SettingsHero({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Yuvarlak kare rozet (daire değil): yeşilin düşük alfalı zemini
        // üstünde gradyan ikon. Beyaz daire kâğıt üstünde "boş yuvarlak"
        // gibi duruyordu; renkli rozet ekranın kimliğini tek bakışta verir.
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Ex.brand.withValues(alpha: 0.12),
            borderRadius: Ex.squircle(72),
          ),
          child: Center(child: GradientIcon(icon, size: 34)),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.9,
                height: 1.1,
                color: Ex.text)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.4, color: Ex.textMuted)),
        ),
      ],
    );
  }
}

/// Alt ekran iskeleti: geri düğmesi, [SettingsHero], ardından kartlar.
/// Üç alt ekranın aynı kenar boşluğu ve ritmi paylaşması için tek yerde.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.hero, required this.children});

  final SettingsHero hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ex.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const BudgyBackButton(),
            const SizedBox(height: 8),
            hero,
            const SizedBox(height: 24),
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 14),
              c,
            ],
          ],
        ),
      ),
    );
  }
}

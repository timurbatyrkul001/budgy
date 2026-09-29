import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ex_style.dart';
import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/notifications.dart';
import 'onboarding_palette.dart';

// ═════════════════════════════════════════════════════════════════════════
// Ekran 1 — Bildirim izni
// ═════════════════════════════════════════════════════════════════════════

/// Sistem bildirim iznini ister; verildiyse true.
///
/// Sistem penceresi testte açılamaz; bu yüzden izin çağrısı widget'a gömülü
/// değil, [notificationPermissionRequesterProvider] üzerinden ya da
/// [NotificationAskPage.requestPermission] parametresiyle enjekte edilir.
typedef NotificationPermissionRequester = Future<bool> Function();

/// Varsayılan izin isteyici: `Notifications.init()` sistem penceresini
/// açar (iOS `requestPermissions`, Android 13+ `requestNotificationsPermission`),
/// ardından platformdan güncel durum okunur. Hata olursa false — akış asla
/// tıkanmaz.
Future<bool> requestNotificationPermission() async {
  try {
    await Notifications.init();
    final plugin = FlutterLocalNotificationsPlugin();
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final o = await ios.checkPermissions();
      return o?.isEnabled ?? false;
    }
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// İzin isteyici; test ve önizleme sahtesini `overrideWithValue` ile verir.
final notificationPermissionRequesterProvider =
    Provider<NotificationPermissionRequester>(
      (_) => requestNotificationPermission,
    );

/// Bildirim izni ekranının metinleri — koordinatör RS'den kurar.
class NotificationAskTexts {
  const NotificationAskTexts({
    required this.title,
    required this.body,
    required this.allow,
    required this.later,
  });

  final String title;

  /// Neden istiyoruz: günü işaretlemeyi hatırlatmak için.
  final String body;

  /// Siyah hap: sistem penceresini açar.
  final String allow;

  /// Metin düğmesi: izinsiz devam.
  final String later;
}

/// Bildirim izni — değer anlatıldıktan sonra, akışın sonuna yakın sorulur.
///
/// "İzin ver" sistem penceresini açar; sonuç ne olursa olsun [onNext]
/// çağrılır. "Şimdi değil" hiç sormadan `onNext(false)` der. İzin çağrısı
/// beklenirken düğme sönük kalır (iki kez dokunma yok).
class NotificationAskPage extends ConsumerStatefulWidget {
  const NotificationAskPage({
    super.key,
    required this.texts,
    required this.onNext,
    this.requestPermission,
  });

  final NotificationAskTexts texts;

  /// İzin verildiyse true; "Şimdi değil" ya da ret için false.
  final void Function(bool granted) onNext;

  /// Verilirse [notificationPermissionRequesterProvider] yerine bu çağrılır
  /// (testte sahte izin için).
  final NotificationPermissionRequester? requestPermission;

  @override
  ConsumerState<NotificationAskPage> createState() =>
      _NotificationAskPageState();
}

class _NotificationAskPageState extends ConsumerState<NotificationAskPage> {
  bool _busy = false;

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final NotificationPermissionRequester ask =
        widget.requestPermission ??
        ref.read(notificationPermissionRequesterProvider);
    var granted = false;
    try {
      granted = await ask();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onNext(granted);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        _PageTitle(t.title).enterUp(context, index: 0),
        const SizedBox(height: 16),
        _Body(t.body).enterUp(context, index: 1),
        const SizedBox(height: 32),
        // Zil: bildirimin kendisi kadar sade — mürekkep çizgili bir kart.
        Center(child: const _BellCard().enterUp(context, index: 2)),
        const Spacer(),
        const SizedBox(height: 24),
        _InkPillButton(
          label: t.allow,
          onTap: _busy ? null : _allow,
        ).enterUp(context, index: 3),
        const SizedBox(height: 4),
        _TextButton(
          label: t.later,
          onTap: _busy ? null : () => widget.onNext(false),
        ).enterUp(context, index: 4),
      ],
    );
  }
}

/// Örnek bildirim kartı: beyaz kart, yeşil zil noktası, iki satır iskelet.
/// Metin yok — dil bağımsız, sadece "bildirim" fikrini gösterir.
class _BellCard extends StatelessWidget {
  const _BellCard();

  @override
  Widget build(BuildContext context) {
    Widget line(double w) => Container(
      height: 8,
      width: w,
      decoration: BoxDecoration(
        color: Poster.ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Poster.ink.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Poster.ink.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Ex.brand,
              shape: BoxShape.circle,
            ),
            child: const CustomPaint(painter: _BellPainter(color: Ex.onBrand)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [line(120), const SizedBox(height: 7), line(170)],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Ekran 2 — İlk gününü işaretle
// ═════════════════════════════════════════════════════════════════════════

/// İlk gün ekranının metinleri — koordinatör RS'den kurar.
class FirstDayTexts {
  const FirstDayTexts({
    required this.title,
    required this.body,
    required this.tapHint,
    required this.amountHint,
    required this.confirm,
    required this.done,
    required this.next,
    required this.skip,
  });

  final String title;
  final String body;

  /// Takvimin altında, henüz dokunulmamışken.
  final String tapHint;

  /// Tutar alanının yer tutucusu.
  final String amountHint;

  /// Tutarı onaylayan hap.
  final String confirm;

  /// Kayıt sonrası kutlama satırı.
  final String done;

  /// Kayıt sonrası devam hapı.
  final String next;

  /// Atlama metin düğmesi.
  final String skip;
}

/// İlk gün — kullanıcı uygulamayı akışın içinde bir kez kullanır.
///
/// Bu ayın küçük takvimi; bugünün hücresi vurgulu. Dokununca tutar alanı
/// açılır, onaylanınca hücre yeşile döner ve küçük bir sıçrama yapar.
/// Tutar Firestore'a YAZILMAZ — [onNext] ile dışarı verilir, kaydetme
/// kararı koordinatörün (kullanıcı henüz giriş yapmamış olabilir).
/// "Şimdilik atla" → `onNext(null)`.
class FirstDayPage extends ConsumerStatefulWidget {
  const FirstDayPage({
    super.key,
    required this.texts,
    required this.onNext,
    this.today,
  });

  final FirstDayTexts texts;

  /// Girilen tutar; atlanırsa null.
  final void Function(double? amount) onNext;

  /// Takvimin "bugün"ü; null ise `DateTime.now()`. Testte sabitlemek için.
  final DateTime? today;

  @override
  ConsumerState<FirstDayPage> createState() => _FirstDayPageState();
}

enum _Stage { idle, entering, done }

class _FirstDayPageState extends ConsumerState<FirstDayPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  _Stage _stage = _Stage.idle;
  double? _saved;

  DateTime get _today {
    final t = widget.today ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  double? get _parsed {
    final v = parseAmount(_controller.text);
    return v == null || v <= 0 ? null : v;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tapToday() {
    // Kayıtlıyken tekrar dokunmak düzenlemeye açar; metin korunur.
    setState(() => _stage = _Stage.entering);
    _focus.requestFocus();
  }

  void _confirm() {
    final v = _parsed;
    if (v == null) return;
    _focus.unfocus();
    setState(() {
      _saved = v;
      _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.texts;
    final instant = reduceMotion(context);
    final d = instant ? Duration.zero : const Duration(milliseconds: 220);
    final stage = _stage;
    final saved = _saved;
    final short = MediaQuery.sizeOf(context).height < 640;

    return _FillScroll(
      children: [
        const SizedBox(height: 8),
        _PageTitle(t.title).enterUp(context, index: 0),
        const SizedBox(height: 12),
        _Body(t.body).enterUp(context, index: 1),
        SizedBox(height: short ? 16 : 24),
        _MonthCalendar(
          today: _today,
          marked: stage == _Stage.done,
          onTapToday: _tapToday,
        ).enterUp(context, index: 2),
        SizedBox(height: short ? 12 : 18),
        // Takvimin altı: ipucu → tutar alanı → kutlama satırı.
        AnimatedSwitcher(
          duration: d,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (stage) {
            _Stage.idle => _Hint(t.tapHint, key: const ValueKey('hint')),
            _Stage.entering => _AmountField(
              key: const ValueKey('field'),
              controller: _controller,
              focus: _focus,
              hint: t.amountHint,
              onSubmitted: _confirm,
            ),
            _Stage.done => _DoneLine(
              key: const ValueKey('done'),
              text: t.done,
              amount: saved ?? 0,
            ),
          },
        ).enterUp(context, index: 3),
        const Spacer(),
        const SizedBox(height: 24),
        // Alt düğmeler: aşamaya göre "Kaydet" / "Devam"; atlama yalnız
        // kayıt yokken.
        (switch (stage) {
          _Stage.idle => const SizedBox.shrink(),
          _Stage.entering => _InkPillButton(
            label: t.confirm,
            onTap: _parsed == null ? null : _confirm,
          ),
          _Stage.done => _InkPillButton(
            label: t.next,
            onTap: () => widget.onNext(saved),
          ),
        }).enterUp(context, index: 4),
        if (stage != _Stage.done) ...[
          const SizedBox(height: 4),
          _TextButton(
            label: t.skip,
            onTap: () => widget.onNext(null),
          ).enterUp(context, index: 5),
        ],
      ],
    );
  }
}

/// Bu ayın takvimi: ay adı, dar hafta günü baş harfleri, gün hücreleri.
/// Yalnız bugün dokunulabilir; öbür günler afişte bağlam için.
/// Ay adı ve gün baş harfleri [MaterialLocalizations]'tan gelir — intl
/// tarih verisi yüklenmemişken de (test) çalışır.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.today,
    required this.marked,
    required this.onTapToday,
  });

  final DateTime today;
  final bool marked;
  final VoidCallback onTapToday;

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex; // 0 = Pazar
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);
    // Ayın ilk gününün, haftanın ilk gününe göre sütunu.
    final firstWeekday = DateTime(today.year, today.month, 1).weekday % 7;
    final lead = (firstWeekday - first + 7) % 7;
    final rows = ((lead + daysInMonth) / 7).ceil();

    final labelStyle = TextStyle(
      fontFamily: 'InterDisplay',
      fontWeight: FontWeight.w600,
      fontSize: 11,
      color: Poster.inkFaint,
    );

    // Hücre: sayfa genişliğine göre (yan boşluk 20+20), 44'ü geçmez.
    // LayoutBuilder kullanılmıyor: sayfa IntrinsicHeight içinde ve
    // LayoutBuilder içsel ölçü veremez.
    final size = MediaQuery.sizeOf(context);
    final width = size.width - 40;
    // Kısa ekranda (iPhone SE sınıfı) hücre küçülür ki tutar alanı ve
    // düğme kaydırmadan görünsün.
    final maxCell = size.height < 640 ? 34.0 : 44.0;
    final cell = ((width - _gap * 6) / 7).clamp(28.0, maxCell);
    final gridWidth = cell * 7 + _gap * 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.formatMonthYear(today),
          style: const TextStyle(
            fontFamily: 'InterDisplay',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Poster.ink,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: gridWidth,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                SizedBox(
                  width: cell,
                  child: Text(
                    loc.narrowWeekdays[(first + i) % 7],
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          Row(
            children: [
              for (var c = 0; c < 7; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                () {
                  final day = r * 7 + c - lead + 1;
                  if (day < 1 || day > daysInMonth) {
                    return SizedBox(width: cell, height: cell);
                  }
                  final isToday = day == today.day;
                  return _DayCell(
                    day: day,
                    size: cell,
                    past: day < today.day,
                    today: isToday,
                    marked: isToday && marked,
                    onTap: isToday ? onTapToday : null,
                  );
                }(),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Gün hücresi. Geçmiş günler soluk, gelecek günler açık; bugün mürekkep
/// halkalı. İşaretlenince yeşile döner, tik çıkar ve 1 → 1.18 → 1 sıçrar
/// (kutlama; hareket azaltmada anında son hâl).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.size,
    required this.past,
    required this.today,
    required this.marked,
    required this.onTap,
  });

  final int day;
  final double size;
  final bool past;
  final bool today;
  final bool marked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final instant = reduceMotion(context);
    final d = instant ? Duration.zero : const Duration(milliseconds: 260);
    final fill = marked
        ? Ex.brand
        : today
        ? Colors.white
        : Poster.ink.withValues(alpha: past ? 0.06 : 0.03);
    final ink = marked
        ? Ex.onBrand
        : today
        ? Poster.ink
        : past
        ? Poster.inkFaint
        : Poster.inkSoft;
    final radius = BorderRadius.circular(size * 0.28);

    Widget cell = AnimatedContainer(
      duration: d,
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: today && !marked
            ? Border.all(color: Poster.ink, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: marked
          ? CustomPaint(
              size: Size.square(size * 0.5),
              painter: const _TickPainter(color: Ex.onBrand),
            )
          : Text(
              '$day',
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: today ? FontWeight.w900 : FontWeight.w600,
                fontSize: size * 0.34,
                height: 1,
                color: ink,
              ),
            ),
    );

    if (marked) {
      // Tek seferlik sıçrama: 0 → 1 arası ölçek eğrisi, tepe 1.18.
      cell = TweenAnimationBuilder<double>(
        key: const ValueKey('bounce'),
        duration: instant ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0, end: 1),
        builder: (context, t, child) => Transform.scale(
          scale: 1 + 0.18 * (1 - (2 * t - 1).abs()).clamp(0.0, 1.0),
          child: child,
        ),
        child: cell,
      );
    }

    return Semantics(
      button: onTap != null,
      selected: marked,
      label: '$day',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

/// Takvimin altındaki ipucu: yeşil nokta + kısa metin.
class _Hint extends StatelessWidget {
  const _Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Ex.brand,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.3,
              color: Poster.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tutar alanı: alt çizgili büyük sayı, sağda yeşil "+" göstergesi.
class _AmountField extends StatelessWidget {
  const _AmountField({
    super.key,
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Poster.ink.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Text(
            '+',
            style: TextStyle(
              fontFamily: 'InterDisplay',
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Ex.brand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmitted(),
              // Sayı, virgül ve nokta; `parseAmount` ikisini de anlar.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: FontWeight.w600,
                fontSize: 24,
                color: Poster.ink,
              ),
              cursorColor: Poster.ink,
              // Uygulama teması alanları koyu dolgulu çizer; afiş beyaz —
              // dolgu ve kenar kapatılır, kart kendi çerçevesini taşır.
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: Poster.inkFaint,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kayıt sonrası satır: yeşil tik + kutlama metni + tutar (para birimi
/// henüz seçilmemiş olabilir, bu yüzden sade sayı).
class _DoneLine extends StatelessWidget {
  const _DoneLine({super.key, required this.text, required this.amount});

  final String text;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(
            color: Ex.brand,
            shape: BoxShape.circle,
          ),
          child: const CustomPaint(painter: _TickPainter(color: Ex.onBrand)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.3,
              color: Poster.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '+${formatNumber(amount)}',
          style: const TextStyle(
            fontFamily: 'InterDisplay',
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Ex.brand,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Ortak parçalar (diğer onboarding dosyalarındaki eşlerinin private kopyası;
// koordinatör birleştirdiğinde kalkabilir)
// ═════════════════════════════════════════════════════════════════════════

/// Sayfa başlığı: sola yaslı display, 36 px (dar ekranda 32).
class _PageTitle extends StatelessWidget {
  const _PageTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width - 40 < 310;
    final size = narrow ? 32.0 : 36.0;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'InterDisplay',
        fontWeight: FontWeight.w900,
        fontSize: size,
        height: 1.0,
        letterSpacing: -1.5 * size / 36,
        color: Poster.ink,
      ),
    );
  }
}

/// Gövde metni.
class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 1.4,
        color: Poster.inkSoft,
      ),
    );
  }
}

/// İçerik ekrana sığmazsa kayar; sığarsa [Spacer] düğmeyi alta iter.
class _FillScroll extends StatelessWidget {
  const _FillScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Siyah hap düğme. null onTap = sönük, dokunulamaz.
class _InkPillButton extends StatelessWidget {
  const _InkPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return AnimatedContainer(
      duration: d,
      decoration: ShapeDecoration(
        color: onTap == null ? Poster.ink.withValues(alpha: 0.35) : Poster.ink,
        shape: const StadiumBorder(),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 15, 30, 15),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'InterDisplay',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: Poster.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// İkincil metin düğmesi ("Şimdi değil", "Şimdilik atla"): hap kadar
/// yüksek dokunma alanı, gövde mürekkebi.
class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'InterDisplay',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: onTap == null ? Poster.inkFaint : Poster.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zil — ikon fontuna bağlı kalmadan çizilir: kubbe + alt bant + tokmak.
class _BellPainter extends CustomPainter {
  const _BellPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    // Kubbe: üstü yuvarlak, altı düz bir yay + gövde.
    final body = Path()
      ..moveTo(w * 0.30, h * 0.62)
      ..lineTo(w * 0.30, h * 0.46)
      ..arcToPoint(
        Offset(w * 0.70, h * 0.46),
        radius: Radius.circular(w * 0.20),
      )
      ..lineTo(w * 0.70, h * 0.62)
      ..lineTo(w * 0.76, h * 0.70)
      ..lineTo(w * 0.24, h * 0.70)
      ..close();
    canvas.drawPath(body, paint);
    // Tokmak.
    canvas.drawCircle(Offset(w * 0.5, h * 0.76), w * 0.07, paint);
    // Üst düğme.
    canvas.drawCircle(Offset(w * 0.5, h * 0.27), w * 0.05, paint);
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.color != color;
}

/// Onay tiki — ikon fontuna bağlı kalmadan çizilir, her ölçekte keskin.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.78, h * 0.32);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

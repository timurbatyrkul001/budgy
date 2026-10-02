import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/ex_style.dart';
import '../../core/feedback.dart';
import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/redesign_l10n.dart';
import '../envelopes/budget_repository.dart';
import '../envelopes/envelope_l10n.dart';
import '../envelopes/home_screen.dart';
import '../workdays/work_days_repository.dart';

/// Paylaşılabilir ay özeti: kazanç, harcama, çalışılan gün, en çok harcanan
/// kategori. Kart ekranda gösterilip PNG olarak paylaşılır — kullanıcı
/// Story'ye attığında uygulamanın adı da beraberinde gider.
class MonthSummary {
  const MonthSummary({
    required this.monthLabel,
    required this.earned,
    required this.spent,
    required this.daysWorked,
    required this.topCategory,
  });

  final String monthLabel;
  final double earned;
  final double spent;
  final int daysWorked;

  /// En çok harcanan kategori adı; hiç gider yoksa null.
  final String? topCategory;

  /// Paylaşmaya değer bir şey var mı? Boş ay kartı kimseye bir şey anlatmaz.
  bool get hasContent => earned > 0 || spent > 0;
}

final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final str = ref.watch(strProvider);
  final now = DateTime.now();

  // allWorkDaysProvider zaten uygulamada akıyor — aynı veri için ikinci bir
  // Firestore aboneliği açmak yerine onu bu aya süzüyoruz.
  final days = (ref.watch(allWorkDaysProvider).value ?? const <WorkDay>[])
      .where((d) =>
          d.date.year == now.year &&
          d.date.month == now.month &&
          (d.amount ?? 0) > 0)
      .map((d) => d.amount!)
      .toList();

  // En çok harcanan kategori: zarf bazlı toplamların en büyüğü. Zarf silinmiş
  // olabilir — o durumda kategoriyi hiç göstermiyoruz, "?" yazmaktansa.
  final byEnvelope = ref.watch(monthlySpentByEnvelopeProvider);
  final envelopes = ref.watch(envelopesProvider).value ?? const [];
  String? top;
  var topAmount = 0.0;
  for (final entry in byEnvelope.entries) {
    if (entry.value <= topAmount) continue;
    final match = envelopes.where((e) => e.id == entry.key);
    if (match.isEmpty) continue;
    topAmount = entry.value;
    top = match.first.displayName(str);
  }

  return MonthSummary(
    monthLabel:
        DateFormat.yMMMM(str.localeCode).format(now).toUpperCase(),
    earned: days.fold<double>(0, (sum, v) => sum + v),
    spent: ref.watch(monthSpentProvider),
    daysWorked: days.length,
    topCategory: top,
  );
});

/// Kartın görseli. Paylaşım için ekran dışında da render edildiğinden
/// ölçüsü sabit: 1080x1350 hedefliyoruz, burada 360x450 mantıksal piksel.
class MonthSummaryCard extends StatelessWidget {
  const MonthSummaryCard({
    super.key,
    required this.summary,
    required this.rs,
    required this.str,
  });

  final MonthSummary summary;
  final RS rs;
  final Strings str;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 450,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
      // Afiş dili: düz kâğıt zemin, siyah mürekkep. Eskiden koyu yeşil
      // gradyandı; uygulama kâğıda geçince paylaşılan görsel de geçti.
      // Akışta krem + kalın siyah tipografi, bir sürü koyu kartın arasında
      // daha çok ayırt ediliyor.
      decoration: const BoxDecoration(color: Ex.bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.monthLabel,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Ex.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 26),
          _Figure(
            label: str.earned,
            value: formatMoney(summary.earned),
            color: Ex.income,
            big: true,
          ),
          const SizedBox(height: 18),
          _Figure(
            label: rs.summarySpent,
            value: formatMoney(summary.spent),
            color: Ex.text,
            big: true,
          ),
          const Spacer(),
          if (summary.topCategory != null) ...[
            _Figure(
              label: rs.summaryTop,
              value: summary.topCategory!,
              color: Ex.textSoft,
              big: false,
            ),
            const SizedBox(height: 14),
          ],
          if (summary.daysWorked > 0)
            Text(
              rs.summaryDaysTpl.replaceAll('{n}', '${summary.daysWorked}'),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Ex.textMuted,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Ex.brand,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: const Text('B',
                    style: TextStyle(
                        color: Ex.onBrand,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 9),
              const Text('Budgy',
                  style: TextStyle(
                      fontFamily: 'InterDisplay',
                      color: Ex.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
    required this.big,
  });

  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Inter',
                color: Ex.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w400)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'InterDisplay',
            color: color,
            fontSize: big ? 38 : 20,
            fontWeight: big ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: big ? -1.6 : -0.3,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Kartı ekran dışında çizip PNG olarak paylaşır.
///
/// Görünmeyen bir widget'ı resme çevirmek için [RepaintBoundary]'nin gerçekten
/// layout'tan geçmesi gerekiyor; bu yüzden kartı Overlay'e opacity 0 ile
/// ekleyip bir kare bekliyoruz. Ekranda görünen karttan `toImage` almak da
/// mümkün ama o zaman paylaşılan görsel ekrandaki boyuta bağlı kalır.
Future<void> shareMonthSummary(BuildContext context, WidgetRef ref) async {
  final str = ref.read(strProvider);
  final summary = ref.read(monthSummaryProvider);

  if (!summary.hasContent) {
    showErrorSnack(context, str.errorSaveFailed);
    return;
  }

  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -2000, // ekran dışında: kullanıcı kartın çizildiğini görmesin
      child: Opacity(
        opacity: 0,
        child: RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MonthSummaryCard(
              summary: summary,
              rs: ref.read(rsProvider),
              str: str,
            ),
          ),
        ),
      ),
    ),
  );

  final overlay = Overlay.of(context);
  overlay.insert(entry);
  try {
    // İki kare bekle: ilkinde layout, ikincisinde boyama tamamlanır.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3); // 1080x1350
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/budgy-${summary.monthLabel}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
  } finally {
    entry.remove();
  }
}

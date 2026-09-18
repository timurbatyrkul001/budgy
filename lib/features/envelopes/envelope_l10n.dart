import '../../core/category_catalog.dart';
import '../../core/l10n.dart';
import 'envelope.dart';

extension EnvelopeL10n on Envelope {
  /// Имя для отображения: пресеты переводятся под текущий язык,
  /// свои конверты показываются как назвал пользователь. Katalogdan
  /// (hızlı giriş kategori sayfası) yaratılan zarflar da preset anahtarı
  /// taşır — adı katalogdan gelir.
  String displayName(Strings str) {
    final key = presetKey;
    if (key == null) return name;
    return str.presetNames[key] ?? catalogItem(key)?.name(str.localeCode) ?? name;
  }
}

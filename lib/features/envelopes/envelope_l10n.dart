import '../../core/l10n.dart';
import 'envelope.dart';

extension EnvelopeL10n on Envelope {
  /// Имя для отображения: пресеты переводятся под текущий язык,
  /// свои конверты показываются как назвал пользователь.
  String displayName(Strings str) => presetKey == null
      ? name
      : (str.presetNames[presetKey!] ?? name);
}

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'redesign_l10n.dart';

/// Fotoğraf seçimi — fiş tarama (transactions/receipt_scan.dart) ve avatar
/// (settings/settings_edit_avatar_screen.dart) ortak kullanır. AI
/// bayrağından ([kAiEnabled]) BAĞIMSIZ: avatar fotoğrafı AI kapalıyken de
/// çalışır; bu dosya pro_state'e ya da core/ai'ye hiç bakmaz.

/// Fotoğraf seçici — gerçekte image_picker; testte sahte (izin reddi,
/// kamerasız cihaz gibi hâlleri taklit etmek için).
final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());

/// image_picker hatasını insan diline çevirir. Kodlar eklentinin kendi
/// kodları (iOS: camera/photo_access_denied|restricted, no_available_camera;
/// Android: camera_access_denied — galeri izin istemez). Tanınmayan hata
/// [fallback]'a düşer; verilmezse fiş taramanın eski genel metni.
///
/// Ayar yolu platforma göre: iOS'ta "Ayarlar → Budgy → Kamera", Android'de
/// "Ayarlar → Uygulamalar → Budgy → İzinler". [platform] testte verilir.
String pickerErrorMessage(
  RS rs,
  Object error,
  ImageSource source, {
  TargetPlatform? platform,
  String? fallback,
}) {
  final android = (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  final code = error is PlatformException ? error.code : '';
  return switch (code) {
    'camera_access_denied' =>
      android ? rs.cameraDeniedAndroid : rs.cameraDenied,
    'camera_access_restricted' => rs.cameraRestricted,
    'no_available_camera' => rs.cameraUnavailable,
    'photo_access_denied' =>
      android ? rs.photosDeniedAndroid : rs.photosDenied,
    'photo_access_restricted' => rs.photosRestricted,
    _ => fallback ?? rs.scanFailed,
  };
}

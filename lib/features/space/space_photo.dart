import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Avatar fotoğrafı: profil belgesinde (`settings/main`, alan `spacePhoto`)
/// base64 metin olarak durur. Firebase Storage YOK — bilinçli karar:
/// avatar minik bir görsel, sıkıştırılınca onlarca KB; Firestore belge
/// sınırı 1 MiB. Yeni servis, yeni kural, hesap silinince ayrı temizlik
/// gerekmez; cihazlar arası diğer ayarlar gibi kendiliğinden eşitlenir.
///
/// BEDELİ: profil belgesi her açılışta okunur. Bu yüzden görsel agresif
/// küçültülür ve KATI bir üst sınır var ([kSpacePhotoMaxChars]); sınırı aşan
/// fotoğraf sessizce yazılmaz — önce daha da küçültülür, olmazsa reddedilir.

/// Seçiciye verilen en uzun kenar (px). Ekranda en büyük kullanım 200 dp
/// (avatar düzenleme önizlemesi); çip 30 dp, ayar başlığı 84 dp.
const kSpacePhotoSide = 256;

/// JPEG kalitesi (0–100). Gerçek bir telefon fotoğrafında 256 px × q70 ≈
/// 14–17 KB JPEG → ≈ 19–22 KB base64; sınırın yarısından az.
const kSpacePhotoQuality = 70;

/// Base64 metnin üst sınırı: 50 KB. Profil belgesinin her açılışta okunan
/// tek belge olduğu unutulmasın — bunu büyütmeden önce iki kez düşün.
const kSpacePhotoMaxChars = 50 * 1024;

/// Seçicinin verdiği baytları profile yazılacak base64 metne çevirir.
/// Sığmazsa null: çağıran kullanıcıya söyler, profile hiçbir şey yazmaz.
///
/// Seçici JPEG'i küçültüp sıkıştırır, ama PNG'yi (ekran görüntüsü, saydam
/// görsel) her iki platformda da sıkıştırmadan geçirir — 256 px PNG fotoğraf
/// ~57 KB olabilir ve base64'te sınırı aşar. dart:ui JPEG yazamaz; o yüzden
/// PNG olarak kenar kademeli küçültülür (192 → 128 → 96; gerçek fotoğrafta
/// 192 px PNG ≈ 45 KB base64 ile zaten sığar). Çözülemeyen veri de null.
Future<String?> encodeSpacePhoto(Uint8List bytes) async {
  var b64 = base64Encode(bytes);
  if (b64.length <= kSpacePhotoMaxChars) return b64;
  try {
    final (w, h) = await _imageSize(bytes);
    for (final side in const [192, 128, 96]) {
      b64 = base64Encode(await _resizePng(bytes, w, h, side));
      if (b64.length <= kSpacePhotoMaxChars) return b64;
    }
  } catch (_) {
    // Görsel değil ya da çözülemiyor — sığdıramayız.
    return null;
  }
  return null;
}

Future<(int, int)> _imageSize(Uint8List src) async {
  final codec = await ui.instantiateImageCodec(src);
  try {
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    return size;
  } finally {
    codec.dispose();
  }
}

/// En uzun kenarı [side] olacak şekilde, oranı koruyarak küçültüp PNG
/// yazar. İki hedef boyut da verilir: dart:ui tek boyut verilince oranı
/// korur ama ikisi verilince tam o boyuta çeker — oranı biz hesaplıyoruz.
Future<Uint8List> _resizePng(Uint8List src, int w, int h, int side) async {
  final scale = side / math.max(w, h);
  final codec = await ui.instantiateImageCodec(
    src,
    targetWidth: math.max(1, (w * scale).round()),
    targetHeight: math.max(1, (h * scale).round()),
    allowUpscaling: false,
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png encode failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

// ── çözme önbelleği ───────────────────────────────────────────────────────

String? _lastKey;
Uint8List? _lastBytes;

/// Base64 metni baytlara çevirir; son sonucu hatırlar.
///
/// Neden önbellek: [SpaceAvatar] her yeniden çizimde çağırır; her seferinde
/// yeni bir Uint8List üretilse `Image.memory` (MemoryImage baytları
/// KİMLİKLE kıyaslar) görseli her çizimde yeniden çözerdi. Aynı metin →
/// aynı bayt nesnesi → görsel önbelleği tutar. Bozuk metin null döner;
/// avatar simge/baş harfe düşer.
Uint8List? decodeSpacePhoto(String b64) {
  if (b64.isEmpty) return null;
  if (_lastKey == b64) return _lastBytes;
  Uint8List? bytes;
  try {
    bytes = base64Decode(b64);
  } on FormatException {
    bytes = null;
  }
  _lastKey = b64;
  _lastBytes = bytes;
  return bytes;
}

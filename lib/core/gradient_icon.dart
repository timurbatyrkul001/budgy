import 'package:flutter/material.dart';


/// Varsayılan ikon gradyanı: açık yeşilden koyuya.
///
/// İki uç bilerek UZAK. `Ex.mint`→`Ex.brand` denendi, 18 pikselde gradyan
/// olduğu anlaşılmıyordu — küçük ikonlarda iki ton arasında belirgin bir
/// atlama olmazsa göz onu düz renk sanıyor.
const kIconGradient = [Color(0xFF45BE8A), Color(0xFF0B5540)];

/// İkonun içini düz renk yerine gradyanla boyar.
///
/// Referans aldığımız arayüzlerdeki "dolu ikon, üstten açık alttan koyu"
/// görünümün sırrı ikon setinde değil: ikonlar düpedüz tek renk, gradyan
/// sonradan uygulanıyor. Aynısını burada yapıyoruz — böylece ücretsiz ve
/// MIT lisanslı herhangi bir dolu set (Material, Phosphor) ile o hava
/// yakalanıyor ve renkler başkasının mavisi değil bizim yeşilimiz oluyor.
///
/// Çalışma biçimi: [ShaderMask] ikonu maske olarak alır, gradyanı yalnız
/// ikonun dolu pikselleri üstünde gösterir. `BlendMode.srcIn` tam olarak
/// bu — "kaynağı (gradyan) hedefin (ikon) içinde çiz".
class GradientIcon extends StatelessWidget {
  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 18,
    this.colors = kIconGradient,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  final IconData icon;
  final double size;

  /// En az iki renk; sırası [begin] → [end] yönünde.
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ).createShader(bounds),
      // ShaderMask maskeyi çocuğun alfasından alır; çocuğun kendi rengi
      // görünmez, yalnız şekli önemli. Beyaz veriyoruz ki alfa tam olsun.
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// Hızlı giriş klavyesinin hesap makinesi: "1200+350*2" gibi ifadeleri
/// çözer. Yalnız + − × ÷ ve ondalık; parantez yok. Ondalık ayraç olarak
/// hem "," hem "." kabul edilir (klavye dile göre virgül basar).
///
/// Sonuç: geçersiz/eksik ifadede (sondaki operatör, boş) mümkün olan
/// kısım çözülür — "12+" → 12; hiç sayı yoksa 0.
double evalExpression(String expr) {
  final s = expr.replaceAll(',', '.').replaceAll(' ', '');
  if (s.isEmpty) return 0;

  // Sayılar ve operatörler sırayla; sondaki operatör yok sayılır.
  final tokens = <Object>[]; // double | String
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    tokens.add(double.tryParse(buf.toString()) ?? 0);
    buf.clear();
  }

  for (final ch in s.split('')) {
    if (isOperator(ch)) {
      flush();
      // Arka arkaya iki operatör: sonuncusu geçerli.
      if (tokens.isNotEmpty && tokens.last is String) tokens.removeLast();
      if (tokens.isNotEmpty) tokens.add(ch);
    } else {
      buf.write(ch);
    }
  }
  flush();
  if (tokens.isNotEmpty && tokens.last is String) tokens.removeLast();
  if (tokens.isEmpty) return 0;

  // Önce × ÷, sonra + −.
  final pass1 = <Object>[tokens.first];
  for (var i = 1; i < tokens.length; i += 2) {
    final op = tokens[i] as String;
    final rhs = tokens[i + 1] as double;
    if (op == '×' || op == '÷') {
      final lhs = pass1.removeLast() as double;
      pass1.add(op == '×' ? lhs * rhs : (rhs == 0 ? 0.0 : lhs / rhs));
    } else {
      pass1
        ..add(op)
        ..add(rhs);
    }
  }
  var result = pass1.first as double;
  for (var i = 1; i < pass1.length; i += 2) {
    final rhs = pass1[i + 1] as double;
    result = pass1[i] == '+' ? result + rhs : result - rhs;
  }
  if (result.isNaN || result.isInfinite) return 0;
  // Kuruşa yuvarla — double kuyrukları bakiyeye sızmasın.
  return (result * 100).roundToDouble() / 100;
}

bool isOperator(String ch) => ch == '+' || ch == '−' || ch == '×' || ch == '÷';

/// İfadeye tuş ekler; anlamsız dizilimleri engeller (çift ayraç, önde
/// operatör, sayıda ikinci ondalık, 2'den fazla ondalık hane).
String appendKey(String expr, String key) {
  if (isOperator(key)) {
    if (expr.isEmpty) return expr;
    if (isOperator(expr[expr.length - 1])) {
      return expr.substring(0, expr.length - 1) + key;
    }
    if (expr.endsWith('.')) return '${expr.substring(0, expr.length - 1)}$key';
    return expr + key;
  }
  // Mevcut sayı parçası (son operatörden sonrası).
  var start = expr.length;
  while (start > 0 && !isOperator(expr[start - 1])) {
    start--;
  }
  final current = expr.substring(start);
  if (key == '.') {
    if (current.contains('.')) return expr;
    return current.isEmpty ? '${expr}0.' : '$expr.';
  }
  // Rakam: baştaki gereksiz sıfırı değiştir, ondalıkta 2 haneyi aşma.
  final dot = current.indexOf('.');
  if (dot >= 0 && current.length - dot > 2) return expr;
  if (current == '0') return '${expr.substring(0, expr.length - 1)}$key';
  if (current.length >= 12) return expr;
  return expr + key;
}

/// Bir tuş geri.
String backspace(String expr) =>
    expr.isEmpty ? expr : expr.substring(0, expr.length - 1);

/// İfadede işlem var mı (yani "=" sonucu göstermeye değer)?
bool hasOperator(String expr) => expr.split('').any(isOperator);

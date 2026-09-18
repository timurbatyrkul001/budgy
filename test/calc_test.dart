import 'package:flutter_test/flutter_test.dart';
import 'package:kopilka_app/core/calc.dart';

/// Hızlı giriş klavyesinin ifade çözücüsü.
void main() {
  group('evalExpression', () {
    test('düz sayı', () => expect(evalExpression('2000'), 2000));
    test('virgül ondalık', () => expect(evalExpression('12,5'), 12.5));
    test('toplama/çıkarma', () => expect(evalExpression('100+50−20'), 130));
    test('çarpma önce', () => expect(evalExpression('2+3×4'), 14));
    test('bölme', () => expect(evalExpression('90÷4'), 22.5));
    test('sıfıra bölme 0', () => expect(evalExpression('5÷0'), 0));
    test('sondaki operatör yok sayılır', () => expect(evalExpression('12+'), 12));
    test('boş 0', () => expect(evalExpression(''), 0));
    test('kuruşa yuvarlar', () => expect(evalExpression('10÷3'), 3.33));
  });

  group('appendKey', () {
    test('önde operatör olmaz', () => expect(appendKey('', '+'), ''));
    test('çift operatör sonuncuyu tutar',
        () => expect(appendKey('5+', '×'), '5×'));
    test('sayıda ikinci ondalık olmaz',
        () => expect(appendKey('1.5', '.'), '1.5'));
    test('boşken ondalık 0. ile başlar', () => expect(appendKey('', '.'), '0.'));
    test('baştaki sıfır değişir', () => expect(appendKey('0', '7'), '7'));
    test('ondalıkta 2 hane', () => expect(appendKey('1.25', '9'), '1.25'));
    test('operatörden sonra yeni sayı', () => expect(appendKey('12+', '3'), '12+3'));
  });

  test('backspace', () {
    expect(backspace('123'), '12');
    expect(backspace(''), '');
  });
}

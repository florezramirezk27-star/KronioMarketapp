import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/utils/format.dart';

void main() {
  group('formatCop', () {
    test('formatea un monto con separador de miles', () {
      expect(formatCop(269000), r'$ 269.000');
    });

    test('formatea montos cortos sin separador', () {
      expect(formatCop(500), r'$ 500');
    });

    test('redondea a entero por defecto', () {
      expect(formatCop(1234.56), r'$ 1.235');
    });

    test('muestra centavos cuando se pide', () {
      expect(formatCop(1234.56, withDecimals: true), r'$ 1.234,56');
    });

    test('formatea cero', () {
      expect(formatCop(0), r'$ 0');
    });

    test('formatea montos grandes', () {
      expect(formatCop(1234567), r'$ 1.234.567');
    });

    test('formatea negativos con el signo en el lugar correcto', () {
      // La version anterior producia "$-.5000".
      expect(formatCop(-5000), r'-$ 5.000');
    });

    test('formatea un precio de producto real del catalogo', () {
      expect(formatCop(269000.0), r'$ 269.000');
      expect(formatCop(50000.0), r'$ 50.000');
    });
  });

  group('formatCount', () {
    test('formatea un numero simple', () {
      expect(formatCount(5), '5');
    });

    test('formatea miles', () {
      expect(formatCount(1234), '1.234');
    });

    test('formatea millones', () {
      expect(formatCount(1234567), '1.234.567');
    });
  });
}

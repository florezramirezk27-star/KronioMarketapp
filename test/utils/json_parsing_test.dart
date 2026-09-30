import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/utils/json_parsing.dart';

void main() {
  group('asString', () {
    test('devuelve el valor tal cual', () {
      expect(asString('hola'), 'hola');
    });

    test('convierte numeros a string', () {
      expect(asString(42), '42');
    });

    test('devuelve el fallback para null', () {
      expect(asString(null), '');
      expect(asString(null, fallback: 'x'), 'x');
    });

    test('usa el fallback para strings vacios o con espacios', () {
      expect(asString(''), '');
      expect(asString('   ', fallback: 'n/a'), 'n/a');
    });

    test('aplica trim', () {
      expect(asString('  hola  '), 'hola');
    });
  });

  group('asInt', () {
    test('acepta int', () {
      expect(asInt(7), 7);
    });

    test('acepta double y trunca', () {
      expect(asInt(7.9), 7);
    });

    test('acepta string numerico', () {
      expect(asInt('7'), 7);
      expect(asInt(' 7 '), 7);
    });

    test('devuelve null si no se puede convertir', () {
      expect(asInt('abc'), isNull);
      expect(asInt(null), isNull);
      expect(asInt(true), isNull);
    });
  });

  group('asDouble', () {
    test('acepta int y double', () {
      expect(asDouble(3), 3.0);
      expect(asDouble(3.5), 3.5);
    });

    test('acepta string', () {
      expect(asDouble('3.5'), 3.5);
    });

    test('devuelve el fallback para null', () {
      expect(asDouble(null), 0);
      expect(asDouble(null, fallback: 9), 9);
    });

    test('devuelve el fallback para texto', () {
      expect(asDouble('abc', fallback: 5), 5);
    });
  });

  group('asStringList', () {
    test('convierte una lista de strings', () {
      expect(asStringList(['a', 'b']), ['a', 'b']);
    });

    test('descarta entradas vacias y nulas', () {
      expect(asStringList(['a', '', null, '  ', 'b']), ['a', 'b']);
    });

    test('devuelve lista vacia si no es una lista', () {
      expect(asStringList(null), isEmpty);
      expect(asStringList('texto'), isEmpty);
      expect(asStringList(42), isEmpty);
    });

    test('convierte elementos no-string', () {
      expect(asStringList([1, 2.5, true]), ['1', '2.5', 'true']);
    });
  });

  group('parseMoney', () {
    test('parsea el formato que manda el backend (string plano)', () {
      expect(parseMoney('269000'), 269000);
    });

    test('acepta num directamente', () {
      expect(parseMoney(269000), 269000.0);
      expect(parseMoney(269000.50), 269000.50);
    });

    test('devuelve 0 para null y vacio', () {
      expect(parseMoney(null), 0);
      expect(parseMoney(''), 0);
      expect(parseMoney('   '), 0);
    });

    test('parsea decimales con punto', () {
      expect(parseMoney('1234.56'), 1234.56);
    });

    test('parsea formato europeo con coma decimal', () {
      expect(parseMoney('1234,56'), 1234.56);
    });

    test('parsea formato con ambos separadores', () {
      // 1.234,56 -> el ultimo separador (coma) es el decimal.
      expect(parseMoney('1.234,56'), 1234.56);
      // 1,234.56 -> el ultimo separador (punto) es el decimal.
      expect(parseMoney('1,234.56'), 1234.56);
    });

    test('ignora espacios', () {
      expect(parseMoney('269 000'), 269000);
      expect(parseMoney('269000'), 269000);
    });

    test('ignora un simbolo de moneda al inicio', () {
      expect(parseMoney(r'$269000'), 269000);
    });

    // Nota: `parseMoney('269.000')` devuelve 269.0, no 269000. El punto se
    // interpreta como separador decimal, que es la convencion del backend
    // (manda "269000" plano, sin separadores). Soportar "$269.000" seria
    // adivinar el formato a partir de un dato ambiguo.

    test('devuelve 0 para texto no numerico', () {
      expect(parseMoney('gratis'), 0);
      expect(parseMoney('abc'), 0);
    });

    test('maneja negativos correctamente', () {
      expect(parseMoney('-5000'), -5000);
      expect(parseMoney('-1234.56'), -1234.56);
    });
  });
}

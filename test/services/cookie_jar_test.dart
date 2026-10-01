import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/services/cookie_jar.dart';

void main() {
  group('splitSetCookieHeader', () {
    test('una sola cookie no se toca', () {
      expect(splitSetCookieHeader('session=abc; Path=/; HttpOnly'), [
        'session=abc; Path=/; HttpOnly',
      ]);
    });

    test('separa dos cookies pegadas por package:http', () {
      final parts = splitSetCookieHeader('a=1; Path=/, b=2; Path=/');
      expect(parts, ['a=1; Path=/', 'b=2; Path=/']);
    });

    // Este es el caso que rompe un split ingenuo por coma: `Expires` lleva una
    // coma adentro y partiria la cookie en dos.
    test('no parte la cookie en la coma de Expires', () {
      const header =
          'session=abc; Path=/; Expires=Wed, 21 Oct 2015 07:28:00 GMT, '
          'csrf-token=xyz; Path=/; Secure';
      final parts = splitSetCookieHeader(header);
      expect(parts, hasLength(2));
      expect(parts[0], contains('Expires=Wed, 21 Oct 2015 07:28:00 GMT'));
      expect(parts[1], 'csrf-token=xyz; Path=/; Secure');
    });
  });

  group('parseHttpDate', () {
    test('parsea RFC 1123', () {
      final d = parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT');
      expect(d, DateTime.utc(2015, 10, 21, 7, 28, 0));
    });

    test('acepta ISO-8601', () {
      expect(
        parseHttpDate('2030-01-02T03:04:05.000Z'),
        DateTime.utc(2030, 1, 2, 3, 4, 5),
      );
    });

    test('devuelve null con basura', () {
      expect(parseHttpDate('no-es-fecha'), isNull);
      expect(parseHttpDate(''), isNull);
    });
  });

  group('CookieJar.absorb', () {
    test('guarda la cookie CSRF real del backend', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/api/proxy/auth'), [
        '__Host-csrf-token=621ae9ced10efc5e8649d61fc666f53bffda89a8dd73b06c6db73b3cfab160e0; Path=/; Secure; SameSite=Lax',
      ]);

      expect(
        jar.valueOf('__Host-csrf-token'),
        '621ae9ced10efc5e8649d61fc666f53bffda89a8dd73b06c6db73b3cfab160e0',
      );
      expect(jar.cookies.single.secure, isTrue);
      expect(jar.cookies.single.httpOnly, isFalse);
    });

    test('Max-Age=0 borra la cookie', () {
      final jar = CookieJar();
      final uri = Uri.parse('https://e.com/');
      jar.absorb(uri, ['session=abc; Path=/']);
      expect(jar.valueOf('session'), 'abc');

      jar.absorb(uri, ['session=; Path=/; Max-Age=0']);
      expect(jar.valueOf('session'), isNull);
    });

    test('Expires en el pasado borra la cookie', () {
      final jar = CookieJar();
      final uri = Uri.parse('https://e.com/');
      jar.absorb(uri, ['session=abc']);
      jar.absorb(uri, ['session=abc; Expires=Wed, 21 Oct 2015 07:28:00 GMT']);
      expect(jar.valueOf('session'), isNull);
    });

    test('una fecha futura mantiene la cookie viva', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), [
        'session=abc; Expires=Wed, 21 Oct 2099 07:28:00 GMT',
      ]);
      expect(jar.valueOf('session'), 'abc');
      expect(jar.cookies.single.isExpired, isFalse);
    });

    test('ignora segmentos sin nombre o sin =', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), ['=sinNombre', 'basura']);
      expect(jar.isEmpty, isTrue);
    });
  });

  group('CookieJar.headerFor', () {
    test('junta las cookies vigentes', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), [
        'session=abc; Path=/, __Host-csrf-token=xyz; Path=/; Secure',
      ]);
      final header = jar.headerFor(Uri.parse('https://e.com/api/proxy/cart'));
      expect(header, contains('session=abc'));
      expect(header, contains('__Host-csrf-token=xyz'));
    });

    test('no manda una cookie Secure por http', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), ['t=1; Path=/; Secure']);
      expect(jar.headerFor(Uri.parse('http://e.com/x')), isNull);
      expect(jar.headerFor(Uri.parse('https://e.com/x')), 't=1');
    });

    test('respeta el Path', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), ['t=1; Path=/api']);
      expect(jar.headerFor(Uri.parse('https://e.com/api/x')), 't=1');
      expect(jar.headerFor(Uri.parse('https://e.com/otro')), isNull);
      // `/apix` no debe matchear `/api`.
      expect(jar.headerFor(Uri.parse('https://e.com/apix')), isNull);
    });

    test('devuelve null con el jar vacio', () {
      expect(CookieJar().headerFor(Uri.parse('https://e.com/')), isNull);
    });

    test('descarta cookies expiradas al construir el header', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), ['t=1; Path=/']);
      jar.absorb(Uri.parse('https://e.com/'), ['t=; Path=/; Max-Age=0']);
      expect(jar.headerFor(Uri.parse('https://e.com/')), isNull);
    });
  });

  group('CookieJar serializacion', () {
    test('round-trip a JSON conserva valor y expiracion', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), [
        'session=abc; Path=/; HttpOnly; Expires=Wed, 21 Oct 2099 07:28:00 GMT',
      ]);

      final restored = CookieJar.fromJson(jar.toJson());
      expect(restored.valueOf('session'), 'abc');
      final cookie = restored.cookies.single;
      expect(cookie.httpOnly, isTrue);
      expect(cookie.expires, DateTime.utc(2099, 10, 21, 7, 28, 0));
    });

    test('clear vacia el jar', () {
      final jar = CookieJar();
      jar.absorb(Uri.parse('https://e.com/'), ['t=1']);
      jar.clear();
      expect(jar.isEmpty, isTrue);
      expect(jar.valueOf('t'), isNull);
    });

    test('fromJson tolera un JSON vacio o corrupto', () {
      expect(CookieJar.fromJson(const {}).isEmpty, isTrue);
      expect(
        CookieJar.fromJson(const {'cookies': 'no-es-lista'}).isEmpty,
        isTrue,
      );
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/services/api_exception.dart';

void main() {
  group('mapStatusCode', () {
    test('404 produce ApiNotFoundException y no se puede reintentar', () {
      final error = mapStatusCode(404);

      expect(error, isA<ApiNotFoundException>());
      expect(error.canRetry, isFalse);
      expect(error.message, isNotEmpty);
    });

    test('500 produce ApiServerException y se puede reintentar', () {
      final error = mapStatusCode(500);

      expect(error, isA<ApiServerException>());
      expect(error.canRetry, isTrue);
    });

    test('503 produce ApiServerException', () {
      expect(mapStatusCode(503), isA<ApiServerException>());
    });

    test('400 produce ApiClientException', () {
      expect(mapStatusCode(400), isA<ApiClientException>());
    });

    test('401 produce ApiClientException', () {
      expect(mapStatusCode(401), isA<ApiClientException>());
    });

    test('429 produce ApiClientException con mensaje de espera', () {
      final error = mapStatusCode(429);

      expect(error, isA<ApiClientException>());
      expect(error.canRetry, isTrue);
    });

    test('el codigo HTTP queda disponible', () {
      expect(mapStatusCode(500).statusCode, 500);
      expect(mapStatusCode(404).statusCode, 404);
    });

    test('extrae el mensaje de error de NestJS', () {
      final error = mapStatusCode(
        400,
        body: '{"message":"El nombre ya existe"}',
      );

      expect(error.message, contains('El nombre ya existe'));
    });

    test('extrae el mensaje cuando viene como arreglo', () {
      final error = mapStatusCode(
        400,
        body: '{"message":["campo requerido","otro error"]}',
      );

      expect(error.message, contains('campo requerido'));
    });

    test('extrae el campo error', () {
      final error = mapStatusCode(400, body: '{"error":"algo fallo"}');

      expect(error.message, contains('algo fallo'));
    });

    test('ignora cuerpos no-JSON sin fallar', () {
      final error = mapStatusCode(502, body: '<html>Bad Gateway</html>');

      expect(error, isA<ApiServerException>());
      expect(error.message, isNotEmpty);
    });

    test('ignora cuerpos vacios', () {
      final error = mapStatusCode(500, body: '');

      expect(error, isA<ApiServerException>());
    });

    test('no filtra HTML crudo al mensaje', () {
      final error = mapStatusCode(500, body: '<html><body>Error</body></html>');

      expect(error.message, isNot(contains('<html>')));
    });
  });

  group('mapNetworkError', () {
    test('TimeoutException produce ApiTimeoutException', () {
      final error = mapNetworkError(TimeoutException('tarde'));

      expect(error, isA<ApiTimeoutException>());
      expect(error.canRetry, isTrue);
    });

    test('un ApiException se devuelve sin transformar', () {
      final original = const ApiNotFoundException('no existe');

      expect(mapNetworkError(original), same(original));
    });

    test('cualquier otra excepcion cae en ApiNetworkException', () {
      final error = mapNetworkError(Exception('algo raro'));

      expect(error, isA<ApiNetworkException>());
      expect(error.canRetry, isTrue);
    });

    test('el mensaje es siempre en espanol para el usuario', () {
      final messages = [
        mapStatusCode(404).message,
        mapStatusCode(500).message,
        mapStatusCode(429).message,
        mapNetworkError(TimeoutException('x')).message,
        mapNetworkError(Exception('y')).message,
      ];

      for (final message in messages) {
        expect(message, isNotEmpty);
        // El texto crudo de la excepcion no debe filtrarse.
        expect(message, isNot(contains('Exception')));
      }
    });
  });

  group('ApiException.canRetry', () {
    test('un 404 no se reintenta pero un 500 si', () {
      expect(const ApiNotFoundException('x').canRetry, isFalse);
      expect(ApiServerException('x', statusCode: 500).canRetry, isTrue);
    });

    test('un error de formato no se reintenta', () {
      expect(const ApiFormatException('x').canRetry, isFalse);
    });

    test('los errores de red y timeout si se reintentan', () {
      expect(const ApiNetworkException('x').canRetry, isTrue);
      expect(const ApiTimeoutException('x').canRetry, isTrue);
    });
  });

  group('ApiException.toString', () {
    test('incluye el codigo HTTP cuando existe', () {
      final text = ApiServerException('fallo', statusCode: 503).toString();

      expect(text, contains('503'));
      expect(text, contains('fallo'));
    });

    test('no rompe cuando no hay codigo HTTP', () {
      expect(
        () => const ApiNetworkException('sin red').toString(),
        returnsNormally,
      );
    });
  });
}

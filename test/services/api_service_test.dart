import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/services/api_exception.dart';
import 'package:kronio_app/services/api_service.dart';

void main() {
  group('PaginatedResult.fromJson', () {
    // Respuesta real de GET /products del backend de Kronio.
    Map<String, dynamic> realResponse() => {
      'items': [
        {
          'id': 'a',
          'name': 'A',
          'slug': 'a',
          'price': '100',
          'image': '',
          'stock': 5,
        },
        {
          'id': 'b',
          'name': 'B',
          'slug': 'b',
          'price': '200',
          'image': '',
          'stock': 5,
        },
      ],
      'total': 45,
      'page': 1,
      'limit': 20,
      'totalPages': 3,
    };

    String productFromJson(Map<String, dynamic> json) =>
        '${json['id']}:${json['name']}';

    test('parsea la forma paginada del backend', () {
      final result = PaginatedResult.fromJson(
        realResponse(),
        itemBuilder: productFromJson,
      );

      expect(result.items.length, 2);
      expect(result.page, 1);
      expect(result.totalPages, 3);
      expect(result.total, 45);
    });

    test('hasMore es true si hay paginas siguientes', () {
      final result = PaginatedResult.fromJson(
        realResponse(),
        itemBuilder: productFromJson,
      );

      expect(result.hasMore, isTrue);
    });

    test('hasMore es false en la ultima pagina', () {
      final body = realResponse()..['page'] = 3;

      final result = PaginatedResult.fromJson(
        body,
        itemBuilder: productFromJson,
      );

      expect(result.hasMore, isFalse);
    });

    test('acepta un array plano como una sola pagina', () {
      final result = PaginatedResult.fromJson([
        {
          'id': 'a',
          'name': 'A',
          'slug': 'a',
          'price': '1',
          'image': '',
          'stock': 1,
        },
      ], itemBuilder: productFromJson);

      expect(result.items.length, 1);
      expect(result.page, 1);
      expect(result.totalPages, 1);
      expect(result.hasMore, isFalse);
    });

    test('acepta la forma antigua {value, Count}', () {
      final result = PaginatedResult.fromJson({
        'value': [
          {
            'id': 'a',
            'name': 'A',
            'slug': 'a',
            'price': '1',
            'image': '',
            'stock': 1,
          },
        ],
        'Count': 10,
      }, itemBuilder: productFromJson);

      expect(result.items.length, 1);
      expect(result.total, 10);
    });

    test('deduce que hay mas paginas si items < total', () {
      final body = {
        'items': [
          {
            'id': 'a',
            'name': 'A',
            'slug': 'a',
            'price': '1',
            'image': '',
            'stock': 1,
          },
        ],
        'total': 30,
        'page': 1,
      };

      final result = PaginatedResult.fromJson(
        body,
        itemBuilder: productFromJson,
      );

      expect(result.totalPages, 2);
      expect(result.hasMore, isTrue);
    });

    test('lanza ApiFormatException si no hay lista de items', () {
      expect(
        () => PaginatedResult.fromJson({
          'message': 'error',
        }, itemBuilder: productFromJson),
        throwsA(isA<ApiFormatException>()),
      );
    });

    test('lanza ApiFormatException con un cuerpo inesperado', () {
      expect(
        () => PaginatedResult.fromJson(
          'texto plano',
          itemBuilder: productFromJson,
        ),
        throwsA(isA<ApiFormatException>()),
      );
    });

    test('ignora elementos que no son mapas', () {
      final result = PaginatedResult.fromJson({
        'items': [
          {
            'id': 'a',
            'name': 'A',
            'slug': 'a',
            'price': '1',
            'image': '',
            'stock': 1,
          },
          'basura',
          null,
          42,
        ],
        'total': 4,
        'page': 1,
        'totalPages': 1,
      }, itemBuilder: productFromJson);

      expect(result.items.length, 1);
    });

    test('acepta numeros de pagina como string', () {
      final result = PaginatedResult.fromJson({
        'items': [
          {
            'id': 'a',
            'name': 'A',
            'slug': 'a',
            'price': '1',
            'image': '',
            'stock': 1,
          },
        ],
        'total': '10',
        'page': '1',
        'totalPages': '2',
      }, itemBuilder: productFromJson);

      expect(result.page, 1);
      expect(result.totalPages, 2);
      expect(result.total, 10);
    });

    test('una lista vacia no es un error', () {
      final result = PaginatedResult.fromJson({
        'items': [],
        'total': 0,
        'page': 1,
        'totalPages': 1,
      }, itemBuilder: productFromJson);

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.total, 0);
    });
  });
}

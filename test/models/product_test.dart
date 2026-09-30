import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/models/product.dart';

void main() {
  group('Product.fromJson', () {
    test('parsea el formato real del backend (precios como string)', () {
      // Respuesta capturada de GET /products del backend de Kronio.
      const json = {
        'id': 'cmubhhnth0006j5e8awhf8qnw',
        'name': 'Reloj Naviforce Casual Nf8028 Crono Hombre',
        'slug': 'reloj-naviforce-casual-nf8028-crono-homb',
        'description': '',
        'price': '269000',
        'oldPrice': '219900',
        'image': 'https://cdn.example.com/reloj.jpg',
        'gallery': <String>[],
        'stock': 100,
        'lowStockThreshold': 5,
        'active': true,
        'dropiProductId': 1734566,
        'categoryId': 'cmubhhnfv0004j5e8bevra2ob',
        'category': {
          'id': 'cmubhhnfv0004j5e8bevra2ob',
          'name': 'Moda',
          'slug': 'moda',
        },
      };

      final product = Product.fromJson(json);

      expect(product.id, 'cmubhhnth0006j5e8awhf8qnw');
      expect(product.price, 269000);
      expect(product.oldPrice, 219900);
      expect(product.stock, 100);
      expect(product.dropiProductId, 1734566);
      expect(product.category?.name, 'Moda');
    });

    test('tolera campos ausentes', () {
      final product = Product.fromJson({'id': 'x'});

      expect(product.id, 'x');
      expect(product.name, 'Sin nombre');
      expect(product.price, 0);
      expect(product.stock, 0);
      expect(product.active, isTrue);
      expect(product.oldPrice, isNull);
      expect(product.gallery, isEmpty);
    });

    test('tolera un cuerpo vacio sin crashear', () {
      final product = Product.fromJson({});

      expect(product.id, '');
      expect(product.price, 0);
    });
  });

  group('Product descuentos', () {
    test('detecta descuento cuando oldPrice es mayor', () {
      final product = Product.fromJson({
        'price': '90000',
        'oldPrice': '120000',
      });

      expect(product.hasDiscount, isTrue);
      expect(product.discountPercent, 25);
    });

    test('NO detecta descuento cuando el precio subio', () {
      // Caso real del catalogo: el "oldPrice" es menor que el precio actual,
      // o sea subio de precio. No hay nada que descontar.
      final product = Product.fromJson({'price': '60000', 'oldPrice': '20500'});

      expect(product.hasDiscount, isFalse);
      expect(product.discountPercent, 0);
    });

    test('NO detecta descuento si oldPrice es igual al precio', () {
      final product = Product.fromJson({'price': '50000', 'oldPrice': '50000'});

      expect(product.hasDiscount, isFalse);
    });

    test('no divide por cero con oldPrice en 0', () {
      final product = Product.fromJson({'price': '0', 'oldPrice': '0'});

      expect(product.hasDiscount, isFalse);
      expect(product.discountPercent, 0);
    });
  });

  group('Product stock', () {
    test('detecta agotado con stock 0', () {
      final product = Product.fromJson({'stock': 0});

      expect(product.outOfStock, isTrue);
      expect(product.lowStock, isFalse);
      expect(product.isAvailable, isFalse);
    });

    test('detecta stock bajo cerca del umbral', () {
      final product = Product.fromJson({'stock': 3, 'lowStockThreshold': 5});

      expect(product.outOfStock, isFalse);
      expect(product.lowStock, isTrue);
      expect(product.isAvailable, isTrue);
    });

    test('no marca stock bajo si esta por encima del umbral', () {
      final product = Product.fromJson({'stock': 50, 'lowStockThreshold': 5});

      expect(product.lowStock, isFalse);
    });

    test('un producto inactivo no esta disponible', () {
      final product = Product.fromJson({'stock': 10, 'active': false});

      expect(product.isAvailable, isFalse);
    });
  });

  group('Product.gallery y displayImages', () {
    test('usa la galeria cuando hay', () {
      final product = Product.fromJson({
        'image': 'a.jpg',
        'gallery': ['a.jpg', 'b.jpg'],
      });

      expect(product.displayImages, ['a.jpg', 'b.jpg']);
    });

    test('cae a la imagen principal si no hay galeria', () {
      final product = Product.fromJson({
        'image': 'a.jpg',
        'gallery': <String>[],
      });

      expect(product.displayImages, ['a.jpg']);
    });

    test('devuelve lista vacia si no hay ninguna imagen', () {
      final product = Product.fromJson({'image': ''});

      expect(product.displayImages, isEmpty);
    });

    test('descarta entradas vacias de la galeria', () {
      final product = Product.fromJson({
        'image': 'a.jpg',
        'gallery': ['a.jpg', '', 'b.jpg'],
      });

      expect(product.gallery, ['a.jpg', 'b.jpg']);
    });
  });

  group('Product.toJson', () {
    test('conserva lo necesario para el carrito', () {
      final product = Product.fromJson({
        'id': 'a',
        'name': 'Producto A',
        'slug': 'producto-a',
        'price': '10000',
        'image': 'a.jpg',
        'stock': 5,
      });

      final json = product.toJson();
      final restored = Product.fromJson(json);

      expect(restored.id, product.id);
      expect(restored.name, product.name);
      expect(restored.price, product.price);
      expect(restored.stock, product.stock);
    });

    test('sobrevive un round-trip por JSON', () {
      final product = Product.fromJson({
        'id': 'a',
        'name': 'Producto A',
        'slug': 'a',
        'price': '12345.67',
        'oldPrice': '20000',
        'image': 'a.jpg',
        'stock': 7,
      });

      final roundTrip = Product.fromJson(
        jsonDecode(jsonEncode(product.toJson())) as Map<String, dynamic>,
      );

      expect(roundTrip.price, 12345.67);
      expect(roundTrip.oldPrice, 20000);
    });
  });
}

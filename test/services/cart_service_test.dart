import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kronio_app/models/product.dart';

Product _product({
  String id = 'p1',
  String name = 'Producto',
  double price = 10000,
  int stock = 10,
  bool active = true,
}) {
  return Product(
    id: id,
    name: name,
    slug: id,
    price: price,
    image: 'https://example.com/$id.jpg',
    stock: stock,
    active: active,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CartService agregar', () {
    test('agrega un producto nuevo', () async {
      final cart = await CartService.load();
      await cart.add(_product());

      expect(cart.isEmpty, isFalse);
      expect(cart.totalItems, 1);
      expect(cart.itemList.first.quantity, 1);
    });

    test('suma la cantidad si el producto ya existe', () async {
      final cart = await CartService.load();
      final product = _product(stock: 10);

      await cart.add(product, quantity: 2);
      await cart.add(product, quantity: 3);

      expect(cart.itemList.length, 1);
      expect(cart.totalItems, 5);
    });

    test('no agrega un producto agotado', () async {
      final cart = await CartService.load();
      final added = await cart.add(_product(stock: 0));

      expect(added, isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('no agrega un producto inactivo', () async {
      final cart = await CartService.load();
      final added = await cart.add(_product(active: false));

      expect(added, isFalse);
      expect(cart.isEmpty, isTrue);
    });

    test('no agrega cantidad cero o negativa', () async {
      final cart = await CartService.load();
      final added = await cart.add(_product(), quantity: 0);

      expect(added, isFalse);
      expect(cart.isEmpty, isTrue);
    });
  });

  group('CartService limites de cantidad', () {
    test('add respeta el stock disponible', () async {
      final cart = await CartService.load();
      // Stock 3, se piden 10: debe quedar en 3, no en 10.
      await cart.add(_product(stock: 3), quantity: 10);

      expect(cart.itemList.first.quantity, 3);
    });

    test('increment no supera el stock', () async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 2));

      await cart.increment('p1');
      await cart.increment('p1');
      await cart.increment('p1'); // deberia ser no-op

      expect(cart.itemList.first.quantity, 2);
    });

    test('increment respeta el tope por item con stock alto', () async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 1000));

      for (var i = 0; i < 150; i++) {
        await cart.increment('p1');
      }

      expect(cart.itemList.first.quantity, CartService.maxQuantityPerItem);
    });

    test('decrement elimina el item al llegar a 1', () async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 5));

      await cart.decrement('p1');

      expect(cart.isEmpty, isTrue);
    });

    test('decrement en cantidad mayor a 1 solo baja en uno', () async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 5), quantity: 3);

      await cart.decrement('p1');

      expect(cart.totalItems, 2);
    });
  });

  group('CartService totales', () {
    test('subtotal multiplica precio por cantidad', () async {
      final cart = await CartService.load();
      await cart.add(_product(price: 25000, stock: 10), quantity: 3);

      expect(cart.subtotal, 75000);
    });

    test('totalItems suma todas las cantidades', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10), quantity: 2);
      await cart.add(_product(id: 'b', stock: 10), quantity: 3);

      expect(cart.itemList.length, 2);
      expect(cart.totalItems, 5);
    });

    test('remove quita solo el item indicado', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10));
      await cart.add(_product(id: 'b', stock: 10));

      await cart.remove('a');

      expect(cart.itemList.length, 1);
      expect(cart.itemList.first.product.id, 'b');
    });

    test('remove de un id inexistente no cambia nada', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10));

      await cart.remove('no-existe');

      expect(cart.totalItems, 1);
    });

    test('clear vacia el carrito', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10));
      await cart.add(_product(id: 'b', stock: 10));

      await cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.subtotal, 0);
    });
  });

  group('CartService persistencia', () {
    test('el carrito sobrevive a una recarga', () async {
      final first = await CartService.load();
      await first.add(_product(id: 'a', price: 12345, stock: 10), quantity: 2);

      // Nueva instancia: lee de SharedPreferences.
      final second = await CartService.load();

      expect(second.totalItems, 2);
      expect(second.subtotal, 24690);
      expect(second.itemList.first.product.name, 'Producto');
    });

    test('un item con cantidad 0 no se restaura', () async {
      SharedPreferences.setMockInitialValues({
        'kronio_cart_v1':
            '[{"product":{"id":"x","name":"X","slug":"x",'
            '"price":100,"image":"","stock":5},"quantity":0}]',
      });

      final cart = await CartService.load();

      expect(cart.isEmpty, isTrue);
    });

    test('un producto sin id no se restaura', () async {
      SharedPreferences.setMockInitialValues({
        'kronio_cart_v1':
            '[{"product":{"id":"","name":"X","slug":"x",'
            '"price":100,"image":"","stock":5},"quantity":3}]',
      });

      final cart = await CartService.load();

      expect(cart.isEmpty, isTrue);
    });

    test('JSON corrupto no rompe la carga', () async {
      SharedPreferences.setMockInitialValues({
        'kronio_cart_v1': 'esto no es json {{{',
      });

      final cart = await CartService.load();

      expect(cart.isEmpty, isTrue);
      expect(cart.isLoaded, isTrue);
    });
  });

  group('CartService.revalidateStock', () {
    test('reduce la cantidad si el stock bajo', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10), quantity: 8);

      final result = await cart.revalidateStock([_product(id: 'a', stock: 3)]);

      expect(cart.itemList.first.quantity, 3);
      expect(result.reducedQuantities, contains('a'));
      expect(result.hasChanges, isTrue);
    });

    test('elimina productos que se agotaron', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10), quantity: 2);

      final result = await cart.revalidateStock([_product(id: 'a', stock: 0)]);

      expect(cart.isEmpty, isTrue);
      expect(result.removedProducts, contains('a'));
    });

    test('no toca items que no vienen en la lista del servidor', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10), quantity: 2);

      final result = await cart.revalidateStock([
        _product(id: 'otro', stock: 5),
      ]);

      expect(cart.totalItems, 2);
      expect(result.hasChanges, isFalse);
    });

    test('no modifica nada si las cantidades ya son validas', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10), quantity: 5);

      final result = await cart.revalidateStock([_product(id: 'a', stock: 10)]);

      expect(cart.itemList.first.quantity, 5);
      expect(result.hasChanges, isFalse);
    });

    test('refresca el precio si el servidor lo cambio', () async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', price: 10000, stock: 10));

      await cart.revalidateStock([_product(id: 'a', price: 8000, stock: 10)]);

      expect(cart.subtotal, 8000);
    });
  });
}

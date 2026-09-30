import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/models/product.dart';
import 'package:kronio_app/screens/cart_screen.dart';
import 'package:kronio_app/services/cart_service.dart';
import 'package:kronio_app/theme/app_theme.dart';
import 'package:kronio_app/widgets/cart_button.dart';
import 'package:kronio_app/widgets/cart_scope.dart';
import 'package:kronio_app/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product({
  String id = 'p1',
  String name = 'Producto de prueba',
  double price = 10000,
  int stock = 10,
  String image = '',
}) {
  return Product(
    id: id,
    name: name,
    slug: id,
    price: price,
    image: image,
    stock: stock,
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  CartService cart,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: CartScope(cart: cart, child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProductCard', () {
    testWidgets('muestra el nombre y el precio formateado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(product: _product(name: 'Reloj', price: 269000)),
          ),
        ),
      );

      expect(find.text('Reloj'), findsOneWidget);
      expect(find.text(r'$ 269.000'), findsOneWidget);
    });

    testWidgets('muestra el porcentaje de descuento', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(
              product: Product.fromJson({
                'id': 'a',
                'name': 'Algo',
                'slug': 'a',
                'price': '80000',
                'oldPrice': '100000',
                'image': '',
                'stock': 5,
              }),
            ),
          ),
        ),
      );

      expect(find.text('-20%'), findsOneWidget);
    });

    testWidgets('no muestra descuento si el precio subio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(
              product: Product.fromJson({
                'id': 'a',
                'name': 'Cosa',
                'slug': 'a',
                'price': '60000',
                'oldPrice': '20500',
                'image': '',
                'stock': 5,
              }),
            ),
          ),
        ),
      );

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('marca como agotado y bloquea la compra', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ProductCard(product: _product(stock: 0))),
        ),
      );

      expect(find.text('AGOTADO'), findsOneWidget);
    });

    testWidgets('avisa cuando quedan pocas unidades', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(
              product: Product.fromJson({
                'id': 'a',
                'name': 'Cosa',
                'slug': 'a',
                'price': '1000',
                'image': '',
                'stock': 2,
                'lowStockThreshold': 5,
              }),
            ),
          ),
        ),
      );

      expect(find.text('Ultimas 2 unidades'), findsOneWidget);
    });

    testWidgets('muestra placeholder si no hay imagen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProductCard(product: _product(image: '')),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });

  group('CartButton', () {
    testWidgets('no muestra el badge con el carrito vacio', (tester) async {
      final cart = await CartService.load();
      await _pumpApp(tester, cart, const Scaffold(body: CartButton()));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('muestra el total de items', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10), quantity: 3);

      await _pumpApp(tester, cart, const Scaffold(body: CartButton()));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('limita el badge a 99+', (tester) async {
      final cart = await CartService.load();
      // Se agregan muchos items distintos para pasar de 99.
      for (var i = 0; i < 3; i++) {
        await cart.add(_product(id: 'p$i', stock: 40), quantity: 40);
      }

      await _pumpApp(tester, cart, const Scaffold(body: CartButton()));

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('CartScreen', () {
    testWidgets('muestra el estado vacio', (tester) async {
      final cart = await CartService.load();
      await _pumpApp(tester, cart, const CartScreen());

      expect(find.text('Tu carrito esta vacio'), findsOneWidget);
      expect(find.text('Ir a la tienda'), findsOneWidget);
    });

    testWidgets('lista los productos del carrito', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(name: 'Producto A', stock: 10), quantity: 2);

      await _pumpApp(tester, cart, const CartScreen());

      expect(find.text('Producto A'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(r'$ 20.000'), findsOneWidget);
    });

    testWidgets('muestra el subtotal', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(price: 5000, stock: 10), quantity: 3);

      await _pumpApp(tester, cart, const CartScreen());

      expect(find.text(r'$ 15.000'), findsOneWidget);
    });

    testWidgets('el boton + se deshabilita al llegar al maximo por item', (
      tester,
    ) async {
      final cart = await CartService.load();
      // Stock 1: no se puede pasar de 1 unidad.
      await cart.add(_product(stock: 1));

      await _pumpApp(tester, cart, const CartScreen());

      final plusButton = find.byIcon(Icons.add_circle_outline);
      expect(plusButton, findsOneWidget);

      final iconButton = tester.widget<IconButton>(
        find.ancestor(of: plusButton, matching: find.byType(IconButton)),
      );
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('el boton - esta habilitado y baja la cantidad', (
      tester,
    ) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10), quantity: 3);

      await _pumpApp(tester, cart, const CartScreen());

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(cart.totalItems, 2);
    });

    testWidgets('baja a cero elimina el item del carrito', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10));

      await _pumpApp(tester, cart, const CartScreen());

      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pumpAndSettle();

      expect(cart.isEmpty, isTrue);
      expect(find.text('Tu carrito esta vacio'), findsOneWidget);
    });

    testWidgets('el boton de quitar item lo elimina', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10));

      await _pumpApp(tester, cart, const CartScreen());

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(cart.isEmpty, isTrue);
    });

    testWidgets('el boton de vaciar pide confirmacion y luego limpia', (
      tester,
    ) async {
      final cart = await CartService.load();
      await cart.add(_product(id: 'a', stock: 10));
      await cart.add(_product(id: 'b', stock: 10));

      await _pumpApp(tester, cart, const CartScreen());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('¿Vaciar carrito?'), findsOneWidget);

      await tester.tap(find.text('Vaciar'));
      await tester.pumpAndSettle();

      expect(cart.isEmpty, isTrue);
    });

    testWidgets('cancelar el vaciado no borra nada', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10));

      await _pumpApp(tester, cart, const CartScreen());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cart.isEmpty, isFalse);
      expect(cart.totalItems, 1);
    });

    testWidgets('bloquea el pago si hay productos agotados', (tester) async {
      final cart = await CartService.load();
      // El producto se guarda con stock 10, luego se marca agotado en memoria.
      await cart.add(_product(stock: 10));
      cart.itemList.first.product = _product(stock: 0);

      await _pumpApp(tester, cart, const CartScreen());

      final payButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceder al pago'),
      );
      expect(payButton.onPressed, isNull);
    });

    testWidgets('permite el pago si no hay productos agotados', (tester) async {
      final cart = await CartService.load();
      await cart.add(_product(stock: 10));

      await _pumpApp(tester, cart, const CartScreen());

      final payButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceder al pago'),
      );
      expect(payButton.onPressed, isNotNull);
    });

    testWidgets('el boton de vaciar no aparece con el carrito vacio', (
      tester,
    ) async {
      final cart = await CartService.load();
      await _pumpApp(tester, cart, const CartScreen());

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}

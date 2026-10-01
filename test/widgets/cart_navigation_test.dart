import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kronio_app/widgets/cart_button.dart';
// main.dart real: usa la KronioApp tal cual la usa la app.
import 'package:kronio_app/main.dart' as app;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('la app real abre el carrito desde el icono sin error', (
    tester,
  ) async {
    // CartService real, con un item, para que no este vacio.
    SharedPreferences.setMockInitialValues({
      'flutter.kronio_cart_v1': '[{"product":{"id":"a","name":"Producto","slug":"p","price":269000,"image":"","stock":100},"quantity":2}]',
    });

    await tester.pumpWidget(const app.KronioApp());
    await tester.pumpAndSettle();

    // Salta la pantalla de bienvenida; el carrito ya esta hidratado.
    expect(find.byType(CartButton), findsOneWidget);

    await tester.tap(find.byType(CartButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('la app real con carrito vacio abre el carrito sin error', (
    tester,
  ) async {
    await tester.pumpWidget(const app.KronioApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CartButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tu carrito esta vacio'), findsOneWidget);
  });
}

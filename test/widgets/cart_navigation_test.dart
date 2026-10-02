import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kronio_app/widgets/brand_logo.dart';
import 'package:kronio_app/widgets/cart_button.dart';
// main.dart real: usa la KronioApp tal cual la usa la app.
import 'package:kronio_app/main.dart' as app;

/// Espera a que la app termine el arranque.
///
/// `pumpAndSettle()` **no** sirve para esto y ya casi lo arruinó. `KronioApp`
/// monta un `BrandSplash` mientras `loadBootstrap()` resuelve (carrito de disco,
/// sesion y catalogo de red). Ese trabajo es asincrono de verdad, y
/// `pumpAndSettle()` solo avanza el reloj simulado: no le da tiempo real a la
/// red. Antes se salvaba de milagro porque el splash traia un
/// `CircularProgressIndicator`, que agenda frames para siempre y hacia que
/// `pumpAndSettle` siguiera bombeando. Se quito el indicador (quedo solo el
/// logo y el nombre, a pedido), y con el se fue ese "truco" accidental.
///
/// La via que si funciona es [WidgetTester.runAsync], que ejecuta el callback
/// fuera de la zona de reloj simulado y deja que las promesas de verdad
/// resuelvan. Por eso se busca el `CartButton` de `HomeScreen`: existe solo si
/// el bootstrap ya termino.
///
/// Tambien sirve para no dejar el timer de 20 s de `loadBootstrap` pendiente,
/// que hace fallar el test aunque todo lo demas este bien.
Future<void> _esperarArranque(WidgetTester tester) async {
  for (var intento = 0; intento < 40; intento++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();

    if (find.byType(CartButton).evaluate().isNotEmpty) return;
  }

  fail(
    'La app no arranco: el bootstrap no llego a pintar HomeScreen. '
    'Sigo viendo el splash.',
  );
}

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
    await _esperarArranque(tester);

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
    await _esperarArranque(tester);

    await tester.tap(find.byType(CartButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tu carrito esta vacio'), findsOneWidget);
  });

  testWidgets('el splash solo muestra el logo y el nombre', (tester) async {
    // La primera pantalla que ve el usuario. Se comprueba en la app real, no
    // en un widget suelto, porque lo que importa es lo que se pinta al abrir.
    await tester.pumpWidget(const app.KronioApp());

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Kronio Market'), findsOneWidget);
    expect(find.text('Tu tienda de confianza'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Se comprueba con el splash todavia en pantalla, pero despues se deja
    // terminar el arranque: el bootstrap tiene un timer de 20 s que, si queda
    // pendiente, hace fallar el test aunque el splash este perfecto.
    await _esperarArranque(tester);
  });
}

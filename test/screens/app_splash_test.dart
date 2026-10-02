import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/screens/app_splash.dart';
import 'package:kronio_app/widgets/brand_logo.dart';

/// Pruebas del splash de arranque.
///
/// El splash tiene que ser solo el logo y el nombre. Se salio el eslogan
/// ("Tu tienda de confianza") y el `CircularProgressIndicator` a pedido del
/// usuario: el nombre de la tienda se lee de un vistazo y sin ruido.
///
/// Estos tests existen para que el texto no vuelva por descuido. Un splash es
/// de los sitios donde mas veces se cuela una linea de marketing "mientras
/// tanto", y es justo donde mas se nota si la app arranco o se quedo colgada.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: BrandSplash()));
    await tester.pump();
  }

  testWidgets('muestra el logo y el nombre', (tester) async {
    await pump(tester);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Kronio Market'), findsOneWidget);
  });

  testWidgets('no muestra el eslogan', (tester) async {
    await pump(tester);

    expect(find.text('Tu tienda de confianza'), findsNothing);
  });

  testWidgets('no muestra el indicador de carga', (tester) async {
    // Quitarlo deja la carga invisible durante el arranque. Es lo pedido, pero
    // queda escrito por si manana alguien lo "restaura" creyendo que es un
    // descuido: el logo solo es la decision, no un forgotten.
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ProgressIndicator), findsNothing);
  });

  testWidgets('el nombre completo se ve sin cortarse', (tester) async {
    // El nombre va centrado y sin `Flexible`, asi que deberia caber siempre.
    // Se mide igual: si alguien lo envuelve en algo con elipsis, el splash
    // mostraria "Kronio Mark..." justo en la primera pantalla que ve el
    // usuario, que es el peor sitio posible para eso.
    await pump(tester);

    final finder = find.text('Kronio Market');
    final text = tester.widget<Text>(finder);
    final context = tester.element(finder);

    final natural = (TextPainter(
      text: TextSpan(
        text: text.data,
        style: DefaultTextStyle.of(context).style.merge(text.style),
      ),
      textDirection: Directionality.of(context),
    )..layout()).width;

    expect(tester.getSize(finder).width, greaterThanOrEqualTo(natural - 0.5));
  });
}

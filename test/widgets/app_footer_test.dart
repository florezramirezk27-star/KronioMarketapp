import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/widgets/app_footer.dart';
import 'package:kronio_app/widgets/brand_logo.dart';

Future<void> _pumpFooter(WidgetTester tester, {double width = 400}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: const AppFooter()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('muestra marca, columnas y copyright', (tester) async {
    await _pumpFooter(tester);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.text('AYUDA'), findsOneWidget);
    expect(find.text('Contacto'), findsOneWidget);
    expect(find.text('Politica de privacidad'), findsOneWidget);
    expect(find.textContaining('Kronio Market'), findsWidgets);
  });

  testWidgets('cada enlace abre su dialogo', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Contacto'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('Esta seccion todavia no esta disponible.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  // En pantallas anchas las columnas van en fila; en telefono se apilan.
  // Se prueba el telefono porque es donde se decide.
  testWidgets('en pantalla ancha las columnas van en fila', (tester) async {
    await _pumpFooter(tester, width: 700);

    final tienda = tester.getTopLeft(find.text('TIENDA'));
    final ayuda = tester.getTopLeft(find.text('AYUDA'));

    expect(ayuda.dx, greaterThan(tienda.dx), reason: 'deben ir lado a lado');
  });
}

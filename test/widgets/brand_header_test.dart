import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/widgets/brand_header.dart';
import 'package:kronio_app/widgets/brand_logo.dart';

void main() {
  testWidgets('muestra logo y nombre de la marca', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandHeader())),
    );

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Kronio Market'), findsOneWidget);
  });

  testWidgets('con showName false dibuja solo el logo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandHeader(showName: false))),
    );

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Kronio Market'), findsNothing);
  });

  testWidgets('expone la accion como boton accesible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandHeader())),
    );

    final node = tester.getSemantics(find.byType(BrandHeader));
    expect(node.label, contains('Ir al inicio'));
    expect(node.flagsCollection.isButton, isTrue);
  });

  // El footer y el AppBar comparten este comportamiento: al tocar la marca se
  // cierra todo lo que haya apilado encima, no solo la ultima pantalla.
  // Antes el menu de perfil vive bajo el carrito y el detalle, asi que hace
  // falta `popUntil` y no un `pop` suelto.
  testWidgets('goHome cierra las pantallas apiladas y vuelve a la raiz', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          appBar: AppBar(title: BrandHeader(showName: false)),
          body: const Text('raiz'),
        ),
      ),
    );

    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: BrandHeader(showName: false)),
          body: const Text('nivel 2'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nivel 2'), findsOneWidget);

    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: BrandHeader(showName: false)),
          body: const Text('nivel 3'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nivel 3'), findsOneWidget);

    await tester.tap(find.byType(BrandHeader));
    await tester.pumpAndSettle();

    // Un `pop` simple habria dejado al usuario en "nivel 2".
    expect(find.text('raiz'), findsOneWidget);
    expect(find.text('nivel 2'), findsNothing);
    expect(find.text('nivel 3'), findsNothing);
  });

  testWidgets('goHome no revienta cuando ya se esta en la raiz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: BrandHeader(showName: false)),
          body: const Text('raiz'),
        ),
      ),
    );

    await tester.tap(find.byType(BrandHeader));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('raiz'), findsOneWidget);
  });

  testWidgets('ComingSoonTag muestra la etiqueta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ComingSoonTag())),
    );

    expect(find.text('Pronto'), findsOneWidget);
  });
}

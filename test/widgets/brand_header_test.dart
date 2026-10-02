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

  // El nombre se cortaba a "Kronio Mark..." dentro del `AppBar` de
  // `HomeScreen`. La causa no es solo el ancho: dentro de un `AppBar` el
  // `DefaultTextStyle` es `titleLarge` (22 px), asi que un `Text` sin
  // `fontSize` propio se inflaba y ya no cabia al lado de los tres botones.
  // Estos tests fijan que el nombre se ve completo.
  group('el nombre no se corta', () {
    testWidgets('con el AppBar real de HomeScreen, con 3 acciones', (
      tester,
    ) async {
      // 360 dp logicos, un telefono pequeno. Se replica el `AppBar` real: sin
      // las tres acciones el nombre tendria sitio de sobra y el test pasaria
      // sin comprobar nada.
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const BrandHeader(),
              actions: const [
                Icon(Icons.search),
                Icon(Icons.shopping_cart_outlined),
                Icon(Icons.person_outline),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_nombreSeMideEntero(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con tamano de fuente grande del sistema', (tester) async {
      // Un usuario con fuente grande es un caso real, no un invento. Con
      // `scaleDown` el nombre se reduce para caber; lo que no puede pasar es
      // que se corte, porque el `Text` nunca recibe el ancho disponible.
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              appBar: AppBar(
                title: const BrandHeader(),
                actions: const [
                  Icon(Icons.search),
                  Icon(Icons.shopping_cart_outlined),
                  Icon(Icons.person_outline),
                ],
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_nombreSeMideEntero(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('incluso en un espacio muy angosto', (tester) async {
      // Red de seguridad: si manana el `AppBar` gana otro boton, o el nombre
      // crece, tiene que seguir enteringo. 150 dp es mas de lo que cualquier
      // telefono real da.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                child: const BrandHeader(logoSize: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_nombreSeMideEntero(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no parte el nombre en dos lineas ni le pone elipsis', (
      tester,
    ) async {
      // Partirlo en "Kronio" / "Market" se lee peor que una version chica: con
      // una fila de iconos al lado parece un error de maquetacion. Y con
      // elipsis el nombre se recorta al ancho disponible en vez de reducirse,
      // que es lo que se estaba viendo en el telefono.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 150, child: const BrandHeader()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Kronio Market'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}

/// Dice si el `Text` del nombre se midio a su tamano natural.
///
/// Es la comprobacion que distingue "el nombre se ve entero" de "el nombre se
/// corto": con `FittedBox(fit: scaleDown)`, Flutter devuelve `BoxConstraints()`
/// vacias al hijo, asi que el `Text` se mide a lo que ocupa de verdad y despues
/// se reduce visualmente. Si estuviera recortado, el `Text` habria recibido el
/// ancho disponible y su ancho seria menor que el natural.
///
/// No se compara contra el ancho de la pantalla: eso no prueba nada, porque
/// tambien "cabe" cuando el texto quedo en una sola palabra.
bool _nombreSeMideEntero(WidgetTester tester) {
  final finder = find.text('Kronio Market');
  final text = tester.widget<Text>(finder);
  final context = tester.element(finder);

  final natural =
      (TextPainter(
            text: TextSpan(
              text: text.data,
              style: DefaultTextStyle.of(context).style.merge(text.style),
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout()) //
          .width;

  final medido = tester.getSize(finder).width;

  // 0.5 de tolerancia por el redondeo a pixeles fisicos.
  return medido >= natural - 0.5;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/screens/content_screen.dart';
import 'package:kronio_app/widgets/app_footer.dart';
import 'package:kronio_app/widgets/brand_header.dart';
import 'package:kronio_app/widgets/brand_logo.dart';

/// Monta el footer dentro de una app con las rutas nombradas que usa.
///
/// Se usa `KronioApp`-con-rutas real para que "Carrito" y "Mi cuenta" lleguen a
/// las mismas rutas que en produccion: si `routes` y el footer se
/// desincronizan, el test falla en vez de romperse en el telefono.
///
/// El viewport se agranda a proposito: con los 800x600 por defecto, la parte de
/// abajo del footer queda fuera de pantalla y `ListView`/`SingleChildScrollView`
/// nunca la construyen, asi que los enlaces de abajo no existirian para el
/// finder.
Future<void> _pumpFooter(
  WidgetTester tester, {
  double width = 400,
  bool withRoutes = false,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final body = Center(
    child: SizedBox(
      width: width,
      child: const SingleChildScrollView(child: AppFooter()),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      routes: {
        if (withRoutes) ...{
          '/cart': (_) => const Scaffold(body: Text('Pantalla de carrito')),
          '/profile': (_) => const Scaffold(body: Text('Pantalla de perfil')),
        },
      },
      home: Scaffold(body: body),
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

  // Este es el cambio de fondo: antes cada enlace abria un dialogo que decia
  // "esta seccion todavia no esta disponible". Ahora cada uno hace algo real.
  testWidgets('Contacto avisa y ensena la direccion si no puede abrir', (
    tester,
  ) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Contacto'));
    await tester.pump();

    // En un entorno de test no hay cliente de correo, asi que la llamada a
    // `url_launcher` nunca responde. Este `pump` hace avanzar el reloj del fake
    // async mas alla del tope de 5s del codigo, que es justamente lo que
    // impide que el enlace se quede esperando para siempre. Este test es la
    // cobertura de ese tope: si alguien lo quita, el future no resuelve y el
    // `expect` de abajo falla.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.byType(ContentScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('soporte@'), findsOneWidget);
  });

  testWidgets('Politica de privacidad abre su documento', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Politica de privacidad'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);
    expect(
      find.text('Politica de privacidad'),
      findsWidgets,
      reason: 'el titulo esta en el AppBar y en el cuerpo',
    );
    expect(find.textContaining('Datos que nos llegan'), findsOneWidget);
    expect(find.textContaining('Tus derechos'), findsOneWidget);
  });

  testWidgets('Terminos y condiciones abre su documento', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Terminos y condiciones'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);
    expect(find.textContaining('Precios y disponibilidad'), findsOneWidget);
  });

  testWidgets('Sobre nosotros abre su documento', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Sobre nosotros'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);
    expect(find.textContaining('Que puedes hacer aqui'), findsOneWidget);
  });

  testWidgets('Carrito navega a la pantalla del carrito', (tester) async {
    await _pumpFooter(tester, withRoutes: true);

    await tester.tap(find.text('Carrito'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de carrito'), findsOneWidget);
  });

  testWidgets('Mi cuenta navega a la pantalla de perfil', (tester) async {
    await _pumpFooter(tester, withRoutes: true);

    await tester.tap(find.text('Mi cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de perfil'), findsOneWidget);
  });

  // El footer vive en las dos pestanas, asi que "Catalogo" no siempre es un
  // no-op: desde la pestana de inicio tiene que pedir el cambio de pestana.
  testWidgets('Catalogo avisa con el callback y vuelve a la raiz', (
    tester,
  ) async {
    var called = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: AppFooter(onOpenCatalog: () => called++),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Catalogo'));
    await tester.pumpAndSettle();

    expect(called, 1, reason: 'debe pedir el cambio de pestana');
  });

  // En pantallas anchas las columnas van en fila; en telefono se apilan.
  // Se prueba el telefono porque es donde se decide.
  testWidgets('en pantalla ancha las columnas van en fila', (tester) async {
    await _pumpFooter(tester, width: 700);

    final tienda = tester.getTopLeft(find.text('TIENDA'));
    final ayuda = tester.getTopLeft(find.text('AYUDA'));

    expect(ayuda.dx, greaterThan(tienda.dx), reason: 'deben ir lado a lado');
  });

  // El footer se centro porque antes arrancaba a la izquierda y se veia
  // descuadrado contra el logo de la cabecera.
  testWidgets('la marca y las columnas quedan centradas', (tester) async {
    await _pumpFooter(tester, width: 400);

    final footerCenter = tester.getRect(find.byType(AppFooter)).center.dx;

    // La marca: logo y nombre van centrados como bloque.
    final marca = tester.getRect(find.byType(BrandHeader));
    expect(
      marca.center.dx,
      closeTo(footerCenter, 1),
      reason: 'la marca debe quedar centrada',
    );

    // Las dos columnas. Se mide el titulo de cada una, que es lo que define
    // el ancho del bloque.
    for (final titulo in ['TIENDA', 'AYUDA']) {
      expect(
        tester.getRect(find.text(titulo)).center.dx,
        closeTo(footerCenter, 1),
        reason: 'la columna "$titulo" debe quedar centrada',
      );
    }
  });

  testWidgets('cada enlace es un bloque centrado', (tester) async {
    await _pumpFooter(tester, width: 400);

    final footerCenter = tester.getRect(find.byType(AppFooter)).center.dx;

    // Se mide el `Row` del enlace (icono + texto) y no solo el texto: el texto
    // va corrido a la derecha porque el icono ocupa 16px a su izquierda, asi
    // que medir solo el texto daria un falso negativo.
    final fila = find.ancestor(
      of: find.text('Contacto'),
      matching: find.byType(Row),
    );

    expect(
      tester.getRect(fila).center.dx,
      closeTo(footerCenter, 1),
      reason: 'el enlace debe quedar centrado, no pegado a la izquierda',
    );
  });
}

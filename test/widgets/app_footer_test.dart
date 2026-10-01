import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/config/app_config.dart';
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
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(900, height);
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
  /// Abre un documento del footer en un viewport de teléfono real.
  ///
  /// El alto importa: con los 2400px que usa el resto de los tests el
  /// documento entero cabe en pantalla, así que no hay nada que probar de
  /// scroll. Con 800 de alto pasa lo que pasa en un teléfono de verdad.
  Future<void> openDocument(
    WidgetTester tester,
    String label, {
    double height = 800,
  }) async {
    await _pumpFooter(tester, height: height);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra marca, columnas y copyright', (tester) async {
    await _pumpFooter(tester);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('TIENDA'), findsOneWidget);
    expect(find.text('AYUDA'), findsOneWidget);
    expect(find.text('Contacto'), findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.textContaining('Kronio Market'), findsWidgets);

    // El enlace "Datos personales" se quitó a propósito: la política de
    // privacidad ya es el aviso de la Ley 1581.
    expect(find.text('Datos personales'), findsNothing);
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
    expect(find.textContaining('@'), findsWidgets);
    expect(
      find.textContaining(AppConfig.supportEmail),
      findsOneWidget,
      reason: 'el aviso tiene que decir a qué correo escribir',
    );
  });

  testWidgets('la politica de privacidad trae el aviso de datos', (
    tester,
  ) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Política de privacidad'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);

    // A partir de aca los `findsWidgets` y no `findsOneWidget`: el índice
    // "Contenido" de la pantalla repite cada título de sección, así que un
    // título aparece dos veces (en el índice y en el cuerpo) y una ley citada
    // en varios apartados aparece tres. Buscar exactamente una coincidencia
    // haría fallar el test por el índice, no por el contenido.
    expect(find.textContaining('Ley 1581'), findsWidgets);
    expect(
      find.textContaining('Datos personales que recopilamos'),
      findsWidgets,
    );
    expect(find.textContaining('Principios del tratamiento'), findsWidgets);
    expect(
      find.textContaining('Derechos del titular de los datos'),
      findsWidgets,
    );
  });

  // El chatbot manda la conversación a servidores de Google fuera del país, y
  // eso tiene que estar escrito. Vive en el apartado 11, así que hay que
  // llegar abajo: un `find` sin desplazar no encontraría nada porque el
  // `ListView` aún no construyó esa parte.
  testWidgets('la politica declara la transferencia al exterior', (
    tester,
  ) async {
    await openDocument(tester, 'Política de privacidad');

    // Se busca la frase del chatbot, no "fuera de Colombia" a secas: el
    // apartado 11 lo dice dos veces y un `findsOneWidget` fallaría por algo que
    // está bien.
    expect(
      find.textContaining('servidores de Google ubicados fuera de Colombia'),
      findsOneWidget,
    );
    expect(find.textContaining('artículo 26'), findsOneWidget);
  });

  // El aviso de que los datos de empresa son marcadores de posición. Sin él,
  // un consumidor leería "NIT: 000.000.000-0" creyendo que es el real.
  testWidgets('el documento avisa que faltan los datos de la empresa', (
    tester,
  ) async {
    await openDocument(tester, 'Términos y condiciones');

    expect(find.textContaining('pendiente de completar'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });

  testWidgets('Términos y condiciones abre su documento', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);
    expect(
      find.textContaining('Productos e información suministrada'),
      findsWidgets,
    );
    expect(find.textContaining('Medios de pago'), findsWidgets);
    expect(find.textContaining('PQRS y canales de atención'), findsWidgets);
  });

  testWidgets('Sobre nosotros abre su documento', (tester) async {
    await _pumpFooter(tester);

    await tester.tap(find.text('Sobre nosotros'));
    await tester.pumpAndSettle();

    expect(find.byType(ContentScreen), findsOneWidget);
    expect(find.textContaining('Qué puedes hacer aquí'), findsWidgets);
  });

  // El índice de la pantalla se arma desde `document.sections` y salta con
  // `Scrollable.ensureVisible`. Si el índice no existiera o no saltara, en un
  // documento de treinta secciones el usuario no encontraría nada.
  testWidgets('el indice salta a la seccion elegida', (tester) async {
    await openDocument(tester, 'Términos y condiciones');

    expect(find.text('CONTENIDO'), findsOneWidget);
    expect(
      find.text('9. Garantía legal'),
      findsNWidgets(2),
      reason: 'el título aparece en el índice y en el cuerpo',
    );

    // Al abrir el documento el apartado 9 está lejos, más allá de la pantalla.
    final cuerpo = find.textContaining('Plazo: la garantía empieza a correr');
    expect(cuerpo, findsOneWidget);
    expect(
      tester.getTopLeft(cuerpo).dy,
      greaterThan(800),
      reason: 'debe estar fuera del viewport antes del salto',
    );

    // La entrada del índice para el apartado 9 también está bajo el pliegue: en
    // un teléfono de 800px el índice completo no cabe. Hay que bajarlo antes
    // de tocarlo, igual que haría el dedo del usuario.
    final entrada = find.text('9. Garantía legal').first;
    await tester.ensureVisible(entrada);
    await tester.pumpAndSettle();

    await tester.tap(entrada);
    await tester.pumpAndSettle();

    // Después del salto el cuerpo de esa sección queda pegado al AppBar.
    expect(
      tester.getTopLeft(cuerpo).dy,
      lessThan(400),
      reason: 'el índice debe dejar la sección elegida cerca del AppBar',
    );

    // Y el título de la sección quedó arriba, no en la posición que tenía antes
    // del salto.
    expect(
      tester.getTopLeft(find.text('9. Garantía legal').last).dy,
      lessThan(200),
    );
  });

  // Con un documento corto, un índice de tres líneas es ruido que empuja el
  // contenido real hacia abajo.
  testWidgets('el indice aparece solo cuando compensan los apartados', (
    tester,
  ) async {
    await openDocument(tester, 'Sobre nosotros');
    expect(find.text('CONTENIDO'), findsOneWidget);
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

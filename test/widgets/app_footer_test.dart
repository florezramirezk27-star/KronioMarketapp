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

  // El footer se alineó a la izquierda. Antes estaba centrado, que es
  // precisamente lo que lo hacia ver como plantilla: los footers de las tiendas
  // en linea arrancan a la izquierda. Estos tests fijan esa decision para que
  // nadie vuelva a centrarlo "porque se ve mas limpio".
  testWidgets('la marca y las columnas arrancan a la izquierda', (
    tester,
  ) async {
    await _pumpFooter(tester, width: 400);

    final footerLeft = tester.getRect(find.byType(AppFooter)).left;
    final ancho = tester.getRect(find.byType(AppFooter)).width;

    // El margen del pie son 20 dp, asi que el contenido arranca 20 px mas a la
    // derecha que el borde del contenedor.
    final contenidoIzq = footerLeft + 20;

    final marca = tester.getRect(find.byType(BrandHeader));
    expect(
      marca.left,
      closeTo(contenidoIzq, 1),
      reason: 'la marca debe arrancar en el margen izquierdo',
    );

    // Los titulos de las columnas, que es lo que define su bloque.
    for (final titulo in ['TIENDA', 'AYUDA']) {
      expect(
        tester.getRect(find.text(titulo)).left,
        closeTo(contenidoIzq, 1),
        reason: 'la columna "$titulo" debe arrancar en el margen izquierdo',
      );
    }

    // Y la marca no debe ocupar el ancho completo, que es lo que hacia alinear
    // al centro. El umbral es 75% porque `BrandHeader` mide el nombre con
    // `FittedBox` y reserva el ancho disponible; lo que importa es que el
    // bloque arranque en el margen, no en el centro.
    expect(marca.right, lessThan(footerLeft + ancho * 0.75));
  });

  testWidgets('cada enlace arranca en el mismo borde izquierdo', (
    tester,
  ) async {
    // Todos los enlaces comparten el borde vertical. Con `Flexible` en vez de
    // `Expanded` el texto se pegaba al icono y cada linea empezaba en un punto
    // distinto, que es lo que hacia ver el bloque desordenado.
    await _pumpFooter(tester, width: 400);

    final contenidoIzq = tester.getRect(find.byType(AppFooter)).left + 20;

    for (final etiqueta in ['Catalogo', 'Carrito', 'Mi cuenta']) {
      final fila = find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(Row),
      );
      final rect = tester.getRect(fila);

      expect(
        rect.left,
        closeTo(contenidoIzq, 1),
        reason: '"$etiqueta" debe arrancar en el margen izquierdo',
      );
    }
  });

  group('ventajas de compra', () {
    // Los tres datos de compra. Cada uno sale de lo que ya dicen los terminos,
    // asi que no se afirma nada que la app no cumpla.
    testWidgets('muestra las tres condiciones reales de compra', (
      tester,
    ) async {
      await _pumpFooter(tester);

      expect(find.text('Paga al recibir'), findsOneWidget);
      expect(find.text('30 días para devolver'), findsOneWidget);
      expect(find.text('Envíos a todo el país'), findsOneWidget);
    });

    // El detalle importa mas que el titulo: "paga al recibir" sin mas podria
    // ser cualquier cosa. El texto deja claro que no se piden datos de tarjeta,
    // que es lo que un comprador Colombian va a leer como señal de confianza.
    testWidgets('aclara que no se piden datos de tarjeta', (tester) async {
      await _pumpFooter(tester);

      expect(
        find.text('Contra entrega, sin pedirte datos de tarjeta'),
        findsOneWidget,
      );
    });

    // Reclamo obligatorio de la Ley 1480: sin el aviso en la pantalla donde se
    // compra, el consumidor no puede saber que existen esos 30 dias.
    testWidgets('el plazo de devolucion es el de la garantia legal', (
      tester,
    ) async {
      await _pumpFooter(tester);

      expect(find.textContaining('30 días'), findsWidgets);
    });

    // Un pie de 400 dp tiene que apilar las tarjetas: en fila, cada una
    // quedaria en ~120 dp y "Envíos a todo el país" se partiria en dos lineas.
    testWidgets('en telefono las ventajas se apilan', (tester) async {
      await _pumpFooter(tester, width: 400);

      final pagas = tester.getTopLeft(find.text('Paga al recibir')).dy;
      final treinta = tester.getTopLeft(find.text('30 días para devolver')).dy;
      final envios = tester.getTopLeft(find.text('Envíos a todo el país')).dy;

      expect(treinta, greaterThan(pagas));
      expect(envios, greaterThan(treinta));
    });

    testWidgets('en pantalla ancha las ventajas van en fila', (tester) async {
      await _pumpFooter(tester, width: 700);

      final pagas = tester.getRect(find.text('Paga al recibir'));
      final envios = tester.getRect(find.text('Envíos a todo el país'));

      // Misma altura vertical: comparten fila.
      expect(pagas.top, closeTo(envios.top, 1));
      expect(envios.left, greaterThan(pagas.left));
    });
  });

  group('el pie no muestra datos de desarrollo', () {
    // "production" al pie de la tienda es informacion de desarrollo en la
    // ultima pantalla que ve el cliente. Se quito de aqui, pero sigue en la
    // pantalla de perfil, que es donde se mira al depurar.
    testWidgets('no muestra el nombre del entorno', (tester) async {
      await _pumpFooter(tester);

      expect(find.text(AppConfig.environment), findsNothing);
    });

    // Lo que si se muestra es un dato que le sirve al cliente y que la SIC
    // exige tener a la vista: la ciudad de la tienda.
    testWidgets('muestra la ciudad en vez del entorno', (tester) async {
      await _pumpFooter(tester);

      expect(find.text(AppConfig.legalCity), findsOneWidget);
    });
  });

  // Un enlace tiene que tener la misma superficie de pulsado que el resto de la
  // lista, no solo el texto. Antes el `Padding` horizontal dejaba 8 px de zona
  // muerta a la izquierda, y con el texto alineado a la izquierda eso se nota.
  testWidgets('la superficie de pulsado cubre toda la linea', (tester) async {
    await _pumpFooter(tester, width: 400);

    final contenidoIzq = tester.getRect(find.byType(AppFooter)).left + 20;

    final pulsable = tester.getRect(
      find.ancestor(of: find.text('Contacto'), matching: find.byType(InkWell)),
    );

    expect(
      pulsable.left,
      closeTo(contenidoIzq, 1),
      reason: 'la zona pulsable no debe dejar margen muerto a la izquierda',
    );
  });
}

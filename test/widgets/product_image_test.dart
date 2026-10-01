import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/widgets/product_image.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// `path_provider` no tiene implementacion en tests, y `flutter_cache_manager`
/// lo pide al construirse. Se le da una carpeta temporal de mentira.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider();

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

void main() {
  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  // El cache manager se limpia dentro de la zona de test; en `main` no hay
  // invoker y `package:http` revienta al construirse.
  tearDown(() => DefaultCacheManager().emptyCache());

  testWidgets('con URL vacia dibuja el marcador sin pedir nada', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductImage(url: '')));

    expect(find.byType(ProductImagePlaceholder), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  // El punto de todo el cambio: la foto pasa por el proveedor con cache en
  // disco, no por `Image.network`, que solo cachea en memoria.
  testWidgets('usa el proveedor con cache y respeta memCacheWidth', (
    tester,
  ) async {
    const url = 'https://cdn.test/abc/probiotico.jpeg';

    await tester.pumpWidget(
      _wrap(const ProductImage(url: url, memCacheWidth: 400)),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, url);
    expect(image.memCacheWidth, 400);
  });

  // No se prueba disparando un fallo de red real: `flutter_test` devuelve 400 a
  // todo y `flutter_cache_manager` reintenta con backoff, asi que el estado de
  // error nunca llega de forma determinista. Se verifica directamente que el
  // builder de error que registramos pinta el marcador.
  testWidgets('el builder de error pinta el marcador', (tester) async {
    await tester.pumpWidget(
      _wrap(const ProductImage(url: 'https://cdn.test/abc.jpeg')),
    );
    await tester.pump();

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final errorWidget = image.errorWidget;
    expect(errorWidget, isNotNull, reason: 'debe tener fallback configurado');

    await tester.pumpWidget(
      _wrap(
        errorWidget!(
          tester.element(find.byType(CachedNetworkImage)),
          image.imageUrl,
          'fallo',
        ),
      ),
    );

    expect(find.byType(ProductImagePlaceholder), findsOneWidget);
  });

  testWidgets('el marcador respeta el tamano de icono pedido', (tester) async {
    await tester.pumpWidget(_wrap(const ProductImage(url: '', iconSize: 64)));

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 64);
  });
}

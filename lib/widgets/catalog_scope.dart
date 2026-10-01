import 'package:flutter/widgets.dart';

import '../controllers/catalog_controller.dart';

/// Publica el [CatalogController] ya cargado a las pantallas.
///
/// `HomeScreen` lo lee con [CatalogScope.of] en vez de crear el suyo. Asi el
/// catalogo que se pidio durante el arranque es el mismo que ve la pantalla: no
/// hay una segunda peticion ni un estado intermedio vacio.
///
/// Vive en su propio archivo (y no dentro de `main.dart`) porque `main.dart` y
/// las pantallas son librerias distintas: importar un `_CatalogScope` privado
/// desde alla no compila.
class CatalogScope extends InheritedWidget {
  const CatalogScope({super.key, required this.catalog, required super.child});

  /// El catalogo ya cargado.
  ///
  /// Se lanza excepcion si no hay scope en el arbol en vez de devolver `null`:
  /// un `null` se propagaria como pantalla roja mas lejos, y un
  /// `dependOnInheritedWidgetOfExactType` nulo significa que el arbol esta mal
  /// armado, que es un error de programacion y no de datos.
  static CatalogController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CatalogScope>();
    assert(scope != null, 'No hay CatalogScope en el arbol de widgets.');
    return scope!.catalog;
  }

  final CatalogController catalog;

  @override
  bool updateShouldNotify(CatalogScope oldWidget) =>
      oldWidget.catalog != catalog;
}

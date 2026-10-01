import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';

/// Suministra el [AuthController] al arbol y notifica a los que dependan de el
/// cuando la sesion cambia.
///
/// Mismo patron que `CartScope`: `InheritedNotifier` en vez de pasar el
/// controlador por constructor a cada pantalla.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController auth,
    required super.child,
  }) : super(notifier: auth);

  /// Obtiene el controlador de sesion. Lanza en debug si falta el [AuthScope],
  /// que casi siempre significa que la pantalla se abrio fuera del arbol.
  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope no encontrado en el arbol de widgets');
    return scope!.notifier!;
  }

  /// Variante opcional, para widgets que pueden existir sin sesion.
  static AuthController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/controllers/auth_controller.dart';
import 'package:kronio_app/models/user.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:kronio_app/widgets/auth_scope.dart';
import 'package:kronio_app/widgets/google_sign_in_button.dart';

/// Monta el boton dentro de un `AuthScope` con un `AuthController` mock.
///
/// Usamos un mock manual de `AuthController` para evitar depender de la red.
/// El test solo verifica la UI, no la red.
Future<void> _pumpButton(WidgetTester tester) async {
  final controller = _MockAuthController();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AuthScope(auth: controller, child: const GoogleSignInButton()),
      ),
    ),
  );
}

/// Mock simple de AuthController para tests de UI.
class _MockAuthController extends ChangeNotifier implements AuthController {
  @override
  AuthStatus status = AuthStatus.unauthenticated;

  @override
  User? user;

  @override
  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  bool get isUnknown => status == AuthStatus.unknown;

  @override
  bool isBusy = false;

  @override
  String? error;

  @override
  AuthService get service => throw UnimplementedError();

  // Completer para controlar cuando termina el signIn en tests
  Completer<void>? _signInCompleter;

  @override
  Future<bool> login({required String email, required String password}) async =>
      true;

  @override
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<void> restore() async {}

  @override
  void clearError() {}

  @override
  Future<bool> signInWithGoogle() async {
    isBusy = true;
    notifyListeners();
    _signInCompleter = Completer<void>();
    await _signInCompleter!.future;
    isBusy = false;
    notifyListeners();
    return true;
  }

  /// Completa el sign-in en tests.
  void completeSignIn() {
    _signInCompleter?.complete();
    _signInCompleter = null;
  }
}

void main() {
  testWidgets('el boton muestra el texto de Google', (tester) async {
    await _pumpButton(tester);

    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  // El boton ahora esta habilitado y llama a `signInWithGoogle` del controller.
  testWidgets('al pulsarlo llama a signInWithGoogle', (tester) async {
    await _pumpButton(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    // El boton se deshabilita mientras esta ocupado
    expect(find.text('Conectando...'), findsOneWidget);
  });
}

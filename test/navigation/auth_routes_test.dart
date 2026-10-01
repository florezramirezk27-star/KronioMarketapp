import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/controllers/auth_controller.dart';
import 'package:kronio_app/main.dart' show generateRoute;
import 'package:kronio_app/screens/login_screen.dart';
import 'package:kronio_app/screens/register_screen.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:kronio_app/widgets/auth_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_backend.dart';

/// Abre una ruta nombrada y guarda lo que devuelve, para poder assertar el
/// resultado de `pushNamed<bool>` tal como lo recibe el codigo real.
class _Opener extends StatelessWidget {
  const _Opener({required this.route, required this.onResult});

  final String route;
  final void Function(bool? result) onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await Navigator.of(context).pushNamed<bool>(route);
            onResult(result);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

/// Monta un `MaterialApp` con el **mismo** generador de rutas que usa la app.
///
/// Si `generateRoute` se moviera de vuelta a `routes`, estos tests fallarian,
/// que es justo lo que evitan.
Future<Widget> _appWith(
  FakeAuthBackend backend, {
  required String route,
  required void Function(bool? result) onResult,
}) async {
  final service = await AuthService.create(
    client: backend.client,
    baseUrl: authTestBaseUrl,
  );
  final controller = AuthController(service: service);

  return AuthScope(
    auth: controller,
    child: MaterialApp(
      onGenerateRoute: generateRoute,
      home: _Opener(route: route, onResult: onResult),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Regresion: `/login` se abria con `pushNamed<bool>` pero estaba registrada en
  // `routes`, que siempre produce `MaterialPageRoute<dynamic>`. El casteo a
  // `Route<bool?>` reventaba con
  // "type 'MaterialPageRoute<dynamic>' is not a subtype of type 'Route<bool?>'"
  // y el boton de iniciar sesion no hacia nada.
  testWidgets('abre /login con pushNamed<bool> sin reventar', (tester) async {
    final backend = FakeAuthBackend();
    await tester.pumpWidget(
      await _appWith(backend, route: '/login', onResult: (_) {}),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('/register tambien se abre como Route<bool>', (tester) async {
    final backend = FakeAuthBackend();
    await tester.pumpWidget(
      await _appWith(backend, route: '/register', onResult: (_) {}),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('un login exitoso devuelve true a quien abrio la ruta', (
    tester,
  ) async {
    final backend = FakeAuthBackend();
    bool? result;
    await tester.pumpWidget(
      await _appWith(backend, route: '/login', onResult: (r) => result = r),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'secreta1');
    await tester.tap(find.text('Entrar'));
    // Deja correr la peticion falsa, el rebuild y el pop.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(backend.request('POST', '/api/proxy/auth/login'), isNotNull);
    expect(result, isTrue);
  });
}

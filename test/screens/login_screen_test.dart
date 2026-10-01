import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/controllers/auth_controller.dart';
import 'package:kronio_app/screens/login_screen.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:kronio_app/widgets/auth_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_backend.dart';

Future<Widget> _appWith(FakeAuthBackend backend) async {
  final service = await AuthService.create(
    client: backend.client,
    baseUrl: authTestBaseUrl,
  );
  final controller = AuthController(service: service);
  return AuthScope(
    auth: controller,
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('valida el correo sin gastar una peticion', (tester) async {
    final backend = FakeAuthBackend();
    await tester.pumpWidget(await _appWith(backend));

    await tester.enterText(find.byType(TextFormField).first, 'no-es-correo');
    await tester.enterText(find.byType(TextFormField).last, 'secreta1');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Ese correo no parece valido'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('rechaza una contrasena corta', (tester) async {
    final backend = FakeAuthBackend();
    await tester.pumpWidget(await _appWith(backend));

    await tester.enterText(find.byType(TextFormField).first, 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Minimo 6 caracteres'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('muestra el error cuando las credenciales son malas', (
    tester,
  ) async {
    final backend = FakeAuthBackend(loginStatus: 401);
    await tester.pumpWidget(await _appWith(backend));

    await tester.enterText(find.byType(TextFormField).first, 'ana@test.com');
    await tester.enterText(find.byType(TextFormField).last, 'secreta1');
    await tester.tap(find.text('Entrar'));
    // Deja correr el request falso y el rebuild.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Correo o contrasena incorrectos.'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/controllers/auth_controller.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_backend.dart';

Future<AuthController> _controllerFor(FakeAuthBackend backend) async {
  final service = await AuthService.create(
    client: backend.client,
    baseUrl: authTestBaseUrl,
  );
  return AuthController(service: service);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('arranca en unknown hasta restaurar', () async {
    final controller = await _controllerFor(FakeAuthBackend());
    expect(controller.status, AuthStatus.unknown);
    expect(controller.isAuthenticated, isFalse);
  });

  test('login exitoso deja la sesion y el usuario', () async {
    final controller = await _controllerFor(FakeAuthBackend());

    final ok = await controller.login(
      email: 'ana@test.com',
      password: 'secreta1',
    );

    expect(ok, isTrue);
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.email, 'ana@test.com');
    expect(controller.error, isNull);
    expect(controller.isBusy, isFalse);
  });

  test('login fallido guarda el mensaje y no autentica', () async {
    final controller = await _controllerFor(FakeAuthBackend(loginStatus: 401));

    final ok = await controller.login(email: 'ana@test.com', password: 'mala');

    expect(ok, isFalse);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.error, 'Correo o contrasena incorrectos.');
  });

  test('clearError borra el mensaje', () async {
    final controller = await _controllerFor(FakeAuthBackend(loginStatus: 401));
    await controller.login(email: 'ana@test.com', password: 'mala');
    expect(controller.error, isNotNull);

    controller.clearError();

    expect(controller.error, isNull);
  });

  test('restore autentica si hay sesion y el perfil responde', () async {
    final backend = FakeAuthBackend();
    final controller = await _controllerFor(backend);
    // restore solo consulta el perfil si hay una cookie de sesion.
    await controller.login(email: 'ana@test.com', password: 'secreta1');

    await controller.restore();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.email, 'ana@test.com');
  });

  test('restore sin sesion no hace ninguna peticion', () async {
    final backend = FakeAuthBackend();
    final controller = await _controllerFor(backend);

    await controller.restore();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(backend.requests, isEmpty);
  });

  test('restore con perfil 401 deja unauthenticated', () async {
    final backend = FakeAuthBackend(profileStatus: 401);
    final controller = await _controllerFor(backend);
    // Sin sesion restore ni llama al perfil, asi que se inicia sesion para
    // llegar al camino del 401.
    await controller.login(email: 'ana@test.com', password: 'secreta1');
    expect(controller.isAuthenticated, isTrue);

    await controller.restore();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.user, isNull);
  });

  test('logout limpia el usuario', () async {
    final controller = await _controllerFor(FakeAuthBackend());
    await controller.login(email: 'ana@test.com', password: 'secreta1');
    expect(controller.isAuthenticated, isTrue);

    await controller.logout();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.user, isNull);
    expect(controller.isBusy, isFalse);
  });
}

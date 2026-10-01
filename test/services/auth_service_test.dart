import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kronio_app/services/api_exception.dart';
import 'package:kronio_app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('login', () {
    test('guarda la sesion y devuelve el usuario', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      final user = await service.login(
        email: 'ana@test.com',
        password: 'secreta1',
      );

      expect(user.email, 'ana@test.com');
      expect(user.name, 'Ana Perez');
      // La cookie de sesion (httpOnly) queda en el jar.
      expect(service.api.cookieJar.valueOf('token'), 'jwt123');
      expect(service.api.cookieJar.valueOf('__Host-csrf-token'), 'csrf123');
    });

    test('consigue el CSRF antes del POST y lo manda como cabecera', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      await service.login(email: 'ana@test.com', password: 'secreta1');

      // El primer request es el GET que emite la cookie CSRF.
      expect(backend.requests.first.method, 'GET');
      expect(backend.requests.first.url.path, '/api/proxy/auth');
      // Y el POST la reenvia.
      final login = backend.request('POST', '/api/proxy/auth/login');
      expect(headerOf(login, 'X-CSRF-Token'), 'csrf123');
    });

    test('manda email y password en el cuerpo', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      await service.login(email: '  ana@test.com ', password: 'secreta1');

      final body = jsonDecode(
        backend.request('POST', '/api/proxy/auth/login').body,
      ) as Map<String, dynamic>;
      expect(body, {'email': 'ana@test.com', 'password': 'secreta1'});
    });

    test('traduce el 401 a un mensaje entendible', () async {
      final backend = FakeAuthBackend(loginStatus: 401);
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      await expectLater(
        service.login(email: 'ana@test.com', password: 'mala'),
        throwsA(
          isA<ApiClientException>().having(
            (e) => e.message,
            'message',
            'Correo o contrasena incorrectos.',
          ),
        ),
      );
    });

    test('no reintenta con refresh cuando el login falla', () async {
      final backend = FakeAuthBackend(loginStatus: 401);
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      try {
        await service.login(email: 'ana@test.com', password: 'mala');
      } on ApiException {
        // Esperado: credenciales invalidas.
      }

      final refreshes = backend.requests
          .where((r) => r.url.path == '/api/proxy/auth/refresh')
          .length;
      expect(refreshes, 0);
    });
  });

  group('register', () {
    test('manda name, email y password', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      await service.register(
        name: 'Ana Perez',
        email: 'ana@test.com',
        password: 'secreta1',
      );

      final body = jsonDecode(
        backend.request('POST', '/api/proxy/auth/register').body,
      ) as Map<String, dynamic>;
      expect(body, {
        'name': 'Ana Perez',
        'email': 'ana@test.com',
        'password': 'secreta1',
      });
    });

    // El backend no emite cookie de sesion al registrar, solo el token CSRF.
    // Sin este login extra la app "entra" pero al reiniciar pierde la sesion,
    // porque la cookie `token` nunca existio.
    test('entra despues del alta porque el registro no deja cookie', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      final user = await service.register(
        name: 'Ana Perez',
        email: 'ana@test.com',
        password: 'secreta1',
      );

      // El usuario sale de la respuesta del login, que si trae `role`.
      expect(user.email, 'ana@test.com');
      expect(user.role, 'USER');

      final loginBody = jsonDecode(
        backend.request('POST', '/api/proxy/auth/login').body,
      ) as Map<String, dynamic>;
      expect(loginBody, {'email': 'ana@test.com', 'password': 'secreta1'});

      // Y la cookie de sesion quedo guardada.
      expect(service.api.cookieJar.valueOf('token'), 'jwt123');
      expect(service.hasSession, isTrue);
    });

    test('traduce el 409 a "ya existe una cuenta"', () async {
      final backend = FakeAuthBackend(registerStatus: 409);
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      await expectLater(
        service.register(
          name: 'Ana Perez',
          email: 'ana@test.com',
          password: 'secreta1',
        ),
        throwsA(
          isA<ApiClientException>().having(
            (e) => e.message,
            'message',
            'Ya existe una cuenta con ese correo.',
          ),
        ),
      );
    });
  });

  group('sesion', () {
    test('fetchProfile devuelve null si no hay sesion (401)', () async {
      final backend = FakeAuthBackend(profileStatus: 401);
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );

      expect(await service.fetchProfile(), isNull);
    });

    test('refresca la sesion y reintenta el perfil tras un 401', () async {
      var refreshed = false;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/proxy/auth':
            return jsonResponse(
              {'message': 'ok'},
              headers: {'set-cookie': csrfCookie},
            );
          case 'POST /api/proxy/auth/refresh':
            refreshed = true;
            return jsonResponse(
              {'ok': true},
              headers: {'set-cookie': sessionCookie},
            );
          case 'GET /api/proxy/auth/profile':
            if (!refreshed) {
              return jsonResponse({
                'statusCode': 401,
                'message': 'expiro',
              }, status: 401);
            }
            return jsonResponse({'user': fakeUserJson});
        }
        return jsonResponse({'statusCode': 404}, status: 404);
      });

      final service = await AuthService.create(
        client: client,
        baseUrl: authTestBaseUrl,
      );
      final user = await service.fetchProfile();

      expect(user?.email, 'ana@test.com');
      expect(refreshed, isTrue);
      // El perfil se pidio dos veces: la que fallo y la reintentada.
      expect(
        requests.where((r) => r.url.path == '/api/proxy/auth/profile').length,
        2,
      );
    });

    test('logout limpia las cookies, tambien en disco', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );
      await service.login(email: 'ana@test.com', password: 'secreta1');
      expect(service.api.cookieJar.isEmpty, isFalse);

      await service.logout();

      expect(service.api.cookieJar.isEmpty, isTrue);
      // Otra instancia no encuentra nada guardado.
      final restored = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );
      expect(restored.api.cookieJar.isEmpty, isTrue);
    });
  });

  group('persistencia', () {
    test('hasSession distingue una sesion de solo-CSRF', () async {
      final backend = FakeAuthBackend();
      final service = await AuthService.create(
        client: backend.client,
        baseUrl: authTestBaseUrl,
      );
      expect(service.hasSession, isFalse);

      await service.login(email: 'ana@test.com', password: 'secreta1');

      expect(service.hasSession, isTrue);
    });

    test('la sesion sobrevive a un reinicio de la app', () async {
      final first = FakeAuthBackend();
      final serviceA = await AuthService.create(
        client: first.client,
        baseUrl: authTestBaseUrl,
      );
      await serviceA.login(email: 'ana@test.com', password: 'secreta1');

      // Segunda instancia como si se hubiera reabierto la app.
      final second = FakeAuthBackend();
      final serviceB = await AuthService.create(
        client: second.client,
        baseUrl: authTestBaseUrl,
      );

      expect(serviceB.api.cookieJar.valueOf('token'), 'jwt123');
      expect(serviceB.api.cookieJar.valueOf('__Host-csrf-token'), 'csrf123');
    });
  });
}

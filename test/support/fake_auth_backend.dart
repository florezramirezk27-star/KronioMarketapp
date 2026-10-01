import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Backend de auth falso, en memoria, para los tests.
///
/// Reproduce el contrato real verificado contra el backend de produccion:
///  - `GET /auth` emite la cookie CSRF (`__Host-csrf-token`),
///  - `POST /auth/login` responde `201` con `{user}` y emite la cookie de
///    sesion (`token`, un JWT de una hora),
///  - `POST /auth/register` responde `201` con la cuenta **plana** y **sin**
///    cookie de sesion: registrar no deja al usuario con sesion,
///  - `GET /auth/profile` responde plano `{id, email, name, role}` o 401,
///  - `POST /auth/refresh` renueva la sesion,
///  - `POST /auth/logout` cierra la sesion.

/// Base URL de mentira que usan los tests de auth.
const authTestBaseUrl = 'https://api.test/api/proxy';

/// Usuario que devuelve el backend falso.
const fakeUserJson = <String, dynamic>{
  'id': 'u1',
  'name': 'Ana Perez',
  'email': 'ana@test.com',
  'role': 'USER',
};

const csrfCookie = '__Host-csrf-token=csrf123; Path=/; Secure; SameSite=Lax';

/// Cookie de sesion real: un JWT en una cookie llamada `token`, de una hora.
const sessionCookie =
    'token=jwt123; Max-Age=3600; Path=/; HttpOnly; Secure; SameSite=Lax';

/// Respuesta JSON con las cabeceras correctas.
http.Response jsonResponse(
  Object body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

/// Valor de una cabecera, sin importar mayusculas.
String? headerOf(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

class FakeAuthBackend {
  FakeAuthBackend({
    this.user = fakeUserJson,
    this.loginStatus = 201,
    this.registerStatus = 201,
    this.profileStatus = 200,
    this.refreshStatus = 200,
    this.logoutStatus = 200,
  });

  final Map<String, dynamic> user;
  final int loginStatus;
  final int registerStatus;
  final int profileStatus;
  final int refreshStatus;
  final int logoutStatus;

  /// Todas las peticiones recibidas, en orden.
  final List<http.Request> requests = [];

  /// Cuantas veces se pidio el perfil.
  int profileCalls = 0;

  MockClient get client => MockClient((request) async {
    requests.add(request);
    switch ('${request.method} ${request.url.path}') {
      case 'GET /api/proxy/auth':
        return jsonResponse(
          {'message': 'Auth funcionando'},
          headers: {'set-cookie': csrfCookie},
        );
      case 'POST /api/proxy/auth/login':
        if (loginStatus < 200 || loginStatus >= 300) {
          return jsonResponse({
            'statusCode': loginStatus,
            'message': 'Invalid credentials',
          }, status: loginStatus);
        }
        return jsonResponse(
          {'user': user},
          status: loginStatus,
          headers: {'set-cookie': sessionCookie},
        );
      case 'POST /api/proxy/auth/register':
        if (registerStatus < 200 || registerStatus >= 300) {
          return jsonResponse({
            'statusCode': registerStatus,
            'message': 'Conflict',
          }, status: registerStatus);
        }
        // El backend responde 201 con la cuenta plana (sin envoltorio `user` ni
        // `role`) y SIN cookie de sesion: el alta no deja al usuario con sesion,
        // hay que entrar aparte. Asi lo reproduce este doble para que un test
        // que solo mire la respuesta del registro no pase por alto que la app
        // tiene que hacer login despues.
        return jsonResponse({
          'id': user['id'],
          'name': user['name'],
          'email': user['email'],
        }, status: registerStatus);
      case 'GET /api/proxy/auth/profile':
        profileCalls++;
        if (profileStatus < 200 || profileStatus >= 300) {
          return jsonResponse({
            'statusCode': profileStatus,
            'message': 'no',
          }, status: profileStatus);
        }
        // El perfil real viene plano, sin envoltorio `user`.
        return jsonResponse(user);
      case 'POST /api/proxy/auth/refresh':
        if (refreshStatus != 200) {
          return jsonResponse({
            'statusCode': refreshStatus,
            'message': 'no',
          }, status: refreshStatus);
        }
        return jsonResponse(
          {'ok': true},
          headers: {'set-cookie': sessionCookie},
        );
      case 'POST /api/proxy/auth/logout':
        if (logoutStatus != 200) {
          return jsonResponse({
            'statusCode': logoutStatus,
            'message': 'no',
          }, status: logoutStatus);
        }
        return jsonResponse({'message': 'ok'});
    }
    return jsonResponse({
      'statusCode': 404,
      'message': 'not found',
    }, status: 404);
  });

  /// La unica peticion a un metodo/ruta dados. Falla si no hay exactamente una.
  http.Request request(String method, String path) {
    final matches = requests
        .where((r) => r.method == method && r.url.path == path)
        .toList();
    if (matches.length != 1) {
      throw StateError(
        'Se esperaba 1 $method $path, se encontraron ${matches.length}',
      );
    }
    return matches.single;
  }
}

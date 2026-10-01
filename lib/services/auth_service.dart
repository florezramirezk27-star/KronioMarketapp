import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_exception.dart';
import 'api_service.dart';
import 'cookie_jar.dart';

/// Sesion del usuario contra el backend.
///
/// La auth del backend es por **cookie httpOnly mas token CSRF**, no por bearer:
/// el frontend web usa `credentials: "include"` y manda `X-CSRF-Token` en los
/// metodos que mutan. En el navegador el cookie jar lo maneja el browser; en
/// movil lo hace este servicio.
///
/// Es el duenio de la sesion: guarda y restaura el [CookieJar] en disco y le da
/// a [ApiService] los dos ganchos que necesita:
///  - `onCookiesChanged`, para persistir cada cookie nueva,
///  - `onUnauthorized`, para renovar la sesion y reintentar solo.
///
/// Se construye con [AuthService.create] porque restaurar la sesion de disco es
/// asincrono.
class AuthService {
  AuthService._(this.api);

  /// Cliente de red ya cableado con la sesion.
  final ApiService api;

  /// Clave donde se serializa el cookie jar.
  static const sessionKey = 'kronio_session_v1';

  static Future<AuthService> create({
    http.Client? client,
    String? baseUrl,
  }) async {
    final jar = await _loadJar();

    // El closure necesita el servicio ya construido para persistir y refrescar,
    // asi que se asigna despues de crear el ApiService. Para cuando cualquiera
    // de los dos ganchos se ejecute, `service` ya esta asignado.
    late final AuthService service;
    final api = ApiService(
      client: client,
      baseUrl: baseUrl,
      cookieJar: jar,
      onCookiesChanged: () => service._persistCookies(),
      onUnauthorized: () => service.refresh(),
    );
    service = AuthService._(api);
    return service;
  }

  /// `true` si hay una cookie que no es la de CSRF.
  ///
  /// Sirve para no pedir el perfil en un arranque sin sesion: sin esto, cada
  /// apertura de la app dispararia un perfil (401), un GET para el CSRF y un
  /// refresh, los tres al pedo.
  bool get hasSession {
    for (final cookie in api.cookieJar.cookies) {
      if (!ApiService.csrfCookieNames.contains(cookie.name)) return true;
    }
    return false;
  }

  // ------------------------------------------------------------------- Cuenta

  /// Inicia sesion. Traduce el 401 a un mensaje entendible para el usuario.
  Future<User> login({required String email, required String password}) async {
    final body = await _guarded(
      () => api.postJson(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        allowRefresh: false,
      ),
      onUnauthorized: 'Correo o contrasena incorrectos.',
    );
    return _parseUser(body);
  }

  /// Crea la cuenta y deja la sesion iniciada.
  ///
  /// Ojo: el backend **no** emite la cookie de sesion al registrarse, solo el
  /// token CSRF. `POST /auth/register` responde `201` con la cuenta plana
  /// (`{id, name, email}`, sin `role`) y ahi sigue sin haber sesion. Por eso
  /// despues del alta se entra con las mismas credenciales: es el unico modo de
  /// conseguir la cookie `token`.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _guarded(
      () => api.postJson(
        '/auth/register',
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
        allowRefresh: false,
      ),
      onUnauthorized: 'No pudimos crear la cuenta con esos datos.',
      onConflict: 'Ya existe una cuenta con ese correo.',
    );

    return login(email: email, password: password);
  }

  /// Perfil de la sesion actual, o `null` si no hay sesion valida.
  ///
  /// Un 401 aca no es un error para mostrar: simplemente no hay sesion. Si la
  /// cookie expiro, [ApiService] intenta refrescar antes y solo queda en `null`
  /// cuando el refresh tambien falla.
  Future<User?> fetchProfile() async {
    try {
      final body = await api.getJson('/auth/profile');
      return _parseUser(body);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Renueva la sesion. Devuelve `true` si quedo renovada.
  ///
  /// Lo llama [ApiService] solo tras un 401, por eso no propaga el error: un
  /// `false` alcanza para que la peticion original termine fallando con 401.
  Future<bool> refresh() async {
    try {
      await api.postJson('/auth/refresh', body: const {}, allowRefresh: false);
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Cierra la sesion en el servidor y borra las cookies locales.
  Future<void> logout() async {
    try {
      await api.postJson('/auth/logout', body: const {}, allowRefresh: false);
    } on ApiException {
      // Aunque el servidor falle, la sesion local se limpia igual.
    }
    api.cookieJar.clear();
    await _persistCookies();
  }

  void dispose() => api.dispose();

  // ------------------------------------------------------------------ Interno

  static Future<CookieJar> _loadJar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(sessionKey);
      if (raw == null || raw.isEmpty) return CookieJar();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return CookieJar.fromJson(decoded);
    } catch (_) {
      // Sesion corrupta: se arranca sin sesion en vez de tumbar la app.
    }
    return CookieJar();
  }

  Future<void> _persistCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (api.cookieJar.isEmpty) {
        await prefs.remove(sessionKey);
      } else {
        await prefs.setString(sessionKey, jsonEncode(api.cookieJar.toJson()));
      }
    } catch (_) {
      // No poder persistir no debe impedir usar la sesion en memoria.
    }
  }

  Future<dynamic> _guarded(
    Future<dynamic> Function() action, {
    String? onUnauthorized,
    String? onConflict,
  }) async {
    try {
      return await action();
    } on ApiException catch (error) {
      if (error.statusCode == 401 && onUnauthorized != null) {
        throw ApiClientException(
          onUnauthorized,
          statusCode: 401,
          uri: error.uri,
        );
      }
      if (error.statusCode == 409 && onConflict != null) {
        throw ApiClientException(onConflict, statusCode: 409, uri: error.uri);
      }
      rethrow;
    }
  }

  User _parseUser(dynamic body) {
    if (body is Map<String, dynamic>) {
      final rawUser = body['user'];
      final data = rawUser is Map<String, dynamic> ? rawUser : body;
      final user = User.fromJson(data);
      if (user.id.isEmpty && user.email.isEmpty) {
        throw const ApiFormatException(
          'La respuesta de la cuenta no tiene el formato esperado.',
        );
      }
      return user;
    }
    throw const ApiFormatException(
      'La respuesta de la cuenta no tiene el formato esperado.',
    );
  }
}

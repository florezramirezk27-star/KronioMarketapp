import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

/// Estado de la sesion.
enum AuthStatus {
  /// Todavia no se consulto el perfil; la pantalla de cuenta muestra un spinner.
  unknown,

  /// No hay sesion.
  unauthenticated,

  /// Hay usuario cargado.
  authenticated,
}

/// Controla el ciclo de vida de la sesion y notifica a la UI.
///
/// Reemplaza al `FutureBuilder`: el estado de auth lo consultan varias
/// pantallas (perfil, y mas adelante checkout), y hace falta un punto unico que
/// sepa si hay usuario y que avise cuando cambia.
class AuthController extends ChangeNotifier {
  AuthController({required this.service});

  final AuthService service;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _busy = false;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isUnknown => _status == AuthStatus.unknown;

  /// `true` mientras hay un login/registro/logout en curso.
  bool get isBusy => _busy;

  /// Ultimo error de la ultima operacion, listo para mostrar.
  String? get error => _error;

  /// Restaura la sesion guardada en disco.
  ///
  /// Se llama una vez al arrancar la app. No bloquea el splash: la app abre y
  /// el perfil resuelve su estado cuando esta llamada termina.
  Future<void> restore() async {
    if (!service.hasSession) {
      _apply(null);
      return;
    }
    try {
      final user = await service.fetchProfile();
      _apply(user);
    } on ApiException {
      _apply(null);
    } catch (_) {
      _apply(null);
    }
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() => service.login(email: email, password: password));
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => service.register(name: name, email: email, password: password),
    );
  }

  Future<void> logout() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await service.logout();
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _busy = false;
      notifyListeners();
    }
  }

  /// Limpia el error para que no se arrastre a otra pantalla.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<User> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final user = await action();
      _user = user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = 'Ocurrio un problema inesperado. Intenta de nuevo.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _apply(User? user) {
    _user = user;
    _status = user == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }
}

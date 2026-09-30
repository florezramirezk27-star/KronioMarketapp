import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Errores de la capa de red, tipados.
///
/// Antes se lanzaba `Exception('Error del servidor: ${response.statusCode}')`
/// y la UI mostraba `snapshot.error` crudo, o sea que un 404 de "producto no
/// encontrado", un 500 del servidor y un corte de internet se veian igual para
/// el usuario. Con estas clases cada pantalla puede decidir que texto mostrar y
/// si tiene sentido ofrecer "Reintentar".
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.uri});

  /// Mensaje listo para mostrar al usuario final, en espanol.
  final String message;

  /// Codigo HTTP, cuando la falla viene de una respuesta del servidor.
  final int? statusCode;

  /// URL que se estaba consultando, para diagnostico.
  final Uri? uri;

  /// Si tiene sentido reintentar la misma peticion.
  ///
  /// Un 404 no: el recurso no existe. Un 500 o un corte de red si.
  bool get canRetry =>
      this is! ApiNotFoundException && this is! ApiFormatException;

  @override
  String toString() =>
      '$runtimeType: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${uri != null ? ' [${uri!.path}]' : ''}';
}

/// El dispositivo no tiene conectividad, o el host no resuelve.
class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.message, {super.uri});
}

/// La peticion supero `AppConfig.requestTimeout`.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException(super.message, {super.uri});
}

/// El servidor respondio 5xx. El problema es del backend.
class ApiServerException extends ApiException {
  const ApiServerException(super.message, {super.statusCode, super.uri});
}

/// El servidor respondio 4xx (distinto de 404). El problema es la peticion.
class ApiClientException extends ApiException {
  const ApiClientException(super.message, {super.statusCode, super.uri});
}

/// El recurso pedido no existe (404).
class ApiNotFoundException extends ApiException {
  const ApiNotFoundException(super.message, {super.statusCode, super.uri});
}

/// La respuesta llego pero no tiene la forma que esperamos.
///
/// Suele indicar un cambio en el contrato del backend o un proxy devolviendo
/// HTML de error en lugar de JSON. No tiene sentido reintentar.
class ApiFormatException extends ApiException {
  const ApiFormatException(super.message, {super.statusCode, super.uri});
}

/// Traduce una excepcion de `http`/`dart:io` a un [ApiException] con mensaje
/// util para el usuario.
ApiException mapNetworkError(Object error, {Uri? uri}) {
  if (error is ApiException) return error;

  if (error is TimeoutException) {
    return ApiTimeoutException(
      'El servidor tardo demasiado en responder. Intenta de nuevo.',
      uri: uri,
    );
  }

  // `http` sobre Android/iOS lanza `SocketException`; en web lanza
  // `http.ClientException` envolviendo un error de XMLHttpRequest.
  if (error is SocketException || error is http.ClientException) {
    return const ApiNetworkException(
      'No pudimos conectarnos a internet. Revisa tu conexion.',
    );
  }

  if (error is HandshakeException) {
    return const ApiNetworkException(
      'No se pudo establecer una conexion segura con el servidor.',
    );
  }

  return ApiNetworkException(
    'Ocurrio un problema inesperado al conectar. Intenta de nuevo.',
    uri: uri,
  );
}

/// Traduce un codigo HTTP a [ApiException].
ApiException mapStatusCode(int statusCode, {Uri? uri, String? body}) {
  final detail = _extractServerMessage(body);

  final message = switch (statusCode) {
    400 => 'La peticion no es valida.${_suffix(detail)}',
    401 => 'Tu sesion expiro. Volve a iniciar sesion.',
    403 => 'No tenes permiso para ver este contenido.',
    404 => 'No encontramos lo que estabas buscando.',
    408 => 'El servidor tardo demasiado en responder. Intenta de nuevo.',
    429 => 'Demasiadas solicitudes. Espera un momento e intenta de nuevo.',
    >= 500 => 'El servidor esta teniendo problemas. Intenta mas tarde.',
    _ => 'No pudimos completar la operacion. Intenta de nuevo.',
  };

  return switch (statusCode) {
    404 => ApiNotFoundException(message, statusCode: statusCode, uri: uri),
    >= 500 => ApiServerException(message, statusCode: statusCode, uri: uri),
    _ => ApiClientException(message, statusCode: statusCode, uri: uri),
  };
}

/// Busca un mensaje util en el cuerpo de la respuesta.
///
/// NestJS suele devolver `{"message": "..."}` o `{"error": "..."}`, a veces
/// como arreglo. Si no hay nada reconocible se devuelve `null`.
String? _extractServerMessage(String? body) {
  if (body == null || body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['error'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
    }
  } on FormatException {
    // Cuerpo no-JSON (por ejemplo HTML de un proxy). Se ignora.
  }
  return null;
}

String _suffix(String? detail) => detail == null ? '' : ' ($detail)';

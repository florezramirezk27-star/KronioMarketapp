/// Cookie jar propio, sin dependencias, porque `package:http` no persiste
/// cookies entre peticiones.
///
/// La auth del backend es por **cookie httpOnly**, no por bearer token: el
/// frontend web usa `credentials: "include"` y protege los POST con un token
/// CSRF que tambien viaja en cookie. En el navegador el jar lo pone el browser;
/// en movil hay que hacerlo a mano.
///
/// Decisiones:
///  - Las cookies se indexan por nombre. La app habla con un solo host, asi que
///    no hace falta el modelo completo de dominio/path del RFC 6265; igual se
///    respetan `Secure`, `Path` y la expiracion, que son los que importan.
///  - Se serializa a JSON para persistir la sesion entre arranques.
///  - No usa `dart:io` a proposito: la app tambien compila para web, donde
///    `dart:io` no existe. Por eso el parseo de fechas HTTP es propio.
library;

/// Una cookie ya parseada.
class StoredCookie {
  const StoredCookie({
    required this.name,
    required this.value,
    this.path = '/',
    this.secure = false,
    this.httpOnly = false,
    this.expires,
  });

  final String name;
  final String value;
  final String path;
  final bool secure;
  final bool httpOnly;

  /// Momento en que deja de ser valida. `null` = cookie de sesion.
  final DateTime? expires;

  bool get isExpired =>
      expires != null && !expires!.isAfter(DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'path': path,
    'secure': secure,
    'httpOnly': httpOnly,
    'expires': expires?.toUtc().toIso8601String(),
  };

  factory StoredCookie.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expires'];
    return StoredCookie(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      path: json['path']?.toString() ?? '/',
      secure: json['secure'] == true,
      httpOnly: json['httpOnly'] == true,
      expires: rawExpires is String
          ? DateTime.tryParse(rawExpires)?.toUtc()
          : null,
    );
  }
}

class CookieJar {
  CookieJar();

  factory CookieJar.fromJson(Map<String, dynamic> json) {
    final jar = CookieJar();
    final raw = json['cookies'];
    if (raw is List) {
      for (final entry in raw.whereType<Map<String, dynamic>>()) {
        final cookie = StoredCookie.fromJson(entry);
        if (cookie.name.isNotEmpty) jar._cookies[cookie.name] = cookie;
      }
    }
    return jar;
  }

  final Map<String, StoredCookie> _cookies = {};

  bool get isEmpty => _cookies.isEmpty;

  Iterable<StoredCookie> get cookies => _cookies.values;

  /// Guarda las cookies de una respuesta.
  ///
  /// `requestUri` es la URL que se consulto, para saber si la cookie exige
  /// `Secure`.
  void absorb(Uri requestUri, Iterable<String> setCookieHeaders) {
    for (final header in setCookieHeaders) {
      for (final raw in splitSetCookieHeader(header)) {
        final cookie = _parseOne(raw);
        if (cookie == null) continue;
        // Una cookie que llega ya vencida (Max-Age=0 o Expires en el pasado) es
        // la forma que tiene el servidor de borrarla.
        if (cookie.isExpired) {
          _cookies.remove(cookie.name);
        } else {
          _cookies[cookie.name] = cookie;
        }
      }
    }
  }

  /// Valor de una cookie por nombre, o `null` si no existe o ya expiro.
  String? valueOf(String name) {
    final cookie = _cookies[name];
    if (cookie == null || cookie.isExpired) return null;
    return cookie.value;
  }

  /// Header `Cookie` para una URL, o `null` si no hay nada que mandar.
  String? headerFor(Uri uri) {
    final parts = <String>[];
    for (final cookie in _cookies.values) {
      if (cookie.isExpired) continue;
      if (cookie.secure && uri.scheme != 'https') continue;
      if (!_pathMatches(uri.path, cookie.path)) continue;
      parts.add('${cookie.name}=${cookie.value}');
    }
    return parts.isEmpty ? null : parts.join('; ');
  }

  void clear() => _cookies.clear();

  Map<String, dynamic> toJson() => {
    'cookies': _cookies.values.map((c) => c.toJson()).toList(),
  };

  StoredCookie? _parseOne(String raw) {
    final segments = raw.split(';');
    final first = segments.first.trim();
    final separator = first.indexOf('=');
    if (separator <= 0) return null;

    final name = first.substring(0, separator).trim();
    final value = first.substring(separator + 1).trim();
    if (name.isEmpty) return null;

    var path = '/';
    var secure = false;
    var httpOnly = false;
    DateTime? expires;

    for (final segment in segments.skip(1)) {
      final part = segment.trim();
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      final key = (eq == -1 ? part : part.substring(0, eq))
          .trim()
          .toLowerCase();
      final attrValue = eq == -1 ? '' : part.substring(eq + 1).trim();

      switch (key) {
        case 'path':
          if (attrValue.isNotEmpty) path = attrValue;
        case 'secure':
          secure = true;
        case 'httponly':
          httpOnly = true;
        case 'max-age':
          final seconds = int.tryParse(attrValue);
          if (seconds != null) {
            expires = DateTime.now().toUtc().add(Duration(seconds: seconds));
          }
        case 'expires':
          // `Max-Age` gana sobre `Expires` segun el RFC 6265, pero solo si ya
          // se leyo; por eso no se pisa una fecha calculada por Max-Age.
          final parsed = parseHttpDate(attrValue);
          if (parsed != null && expires == null) expires = parsed.toUtc();
      }
    }

    return StoredCookie(
      name: name,
      value: value,
      path: path,
      secure: secure,
      httpOnly: httpOnly,
      expires: expires,
    );
  }

  /// El prefijo de path del RFC 6265: `/foo` cubre `/foo` y `/foo/bar`, pero no
  /// `/foobar`.
  static bool _pathMatches(String requestPath, String cookiePath) {
    if (cookiePath == '/' || cookiePath.isEmpty) return true;
    if (!requestPath.startsWith(cookiePath)) return false;
    if (requestPath.length == cookiePath.length) return true;
    return requestPath[cookiePath.length] == '/';
  }
}

/// Separa un header `Set-Cookie` que puede traer varias cookies pegadas con
/// `", "`.
///
/// Es un problema real: `package:http` colapsa los headers repetidos en uno
/// solo unido por comas, y no se puede partir por coma sin mas porque `Expires`
/// tambien lleva una: `Expires=Wed, 21 Oct 2015 07:28:00 GMT`.
///
/// La heuristica es cortar solo en la coma que va seguida de `nombre=`, que es
/// como empieza una cookie. En `Expires` la coma va seguida de ` 21`, un numero,
/// asi que no matchea.
List<String> splitSetCookieHeader(String header) {
  if (header.isEmpty) return const [];
  return header
      .split(RegExp(r',(?=\s*[A-Za-z0-9_\-!#$%&\x27*+.^`|~]+=)'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

/// Parsea una fecha HTTP (RFC 1123), el formato que usan los servidores:
/// `Wed, 21 Oct 2015 07:28:00 GMT`.
///
/// No se usa `HttpDate.parse` de `dart:io` porque `dart:io` no existe en web.
/// Tambien acepta ISO-8601 por si algun proxy la manda asi.
DateTime? parseHttpDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  final match = RegExp(
    r'^[A-Za-z]{3},?\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s*(GMT|UTC)?$',
  ).firstMatch(value);
  if (match == null) return null;

  const months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final month = months[match.group(2)!.toLowerCase()];
  if (month == null) return null;

  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}

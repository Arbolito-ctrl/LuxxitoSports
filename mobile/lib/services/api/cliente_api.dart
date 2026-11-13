import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sesion_api.dart';

/// Error que devuelve la API (o un problema de red), listo para mostrar al usuario.
///
/// - [statusCode]: código HTTP (0 si no hubo respuesta, por ejemplo sin internet).
/// - [code]: código de la API, como CONFLICT o FORBIDDEN.
/// - [message]: mensaje en español que la app muestra tal cual.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => '[$statusCode $code] $message';
}

/// Cliente HTTP común para todas las llamadas a la API propia (backend en Render).
///
/// Centraliza lo que antes se repetía en cada método:
/// - la URL base y el tiempo máximo de espera,
/// - el encabezado Authorization con el token de la sesión,
/// - la conversión de la respuesta JSON y de los errores a [ApiException].
///
/// La app habla SOLO con la API propia: las reglas de negocio viven en el
/// servidor. Ya no existe el antiguo modo "Supabase directo".
class ClienteApi {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // El APK del taller usa la API propia incluso en Wi-Fi/datos móviles.
  // Desarrollo local: --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
  static String _baseUrl = _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : 'https://luxxito-sports-api.onrender.com/api';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
  }

  /// La instancia gratuita de Render puede tardar en "despertar": se espera hasta 60 s.
  static const Duration timeout = Duration(seconds: 60);

  /// Subir imágenes (fotos de canchas y vouchers) tiene su propio límite.
  static const Duration timeoutSubida = Duration(seconds: 30);

  static Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final token = SesionApi.currentSession?.token ?? '';
    if (token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  static Uri _uri(String ruta, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$ruta');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  // ---------------------------------------------------------------------------
  // Verbos HTTP. Todos devuelven el cuerpo JSON de la respuesta ({ ok, data, ... }).
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> get(String ruta, {Map<String, String>? query}) =>
      _enviar(() => http.get(_uri(ruta, query), headers: _headers), timeout);

  static Future<Map<String, dynamic>> post(
    String ruta, {
    Object? body,
    Duration tiempo = timeout,
  }) =>
      _enviar(
        () => http.post(_uri(ruta), headers: _headers, body: body == null ? null : jsonEncode(body)),
        tiempo,
      );

  static Future<Map<String, dynamic>> put(String ruta, {Object? body}) => _enviar(
        () => http.put(_uri(ruta), headers: _headers, body: body == null ? null : jsonEncode(body)),
        timeout,
      );

  static Future<Map<String, dynamic>> patch(String ruta, {Object? body}) => _enviar(
        () => http.patch(_uri(ruta), headers: _headers, body: body == null ? null : jsonEncode(body)),
        timeout,
      );

  static Future<Map<String, dynamic>> delete(String ruta) =>
      _enviar(() => http.delete(_uri(ruta), headers: _headers), timeout);

  /// Ejecuta la petición y traduce cualquier fallo a [ApiException]:
  /// - Si la API respondió con un error (409, 403...), se usa su mensaje.
  /// - Si no hubo respuesta (sin internet, tiempo agotado), se muestra un
  ///   mensaje de red. No hay plan B: la app nunca salta a otra fuente de datos.
  static Future<Map<String, dynamic>> _enviar(
    Future<http.Response> Function() peticion,
    Duration tiempo,
  ) async {
    final http.Response res;
    try {
      res = await peticion().timeout(tiempo);
    } catch (_) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'No se pudo conectar con la API. Comprueba tu red e inténtalo nuevamente.',
      );
    }
    return _decodificar(res);
  }

  /// Convierte la respuesta en un mapa; si el código HTTP no es 2xx, lanza el
  /// error con el `code` y el `message` que envía el backend.
  static Map<String, dynamic> _decodificar(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'INVALID_RESPONSE',
        message: 'Respuesta inesperada del servidor (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: body['code']?.toString() ?? 'HTTP_${response.statusCode}',
      message: body['message']?.toString() ?? 'Error al procesar la solicitud.',
    );
  }

  /// Validación en la app antes de llamar (el servidor vuelve a validar todo).
  static ApiException datoInvalido(String mensaje) =>
      ApiException(statusCode: 400, code: 'BAD_REQUEST', message: mensaje);
}

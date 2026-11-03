import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/luxxito_models.dart';

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

class ApiService {
  static String _baseUrl = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? 'http://10.0.2.2:3000/api'
      : 'http://localhost:3000/api';

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
  }

  static const Duration _timeout = Duration(seconds: 12);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  static Map<String, dynamic> _decodeResponse(http.Response response) {
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

  static Future<T> _safeCall<T>(Future<T> Function() fn) async {
    try {
      return await fn().timeout(_timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        code: 'TIMEOUT',
        message:
            'Tiempo de espera agotado al conectar con $_baseUrl. Verifica que el backend esté activo.',
      );
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message:
            'Error de conexión con la API ($_baseUrl). Verifica que el servidor esté ejecutándose.',
      );
    }
  }

  // 1. GET /api/health
  static Future<Map<String, dynamic>> checkHealth() {
    return _safeCall(() async {
      final res = await http.get(Uri.parse('$_baseUrl/health'), headers: _headers);
      return _decodeResponse(res);
    });
  }

  // 2. GET /api/complejos
  static Future<List<Complejo>> getComplejos({String? distrito}) {
    return _safeCall(() async {
      final uri = Uri.parse('$_baseUrl/complejos').replace(
        queryParameters: distrito != null && distrito.isNotEmpty
            ? {'distrito': distrito}
            : null,
      );
      final res = await http.get(uri, headers: _headers);
      final body = _decodeResponse(res);
      final list = body['data'] as List<dynamic>? ?? [];
      return list.map((e) => Complejo.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  // 3. GET /api/canchas
  static Future<List<Cancha>> getCanchas({
    int? complejoId,
    String? distrito,
    String? deporte,
  }) {
    return _safeCall(() async {
      final params = <String, String>{};
      if (complejoId != null) params['complejo_id'] = complejoId.toString();
      if (distrito != null && distrito.isNotEmpty) params['distrito'] = distrito;
      if (deporte != null && deporte.isNotEmpty) params['deporte'] = deporte;

      final uri = Uri.parse('$_baseUrl/canchas').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
      final res = await http.get(uri, headers: _headers);
      final body = _decodeResponse(res);
      final list = body['data'] as List<dynamic>? ?? [];
      return list.map((e) => Cancha.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  // 4. POST /api/canchas (CRUD Create)
  static Future<Cancha> crearCancha({
    required int complejoId,
    required String nombre,
    required String deporte,
    required String superficie,
    required bool techada,
    required double precioDiurno,
    required double precioNocturno,
  }) {
    return _safeCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/canchas'),
        headers: _headers,
        body: jsonEncode({
          'complejo_id': complejoId,
          'nombre': nombre,
          'deporte': deporte,
          'superficie': superficie,
          'techada': techada,
          'iluminacion': true,
          'precio_hora_diurno': precioDiurno,
          'precio_hora_nocturno': precioNocturno,
        }),
      );
      final body = _decodeResponse(res);
      return Cancha.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  // 5. GET /api/canchas/:id/disponibilidad (Lógica de negocio)
  static Future<DisponibilidadData> getDisponibilidad({
    required int canchaId,
    required String fecha,
    int? hora,
  }) {
    return _safeCall(() async {
      final params = <String, String>{'fecha': fecha};
      if (hora != null) params['hora'] = hora.toString();
      final uri = Uri.parse('$_baseUrl/canchas/$canchaId/disponibilidad')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers);
      final body = _decodeResponse(res);
      return DisponibilidadData.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  // 6. POST /api/reservas/cotizar (Lógica de negocio en servidor)
  static Future<Map<String, dynamic>> cotizarReserva({
    required int canchaId,
    required String fecha,
    required int horaInicio,
    required int horaFin,
    required List<Map<String, int>> extras,
  }) {
    return _safeCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/reservas/cotizar'),
        headers: _headers,
        body: jsonEncode({
          'cancha_id': canchaId,
          'fecha': fecha,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'extras': extras,
        }),
      );
      final body = _decodeResponse(res);
      return body['data'] as Map<String, dynamic>;
    });
  }

  // 7. POST /api/reservas (CRUD Create + Bloqueo 20 min)
  static Future<Reserva> crearReserva({
    required int canchaId,
    required String clienteNombre,
    required String clienteDni,
    required String clienteTelefono,
    required String clienteEmail,
    required String fecha,
    required int horaInicio,
    required int horaFin,
    String? notas,
    required List<Map<String, int>> extras,
  }) {
    return _safeCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/reservas'),
        headers: _headers,
        body: jsonEncode({
          'cancha_id': canchaId,
          'cliente_nombre': clienteNombre,
          'cliente_dni': clienteDni,
          'cliente_telefono': clienteTelefono,
          'cliente_email': clienteEmail,
          'fecha': fecha,
          'hora_inicio': horaInicio,
          'hora_fin': horaFin,
          'notas': notas,
          'extras': extras,
        }),
      );
      final body = _decodeResponse(res);
      return Reserva.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  // 8. GET /api/reservas (CRUD Read)
  static Future<List<Reserva>> getReservas({String? estado}) {
    return _safeCall(() async {
      final uri = Uri.parse('$_baseUrl/reservas').replace(
        queryParameters:
            estado != null && estado.isNotEmpty ? {'estado': estado} : null,
      );
      final res = await http.get(uri, headers: _headers);
      final body = _decodeResponse(res);
      final list = body['data'] as List<dynamic>? ?? [];
      return list.map((e) => Reserva.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  // 9. PUT /api/reservas/:id (CRUD Update)
  static Future<Reserva> actualizarReserva({
    required int reservaId,
    required String clienteTelefono,
    required String notas,
  }) {
    return _safeCall(() async {
      final res = await http.put(
        Uri.parse('$_baseUrl/reservas/$reservaId'),
        headers: _headers,
        body: jsonEncode({
          'cliente_telefono': clienteTelefono,
          'notas': notas,
        }),
      );
      final body = _decodeResponse(res);
      return Reserva.fromJson(body['data'] as Map<String, dynamic>);
    });
  }

  // 10. DELETE /api/reservas/:id (CRUD Delete)
  static Future<void> eliminarReserva(int reservaId) {
    return _safeCall(() async {
      final res = await http.delete(
        Uri.parse('$_baseUrl/reservas/$reservaId'),
        headers: _headers,
      );
      _decodeResponse(res);
    });
  }

  // 11. POST /api/reservas/:id/pagos (Registro de comprobante + QR)
  static Future<Reserva> registrarPago({
    required int reservaId,
    required String metodo,
    required String modalidad,
    required double monto,
    required String numeroOperacion,
    bool autoAprobar = true,
  }) {
    return _safeCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/reservas/$reservaId/pagos'),
        headers: _headers,
        body: jsonEncode({
          'metodo': metodo,
          'modalidad': modalidad,
          'monto': monto,
          'numero_operacion': numeroOperacion,
          'auto_aprobar': autoAprobar,
        }),
      );
      final body = _decodeResponse(res);
      final data = body['data'] as Map<String, dynamic>;
      return Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
    });
  }

  // 12. POST /api/reservas/:id/cancelar (Regla de negocio 24h)
  static Future<Map<String, dynamic>> cancelarReserva({
    required int reservaId,
    required String motivo,
  }) {
    return _safeCall(() async {
      final res = await http.post(
        Uri.parse('$_baseUrl/reservas/$reservaId/cancelar'),
        headers: _headers,
        body: jsonEncode({'motivo': motivo}),
      );
      final body = _decodeResponse(res);
      return body['data'] as Map<String, dynamic>;
    });
  }
}

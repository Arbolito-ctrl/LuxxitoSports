import 'dart:convert';

import '../../models/luxxito_models.dart';
import 'cliente_api.dart';

/// Catálogo: complejos, canchas, disponibilidad por día y gestión de canchas (ADMIN).
class CatalogoApi {
  /// GET /health — estado del servicio y de la base de datos.
  static Future<Map<String, dynamic>> checkHealth() => ClienteApi.get('/health');

  /// GET /complejos?distrito=
  static Future<List<Complejo>> getComplejos({String? distrito}) async {
    final body = await ClienteApi.get(
      '/complejos',
      query: {if (distrito != null && distrito.isNotEmpty) 'distrito': distrito},
    );
    final list = body['data'] as List<dynamic>? ?? [];
    return list.map((e) => Complejo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /canchas?complejo_id=&distrito=&deporte=
  static Future<List<Cancha>> getCanchas({
    int? complejoId,
    String? distrito,
    String? deporte,
  }) async {
    final body = await ClienteApi.get(
      '/canchas',
      query: {
        if (complejoId != null) 'complejo_id': complejoId.toString(),
        if (distrito != null && distrito.isNotEmpty) 'distrito': distrito,
        if (deporte != null && deporte.isNotEmpty) 'deporte': deporte,
      },
    );
    final list = body['data'] as List<dynamic>? ?? [];
    return list.map((e) => Cancha.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /canchas/:id/disponibilidad?fecha= — turnos del día y extras con su stock.
  static Future<DisponibilidadData> getDisponibilidad({
    required int canchaId,
    required String fecha,
    int? hora,
  }) async {
    final body = await ClienteApi.get(
      '/canchas/$canchaId/disponibilidad',
      query: {'fecha': fecha, if (hora != null) 'hora': hora.toString()},
    );
    return DisponibilidadData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// POST /canchas (ADMIN) — publica una cancha nueva.
  static Future<Cancha> crearCancha({
    required int complejoId,
    required String nombre,
    required String deporte,
    required String superficie,
    required bool techada,
    required double precioDiurno,
    required double precioNocturno,
  }) async {
    if (nombre.trim().length < 3) {
      throw ClienteApi.datoInvalido('El nombre de la cancha debe tener al menos 3 caracteres.');
    }
    if (precioDiurno <= 0 || precioNocturno < precioDiurno) {
      throw ClienteApi.datoInvalido(
        'El precio diurno debe ser > 0 y el precio nocturno >= al precio diurno.',
      );
    }

    final body = await ClienteApi.post(
      '/canchas',
      body: {
        'complejo_id': complejoId,
        'nombre': nombre,
        'deporte': deporte,
        'superficie': superficie,
        'techada': techada,
        'iluminacion': true,
        'precio_hora_diurno': precioDiurno,
        'precio_hora_nocturno': precioNocturno,
      },
    );
    return Cancha.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// POST /canchas/:id/imagen (ADMIN) — foto propia de la cancha (bucket público 'canchas').
  static Future<Cancha> subirImagenCancha({
    required int canchaId,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final body = await ClienteApi.post(
      '/canchas/$canchaId/imagen',
      body: {'mime_type': mimeType, 'contenido_base64': base64Encode(bytes)},
      tiempo: ClienteApi.timeoutSubida,
    );
    return Cancha.fromJson(body['data'] as Map<String, dynamic>);
  }
}

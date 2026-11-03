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
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _supaUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supaKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String _baseUrl = _envBaseUrl.isNotEmpty
      ? _envBaseUrl
      : (_supaUrl.isNotEmpty
          ? 'SUPABASE_CLOUD ($_supaUrl)'
          : ((!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              ? 'http://192.168.1.14:3000/api'
              : 'http://localhost:3000/api'));

  static String get baseUrl => _baseUrl;

  static bool get _useSupabaseDirect =>
      _supaUrl.isNotEmpty &&
      _supaKey.isNotEmpty &&
      (_baseUrl.startsWith('SUPABASE_CLOUD') || _baseUrl.contains('.supabase.co'));

  static UserSession? _currentSession;
  static UserSession? get currentSession => _currentSession;

  static void setSession(UserSession? session) {
    _currentSession = session;
  }

  static void logout() {
    _currentSession = null;
  }

  static void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
  }

  static void enableSupabaseCloudMode() {
    if (_supaUrl.isNotEmpty) {
      _baseUrl = 'SUPABASE_CLOUD ($_supaUrl)';
    }
  }

  static const Duration _timeout = Duration(seconds: 8);

  static Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_currentSession != null && _currentSession!.token.isNotEmpty) {
      map['Authorization'] = 'Bearer ${_currentSession!.token}';
    }
    return map;
  }

  static Map<String, String> get _supaHeaders => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'apikey': _supaKey,
        'Authorization': 'Bearer $_supaKey',
        'Prefer': 'return=representation',
      };

  static Future<dynamic> _supaGet(String pathAndQuery) async {
    final res = await http
        .get(Uri.parse('$_supaUrl/rest/v1/$pathAndQuery'), headers: _supaHeaders)
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: 'SUPABASE_ERROR',
      message: 'Error al consultar Supabase (${res.statusCode}).',
    );
  }

  static Future<dynamic> _supaPost(String table, Object body) async {
    final res = await http
        .post(
          Uri.parse('$_supaUrl/rest/v1/$table'),
          headers: _supaHeaders,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: 'SUPABASE_WRITE_ERROR',
      message: 'Error al guardar en Supabase (${res.statusCode}): ${res.body}',
    );
  }

  static Future<dynamic> _supaPatch(String query, Object body) async {
    final res = await http
        .patch(
          Uri.parse('$_supaUrl/rest/v1/$query'),
          headers: _supaHeaders,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: 'SUPABASE_UPDATE_ERROR',
      message: 'Error al actualizar en Supabase (${res.statusCode}).',
    );
  }

  static Future<void> _supaDelete(String query) async {
    final res = await http
        .delete(Uri.parse('$_supaUrl/rest/v1/$query'), headers: _supaHeaders)
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        statusCode: res.statusCode,
        code: 'SUPABASE_DELETE_ERROR',
        message: 'Error al eliminar en Supabase (${res.statusCode}).',
      );
    }
  }

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

  // 1. GET /api/health
  static Future<Map<String, dynamic>> checkHealth() async {
    if (_useSupabaseDirect) {
      await _supaGet('complejos?select=id&limit=1');
      return {
        'ok': true,
        'service': 'Luxxito Sports Cloud API + Supabase PostgreSQL (4G/Wi-Fi)',
        'db_mode': 'SUPABASE_POSTGRES_CLOUD',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(_timeout);
      return _decodeResponse(res);
    } catch (_) {
      if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
        enableSupabaseCloudMode();
        return checkHealth();
      }
      throw ApiException(
        statusCode: 0,
        code: 'TIMEOUT',
        message: 'No se pudo conectar con $_baseUrl.',
      );
    }
  }

  // 1b. GET /api/version
  static Future<Map<String, dynamic>> checkAppUpdate() async {
    return {
      'version': '1.0.2',
      'build_number': 3,
      'release_notes':
          'Incluye Login inicial obligatorio, conexión directa en la nube (4.5G/Wi-Fi) con Supabase PostgreSQL y temporizador de 20 min.',
      'github_release_apk_url':
          'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk',
      'server_apk_url': 'http://192.168.1.14:3000/api/apk/download',
    };
  }

  // 1c. Login y Registro
  static Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();
    if (cleanEmail.isEmpty || cleanPass.isEmpty) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'Ingresa tu correo y contraseña.',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/auth/login'),
              headers: _headers,
              body: jsonEncode({'email': cleanEmail, 'password': cleanPass}),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        final session = UserSession.fromJson(body['data'] as Map<String, dynamic>);
        _currentSession = session;
        return session;
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    if (_useSupabaseDirect) {
      final rows = await _supaGet(
        'usuarios?select=*&email=ilike.${Uri.encodeComponent(cleanEmail)}&limit=1',
      ) as List<dynamic>;
      if (rows.isEmpty || rows.first['password_hash']?.toString() != cleanPass) {
        throw ApiException(
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
          message: 'Correo o contraseña incorrectos.',
        );
      }
      final u = rows.first as Map<String, dynamic>;
      final session = UserSession.fromJson(
        u,
        tokenOverride: 'jwt-supa-${u['id']}-${DateTime.now().millisecondsSinceEpoch}',
      );
      _currentSession = session;
      return session;
    }

    throw ApiException(
      statusCode: 0,
      code: 'NETWORK_ERROR',
      message: 'No se pudo conectar al servidor de autenticación.',
    );
  }

  static Future<UserSession> registrarUsuario({
    required String nombre,
    required String dni,
    required String telefono,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (nombre.trim().length < 3) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'El nombre debe tener al menos 3 caracteres.',
      );
    }
    if (!RegExp(r'^\d{8}$').hasMatch(dni.trim())) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'El DNI debe tener exactamente 8 dígitos numéricos.',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/auth/registro'),
              headers: _headers,
              body: jsonEncode({
                'nombre': nombre.trim(),
                'dni': dni.trim(),
                'telefono': telefono.trim(),
                'email': cleanEmail,
                'password': password.trim(),
              }),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        final session = UserSession.fromJson(body['data'] as Map<String, dynamic>);
        _currentSession = session;
        return session;
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    if (_useSupabaseDirect) {
      final existing = await _supaGet(
        'usuarios?select=id&or=(email.ilike.${Uri.encodeComponent(cleanEmail)},dni.eq.${dni.trim()})',
      ) as List<dynamic>;
      if (existing.isNotEmpty) {
        throw ApiException(
          statusCode: 409,
          code: 'CONFLICT',
          message: 'Ya existe un usuario registrado con ese correo o DNI.',
        );
      }
      final created = await _supaPost('usuarios', {
        'nombre': nombre.trim(),
        'dni': dni.trim(),
        'telefono': telefono.trim(),
        'email': cleanEmail,
        'password_hash': password.trim(),
        'rol': 'JUGADOR',
      }) as List<dynamic>;
      final u = created.first as Map<String, dynamic>;
      final session = UserSession.fromJson(
        u,
        tokenOverride: 'jwt-supa-${u['id']}-${DateTime.now().millisecondsSinceEpoch}',
      );
      _currentSession = session;
      return session;
    }

    throw ApiException(
      statusCode: 0,
      code: 'NETWORK_ERROR',
      message: 'No se pudo conectar al servidor para el registro.',
    );
  }

  // 2. GET /api/complejos
  static Future<List<Complejo>> getComplejos({String? distrito}) async {
    if (!_useSupabaseDirect) {
      try {
        final uri = Uri.parse('$_baseUrl/complejos').replace(
          queryParameters: distrito != null && distrito.isNotEmpty
              ? {'distrito': distrito}
              : null,
        );
        final res = await http.get(uri, headers: _headers).timeout(_timeout);
        final body = _decodeResponse(res);
        final list = body['data'] as List<dynamic>? ?? [];
        return list
            .map((e) => Complejo.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        } else {
          rethrow;
        }
      }
    }

    var query = 'complejos?select=*&activo=eq.true&order=id.asc';
    if (distrito != null && distrito.isNotEmpty) {
      query += '&distrito=ilike.${Uri.encodeComponent(distrito)}';
    }
    final rows = await _supaGet(query) as List<dynamic>;
    return rows.map((e) => Complejo.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 3. GET /api/canchas
  static Future<List<Cancha>> getCanchas({
    int? complejoId,
    String? distrito,
    String? deporte,
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final params = <String, String>{};
        if (complejoId != null) params['complejo_id'] = complejoId.toString();
        if (distrito != null && distrito.isNotEmpty) params['distrito'] = distrito;
        if (deporte != null && deporte.isNotEmpty) params['deporte'] = deporte;

        final uri = Uri.parse('$_baseUrl/canchas').replace(
          queryParameters: params.isNotEmpty ? params : null,
        );
        final res = await http.get(uri, headers: _headers).timeout(_timeout);
        final body = _decodeResponse(res);
        final list = body['data'] as List<dynamic>? ?? [];
        return list
            .map((e) => Cancha.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        } else {
          rethrow;
        }
      }
    }

    final complejos = await getComplejos();
    final compMap = {for (final c in complejos) c.id: c};

    var query = 'canchas?select=*&order=id.asc';
    if (complejoId != null) query += '&complejo_id=eq.$complejoId';
    if (deporte != null && deporte.isNotEmpty) {
      query += '&deporte=ilike.${Uri.encodeComponent(deporte)}';
    }
    final rows = await _supaGet(query) as List<dynamic>;
    var list = rows.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final comp = compMap[(m['complejo_id'] as num).toInt()];
      m['complejo_nombre'] = comp?.nombre ?? 'Complejo Luxxito';
      m['distrito'] = comp?.distrito ?? 'Lima';
      m['direccion'] = comp?.direccion ?? '';
      return Cancha.fromJson(m);
    }).toList();

    if (distrito != null && distrito.isNotEmpty) {
      list = list
          .where((c) => c.distrito.toLowerCase() == distrito.toLowerCase())
          .toList();
    }
    return list;
  }

  // 4. POST /api/canchas
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
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'El nombre de la cancha debe tener al menos 3 caracteres.',
      );
    }
    if (precioDiurno <= 0 || precioNocturno < precioDiurno) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message:
            'El precio diurno debe ser > 0 y el precio nocturno >= al precio diurno.',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
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
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        return Cancha.fromJson(body['data'] as Map<String, dynamic>);
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    final created = await _supaPost('canchas', {
      'complejo_id': complejoId,
      'nombre': nombre.trim(),
      'deporte': deporte,
      'superficie': superficie.trim(),
      'techada': techada,
      'iluminacion': true,
      'precio_hora_diurno': precioDiurno,
      'precio_hora_nocturno': precioNocturno,
      'estado': 'ACTIVA',
    }) as List<dynamic>;
    final m = Map<String, dynamic>.from(created.first as Map<String, dynamic>);
    return Cancha.fromJson(m);
  }

  // 5. GET /api/canchas/:id/disponibilidad
  static Future<DisponibilidadData> getDisponibilidad({
    required int canchaId,
    required String fecha,
    int? hora,
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final params = <String, String>{'fecha': fecha};
        if (hora != null) params['hora'] = hora.toString();
        final uri = Uri.parse('$_baseUrl/canchas/$canchaId/disponibilidad')
            .replace(queryParameters: params);
        final res = await http.get(uri, headers: _headers).timeout(_timeout);
        final body = _decodeResponse(res);
        return DisponibilidadData.fromJson(body['data'] as Map<String, dynamic>);
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    final canchas = await getCanchas();
    final cancha = canchas.firstWhere((c) => c.id == canchaId);
    final complejos = await getComplejos();
    final complejo = complejos.firstWhere((co) => co.id == cancha.complejoId);

    final reservasDia = await _supaGet(
      'reservas?select=*&cancha_id=eq.$canchaId&fecha=eq.$fecha',
    ) as List<dynamic>;

    final turnos = <TurnoDisponibilidad>[];
    for (var h = complejo.horaApertura; h < complejo.horaCierre; h++) {
      final esNocturno = h >= 18;
      final precio =
          esNocturno ? cancha.precioHoraNocturno : cancha.precioHoraDiurno;
      var estado = 'DISPONIBLE';
      for (final r in reservasDia) {
        final rMap = r as Map<String, dynamic>;
        final est = rMap['estado']?.toString() ?? '';
        final hi = (rMap['hora_inicio'] as num).toInt();
        final hf = (rMap['hora_fin'] as num).toInt();
        if (['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'].contains(est) &&
            h >= hi &&
            h < hf) {
          estado = est == 'CONFIRMADA' ? 'OCUPADA' : 'BLOQUEADA';
          break;
        }
      }
      turnos.add(
        TurnoDisponibilidad(
          horaInicio: h,
          horaFin: h + 1,
          etiqueta:
              '${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00',
          tarifaTipo: esNocturno ? 'NOCTURNA' : 'DIURNA',
          precio: precio,
          estado: estado,
        ),
      );
    }

    final extrasRows = await _supaGet(
      'extras?select=*&complejo_id=eq.${complejo.id}&activo=eq.true&order=id.asc',
    ) as List<dynamic>;
    final extras = extrasRows
        .map((e) => ExtraItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DisponibilidadData(
      cancha: cancha,
      complejo: complejo,
      fecha: fecha,
      turnos: turnos,
      extrasDisponibles: extras,
    );
  }

  // 6. POST /api/reservas/cotizar
  static Future<Map<String, dynamic>> cotizarReserva({
    required int canchaId,
    required String fecha,
    required int horaInicio,
    required int horaFin,
    required List<Map<String, int>> extras,
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/reservas/cotizar'),
              headers: _headers,
              body: jsonEncode({
                'cancha_id': canchaId,
                'fecha': fecha,
                'hora_inicio': horaInicio,
                'hora_fin': horaFin,
                'extras': extras,
              }),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        return body['data'] as Map<String, dynamic>;
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    final canchas = await getCanchas();
    final cancha = canchas.firstWhere((c) => c.id == canchaId);
    double subCancha = 0;
    for (var h = horaInicio; h < horaFin; h++) {
      subCancha += h >= 18 ? cancha.precioHoraNocturno : cancha.precioHoraDiurno;
    }

    final extrasRows = await _supaGet(
      'extras?select=*&complejo_id=eq.${cancha.complejoId}&activo=eq.true',
    ) as List<dynamic>;
    final extraMap = {
      for (final e in extrasRows)
        ((e as Map<String, dynamic>)['id'] as num).toInt():
            ExtraItem.fromJson(e)
    };

    double subExtras = 0;
    final desgloseExtras = <Map<String, dynamic>>[];
    for (final req in extras) {
      final exId = req['extra_id']!;
      final cant = req['cantidad']!;
      final item = extraMap[exId];
      if (item != null && cant > 0) {
        if (cant > item.stockTotal) {
          throw ApiException(
            statusCode: 409,
            code: 'CONFLICT',
            message: 'Stock insuficiente para ${item.nombre}.',
          );
        }
        final sub = item.precioUnitario * cant;
        subExtras += sub;
        desgloseExtras.add({
          'extra_id': exId,
          'nombre': item.nombre,
          'cantidad': cant,
          'precio_unitario': item.precioUnitario,
          'subtotal': sub,
        });
      }
    }

    final total = subCancha + subExtras;
    return {
      'cancha_id': cancha.id,
      'cancha_nombre': cancha.nombre,
      'complejo_nombre': cancha.complejoNombre,
      'fecha': fecha,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'duracion_horas': horaFin - horaInicio,
      'subtotal_cancha': subCancha,
      'subtotal_extras': subExtras,
      'total': total,
      'monto_sena_50': double.parse((total * 0.5).toStringAsFixed(2)),
      'desglose_extras': desgloseExtras,
    };
  }

  // 7. POST /api/reservas
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
  }) async {
    if (clienteNombre.trim().length < 3 ||
        !RegExp(r'^\d{8}$').hasMatch(clienteDni.trim())) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'Ingresa un nombre válido y DNI de 8 dígitos numéricos.',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
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
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        return Reserva.fromJson(body['data'] as Map<String, dynamic>);
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    // Verificar solapamiento en Supabase
    final existentes = await _supaGet(
      'reservas?select=*&cancha_id=eq.$canchaId&fecha=eq.$fecha',
    ) as List<dynamic>;
    for (final raw in existentes) {
      final r = raw as Map<String, dynamic>;
      final est = r['estado']?.toString() ?? '';
      final hi = (r['hora_inicio'] as num).toInt();
      final hf = (r['hora_fin'] as num).toInt();
      if (['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'].contains(est) &&
          hi < horaFin &&
          hf > horaInicio) {
        throw ApiException(
          statusCode: 409,
          code: 'CONFLICT',
          message:
              'El turno de $horaInicio:00 a $horaFin:00 ya se encuentra reservado o bloqueado (Reserva #${r['id']}).',
        );
      }
    }

    final quote = await cotizarReserva(
      canchaId: canchaId,
      fecha: fecha,
      horaInicio: horaInicio,
      horaFin: horaFin,
      extras: extras,
    );

    final expiresAt =
        DateTime.now().add(const Duration(minutes: 20)).toIso8601String();
    final inserted = await _supaPost('reservas', {
      'cancha_id': canchaId,
      'cliente_nombre': clienteNombre.trim(),
      'cliente_dni': clienteDni.trim(),
      'cliente_telefono': clienteTelefono.trim(),
      'cliente_email': clienteEmail.trim(),
      'fecha': fecha,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'subtotal_cancha': quote['subtotal_cancha'],
      'subtotal_extras': quote['subtotal_extras'],
      'total': quote['total'],
      'monto_pagado': 0,
      'monto_devolucion': 0,
      'estado': 'PENDIENTE_PAGO',
      'notas': notas,
      'expires_at': expiresAt,
    }) as List<dynamic>;

    final resMap = Map<String, dynamic>.from(inserted.first as Map<String, dynamic>);
    final newId = (resMap['id'] as num).toInt();

    final desgloseExtras = quote['desglose_extras'] as List<dynamic>? ?? [];
    for (final item in desgloseExtras) {
      final m = item as Map<String, dynamic>;
      await _supaPost('reserva_extras', {
        'reserva_id': newId,
        'extra_id': m['extra_id'],
        'cantidad': m['cantidad'],
        'precio_unitario': m['precio_unitario'],
        'subtotal': m['subtotal'],
      });
    }

    final all = await getReservas();
    return all.firstWhere((r) => r.id == newId);
  }

  // 8. GET /api/reservas
  static Future<List<Reserva>> getReservas({String? estado}) async {
    if (!_useSupabaseDirect) {
      try {
        final uri = Uri.parse('$_baseUrl/reservas').replace(
          queryParameters:
              estado != null && estado.isNotEmpty ? {'estado': estado} : null,
        );
        final res = await http.get(uri, headers: _headers).timeout(_timeout);
        final body = _decodeResponse(res);
        final list = body['data'] as List<dynamic>? ?? [];
        return list
            .map((e) => Reserva.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        } else {
          rethrow;
        }
      }
    }

    final canchas = await getCanchas();
    final canchaMap = {for (final c in canchas) c.id: c};

    var query = 'reservas?select=*&order=id.desc';
    if (estado != null && estado.isNotEmpty) {
      query += '&estado=eq.$estado';
    }
    final rows = await _supaGet(query) as List<dynamic>;
    final reRows = await _supaGet('reserva_extras?select=*') as List<dynamic>;
    final exRows = await _supaGet('extras?select=id,nombre') as List<dynamic>;
    final exNames = {
      for (final e in exRows)
        ((e as Map<String, dynamic>)['id'] as num).toInt():
            e['nombre']?.toString() ?? 'Extra'
    };

    return rows.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final cId = (m['cancha_id'] as num).toInt();
      final rId = (m['id'] as num).toInt();
      final cancha = canchaMap[cId];
      m['cancha_nombre'] = cancha?.nombre ?? 'Cancha #$cId';
      m['deporte'] = cancha?.deporte ?? 'Deporte';
      m['complejo_nombre'] = cancha?.complejoNombre ?? 'Complejo Luxxito';
      m['distrito'] = cancha?.distrito ?? 'Lima';
      m['extras'] = reRows
          .where((re) =>
              ((re as Map<String, dynamic>)['reserva_id'] as num).toInt() ==
              rId)
          .map((re) {
        final rm = Map<String, dynamic>.from(re as Map<String, dynamic>);
        rm['nombre'] = exNames[(rm['extra_id'] as num).toInt()] ?? 'Extra';
        return rm;
      }).toList();
      return Reserva.fromJson(m);
    }).toList();
  }

  // 9. PUT /api/reservas/:id
  static Future<Reserva> actualizarReserva({
    required int reservaId,
    required String clienteTelefono,
    required String notas,
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .put(
              Uri.parse('$_baseUrl/reservas/$reservaId'),
              headers: _headers,
              body: jsonEncode({
                'cliente_telefono': clienteTelefono,
                'notas': notas,
              }),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        return Reserva.fromJson(body['data'] as Map<String, dynamic>);
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    await _supaPatch('reservas?id=eq.$reservaId', {
      'cliente_telefono': clienteTelefono,
      'notas': notas,
      'updated_at': DateTime.now().toIso8601String(),
    });
    final list = await getReservas();
    return list.firstWhere((r) => r.id == reservaId);
  }

  // 10. DELETE /api/reservas/:id
  static Future<void> eliminarReserva(int reservaId) async {
    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .delete(
              Uri.parse('$_baseUrl/reservas/$reservaId'),
              headers: _headers,
            )
            .timeout(_timeout);
        _decodeResponse(res);
        return;
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }
    await _supaDelete('reservas?id=eq.$reservaId');
  }

  // 11. POST /api/reservas/:id/pagos
  static Future<Reserva> registrarPago({
    required int reservaId,
    required String metodo,
    required String modalidad,
    required double monto,
    required String numeroOperacion,
    bool autoAprobar = true,
  }) async {
    if (numeroOperacion.trim().length < 4) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'Ingresa un número de operación válido (mínimo 4 caracteres).',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/reservas/$reservaId/pagos'),
              headers: _headers,
              body: jsonEncode({
                'metodo': metodo,
                'modalidad': modalidad,
                'monto': monto,
                'numero_operacion': numeroOperacion,
                'auto_aprobar': autoAprobar,
              }),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        final data = body['data'] as Map<String, dynamic>;
        return Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    await _supaPost('pagos', {
      'reserva_id': reservaId,
      'metodo': metodo,
      'modalidad': modalidad,
      'monto': monto,
      'numero_operacion': numeroOperacion.trim(),
      'estado': autoAprobar ? 'APROBADO' : 'PENDIENTE_REVISION',
    });

    final qr =
        'LUXXITO-QR-$reservaId-${numeroOperacion.trim().toUpperCase()}';
    await _supaPatch('reservas?id=eq.$reservaId', {
      'estado': autoAprobar ? 'CONFIRMADA' : 'EN_REVISION',
      'monto_pagado': monto,
      'codigo_qr': autoAprobar ? qr : null,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final list = await getReservas();
    return list.firstWhere((r) => r.id == reservaId);
  }

  // 12. POST /api/reservas/:id/cancelar
  static Future<Map<String, dynamic>> cancelarReserva({
    required int reservaId,
    required String motivo,
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/reservas/$reservaId/cancelar'),
              headers: _headers,
              body: jsonEncode({'motivo': motivo}),
            )
            .timeout(_timeout);
        final body = _decodeResponse(res);
        return body['data'] as Map<String, dynamic>;
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        }
      }
    }

    final list = await getReservas();
    final r = list.firstWhere((item) => item.id == reservaId);
    final inicioTurno = DateTime.tryParse(
          '${r.fecha}T${r.horaInicio.toString().padLeft(2, '0')}:00:00',
        ) ??
        DateTime.now().add(const Duration(hours: 48));
    final horasRestantes =
        inicioTurno.difference(DateTime.now()).inMinutes / 60.0;

    double devolucion = 0;
    String politica = 'SIN_PAGOS_PREVIOS';
    if (r.montoPagado > 0) {
      if (horasRestantes >= 24) {
        devolucion = r.montoPagado;
        politica = 'REEMBOLSO_100_MAYOR_24H';
      } else {
        devolucion = double.parse((r.montoPagado * 0.5).toStringAsFixed(2));
        politica = 'RETENCION_50_MENOR_24H';
      }
    }

    await _supaPatch('reservas?id=eq.$reservaId', {
      'estado': 'CANCELADA',
      'monto_devolucion': devolucion,
      'codigo_qr': null,
      'motivo_cancelacion': motivo.trim().isEmpty
          ? 'Cancelada desde la app ($politica)'
          : motivo.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return {
      'politica_aplicada': politica,
      'monto_devolucion': devolucion,
    };
  }
}

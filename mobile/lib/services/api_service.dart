import 'dart:async';
import 'dart:convert';
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
          : 'http://192.168.1.14:3000/api');

  static String get baseUrl => _baseUrl;

  static bool get _useSupabaseDirect =>
      _supaUrl.isNotEmpty &&
      _supaKey.isNotEmpty &&
      (_baseUrl.startsWith('SUPABASE_CLOUD') || _baseUrl.contains('.supabase.co'));

  static UserSession? _currentSession;
  static UserSession? get currentSession => _currentSession;
  static bool get esAdmin => _currentSession?.rol == 'ADMIN';

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

  /// Invoca una función RPC SECURITY DEFINER en el servidor PostgreSQL de Supabase.
  /// Garantiza que toda regla de negocio y validación de rol ADMIN se ejecute en el servidor.
  static Future<dynamic> _supaRpc(
    String fnName,
    Map<String, dynamic> params,
  ) async {
    final res = await http
        .post(
          Uri.parse('$_supaUrl/rest/v1/rpc/$fnName'),
          headers: _supaHeaders,
          body: jsonEncode(params),
        )
        .timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String rawMsg = 'Error en operación del servidor (${res.statusCode}).';
    try {
      final errBody = jsonDecode(utf8.decode(res.bodyBytes));
      if (errBody is Map && errBody['message'] != null) {
        rawMsg = errBody['message'].toString();
      }
    } catch (_) {}

    if (rawMsg.contains('INVALID_CREDENTIALS:')) {
      throw ApiException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: rawMsg.split('INVALID_CREDENTIALS:').last.trim(),
      );
    }
    if (rawMsg.contains('FORBIDDEN:')) {
      throw ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: rawMsg.split('FORBIDDEN:').last.trim(),
      );
    }
    if (rawMsg.contains('NOT_FOUND:')) {
      throw ApiException(
        statusCode: 404,
        code: 'NOT_FOUND',
        message: rawMsg.split('NOT_FOUND:').last.trim(),
      );
    }
    if (rawMsg.contains('CONFLICT:')) {
      throw ApiException(
        statusCode: 409,
        code: 'CONFLICT',
        message: rawMsg.split('CONFLICT:').last.trim(),
      );
    }
    if (rawMsg.contains('BUSINESS_RULE_VIOLATION:')) {
      throw ApiException(
        statusCode: 422,
        code: 'BUSINESS_RULE_VIOLATION',
        message: rawMsg.split('BUSINESS_RULE_VIOLATION:').last.trim(),
      );
    }
    if (rawMsg.contains('BAD_REQUEST:')) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: rawMsg.split('BAD_REQUEST:').last.trim(),
      );
    }

    throw ApiException(
      statusCode: res.statusCode,
      code: 'RPC_ERROR',
      message: rawMsg,
    );
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

  static void _requireAdminSession() {
    if (_currentSession == null || _currentSession!.token.isEmpty) {
      throw ApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: 'Debes iniciar sesión para realizar esta operación.',
      );
    }
    if (!esAdmin) {
      throw ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Acceso restringido: esta operación requiere rol ADMIN.',
      );
    }
  }

  // 1. GET /api/health
  static Future<Map<String, dynamic>> checkHealth() async {
    if (_useSupabaseDirect) {
      await _supaGet('complejos?select=id&limit=1');
      return {
        'ok': true,
        'service': 'Luxxito Sports Cloud API + Supabase PostgreSQL (RLS + RPC)',
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
      'version': '1.0.3',
      'build_number': 4,
      'release_notes':
          'Incluye control de acceso JWT por rol ADMIN (LX-201), Row Level Security (RLS), bucket privado comprobantes y RPCs en servidor.',
      'github_release_apk_url':
          'https://github.com/Arbolito-ctrl/LuxxitoSports/raw/main/release/luxxito-sports.apk',
      'server_apk_url': 'http://192.168.1.14:3000/api/apk/download',
    };
  }

  // 1c. Login y Registro (validados en servidor / RPC sin exponer password_hash)
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
      final u = await _supaRpc('rpc_login_usuario', {
        'p_email': cleanEmail,
        'p_password': cleanPass,
      }) as Map<String, dynamic>;
      final session = UserSession.fromJson(
        u,
        tokenOverride: 'jwt-supa-${u['id']}-${u['rol']}-${DateTime.now().millisecondsSinceEpoch}',
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
      final u = await _supaRpc('rpc_registrar_usuario', {
        'p_nombre': nombre.trim(),
        'p_dni': dni.trim(),
        'p_telefono': telefono.trim(),
        'p_email': cleanEmail,
        'p_password': password.trim(),
      }) as Map<String, dynamic>;
      final session = UserSession.fromJson(
        u,
        tokenOverride: 'jwt-supa-${u['id']}-${u['rol']}-${DateTime.now().millisecondsSinceEpoch}',
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

    final created = await _supaRpc('rpc_crear_cancha', {
      'p_complejo_id': complejoId,
      'p_nombre': nombre.trim(),
      'p_deporte': deporte,
      'p_superficie': superficie.trim(),
      'p_techada': techada,
      'p_precio_diurno': precioDiurno,
      'p_precio_nocturno': precioNocturno,
    }) as Map<String, dynamic>;
    return Cancha.fromJson(created);
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

  // 7. POST /api/reservas (ejecutado en servidor / RPC rpc_crear_reserva)
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

    final created = await _supaRpc('rpc_crear_reserva', {
      'p_cancha_id': canchaId,
      'p_cliente_nombre': clienteNombre.trim(),
      'p_cliente_dni': clienteDni.trim(),
      'p_cliente_telefono': clienteTelefono.trim(),
      'p_cliente_email': clienteEmail.trim(),
      'p_fecha': fecha,
      'p_hora_inicio': horaInicio,
      'p_hora_fin': horaFin,
      'p_notas': notas,
      'p_extras': extras,
    }) as Map<String, dynamic>;

    final newId = (created['id'] as num).toInt();
    final all = await getReservas();
    return all.firstWhere((r) => r.id == newId);
  }

  // 8. GET /api/reservas
  static Future<List<Reserva>> getReservas({
    String? estado,
    String? clienteDni,
  }) async {
    final filtros = <String, String>{
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      if (clienteDni != null && clienteDni.isNotEmpty) 'cliente_dni': clienteDni,
    };
    if (!_useSupabaseDirect) {
      try {
        final uri = Uri.parse('$_baseUrl/reservas').replace(
          queryParameters: filtros.isEmpty ? null : filtros,
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
    filtros.forEach((campo, valor) {
      query += '&$campo=eq.${Uri.encodeComponent(valor)}';
    });
    final rows = await _supaGet(query) as List<dynamic>;
    final reRows = await _supaGet('reserva_extras?select=*') as List<dynamic>;
    final exRows = await _supaGet('extras?select=id,nombre') as List<dynamic>;
    final pagoRows =
        await _supaGet('pagos?select=*&order=id.asc') as List<dynamic>;
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
      m['pagos'] = pagoRows
          .where((p) =>
              ((p as Map<String, dynamic>)['reserva_id'] as num).toInt() == rId)
          .toList();
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

    await _supaRpc('rpc_actualizar_reserva', {
      'p_reserva_id': reservaId,
      'p_cliente_telefono': clienteTelefono,
      'p_notas': notas,
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
    await _supaRpc('rpc_eliminar_reserva', {'p_reserva_id': reservaId});
  }

  // 11. POST /api/reservas/:id/pagos
  static Future<Reserva> registrarPago({
    required int reservaId,
    required String metodo,
    required String modalidad,
    required double monto,
    required String numeroOperacion,
    bool autoAprobar = false,
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

    await _supaRpc('rpc_registrar_pago', {
      'p_reserva_id': reservaId,
      'p_metodo': metodo,
      'p_modalidad': modalidad,
      'p_monto': monto,
      'p_numero_operacion': numeroOperacion.trim(),
      'p_auto_aprobar': autoAprobar,
    });

    final list = await getReservas();
    return list.firstWhere((r) => r.id == reservaId);
  }

  // 11b. GET /api/pagos?estado= (Bandeja de revisión del operador - requiere rol ADMIN)
  static Future<List<PagoEnRevision>> listarPagos({
    String estado = 'PENDIENTE_REVISION',
  }) async {
    if (!_useSupabaseDirect) {
      try {
        final uri = Uri.parse('$_baseUrl/pagos').replace(
          queryParameters: {'estado': estado},
        );
        final res = await http.get(uri, headers: _headers).timeout(_timeout);
        final body = _decodeResponse(res);
        return (body['data'] as List<dynamic>)
            .map((p) => PagoEnRevision.fromJson(p as Map<String, dynamic>))
            .toList();
      } on ApiException {
        rethrow;
      } catch (_) {
        if (_supaUrl.isNotEmpty && _supaKey.isNotEmpty) {
          enableSupabaseCloudMode();
        } else {
          rethrow;
        }
      }
    }

    _requireAdminSession();

    final pagos = await _supaGet(
      'pagos?select=*&estado=eq.$estado&order=created_at.asc,id.asc',
    ) as List<dynamic>;
    if (pagos.isEmpty) return [];
    final reservas = {for (final r in await getReservas()) r.id: r};

    return pagos.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final r = reservas[(m['reserva_id'] as num).toInt()];
      if (r != null) {
        m['reserva'] = {
          'estado': r.estado,
          'cancha_nombre': r.canchaNombre,
          'complejo_nombre': r.complejoNombre,
          'cliente_nombre': r.clienteNombre,
          'cliente_dni': r.clienteDni,
          'cliente_telefono': r.clienteTelefono,
          'fecha': r.fecha,
          'hora_inicio': r.horaInicio,
          'hora_fin': r.horaFin,
          'total': r.total,
        };
      }
      return PagoEnRevision.fromJson(m);
    }).toList();
  }

  // 11c. PATCH /api/pagos/:id/aprobar (Aprobación idempotente + Ticket QR - requiere ADMIN)
  static Future<Reserva> aprobarPago(int pagoId) async {
    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .patch(
              Uri.parse('$_baseUrl/pagos/$pagoId/aprobar'),
              headers: _headers,
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

    _requireAdminSession();
    final updated = await _supaRpc('rpc_aprobar_pago', {
      'p_pago_id': pagoId,
      'p_rol': _currentSession?.rol ?? '',
    }) as Map<String, dynamic>;
    final reservaId = (updated['id'] as num).toInt();

    final list = await getReservas();
    return list.firstWhere((item) => item.id == reservaId);
  }

  // 11d. PATCH /api/pagos/:id/rechazar (Rechazo con observación obligatoria - requiere ADMIN)
  static Future<Reserva> rechazarPago({
    required int pagoId,
    required String observacion,
  }) async {
    if (observacion.trim().length < 5) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'Indica el motivo del rechazo (mínimo 5 caracteres).',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .patch(
              Uri.parse('$_baseUrl/pagos/$pagoId/rechazar'),
              headers: _headers,
              body: jsonEncode({'observacion': observacion.trim()}),
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

    _requireAdminSession();
    final updated = await _supaRpc('rpc_rechazar_pago', {
      'p_pago_id': pagoId,
      'p_observacion': observacion.trim(),
      'p_rol': _currentSession?.rol ?? '',
    }) as Map<String, dynamic>;
    final reservaId = (updated['id'] as num).toInt();

    final list = await getReservas();
    return list.firstWhere((item) => item.id == reservaId);
  }

  // 12. POST /api/reservas/:id/cancelar (Regla de 24h ejecutada en servidor / RPC)
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

    final result = await _supaRpc('rpc_cancelar_reserva', {
      'p_reserva_id': reservaId,
      'p_motivo': motivo.trim(),
    }) as Map<String, dynamic>;
    return result;
  }

  // 13. POST /api/reservas/verificar-qr (Verificación de ingreso único con QR - LX-202)
  static Future<Map<String, dynamic>> verificarTicketQr(String codigoQr) async {
    final clean = codigoQr.trim();
    if (clean.isEmpty || !clean.toUpperCase().startsWith('LUXXITO-QR-')) {
      throw ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'Ingresa un código QR con formato LUXXITO-QR-...',
      );
    }

    if (!_useSupabaseDirect) {
      try {
        final res = await http
            .post(
              Uri.parse('$_baseUrl/reservas/verificar-qr'),
              headers: _headers,
              body: jsonEncode({'codigo_qr': clean}),
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

    final result = await _supaRpc('rpc_verificar_qr', {
      'p_codigo_qr': clean,
    }) as Map<String, dynamic>;
    return result;
  }
}

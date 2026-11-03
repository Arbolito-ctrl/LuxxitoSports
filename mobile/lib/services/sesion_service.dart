import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/luxxito_models.dart';
import 'api_service.dart';

/// Mantiene la sesión entre aperturas de la app (y tras actualizarla):
/// el token se guarda cifrado en el almacenamiento seguro de Android.
class SesionService {
  SesionService._();

  static const _storage = FlutterSecureStorage();
  static const _clave = 'luxxito_sesion';

  static Future<void> guardar(UserSession sesion) async {
    await _storage.write(
      key: _clave,
      value: jsonEncode({
        'token': sesion.token,
        'user': {
          'id': sesion.id,
          'nombre': sesion.nombre,
          'dni': sesion.dni,
          'telefono': sesion.telefono,
          'email': sesion.email,
          'rol': sesion.rol,
        },
      }),
    );
  }

  static Future<void> borrar() async {
    try {
      await _storage.delete(key: _clave);
    } catch (_) {
      // Si el almacenamiento no está disponible no hay nada que borrar
    }
  }

  /// Recupera la sesión guardada y la valida con `GET /api/auth/me`.
  /// Si el servidor la rechaza (vencida o inválida) se borra; si no hay
  /// conexión se conserva para no expulsar al usuario por estar sin señal.
  static Future<UserSession?> restaurar() async {
    final UserSession guardada;
    try {
      final crudo = await _storage.read(key: _clave);
      if (crudo == null) return null;
      guardada = UserSession.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
    } catch (_) {
      await borrar();
      return null;
    }
    if (guardada.token.isEmpty) return null;

    try {
      final res = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/auth/me'),
            headers: {'Authorization': 'Bearer ${guardada.token}'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 401 || res.statusCode == 403) {
        await borrar();
        return null;
      }
      if (res.statusCode == 200) {
        // Datos del perfil actualizados desde el servidor (nombre, teléfono, rol)
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final actualizada = UserSession.fromJson(
          body['data'] as Map<String, dynamic>,
          tokenOverride: guardada.token,
        );
        await guardar(actualizada);
        return actualizada;
      }
    } catch (_) {
      // Sin conexión: se usa la sesión guardada
    }
    return guardada;
  }
}

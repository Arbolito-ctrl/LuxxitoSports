import '../../models/luxxito_models.dart';
import 'cliente_api.dart';
import 'sesion_api.dart';

/// Inicio de sesión y registro (POST /auth/login y /auth/registro).
/// Si sale bien, la sesión queda guardada en [SesionApi].
class AuthApi {
  static Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();
    if (cleanEmail.isEmpty || cleanPass.isEmpty) {
      throw ClienteApi.datoInvalido('Ingresa tu correo y contraseña.');
    }

    final body = await ClienteApi.post(
      '/auth/login',
      body: {'email': cleanEmail, 'password': cleanPass},
    );
    final session = UserSession.fromJson(body['data'] as Map<String, dynamic>);
    SesionApi.setSession(session);
    return session;
  }

  static Future<UserSession> registrarUsuario({
    required String nombre,
    required String dni,
    required String telefono,
    required String email,
    required String password,
  }) async {
    if (nombre.trim().length < 3) {
      throw ClienteApi.datoInvalido('El nombre debe tener al menos 3 caracteres.');
    }
    if (!RegExp(r'^\d{8}$').hasMatch(dni.trim())) {
      throw ClienteApi.datoInvalido('El DNI debe tener exactamente 8 dígitos numéricos.');
    }

    final body = await ClienteApi.post(
      '/auth/registro',
      body: {
        'nombre': nombre.trim(),
        'dni': dni.trim(),
        'telefono': telefono.trim(),
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
      },
    );
    final session = UserSession.fromJson(body['data'] as Map<String, dynamic>);
    SesionApi.setSession(session);
    return session;
  }
}

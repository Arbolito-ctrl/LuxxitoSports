import '../../models/luxxito_models.dart';

/// Usuario que inició sesión en la app (una sola sesión a la vez).
///
/// ClienteApi lee de aquí el token para enviarlo en cada petición, y las
/// pantallas usan [esAdmin] para mostrar u ocultar las opciones del operador.
/// Guardar la sesión en el teléfono entre aperturas lo hace SesionService.
class SesionApi {
  static UserSession? _currentSession;

  static UserSession? get currentSession => _currentSession;

  /// Solo indica qué mostrar en la app: los permisos reales los valida el
  /// backend con el token en cada petición.
  static bool get esAdmin => _currentSession?.rol == 'ADMIN';

  static void setSession(UserSession? session) {
    _currentSession = session;
  }

  static void logout() {
    _currentSession = null;
  }
}

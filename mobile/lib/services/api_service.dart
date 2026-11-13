import '../models/luxxito_models.dart';
import 'api/auth_api.dart';
import 'api/catalogo_api.dart';
import 'api/cliente_api.dart';
import 'api/pagos_api.dart';
import 'api/reservas_api.dart';
import 'api/sesion_api.dart';

export 'api/cliente_api.dart' show ApiException;

/// Punto de entrada único de la app hacia la API propia (backend en Render).
///
/// Las pantallas siguen llamando a `ApiService.algo()` como siempre; este
/// archivo solo redirige cada llamada al módulo que la implementa:
///
/// | Módulo                | Qué hace                                              |
/// |-----------------------|-------------------------------------------------------|
/// | api/cliente_api.dart  | URL base, token, timeout y traducción de errores      |
/// | api/sesion_api.dart   | usuario logueado y si es ADMIN                        |
/// | api/auth_api.dart     | login, registro y sugerencia de nombre por DNI        |
/// | api/catalogo_api.dart | complejos, canchas, disponibilidad, gestión de canchas|
/// | api/reservas_api.dart | cotizar, crear, listar, editar, eliminar, cancelar    |
/// | api/pagos_api.dart    | pagos, comprobantes, bandeja del ADMIN y Ticket QR    |
///
/// La app habla SOLO con la API: las reglas de negocio viven en el servidor.
/// El antiguo "plan B" (llamar directo a Supabase si la API fallaba) se quitó:
/// estaba desactivado en el APK y dejaba funciones abiertas en la base de datos.
class ApiService {
  // --- Configuración y sesión -------------------------------------------------
  static String get baseUrl => ClienteApi.baseUrl;
  static void setBaseUrl(String url) => ClienteApi.setBaseUrl(url);

  static UserSession? get currentSession => SesionApi.currentSession;
  static bool get esAdmin => SesionApi.esAdmin;
  static void setSession(UserSession? session) => SesionApi.setSession(session);
  static void logout() => SesionApi.logout();

  // --- Autenticación -----------------------------------------------------------
  static Future<UserSession> login({
    required String email,
    required String password,
  }) =>
      AuthApi.login(email: email, password: password);

  static Future<UserSession> registrarUsuario({
    required String nombre,
    required String dni,
    required String telefono,
    required String email,
    required String password,
  }) =>
      AuthApi.registrarUsuario(
        nombre: nombre,
        dni: dni,
        telefono: telefono,
        email: email,
        password: password,
      );

  static Future<String?> sugerirNombrePorDni(String dni) =>
      AuthApi.sugerirNombrePorDni(dni);

  // --- Catálogo ----------------------------------------------------------------
  static Future<Map<String, dynamic>> checkHealth() => CatalogoApi.checkHealth();

  static Future<List<Complejo>> getComplejos({String? distrito}) =>
      CatalogoApi.getComplejos(distrito: distrito);

  static Future<List<Cancha>> getCanchas({
    int? complejoId,
    String? distrito,
    String? deporte,
  }) =>
      CatalogoApi.getCanchas(complejoId: complejoId, distrito: distrito, deporte: deporte);

  static Future<DisponibilidadData> getDisponibilidad({
    required int canchaId,
    required String fecha,
    int? hora,
  }) =>
      CatalogoApi.getDisponibilidad(canchaId: canchaId, fecha: fecha, hora: hora);

  static Future<Cancha> crearCancha({
    required int complejoId,
    required String nombre,
    required String deporte,
    required String superficie,
    required bool techada,
    required double precioDiurno,
    required double precioNocturno,
  }) =>
      CatalogoApi.crearCancha(
        complejoId: complejoId,
        nombre: nombre,
        deporte: deporte,
        superficie: superficie,
        techada: techada,
        precioDiurno: precioDiurno,
        precioNocturno: precioNocturno,
      );

  static Future<Cancha> subirImagenCancha({
    required int canchaId,
    required List<int> bytes,
    required String mimeType,
  }) =>
      CatalogoApi.subirImagenCancha(canchaId: canchaId, bytes: bytes, mimeType: mimeType);

  // --- Reservas ----------------------------------------------------------------
  static Future<Map<String, dynamic>> cotizarReserva({
    required int canchaId,
    required String fecha,
    required int horaInicio,
    required int horaFin,
    required List<Map<String, int>> extras,
  }) =>
      ReservasApi.cotizarReserva(
        canchaId: canchaId,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        extras: extras,
      );

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
  }) =>
      ReservasApi.crearReserva(
        canchaId: canchaId,
        clienteNombre: clienteNombre,
        clienteDni: clienteDni,
        clienteTelefono: clienteTelefono,
        clienteEmail: clienteEmail,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        notas: notas,
        extras: extras,
      );

  static Future<List<Reserva>> getReservas({String? estado, String? clienteDni}) =>
      ReservasApi.getReservas(estado: estado, clienteDni: clienteDni);

  static Future<Reserva> actualizarReserva({
    required int reservaId,
    required String clienteTelefono,
    required String notas,
  }) =>
      ReservasApi.actualizarReserva(
        reservaId: reservaId,
        clienteTelefono: clienteTelefono,
        notas: notas,
      );

  static Future<void> eliminarReserva(int reservaId) =>
      ReservasApi.eliminarReserva(reservaId);

  static Future<Map<String, dynamic>> cancelarReserva({
    required int reservaId,
    required String motivo,
  }) =>
      ReservasApi.cancelarReserva(reservaId: reservaId, motivo: motivo);

  // --- Pagos y Ticket QR -------------------------------------------------------
  static Future<Reserva> registrarPago({
    required int reservaId,
    required String metodo,
    required String modalidad,
    required double monto,
    required String numeroOperacion,
    String? comprobanteUrl,
    bool autoAprobar = false,
  }) =>
      PagosApi.registrarPago(
        reservaId: reservaId,
        metodo: metodo,
        modalidad: modalidad,
        monto: monto,
        numeroOperacion: numeroOperacion,
        comprobanteUrl: comprobanteUrl,
        autoAprobar: autoAprobar,
      );

  static Future<String> subirComprobante({
    required int reservaId,
    required List<int> bytes,
    required String mimeType,
  }) =>
      PagosApi.subirComprobante(reservaId: reservaId, bytes: bytes, mimeType: mimeType);

  static Future<List<PagoEnRevision>> listarPagos({String estado = 'PENDIENTE_REVISION'}) =>
      PagosApi.listarPagos(estado: estado);

  static Future<Reserva> aprobarPago(int pagoId) => PagosApi.aprobarPago(pagoId);

  static Future<Reserva> rechazarPago({
    required int pagoId,
    required String observacion,
  }) =>
      PagosApi.rechazarPago(pagoId: pagoId, observacion: observacion);

  static Future<Map<String, dynamic>> verificarTicketQr(String codigoQr) =>
      PagosApi.verificarTicketQr(codigoQr);
}

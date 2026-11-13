import '../../models/luxxito_models.dart';
import 'cliente_api.dart';

/// Reservas: cotizar, crear, listar, editar, eliminar y cancelar.
/// El precio y todas las reglas (horario, solapamiento, stock, 24 h) los decide el servidor.
class ReservasApi {
  /// POST /reservas/cotizar — precio calculado por el servidor, sin guardar nada.
  static Future<Map<String, dynamic>> cotizarReserva({
    required int canchaId,
    required String fecha,
    required int horaInicio,
    required int horaFin,
    required List<Map<String, int>> extras,
  }) async {
    final body = await ClienteApi.post(
      '/reservas/cotizar',
      body: {
        'cancha_id': canchaId,
        'fecha': fecha,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'extras': extras,
      },
    );
    return body['data'] as Map<String, dynamic>;
  }

  /// POST /reservas — crea la reserva con bloqueo de 20 minutos.
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
      throw ClienteApi.datoInvalido('Ingresa un nombre válido y DNI de 8 dígitos numéricos.');
    }

    final body = await ClienteApi.post(
      '/reservas',
      body: {
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
      },
    );
    return Reserva.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// GET /reservas?estado=&cliente_dni= — el servidor devuelve solo las del
  /// jugador logueado; el ADMIN ve todas.
  static Future<List<Reserva>> getReservas({
    String? estado,
    String? clienteDni,
  }) async {
    final body = await ClienteApi.get(
      '/reservas',
      query: {
        if (estado != null && estado.isNotEmpty) 'estado': estado,
        if (clienteDni != null && clienteDni.isNotEmpty) 'cliente_dni': clienteDni,
      },
    );
    final list = body['data'] as List<dynamic>? ?? [];
    return list.map((e) => Reserva.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PUT /reservas/:id — solo datos de contacto y notas.
  static Future<Reserva> actualizarReserva({
    required int reservaId,
    required String clienteTelefono,
    required String notas,
  }) async {
    final body = await ClienteApi.put(
      '/reservas/$reservaId',
      body: {'cliente_telefono': clienteTelefono, 'notas': notas},
    );
    return Reserva.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// DELETE /reservas/:id
  static Future<void> eliminarReserva(int reservaId) async {
    await ClienteApi.delete('/reservas/$reservaId');
  }

  /// POST /reservas/:id/cancelar — aplica la política de devolución de 24 horas.
  /// Devuelve el detalle (incluye `monto_devolucion`).
  static Future<Map<String, dynamic>> cancelarReserva({
    required int reservaId,
    required String motivo,
  }) async {
    final body = await ClienteApi.post(
      '/reservas/$reservaId/cancelar',
      body: {'motivo': motivo},
    );
    return body['data'] as Map<String, dynamic>;
  }
}

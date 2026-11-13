import 'dart:convert';

import '../../models/luxxito_models.dart';
import 'cliente_api.dart';

/// Pagos con comprobante, bandeja del ADMIN y verificación del Ticket QR.
class PagosApi {
  /// POST /reservas/:id/pagos — el jugador registra su comprobante.
  /// Devuelve la reserva actualizada (EN_REVISION, o CONFIRMADA si se autoaprobó).
  static Future<Reserva> registrarPago({
    required int reservaId,
    required String metodo,
    required String modalidad,
    required double monto,
    required String numeroOperacion,
    String? comprobanteUrl,
    bool autoAprobar = false,
  }) async {
    if (numeroOperacion.trim().length < 4) {
      throw ClienteApi.datoInvalido(
        'Ingresa un número de operación válido (mínimo 4 caracteres).',
      );
    }

    final body = await ClienteApi.post(
      '/reservas/$reservaId/pagos',
      body: {
        'metodo': metodo,
        'modalidad': modalidad,
        'monto': monto,
        'numero_operacion': numeroOperacion,
        'comprobante_url': ?comprobanteUrl,
        'auto_aprobar': autoAprobar,
      },
    );
    final data = body['data'] as Map<String, dynamic>;
    return Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
  }

  /// POST /pagos/comprobante — sube la foto del voucher al bucket privado.
  /// Devuelve la referencia `supabase://comprobantes/...` para adjuntarla al pago.
  static Future<String> subirComprobante({
    required int reservaId,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final body = await ClienteApi.post(
      '/pagos/comprobante',
      body: {
        'reserva_id': reservaId,
        'mime_type': mimeType,
        'contenido_base64': base64Encode(bytes),
      },
      tiempo: ClienteApi.timeoutSubida,
    );
    return (body['data'] as Map<String, dynamic>)['comprobante_url'] as String;
  }

  /// GET /pagos?estado= (ADMIN) — bandeja de revisión.
  static Future<List<PagoEnRevision>> listarPagos({
    String estado = 'PENDIENTE_REVISION',
  }) async {
    final body = await ClienteApi.get('/pagos', query: {'estado': estado});
    return (body['data'] as List<dynamic>)
        .map((p) => PagoEnRevision.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /pagos/:id/aprobar (ADMIN) — confirma la reserva y emite el Ticket QR.
  static Future<Reserva> aprobarPago(int pagoId) async {
    final body = await ClienteApi.patch('/pagos/$pagoId/aprobar');
    final data = body['data'] as Map<String, dynamic>;
    return Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
  }

  /// PATCH /pagos/:id/rechazar (ADMIN) — el motivo es obligatorio.
  static Future<Reserva> rechazarPago({
    required int pagoId,
    required String observacion,
  }) async {
    if (observacion.trim().length < 5) {
      throw ClienteApi.datoInvalido('Indica el motivo del rechazo (mínimo 5 caracteres).');
    }

    final body = await ClienteApi.patch(
      '/pagos/$pagoId/rechazar',
      body: {'observacion': observacion.trim()},
    );
    final data = body['data'] as Map<String, dynamic>;
    return Reserva.fromJson(data['reserva'] as Map<String, dynamic>);
  }

  /// POST /reservas/verificar-qr (ADMIN) — valida el ticket y registra el ingreso.
  static Future<Map<String, dynamic>> verificarTicketQr(String codigoQr) async {
    final clean = codigoQr.trim();
    if (clean.isEmpty || !clean.toUpperCase().startsWith('LUXXITO-QR-')) {
      throw ClienteApi.datoInvalido('Ingresa un código QR con formato LUXXITO-QR-...');
    }

    final body = await ClienteApi.post(
      '/reservas/verificar-qr',
      body: {'codigo_qr': clean},
    );
    return body['data'] as Map<String, dynamic>;
  }
}

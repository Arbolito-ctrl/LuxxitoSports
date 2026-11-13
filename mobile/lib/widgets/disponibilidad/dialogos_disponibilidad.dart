import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Confirma que el turno quedó reservado y recuerda que hay 20 minutos para pagar.
Future<void> mostrarDialogoReservaCreada(
  BuildContext context, {
  required String canchaNombre,
  required Reserva reserva,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.check_circle,
        color: LuxxitoColors.exito,
        size: 48,
      ),
      title: const Text('¡Turno reservado!'),
      content: Text(
        '$canchaNombre\n'
        '${Formato.fechaLarga(reserva.fecha)} · ${Formato.rango(reserva.horaInicio, reserva.horaFin)}\n\n'
        'Te guardamos el turno por 20 minutos. Envía tu comprobante de '
        '${Formato.soles(reserva.total)} desde "Mis reservas" para confirmarlo.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Ir a pagar'),
        ),
      ],
    ),
  );
}

/// Explica por qué no se pudo reservar. Si el servidor respondió 409, alguien
/// tomó el turno mientras tanto y se ofrece ver los horarios actualizados.
///
/// Devuelve true si el usuario pidió recargar los horarios.
Future<bool> mostrarDialogoErrorReserva(BuildContext context, Object error) async {
  final ocupado = error is ApiException && error.statusCode == 409;
  final recargar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        ocupado ? Icons.event_busy : Icons.error_outline,
        color: LuxxitoColors.error,
        size: 44,
      ),
      title: Text(
        ocupado ? 'Ese horario ya no está libre' : 'No pudimos reservar',
      ),
      content: Text(mensajeError(error), textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ocupado),
          child: Text(ocupado ? 'Ver horarios actualizados' : 'Entendido'),
        ),
      ],
    ),
  );
  return recargar == true;
}

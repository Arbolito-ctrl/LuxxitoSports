import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

// Diálogos de "Mis reservas" para editar, cancelar y eliminar una reserva.
// Cada función solo muestra el diálogo (y, si corresponde, llama a la API) y
// devuelve el resultado; la pantalla decide qué aviso mostrar y si recarga.

/// Edita el celular de contacto y las notas. Devuelve true si se guardó.
Future<bool> mostrarDialogoEditarReserva(
  BuildContext context,
  Reserva r,
) async {
  final telCtrl = TextEditingController(text: r.clienteTelefono);
  final notasCtrl = TextEditingController(text: r.notas ?? '');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Editar datos de contacto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: telCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Celular de contacto',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notasCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas para el complejo',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ApiService.actualizarReserva(
                reservaId: r.id,
                clienteTelefono: telCtrl.text.trim(),
                notas: notasCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(true);
            } catch (e) {
              if (!ctx.mounted) return;
              mostrarAviso(ctx, mensajeError(e), tipo: TipoAviso.error);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );

  return ok == true;
}

/// Confirma la cancelación mostrando cuánto se devolverá según la política de
/// 24 horas (100 % con 24 h o más de anticipación; 50 % con menos).
/// El cálculo aquí es solo informativo: el monto real lo decide el servidor.
///
/// Devuelve la respuesta del servidor (incluye `monto_devolucion`) o null si
/// el usuario no canceló.
Future<Map<String, dynamic>?> mostrarDialogoCancelarReserva(
  BuildContext context,
  Reserva r,
) async {
  final inicio = DateTime.tryParse(
    '${r.fecha}T${r.horaInicio.toString().padLeft(2, '0')}:00:00',
  );
  final horas = inicio == null
      ? 48.0
      : inicio.difference(DateTime.now()).inMinutes / 60;
  final reembolsoTotal = horas >= 24;
  final devolucion = reembolsoTotal ? r.montoPagado : r.montoPagado * 0.5;
  String motivo = 'Ya no podré asistir';

  final resultado = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        icon: const Icon(
          Icons.event_busy,
          color: LuxxitoColors.advertencia,
          size: 40,
        ),
        title: const Text('¿Cancelar esta reserva?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${r.canchaNombre} · ${Formato.fecha(r.fecha)}, ${Formato.rango(r.horaInicio, r.horaFin)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (r.montoPagado > 0)
              AvisoBanner(
                icono: reembolsoTotal
                    ? Icons.savings_outlined
                    : Icons.warning_amber,
                color: reembolsoTotal
                    ? LuxxitoColors.exito
                    : LuxxitoColors.advertencia,
                titulo: 'Te devolveremos ${Formato.soles(devolucion)}',
                texto: reembolsoTotal
                    ? 'Cancelas con más de 24 horas de anticipación: reembolso del 100%.'
                    : 'Faltan menos de 24 horas: se retiene el 50% de lo pagado.',
              )
            else
              const AvisoBanner(
                icono: Icons.info_outline,
                color: LuxxitoColors.info,
                texto: 'Aún no has pagado, así que no hay cargos.',
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: motivo,
              dropdownColor: LuxxitoColors.superficieAlta,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: const [
                'Ya no podré asistir',
                'Cambio de fecha u horario',
                'Problemas de clima',
                'Otro motivo',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setDialogState(() => motivo = v ?? motivo),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final data = await ApiService.cancelarReserva(
                  reservaId: r.id,
                  motivo: motivo,
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(data);
              } catch (e) {
                if (!ctx.mounted) return;
                mostrarAviso(ctx, mensajeError(e), tipo: TipoAviso.error);
              }
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    ),
  );

  return resultado;
}

/// Pide confirmación para eliminar la reserva del historial. Devuelve true si
/// el usuario confirma; la llamada a la API la hace la pantalla.
Future<bool> confirmarEliminarReserva(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.delete_outline,
        color: LuxxitoColors.error,
        size: 40,
      ),
      title: const Text('¿Eliminar del historial?'),
      content: const Text(
        'La reserva desaparecerá de tu lista. Esta acción no se puede deshacer.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  return ok == true;
}

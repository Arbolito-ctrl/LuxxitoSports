import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Tarjeta de una reserva en "Mis reservas": datos del turno, avisos según el
/// estado (tiempo restante, pago en revisión, ingreso registrado...) y botones
/// para pagar, ver el Ticket QR, editar, cancelar o eliminar.
///
/// Es un widget "tonto": solo muestra la reserva que recibe. Las acciones no se
/// resuelven aquí; la tarjeta avisa a la pantalla con los callbacks `on...` y es
/// la pantalla la que abre la hoja de pago, los diálogos o llama a la API.
/// Así la tarjeta no depende del estado de la pantalla y se puede reutilizar.
///
/// La cuenta regresiva se actualiza sola: la pantalla tiene un Timer que la
/// redibuja cada segundo y en cada redibujo se recalcula el tiempo restante.
class TarjetaReserva extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback onPagar;
  final VoidCallback onVerTicket;
  final VoidCallback onEditar;
  final VoidCallback onCancelar;
  final VoidCallback onEliminar;

  const TarjetaReserva({
    super.key,
    required this.reserva,
    required this.onPagar,
    required this.onVerTicket,
    required this.onEditar,
    required this.onCancelar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final r = reserva;
    final estado = EstadoReservaInfo.de(r.estado);
    final activa = r.estado != 'CANCELADA' && r.estado != 'VENCIDA';
    final saldo = double.parse((r.total - r.montoPagado).toStringAsFixed(2));
    // Pagar es una acción del jugador; el ADMIN solo revisa los comprobantes.
    final puedePagar = !ApiService.esAdmin &&
        (r.estado == 'PENDIENTE_PAGO' || (r.estado == 'CONFIRMADA' && saldo > 0));
    final tieneQr = r.codigoQr != null && r.estado == 'CONFIRMADA';
    final avisos = _avisos(r);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Encabezado: deporte, cancha, estado y menú de opciones --------
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: estado.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconoDeporte(r.deporte), color: estado.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.canchaNombre,
                        style: const TextStyle(
                          color: LuxxitoColors.texto,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${r.complejoNombre} · Reserva #${r.id}',
                        style: const TextStyle(
                          color: LuxxitoColors.textoTenue,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Insignia(
                  estado.etiqueta,
                  color: estado.color,
                  icono: estado.icono,
                ),
                _menuOpciones(activa: activa, confirmada: r.estado == 'CONFIRMADA'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Detalle del turno --------------------------------------
                  const SizedBox(height: 6),
                  DatoFila(
                    Icons.event_outlined,
                    '${Formato.fechaLarga(r.fecha)} · ${Formato.rango(r.horaInicio, r.horaFin)}',
                  ),
                  if (ApiService.esAdmin)
                    DatoFila(
                      Icons.person_outline,
                      '${r.clienteNombre} · DNI ${r.clienteDni}',
                    ),
                  if (r.extras.isNotEmpty)
                    DatoFila(
                      Icons.inventory_2_outlined,
                      r.extras
                          .map((e) => '${e.nombre} ×${e.cantidad}')
                          .join(', '),
                    ),
                  if (r.notas != null && r.notas!.isNotEmpty)
                    DatoFila(Icons.notes, r.notas!),
                  // --- Avisos según el estado ---------------------------------
                  for (final aviso in avisos) ...[
                    const SizedBox(height: 10),
                    aviso,
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 10),
                  // --- Importes y botones de acción ---------------------------
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formato.soles(r.total),
                              style: const TextStyle(
                                color: LuxxitoColors.texto,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              r.montoDevolucion > 0
                                  ? 'Reembolso: ${Formato.soles(r.montoDevolucion)}'
                                  : r.montoPagado > 0
                                  ? 'Pagado: ${Formato.soles(r.montoPagado)}'
                                  : 'Sin pagos aún',
                              style: TextStyle(
                                color: r.montoDevolucion > 0
                                    ? LuxxitoColors.advertencia
                                    : LuxxitoColors.textoTenue,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tieneQr) ...[
                        OutlinedButton.icon(
                          onPressed: onVerTicket,
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('Ticket'),
                        ),
                        if (puedePagar) const SizedBox(width: 8),
                      ],
                      if (puedePagar)
                        FilledButton.icon(
                          onPressed: onPagar,
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: Text(
                            r.montoPagado > 0 ? 'Pagar saldo' : 'Pagar',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menú "⋮": editar y cancelar solo si la reserva sigue activa; eliminar solo
  /// si no está CONFIRMADA (una confirmada se cancela para aplicar la devolución).
  Widget _menuOpciones({required bool activa, required bool confirmada}) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: const Icon(
        Icons.more_vert,
        color: LuxxitoColors.textoSecundario,
      ),
      color: LuxxitoColors.superficieAlta,
      onSelected: (accion) {
        switch (accion) {
          case 'editar':
            onEditar();
          case 'cancelar':
            onCancelar();
          case 'eliminar':
            onEliminar();
        }
      },
      itemBuilder: (_) => [
        if (activa)
          const PopupMenuItem(
            value: 'editar',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Editar contacto'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (activa)
          const PopupMenuItem(
            value: 'cancelar',
            child: ListTile(
              leading: Icon(
                Icons.event_busy,
                color: LuxxitoColors.advertencia,
              ),
              title: Text('Cancelar reserva'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (!confirmada)
          const PopupMenuItem(
            value: 'eliminar',
            child: ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: LuxxitoColors.error,
              ),
              title: Text('Eliminar del historial'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  /// Avisos que se muestran según el estado de la reserva.
  List<Widget> _avisos(Reserva r) {
    final avisos = <Widget>[];
    if (r.estado == 'PENDIENTE_PAGO') {
      // Si el admin rechazó el último comprobante, se explica el motivo
      final rechazo = r.rechazoVigente;
      if (rechazo != null) {
        avisos.add(
          AvisoBanner(
            icono: Icons.report_outlined,
            color: LuxxitoColors.error,
            titulo: 'Tu comprobante fue rechazado',
            texto:
                '${rechazo.observacion ?? 'Sin motivo indicado'}. '
                'Envía uno nuevo antes de que se libere el turno.',
          ),
        );
      }
      // Cuenta regresiva del bloqueo de 20 minutos
      final restante = _tiempoRestante(r.expiresAt);
      avisos.add(
        AvisoBanner(
          icono: Icons.timer_outlined,
          color: LuxxitoColors.advertencia,
          titulo: restante != null
              ? 'Turno guardado por $restante'
              : 'Tiempo agotado',
          texto: restante != null
              ? 'Paga y envía tu comprobante para confirmarlo.'
              : 'El turno se liberará en breve. Si aún lo quieres, reserva de nuevo.',
        ),
      );
    } else if (r.estado == 'EN_REVISION') {
      avisos.add(
        const AvisoBanner(
          icono: Icons.hourglass_top,
          color: LuxxitoColors.info,
          titulo: 'Estamos revisando tu pago',
          texto: 'Tu turno está protegido mientras confirmamos el comprobante.',
        ),
      );
    } else if (r.estado == 'CONFIRMADA' && r.qrUsadoAt != null) {
      final hora = DateTime.tryParse(r.qrUsadoAt!)?.toLocal();
      avisos.add(AvisoBanner(
        icono: Icons.how_to_reg,
        color: LuxxitoColors.exito,
        titulo: 'Ingreso registrado',
        texto: hora != null
            ? 'El ticket se validó en la entrada a las ${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}.'
            : 'El ticket ya se validó en la entrada.',
      ));
    } else if (r.estado == 'CANCELADA' && r.motivoCancelacion != null) {
      avisos.add(
        AvisoBanner(
          icono: Icons.info_outline,
          color: LuxxitoColors.textoTenue,
          texto: r.motivoCancelacion!,
        ),
      );
    }
    return avisos;
  }

  /// Tiempo que queda del bloqueo en formato mm:ss, o null si ya venció.
  String? _tiempoRestante(String expiresAtIso) {
    final exp = DateTime.tryParse(expiresAtIso);
    if (exp == null) return null;
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) return null;
    final mins = diff.inMinutes.toString().padLeft(2, '0');
    final secs = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

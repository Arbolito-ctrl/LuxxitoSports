import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Muestra el Ticket QR de una reserva CONFIRMADA para presentarlo en la entrada.
///
/// El backend solo guarda el texto del código (LUXXITO-QR-...); aquí el paquete
/// qr_flutter lo dibuja como imagen. Debajo se muestra el mismo texto por si el
/// operador necesita escribirlo a mano, y los datos del turno.
void mostrarTicketQr(BuildContext context, Reserva r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu ticket de ingreso',
              style: TextStyle(
                color: LuxxitoColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Muestra este código en la entrada del complejo.',
              style: TextStyle(color: LuxxitoColors.textoSecundario),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LuxxitoColors.texto,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: r.codigoQr!,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              r.codigoQr!,
              style: const TextStyle(
                color: LuxxitoColors.textoSecundario,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    DatoFila(
                      Icons.stadium_outlined,
                      '${r.canchaNombre} · ${r.complejoNombre}',
                    ),
                    DatoFila(
                      Icons.event_outlined,
                      '${Formato.fechaLarga(r.fecha)} · ${Formato.rango(r.horaInicio, r.horaFin)}',
                    ),
                    DatoFila(
                      Icons.person_outline,
                      '${r.clienteNombre} · DNI ${r.clienteDni}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

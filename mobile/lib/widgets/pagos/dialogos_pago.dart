import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';
import 'formato_pago.dart';

/// Mínimo de caracteres del motivo de rechazo (el backend exige lo mismo).
const int minObservacionRechazo = 5;

const List<String> _motivosFrecuentes = [
  'El monto no coincide con la reserva',
  'Comprobante ilegible o recortado',
  'Número de operación inválido',
  'El pago no se refleja en la cuenta',
];

/// Pide confirmación antes de aprobar un pago. Devuelve true si el ADMIN acepta.
Future<bool> confirmarAprobacionPago(
  BuildContext context,
  PagoEnRevision item,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LuxxitoColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const Icon(Icons.verified, color: LuxxitoColors.primario, size: 40),
      title: const Text(
        '¿Aprobar este pago?',
        style: TextStyle(color: LuxxitoColors.texto, fontSize: 18),
      ),
      content: Text(
        'Confirmaremos la reserva de ${item.clienteNombre} '
        '(${fechaLegiblePago(item.fecha)}, ${horaPago(item.horaInicio)}) '
        'y le enviaremos su Ticket QR por S/ ${item.pago.monto.toStringAsFixed(2)}.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: LuxxitoColors.textoSecundario,
          height: 1.4,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: LuxxitoColors.primario,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.check),
          label: const Text('Sí, aprobar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Hoja para escribir (o elegir de una lista) el motivo del rechazo.
/// El jugador verá ese motivo en "Mis reservas".
///
/// Devuelve el motivo (mínimo [minObservacionRechazo] caracteres) o null si
/// el ADMIN cerró la hoja sin rechazar.
Future<String?> pedirMotivoRechazo(
  BuildContext context,
  PagoEnRevision item,
) {
  final obsCtrl = TextEditingController();
  String? errorObs;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LuxxitoColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + espacioInferior(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LuxxitoColors.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rechazar comprobante',
              style: TextStyle(
                color: LuxxitoColors.texto,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.clienteNombre} verá este motivo y podrá enviar un nuevo comprobante.',
              style: const TextStyle(
                color: LuxxitoColors.textoSecundario,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            // Motivos frecuentes: un toque los copia en el campo de texto
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _motivosFrecuentes
                  .map(
                    (m) => ActionChip(
                      label: Text(m, style: const TextStyle(fontSize: 12)),
                      backgroundColor: LuxxitoColors.fondo,
                      labelStyle: const TextStyle(
                        color: LuxxitoColors.textoSecundario,
                      ),
                      side: const BorderSide(color: LuxxitoColors.borde),
                      onPressed: () => setSheetState(() {
                        obsCtrl.text = m;
                        errorObs = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: obsCtrl,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(color: LuxxitoColors.texto),
              onChanged: (_) {
                if (errorObs != null) setSheetState(() => errorObs = null);
              },
              decoration: InputDecoration(
                hintText: 'Escribe o elige un motivo…',
                hintStyle: const TextStyle(color: LuxxitoColors.textoTenue),
                filled: true,
                fillColor: LuxxitoColors.fondo,
                errorText: errorObs,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: LuxxitoColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final texto = obsCtrl.text.trim();
                  if (texto.length < minObservacionRechazo) {
                    setSheetState(
                      () => errorObs =
                          'Cuéntale al jugador qué falló (mínimo $minObservacionRechazo caracteres).',
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(texto);
                },
                icon: const Icon(Icons.block),
                label: const Text('Rechazar y notificar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

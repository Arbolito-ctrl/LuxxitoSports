import 'package:flutter/material.dart';

import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Barra fija inferior con el horario elegido, el total y el botón "Reservar".
class BarraReserva extends StatelessWidget {
  /// Texto de la fecha y el horario elegidos, o null si aún no se eligió horario.
  final String? textoHorario;

  /// Total de la cotización del servidor; null mientras no haya cotización.
  final num? total;

  /// Se desactiva el botón mientras se recalcula el precio.
  final bool cotizando;

  /// Muestra el indicador de carga en el botón mientras se crea la reserva.
  final bool enviando;
  final VoidCallback onReservar;

  const BarraReserva({
    super.key,
    required this.textoHorario,
    required this.total,
    required this.cotizando,
    required this.enviando,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    final hayHorario = textoHorario != null;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + espacioInferior(context)),
      decoration: const BoxDecoration(
        color: LuxxitoColors.superficie,
        border: Border(top: BorderSide(color: LuxxitoColors.borde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textoHorario ?? 'Elige un horario',
                  style: const TextStyle(
                    color: LuxxitoColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  total != null ? Formato.soles(total) : '—',
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            // Solo se puede reservar con horario, precio calculado y sin otra acción en curso
            onPressed: hayHorario && total != null && !enviando && !cotizando
                ? onReservar
                : null,
            icon: enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_clock),
            label: Text(enviando ? 'Reservando…' : 'Reservar'),
          ),
        ],
      ),
    );
  }
}

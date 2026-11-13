import 'package:flutter/material.dart';

import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Resumen del precio que calculó el servidor (POST /reservas/cotizar):
/// cancha, extras, total y cuánto sería el adelanto del 50 %.
///
/// La app nunca calcula el precio por su cuenta; solo muestra la cotización.
/// Mientras se recalcula ([cotizando]) el resumen anterior se ve atenuado.
class ResumenCotizacion extends StatelessWidget {
  /// Respuesta de la cotización, o null si todavía no hay ninguna.
  final Map<String, dynamic>? cotizacion;
  final bool cotizando;

  const ResumenCotizacion({
    super.key,
    required this.cotizacion,
    required this.cotizando,
  });

  @override
  Widget build(BuildContext context) {
    final q = cotizacion;
    if (cotizando && q == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (q == null) return const SizedBox.shrink();

    Widget fila(String etiqueta, num monto, {bool destacado = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    color: destacado
                        ? LuxxitoColors.texto
                        : LuxxitoColors.textoSecundario,
                    fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
                    fontSize: destacado ? 16 : 14,
                  ),
                ),
              ),
              Text(
                Formato.soles(monto),
                style: TextStyle(
                  color: LuxxitoColors.texto,
                  fontWeight: destacado ? FontWeight.bold : FontWeight.w500,
                  fontSize: destacado ? 18 : 14,
                ),
              ),
            ],
          ),
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: cotizando ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              fila(
                'Cancha · ${q['duracion_horas']} h (${Formato.rango((q['hora_inicio'] as num).toInt(), (q['hora_fin'] as num).toInt())})',
                q['subtotal_cancha'] as num,
              ),
              if ((q['subtotal_extras'] as num) > 0)
                fila('Extras', q['subtotal_extras'] as num),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              fila('Total', q['total'] as num, destacado: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: LuxxitoColors.textoTenue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Puedes adelantar solo el 50% (${Formato.soles(q['monto_sena_50'] as num)}) y pagar el resto en el complejo.',
                      style: const TextStyle(
                        color: LuxxitoColors.textoTenue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

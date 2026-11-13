import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Cabecera de la pantalla de reserva: foto, deporte, superficie, dirección y
/// las tarifas de día y de noche de la cancha.
class CabeceraCancha extends StatelessWidget {
  final Cancha cancha;

  /// Complejo que devuelve la consulta de disponibilidad; si aún no llegó, se
  /// usan los datos resumidos que ya trae la cancha.
  final Complejo? complejo;

  const CabeceraCancha({super.key, required this.cancha, this.complejo});

  @override
  Widget build(BuildContext context) {
    final complejo = this.complejo;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FotoComplejo(
            url: cancha.imagenUrl ?? complejo?.imagenUrl,
            iconoRespaldo: iconoDeporte(cancha.deporte),
            height: 140,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LuxxitoColors.primario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconoDeporte(cancha.deporte),
                    color: LuxxitoColors.primario,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cancha.deporte} · ${cancha.superficie}',
                        style: const TextStyle(
                          color: LuxxitoColors.texto,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complejo != null && complejo.direccion.isNotEmpty
                            ? '${complejo.nombre} · ${complejo.direccion}'
                            : '${cancha.complejoNombre} · ${cancha.distrito}',
                        style: const TextStyle(
                          color: LuxxitoColors.textoSecundario,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Insignia(
                            'Día S/ ${cancha.precioHoraDiurno.toStringAsFixed(0)}',
                            color: LuxxitoColors.secundario,
                            icono: Icons.wb_sunny_outlined,
                          ),
                          Insignia(
                            'Noche S/ ${cancha.precioHoraNocturno.toStringAsFixed(0)}',
                            color: LuxxitoColors.nocturno,
                            icono: Icons.nightlight_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

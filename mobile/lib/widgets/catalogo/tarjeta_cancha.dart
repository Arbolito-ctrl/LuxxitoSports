import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Tarjeta de una cancha en el catálogo: foto, deporte, ubicación, características
/// (superficie, techada, iluminación) y precio desde la tarifa de día.
///
/// Tiene dos modos:
/// - Jugador: la tarjeta y el botón "Reservar" abren la reserva (si está ACTIVA).
/// - Gestión (ADMIN): muestra si está activa y el botón "Cambiar foto".
class TarjetaCancha extends StatelessWidget {
  final Cancha cancha;

  /// Foto del complejo, que se usa si la cancha no tiene foto propia.
  final String? fotoComplejo;
  final bool modoGestion;
  final VoidCallback onReservar;
  final VoidCallback onCambiarFoto;

  const TarjetaCancha({
    super.key,
    required this.cancha,
    required this.fotoComplejo,
    required this.modoGestion,
    required this.onReservar,
    required this.onCambiarFoto,
  });

  @override
  Widget build(BuildContext context) {
    final activa = cancha.estado == 'ACTIVA';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activa && !modoGestion ? onReservar : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Foto con la etiqueta del deporte ------------------------------
            Stack(
              children: [
                FotoComplejo(
                  url: cancha.imagenUrl ?? fotoComplejo,
                  iconoRespaldo: iconoDeporte(cancha.deporte),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconoDeporte(cancha.deporte),
                          size: 14,
                          color: LuxxitoColors.texto,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          cancha.deporte,
                          style: const TextStyle(
                            color: LuxxitoColors.texto,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                cancha.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LuxxitoColors.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatoFila(
                    Icons.location_on_outlined,
                    '${cancha.complejoNombre} · ${cancha.distrito}',
                  ),
                  // --- Características ------------------------------------------
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Insignia(
                        cancha.superficie,
                        color: LuxxitoColors.textoSecundario,
                        icono: Icons.grass,
                      ),
                      Insignia(
                        cancha.techada ? 'Techada' : 'Aire libre',
                        color: LuxxitoColors.secundario,
                        icono: cancha.techada
                            ? Icons.roofing
                            : Icons.wb_sunny_outlined,
                      ),
                      if (cancha.iluminacion)
                        const Insignia(
                          'Iluminación',
                          color: LuxxitoColors.advertencia,
                          icono: Icons.lightbulb_outline,
                        ),
                      if (!activa)
                        const Insignia(
                          'En mantenimiento',
                          color: LuxxitoColors.error,
                          icono: Icons.construction,
                        ),
                    ],
                  ),
                  // --- Precio y acción ------------------------------------------
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Desde ',
                                    style: TextStyle(
                                      color: LuxxitoColors.textoSecundario,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        'S/ ${cancha.precioHoraDiurno.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: LuxxitoColors.texto,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' /hora',
                                    style: TextStyle(
                                      color: LuxxitoColors.textoSecundario,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Noche (desde 18:00): S/ ${cancha.precioHoraNocturno.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: LuxxitoColors.textoTenue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (modoGestion)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Insignia(
                              activa ? 'Activa' : 'Inactiva',
                              color: activa
                                  ? LuxxitoColors.exito
                                  : LuxxitoColors.error,
                              icono: activa ? Icons.check_circle : Icons.block,
                            ),
                            TextButton.icon(
                              onPressed: onCambiarFoto,
                              icon: const Icon(
                                Icons.add_a_photo_outlined,
                                size: 18,
                              ),
                              label: const Text('Cambiar foto'),
                            ),
                          ],
                        )
                      else
                        FilledButton.icon(
                          onPressed: activa ? onReservar : null,
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Reservar'),
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
}

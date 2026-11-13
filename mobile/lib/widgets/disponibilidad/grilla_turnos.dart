import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Leyenda de colores de la grilla: libre, tu selección y no disponible.
class LeyendaTurnos extends StatelessWidget {
  const LeyendaTurnos({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(color: LuxxitoColors.textoTenue, fontSize: 12),
        ),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(LuxxitoColors.superficieAlta, 'Libre'),
        item(LuxxitoColors.primario, 'Tu selección'),
        item(LuxxitoColors.error.withValues(alpha: 0.5), 'No disponible'),
      ],
    );
  }
}

/// Grilla de horarios del día en 3 columnas. Cada turno muestra la hora, el
/// precio (con una luna si es tarifa nocturna) o por qué no está disponible.
///
/// La selección (desde [horaInicioSel] hasta [horaFinSel]) la maneja la pantalla:
/// la grilla solo la pinta y avisa con [onSeleccionar] qué turno libre se tocó.
class GrillaTurnos extends StatelessWidget {
  final List<TurnoDisponibilidad> turnos;
  final int? horaInicioSel;
  final int? horaFinSel;
  final ValueChanged<TurnoDisponibilidad> onSeleccionar;

  const GrillaTurnos({
    super.key,
    required this.turnos,
    required this.horaInicioSel,
    required this.horaFinSel,
    required this.onSeleccionar,
  });

  /// Texto que se muestra en lugar del precio cuando el turno no se puede tomar.
  String _etiquetaNoDisponible(String estado) {
    switch (estado) {
      case 'OCUPADA':
        return 'Ocupado';
      case 'BLOQUEADA':
        return 'Reservándose';
      case 'MANTENIMIENTO':
        return 'Mantenimiento';
      case 'PASADA':
        return 'Ya pasó';
      default:
        return 'No disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (turnos.isEmpty) {
      return const AvisoBanner(
        icono: Icons.event_busy,
        color: LuxxitoColors.advertencia,
        texto: 'No hay horarios publicados para este día.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ancho de cada casilla para que entren exactamente 3 por fila
        const columnas = 3;
        const espacio = 10.0;
        final ancho =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: turnos.map((turno) {
            final libre = turno.estado == 'DISPONIBLE';
            final seleccionado =
                horaInicioSel != null &&
                turno.horaInicio >= horaInicioSel! &&
                turno.horaFin <= horaFinSel!;
            final nocturno = turno.tarifaTipo == 'NOCTURNA';

            final fondo = seleccionado
                ? LuxxitoColors.primario
                : libre
                ? LuxxitoColors.superficie
                : LuxxitoColors.error.withValues(alpha: 0.08);
            final colorTexto = seleccionado
                ? Colors.white
                : libre
                ? LuxxitoColors.texto
                : LuxxitoColors.textoTenue;

            return InkWell(
              onTap: libre ? () => onSeleccionar(turno) : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: ancho,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: seleccionado
                        ? LuxxitoColors.primario
                        : libre
                        ? LuxxitoColors.borde
                        : LuxxitoColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (nocturno && libre) ...[
                          Icon(
                            Icons.nightlight_round,
                            size: 12,
                            color: seleccionado
                                ? Colors.white70
                                : LuxxitoColors.nocturno,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          Formato.hora(turno.horaInicio),
                          style: TextStyle(
                            color: colorTexto,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: libre
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      libre
                          ? 'S/ ${turno.precio.toStringAsFixed(0)}'
                          : _etiquetaNoDisponible(turno.estado),
                      style: TextStyle(
                        color: seleccionado
                            ? Colors.white70
                            : LuxxitoColors.textoTenue,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

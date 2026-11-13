import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Lista de extras del complejo (chalecos, balones, árbitro...) con botones
/// − / + para elegir la cantidad.
///
/// No se puede agregar más de lo que queda en stock para ese horario, y el
/// botón + está desactivado hasta que se elija un horario ([hayHorario]),
/// porque el stock depende de las horas. Las cantidades las guarda la pantalla.
class SelectorExtras extends StatelessWidget {
  final List<ExtraItem> extras;

  /// Cantidad elegida por cada extra (clave: id del extra).
  final Map<int, int> cantidades;
  final bool hayHorario;

  /// Se llama con el id del extra y la nueva cantidad.
  final void Function(int extraId, int cantidad) onCambiar;

  const SelectorExtras({
    super.key,
    required this.extras,
    required this.cantidades,
    required this.hayHorario,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) {
      return const Text(
        'Este complejo no ofrece extras por ahora.',
        style: TextStyle(color: LuxxitoColors.textoTenue),
      );
    }
    final sinHorario = !hayHorario;
    return Column(
      children: extras.map((extra) {
        final cant = cantidades[extra.id] ?? 0;
        final agotado = extra.stockDisponible <= 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extra.nombre,
                          style: const TextStyle(
                            color: LuxxitoColors.texto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agotado
                              ? 'Agotado para este horario'
                              : '${Formato.soles(extra.precioUnitario)} c/u · quedan ${extra.stockDisponible}',
                          style: TextStyle(
                            color: agotado
                                ? LuxxitoColors.error
                                : LuxxitoColors.textoTenue,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.remove_circle_outline),
                    color: LuxxitoColors.textoSecundario,
                    onPressed: cant > 0
                        ? () => onCambiar(extra.id, cant - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$cant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cant > 0
                            ? LuxxitoColors.primario
                            : LuxxitoColors.textoTenue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: sinHorario
                        ? 'Elige primero un horario'
                        : 'Agregar',
                    icon: const Icon(Icons.add_circle),
                    color: LuxxitoColors.primario,
                    onPressed: !sinHorario && cant < extra.stockDisponible
                        ? () => onCambiar(extra.id, cant + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

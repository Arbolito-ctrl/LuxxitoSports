import 'package:flutter/material.dart';

import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Convierte una fecha al formato que espera la API: YYYY-MM-DD.
String fechaIso(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Fila horizontal con los próximos 8 días (hoy incluido) para elegir la fecha.
class SelectorFechas extends StatelessWidget {
  /// Fecha elegida en formato YYYY-MM-DD.
  final String fechaSeleccionada;

  /// Se llama con la nueva fecha (YYYY-MM-DD) solo si es distinta de la actual.
  final ValueChanged<String> onSeleccionar;

  const SelectorFechas({
    super.key,
    required this.fechaSeleccionada,
    required this.onSeleccionar,
  });

  List<DateTime> _proximosDias() {
    final hoy = DateTime.now();
    return List.generate(8, (i) => DateTime(hoy.year, hoy.month, hoy.day + i));
  }

  @override
  Widget build(BuildContext context) {
    final dias = _proximosDias();
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final d = dias[idx];
          final iso = fechaIso(d);
          final activo = iso == fechaSeleccionada;
          final etiqueta = idx == 0
              ? 'Hoy'
              : idx == 1
              ? 'Mañana'
              : Formato.diaSemana(d);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (activo) return;
              onSeleccionar(iso);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              decoration: BoxDecoration(
                color: activo
                    ? LuxxitoColors.primario
                    : LuxxitoColors.superficie,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: activo ? LuxxitoColors.primario : LuxxitoColors.borde,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    etiqueta,
                    style: TextStyle(
                      color: activo
                          ? Colors.white
                          : LuxxitoColors.textoSecundario,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      color: activo ? Colors.white : LuxxitoColors.texto,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    Formato.mesCorto(d),
                    style: TextStyle(
                      color: activo ? Colors.white70 : LuxxitoColors.textoTenue,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

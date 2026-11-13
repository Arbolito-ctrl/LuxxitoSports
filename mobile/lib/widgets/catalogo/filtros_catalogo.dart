import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Encabezado del catálogo: saludo (o título en modo gestión) y dos filas de
/// chips para filtrar por distrito y por deporte. El valor '' significa "todos".
class FiltrosCatalogo extends StatelessWidget {
  final bool modoGestion;
  final List<String> distritos;
  final List<String> deportes;
  final String distritoSeleccionado;
  final String deporteSeleccionado;
  final ValueChanged<String> onDistrito;
  final ValueChanged<String> onDeporte;

  const FiltrosCatalogo({
    super.key,
    required this.modoGestion,
    required this.distritos,
    required this.deportes,
    required this.distritoSeleccionado,
    required this.deporteSeleccionado,
    required this.onDistrito,
    required this.onDeporte,
  });

  @override
  Widget build(BuildContext context) {
    // Primer nombre del jugador para el saludo
    final nombre = ApiService.currentSession?.nombre.split(' ').first ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modoGestion
                ? 'Catálogo de canchas'
                : nombre.isEmpty
                ? '¡Hola!'
                : '¡Hola, $nombre!',
            style: const TextStyle(
              color: LuxxitoColors.texto,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            modoGestion
                ? 'Revisa precios y estado de cada cancha, o publica una nueva.'
                : '¿Dónde y a qué juegas hoy?',
            style: const TextStyle(color: LuxxitoColors.textoSecundario),
          ),
          const SizedBox(height: 14),
          _FilaChips(
            opciones: distritos,
            seleccion: distritoSeleccionado,
            etiquetaTodos: 'Todo Lima',
            icono: (_) => Icons.location_on_outlined,
            onSeleccion: onDistrito,
          ),
          const SizedBox(height: 8),
          _FilaChips(
            opciones: deportes,
            seleccion: deporteSeleccionado,
            etiquetaTodos: 'Todos los deportes',
            icono: (d) => d.isEmpty ? Icons.sports : iconoDeporte(d),
            onSeleccion: onDeporte,
          ),
        ],
      ),
    );
  }
}

/// Fila deslizable de chips donde solo uno puede estar elegido.
class _FilaChips extends StatelessWidget {
  final List<String> opciones;
  final String seleccion;
  final String etiquetaTodos;
  final IconData Function(String) icono;
  final ValueChanged<String> onSeleccion;

  const _FilaChips({
    required this.opciones,
    required this.seleccion,
    required this.etiquetaTodos,
    required this.icono,
    required this.onSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final valor = opciones[idx];
          final sel = valor == seleccion;
          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              icono(valor),
              size: 16,
              color: sel ? Colors.white : LuxxitoColors.textoSecundario,
            ),
            label: Text(valor.isEmpty ? etiquetaTodos : valor),
            selected: sel,
            onSelected: (_) => onSeleccion(valor),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';

// =============================================================================
// Formato amigable en español (fechas, horas y montos)
// =============================================================================

class Formato {
  Formato._();

  static const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _diasLargos = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  static const _mesesLargos = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// "2026-11-12" -> "jue 12 nov"
  static String fecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_diasCortos[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
  }

  /// "2026-11-12" -> "Jueves 12 de noviembre"
  static String fechaLarga(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final dia = _diasLargos[d.weekday - 1];
    return '${dia[0].toUpperCase()}${dia.substring(1)} ${d.day} de ${_mesesLargos[d.month - 1]}';
  }

  static String diaSemana(DateTime d) => _diasCortos[d.weekday - 1];
  static String mesCorto(DateTime d) => _meses[d.month - 1];

  static String hora(int h) => '${h.toString().padLeft(2, '0')}:00';

  static String rango(int inicio, int fin) => '${hora(inicio)} – ${hora(fin)}';

  static String soles(num monto) => 'S/ ${monto.toStringAsFixed(2)}';

  static String iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final ini = partes.take(2).map((p) => p[0].toUpperCase()).join();
    return ini.isEmpty ? '?' : ini;
  }
}

/// Mensaje legible para el usuario a partir de cualquier error.
String mensajeError(Object e) => e is ApiException ? e.message : e.toString();

IconData iconoDeporte(String deporte) {
  final d = deporte.toLowerCase();
  if (d.contains('futbol') || d.contains('fútbol')) return Icons.sports_soccer;
  if (d.contains('voley') || d.contains('vóley')) {
    return Icons.sports_volleyball;
  }
  if (d.contains('padel') || d.contains('pádel')) return Icons.sports_tennis;
  if (d.contains('tenis')) return Icons.sports_tennis;
  if (d.contains('basquet') || d.contains('básquet')) {
    return Icons.sports_basketball;
  }
  return Icons.sports;
}

// =============================================================================
// Estados de reserva con etiqueta, color e ícono para el usuario
// =============================================================================

class EstadoReservaInfo {
  final String etiqueta;
  final Color color;
  final IconData icono;

  const EstadoReservaInfo(this.etiqueta, this.color, this.icono);

  static EstadoReservaInfo de(String estado) {
    switch (estado) {
      case 'PENDIENTE_PAGO':
        return const EstadoReservaInfo(
          'Por pagar',
          LuxxitoColors.advertencia,
          Icons.schedule,
        );
      case 'EN_REVISION':
        return const EstadoReservaInfo(
          'En revisión',
          LuxxitoColors.info,
          Icons.hourglass_top,
        );
      case 'CONFIRMADA':
        return const EstadoReservaInfo(
          'Confirmada',
          LuxxitoColors.exito,
          Icons.check_circle,
        );
      case 'CANCELADA':
        return const EstadoReservaInfo(
          'Cancelada',
          LuxxitoColors.error,
          Icons.cancel,
        );
      case 'VENCIDA':
        return const EstadoReservaInfo(
          'Vencida',
          LuxxitoColors.textoTenue,
          Icons.timer_off,
        );
      default:
        return EstadoReservaInfo(estado, Colors.grey, Icons.info_outline);
    }
  }
}

// =============================================================================
// Componentes visuales reutilizables
// =============================================================================

enum TipoAviso { exito, error, info }

void mostrarAviso(
  BuildContext context,
  String mensaje, {
  TipoAviso tipo = TipoAviso.exito,
}) {
  final (color, icono) = switch (tipo) {
    TipoAviso.exito => (const Color(0xFF059669), Icons.check_circle),
    TipoAviso.error => (const Color(0xFFDC2626), Icons.error_outline),
    TipoAviso.info => (LuxxitoColors.texto, Icons.info_outline),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
      ),
    );
}

/// Pantalla completa de carga, vacío o error. Es desplazable para que funcione
/// dentro de un RefreshIndicator.
class EstadoVista extends StatelessWidget {
  final IconData? icono;
  final Color color;
  final String titulo;
  final String? detalle;
  final Widget? accion;
  final bool cargando;

  const EstadoVista({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
    this.color = LuxxitoColors.primario,
  }) : cargando = false;

  const EstadoVista.cargando({super.key, this.titulo = 'Cargando…'})
    : icono = null,
      detalle = null,
      accion = null,
      color = LuxxitoColors.primario,
      cargando = true;

  factory EstadoVista.error({
    Key? key,
    required String mensaje,
    required VoidCallback onReintentar,
    String titulo = 'Algo salió mal',
  }) {
    return EstadoVista(
      key: key,
      icono: Icons.wifi_off_rounded,
      color: LuxxitoColors.error,
      titulo: titulo,
      detalle: mensaje,
      accion: FilledButton.icon(
        onPressed: onReintentar,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
            minWidth: constraints.maxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cargando)
                  const CircularProgressIndicator()
                else
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icono, size: 36, color: color),
                  ),
                const SizedBox(height: 18),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cargando
                        ? LuxxitoColors.textoSecundario
                        : LuxxitoColors.texto,
                    fontSize: cargando ? 14 : 18,
                    fontWeight: cargando ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                if (detalle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    detalle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LuxxitoColors.textoSecundario,
                      height: 1.4,
                    ),
                  ),
                ],
                if (accion != null) ...[const SizedBox(height: 20), accion!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta pequeña de color (estado, deporte, características).
class Insignia extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;

  const Insignia(this.texto, {super.key, required this.color, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje destacado dentro de una tarjeta (avisos, temporizador, rechazo).
class AvisoBanner extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;
  final String? titulo;

  const AvisoBanner({
    super.key,
    required this.icono,
    required this.color,
    required this.texto,
    this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      titulo!,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Text(
                  texto,
                  style: const TextStyle(
                    color: LuxxitoColors.textoSecundario,
                    fontSize: 13,
                    height: 1.35,
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

/// Encabezado de sección con subtítulo opcional.
class SeccionTitulo extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  const SeccionTitulo(this.titulo, {super.key, this.subtitulo, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: const TextStyle(
                      color: LuxxitoColors.textoTenue,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Fila "ícono + texto" para detalles dentro de tarjetas.
class DatoFila extends StatelessWidget {
  final IconData icono;
  final String texto;

  const DatoFila(this.icono, this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: LuxxitoColors.textoTenue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: LuxxitoColors.textoSecundario,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto del complejo con respaldo neutro si no hay URL o la imagen no carga.
class FotoComplejo extends StatelessWidget {
  final String? url;
  final IconData iconoRespaldo;
  final double height;

  const FotoComplejo({
    super.key,
    required this.url,
    this.iconoRespaldo = Icons.sports_soccer,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final respaldo = Container(
      height: height,
      color: LuxxitoColors.superficieAlta,
      alignment: Alignment.center,
      child: Icon(iconoRespaldo, size: 44, color: LuxxitoColors.textoTenue),
    );
    if (url == null || url!.isEmpty) return respaldo;
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => respaldo,
      loadingBuilder: (_, child, progreso) => progreso == null
          ? child
          : Container(height: height, color: LuxxitoColors.superficieAlta),
    );
  }
}

/// Espacio inferior para hojas y barras: el mayor entre el teclado abierto y
/// la barra de navegación del sistema (gestos o botones de Android).
double espacioInferior(BuildContext context) {
  final teclado = MediaQuery.viewInsetsOf(context).bottom;
  final sistema = MediaQuery.viewPaddingOf(context).bottom;
  return teclado > sistema ? teclado : sistema;
}

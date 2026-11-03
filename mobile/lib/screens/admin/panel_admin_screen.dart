import 'package:flutter/material.dart';
import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../../widgets/luxxito_widgets.dart';

/// Inicio del ADMIN: resumen del día y accesos rápidos a las tareas del operador.
class PanelAdminScreen extends StatefulWidget {
  final VoidCallback onIrAPagos;
  final VoidCallback onIrAIngreso;
  final VoidCallback onIrAReservas;
  final VoidCallback onVerCatalogo;

  const PanelAdminScreen({
    super.key,
    required this.onIrAPagos,
    required this.onIrAIngreso,
    required this.onIrAReservas,
    required this.onVerCatalogo,
  });

  @override
  State<PanelAdminScreen> createState() => PanelAdminScreenState();
}

class PanelAdminScreenState extends State<PanelAdminScreen> {
  static const _activas = {'PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'};

  List<Reserva> _reservas = [];
  int _pagosPendientes = 0;
  bool _cargando = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService.getReservas(),
        ApiService.listarPagos(),
      ]);
      if (!mounted) return;
      setState(() {
        _reservas = resultados[0] as List<Reserva>;
        _pagosPendientes = (resultados[1] as List).length;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = mensajeError(e);
        _cargando = false;
      });
    }
  }

  String get _hoyIso {
    final h = DateTime.now();
    return '${h.year}-${h.month.toString().padLeft(2, '0')}-${h.day.toString().padLeft(2, '0')}';
  }

  Widget _indicador({
    required IconData icono,
    required Color color,
    required String valor,
    required String etiqueta,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color),
                const SizedBox(height: 10),
                Text(
                  valor,
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  etiqueta,
                  style: const TextStyle(color: LuxxitoColors.textoSecundario, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _accion(IconData icono, String texto, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 18),
        label: Text(texto, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _filaTurno(Reserva r) {
    final estado = EstadoReservaInfo.de(r.estado);
    final ingreso = r.qrUsadoAt != null;
    return ListTile(
      leading: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: LuxxitoColors.superficieAlta,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formato.hora(r.horaInicio),
              style: const TextStyle(fontWeight: FontWeight.w700, color: LuxxitoColors.texto),
            ),
            Text(
              Formato.hora(r.horaFin),
              style: const TextStyle(fontSize: 11, color: LuxxitoColors.textoTenue),
            ),
          ],
        ),
      ),
      title: Text(r.canchaNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        r.clienteNombre,
        style: const TextStyle(color: LuxxitoColors.textoSecundario),
      ),
      trailing: ingreso
          ? const Insignia('Ingresó', color: LuxxitoColors.exito, icono: Icons.how_to_reg)
          : Insignia(estado.etiqueta, color: estado.color, icono: estado.icono),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _reservas.isEmpty) {
      return const EstadoVista.cargando(titulo: 'Preparando el resumen del día…');
    }
    if (_errorMsg != null) {
      return EstadoVista.error(
        titulo: 'No pudimos cargar el panel',
        mensaje: _errorMsg!,
        onReintentar: recargar,
      );
    }

    final hoy = _hoyIso;
    final turnosHoy = _reservas
        .where((r) => r.fecha == hoy && _activas.contains(r.estado))
        .toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    final cobradoHoy = _reservas
        .where((r) => r.fecha == hoy && r.estado == 'CONFIRMADA')
        .fold<double>(0, (total, r) => total + r.montoPagado);
    final porPagar = _reservas.where((r) => r.estado == 'PENDIENTE_PAGO').length;
    final ingresaron = turnosHoy.where((r) => r.qrUsadoAt != null).length;

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            Formato.fechaLarga(hoy),
            style: const TextStyle(color: LuxxitoColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _indicador(
                icono: Icons.fact_check_outlined,
                color: _pagosPendientes > 0 ? LuxxitoColors.advertencia : LuxxitoColors.exito,
                valor: '$_pagosPendientes',
                etiqueta: _pagosPendientes == 1 ? 'pago por revisar' : 'pagos por revisar',
                onTap: widget.onIrAPagos,
              ),
              const SizedBox(width: 10),
              _indicador(
                icono: Icons.event_available,
                color: LuxxitoColors.secundario,
                valor: '${turnosHoy.length}',
                etiqueta: turnosHoy.length == 1 ? 'turno hoy' : 'turnos hoy',
                onTap: widget.onIrAReservas,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _indicador(
                icono: Icons.payments_outlined,
                color: LuxxitoColors.exito,
                valor: Formato.soles(cobradoHoy),
                etiqueta: 'cobrado en turnos de hoy',
              ),
              const SizedBox(width: 10),
              _indicador(
                icono: Icons.schedule,
                color: LuxxitoColors.advertencia,
                valor: '$porPagar',
                etiqueta: porPagar == 1 ? 'reserva por pagar' : 'reservas por pagar',
                onTap: widget.onIrAReservas,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _accion(Icons.qr_code_scanner, 'Verificar QR', widget.onIrAIngreso),
              const SizedBox(width: 10),
              _accion(Icons.stadium_outlined, 'Canchas', widget.onVerCatalogo),
            ],
          ),
          const SizedBox(height: 22),
          SeccionTitulo(
            'Turnos de hoy',
            subtitulo: turnosHoy.isEmpty
                ? null
                : '$ingresaron de ${turnosHoy.length} ya ingresaron',
          ),
          if (turnosHoy.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No hay turnos reservados para hoy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LuxxitoColors.textoSecundario),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < turnosHoy.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _filaTurno(turnosHoy[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

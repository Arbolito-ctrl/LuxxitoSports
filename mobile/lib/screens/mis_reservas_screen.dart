import 'dart:async';

import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';
import '../widgets/reservas/dialogos_reserva.dart';
import '../widgets/reservas/hoja_pago.dart';
import '../widgets/reservas/tarjeta_reserva.dart';
import '../widgets/reservas/ticket_qr_sheet.dart';

class MisReservasScreen extends StatefulWidget {
  final VoidCallback? onExplorar;

  const MisReservasScreen({super.key, this.onExplorar});

  @override
  State<MisReservasScreen> createState() => MisReservasScreenState();
}

class MisReservasScreenState extends State<MisReservasScreen>
    with WidgetsBindingObserver {
  List<Reserva> _reservas = [];
  bool _cargando = true;
  String? _errorMsg;
  String _estadoFiltro = '';
  Timer? _countdownTimer;

  static const List<(String, String)> _filtros = [
    ('', 'Todas'),
    ('PENDIENTE_PAGO', 'Por pagar'),
    ('EN_REVISION', 'En revisión'),
    ('CONFIRMADA', 'Confirmadas'),
    ('CANCELADA', 'Canceladas'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarReservas();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _reservas.any((r) => r.estado == 'PENDIENTE_PAGO')) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  // LX-103: Recuperar expires_at y estado real desde el servidor al volver de segundo plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarReservas();
    }
  }

  /// Permite que la navegación principal refresque la lista al entrar a la pestaña.
  void recargar() {
    if (!_cargando) _cargarReservas();
  }

  Future<void> _cargarReservas() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });

    try {
      // El administrador ve todas; el jugador solo las suyas.
      final list = await ApiService.getReservas(
        estado: _estadoFiltro.isEmpty ? null : _estadoFiltro,
        clienteDni: ApiService.esAdmin ? null : ApiService.currentSession?.dni,
      );
      if (!mounted) return;
      setState(() {
        _reservas = list;
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

  // ---------------------------------------------------------------------------
  // Pago con comprobante
  // ---------------------------------------------------------------------------

  Future<void> _mostrarHojaPago(Reserva r) async {
    final enviado = await mostrarHojaPago(context, r);

    if (enviado && mounted) {
      mostrarAviso(
        context,
        'Comprobante enviado. Te avisaremos cuando lo revisemos.',
      );
      _cargarReservas();
    }
  }

  // ---------------------------------------------------------------------------
  // Ticket QR
  // ---------------------------------------------------------------------------

  void _mostrarTicket(Reserva r) => mostrarTicketQr(context, r);

  // ---------------------------------------------------------------------------
  // Editar, cancelar y eliminar
  // ---------------------------------------------------------------------------

  Future<void> _mostrarDialogoEditar(Reserva r) async {
    final ok = await mostrarDialogoEditarReserva(context, r);

    if (ok == true && mounted) {
      mostrarAviso(context, 'Datos actualizados.');
      _cargarReservas();
    }
  }

  Future<void> _confirmarCancelacion(Reserva r) async {
    final resultado = await mostrarDialogoCancelarReserva(context, r);

    if (resultado != null && mounted) {
      final dev = (resultado['monto_devolucion'] as num?)?.toDouble() ?? 0.0;
      mostrarAviso(
        context,
        dev > 0
            ? 'Reserva cancelada. Te devolveremos ${Formato.soles(dev)}.'
            : 'Reserva cancelada.',
        tipo: TipoAviso.info,
      );
      _cargarReservas();
    }
  }

  Future<void> _confirmarEliminacion(Reserva r) async {
    final ok = await confirmarEliminarReserva(context);
    if (ok != true) return;
    try {
      await ApiService.eliminarReserva(r.id);
      if (!mounted) return;
      mostrarAviso(context, 'Reserva eliminada.', tipo: TipoAviso.info);
      _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      mostrarAviso(context, mensajeError(e), tipo: TipoAviso.error);
    }
  }

  // ---------------------------------------------------------------------------
  // Componentes visuales
  // ---------------------------------------------------------------------------

  Widget _barraFiltros() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _filtros.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final (valor, etiqueta) = _filtros[idx];
          return ChoiceChip(
            showCheckmark: false,
            label: Text(etiqueta),
            selected: valor == _estadoFiltro,
            onSelected: (_) {
              setState(() => _estadoFiltro = valor);
              _cargarReservas();
            },
          );
        },
      ),
    );
  }

  Widget _contenido() {
    if (_cargando && _reservas.isEmpty) {
      return const EstadoVista.cargando(titulo: 'Cargando tus reservas…');
    }
    if (_errorMsg != null) {
      return EstadoVista.error(
        titulo: 'No pudimos cargar tus reservas',
        mensaje: _errorMsg!,
        onReintentar: _cargarReservas,
      );
    }
    if (_reservas.isEmpty) {
      final sinFiltro = _estadoFiltro.isEmpty;
      return EstadoVista(
        icono: Icons.confirmation_number_outlined,
        color: LuxxitoColors.secundario,
        titulo: sinFiltro ? 'Aún no tienes reservas' : 'Nada por aquí',
        detalle: sinFiltro
            ? 'Encuentra una cancha cerca de ti y reserva tu primer turno.'
            : 'No tienes reservas con este estado.',
        accion: sinFiltro && widget.onExplorar != null
            ? FilledButton.icon(
                onPressed: widget.onExplorar,
                icon: const Icon(Icons.explore),
                label: const Text('Explorar canchas'),
              )
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _reservas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        final r = _reservas[idx];
        // La tarjeta solo dibuja; las acciones las resuelve esta pantalla
        return TarjetaReserva(
          reserva: r,
          onPagar: () => _mostrarHojaPago(r),
          onVerTicket: () => _mostrarTicket(r),
          onEditar: () => _mostrarDialogoEditar(r),
          onCancelar: () => _confirmarCancelacion(r),
          onEliminar: () => _confirmarEliminacion(r),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _barraFiltros(),
          if (_cargando && _reservas.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarReservas,
              child: _contenido(),
            ),
          ),
        ],
      ),
    );
  }
}

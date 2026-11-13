import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/pagos/dialogos_pago.dart';
import '../widgets/pagos/resumen_bandeja.dart';
import '../widgets/pagos/tarjeta_pago.dart';

/// Modo Operador (LX-301): bandeja de comprobantes PENDIENTE_REVISION para
/// aprobarlos (reserva CONFIRMADA + Ticket QR) o rechazarlos con motivo.
///
/// Esta pantalla guarda la lista y llama a la API; la tarjeta de cada pago,
/// el resumen y los diálogos están en widgets/pagos/.
class RevisionPagosScreen extends StatefulWidget {
  /// false cuando la bandeja vive como pestaña del panel del ADMIN.
  final bool mostrarAppBar;

  /// Informa cuántos comprobantes quedan por revisar (para el contador de la pestaña).
  final ValueChanged<int>? onPendientes;

  const RevisionPagosScreen({
    super.key,
    this.mostrarAppBar = true,
    this.onPendientes,
  });

  @override
  State<RevisionPagosScreen> createState() => RevisionPagosScreenState();
}

class RevisionPagosScreenState extends State<RevisionPagosScreen> {
  static const Color _verde = LuxxitoColors.primario;

  List<PagoEnRevision> _pagos = [];
  bool _cargando = true;
  String? _errorMsg;

  /// IDs de los pagos que se están aprobando o rechazando en este momento.
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  /// Permite que el panel del ADMIN refresque la bandeja al abrir la pestaña.
  void recargar() {
    if (!_cargando) _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });
    try {
      final pagos = await ApiService.listarPagos();
      if (!mounted) return;
      setState(() {
        _pagos = pagos;
        _cargando = false;
      });
      widget.onPendientes?.call(pagos.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e is ApiException ? e.message : e.toString();
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  /// Ejecuta aprobar o rechazar: marca la tarjeta como "procesando", llama a la
  /// API y, si sale bien, quita el pago de la bandeja y muestra el aviso.
  Future<void> _ejecutar(
    PagoEnRevision item,
    Future<void> Function() accion,
    String mensajeExito,
  ) async {
    setState(() => _procesando.add(item.pago.id));
    try {
      await accion();
      if (!mounted) return;
      setState(() => _pagos.removeWhere((p) => p.pago.id == item.pago.id));
      widget.onPendientes?.call(_pagos.length);
      _aviso(mensajeExito, const Color(0xFF059669), Icons.check_circle);
    } catch (e) {
      if (!mounted) return;
      _aviso(
        e is ApiException ? e.message : e.toString(),
        LuxxitoColors.error,
        Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _procesando.remove(item.pago.id));
    }
  }

  void _aviso(String mensaje, Color color, IconData icono) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
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

  Future<void> _aprobar(PagoEnRevision item) async {
    if (!await confirmarAprobacionPago(context, item)) return;
    await _ejecutar(
      item,
      () => ApiService.aprobarPago(item.pago.id),
      'Pago aprobado. ${item.clienteNombre} ya tiene su Ticket QR.',
    );
  }

  Future<void> _rechazar(PagoEnRevision item) async {
    final observacion = await pedirMotivoRechazo(context, item);
    if (observacion == null) return;
    await _ejecutar(
      item,
      () => ApiService.rechazarPago(
        pagoId: item.pago.id,
        observacion: observacion,
      ),
      'Comprobante rechazado. Avisamos a ${item.clienteNombre} del motivo.',
    );
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  /// Vista centrada para "error" y "bandeja vacía". Es una lista para que se
  /// pueda deslizar hacia abajo y recargar.
  Widget _estadoCentrado({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    Widget? accion,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icono, size: 36, color: color),
        ),
        const SizedBox(height: 18),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LuxxitoColors.texto,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LuxxitoColors.textoSecundario,
            height: 1.4,
          ),
        ),
        if (accion != null) ...[
          const SizedBox(height: 20),
          Center(child: accion),
        ],
      ],
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _verde),
            SizedBox(height: 14),
            Text(
              'Buscando comprobantes pendientes…',
              style: TextStyle(color: LuxxitoColors.textoSecundario),
            ),
          ],
        ),
      );
    }
    if (_errorMsg != null) {
      return _estadoCentrado(
        icono: Icons.wifi_off_rounded,
        color: LuxxitoColors.error,
        titulo: 'No pudimos cargar la bandeja',
        detalle: _errorMsg!,
        accion: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _verde,
            foregroundColor: Colors.white,
          ),
          onPressed: _cargarPagos,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_pagos.isEmpty) {
      return RefreshIndicator(
        color: _verde,
        onRefresh: _cargarPagos,
        child: _estadoCentrado(
          icono: Icons.task_alt_rounded,
          color: _verde,
          titulo: '¡Todo al día!',
          detalle: 'No hay comprobantes esperando revisión.\nDesliza hacia abajo para buscar nuevos.',
        ),
      );
    }
    return RefreshIndicator(
      color: _verde,
      onRefresh: _cargarPagos,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _pagos.length + 1,
        itemBuilder: (context, idx) {
          // La primera fila es el resumen; las demás, una tarjeta por pago
          if (idx == 0) return ResumenBandeja(pagos: _pagos);
          final item = _pagos[idx - 1];
          return Padding(
            padding: EdgeInsets.fromLTRB(16, idx == 1 ? 12 : 0, 16, 0),
            child: TarjetaPago(
              item: item,
              procesando: _procesando.contains(item.pago.id),
              onAprobar: () => _aprobar(item),
              onRechazar: () => _rechazar(item),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxxitoColors.fondo,
      appBar: !widget.mostrarAppBar
          ? null
          : AppBar(
        backgroundColor: LuxxitoColors.superficie,
        foregroundColor: LuxxitoColors.texto,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revisión de pagos', style: TextStyle(fontSize: 18)),
            Text(
              'Modo operador',
              style: TextStyle(fontSize: 12, color: LuxxitoColors.secundario),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargarPagos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }
}

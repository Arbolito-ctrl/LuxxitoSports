import 'package:flutter/material.dart';
import '../models/luxxito_models.dart';
import '../services/api_service.dart';

/// Modo Operador (LX-301): bandeja de comprobantes PENDIENTE_REVISION para
/// aprobarlos (reserva CONFIRMADA + Ticket QR) o rechazarlos con motivo.
class RevisionPagosScreen extends StatefulWidget {
  const RevisionPagosScreen({super.key});

  @override
  State<RevisionPagosScreen> createState() => _RevisionPagosScreenState();
}

class _RevisionPagosScreenState extends State<RevisionPagosScreen> {
  static const Color _fondo = Color(0xFF0F172A);
  static const Color _superficie = Color(0xFF1E293B);
  static const Color _verde = Color(0xFF10B981);
  static const Color _celeste = Color(0xFF38BDF8);
  static const int _minObservacion = 5;
  static const List<String> _motivosFrecuentes = [
    'El monto no coincide con la reserva',
    'Comprobante ilegible o recortado',
    'Número de operación inválido',
    'El pago no se refleja en la cuenta',
  ];
  static const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  List<PagoEnRevision> _pagos = [];
  bool _cargando = true;
  String? _errorMsg;
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargarPagos();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e is ApiException ? e.message : e.toString();
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Formato amigable
  // ---------------------------------------------------------------------------

  String _fechaLegible(String fecha) {
    final d = DateTime.tryParse(fecha);
    if (d == null) return fecha;
    return '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
  }

  String _hora(int h) => '${h.toString().padLeft(2, '0')}:00';

  String _haceCuanto(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }

  Color _colorMetodo(String metodo) {
    switch (metodo) {
      case 'YAPE':
        return const Color(0xFFA855F7);
      case 'PLIN':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

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
      _aviso(mensajeExito, const Color(0xFF059669), Icons.check_circle);
    } catch (e) {
      if (!mounted) return;
      _aviso(
        e is ApiException ? e.message : e.toString(),
        Colors.redAccent,
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

  Future<void> _confirmarAprobacion(PagoEnRevision item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.verified, color: _verde, size: 40),
        title: const Text(
          '¿Aprobar este pago?',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          'Confirmaremos la reserva de ${item.clienteNombre} '
          '(${_fechaLegible(item.fecha)}, ${_hora(item.horaInicio)}) '
          'y le enviaremos su Ticket QR por S/ ${item.pago.monto.toStringAsFixed(2)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Sí, aprobar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(
      item,
      () => ApiService.aprobarPago(item.pago.id),
      'Pago aprobado. ${item.clienteNombre} ya tiene su Ticket QR.',
    );
  }

  Future<void> _mostrarDialogoRechazo(PagoEnRevision item) async {
    final obsCtrl = TextEditingController();
    String? errorObs;

    final observacion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rechazar comprobante',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.clienteNombre} verá este motivo y podrá enviar un nuevo comprobante.',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _motivosFrecuentes
                    .map(
                      (m) => ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        backgroundColor: _fondo,
                        labelStyle: const TextStyle(color: Colors.white70),
                        side: const BorderSide(color: Colors.white24),
                        onPressed: () => setSheetState(() {
                          obsCtrl.text = m;
                          errorObs = null;
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: obsCtrl,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (errorObs != null) setSheetState(() => errorObs = null);
                },
                decoration: InputDecoration(
                  hintText: 'Escribe o elige un motivo…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: _fondo,
                  errorText: errorObs,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final texto = obsCtrl.text.trim();
                    if (texto.length < _minObservacion) {
                      setSheetState(() => errorObs =
                          'Cuéntale al jugador qué falló (mínimo $_minObservacion caracteres).');
                      return;
                    }
                    Navigator.of(ctx).pop(texto);
                  },
                  icon: const Icon(Icons.block),
                  label: const Text('Rechazar y notificar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    obsCtrl.dispose();
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

  void _verComprobante(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Comprobante'),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.network(
                url,
                errorBuilder: (_, _, _) => const Text(
                  'No se pudo cargar la imagen del comprobante.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Componentes visuales
  // ---------------------------------------------------------------------------

  Widget _resumen() {
    final totalMonto = _pagos.fold<double>(0, (acc, p) => acc + p.pago.monto);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Icon(Icons.receipt_long, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pagos.length == 1
                      ? '1 comprobante por revisar'
                      : '${_pagos.length} comprobantes por revisar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Los más antiguos aparecen primero.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Por conciliar',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                'S/ ${totalMonto.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaPreviaComprobante(Pago pago) {
    final url = pago.comprobanteUrl;
    final placeholder = Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, color: Colors.white38),
          SizedBox(width: 8),
          Text(
            'Sin imagen del comprobante',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return placeholder;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _verComprobante(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.network(
              url,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 150,
                      color: _fondo,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _verde,
                      ),
                    ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaPago(PagoEnRevision item) {
    final pago = item.pago;
    final ocupado = _procesando.contains(pago.id);
    final colorMetodo = _colorMetodo(pago.metodo);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: ocupado ? 0.6 : 1,
      child: Card(
        color: _superficie,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorMetodo.withValues(alpha: 0.2),
                    child: Text(
                      _iniciales(item.clienteNombre),
                      style: TextStyle(
                        color: colorMetodo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.clienteNombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enviado ${_haceCuanto(pago.createdAt)} · Reserva #${pago.reservaId}',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${pago.monto.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _verde,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _chip(pago.metodo, colorMetodo),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _dato(Icons.stadium_outlined,
                  '${item.canchaNombre} · ${item.complejoNombre}'),
              _dato(Icons.event_outlined,
                  '${_fechaLegible(item.fecha)} · ${_hora(item.horaInicio)} – ${_hora(item.horaFin)}'),
              _dato(Icons.tag,
                  'Operación ${pago.numeroOperacion} · ${pago.modalidad == 'SENA_50' ? 'Seña 50%' : 'Pago total'} de S/ ${item.total.toStringAsFixed(2)}'),
              _dato(Icons.phone_outlined,
                  '${item.clienteTelefono} · DNI ${item.clienteDni}'),
              const SizedBox(height: 12),
              _vistaPreviaComprobante(pago),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: ocupado ? null : () => _mostrarDialogoRechazo(item),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: ocupado ? null : () => _confirmarAprobacion(item),
                      icon: ocupado
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(ocupado ? 'Procesando…' : 'Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, height: 1.4),
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
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }
    if (_errorMsg != null) {
      return _estadoCentrado(
        icono: Icons.wifi_off_rounded,
        color: Colors.redAccent,
        titulo: 'No pudimos cargar la bandeja',
        detalle: _errorMsg!,
        accion: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _verde,
            foregroundColor: Colors.black,
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
          detalle:
              'No hay comprobantes esperando revisión.\nDesliza hacia abajo para buscar nuevos.',
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
          if (idx == 0) return _resumen();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, idx == 1 ? 12 : 0, 16, 0),
            child: _tarjetaPago(_pagos[idx - 1]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _superficie,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revisión de pagos', style: TextStyle(fontSize: 18)),
            Text(
              'Modo operador',
              style: TextStyle(fontSize: 12, color: _celeste),
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

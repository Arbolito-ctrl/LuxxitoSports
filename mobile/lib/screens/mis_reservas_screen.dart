import 'dart:async';
import 'package:flutter/material.dart';
import '../models/luxxito_models.dart';
import '../services/api_service.dart';

class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen>
    with WidgetsBindingObserver {
  List<Reserva> _reservas = [];
  bool _cargando = true;
  String? _errorMsg;
  String _estadoFiltro = '';
  Timer? _countdownTimer;

  final List<String> _estados = [
    '',
    'PENDIENTE_PAGO',
    'CONFIRMADA',
    'CANCELADA',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarReservas();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _reservas.any((r) => r.estado == 'PENDIENTE_PAGO')) {
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

  String _formatearTiempoRestante(String expiresAtIso) {
    final exp = DateTime.tryParse(expiresAtIso);
    if (exp == null) return '20:00';
    final diff = exp.difference(DateTime.now());
    if (diff.isNegative) {
      return 'Expirado (pendiente liberación)';
    }
    final mins = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _cargarReservas() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });

    try {
      final list = await ApiService.getReservas(
        estado: _estadoFiltro.isEmpty ? null : _estadoFiltro,
      );
      if (!mounted) return;
      setState(() {
        _reservas = list;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _mostrarDialogoPago(Reserva r) async {
    String metodo = 'YAPE';
    String modalidad = 'TOTAL';
    final opCtrl = TextEditingController(
      text: 'YAPE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final montoRequerido = modalidad == 'SENA_50'
              ? double.parse((r.total * 0.5).toStringAsFixed(2))
              : double.parse((r.total - r.montoPagado).toStringAsFixed(2));

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              'Enviar Comprobante · Reserva #${r.id}',
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Destinatario Verificado: Luxxito Sports SAC (987-654-321)',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: metodo,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: ['YAPE', 'PLIN', 'TRANSFERENCIA']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => metodo = v ?? 'YAPE'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: modalidad,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Modalidad de Pago',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'TOTAL', child: Text('Pago Total (100%)')),
                      DropdownMenuItem(
                          value: 'SENA_50', child: Text('Seña / Adelanto (50%)')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => modalidad = v ?? 'TOTAL'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: opCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'N° de Operación del Comprobante',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Importe a Conciliar: S/ ${montoRequerido.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  try {
                    await ApiService.registrarPago(
                      reservaId: r.id,
                      metodo: metodo,
                      modalidad: modalidad,
                      monto: montoRequerido,
                      numeroOperacion: opCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop(true);
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Enviar Comprobante'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comprobante enviado. Tu turno queda protegido mientras el operador lo revisa.',
            ),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
      _cargarReservas();
    }
  }

  Future<void> _mostrarDialogoEditar(Reserva r) async {
    final telCtrl = TextEditingController(text: r.clienteTelefono);
    final notasCtrl = TextEditingController(text: r.notas ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Editar Reserva #${r.id} (CRUD PUT)',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: telCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Teléfono de Contacto',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notasCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Notas o requerimientos',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              try {
                await ApiService.actualizarReserva(
                  reservaId: r.id,
                  clienteTelefono: telCtrl.text.trim(),
                  notas: notasCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      _cargarReservas();
    }
  }

  Future<void> _confirmarCancelacion(Reserva r) async {
    final motivoCtrl =
        TextEditingController(text: 'Cancelación solicitada desde la app');

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Cancelar Reserva #${r.id}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Política de Cancelación (24 Horas):\n• >= 24h antes: Devolución del 100% pagado.\n• < 24h antes: Retención del 50% por penalidad.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Motivo de cancelación',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final data = await ApiService.cancelarReserva(
                  reservaId: r.id,
                  motivo: motivoCtrl.text.trim(),
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(data);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Confirmar Cancelación'),
          ),
        ],
      ),
    );

    if (resultado != null && mounted) {
      final dev = (resultado['monto_devolucion'] as num?)?.toDouble() ?? 0.0;
      final pol = resultado['politica_aplicada']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reserva cancelada ($pol). Devolución calculada: S/ ${dev.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      _cargarReservas();
    }
  }

  Future<void> _eliminarReservaNoConfirmada(Reserva r) async {
    try {
      await ApiService.eliminarReserva(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reserva #${r.id} eliminada de la base de datos.'),
        ),
      );
      _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'CONFIRMADA':
        return const Color(0xFF10B981);
      case 'EN_REVISION':
        return const Color(0xFF0EA5E9);
      case 'PENDIENTE_PAGO':
        return const Color(0xFFF59E0B);
      case 'CANCELADA':
      case 'VENCIDA':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _estados.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final est = _estados[idx];
                        final sel = est == _estadoFiltro;
                        return ChoiceChip(
                          label: Text(est.isEmpty ? 'Todas' : est),
                          selected: sel,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF0F172A),
                          labelStyle: TextStyle(
                            color: sel ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) {
                            setState(() => _estadoFiltro = est);
                            _cargarReservas();
                          },
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _cargarReservas,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Recargar reservas',
                ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : _errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.redAccent),
                              const SizedBox(height: 10),
                              Text(
                                _errorMsg!,
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _cargarReservas,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _reservas.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Aún no tienes reservas registradas.\nVe a la pestaña "Explorar" para elegir una cancha y horario.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 15),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarReservas,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _reservas.length,
                              itemBuilder: (context, idx) {
                                final r = _reservas[idx];
                                final badgeColor = _colorEstado(r.estado);

                                return Card(
                                  color: const Color(0xFF1E293B),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color:
                                            badgeColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Reserva #${r.id} · ${r.fecha}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: badgeColor.withValues(
                                                    alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: badgeColor),
                                              ),
                                              child: Text(
                                                r.estado,
                                                style: TextStyle(
                                                  color: badgeColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${r.canchaNombre} (${r.deporte}) - ${r.complejoNombre}',
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Horario: ${r.horaInicio}:00 - ${r.horaFin}:00 · Cliente: ${r.clienteNombre} (DNI ${r.clienteDni})',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13),
                                        ),
                                        if (r.extras.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Extras: ${r.extras.map((e) => "${e.nombre} x${e.cantidad}").join(", ")}',
                                            style: const TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if (r.notas != null &&
                                            r.notas!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Notas: ${r.notas}',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontStyle: FontStyle.italic,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if (r.estado == 'PENDIENTE_PAGO') ...[
                                          if (r.rechazoVigente != null) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent
                                                    .withValues(alpha: 0.16),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.redAccent),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.report_outlined,
                                                    size: 16,
                                                    color: Colors.redAccent,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Comprobante ${r.rechazoVigente!.numeroOperacion} rechazado: ${r.rechazoVigente!.observacion ?? 'sin motivo'}. Envía uno nuevo antes de que venza el bloqueo.',
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFFFECACA),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B)
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFF59E0B)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.timer_outlined,
                                                  size: 16,
                                                  color: Color(0xFFFBBF24),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Bloqueo de servidor (20 min) vence en: ${_formatearTiempoRestante(r.expiresAt)}',
                                                    style: const TextStyle(
                                                      color: Color(0xFFFDE68A),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else if (r.estado == 'EN_REVISION') ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0EA5E9)
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF38BDF8)),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.shield_outlined,
                                                  size: 16,
                                                  color: Color(0xFF38BDF8),
                                                ),
                                                SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Comprobante enviado: turno protegido en revisión administrativa.',
                                                    style: TextStyle(
                                                      color: Color(0xFFBAE6FD),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const Divider(color: Colors.white24),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total: S/ ${r.total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              'Pagado: S/ ${r.montoPagado.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF34D399),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (r.montoDevolucion > 0)
                                              Text(
                                                'Reembolso: S/ ${r.montoDevolucion.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (r.codigoQr != null) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF064E3B),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF10B981)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.qr_code_2,
                                                    color: Colors.white,
                                                    size: 32),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'TICKET QR VERIFICABLE DE INGRESO',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFF6EE7B7),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        r.codigoQr!,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (r.estado == 'PENDIENTE_PAGO' ||
                                                (r.estado == 'CONFIRMADA' &&
                                                    r.montoPagado < r.total))
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF10B981),
                                                  foregroundColor: Colors.black,
                                                ),
                                                onPressed: () =>
                                                    _mostrarDialogoPago(r),
                                                icon: const Icon(Icons.payments,
                                                    size: 16),
                                                label:
                                                    const Text('Pagar / Yape'),
                                              ),
                                            if (r.estado != 'CANCELADA')
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(
                                                      color: Colors.white38),
                                                ),
                                                onPressed: () =>
                                                    _mostrarDialogoEditar(r),
                                                icon: const Icon(Icons.edit,
                                                    size: 16),
                                                label: const Text('Editar'),
                                              ),
                                            if (r.estado != 'CANCELADA')
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.orangeAccent,
                                                  side: const BorderSide(
                                                      color:
                                                          Colors.orangeAccent),
                                                ),
                                                onPressed: () =>
                                                    _confirmarCancelacion(r),
                                                icon: const Icon(Icons.cancel,
                                                    size: 16),
                                                label: const Text('Cancelar'),
                                              ),
                                            if (r.estado != 'CONFIRMADA')
                                              IconButton(
                                                onPressed: () =>
                                                    _eliminarReservaNoConfirmada(
                                                        r),
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent),
                                                tooltip:
                                                    'Eliminar registro (CRUD Delete)',
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

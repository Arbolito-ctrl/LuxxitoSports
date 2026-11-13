import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';
import '../widgets/reservas/tarjeta_reserva.dart';

class MisReservasScreen extends StatefulWidget {
  final VoidCallback? onExplorar;

  const MisReservasScreen({super.key, this.onExplorar});

  @override
  State<MisReservasScreen> createState() => MisReservasScreenState();
}

class MisReservasScreenState extends State<MisReservasScreen>
    with WidgetsBindingObserver {
  static const String _numeroYape = '987 654 321';

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

  /// Foto del voucher reducida para no superar el límite de 5 MB del bucket.
  Future<(Uint8List, String)?> _elegirFoto(ImageSource origen) async {
    try {
      final foto = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (foto == null) return null;
      final nombre = foto.name.toLowerCase();
      final mime = nombre.endsWith('.png')
          ? 'image/png'
          : nombre.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      return (await foto.readAsBytes(), mime);
    } catch (_) {
      if (mounted) {
        mostrarAviso(
          context,
          'No pudimos abrir la cámara o la galería. Revisa los permisos de la app.',
          tipo: TipoAviso.error,
        );
      }
      return null;
    }
  }

  Future<void> _mostrarHojaPago(Reserva r) async {
    final formKey = GlobalKey<FormState>();
    final opCtrl = TextEditingController();
    final primerPago = r.montoPagado == 0;
    String metodo = 'YAPE';
    String modalidad = 'TOTAL';
    bool enviando = false;
    String? estadoEnvio;
    String? errorEnvio;
    Uint8List? fotoBytes;
    String fotoMime = 'image/jpeg';
    String? fotoSubidaUrl;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final monto = modalidad == 'SENA_50'
              ? double.parse((r.total * 0.5).toStringAsFixed(2))
              : double.parse((r.total - r.montoPagado).toStringAsFixed(2));

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + espacioInferior(ctx),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      primerPago ? 'Paga tu reserva' : 'Paga el saldo',
                      style: const TextStyle(
                        color: LuxxitoColors.texto,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.canchaNombre} · ${Formato.fecha(r.fecha)}, ${Formato.rango(r.horaInicio, r.horaFin)}',
                      style: const TextStyle(
                        color: LuxxitoColors.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (primerPago) ...[
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'TOTAL',
                            label: Text('Pago total'),
                          ),
                          ButtonSegment(
                            value: 'SENA_50',
                            label: Text('Adelanto 50%'),
                          ),
                        ],
                        selected: {modalidad},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) =>
                            setSheetState(() => modalidad = s.first),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuxxitoColors.primarioSuave,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Monto a pagar',
                            style: TextStyle(
                              color: LuxxitoColors.primario,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            Formato.soles(monto),
                            style: const TextStyle(
                              color: LuxxitoColors.texto,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '1. Envía el pago a Luxxito Sports SAC',
                      style: TextStyle(
                        color: LuxxitoColors.texto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: LuxxitoColors.fondo,
                      child: ListTile(
                        leading: const Icon(
                          Icons.qr_code_2,
                          color: LuxxitoColors.primario,
                        ),
                        title: const Text(
                          _numeroYape,
                          style: TextStyle(
                            color: LuxxitoColors.texto,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        subtitle: const Text(
                          'Yape · Plin',
                          style: TextStyle(color: LuxxitoColors.textoTenue),
                        ),
                        trailing: IconButton(
                          tooltip: 'Copiar número',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: _numeroYape.replaceAll(' ', ''),
                              ),
                            );
                            mostrarAviso(
                              ctx,
                              'Número copiado',
                              tipo: TipoAviso.info,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '2. Cuéntanos cómo pagaste',
                      style: TextStyle(
                        color: LuxxitoColors.texto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'YAPE', label: Text('Yape')),
                        ButtonSegment(value: 'PLIN', label: Text('Plin')),
                        ButtonSegment(
                          value: 'TRANSFERENCIA',
                          label: Text('Transfer.'),
                        ),
                      ],
                      selected: {metodo},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setSheetState(() => metodo = s.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: opCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'N° de operación',
                        hintText: 'Lo encuentras en tu constancia',
                        prefixIcon: Icon(Icons.tag),
                      ),
                      validator: (v) => (v ?? '').trim().length < 4
                          ? 'Ingresa al menos 4 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '3. Adjunta la captura del pago (recomendado)',
                      style: TextStyle(
                        color: LuxxitoColors.texto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (fotoBytes == null)
                      Row(
                        children: [
                          for (final (origen, icono, etiqueta) in const [
                            (ImageSource.camera, Icons.photo_camera_outlined, 'Cámara'),
                            (ImageSource.gallery, Icons.photo_library_outlined, 'Galería'),
                          ]) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: enviando
                                    ? null
                                    : () async {
                                        final foto = await _elegirFoto(origen);
                                        if (foto == null) return;
                                        setSheetState(() {
                                          (fotoBytes, fotoMime) = foto;
                                          fotoSubidaUrl = null;
                                        });
                                      },
                                icon: Icon(icono),
                                label: Text(etiqueta),
                              ),
                            ),
                            if (origen == ImageSource.camera) const SizedBox(width: 10),
                          ],
                        ],
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              fotoBytes!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton.filled(
                              tooltip: 'Quitar foto',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: enviando
                                  ? null
                                  : () => setSheetState(() {
                                      fotoBytes = null;
                                      fotoSubidaUrl = null;
                                    }),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    if (errorEnvio != null) ...[
                      AvisoBanner(
                        icono: Icons.error_outline,
                        color: LuxxitoColors.error,
                        titulo: 'No pudimos enviar tu comprobante',
                        texto: errorEnvio!,
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: enviando
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() {
                                enviando = true;
                                errorEnvio = null;
                              });
                              try {
                                // Si el registro falla, el reintento reutiliza la foto ya subida
                                if (fotoBytes != null && fotoSubidaUrl == null) {
                                  setSheetState(() => estadoEnvio = 'Subiendo foto…');
                                  fotoSubidaUrl = await ApiService.subirComprobante(
                                    reservaId: r.id,
                                    bytes: fotoBytes!,
                                    mimeType: fotoMime,
                                  );
                                }
                                setSheetState(() => estadoEnvio = 'Enviando…');
                                await ApiService.registrarPago(
                                  reservaId: r.id,
                                  metodo: metodo,
                                  modalidad: modalidad,
                                  monto: monto,
                                  numeroOperacion: opCtrl.text.trim(),
                                  comprobanteUrl: fotoSubidaUrl,
                                );
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop(true);
                              } catch (e) {
                                setSheetState(() {
                                  enviando = false;
                                  estadoEnvio = null;
                                  errorEnvio = mensajeError(e);
                                });
                              }
                            },
                      icon: enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        enviando ? (estadoEnvio ?? 'Enviando…') : 'Enviar comprobante',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (ok == true && mounted) {
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

  void _mostrarTicket(Reserva r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu ticket de ingreso',
                style: TextStyle(
                  color: LuxxitoColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Muestra este código en la entrada del complejo.',
                style: TextStyle(color: LuxxitoColors.textoSecundario),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LuxxitoColors.texto,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: r.codigoQr!,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                r.codigoQr!,
                style: const TextStyle(
                  color: LuxxitoColors.textoSecundario,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      DatoFila(
                        Icons.stadium_outlined,
                        '${r.canchaNombre} · ${r.complejoNombre}',
                      ),
                      DatoFila(
                        Icons.event_outlined,
                        '${Formato.fechaLarga(r.fecha)} · ${Formato.rango(r.horaInicio, r.horaFin)}',
                      ),
                      DatoFila(
                        Icons.person_outline,
                        '${r.clienteNombre} · DNI ${r.clienteDni}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Editar, cancelar y eliminar
  // ---------------------------------------------------------------------------

  Future<void> _mostrarDialogoEditar(Reserva r) async {
    final telCtrl = TextEditingController(text: r.clienteTelefono);
    final notasCtrl = TextEditingController(text: r.notas ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar datos de contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular de contacto',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas para el complejo',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
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
                mostrarAviso(ctx, mensajeError(e), tipo: TipoAviso.error);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      mostrarAviso(context, 'Datos actualizados.');
      _cargarReservas();
    }
  }

  Future<void> _confirmarCancelacion(Reserva r) async {
    final inicio = DateTime.tryParse(
      '${r.fecha}T${r.horaInicio.toString().padLeft(2, '0')}:00:00',
    );
    final horas = inicio == null
        ? 48.0
        : inicio.difference(DateTime.now()).inMinutes / 60;
    final reembolsoTotal = horas >= 24;
    final devolucion = reembolsoTotal ? r.montoPagado : r.montoPagado * 0.5;
    String motivo = 'Ya no podré asistir';

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.event_busy,
            color: LuxxitoColors.advertencia,
            size: 40,
          ),
          title: const Text('¿Cancelar esta reserva?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${r.canchaNombre} · ${Formato.fecha(r.fecha)}, ${Formato.rango(r.horaInicio, r.horaFin)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              if (r.montoPagado > 0)
                AvisoBanner(
                  icono: reembolsoTotal
                      ? Icons.savings_outlined
                      : Icons.warning_amber,
                  color: reembolsoTotal
                      ? LuxxitoColors.exito
                      : LuxxitoColors.advertencia,
                  titulo: 'Te devolveremos ${Formato.soles(devolucion)}',
                  texto: reembolsoTotal
                      ? 'Cancelas con más de 24 horas de anticipación: reembolso del 100%.'
                      : 'Faltan menos de 24 horas: se retiene el 50% de lo pagado.',
                )
              else
                const AvisoBanner(
                  icono: Icons.info_outline,
                  color: LuxxitoColors.info,
                  texto: 'Aún no has pagado, así que no hay cargos.',
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: motivo,
                dropdownColor: LuxxitoColors.superficieAlta,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items:
                    const [
                          'Ya no podré asistir',
                          'Cambio de fecha u horario',
                          'Problemas de clima',
                          'Otro motivo',
                        ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                onChanged: (v) => setDialogState(() => motivo = v ?? motivo),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  final data = await ApiService.cancelarReserva(
                    reservaId: r.id,
                    motivo: motivo,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop(data);
                } catch (e) {
                  if (!ctx.mounted) return;
                  mostrarAviso(ctx, mensajeError(e), tipo: TipoAviso.error);
                }
              },
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      ),
    );

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          color: LuxxitoColors.error,
          size: 40,
        ),
        title: const Text('¿Eliminar del historial?'),
        content: const Text(
          'La reserva desaparecerá de tu lista. Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
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

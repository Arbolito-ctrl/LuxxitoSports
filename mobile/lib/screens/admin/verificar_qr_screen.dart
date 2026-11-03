import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../../widgets/luxxito_widgets.dart';

/// Ingreso en puerta (LX-202): el operador escanea el Ticket QR con la cámara
/// o escribe el código; el servidor lo valida una sola vez.
class VerificarQrScreen extends StatefulWidget {
  /// La cámara solo se enciende mientras la pestaña está visible.
  final bool activa;

  const VerificarQrScreen({super.key, required this.activa});

  @override
  State<VerificarQrScreen> createState() => _VerificarQrScreenState();
}

class _ResultadoVerificacion {
  final bool exito;
  final String titulo;
  final String detalle;
  final Reserva? reserva;
  final DateTime? verificadoEn;

  const _ResultadoVerificacion({
    required this.exito,
    required this.titulo,
    required this.detalle,
    this.reserva,
    this.verificadoEn,
  });
}

class _VerificarQrScreenState extends State<VerificarQrScreen> {
  final _camara = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _codigoCtrl = TextEditingController();

  bool _verificando = false;
  bool _linterna = false;
  _ResultadoVerificacion? _resultado;

  @override
  void initState() {
    super.initState();
    if (widget.activa) _camara.start();
  }

  @override
  void didUpdateWidget(covariant VerificarQrScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa != oldWidget.activa) {
      if (widget.activa && _resultado == null) {
        _camara.start();
      } else if (!widget.activa) {
        _camara.stop();
      }
    }
  }

  @override
  void dispose() {
    _camara.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_verificando || _resultado != null) return;
    final codigo = captura.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.toUpperCase().startsWith('LUXXITO-QR-'), orElse: () => '');
    if (codigo.isNotEmpty) _verificar(codigo);
  }

  Future<void> _verificar(String codigo) async {
    FocusScope.of(context).unfocus();
    setState(() => _verificando = true);
    await _camara.stop();

    _ResultadoVerificacion resultado;
    try {
      final data = await ApiService.verificarTicketQr(codigo);
      resultado = _ResultadoVerificacion(
        exito: true,
        titulo: 'Ingreso registrado',
        detalle: 'El ticket es válido. Ya puede ingresar a la cancha.',
        reserva: data['reserva'] is Map<String, dynamic>
            ? Reserva.fromJson(data['reserva'] as Map<String, dynamic>)
            : null,
        verificadoEn: DateTime.tryParse(data['verificado_en']?.toString() ?? '')?.toLocal(),
      );
    } on ApiException catch (e) {
      final titulo = switch (e.statusCode) {
        409 => 'Ticket no válido para ingresar',
        404 => 'Ticket no encontrado',
        400 => 'Código con formato incorrecto',
        401 || 403 => 'Sin permisos de operador',
        _ => 'No pudimos verificar el ticket',
      };
      resultado = _ResultadoVerificacion(exito: false, titulo: titulo, detalle: e.message);
    } catch (e) {
      resultado = _ResultadoVerificacion(
        exito: false,
        titulo: 'No pudimos verificar el ticket',
        detalle: mensajeError(e),
      );
    }

    if (!mounted) return;
    setState(() {
      _verificando = false;
      _resultado = resultado;
    });
  }

  void _escanearOtro() {
    setState(() {
      _resultado = null;
      _codigoCtrl.clear();
    });
    if (widget.activa) _camara.start();
  }

  Widget _visor() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camara,
              onDetect: _alDetectar,
              errorBuilder: (context, error) => Container(
                color: LuxxitoColors.superficieAlta,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined,
                        size: 40, color: LuxxitoColors.textoTenue),
                    const SizedBox(height: 10),
                    Text(
                      error.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'Permite el uso de la cámara en los ajustes del teléfono, o escribe el código abajo.'
                          : 'No pudimos abrir la cámara. Escribe el código abajo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: LuxxitoColors.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
            // Marco guía para encuadrar el código
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 0.62,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: IconButton.filled(
                tooltip: _linterna ? 'Apagar linterna' : 'Encender linterna',
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () async {
                  await _camara.toggleTorch();
                  setState(() => _linterna = !_linterna);
                },
                icon: Icon(
                  _linterna ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
              ),
            ),
            if (_verificando)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaResultado(_ResultadoVerificacion r) {
    final color = r.exito ? LuxxitoColors.exito : LuxxitoColors.error;
    final reserva = r.reserva;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                r.exito ? Icons.check_circle : Icons.block,
                size: 44,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              r.titulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              r.detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: LuxxitoColors.textoSecundario, height: 1.4),
            ),
            if (reserva != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              DatoFila(Icons.person_outline, '${reserva.clienteNombre} · DNI ${reserva.clienteDni}'),
              DatoFila(Icons.stadium_outlined, '${reserva.canchaNombre} · ${reserva.complejoNombre}'),
              DatoFila(
                Icons.event_outlined,
                '${Formato.fechaLarga(reserva.fecha)} · ${Formato.rango(reserva.horaInicio, reserva.horaFin)}',
              ),
              if (r.verificadoEn != null)
                DatoFila(
                  Icons.schedule,
                  'Validado a las ${r.verificadoEn!.hour.toString().padLeft(2, '0')}:${r.verificadoEn!.minute.toString().padLeft(2, '0')}',
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _escanearOtro,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Verificar otro ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + espacioInferior(context)),
      children: [
        if (_resultado != null)
          _tarjetaResultado(_resultado!)
        else ...[
          const Text(
            'Apunta la cámara al Ticket QR del jugador',
            style: TextStyle(color: LuxxitoColors.textoSecundario),
          ),
          const SizedBox(height: 12),
          _visor(),
          const SizedBox(height: 20),
          const SeccionTitulo(
            '¿No se puede escanear?',
            subtitulo: 'Escribe el código que aparece debajo del QR.',
          ),
          TextField(
            controller: _codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_verificando,
            decoration: const InputDecoration(
              labelText: 'Código del ticket',
              hintText: 'LUXXITO-QR-…',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            onSubmitted: (v) => v.trim().isEmpty ? null : _verificar(v.trim()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _verificando
                ? null
                : () {
                    final codigo = _codigoCtrl.text.trim();
                    if (codigo.isEmpty) {
                      mostrarAviso(context, 'Escribe el código del ticket.', tipo: TipoAviso.info);
                      return;
                    }
                    _verificar(codigo);
                  },
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(_verificando ? 'Verificando…' : 'Verificar ingreso'),
          ),
        ],
      ],
    );
  }
}

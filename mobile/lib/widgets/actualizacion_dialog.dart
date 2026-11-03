import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../services/actualizacion_service.dart';
import '../theme/luxxito_theme.dart';
import 'luxxito_widgets.dart';

bool _revisadoEnEstaSesion = false;

/// Al entrar a la app revisa una sola vez si hay una versión nueva y la ofrece.
Future<void> revisarActualizacionAlIniciar(BuildContext context) async {
  if (_revisadoEnEstaSesion || !ActualizacionService.disponible) return;
  _revisadoEnEstaSesion = true;
  try {
    final info = await ActualizacionService.buscar();
    if (info != null && context.mounted) {
      await ofrecerActualizacion(context, info);
    }
  } catch (_) {
    // Sin conexión con GitHub: se volverá a intentar en la próxima apertura.
  }
}

/// Aviso "Nueva versión disponible" con la opción de instalarla desde la app.
Future<void> ofrecerActualizacion(
  BuildContext context,
  InfoActualizacion info,
) async {
  final actualizar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.system_update,
        color: LuxxitoColors.primario,
        size: 40,
      ),
      title: const Text('Nueva versión disponible'),
      content: Text(
        'Luxxito Sports ${info.version} ya está lista. '
        'Se descargará dentro de la app y Android te pedirá confirmar la instalación.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Más tarde'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.download),
          label: const Text('Actualizar ahora'),
        ),
      ],
    ),
  );
  if (actualizar == true && context.mounted) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DescargaDialog(info: info),
    );
  }
}

class _DescargaDialog extends StatefulWidget {
  final InfoActualizacion info;

  const _DescargaDialog({required this.info});

  @override
  State<_DescargaDialog> createState() => _DescargaDialogState();
}

class _DescargaDialogState extends State<_DescargaDialog> {
  StreamSubscription<OtaEvent>? _suscripcion;
  double? _progreso;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  void _iniciar() {
    setState(() {
      _progreso = null;
      _error = null;
    });
    _suscripcion?.cancel();
    _suscripcion = ActualizacionService.instalar(widget.info).listen(
      (evento) {
        if (!mounted) return;
        switch (evento.status) {
          case OtaStatus.DOWNLOADING:
            final porcentaje = double.tryParse(evento.value ?? '');
            setState(
              () => _progreso = porcentaje == null ? null : porcentaje / 100,
            );
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
            // Android muestra su propio instalador; este diálogo ya no hace falta
            Navigator.of(context).pop();
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            setState(
              () => _error =
                  'Android necesita tu permiso para instalar la actualización. '
                  'Actívalo en Ajustes → Apps → Luxxito Sports → Instalar apps desconocidas, y vuelve a intentarlo.',
            );
          case OtaStatus.CANCELED:
            Navigator.of(context).pop();
          default:
            setState(
              () => _error = 'No pudimos descargar la actualización. Revisa tu conexión e inténtalo de nuevo.',
            );
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = mensajeError(e));
      },
    );
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final porcentaje = _progreso == null ? null : (_progreso! * 100).round();
    return AlertDialog(
      title: Text(
        _error == null ? 'Descargando actualización' : 'No se pudo actualizar',
      ),
      content: _error != null
          ? Text(_error!)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: _progreso, minHeight: 6),
                const SizedBox(height: 12),
                Text(
                  porcentaje == null
                      ? 'Preparando la descarga…'
                      : '$porcentaje% de Luxxito Sports ${widget.info.version}',
                  style: const TextStyle(color: LuxxitoColors.textoSecundario),
                ),
              ],
            ),
      actions: _error == null
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                onPressed: _iniciar,
                child: const Text('Reintentar'),
              ),
            ],
    );
  }
}

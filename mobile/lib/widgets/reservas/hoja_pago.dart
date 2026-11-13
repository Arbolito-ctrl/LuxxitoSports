import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';
import '../selector_foto.dart';

/// Número de Yape/Plin de Luxxito Sports al que el jugador envía el pago.
const String numeroYapeLuxxito = '987 654 321';

/// Hoja inferior para pagar una reserva con comprobante (Yape, Plin o transferencia).
///
/// Pasos que ve el jugador:
///   1. Elige pago total o adelanto del 50 % (solo en el primer pago) y ve el monto.
///   2. Envía el dinero al número de Luxxito e indica el método y el N° de operación.
///   3. Adjunta (opcional) la captura del pago desde la cámara o la galería.
///
/// Al enviar, primero sube la foto al bucket privado y luego registra el pago.
/// Si el registro falla, el reintento reutiliza la foto ya subida.
///
/// Devuelve true si el comprobante se envió; la pantalla que la abre decide qué
/// hacer después (mostrar un aviso y recargar la lista).
Future<bool> mostrarHojaPago(BuildContext context, Reserva r) async {
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
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + espacioInferior(ctx)),
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
                        numeroYapeLuxxito,
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
                              text: numeroYapeLuxxito.replaceAll(' ', ''),
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
                          (
                            ImageSource.camera,
                            Icons.photo_camera_outlined,
                            'Cámara',
                          ),
                          (
                            ImageSource.gallery,
                            Icons.photo_library_outlined,
                            'Galería',
                          ),
                        ]) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: enviando
                                  ? null
                                  : () async {
                                      final foto = await tomarFoto(ctx, origen);
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
                          if (origen == ImageSource.camera)
                            const SizedBox(width: 10),
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
                                setSheetState(
                                  () => estadoEnvio = 'Subiendo foto…',
                                );
                                fotoSubidaUrl =
                                    await ApiService.subirComprobante(
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
                      enviando
                          ? (estadoEnvio ?? 'Enviando…')
                          : 'Enviar comprobante',
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

  return ok == true;
}

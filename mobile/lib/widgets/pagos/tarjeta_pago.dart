import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';
import 'formato_pago.dart';

/// Tarjeta de un comprobante en la bandeja del ADMIN: quién pagó, cuánto, por
/// qué método, los datos de la reserva, la foto del voucher y los botones
/// Rechazar / Aprobar.
///
/// Mientras se aprueba o rechaza ([procesando]) la tarjeta se atenúa y los
/// botones se desactivan para evitar dobles envíos.
class TarjetaPago extends StatelessWidget {
  final PagoEnRevision item;
  final bool procesando;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  const TarjetaPago({
    super.key,
    required this.item,
    required this.procesando,
    required this.onAprobar,
    required this.onRechazar,
  });

  @override
  Widget build(BuildContext context) {
    final pago = item.pago;
    final ocupado = procesando;
    final colorMetodo = colorMetodoPago(pago.metodo);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: ocupado ? 0.6 : 1,
      child: Card(
        color: LuxxitoColors.superficie,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LuxxitoColors.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Cliente, cuándo envió el comprobante, monto y método --------
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colorMetodo.withValues(alpha: 0.2),
                    child: Text(
                      inicialesCliente(item.clienteNombre),
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
                            color: LuxxitoColors.texto,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enviado ${haceCuanto(pago.createdAt)} · Reserva #${pago.reservaId}',
                          style: const TextStyle(
                            color: LuxxitoColors.textoTenue,
                            fontSize: 12,
                          ),
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
                          color: LuxxitoColors.primario,
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
              // --- Datos de la reserva y del comprobante ------------------------
              const SizedBox(height: 10),
              _dato(
                Icons.stadium_outlined,
                '${item.canchaNombre} · ${item.complejoNombre}',
              ),
              _dato(
                Icons.event_outlined,
                '${fechaLegiblePago(item.fecha)} · ${horaPago(item.horaInicio)} – ${horaPago(item.horaFin)}',
              ),
              _dato(
                Icons.tag,
                'Operación ${pago.numeroOperacion} · ${pago.modalidad == 'SENA_50' ? 'Seña 50%' : 'Pago total'} de S/ ${item.total.toStringAsFixed(2)}',
              ),
              _dato(
                Icons.phone_outlined,
                '${item.clienteTelefono} · DNI ${item.clienteDni}',
              ),
              const SizedBox(height: 12),
              _VistaPreviaComprobante(pago: pago),
              const SizedBox(height: 14),
              // --- Acciones ------------------------------------------------------
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LuxxitoColors.error,
                        side: const BorderSide(color: LuxxitoColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: ocupado ? null : onRechazar,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: LuxxitoColors.primario,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: ocupado ? null : onAprobar,
                      icon: ocupado
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
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

  /// Etiqueta de color con el método de pago (YAPE, PLIN, TRANSFERENCIA).
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
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Fila con un ícono y un dato de la reserva.
  Widget _dato(IconData icono, String texto) {
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

/// Miniatura del voucher. Al tocarla se abre a pantalla completa con zoom.
class _VistaPreviaComprobante extends StatelessWidget {
  final Pago pago;

  const _VistaPreviaComprobante({required this.pago});

  @override
  Widget build(BuildContext context) {
    // El bucket es privado: solo se puede mostrar el enlace firmado temporal.
    final directa = pago.comprobanteUrl;
    final url = pago.comprobanteUrlFirmada ??
        (directa != null && directa.startsWith('http') ? directa : null);
    final placeholder = Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LuxxitoColors.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LuxxitoColors.borde),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: LuxxitoColors.textoTenue,
          ),
          SizedBox(width: 8),
          Text(
            'Sin imagen del comprobante',
            style: TextStyle(color: LuxxitoColors.textoTenue, fontSize: 12),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return placeholder;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _verComprobante(context, url),
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
                      color: LuxxitoColors.fondo,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LuxxitoColors.primario,
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

  /// Abre el voucher a pantalla completa con zoom (hasta 5x).
  void _verComprobante(BuildContext context, String url) {
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
                  style: TextStyle(color: LuxxitoColors.textoSecundario),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

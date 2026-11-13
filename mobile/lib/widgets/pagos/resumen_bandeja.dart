import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../theme/luxxito_theme.dart';

/// Encabezado de la bandeja: cuántos comprobantes faltan revisar y la suma de
/// sus montos (lo que queda por conciliar).
class ResumenBandeja extends StatelessWidget {
  final List<PagoEnRevision> pagos;

  const ResumenBandeja({super.key, required this.pagos});

  @override
  Widget build(BuildContext context) {
    final totalMonto = pagos.fold<double>(0, (acc, p) => acc + p.pago.monto);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxxitoColors.superficie,
        border: Border.all(color: LuxxitoColors.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: LuxxitoColors.primarioSuave,
            child: Icon(Icons.receipt_long, color: LuxxitoColors.primario),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pagos.length == 1
                      ? '1 comprobante por revisar'
                      : '${pagos.length} comprobantes por revisar',
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Los más antiguos aparecen primero.',
                  style: TextStyle(
                    color: LuxxitoColors.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Por conciliar',
                style: TextStyle(
                  color: LuxxitoColors.textoSecundario,
                  fontSize: 11,
                ),
              ),
              Text(
                'S/ ${totalMonto.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: LuxxitoColors.primario,
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
}

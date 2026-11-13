import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/luxxito_models.dart';
import '../../services/api_service.dart';
import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';
import '../selector_foto.dart';

/// Hoja del ADMIN para publicar una cancha nueva en el catálogo.
///
/// Pide complejo, nombre, deporte, superficie, precio de día y de noche (el de
/// noche no puede ser menor), si es techada y, opcionalmente, una foto.
/// Primero crea la cancha y luego sube la foto; si la foto falla, la cancha
/// queda creada igual y se avisa que se puede agregar luego con "Cambiar foto".
///
/// [deportes] es la lista de deportes de los filtros (el valor vacío "Todos"
/// se ignora). Devuelve true si la cancha se publicó.
Future<bool> mostrarHojaNuevaCancha(
  BuildContext context, {
  required List<Complejo> complejos,
  required List<String> deportes,
}) async {
  final formKey = GlobalKey<FormState>();
  final nombreCtrl = TextEditingController();
  final superficieCtrl = TextEditingController(text: 'Grass sintético');
  final diurnoCtrl = TextEditingController(text: '85');
  final nocturnoCtrl = TextEditingController(text: '115');
  int? complejoSel = complejos.isNotEmpty ? complejos.first.id : null;
  String deporteSel = 'Futbol 7';
  bool techada = false;
  bool guardando = false;
  (Uint8List, String)? fotoNueva;

  final creado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + espacioInferior(ctx)),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nueva cancha',
                  style: TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Se publicará de inmediato en el catálogo.',
                  style: TextStyle(color: LuxxitoColors.textoSecundario),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: complejoSel,
                  dropdownColor: LuxxitoColors.superficieAlta,
                  decoration: const InputDecoration(
                    labelText: 'Complejo',
                    prefixIcon: Icon(Icons.stadium_outlined),
                  ),
                  items: complejos
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre),
                        ),
                      )
                      .toList(),
                  validator: (v) => v == null ? 'Elige un complejo' : null,
                  onChanged: (v) => setSheetState(() => complejoSel = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nombreCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la cancha',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Escribe un nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: deporteSel,
                        dropdownColor: LuxxitoColors.superficieAlta,
                        decoration: const InputDecoration(
                          labelText: 'Deporte',
                        ),
                        items: deportes
                            .where((d) => d.isNotEmpty)
                            .map(
                              (d) =>
                                  DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setSheetState(() => deporteSel = v ?? deporteSel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: superficieCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Superficie',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: diurnoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio día',
                          prefixText: 'S/ ',
                          helperText: 'Antes de 18:00',
                        ),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Precio inválido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: nocturnoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio noche',
                          prefixText: 'S/ ',
                          helperText: 'Desde 18:00',
                        ),
                        validator: (v) {
                          final noche = double.tryParse(v ?? '') ?? 0;
                          final dia = double.tryParse(diurnoCtrl.text) ?? 0;
                          if (noche <= 0) return 'Precio inválido';
                          if (noche < dia) return 'Debe ser ≥ día';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cancha techada'),
                  value: techada,
                  onChanged: (v) => setSheetState(() => techada = v),
                ),
                if (fotoNueva == null)
                  OutlinedButton.icon(
                    onPressed: guardando
                        ? null
                        : () async {
                            final foto = await elegirFoto(ctx);
                            if (foto != null) {
                              setSheetState(() => fotoNueva = foto);
                            }
                          },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Agregar foto de la cancha (opcional)'),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.memory(
                          fotoNueva!.$1,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton.filled(
                            tooltip: 'Quitar foto',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: guardando
                                ? null
                                : () => setSheetState(() => fotoNueva = null),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => guardando = true);
                          try {
                            final creada = await ApiService.crearCancha(
                              complejoId: complejoSel!,
                              nombre: nombreCtrl.text.trim(),
                              deporte: deporteSel,
                              superficie: superficieCtrl.text.trim(),
                              techada: techada,
                              precioDiurno: double.parse(diurnoCtrl.text),
                              precioNocturno: double.parse(nocturnoCtrl.text),
                            );
                            if (fotoNueva != null) {
                              try {
                                await ApiService.subirImagenCancha(
                                  canchaId: creada.id,
                                  bytes: fotoNueva!.$1,
                                  mimeType: fotoNueva!.$2,
                                );
                              } catch (_) {
                                // La cancha ya existe: la foto se puede agregar luego con "Cambiar foto"
                                if (ctx.mounted) {
                                  mostrarAviso(
                                    ctx,
                                    'Cancha creada, pero no se pudo subir la foto.',
                                    tipo: TipoAviso.info,
                                  );
                                }
                              }
                            }
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (e) {
                            setSheetState(() => guardando = false);
                            if (!ctx.mounted) return;
                            mostrarAviso(
                              ctx,
                              mensajeError(e),
                              tipo: TipoAviso.error,
                            );
                          }
                        },
                  child: Text(guardando ? 'Guardando…' : 'Publicar cancha'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  return creado == true;
}

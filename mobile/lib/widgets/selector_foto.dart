import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'luxxito_widgets.dart';

/// Pregunta si usar cámara o galería y devuelve la foto reducida (máx. 1600 px)
/// junto con su tipo MIME; null si el usuario cancela.
Future<(Uint8List, String)?> elegirFoto(BuildContext context) async {
  final origen = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (origen == null) return null;

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
    if (context.mounted) {
      mostrarAviso(
        context,
        'No pudimos abrir la cámara o la galería. Revisa los permisos de la app.',
        tipo: TipoAviso.error,
      );
    }
    return null;
  }
}

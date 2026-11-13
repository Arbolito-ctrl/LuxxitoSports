import 'package:flutter/material.dart';

import '../../theme/luxxito_theme.dart';

// Formatos de texto que usa la bandeja de revisión de pagos del ADMIN.

const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const List<String> _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "2026-11-14" → "sáb 14 nov". Si no es una fecha válida, la devuelve tal cual.
String fechaLegiblePago(String fecha) {
  final d = DateTime.tryParse(fecha);
  if (d == null) return fecha;
  return '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
}

/// 9 → "09:00".
String horaPago(int h) => '${h.toString().padLeft(2, '0')}:00';

/// Tiempo transcurrido desde una fecha ISO: "hace 5 min", "hace 2 h"...
String haceCuanto(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} d';
}

/// Hasta dos iniciales del nombre: "Ana María Pérez" → "AM".
String inicialesCliente(String nombre) {
  final partes = nombre
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Color de cada método de pago: morado para Yape, celeste para Plin.
Color colorMetodoPago(String metodo) {
  switch (metodo) {
    case 'YAPE':
      return const Color(0xFF7C3AED);
    case 'PLIN':
      return const Color(0xFF0891B2);
    default:
      return LuxxitoColors.textoSecundario;
  }
}

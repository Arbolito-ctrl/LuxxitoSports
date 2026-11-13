import 'package:flutter/material.dart';

import '../../theme/luxxito_theme.dart';
import '../luxxito_widgets.dart';

/// Datos de quien hace la reserva (titular).
///
/// Si el jugador inició sesión, se muestran sus datos en una tarjeta con el
/// botón "Cambiar"; al tocarlo (o si no hay sesión) aparece el formulario con
/// validaciones de DNI (8 dígitos), celular (9 dígitos que empiezan en 9) y correo.
///
/// Los controladores y la clave del formulario son de la pantalla, porque ella
/// lee los valores al crear la reserva y valida el formulario antes de enviar.
class FormularioTitular extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreCtrl;
  final TextEditingController dniCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController emailCtrl;

  /// true: se muestra el formulario editable; false: la tarjeta de resumen.
  final bool editando;
  final VoidCallback onEditar;

  const FormularioTitular({
    super.key,
    required this.formKey,
    required this.nombreCtrl,
    required this.dniCtrl,
    required this.telefonoCtrl,
    required this.emailCtrl,
    required this.editando,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    if (!editando) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: LuxxitoColors.primario.withValues(alpha: 0.2),
            child: Text(
              Formato.iniciales(nombreCtrl.text),
              style: const TextStyle(
                color: LuxxitoColors.primario,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            nombreCtrl.text,
            style: const TextStyle(
              color: LuxxitoColors.texto,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'DNI ${dniCtrl.text} · ${telefonoCtrl.text}',
            style: const TextStyle(color: LuxxitoColors.textoTenue),
          ),
          trailing: TextButton(
            onPressed: onEditar,
            child: const Text('Cambiar'),
          ),
        ),
      );
    }
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Ingresa el nombre' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: dniCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'DNI',
                    counterText: '',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '8 dígitos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    counterText: '',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      RegExp(r'^9\d{8}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '9 dígitos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Revisa el correo',
          ),
        ],
      ),
    );
  }
}

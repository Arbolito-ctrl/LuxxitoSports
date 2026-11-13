import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';

class AuthScreen extends StatefulWidget {
  final ValueChanged<UserSession> onAuthenticated;
  final bool isStandalonePage;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.isStandalonePage = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Cuentas de prueba del backend, visibles solo en compilaciones de desarrollo.
  static const _cuentasDemo = [
    ('Jugador demo', 'elvis.arboleda@uni.pe', 'luxxito2026'),
    ('Admin demo', 'admin@luxxitosports.pe', 'admin2026'),
  ];

  final _formKey = GlobalKey<FormState>();
  bool _esRegistro = false;
  bool _cargando = false;
  bool _verPassword = false;

  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Sugerencia de nombre por DNI (solo en el registro). Es opcional: si el
  // servicio no responde, el usuario escribe su nombre como siempre.
  String? _nombreSugerido;
  bool _buscandoNombre = false;
  String _dniConsultado = '';

  @override
  void initState() {
    super.initState();
    _dniCtrl.addListener(_alCambiarDni);
  }

  /// Al completar los 8 dígitos del DNI pide al servidor el nombre asociado.
  /// Si el campo "Nombre completo" está vacío lo rellena; si no, solo lo ofrece.
  Future<void> _alCambiarDni() async {
    if (!_esRegistro) return;
    final dni = _dniCtrl.text.trim();
    if (dni == _dniConsultado) return;
    _dniConsultado = dni;

    if (!RegExp(r'^\d{8}$').hasMatch(dni)) {
      if (_nombreSugerido != null || _buscandoNombre) {
        setState(() {
          _nombreSugerido = null;
          _buscandoNombre = false;
        });
      }
      return;
    }

    setState(() {
      _buscandoNombre = true;
      _nombreSugerido = null;
    });
    final nombre = await ApiService.sugerirNombrePorDni(dni);
    // Si el usuario cambió el DNI mientras se consultaba, se ignora esta respuesta
    if (!mounted || _dniCtrl.text.trim() != dni) return;

    final sugerido = nombre == null ? null : _formatoNombre(nombre);
    setState(() {
      _buscandoNombre = false;
      _nombreSugerido = sugerido;
      if (sugerido != null && _nombreCtrl.text.trim().isEmpty) {
        _nombreCtrl.text = sugerido;
      }
    });
  }

  /// "JUAN CARLOS PEREZ GARCIA" → "Juan Carlos Perez Garcia".
  String _formatoNombre(String nombre) => nombre
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');

  /// Debajo del DNI: "buscando…", "completamos tu nombre" o "¿usar este nombre?".
  Widget _avisoNombreDni() {
    if (_buscandoNombre) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Buscando tu nombre…',
              style: TextStyle(color: LuxxitoColors.textoTenue, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    final sugerido = _nombreSugerido;
    if (sugerido == null) return const SizedBox.shrink();

    if (_nombreCtrl.text.trim() == sugerido) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: LuxxitoColors.exito),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Completamos tu nombre con tu DNI. Puedes corregirlo si hace falta.',
                style: TextStyle(color: LuxxitoColors.textoTenue, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _nombreCtrl.text = sugerido),
        icon: const Icon(Icons.person_search, size: 18),
        label: Text('¿Eres $sugerido? Usar este nombre'),
      ),
    );
  }

  @override
  void dispose() {
    _dniCtrl.removeListener(_alCambiarDni);
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validarRequerido(String? v, String campo) =>
      (v == null || v.trim().isEmpty) ? 'Ingresa tu $campo' : null;

  String? _validarEmail(String? v) {
    final texto = v?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresa tu correo';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(texto)) {
      return 'Revisa el formato del correo';
    }
    return null;
  }

  String? _validarPassword(String? v) {
    final texto = v?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresa tu contraseña';
    if (_esRegistro && texto.length < 6) return 'Usa al menos 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    try {
      final UserSession session;
      if (_esRegistro) {
        session = await ApiService.registrarUsuario(
          nombre: _nombreCtrl.text.trim(),
          dni: _dniCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      } else {
        session = await ApiService.login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      setState(() => _cargando = false);
      widget.onAuthenticated(session);
      if (widget.isStandalonePage && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(session);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarAviso(context, mensajeError(e), tipo: TipoAviso.error);
    }
  }

  void _cambiarModo() {
    setState(() {
      _esRegistro = !_esRegistro;
      _nombreSugerido = null;
      _buscandoNombre = false;
      _dniConsultado = '';
    });
    _formKey.currentState?.reset();
  }

  Future<void> _mostrarRecuperarAcceso() async {
    final recCtrl = TextEditingController(text: _emailCtrl.text);
    final correo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.lock_reset,
          color: LuxxitoColors.primario,
          size: 36,
        ),
        title: const Text('Recuperar acceso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Te enviaremos un enlace para crear una nueva contraseña.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: recCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(recCtrl.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (correo == null || correo.isEmpty || !mounted) return;
    mostrarAviso(context, 'Listo. Revisa tu bandeja de entrada en $correo.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                shrinkWrap: true,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: LuxxitoColors.primario,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.sports_soccer,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _esRegistro
                        ? 'Crea tu cuenta'
                        : 'Bienvenido a Luxxito Sports',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LuxxitoColors.texto,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _esRegistro
                        ? 'Regístrate en segundos y reserva tu próxima pichanga.'
                        : 'Reserva canchas en Lima y recibe tu ticket QR al instante.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LuxxitoColors.textoSecundario,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_esRegistro) ...[
                    // El DNI va primero: al completarlo se sugiere el nombre
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dniCtrl,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            maxLength: 8,
                            decoration: const InputDecoration(
                              labelText: 'DNI',
                              counterText: '',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                                ? null
                                : '8 dígitos',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _telefonoCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            maxLength: 9,
                            decoration: const InputDecoration(
                              labelText: 'Celular',
                              counterText: '',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) =>
                                RegExp(r'^9\d{8}$').hasMatch(v?.trim() ?? '')
                                ? null
                                : '9 dígitos (9…)',
                          ),
                        ),
                      ],
                    ),
                    _avisoNombreDni(),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      // Redibuja para que el aviso de la sugerencia siga al texto
                      onChanged: (_) {
                        if (_nombreSugerido != null) setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => _validarRequerido(v, 'nombre'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validarEmail,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: !_verPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
                        icon: Icon(
                          _verPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: LuxxitoColors.textoTenue,
                        ),
                        onPressed: () =>
                            setState(() => _verPassword = !_verPassword),
                      ),
                    ),
                    validator: _validarPassword,
                  ),
                  if (!_esRegistro)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _mostrarRecuperarAcceso,
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: LuxxitoColors.textoSecundario,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _cargando ? null : _submit,
                      child: _cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _esRegistro ? 'Crear cuenta' : 'Iniciar Sesión',
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _esRegistro ? '¿Ya tienes cuenta?' : '¿Eres nuevo?',
                        style: const TextStyle(
                          color: LuxxitoColors.textoSecundario,
                        ),
                      ),
                      TextButton(
                        onPressed: _cargando ? null : _cambiarModo,
                        child: Text(
                          _esRegistro ? 'Inicia sesión' : 'Crea tu cuenta',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (kDebugMode && !_esRegistro) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Cuentas de prueba (solo desarrollo)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LuxxitoColors.textoTenue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: _cuentasDemo
                          .map(
                            (c) => ActionChip(
                              avatar: const Icon(Icons.bolt, size: 16),
                              label: Text(c.$1),
                              onPressed: () => setState(() {
                                _emailCtrl.text = c.$2;
                                _passwordCtrl.text = c.$3;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

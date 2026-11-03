import 'package:flutter/material.dart';
import '../models/luxxito_models.dart';
import '../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  final ValueChanged<UserSession> onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _esRegistro = false;
  bool _cargando = false;

  final _nombreCtrl = TextEditingController(text: 'Elvis Arboleda');
  final _dniCtrl = TextEditingController(text: '74125896');
  final _telefonoCtrl = TextEditingController(text: '987654321');
  final _emailCtrl = TextEditingController(text: 'elvis.arboleda@uni.pe');
  final _passwordCtrl = TextEditingController(text: 'luxxito2026');

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _cargando = true;
    });

    try {
      UserSession session;
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
      setState(() {
        _cargando = false;
      });
      widget.onAuthenticated(session);
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(_esRegistro ? 'Crear Cuenta Jugador' : 'Iniciar Sesión'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.sports_soccer,
            size: 56,
            color: Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          Text(
            _esRegistro
                ? 'Regístrate en Luxxito Sports'
                : 'Bienvenido a Luxxito Sports',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu sesión autocompleta tus reservas y sincroniza tus Tickets QR.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 22),

          if (_esRegistro) ...[
            _buildInput(_nombreCtrl, 'Nombre Completo', Icons.person),
            const SizedBox(height: 12),
            _buildInput(_dniCtrl, 'DNI (8 dígitos)', Icons.badge_outlined),
            const SizedBox(height: 12),
            _buildInput(_telefonoCtrl, 'Teléfono / Celular', Icons.phone),
            const SizedBox(height: 12),
          ],

          _buildInput(_emailCtrl, 'Correo Electrónico', Icons.email_outlined),
          const SizedBox(height: 12),
          _buildInput(
            _passwordCtrl,
            'Contraseña',
            Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: 22),

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _cargando ? null : _submit,
              icon: _cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(_esRegistro ? Icons.person_add : Icons.login),
              label: Text(
                _esRegistro ? 'Registrarme y Continuar' : 'Ingresar a mi Cuenta',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _esRegistro = !_esRegistro;
              });
            },
            child: Text(
              _esRegistro
                  ? '¿Ya tienes cuenta? Inicia sesión aquí'
                  : '¿No tienes cuenta? Crear cuenta nueva',
              style: const TextStyle(color: Color(0xFF34D399)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
      ),
    );
  }
}

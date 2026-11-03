import 'package:flutter/material.dart';
import '../../theme/luxxito_theme.dart';
import '../explorar_screen.dart';
import '../mis_reservas_screen.dart';
import '../perfil_config_screen.dart';
import '../revision_pagos_screen.dart';
import 'panel_admin_screen.dart';
import 'verificar_qr_screen.dart';

/// Navegación propia del ADMIN: operar el complejo en lugar de reservar canchas.
class AdminShellScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const AdminShellScreen({super.key, this.onLogout});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  static const _inicio = 0;
  static const _pagos = 1;
  static const _ingreso = 2;
  static const _reservas = 3;

  static const _titulos = [
    'Panel del complejo',
    'Revisión de pagos',
    'Ingreso con QR',
    'Todas las reservas',
    'Mi perfil',
  ];

  int _seleccion = _inicio;
  int _pagosPendientes = 0;

  final _panelKey = GlobalKey<PanelAdminScreenState>();
  final _pagosKey = GlobalKey<RevisionPagosScreenState>();
  final _reservasKey = GlobalKey<MisReservasScreenState>();

  void _irA(int indice) {
    setState(() => _seleccion = indice);
    switch (indice) {
      case _inicio:
        _panelKey.currentState?.recargar();
      case _pagos:
        _pagosKey.currentState?.recargar();
      case _reservas:
        _reservasKey.currentState?.recargar();
    }
  }

  void _verCatalogo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Gestión de canchas')),
          body: ExplorarScreen(onNavigateToReservas: () {}, modoGestion: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: LuxxitoColors.secundario.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: LuxxitoColors.secundario,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(_titulos[_seleccion]),
          ],
        ),
      ),
      body: IndexedStack(
        index: _seleccion,
        children: [
          PanelAdminScreen(
            key: _panelKey,
            onIrAPagos: () => _irA(_pagos),
            onIrAIngreso: () => _irA(_ingreso),
            onIrAReservas: () => _irA(_reservas),
            onVerCatalogo: _verCatalogo,
          ),
          RevisionPagosScreen(
            key: _pagosKey,
            mostrarAppBar: false,
            onPendientes: (n) {
              if (mounted && n != _pagosPendientes) setState(() => _pagosPendientes = n);
            },
          ),
          VerificarQrScreen(activa: _seleccion == _ingreso),
          MisReservasScreen(key: _reservasKey),
          PerfilConfigScreen(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _seleccion,
        onDestinationSelected: _irA,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: LuxxitoColors.primario),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _pagosPendientes > 0,
              label: Text('$_pagosPendientes'),
              child: const Icon(Icons.fact_check_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _pagosPendientes > 0,
              label: Text('$_pagosPendientes'),
              child: const Icon(Icons.fact_check, color: LuxxitoColors.primario),
            ),
            label: 'Pagos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code_scanner, color: LuxxitoColors.primario),
            label: 'Ingreso',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note, color: LuxxitoColors.primario),
            label: 'Reservas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: LuxxitoColors.primario),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

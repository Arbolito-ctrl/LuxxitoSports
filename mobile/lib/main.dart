import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/explorar_screen.dart';
import 'screens/mis_reservas_screen.dart';
import 'screens/perfil_config_screen.dart';
import 'services/api_service.dart';
import 'theme/luxxito_theme.dart';

void main() {
  runApp(const LuxxitoSportsApp());
}

class LuxxitoSportsApp extends StatelessWidget {
  const LuxxitoSportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luxxito Sports',
      debugShowCheckedModeBanner: false,
      theme: buildLuxxitoTheme(),
      home: const AuthGateScreen(),
    );
  }
}

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  @override
  Widget build(BuildContext context) {
    if (ApiService.currentSession == null) {
      return AuthScreen(
        onAuthenticated: (_) {
          setState(() {});
        },
      );
    }
    return MainShellScreen(
      onLogout: () {
        ApiService.logout();
        setState(() {});
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MainShellScreen({super.key, this.onLogout});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  final _misReservasKey = GlobalKey<MisReservasScreenState>();

  void _irAMisReservas() {
    setState(() {
      _selectedIndex = 1;
    });
    _misReservasKey.currentState?.recargar();
  }

  void _irAExplorar() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const titulos = ['Explorar canchas', 'Mis reservas', 'Mi perfil'];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: LuxxitoColors.primario.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: LuxxitoColors.primario,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(titulos[_selectedIndex]),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ExplorarScreen(onNavigateToReservas: _irAMisReservas),
          MisReservasScreen(key: _misReservasKey, onExplorar: _irAExplorar),
          PerfilConfigScreen(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
          if (idx == 1) _misReservasKey.currentState?.recargar();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: LuxxitoColors.primario),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(
              Icons.confirmation_number,
              color: LuxxitoColors.primario,
            ),
            label: 'Mis reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: LuxxitoColors.primario),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

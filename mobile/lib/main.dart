import 'package:flutter/material.dart';
import 'screens/explorar_screen.dart';
import 'screens/mis_reservas_screen.dart';
import 'screens/perfil_config_screen.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF0EA5E9),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  void _irAMisReservas() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titulos = [
      'Luxxito Sports · Explorar',
      'Mis Reservas y Tickets QR',
      'Perfil y Estado de API',
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.sports_soccer, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulos[_selectedIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ExplorarScreen(onNavigateToReservas: _irAMisReservas),
          const MisReservasScreen(),
          const PerfilConfigScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.25),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Color(0xFF10B981)),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon:
                Icon(Icons.confirmation_number, color: Color(0xFF10B981)),
            label: 'Mis reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF10B981)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

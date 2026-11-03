import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';

class PerfilConfigScreen extends StatefulWidget {
  const PerfilConfigScreen({super.key});

  @override
  State<PerfilConfigScreen> createState() => _PerfilConfigScreenState();
}

class _PerfilConfigScreenState extends State<PerfilConfigScreen> {
  static const String currentInstalledVersion = '1.0.0';

  late TextEditingController _urlCtrl;
  Map<String, dynamic>? _healthInfo;
  Map<String, dynamic>? _updateInfo;
  String? _errorMsg;
  bool _verificando = false;
  bool _buscandoUpdate = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiService.baseUrl);
    _verificarConexion();
    _verificarActualizacionApk();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarConexion() async {
    setState(() {
      _verificando = true;
      _errorMsg = null;
    });
    try {
      ApiService.setBaseUrl(_urlCtrl.text);
      final data = await ApiService.checkHealth();
      if (!mounted) return;
      setState(() {
        _healthInfo = data;
        _verificando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthInfo = null;
        _errorMsg = e.toString();
        _verificando = false;
      });
    }
  }

  Future<void> _verificarActualizacionApk() async {
    setState(() {
      _buscandoUpdate = true;
    });
    final info = await ApiService.checkAppUpdate();
    if (!mounted) return;
    setState(() {
      _updateInfo = info;
      _buscandoUpdate = false;
    });
  }

  void _mostrarModalDescargaApk(String url, String origen) {
    Clipboard.setData(ClipboardData(text: url));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Descargar Actualización APK ($origen)',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El enlace directo al archivo APK actualizado ha sido copiado al portapapeles para abrirlo en el navegador de tu teléfono Android:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestVersion = _updateInfo?['version']?.toString() ?? '1.0.1';
    final hayNuevaVersion = latestVersion != currentInstalledVersion;
    final session = ApiService.currentSession;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF10B981),
                      child: Icon(Icons.sports_soccer,
                          color: Colors.black, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session != null
                                ? session.nombre
                                : 'Luxxito Sports Mobile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session != null
                                ? '${session.email} · DNI ${session.dni}'
                                : 'Versión instalada: v1.0.0 · Sesión de Invitado',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (session == null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AuthScreen(
                                onAuthenticated: (_) {
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                          setState(() {});
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text(
                          'Iniciar Sesión / Crear Cuenta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () {
                          ApiService.logout();
                          setState(() {});
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Cerrar Sesión'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TARJETA DE ACTUALIZACIÓN DESCARGABLE DE APK (OTA / GITHUB RELEASES)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hayNuevaVersion
                    ? const Color(0xFF10B981)
                    : Colors.white24,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.android, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text(
                          'Actualizaciones de APK (OTA)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed:
                          _buscandoUpdate ? null : _verificarActualizacionApk,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      tooltip: 'Buscar nueva versión de APK',
                    ),
                  ],
                ),
                Text(
                  'Versión instalada: $currentInstalledVersion  |  Última en servidor: $latestVersion',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _updateInfo?['release_notes']?.toString() ??
                      'Cada push a main/develop compila y publica automáticamente el nuevo APK en GitHub Releases.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        final ghUrl = _updateInfo?['github_release_apk_url']
                                ?.toString() ??
                            'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk';
                        _mostrarModalDescargaApk(ghUrl, 'GitHub Releases');
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text(
                        'Descargar APK (GitHub Release)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF0EA5E9)),
                      ),
                      onPressed: () {
                        final srvUrl =
                            _updateInfo?['server_apk_url']?.toString() ??
                                '${ApiService.baseUrl}/apk/download';
                        _mostrarModalDescargaApk(srvUrl, 'Servidor API');
                      },
                      icon: const Icon(Icons.cloud_download,
                          size: 18, color: Color(0xFF38BDF8)),
                      label: const Text('Descargar APK desde API'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Text(
            'Configuración de Conexión a la API REST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'URL Base de la API',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.link, color: Color(0xFF10B981)),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                label: const Text('Localhost (Windows/Web/iOS)',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  _urlCtrl.text = 'http://localhost:3000/api';
                  _verificarConexion();
                },
              ),
              ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                label: const Text('Emulador Android (10.0.2.2)',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () {
                  _urlCtrl.text = 'http://10.0.2.2:3000/api';
                  _verificarConexion();
                },
              ),
              ActionChip(
                backgroundColor: const Color(0xFF064E3B),
                label: const Text('Cloud Render (Producción)',
                    style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 12)),
                onPressed: () {
                  _urlCtrl.text = 'https://luxxito-sports-api.onrender.com/api';
                  _verificarConexion();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
            ),
            onPressed: _verificando ? null : _verificarConexion,
            icon: const Icon(Icons.network_check),
            label: Text(_verificando
                ? 'Verificando...'
                : 'Probar Conexión con GET /api/health'),
          ),
          const SizedBox(height: 14),

          if (_healthInfo != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF34D399)),
                      SizedBox(width: 8),
                      Text(
                        'Conectado a la API REST',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Servicio: ${_healthInfo!['service']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Modo BD: ${_healthInfo!['db_mode']}',
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.white),
              ),
            ),

          const SizedBox(height: 22),
          const Text(
            'Reglas de Negocio Verificadas en Servidor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildRuleTile(
            Icons.price_check,
            'Tarifa Diferenciada y Cotización en Servidor',
            'Tarifa diurna (< 18:00) y tarifa nocturna (>= 18:00) calculadas exclusivamente en el backend junto con el 50% de seña.',
          ),
          _buildRuleTile(
            Icons.event_busy,
            'Exclusión Mutua y Bloqueo de 20 Minutos',
            'Impide solapamientos de reservas activas (HTTP 409 Conflict) y protege reservas en revisión de comprobante.',
          ),
          _buildRuleTile(
            Icons.inventory_2_outlined,
            'Control de Capacidad de Extras por Intervalo',
            'Descuenta y verifica el stock disponible de chalecos, balones y árbitros en el mismo complejo e intervalo horario.',
          ),
          _buildRuleTile(
            Icons.assignment_return_outlined,
            'Política de Cancelación de 24 Horas y Ticket QR',
            'Reembolso del 100% si se cancela con >= 24h de anticipación o retención del 50% si faltan < 24h, revocando el QR.',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleTile(IconData icon, String title, String desc) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF10B981)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

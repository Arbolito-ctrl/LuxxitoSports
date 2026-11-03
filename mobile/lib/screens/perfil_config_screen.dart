import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';

class PerfilConfigScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const PerfilConfigScreen({super.key, this.onLogout});

  @override
  State<PerfilConfigScreen> createState() => _PerfilConfigScreenState();
}

class _PerfilConfigScreenState extends State<PerfilConfigScreen> {
  static const String currentInstalledVersion = '1.0.0';
  bool _buscandoUpdate = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _buscarActualizacion() async {
    setState(() => _buscandoUpdate = true);
    final info = await ApiService.checkAppUpdate();
    if (!mounted) return;
    setState(() => _buscandoUpdate = false);

    final ultima = info['version']?.toString() ?? currentInstalledVersion;
    final hayNueva = ultima != currentInstalledVersion;
    final url =
        info['github_release_apk_url']?.toString() ??
        'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          hayNueva ? Icons.system_update : Icons.verified,
          color: LuxxitoColors.primario,
          size: 40,
        ),
        title: Text(
          hayNueva
              ? 'Nueva versión $ultima disponible'
              : 'Tienes la última versión',
        ),
        content: Text(
          hayNueva
              ? (info['release_notes']?.toString() ??
                    'Descarga el APK e instálalo sobre la versión actual.')
              : 'Luxxito Sports $currentInstalledVersion está al día.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (hayNueva)
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.of(ctx).pop();
                mostrarAviso(
                  context,
                  'Enlace copiado. Pégalo en tu navegador para descargar el APK.',
                  tipo: TipoAviso.info,
                );
              },
              icon: const Icon(Icons.link),
              label: const Text('Copiar enlace'),
            ),
        ],
      ),
    );
  }

  void _mostrarPoliticas() {
    Widget regla(IconData icono, String titulo, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: LuxxitoColors.primario.withValues(alpha: 0.15),
            child: Icon(icono, color: LuxxitoColors.primario, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: const TextStyle(
                    color: LuxxitoColors.textoSecundario,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cómo funcionan las reservas',
                style: TextStyle(
                  color: LuxxitoColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              regla(
                Icons.wb_twilight,
                'Tarifa de día y de noche',
                'Desde las 18:00 rige la tarifa nocturna. El precio final siempre lo calcula nuestro sistema.',
              ),
              regla(
                Icons.lock_clock,
                'Te guardamos el turno 20 minutos',
                'Al reservar, nadie más puede tomar ese horario mientras envías tu comprobante. Puedes pagar el total o un adelanto del 50%.',
              ),
              regla(
                Icons.fact_check_outlined,
                'Revisamos tu pago',
                'Mientras validamos el comprobante tu turno sigue protegido. Si hay un problema te diremos el motivo para que envíes uno nuevo.',
              ),
              regla(
                Icons.inventory_2_outlined,
                'Extras según disponibilidad',
                'Chalecos, balones y árbitros dependen del stock del complejo en ese horario.',
              ),
              regla(
                Icons.event_busy,
                'Cancelaciones',
                'Con 24 horas o más de anticipación te devolvemos el 100%. Con menos de 24 horas se retiene el 50% de lo pagado.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarCerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Podrás volver a ingresar cuando quieras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ApiService.logout();
    widget.onLogout?.call();
  }

  // ---------------------------------------------------------------------------
  // Componentes
  // ---------------------------------------------------------------------------

  Widget _grupo(String titulo, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: const TextStyle(
                color: LuxxitoColors.textoTenue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcion({
    required IconData icono,
    required String titulo,
    String? subtitulo,
    Widget? trailing,
    VoidCallback? onTap,
    Color color = LuxxitoColors.primario,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icono, color: color),
      title: Text(titulo, style: const TextStyle(color: LuxxitoColors.texto)),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo,
              style: const TextStyle(color: LuxxitoColors.textoTenue),
            ),
      trailing:
          trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: LuxxitoColors.textoTenue)
              : null),
    );
  }

  Widget _cabecera() {
    final session = ApiService.currentSession;
    final nombre = session?.nombre ?? 'Invitado';
    final esAdmin = ApiService.esAdmin;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LuxxitoColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LuxxitoColors.borde),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: LuxxitoColors.primarioSuave,
            child: Text(
              Formato.iniciales(nombre),
              style: const TextStyle(
                color: LuxxitoColors.primario,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (session != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.email,
                    style: const TextStyle(
                      color: LuxxitoColors.textoSecundario,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Insignia(
                  esAdmin ? 'Administrador' : 'Jugador',
                  color: esAdmin
                      ? LuxxitoColors.secundario
                      : LuxxitoColors.primario,
                  icono: esAdmin ? Icons.shield_outlined : Icons.sports_soccer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiService.currentSession;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _cabecera(),
          if (session != null)
            _grupo('Mi cuenta', [
              _opcion(
                icono: Icons.badge_outlined,
                titulo: 'DNI',
                subtitulo: session.dni,
              ),
              _opcion(
                icono: Icons.phone_outlined,
                titulo: 'Celular',
                subtitulo: session.telefono.isEmpty
                    ? 'Sin registrar'
                    : session.telefono,
              ),
              _opcion(
                icono: Icons.email_outlined,
                titulo: 'Correo',
                subtitulo: session.email,
              ),
            ]),
          _grupo('Ayuda', [
            _opcion(
              icono: Icons.menu_book_outlined,
              titulo: 'Cómo funcionan las reservas',
              subtitulo: 'Pagos, tiempos y cancelaciones',
              onTap: _mostrarPoliticas,
            ),
          ]),
          _grupo('Acerca de', [
            _opcion(
              icono: Icons.system_update_outlined,
              titulo: 'Buscar actualizaciones',
              trailing: _buscandoUpdate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _buscandoUpdate ? null : _buscarActualizacion,
            ),
            _opcion(
              icono: Icons.info_outline,
              titulo: 'Versión',
              subtitulo: 'Luxxito Sports $currentInstalledVersion',
              trailing: const SizedBox.shrink(),
            ),
          ]),
          if (session != null) ...[
            const SizedBox(height: 28),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LuxxitoColors.error,
                side: BorderSide(
                  color: LuxxitoColors.error.withValues(alpha: 0.5),
                ),
              ),
              onPressed: _confirmarCerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ],
      ),
    );
  }
}

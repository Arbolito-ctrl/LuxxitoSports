import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/catalogo/filtros_catalogo.dart';
import '../widgets/catalogo/hoja_nueva_cancha.dart';
import '../widgets/catalogo/tarjeta_cancha.dart';
import '../widgets/luxxito_widgets.dart';
import '../widgets/selector_foto.dart';
import 'disponibilidad_reserva_screen.dart';

/// Catálogo de canchas con filtros por distrito y deporte.
///
/// El jugador lo usa para elegir dónde reservar; el ADMIN ([modoGestion]) lo
/// usa para ver el estado de las canchas, cambiar sus fotos y publicar nuevas.
/// Lo visual está en widgets/catalogo/.
class ExplorarScreen extends StatefulWidget {
  final VoidCallback onNavigateToReservas;

  /// Vista del ADMIN: catálogo para administrar canchas, sin acciones de reserva.
  final bool modoGestion;

  const ExplorarScreen({
    super.key,
    required this.onNavigateToReservas,
    this.modoGestion = false,
  });

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  List<Complejo> _complejos = [];
  List<Cancha> _canchas = [];

  /// Foto de cada complejo (por id), para las canchas que no tienen foto propia.
  Map<int, String?> _fotos = {};
  bool _cargando = true;
  String? _errorMsg;

  String _distritoFiltro = '';
  String _deporteFiltro = '';

  static const List<String> _distritos = [
    '',
    'San Miguel',
    'Santiago de Surco',
    'Miraflores',
  ];

  static const List<String> _deportes = [
    '',
    'Futbol 7',
    'Futbol 5',
    'Voley',
    'Padel',
    'Tenis',
  ];

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  /// Carga complejos y canchas en paralelo aplicando los filtros actuales.
  Future<void> _cargarCatalogo() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getComplejos(
          distrito: _distritoFiltro.isEmpty ? null : _distritoFiltro,
        ),
        ApiService.getCanchas(
          distrito: _distritoFiltro.isEmpty ? null : _distritoFiltro,
          deporte: _deporteFiltro.isEmpty ? null : _deporteFiltro,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _complejos = results[0] as List<Complejo>;
        _fotos = {for (final c in _complejos) c.id: c.imagenUrl};
        _canchas = results[1] as List<Cancha>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = mensajeError(e);
        _cargando = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _abrirReserva(Cancha cancha) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DisponibilidadReservaScreen(
          cancha: cancha,
          onReservaCreada: widget.onNavigateToReservas,
        ),
      ),
    );
    if (ok == true) widget.onNavigateToReservas();
  }

  /// ADMIN: reemplaza la foto de una cancha (bucket público 'canchas').
  Future<void> _cambiarFoto(Cancha cancha) async {
    final foto = await elegirFoto(context);
    if (foto == null || !mounted) return;
    mostrarAviso(
      context,
      'Subiendo foto de ${cancha.nombre}…',
      tipo: TipoAviso.info,
    );
    try {
      await ApiService.subirImagenCancha(
        canchaId: cancha.id,
        bytes: foto.$1,
        mimeType: foto.$2,
      );
      if (!mounted) return;
      mostrarAviso(context, 'Foto de ${cancha.nombre} actualizada.');
      _cargarCatalogo();
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, mensajeError(e), tipo: TipoAviso.error);
      }
    }
  }

  Future<void> _nuevaCancha() async {
    final creado = await mostrarHojaNuevaCancha(
      context,
      complejos: _complejos,
      deportes: _deportes,
    );
    if (creado && mounted) {
      mostrarAviso(context, 'Cancha publicada en el catálogo.');
      _cargarCatalogo();
    }
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  Widget _contenido() {
    if (_cargando) {
      return const EstadoVista.cargando(titulo: 'Buscando canchas…');
    }
    if (_errorMsg != null) {
      return EstadoVista.error(
        titulo: 'No pudimos cargar las canchas',
        mensaje: _errorMsg!,
        onReintentar: _cargarCatalogo,
      );
    }
    if (_canchas.isEmpty) {
      return EstadoVista(
        icono: Icons.search_off,
        color: LuxxitoColors.secundario,
        titulo: 'Sin canchas para estos filtros',
        detalle: 'Prueba con otro distrito o deporte.',
        accion: OutlinedButton(
          onPressed: () {
            setState(() {
              _distritoFiltro = '';
              _deporteFiltro = '';
            });
            _cargarCatalogo();
          },
          child: const Text('Quitar filtros'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: _canchas.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        // La primera fila es el contador; las demás, una tarjeta por cancha
        if (idx == 0) {
          return Text(
            _canchas.length == 1
                ? (widget.modoGestion
                      ? '1 cancha en el catálogo'
                      : '1 cancha disponible')
                : widget.modoGestion
                ? '${_canchas.length} canchas en el catálogo'
                : '${_canchas.length} canchas disponibles',
            style: const TextStyle(
              color: LuxxitoColors.textoTenue,
              fontSize: 13,
            ),
          );
        }
        final cancha = _canchas[idx - 1];
        return TarjetaCancha(
          cancha: cancha,
          fotoComplejo: _fotos[cancha.complejoId],
          modoGestion: widget.modoGestion,
          onReservar: () => _abrirReserva(cancha),
          onCambiarFoto: () => _cambiarFoto(cancha),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ApiService.esAdmin
          ? FloatingActionButton.extended(
              onPressed: _nuevaCancha,
              icon: const Icon(Icons.add),
              label: const Text(
                'Nueva cancha',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Column(
        children: [
          FiltrosCatalogo(
            modoGestion: widget.modoGestion,
            distritos: _distritos,
            deportes: _deportes,
            distritoSeleccionado: _distritoFiltro,
            deporteSeleccionado: _deporteFiltro,
            onDistrito: (v) {
              setState(() => _distritoFiltro = v);
              _cargarCatalogo();
            },
            onDeporte: (v) {
              setState(() => _deporteFiltro = v);
              _cargarCatalogo();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarCatalogo,
              child: _contenido(),
            ),
          ),
        ],
      ),
    );
  }
}

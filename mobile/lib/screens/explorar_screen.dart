import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';
import 'disponibilidad_reserva_screen.dart';

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

  Future<void> _mostrarDialogoNuevaCancha() async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final superficieCtrl = TextEditingController(text: 'Grass sintético');
    final diurnoCtrl = TextEditingController(text: '85');
    final nocturnoCtrl = TextEditingController(text: '115');
    int? complejoSel = _complejos.isNotEmpty ? _complejos.first.id : null;
    String deporteSel = 'Futbol 7';
    bool techada = false;
    bool guardando = false;

    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + espacioInferior(ctx),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nueva cancha',
                    style: TextStyle(
                      color: LuxxitoColors.texto,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Se publicará de inmediato en el catálogo.',
                    style: TextStyle(color: LuxxitoColors.textoSecundario),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<int>(
                    initialValue: complejoSel,
                    dropdownColor: LuxxitoColors.superficieAlta,
                    decoration: const InputDecoration(
                      labelText: 'Complejo',
                      prefixIcon: Icon(Icons.stadium_outlined),
                    ),
                    items: _complejos
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? 'Elige un complejo' : null,
                    onChanged: (v) => setSheetState(() => complejoSel = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la cancha',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Escribe un nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: deporteSel,
                          dropdownColor: LuxxitoColors.superficieAlta,
                          decoration: const InputDecoration(
                            labelText: 'Deporte',
                          ),
                          items: _deportes
                              .where((d) => d.isNotEmpty)
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setSheetState(() => deporteSel = v ?? deporteSel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: superficieCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Superficie',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: diurnoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio día',
                            prefixText: 'S/ ',
                            helperText: 'Antes de 18:00',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                              ? 'Precio inválido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: nocturnoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio noche',
                            prefixText: 'S/ ',
                            helperText: 'Desde 18:00',
                          ),
                          validator: (v) {
                            final noche = double.tryParse(v ?? '') ?? 0;
                            final dia = double.tryParse(diurnoCtrl.text) ?? 0;
                            if (noche <= 0) return 'Precio inválido';
                            if (noche < dia) return 'Debe ser ≥ día';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cancha techada'),
                    value: techada,
                    onChanged: (v) => setSheetState(() => techada = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: guardando
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => guardando = true);
                            try {
                              await ApiService.crearCancha(
                                complejoId: complejoSel!,
                                nombre: nombreCtrl.text.trim(),
                                deporte: deporteSel,
                                superficie: superficieCtrl.text.trim(),
                                techada: techada,
                                precioDiurno: double.parse(diurnoCtrl.text),
                                precioNocturno: double.parse(nocturnoCtrl.text),
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop(true);
                            } catch (e) {
                              setSheetState(() => guardando = false);
                              if (!ctx.mounted) return;
                              mostrarAviso(
                                ctx,
                                mensajeError(e),
                                tipo: TipoAviso.error,
                              );
                            }
                          },
                    child: Text(guardando ? 'Guardando…' : 'Publicar cancha'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );


    if (creado == true && mounted) {
      mostrarAviso(context, 'Cancha publicada en el catálogo.');
      _cargarCatalogo();
    }
  }

  Widget _filtros() {
    final nombre = ApiService.currentSession?.nombre.split(' ').first ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.modoGestion
                ? 'Catálogo de canchas'
                : nombre.isEmpty
                    ? '¡Hola!'
                    : '¡Hola, $nombre!',
            style: const TextStyle(
              color: LuxxitoColors.texto,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.modoGestion
                ? 'Revisa precios y estado de cada cancha, o publica una nueva.'
                : '¿Dónde y a qué juegas hoy?',
            style: const TextStyle(color: LuxxitoColors.textoSecundario),
          ),
          const SizedBox(height: 14),
          _filaChips(
            opciones: _distritos,
            seleccion: _distritoFiltro,
            etiquetaTodos: 'Todo Lima',
            icono: (_) => Icons.location_on_outlined,
            onSeleccion: (v) {
              setState(() => _distritoFiltro = v);
              _cargarCatalogo();
            },
          ),
          const SizedBox(height: 8),
          _filaChips(
            opciones: _deportes,
            seleccion: _deporteFiltro,
            etiquetaTodos: 'Todos los deportes',
            icono: (d) => d.isEmpty ? Icons.sports : iconoDeporte(d),
            onSeleccion: (v) {
              setState(() => _deporteFiltro = v);
              _cargarCatalogo();
            },
          ),
        ],
      ),
    );
  }

  Widget _filaChips({
    required List<String> opciones,
    required String seleccion,
    required String etiquetaTodos,
    required IconData Function(String) icono,
    required ValueChanged<String> onSeleccion,
  }) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final valor = opciones[idx];
          final sel = valor == seleccion;
          return ChoiceChip(
            showCheckmark: false,
            avatar: Icon(
              icono(valor),
              size: 16,
              color: sel ? Colors.white : LuxxitoColors.textoSecundario,
            ),
            label: Text(valor.isEmpty ? etiquetaTodos : valor),
            selected: sel,
            onSelected: (_) => onSeleccion(valor),
          );
        },
      ),
    );
  }

  Widget _tarjetaCancha(Cancha cancha) {
    final activa = cancha.estado == 'ACTIVA';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activa && !widget.modoGestion ? () => _abrirReserva(cancha) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                FotoComplejo(
                  url: _fotos[cancha.complejoId],
                  iconoRespaldo: iconoDeporte(cancha.deporte),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconoDeporte(cancha.deporte),
                          size: 14,
                          color: LuxxitoColors.texto,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          cancha.deporte,
                          style: const TextStyle(
                            color: LuxxitoColors.texto,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                cancha.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LuxxitoColors.texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatoFila(
                    Icons.location_on_outlined,
                    '${cancha.complejoNombre} · ${cancha.distrito}',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Insignia(
                        cancha.superficie,
                        color: LuxxitoColors.textoSecundario,
                        icono: Icons.grass,
                      ),
                      Insignia(
                        cancha.techada ? 'Techada' : 'Aire libre',
                        color: LuxxitoColors.secundario,
                        icono: cancha.techada
                            ? Icons.roofing
                            : Icons.wb_sunny_outlined,
                      ),
                      if (cancha.iluminacion)
                        const Insignia(
                          'Iluminación',
                          color: LuxxitoColors.advertencia,
                          icono: Icons.lightbulb_outline,
                        ),
                      if (!activa)
                        const Insignia(
                          'En mantenimiento',
                          color: LuxxitoColors.error,
                          icono: Icons.construction,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Desde ',
                                    style: TextStyle(
                                      color: LuxxitoColors.textoSecundario,
                                      fontSize: 13,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        'S/ ${cancha.precioHoraDiurno.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: LuxxitoColors.texto,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' /hora',
                                    style: TextStyle(
                                      color: LuxxitoColors.textoSecundario,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Noche (desde 18:00): S/ ${cancha.precioHoraNocturno.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: LuxxitoColors.textoTenue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.modoGestion)
                        Insignia(
                          activa ? 'Activa' : 'Inactiva',
                          color: activa ? LuxxitoColors.exito : LuxxitoColors.error,
                          icono: activa ? Icons.check_circle : Icons.block,
                        )
                      else
                        FilledButton.icon(
                          onPressed: activa ? () => _abrirReserva(cancha) : null,
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Reservar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        if (idx == 0) {
          return Text(
            _canchas.length == 1
                ? (widget.modoGestion ? '1 cancha en el catálogo' : '1 cancha disponible')
                : widget.modoGestion
                    ? '${_canchas.length} canchas en el catálogo'
                    : '${_canchas.length} canchas disponibles',
            style: const TextStyle(
              color: LuxxitoColors.textoTenue,
              fontSize: 13,
            ),
          );
        }
        return _tarjetaCancha(_canchas[idx - 1]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ApiService.esAdmin
          ? FloatingActionButton.extended(
              onPressed: _mostrarDialogoNuevaCancha,
              icon: const Icon(Icons.add),
              label: const Text(
                'Nueva cancha',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: Column(
        children: [
          _filtros(),
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

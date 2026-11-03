import 'package:flutter/material.dart';
import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import 'disponibilidad_reserva_screen.dart';

class ExplorarScreen extends StatefulWidget {
  final VoidCallback onNavigateToReservas;

  const ExplorarScreen({super.key, required this.onNavigateToReservas});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  List<Complejo> _complejos = [];
  List<Cancha> _canchas = [];
  bool _cargando = true;
  String? _errorMsg;

  String _distritoFiltro = '';
  String _deporteFiltro = '';

  final List<String> _distritos = [
    '',
    'San Miguel',
    'Santiago de Surco',
    'Miraflores',
  ];

  final List<String> _deportes = [
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
        _canchas = results[1] as List<Cancha>;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _mostrarDialogoNuevaCancha() async {
    final nombreCtrl = TextEditingController();
    final superficieCtrl = TextEditingController(text: 'Grass Sintetico Pro');
    final diurnoCtrl = TextEditingController(text: '85');
    final nocturnoCtrl = TextEditingController(text: '115');
    int complejoSel = _complejos.isNotEmpty ? _complejos.first.id : 1;
    String deporteSel = 'Futbol 7';
    bool techada = false;

    final creado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Registrar Nueva Cancha (CRUD)',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: complejoSel,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Complejo Deportivo',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: (_complejos.isNotEmpty
                          ? _complejos
                          : [
                              Complejo(
                                id: 1,
                                nombre: 'Luxxito Arena San Miguel',
                                distrito: 'San Miguel',
                                direccion: '',
                                telefono: '',
                                horaApertura: 7,
                                horaCierre: 23,
                              )
                            ])
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => complejoSel = v ?? 1),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nombreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Cancha',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: deporteSel,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Deporte',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: ['Futbol 7', 'Futbol 5', 'Voley', 'Padel', 'Tenis']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => deporteSel = v ?? 'Futbol 7'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: diurnoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Precio Hora Diurno (S/)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nocturnoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Precio Hora Nocturno >=18h (S/)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Cancha Techada',
                      style: TextStyle(color: Colors.white)),
                  value: techada,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (v) => setDialogState(() => techada = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                try {
                  await ApiService.crearCancha(
                    complejoId: complejoSel,
                    nombre: nombreCtrl.text.trim(),
                    deporte: deporteSel,
                    superficie: superficieCtrl.text.trim(),
                    techada: techada,
                    precioDiurno: double.tryParse(diurnoCtrl.text) ?? 0,
                    precioNocturno: double.tryParse(nocturnoCtrl.text) ?? 0,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (creado == true) {
      _cargarCatalogo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.black,
        onPressed: _mostrarDialogoNuevaCancha,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva Cancha',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Panel de Filtros por Distrito y Deporte
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por Distrito:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _distritos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final dist = _distritos[idx];
                      final sel = dist == _distritoFiltro;
                      return ChoiceChip(
                        label: Text(dist.isEmpty ? 'Todos' : dist),
                        selected: sel,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: sel ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) {
                          setState(() => _distritoFiltro = dist);
                          _cargarCatalogo();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Filtrar por Deporte:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _deportes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final dep = _deportes[idx];
                      final sel = dep == _deporteFiltro;
                      return ChoiceChip(
                        label: Text(dep.isEmpty ? 'Todos' : dep),
                        selected: sel,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: sel ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) {
                          setState(() => _deporteFiltro = dep);
                          _cargarCatalogo();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : _errorMsg != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off,
                                  size: 56, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text(
                                _errorMsg!,
                                style: const TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _cargarCatalogo,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar conexión'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _canchas.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron canchas para los filtros seleccionados.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarCatalogo,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 85),
                              itemCount: _canchas.length,
                              itemBuilder: (context, idx) {
                                final cancha = _canchas[idx];
                                return Card(
                                  color: const Color(0xFF1E293B),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                        color: Colors.white12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${cancha.complejoNombre} · ${cancha.distrito}',
                                                style: const TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9)
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                cancha.deporte,
                                                style: const TextStyle(
                                                  color: Color(0xFF38BDF8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cancha.nombre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${cancha.superficie} · ${cancha.techada ? "Techada" : "Aire libre"} · ${cancha.estado}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Día: S/ ${cancha.precioHoraDiurno.toStringAsFixed(2)} /h',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Noche (>=18h): S/ ${cancha.precioHoraNocturno.toStringAsFixed(2)} /h',
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF10B981),
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () async {
                                                final ok = await Navigator.of(
                                                        context)
                                                    .push<bool>(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        DisponibilidadReservaScreen(
                                                      cancha: cancha,
                                                      onReservaCreada: widget
                                                          .onNavigateToReservas,
                                                    ),
                                                  ),
                                                );
                                                if (ok == true) {
                                                  widget.onNavigateToReservas();
                                                }
                                              },
                                              icon: const Icon(
                                                  Icons.calendar_month,
                                                  size: 18),
                                              label: const Text(
                                                'Ver Horarios',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

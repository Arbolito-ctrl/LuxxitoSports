import 'package:flutter/material.dart';
import '../models/luxxito_models.dart';
import '../services/api_service.dart';

class DisponibilidadReservaScreen extends StatefulWidget {
  final Cancha cancha;
  final VoidCallback onReservaCreada;

  const DisponibilidadReservaScreen({
    super.key,
    required this.cancha,
    required this.onReservaCreada,
  });

  @override
  State<DisponibilidadReservaScreen> createState() =>
      _DisponibilidadReservaScreenState();
}

class _DisponibilidadReservaScreenState
    extends State<DisponibilidadReservaScreen> {
  late String _fechaSeleccionada;
  DisponibilidadData? _disponibilidad;
  bool _cargando = true;
  String? _errorMsg;

  int? _horaInicioSel;
  int? _horaFinSel;
  final Map<int, int> _extrasSeleccionados = {};

  Map<String, dynamic>? _cotizacionServidor;
  bool _cotizando = false;
  bool _enviandoReserva = false;

  final _nombreCtrl = TextEditingController(text: 'Carlos Mendoza');
  final _dniCtrl = TextEditingController(text: '74125896');
  final _telefonoCtrl = TextEditingController(text: '987654321');
  final _emailCtrl = TextEditingController(text: 'carlos.mendoza@uni.pe');
  final _notasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final manana = DateTime.now().add(const Duration(days: 1));
    _fechaSeleccionada = _formatDate(manana);
    _cargarDisponibilidad();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<String> _proximosDias() {
    final hoy = DateTime.now();
    return List.generate(7, (i) => _formatDate(hoy.add(Duration(days: i + 1))));
  }

  Future<void> _cargarDisponibilidad() async {
    setState(() {
      _cargando = true;
      _errorMsg = null;
      _horaInicioSel = null;
      _horaFinSel = null;
      _extrasSeleccionados.clear();
      _cotizacionServidor = null;
    });

    try {
      final data = await ApiService.getDisponibilidad(
        canchaId: widget.cancha.id,
        fecha: _fechaSeleccionada,
      );
      if (!mounted) return;
      setState(() {
        _disponibilidad = data;
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

  void _seleccionarTurno(TurnoDisponibilidad turno) {
    if (turno.estado != 'DISPONIBLE') return;

    setState(() {
      if (_horaInicioSel == null ||
          (_horaInicioSel != null && _horaFinSel != _horaInicioSel! + 1)) {
        _horaInicioSel = turno.horaInicio;
        _horaFinSel = turno.horaFin;
      } else if (turno.horaInicio == _horaFinSel &&
          (_horaFinSel! - _horaInicioSel!) < 3) {
        // Permite seleccionar hasta 3 horas consecutivas
        _horaFinSel = turno.horaFin;
      } else {
        _horaInicioSel = turno.horaInicio;
        _horaFinSel = turno.horaFin;
      }
    });
    _solicitarCotizacionServidor();
  }

  Future<void> _solicitarCotizacionServidor() async {
    if (_horaInicioSel == null || _horaFinSel == null) return;
    setState(() {
      _cotizando = true;
    });
    try {
      final extrasPayload = _extrasSeleccionados.entries
          .where((e) => e.value > 0)
          .map((e) => {'extra_id': e.key, 'cantidad': e.value})
          .toList();

      final quote = await ApiService.cotizarReserva(
        canchaId: widget.cancha.id,
        fecha: _fechaSeleccionada,
        horaInicio: _horaInicioSel!,
        horaFin: _horaFinSel!,
        extras: extrasPayload,
      );
      if (!mounted) return;
      setState(() {
        _cotizacionServidor = quote;
        _cotizando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cotizando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmarCreacionReserva() async {
    if (_horaInicioSel == null || _horaFinSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero un horario disponible.')),
      );
      return;
    }

    setState(() {
      _enviandoReserva = true;
    });

    try {
      final extrasPayload = _extrasSeleccionados.entries
          .where((e) => e.value > 0)
          .map((e) => {'extra_id': e.key, 'cantidad': e.value})
          .toList();

      final reserva = await ApiService.crearReserva(
        canchaId: widget.cancha.id,
        clienteNombre: _nombreCtrl.text.trim(),
        clienteDni: _dniCtrl.text.trim(),
        clienteTelefono: _telefonoCtrl.text.trim(),
        clienteEmail: _emailCtrl.text.trim(),
        fecha: _fechaSeleccionada,
        horaInicio: _horaInicioSel!,
        horaFin: _horaFinSel!,
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        extras: extrasPayload,
      );

      if (!mounted) return;
      setState(() {
        _enviandoReserva = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Reserva #${reserva.id} creada con bloqueo de 20 min! Total: S/ ${reserva.total.toStringAsFixed(2)}',
          ),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      widget.onReservaCreada();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviandoReserva = false;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Expanded(child: Text('Validación del Servidor')),
            ],
          ),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = _proximosDias();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(widget.cancha.nombre),
        actions: [
          IconButton(
            onPressed: _cargarDisponibilidad,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar disponibilidad',
          ),
        ],
      ),
      body: _cargando
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
                        const Icon(Icons.cloud_off,
                            size: 56, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _cargarDisponibilidad,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Cabecera de cancha
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.cancha.complejoNombre} · ${widget.cancha.distrito}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.cancha.deporte} · ${widget.cancha.superficie}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildPriceTag(
                                'Día (<18h): S/ ${widget.cancha.precioHoraDiurno.toStringAsFixed(0)}',
                                const Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 8),
                              _buildPriceTag(
                                'Noche (>=18h): S/ ${widget.cancha.precioHoraNocturno.toStringAsFixed(0)}',
                                const Color(0xFF8B5CF6),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector horizontal de fechas
                    const Text(
                      '1. Selecciona la Fecha',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dias.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final d = dias[idx];
                          final activo = d == _fechaSeleccionada;
                          return ChoiceChip(
                            label: Text(d),
                            selected: activo,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: const Color(0xFF1E293B),
                            labelStyle: TextStyle(
                              color: activo ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _fechaSeleccionada = d;
                              });
                              _cargarDisponibilidad();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Grilla de horarios
                    const Text(
                      '2. Elige tu Turno (Toca horas consecutivas para ampliar)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_disponibilidad?.turnos ?? []).map((turno) {
                        final seleccionado = _horaInicioSel != null &&
                            _horaFinSel != null &&
                            turno.horaInicio >= _horaInicioSel! &&
                            turno.horaFin <= _horaFinSel!;

                        Color bgColor = const Color(0xFF1E293B);
                        Color borderColor = Colors.white24;
                        if (turno.estado != 'DISPONIBLE') {
                          bgColor = Colors.red.withValues(alpha: 0.18);
                          borderColor = Colors.redAccent;
                        } else if (seleccionado) {
                          bgColor = const Color(0xFF10B981);
                          borderColor = const Color(0xFF10B981);
                        }

                        return InkWell(
                          onTap: turno.estado == 'DISPONIBLE'
                              ? () => _seleccionarTurno(turno)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 155,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  turno.etiqueta,
                                  style: TextStyle(
                                    color: seleccionado
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${turno.estado} · S/ ${turno.precio.toStringAsFixed(0)} (${turno.tarifaTipo == 'NOCTURNA' ? 'Noche' : 'Día'})',
                                  style: TextStyle(
                                    color: seleccionado
                                        ? Colors.black87
                                        : Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Selección de Extras con stock del servidor
                    const Text(
                      '3. Equipamiento Adicional / Extras (Opcional)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_disponibilidad?.extrasDisponibles ?? []).map((extra) {
                      final cant = _extrasSeleccionados[extra.id] ?? 0;
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            extra.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'S/ ${extra.precioUnitario.toStringAsFixed(2)} c/u · Stock máx: ${extra.stockDisponible}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.white70),
                                onPressed: cant > 0
                                    ? () {
                                        setState(() {
                                          _extrasSeleccionados[extra.id] =
                                              cant - 1;
                                        });
                                        _solicitarCotizacionServidor();
                                      }
                                    : null,
                              ),
                              Text(
                                '$cant',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Color(0xFF10B981)),
                                onPressed: cant < extra.stockDisponible
                                    ? () {
                                        setState(() {
                                          _extrasSeleccionados[extra.id] =
                                              cant + 1;
                                        });
                                        _solicitarCotizacionServidor();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Resumen de Cotización del Servidor
                    if (_cotizando)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                              color: Color(0xFF10B981)),
                        ),
                      )
                    else if (_cotizacionServidor != null)
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
                            const Text(
                              'Cotización Verificada por el Servidor',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Horario: ${_cotizacionServidor!['hora_inicio']}:00 - ${_cotizacionServidor!['hora_fin']}:00 (${_cotizacionServidor!['duracion_horas']} h)',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'Subtotal Cancha: S/ ${(_cotizacionServidor!['subtotal_cancha'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Subtotal Extras: S/ ${(_cotizacionServidor!['subtotal_extras'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Divider(color: Colors.white24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL: S/ ${(_cotizacionServidor!['total'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Seña 50%: S/ ${(_cotizacionServidor!['monto_sena_50'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFF6EE7B7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),

                    // Formulario de datos del cliente
                    const Text(
                      '4. Datos del Titular de la Reserva',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(_nombreCtrl, 'Nombre Completo', Icons.person),
                    const SizedBox(height: 10),
                    _buildTextField(
                        _dniCtrl, 'DNI (8 dígitos)', Icons.badge_outlined),
                    const SizedBox(height: 10),
                    _buildTextField(
                        _telefonoCtrl, 'Teléfono / Celular', Icons.phone),
                    const SizedBox(height: 10),
                    _buildTextField(
                        _emailCtrl, 'Correo Electrónico', Icons.email_outlined),
                    const SizedBox(height: 10),
                    _buildTextField(
                      _notasCtrl,
                      'Notas adicionales (opcional)',
                      Icons.notes,
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            _enviandoReserva ? null : _confirmarCreacionReserva,
                        icon: _enviandoReserva
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.lock_clock),
                        label: Text(
                          _enviandoReserva
                              ? 'Procesando en servidor...'
                              : 'Adquirir Bloqueo (20 min) y Reservar',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }

  Widget _buildPriceTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
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

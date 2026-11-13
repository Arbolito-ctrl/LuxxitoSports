import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/disponibilidad/barra_reserva.dart';
import '../widgets/disponibilidad/cabecera_cancha.dart';
import '../widgets/disponibilidad/dialogos_disponibilidad.dart';
import '../widgets/disponibilidad/formulario_titular.dart';
import '../widgets/disponibilidad/grilla_turnos.dart';
import '../widgets/disponibilidad/resumen_cotizacion.dart';
import '../widgets/disponibilidad/selector_extras.dart';
import '../widgets/disponibilidad/selector_fechas.dart';
import '../widgets/luxxito_widgets.dart';

/// Pantalla para reservar una cancha: el jugador elige día, horas seguidas y
/// extras; el servidor cotiza el precio y, al confirmar, crea la reserva con un
/// bloqueo de 20 minutos para pagar.
///
/// Esta pantalla guarda el estado (fecha, horario, extras, cotización) y habla
/// con la API. Lo visual está en widgets/disponibilidad/.
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
  static const int _maxHoras = 3;

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
  bool _editarTitular = false;

  final _titularKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si hay sesión, el titular se rellena con los datos del jugador
    final session = ApiService.currentSession;
    if (session != null) {
      _nombreCtrl.text = session.nombre;
      _dniCtrl.text = session.dni;
      _telefonoCtrl.text = session.telefono;
      _emailCtrl.text = session.email;
    }
    _editarTitular = session == null;
    _fechaSeleccionada = fechaIso(
      DateTime.now().add(const Duration(days: 1)),
    );
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

  // ---------------------------------------------------------------------------
  // Datos y acciones
  // ---------------------------------------------------------------------------

  /// Consulta los turnos y extras del día elegido y reinicia la selección.
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
        _errorMsg = mensajeError(e);
        _cargando = false;
      });
    }
  }

  /// Reglas al tocar un turno libre:
  /// - Si es el único seleccionado, se deselecciona.
  /// - Si va justo después del último elegido (y no supera 3 horas), se suma.
  /// - En otro caso, la selección empieza de nuevo en ese turno.
  void _seleccionarTurno(TurnoDisponibilidad turno) {
    if (turno.estado != 'DISPONIBLE') return;

    setState(() {
      final extiende =
          _horaInicioSel != null &&
          turno.horaInicio == _horaFinSel &&
          (_horaFinSel! - _horaInicioSel!) < _maxHoras;
      final esUnicoSeleccionado =
          _horaInicioSel == turno.horaInicio && _horaFinSel == turno.horaFin;

      if (esUnicoSeleccionado) {
        _horaInicioSel = null;
        _horaFinSel = null;
        _cotizacionServidor = null;
      } else if (extiende) {
        _horaFinSel = turno.horaFin;
      } else {
        _horaInicioSel = turno.horaInicio;
        _horaFinSel = turno.horaFin;
      }
    });
    _solicitarCotizacionServidor();
  }

  void _cambiarExtra(int extraId, int cantidad) {
    setState(() => _extrasSeleccionados[extraId] = cantidad);
    _solicitarCotizacionServidor();
  }

  /// Pide al servidor el precio del horario y extras elegidos.
  Future<void> _solicitarCotizacionServidor() async {
    if (_horaInicioSel == null || _horaFinSel == null) return;
    setState(() => _cotizando = true);
    try {
      final quote = await ApiService.cotizarReserva(
        canchaId: widget.cancha.id,
        fecha: _fechaSeleccionada,
        horaInicio: _horaInicioSel!,
        horaFin: _horaFinSel!,
        extras: _extrasPayload(),
      );
      if (!mounted) return;
      setState(() {
        _cotizacionServidor = quote;
        _cotizando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cotizando = false);
      mostrarAviso(context, mensajeError(e), tipo: TipoAviso.error);
    }
  }

  /// Extras con cantidad mayor a 0, en el formato que espera la API.
  List<Map<String, int>> _extrasPayload() => _extrasSeleccionados.entries
      .where((e) => e.value > 0)
      .map((e) => {'extra_id': e.key, 'cantidad': e.value})
      .toList();

  Future<void> _confirmarCreacionReserva() async {
    if (_horaInicioSel == null || _horaFinSel == null) return;
    if (_editarTitular && !(_titularKey.currentState?.validate() ?? true)) {
      mostrarAviso(
        context,
        'Completa los datos del titular.',
        tipo: TipoAviso.error,
      );
      return;
    }

    setState(() => _enviandoReserva = true);
    try {
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
        extras: _extrasPayload(),
      );

      if (!mounted) return;
      setState(() => _enviandoReserva = false);
      await mostrarDialogoReservaCreada(
        context,
        canchaNombre: widget.cancha.nombre,
        reserva: reserva,
      );
      if (!mounted) return;
      widget.onReservaCreada();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviandoReserva = false);
      final recargar = await mostrarDialogoErrorReserva(context, e);
      if (recargar && mounted) _cargarDisponibilidad();
    }
  }

  // ---------------------------------------------------------------------------
  // Pantalla
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hayHorario = _horaInicioSel != null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.cancha.nombre, style: const TextStyle(fontSize: 18)),
            Text(
              widget.cancha.complejoNombre,
              style: const TextStyle(
                fontSize: 12.5,
                color: LuxxitoColors.textoSecundario,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargarDisponibilidad,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar horarios',
          ),
        ],
      ),
      bottomNavigationBar: _cargando || _errorMsg != null
          ? null
          : BarraReserva(
              textoHorario: hayHorario
                  ? '${Formato.fecha(_fechaSeleccionada)} · ${Formato.rango(_horaInicioSel!, _horaFinSel!)}'
                  : null,
              total: _cotizacionServidor?['total'] as num?,
              cotizando: _cotizando,
              enviando: _enviandoReserva,
              onReservar: _confirmarCreacionReserva,
            ),
      body: _cargando
          ? const EstadoVista.cargando(titulo: 'Consultando horarios…')
          : _errorMsg != null
          ? EstadoVista.error(
              titulo: 'No pudimos cargar los horarios',
              mensaje: _errorMsg!,
              onReintentar: _cargarDisponibilidad,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                CabeceraCancha(
                  cancha: widget.cancha,
                  complejo: _disponibilidad?.complejo,
                ),
                const SizedBox(height: 22),
                const SeccionTitulo('¿Qué día quieres jugar?'),
                SelectorFechas(
                  fechaSeleccionada: _fechaSeleccionada,
                  onSeleccionar: (iso) {
                    setState(() => _fechaSeleccionada = iso);
                    _cargarDisponibilidad();
                  },
                ),
                const SizedBox(height: 22),
                SeccionTitulo(
                  '¿A qué hora?',
                  subtitulo:
                      'Toca horas seguidas para jugar hasta $_maxHoras horas.',
                ),
                const LeyendaTurnos(),
                const SizedBox(height: 12),
                GrillaTurnos(
                  turnos: _disponibilidad?.turnos ?? [],
                  horaInicioSel: _horaInicioSel,
                  horaFinSel: _horaFinSel,
                  onSeleccionar: _seleccionarTurno,
                ),
                const SizedBox(height: 22),
                const SeccionTitulo(
                  'Extras',
                  subtitulo: 'Opcional: chalecos, balones, árbitro y más.',
                ),
                SelectorExtras(
                  extras: _disponibilidad?.extrasDisponibles ?? [],
                  cantidades: _extrasSeleccionados,
                  hayHorario: hayHorario,
                  onCambiar: _cambiarExtra,
                ),
                if (_cotizacionServidor != null || _cotizando) ...[
                  const SizedBox(height: 12),
                  const SeccionTitulo('Resumen'),
                  ResumenCotizacion(
                    cotizacion: _cotizacionServidor,
                    cotizando: _cotizando,
                  ),
                ],
                const SizedBox(height: 22),
                const SeccionTitulo('Titular de la reserva'),
                FormularioTitular(
                  formKey: _titularKey,
                  nombreCtrl: _nombreCtrl,
                  dniCtrl: _dniCtrl,
                  telefonoCtrl: _telefonoCtrl,
                  emailCtrl: _emailCtrl,
                  editando: _editarTitular,
                  onEditar: () => setState(() => _editarTitular = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notasCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas para el complejo (opcional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
    );
  }
}

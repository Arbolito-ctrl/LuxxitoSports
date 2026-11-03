import 'package:flutter/material.dart';

import '../models/luxxito_models.dart';
import '../services/api_service.dart';
import '../theme/luxxito_theme.dart';
import '../widgets/luxxito_widgets.dart';

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
    final session = ApiService.currentSession;
    if (session != null) {
      _nombreCtrl.text = session.nombre;
      _dniCtrl.text = session.dni;
      _telefonoCtrl.text = session.telefono;
      _emailCtrl.text = session.email;
    }
    _editarTitular = session == null;
    _fechaSeleccionada = _formatDate(
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

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<DateTime> _proximosDias() {
    final hoy = DateTime.now();
    return List.generate(8, (i) => DateTime(hoy.year, hoy.month, hoy.day + i));
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
        _errorMsg = mensajeError(e);
        _cargando = false;
      });
    }
  }

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
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: LuxxitoColors.exito,
            size: 48,
          ),
          title: const Text('¡Turno reservado!'),
          content: Text(
            '${widget.cancha.nombre}\n'
            '${Formato.fechaLarga(reserva.fecha)} · ${Formato.rango(reserva.horaInicio, reserva.horaFin)}\n\n'
            'Te guardamos el turno por 20 minutos. Envía tu comprobante de '
            '${Formato.soles(reserva.total)} desde "Mis reservas" para confirmarlo.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ir a pagar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      widget.onReservaCreada();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviandoReserva = false);
      final ocupado = e is ApiException && e.statusCode == 409;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            ocupado ? Icons.event_busy : Icons.error_outline,
            color: LuxxitoColors.error,
            size: 44,
          ),
          title: Text(
            ocupado ? 'Ese horario ya no está libre' : 'No pudimos reservar',
          ),
          content: Text(mensajeError(e), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (ocupado) _cargarDisponibilidad();
              },
              child: Text(ocupado ? 'Ver horarios actualizados' : 'Entendido'),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _cabecera() {
    final complejo = _disponibilidad?.complejo;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FotoComplejo(
            url: complejo?.imagenUrl,
            iconoRespaldo: iconoDeporte(widget.cancha.deporte),
            height: 140,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: LuxxitoColors.primario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconoDeporte(widget.cancha.deporte),
                    color: LuxxitoColors.primario,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.cancha.deporte} · ${widget.cancha.superficie}',
                        style: const TextStyle(
                          color: LuxxitoColors.texto,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        complejo != null && complejo.direccion.isNotEmpty
                            ? '${complejo.nombre} · ${complejo.direccion}'
                            : '${widget.cancha.complejoNombre} · ${widget.cancha.distrito}',
                        style: const TextStyle(
                          color: LuxxitoColors.textoSecundario,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Insignia(
                            'Día S/ ${widget.cancha.precioHoraDiurno.toStringAsFixed(0)}',
                            color: LuxxitoColors.secundario,
                            icono: Icons.wb_sunny_outlined,
                          ),
                          Insignia(
                            'Noche S/ ${widget.cancha.precioHoraNocturno.toStringAsFixed(0)}',
                            color: LuxxitoColors.nocturno,
                            icono: Icons.nightlight_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorFechas() {
    final dias = _proximosDias();
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final d = dias[idx];
          final iso = _formatDate(d);
          final activo = iso == _fechaSeleccionada;
          final etiqueta = idx == 0
              ? 'Hoy'
              : idx == 1
              ? 'Mañana'
              : Formato.diaSemana(d);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (activo) return;
              setState(() => _fechaSeleccionada = iso);
              _cargarDisponibilidad();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              decoration: BoxDecoration(
                color: activo
                    ? LuxxitoColors.primario
                    : LuxxitoColors.superficie,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: activo ? LuxxitoColors.primario : LuxxitoColors.borde,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    etiqueta,
                    style: TextStyle(
                      color: activo
                          ? Colors.white
                          : LuxxitoColors.textoSecundario,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      color: activo ? Colors.white : LuxxitoColors.texto,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    Formato.mesCorto(d),
                    style: TextStyle(
                      color: activo ? Colors.white70 : LuxxitoColors.textoTenue,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _etiquetaNoDisponible(String estado) {
    switch (estado) {
      case 'OCUPADA':
        return 'Ocupado';
      case 'BLOQUEADA':
        return 'Reservándose';
      case 'MANTENIMIENTO':
        return 'Mantenimiento';
      case 'PASADA':
        return 'Ya pasó';
      default:
        return 'No disponible';
    }
  }

  Widget _leyenda() {
    Widget item(Color color, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(color: LuxxitoColors.textoTenue, fontSize: 12),
        ),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(LuxxitoColors.superficieAlta, 'Libre'),
        item(LuxxitoColors.primario, 'Tu selección'),
        item(LuxxitoColors.error.withValues(alpha: 0.5), 'No disponible'),
      ],
    );
  }

  Widget _grillaTurnos() {
    final turnos = _disponibilidad?.turnos ?? [];
    if (turnos.isEmpty) {
      return const AvisoBanner(
        icono: Icons.event_busy,
        color: LuxxitoColors.advertencia,
        texto: 'No hay horarios publicados para este día.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const columnas = 3;
        const espacio = 10.0;
        final ancho =
            (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: turnos.map((turno) {
            final libre = turno.estado == 'DISPONIBLE';
            final seleccionado =
                _horaInicioSel != null &&
                turno.horaInicio >= _horaInicioSel! &&
                turno.horaFin <= _horaFinSel!;
            final nocturno = turno.tarifaTipo == 'NOCTURNA';

            final fondo = seleccionado
                ? LuxxitoColors.primario
                : libre
                ? LuxxitoColors.superficie
                : LuxxitoColors.error.withValues(alpha: 0.08);
            final colorTexto = seleccionado
                ? Colors.white
                : libre
                ? LuxxitoColors.texto
                : LuxxitoColors.textoTenue;

            return InkWell(
              onTap: libre ? () => _seleccionarTurno(turno) : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: ancho,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: seleccionado
                        ? LuxxitoColors.primario
                        : libre
                        ? LuxxitoColors.borde
                        : LuxxitoColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (nocturno && libre) ...[
                          Icon(
                            Icons.nightlight_round,
                            size: 12,
                            color: seleccionado
                                ? Colors.white70
                                : LuxxitoColors.nocturno,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          Formato.hora(turno.horaInicio),
                          style: TextStyle(
                            color: colorTexto,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: libre
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      libre
                          ? 'S/ ${turno.precio.toStringAsFixed(0)}'
                          : _etiquetaNoDisponible(turno.estado),
                      style: TextStyle(
                        color: seleccionado
                            ? Colors.white70
                            : LuxxitoColors.textoTenue,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _extras() {
    final extras = _disponibilidad?.extrasDisponibles ?? [];
    if (extras.isEmpty) {
      return const Text(
        'Este complejo no ofrece extras por ahora.',
        style: TextStyle(color: LuxxitoColors.textoTenue),
      );
    }
    final sinHorario = _horaInicioSel == null;
    return Column(
      children: extras.map((extra) {
        final cant = _extrasSeleccionados[extra.id] ?? 0;
        final agotado = extra.stockDisponible <= 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          extra.nombre,
                          style: const TextStyle(
                            color: LuxxitoColors.texto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agotado
                              ? 'Agotado para este horario'
                              : '${Formato.soles(extra.precioUnitario)} c/u · quedan ${extra.stockDisponible}',
                          style: TextStyle(
                            color: agotado
                                ? LuxxitoColors.error
                                : LuxxitoColors.textoTenue,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.remove_circle_outline),
                    color: LuxxitoColors.textoSecundario,
                    onPressed: cant > 0
                        ? () {
                            setState(
                              () => _extrasSeleccionados[extra.id] = cant - 1,
                            );
                            _solicitarCotizacionServidor();
                          }
                        : null,
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$cant',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cant > 0
                            ? LuxxitoColors.primario
                            : LuxxitoColors.textoTenue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: sinHorario
                        ? 'Elige primero un horario'
                        : 'Agregar',
                    icon: const Icon(Icons.add_circle),
                    color: LuxxitoColors.primario,
                    onPressed: !sinHorario && cant < extra.stockDisponible
                        ? () {
                            setState(
                              () => _extrasSeleccionados[extra.id] = cant + 1,
                            );
                            _solicitarCotizacionServidor();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _resumen() {
    final q = _cotizacionServidor;
    if (_cotizando && q == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (q == null) return const SizedBox.shrink();

    Widget fila(String etiqueta, num monto, {bool destacado = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    color: destacado
                        ? LuxxitoColors.texto
                        : LuxxitoColors.textoSecundario,
                    fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
                    fontSize: destacado ? 16 : 14,
                  ),
                ),
              ),
              Text(
                Formato.soles(monto),
                style: TextStyle(
                  color: LuxxitoColors.texto,
                  fontWeight: destacado ? FontWeight.bold : FontWeight.w500,
                  fontSize: destacado ? 18 : 14,
                ),
              ),
            ],
          ),
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _cotizando ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              fila(
                'Cancha · ${q['duracion_horas']} h (${Formato.rango((q['hora_inicio'] as num).toInt(), (q['hora_fin'] as num).toInt())})',
                q['subtotal_cancha'] as num,
              ),
              if ((q['subtotal_extras'] as num) > 0)
                fila('Extras', q['subtotal_extras'] as num),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              fila('Total', q['total'] as num, destacado: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: LuxxitoColors.textoTenue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Puedes adelantar solo el 50% (${Formato.soles(q['monto_sena_50'] as num)}) y pagar el resto en el complejo.',
                      style: const TextStyle(
                        color: LuxxitoColors.textoTenue,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titular() {
    if (!_editarTitular) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: LuxxitoColors.primario.withValues(alpha: 0.2),
            child: Text(
              Formato.iniciales(_nombreCtrl.text),
              style: const TextStyle(
                color: LuxxitoColors.primario,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            _nombreCtrl.text,
            style: const TextStyle(
              color: LuxxitoColors.texto,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'DNI ${_dniCtrl.text} · ${_telefonoCtrl.text}',
            style: const TextStyle(color: LuxxitoColors.textoTenue),
          ),
          trailing: TextButton(
            onPressed: () => setState(() => _editarTitular = true),
            child: const Text('Cambiar'),
          ),
        ),
      );
    }
    return Form(
      key: _titularKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Ingresa el nombre' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dniCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'DNI',
                    counterText: '',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => RegExp(r'^\d{8}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '8 dígitos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    counterText: '',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      RegExp(r'^9\d{8}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : '9 dígitos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
                ? null
                : 'Revisa el correo',
          ),
        ],
      ),
    );
  }

  Widget _barraInferior() {
    final total = _cotizacionServidor?['total'] as num?;
    final hayHorario = _horaInicioSel != null;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + espacioInferior(context)),
      decoration: const BoxDecoration(
        color: LuxxitoColors.superficie,
        border: Border(top: BorderSide(color: LuxxitoColors.borde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hayHorario
                      ? '${Formato.fecha(_fechaSeleccionada)} · ${Formato.rango(_horaInicioSel!, _horaFinSel!)}'
                      : 'Elige un horario',
                  style: const TextStyle(
                    color: LuxxitoColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  total != null ? Formato.soles(total) : '—',
                  style: const TextStyle(
                    color: LuxxitoColors.texto,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed:
                hayHorario && total != null && !_enviandoReserva && !_cotizando
                ? _confirmarCreacionReserva
                : null,
            icon: _enviandoReserva
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_clock),
            label: Text(_enviandoReserva ? 'Reservando…' : 'Reservar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          : _barraInferior(),
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
                _cabecera(),
                const SizedBox(height: 22),
                const SeccionTitulo('¿Qué día quieres jugar?'),
                _selectorFechas(),
                const SizedBox(height: 22),
                SeccionTitulo(
                  '¿A qué hora?',
                  subtitulo:
                      'Toca horas seguidas para jugar hasta $_maxHoras horas.',
                ),
                _leyenda(),
                const SizedBox(height: 12),
                _grillaTurnos(),
                const SizedBox(height: 22),
                const SeccionTitulo(
                  'Extras',
                  subtitulo: 'Opcional: chalecos, balones, árbitro y más.',
                ),
                _extras(),
                if (_cotizacionServidor != null || _cotizando) ...[
                  const SizedBox(height: 12),
                  const SeccionTitulo('Resumen'),
                  _resumen(),
                ],
                const SizedBox(height: 22),
                const SeccionTitulo('Titular de la reserva'),
                _titular(),
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

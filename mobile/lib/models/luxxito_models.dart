class UserSession {
  final int id;
  final String nombre;
  final String dni;
  final String telefono;
  final String email;
  final String rol;
  final String token;

  UserSession({
    required this.id,
    required this.nombre,
    required this.dni,
    required this.telefono,
    required this.email,
    required this.rol,
    required this.token,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, {String? tokenOverride}) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return UserSession(
      id: (userMap['id'] as num?)?.toInt() ?? 1,
      nombre: userMap['nombre']?.toString() ?? '',
      dni: userMap['dni']?.toString() ?? '',
      telefono: userMap['telefono']?.toString() ?? '',
      email: userMap['email']?.toString() ?? '',
      rol: userMap['rol']?.toString() ?? 'JUGADOR',
      token: tokenOverride ?? json['token']?.toString() ?? '',
    );
  }
}

class Complejo {
  final int id;
  final String nombre;
  final String distrito;
  final String direccion;
  final String telefono;
  final int horaApertura;
  final int horaCierre;
  final String? imagenUrl;

  Complejo({
    required this.id,
    required this.nombre,
    required this.distrito,
    required this.direccion,
    required this.telefono,
    required this.horaApertura,
    required this.horaCierre,
    this.imagenUrl,
  });

  factory Complejo.fromJson(Map<String, dynamic> json) {
    return Complejo(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre']?.toString() ?? '',
      distrito: json['distrito']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      horaApertura: (json['hora_apertura'] as num?)?.toInt() ?? 7,
      horaCierre: (json['hora_cierre'] as num?)?.toInt() ?? 23,
      imagenUrl: json['imagen_url']?.toString(),
    );
  }
}

class Cancha {
  final int id;
  final int complejoId;
  final String complejoNombre;
  final String distrito;
  final String direccion;
  final String nombre;
  final String deporte;
  final String superficie;
  final bool techada;
  final bool iluminacion;
  final double precioHoraDiurno;
  final double precioHoraNocturno;
  final String estado;

  Cancha({
    required this.id,
    required this.complejoId,
    required this.complejoNombre,
    required this.distrito,
    required this.direccion,
    required this.nombre,
    required this.deporte,
    required this.superficie,
    required this.techada,
    required this.iluminacion,
    required this.precioHoraDiurno,
    required this.precioHoraNocturno,
    required this.estado,
  });

  factory Cancha.fromJson(Map<String, dynamic> json) {
    return Cancha(
      id: (json['id'] as num).toInt(),
      complejoId: (json['complejo_id'] as num).toInt(),
      complejoNombre: json['complejo_nombre']?.toString() ?? 'Complejo Luxxito',
      distrito: json['distrito']?.toString() ?? 'Lima',
      direccion: json['direccion']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      deporte: json['deporte']?.toString() ?? '',
      superficie: json['superficie']?.toString() ?? 'Grass Sintético',
      techada: json['techada'] == true,
      iluminacion: json['iluminacion'] == true,
      precioHoraDiurno: (json['precio_hora_diurno'] as num).toDouble(),
      precioHoraNocturno: (json['precio_hora_nocturno'] as num).toDouble(),
      estado: json['estado']?.toString() ?? 'ACTIVA',
    );
  }
}

class ExtraItem {
  final int id;
  final int complejoId;
  final String nombre;
  final String descripcion;
  final double precioUnitario;
  final int stockTotal;
  final int stockDisponible;

  ExtraItem({
    required this.id,
    required this.complejoId,
    required this.nombre,
    required this.descripcion,
    required this.precioUnitario,
    required this.stockTotal,
    required this.stockDisponible,
  });

  factory ExtraItem.fromJson(Map<String, dynamic> json) {
    final total = (json['stock_total'] as num?)?.toInt() ?? 0;
    return ExtraItem(
      id: (json['id'] as num).toInt(),
      complejoId: (json['complejo_id'] as num?)?.toInt() ?? 1,
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      stockTotal: total,
      stockDisponible: (json['stock_disponible'] as num?)?.toInt() ?? total,
    );
  }
}

class TurnoDisponibilidad {
  final int horaInicio;
  final int horaFin;
  final String etiqueta;
  final String tarifaTipo;
  final double precio;
  final String estado;

  TurnoDisponibilidad({
    required this.horaInicio,
    required this.horaFin,
    required this.etiqueta,
    required this.tarifaTipo,
    required this.precio,
    required this.estado,
  });

  factory TurnoDisponibilidad.fromJson(Map<String, dynamic> json) {
    return TurnoDisponibilidad(
      horaInicio: (json['hora_inicio'] as num).toInt(),
      horaFin: (json['hora_fin'] as num).toInt(),
      etiqueta: json['etiqueta']?.toString() ?? '',
      tarifaTipo: json['tarifa_tipo']?.toString() ?? 'DIURNA',
      precio: (json['precio'] as num).toDouble(),
      estado: json['estado']?.toString() ?? 'DISPONIBLE',
    );
  }
}

class DisponibilidadData {
  final Cancha cancha;
  final Complejo complejo;
  final String fecha;
  final List<TurnoDisponibilidad> turnos;
  final List<ExtraItem> extrasDisponibles;

  DisponibilidadData({
    required this.cancha,
    required this.complejo,
    required this.fecha,
    required this.turnos,
    required this.extrasDisponibles,
  });

  factory DisponibilidadData.fromJson(Map<String, dynamic> json) {
    return DisponibilidadData(
      cancha: Cancha.fromJson(json['cancha'] as Map<String, dynamic>),
      complejo: Complejo.fromJson(json['complejo'] as Map<String, dynamic>),
      fecha: json['fecha']?.toString() ?? '',
      turnos: (json['turnos'] as List<dynamic>? ?? [])
          .map((e) => TurnoDisponibilidad.fromJson(e as Map<String, dynamic>))
          .toList(),
      extrasDisponibles: (json['extras_disponibles'] as List<dynamic>? ?? [])
          .map((e) => ExtraItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReservaExtraDetalle {
  final int extraId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  ReservaExtraDetalle({
    required this.extraId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ReservaExtraDetalle.fromJson(Map<String, dynamic> json) {
    return ReservaExtraDetalle(
      extraId: (json['extra_id'] as num).toInt(),
      nombre: json['nombre']?.toString() ?? 'Extra deportivo',
      cantidad: (json['cantidad'] as num).toInt(),
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );
  }
}

class Pago {
  final int id;
  final int reservaId;
  final String metodo;
  final String modalidad;
  final double monto;
  final String numeroOperacion;
  final String? comprobanteUrl;
  /// Enlace temporal para ver el voucher (solo lo envía la bandeja del operador).
  final String? comprobanteUrlFirmada;
  final String estado;
  final String? observacion;
  final String createdAt;

  Pago({
    required this.id,
    required this.reservaId,
    required this.metodo,
    required this.modalidad,
    required this.monto,
    required this.numeroOperacion,
    this.comprobanteUrl,
    this.comprobanteUrlFirmada,
    required this.estado,
    this.observacion,
    required this.createdAt,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      id: (json['id'] as num).toInt(),
      reservaId: (json['reserva_id'] as num).toInt(),
      metodo: json['metodo']?.toString() ?? 'YAPE',
      modalidad: json['modalidad']?.toString() ?? 'TOTAL',
      monto: (json['monto'] as num).toDouble(),
      numeroOperacion: json['numero_operacion']?.toString() ?? '',
      comprobanteUrl: json['comprobante_url']?.toString(),
      comprobanteUrlFirmada: json['comprobante_url_firmada']?.toString(),
      estado: json['estado']?.toString() ?? 'PENDIENTE_REVISION',
      observacion: json['observacion']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

/// Pago de la bandeja del operador (GET /api/pagos) con el resumen de su reserva.
class PagoEnRevision {
  final Pago pago;
  final String reservaEstado;
  final String canchaNombre;
  final String complejoNombre;
  final String clienteNombre;
  final String clienteDni;
  final String clienteTelefono;
  final String fecha;
  final int horaInicio;
  final int horaFin;
  final double total;

  PagoEnRevision({
    required this.pago,
    required this.reservaEstado,
    required this.canchaNombre,
    required this.complejoNombre,
    required this.clienteNombre,
    required this.clienteDni,
    required this.clienteTelefono,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.total,
  });

  factory PagoEnRevision.fromJson(Map<String, dynamic> json) {
    final reserva = json['reserva'] as Map<String, dynamic>? ?? const {};
    return PagoEnRevision(
      pago: Pago.fromJson(json),
      reservaEstado: reserva['estado']?.toString() ?? '',
      canchaNombre: reserva['cancha_nombre']?.toString() ?? 'Cancha',
      complejoNombre: reserva['complejo_nombre']?.toString() ?? 'Complejo Luxxito',
      clienteNombre: reserva['cliente_nombre']?.toString() ?? '',
      clienteDni: reserva['cliente_dni']?.toString() ?? '',
      clienteTelefono: reserva['cliente_telefono']?.toString() ?? '',
      fecha: reserva['fecha']?.toString() ?? '',
      horaInicio: (reserva['hora_inicio'] as num?)?.toInt() ?? 0,
      horaFin: (reserva['hora_fin'] as num?)?.toInt() ?? 0,
      total: (reserva['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Reserva {
  final int id;
  final int canchaId;
  final String canchaNombre;
  final String deporte;
  final String complejoNombre;
  final String distrito;
  final String clienteNombre;
  final String clienteDni;
  final String clienteTelefono;
  final String clienteEmail;
  final String fecha;
  final int horaInicio;
  final int horaFin;
  final double subtotalCancha;
  final double subtotalExtras;
  final double total;
  final double montoPagado;
  final double montoDevolucion;
  final String estado;
  final String? codigoQr;
  final String? motivoCancelacion;
  final String? notas;
  final String expiresAt;
  final List<ReservaExtraDetalle> extras;
  final List<Pago> pagos;

  Reserva({
    required this.id,
    required this.canchaId,
    required this.canchaNombre,
    required this.deporte,
    required this.complejoNombre,
    required this.distrito,
    required this.clienteNombre,
    required this.clienteDni,
    required this.clienteTelefono,
    required this.clienteEmail,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.subtotalCancha,
    required this.subtotalExtras,
    required this.total,
    required this.montoPagado,
    required this.montoDevolucion,
    required this.estado,
    this.codigoQr,
    this.motivoCancelacion,
    this.notas,
    required this.expiresAt,
    required this.extras,
    this.pagos = const [],
  });

  /// Último pago rechazado si el jugador aún no ha reenviado un comprobante válido.
  Pago? get rechazoVigente {
    if (estado != 'PENDIENTE_PAGO' || pagos.isEmpty) return null;
    final ultimo = pagos.last;
    return ultimo.estado == 'RECHAZADO' ? ultimo : null;
  }

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: (json['id'] as num).toInt(),
      canchaId: (json['cancha_id'] as num).toInt(),
      canchaNombre: json['cancha_nombre']?.toString() ?? 'Cancha #${json['cancha_id']}',
      deporte: json['deporte']?.toString() ?? 'Deporte',
      complejoNombre: json['complejo_nombre']?.toString() ?? 'Complejo Luxxito',
      distrito: json['distrito']?.toString() ?? 'Lima',
      clienteNombre: json['cliente_nombre']?.toString() ?? '',
      clienteDni: json['cliente_dni']?.toString() ?? '',
      clienteTelefono: json['cliente_telefono']?.toString() ?? '',
      clienteEmail: json['cliente_email']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      horaInicio: (json['hora_inicio'] as num).toInt(),
      horaFin: (json['hora_fin'] as num).toInt(),
      subtotalCancha: (json['subtotal_cancha'] as num).toDouble(),
      subtotalExtras: (json['subtotal_extras'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      montoPagado: (json['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      montoDevolucion: (json['monto_devolucion'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado']?.toString() ?? 'PENDIENTE_PAGO',
      codigoQr: json['codigo_qr']?.toString(),
      motivoCancelacion: json['motivo_cancelacion']?.toString(),
      notas: json['notas']?.toString(),
      expiresAt: json['expires_at']?.toString() ?? '',
      extras: (json['extras'] as List<dynamic>? ?? [])
          .map((e) => ReservaExtraDetalle.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagos: (json['pagos'] as List<dynamic>? ?? [])
          .map((p) => Pago.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

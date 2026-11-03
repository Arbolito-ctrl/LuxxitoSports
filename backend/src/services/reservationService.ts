import crypto from 'crypto';
import { dataRepository } from '../repositories/dataRepository';
import {
  CotizacionInput,
  CotizacionOutput,
  EstadoPago,
  MetodoPago,
  ModalidadPago,
  Pago,
  Reserva,
  ReservaExtraItem,
} from '../types/models';
import { Errors } from '../utils/errors';

const VALID_METODOS_PAGO: MetodoPago[] = ['YAPE', 'PLIN', 'TRANSFERENCIA'];
const VALID_MODALIDADES: ModalidadPago[] = ['SENA_50', 'TOTAL'];
const VALID_ESTADOS_PAGO: EstadoPago[] = [
  'PENDIENTE_REVISION',
  'APROBADO',
  'RECHAZADO',
  'REEMBOLSADO',
];
const BLOQUEO_MINUTOS = 20;
const MIN_OBSERVACION_RECHAZO = 5;

export type PagoConReserva = Pago & {
  reserva: Pick<
    Reserva,
    | 'id'
    | 'estado'
    | 'cancha_nombre'
    | 'complejo_nombre'
    | 'cliente_nombre'
    | 'cliente_dni'
    | 'cliente_telefono'
    | 'fecha'
    | 'hora_inicio'
    | 'hora_fin'
    | 'total'
    | 'monto_pagado'
  > | null;
};

export class ReservationService {
  /**
   * LÓGICA DE NEGOCIO 2:
   * Cotización exacta en el servidor (nunca confía en importes enviados por el cliente).
   * Calcula tarifa diurna (< 18:00) y nocturna (>= 18:00) por cada hora del intervalo,
   * valida pertenencia y stock de extras por intervalo, y calcula el adelanto del 50%.
   */
  async cotizarReserva(input: CotizacionInput): Promise<CotizacionOutput> {
    await dataRepository.expireOverdueReservas();
    const canchaId = Number(input.cancha_id);
    if (!Number.isInteger(canchaId) || canchaId <= 0) {
      throw Errors.badRequest('El campo cancha_id debe ser un entero positivo.');
    }

    const cancha = await dataRepository.getCanchaById(canchaId);
    if (!cancha) {
      throw Errors.notFound(`No existe la cancha con ID ${canchaId}.`);
    }
    if (cancha.estado !== 'ACTIVA') {
      throw Errors.conflict(
        `La cancha "${cancha.nombre}" no está disponible actualmente (estado: ${cancha.estado}).`
      );
    }

    const complejo = await dataRepository.getComplejoById(cancha.complejo_id);
    if (!complejo) {
      throw Errors.notFound('Complejo deportivo asociado no encontrado.');
    }

    const fecha = String(input.fecha || '').trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
      throw Errors.badRequest('La fecha debe tener el formato YYYY-MM-DD.');
    }

    const horaInicio = Number(input.hora_inicio);
    const horaFin = Number(input.hora_fin);
    if (
      !Number.isInteger(horaInicio) ||
      !Number.isInteger(horaFin) ||
      horaFin <= horaInicio
    ) {
      throw Errors.badRequest(
        'Las horas de inicio y fin deben ser enteros válidos y hora_fin debe ser mayor a hora_inicio.'
      );
    }

    if (horaInicio < complejo.hora_apertura || horaFin > complejo.hora_cierre) {
      throw Errors.unprocessable(
        `El horario solicitado (${horaInicio}:00 - ${horaFin}:00) está fuera del horario de atención del complejo (${complejo.hora_apertura}:00 - ${complejo.hora_cierre}:00).`
      );
    }

    if (horaFin - horaInicio > 4) {
      throw Errors.unprocessable('La duración máxima por reserva es de 4 horas consecutivas.');
    }

    // Calcular desglose de horas (tarifa diurna vs nocturna a partir de las 18:00)
    const desgloseHoras: CotizacionOutput['desglose_horas'] = [];
    let subtotalCancha = 0;

    for (let h = horaInicio; h < horaFin; h++) {
      const esNocturno = h >= 18;
      const precioHora = esNocturno
        ? cancha.precio_hora_nocturno
        : cancha.precio_hora_diurno;
      subtotalCancha += precioHora;
      desgloseHoras.push({
        hora: `${String(h).padStart(2, '0')}:00 - ${String(h + 1).padStart(2, '0')}:00`,
        tipo: esNocturno ? 'NOCTURNA' : 'DIURNA',
        precio: precioHora,
      });
    }

    // Procesar y validar extras contra el stock disponible en ese intervalo
    const extrasComplejo = await dataRepository.getExtrasByComplejo(complejo.id);
    const desgloseExtras: ReservaExtraItem[] = [];
    let subtotalExtras = 0;

    if (Array.isArray(input.extras) && input.extras.length > 0) {
      for (const reqExtra of input.extras) {
        const extraId = Number(reqExtra.extra_id);
        const cantidad = Number(reqExtra.cantidad);
        if (!Number.isInteger(cantidad) || cantidad <= 0) {
          throw Errors.badRequest('La cantidad de cada extra debe ser un entero mayor a 0.');
        }

        const extraCatalog = extrasComplejo.find((e) => e.id === extraId);
        if (!extraCatalog) {
          throw Errors.badRequest(
            `El extra con ID ${extraId} no pertenece al complejo "${complejo.nombre}".`
          );
        }

        const usadoEnIntervalo = await dataRepository.getExtraUsedQuantityInInterval(
          extraId,
          fecha,
          horaInicio,
          horaFin
        );
        const disponible = extraCatalog.stock_total - usadoEnIntervalo;
        if (cantidad > disponible) {
          throw Errors.conflict(
            `Stock insuficiente para "${extraCatalog.nombre}" en el horario seleccionado. Disponible: ${disponible}, solicitado: ${cantidad}.`
          );
        }

        const sub = Number((extraCatalog.precio_unitario * cantidad).toFixed(2));
        subtotalExtras += sub;
        desgloseExtras.push({
          extra_id: extraId,
          nombre: extraCatalog.nombre,
          cantidad,
          precio_unitario: extraCatalog.precio_unitario,
          subtotal: sub,
        });
      }
    }

    subtotalCancha = Number(subtotalCancha.toFixed(2));
    subtotalExtras = Number(subtotalExtras.toFixed(2));
    const total = Number((subtotalCancha + subtotalExtras).toFixed(2));
    const montoSena50 = Number((total * 0.5).toFixed(2));

    return {
      cancha_id: cancha.id,
      cancha_nombre: cancha.nombre,
      complejo_nombre: complejo.nombre,
      fecha,
      hora_inicio: horaInicio,
      hora_fin: horaFin,
      duracion_horas: horaFin - horaInicio,
      subtotal_cancha: subtotalCancha,
      subtotal_extras: subtotalExtras,
      total,
      monto_sena_50: montoSena50,
      desglose_horas: desgloseHoras,
      desglose_extras: desgloseExtras,
    };
  }

  /**
   * LÓGICA DE NEGOCIO 3:
   * Creación de reserva con validación de no solapamiento horario (exclusión mutua),
   * rechazo de fechas/horas pasadas, bloqueo de 20 minutos y reserva de stock de extras.
   */
  async crearReserva(payload: any): Promise<Reserva> {
    const clienteNombre = String(payload.cliente_nombre || '').trim();
    const clienteDni = String(payload.cliente_dni || '').trim();
    const clienteTelefono = String(payload.cliente_telefono || '').trim();
    const clienteEmail = String(payload.cliente_email || '').trim();

    if (clienteNombre.length < 3) {
      throw Errors.badRequest(
        'El nombre del cliente es obligatorio (mínimo 3 caracteres).'
      );
    }
    if (!/^\d{8}$/.test(clienteDni)) {
      throw Errors.badRequest('El DNI del cliente debe contener exactamente 8 dígitos numéricos.');
    }
    if (clienteTelefono.length < 7) {
      throw Errors.badRequest('El teléfono del cliente es obligatorio.');
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clienteEmail)) {
      throw Errors.badRequest('El correo electrónico ingresado no tiene un formato válido.');
    }

    // Primero cotizar y validar horario + extras + estado de cancha
    const cotizacion = await this.cotizarReserva({
      cancha_id: Number(payload.cancha_id),
      fecha: String(payload.fecha || ''),
      hora_inicio: Number(payload.hora_inicio),
      hora_fin: Number(payload.hora_fin),
      extras: payload.extras,
    });

    // Validar que no sea una fecha u hora pasada respecto a Lima (UTC-5)
    const now = new Date();
    const limaNow = new Date(now.getTime() - 5 * 60 * 60 * 1000);
    const hoyLima = limaNow.toISOString().split('T')[0];
    const horaActualLima = limaNow.getUTCHours();

    if (
      cotizacion.fecha < hoyLima ||
      (cotizacion.fecha === hoyLima && cotizacion.hora_inicio <= horaActualLima)
    ) {
      throw Errors.unprocessable(
        'No se pueden registrar reservas en fechas u horas que ya han transcurrido.'
      );
    }

    // Verificar solapamiento de reservas activas en la misma cancha y fecha
    const existentes = await dataRepository.getReservasByCanchaAndDate(
      cotizacion.cancha_id,
      cotizacion.fecha
    );
    const conflicto = existentes.find(
      (r) =>
        ['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'].includes(r.estado) &&
        r.hora_inicio < cotizacion.hora_fin &&
        r.hora_fin > cotizacion.hora_inicio
    );

    if (conflicto) {
      throw Errors.conflict(
        `El turno de ${cotizacion.hora_inicio}:00 a ${cotizacion.hora_fin}:00 ya se encuentra ocupado o bloqueado (Reserva #${conflicto.id} en estado ${conflicto.estado}).`
      );
    }

    // Bloqueo temporal de 20 minutos según especificación de Luxxito Sports
    const expiresAt = new Date(Date.now() + BLOQUEO_MINUTOS * 60 * 1000).toISOString();

    return dataRepository.createReserva(
      {
        cancha_id: cotizacion.cancha_id,
        cliente_nombre: clienteNombre,
        cliente_dni: clienteDni,
        cliente_telefono: clienteTelefono,
        cliente_email: clienteEmail,
        fecha: cotizacion.fecha,
        hora_inicio: cotizacion.hora_inicio,
        hora_fin: cotizacion.hora_fin,
        subtotal_cancha: cotizacion.subtotal_cancha,
        subtotal_extras: cotizacion.subtotal_extras,
        total: cotizacion.total,
        estado: 'PENDIENTE_PAGO',
        codigo_qr: null,
        motivo_cancelacion: null,
        notas: payload.notas ? String(payload.notas).trim() : null,
        expires_at: expiresAt,
      },
      cotizacion.desglose_extras
    );
  }

  async listarReservas(filters?: {
    estado?: string;
    cliente_dni?: string;
    fecha?: string;
  }): Promise<Reserva[]> {
    await dataRepository.expireOverdueReservas();
    return dataRepository.getReservas(filters);
  }

  async obtenerReserva(id: number): Promise<Reserva> {
    if (!Number.isInteger(id) || id <= 0) {
      throw Errors.badRequest('El ID de la reserva debe ser un entero positivo.');
    }
    await dataRepository.expireOverdueReservas();
    const reserva = await dataRepository.getReservaById(id);
    if (!reserva) {
      throw Errors.notFound(`No se encontró la reserva con ID ${id}.`);
    }
    return reserva;
  }

  async actualizarReserva(id: number, payload: any): Promise<Reserva> {
    const reserva = await this.obtenerReserva(id);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se puede modificar una reserva en estado ${reserva.estado}.`
      );
    }

    if (payload.cliente_email !== undefined) {
      const email = String(payload.cliente_email).trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw Errors.badRequest('El correo electrónico proporcionado no es válido.');
      }
    }

    const updated = await dataRepository.updateReserva(id, {
      cliente_nombre: payload.cliente_nombre
        ? String(payload.cliente_nombre).trim()
        : reserva.cliente_nombre,
      cliente_telefono: payload.cliente_telefono
        ? String(payload.cliente_telefono).trim()
        : reserva.cliente_telefono,
      cliente_email: payload.cliente_email
        ? String(payload.cliente_email).trim()
        : reserva.cliente_email,
      notas:
        payload.notas !== undefined
          ? payload.notas
            ? String(payload.notas).trim()
            : null
          : reserva.notas,
    });
    return updated!;
  }

  async eliminarReserva(id: number): Promise<{ message: string; deleted_id: number }> {
    const reserva = await this.obtenerReserva(id);
    if (reserva.estado === 'CONFIRMADA') {
      throw Errors.conflict(
        'No se puede eliminar físicamente una reserva CONFIRMADA; debe cancelarla primero para aplicar la política de devolución.'
      );
    }
    await dataRepository.deleteReserva(id);
    return {
      message: `Reserva #${id} eliminada correctamente.`,
      deleted_id: id,
    };
  }

  /**
   * LÓGICA DE NEGOCIO 4:
   * Registro de comprobante de pago (Yape/Plin/Transferencia) y aprobación idempotente.
   * Protege la reserva pasándola a EN_REVISION y valida el importe (50% seña o 100% total).
   */
  async registrarPago(
    reservaId: number,
    payload: any
  ): Promise<{ pago: Pago; reserva: Reserva }> {
    const reserva = await this.obtenerReserva(reservaId);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se pueden registrar pagos para una reserva en estado ${reserva.estado}.`
      );
    }
    if (reserva.estado === 'CONFIRMADA' && reserva.monto_pagado >= reserva.total) {
      throw Errors.conflict('Esta reserva ya se encuentra pagada en su totalidad.');
    }

    const metodo = String(payload.metodo || 'YAPE').toUpperCase() as MetodoPago;
    if (!VALID_METODOS_PAGO.includes(metodo)) {
      throw Errors.badRequest(
        `Método de pago inválido. Permitidos: ${VALID_METODOS_PAGO.join(', ')}.`
      );
    }

    const modalidad = String(payload.modalidad || 'TOTAL').toUpperCase() as ModalidadPago;
    if (!VALID_MODALIDADES.includes(modalidad)) {
      throw Errors.badRequest(
        `Modalidad inválida. Permitidas: ${VALID_MODALIDADES.join(', ')}.`
      );
    }

    const numeroOperacion = String(payload.numero_operacion || '').trim();
    if (numeroOperacion.length < 4) {
      throw Errors.badRequest(
        'El número de operación del comprobante es obligatorio (mínimo 4 caracteres).'
      );
    }

    const saldoPendiente = Number((reserva.total - reserva.monto_pagado).toFixed(2));
    const montoEsperado =
      modalidad === 'SENA_50' && reserva.monto_pagado === 0
        ? Number((reserva.total * 0.5).toFixed(2))
        : saldoPendiente;

    const monto =
      payload.monto !== undefined ? Number(payload.monto) : montoEsperado;
    if (isNaN(monto) || monto <= 0) {
      throw Errors.badRequest('El monto del pago debe ser mayor a 0.');
    }
    if (Math.abs(monto - montoEsperado) > 0.05 && Math.abs(monto - reserva.total) > 0.05) {
      throw Errors.unprocessable(
        `El monto enviado (S/ ${monto.toFixed(2)}) no coincide con el monto requerido para la modalidad ${modalidad} (S/ ${montoEsperado.toFixed(2)}).`
      );
    }

    const pago = await dataRepository.createPago({
      reserva_id: reservaId,
      metodo,
      modalidad,
      monto,
      numero_operacion: numeroOperacion,
      comprobante_url: payload.comprobante_url
        ? String(payload.comprobante_url).trim()
        : `https://storage.luxxitosports.pe/comprobantes/op-${numeroOperacion}.jpg`,
      estado: 'PENDIENTE_REVISION',
      observacion: payload.observacion ? String(payload.observacion).trim() : null,
    });

    // Proteger la reserva contra expiración de 20 min mientras se revisa el comprobante
    let reservaActualizada = (await dataRepository.updateReserva(reservaId, {
      estado: 'EN_REVISION',
    }))!;

    // Si se solicita aprobación inmediata (o verificación automática de demo)
    if (payload.auto_aprobar === true) {
      const aprobado = await this.aprobarPago(pago.id);
      return aprobado;
    }

    return { pago, reserva: reservaActualizada };
  }

  /**
   * Aprobación idempotente de pago:
   * Si el pago ya estaba APROBADO, retorna el estado actual sin duplicar saldo ni QR.
   */
  async aprobarPago(pagoId: number): Promise<{ pago: Pago; reserva: Reserva; idempotent: boolean }> {
    if (!Number.isInteger(pagoId) || pagoId <= 0) {
      throw Errors.badRequest('El ID del pago debe ser un entero positivo.');
    }
    const pago = await dataRepository.getPagoById(pagoId);
    if (!pago) {
      throw Errors.notFound(`No se encontró el pago con ID ${pagoId}.`);
    }

    const reserva = await this.obtenerReserva(pago.reserva_id);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se puede aprobar un pago de una reserva en estado ${reserva.estado}.`
      );
    }

    // Idempotencia: si ya fue aprobado previamente, no volver a sumar monto_pagado
    if (pago.estado === 'APROBADO') {
      return { pago, reserva, idempotent: true };
    }
    if (pago.estado !== 'PENDIENTE_REVISION') {
      throw Errors.conflict(
        `No se puede aprobar un pago en estado ${pago.estado}; el jugador debe enviar un nuevo comprobante.`
      );
    }

    const pagoAprobado = (await dataRepository.updatePagoEstado(
      pagoId,
      'APROBADO',
      'Comprobante verificado y conciliado.'
    ))!;

    const nuevoMontoPagado = Number(
      Math.min(reserva.total, reserva.monto_pagado + pago.monto).toFixed(2)
    );
    const qrToken =
      reserva.codigo_qr ||
      `LUXXITO-QR-${reserva.id}-${crypto
        .createHash('sha256')
        .update(`${reserva.id}-${reserva.cliente_dni}-${reserva.fecha}`)
        .digest('hex')
        .substring(0, 10)
        .toUpperCase()}`;

    const reservaConfirmada = (await dataRepository.updateReserva(reserva.id, {
      estado: 'CONFIRMADA',
      monto_pagado: nuevoMontoPagado,
      codigo_qr: qrToken,
    }))!;

    return { pago: pagoAprobado, reserva: reservaConfirmada, idempotent: false };
  }

  /**
   * Bandeja de revisión del operador: lista los pagos (opcionalmente filtrados por estado)
   * con el resumen de su reserva para poder aprobarlos o rechazarlos sin consultas extra.
   */
  async listarPagos(estado?: string): Promise<PagoConReserva[]> {
    let estadoFiltro: EstadoPago | undefined;
    if (estado !== undefined) {
      estadoFiltro = String(estado).toUpperCase() as EstadoPago;
      if (!VALID_ESTADOS_PAGO.includes(estadoFiltro)) {
        throw Errors.badRequest(
          `Estado de pago inválido. Permitidos: ${VALID_ESTADOS_PAGO.join(', ')}.`
        );
      }
    }

    const pagos = await dataRepository.getPagos(estadoFiltro);
    const reservas = new Map<number, Reserva | null>();
    for (const pago of pagos) {
      if (!reservas.has(pago.reserva_id)) {
        reservas.set(pago.reserva_id, await dataRepository.getReservaById(pago.reserva_id));
      }
    }

    return pagos.map((pago) => {
      const r = reservas.get(pago.reserva_id);
      return {
        ...pago,
        reserva: r
          ? {
              id: r.id,
              estado: r.estado,
              cancha_nombre: r.cancha_nombre,
              complejo_nombre: r.complejo_nombre,
              cliente_nombre: r.cliente_nombre,
              cliente_dni: r.cliente_dni,
              cliente_telefono: r.cliente_telefono,
              fecha: r.fecha,
              hora_inicio: r.hora_inicio,
              hora_fin: r.hora_fin,
              total: r.total,
              monto_pagado: r.monto_pagado,
            }
          : null,
      };
    });
  }

  /**
   * Rechazo idempotente de pago con motivo obligatorio:
   * - Solo se rechazan pagos en PENDIENTE_REVISION (un pago APROBADO o REEMBOLSADO responde 409).
   * - Si la reserva estaba EN_REVISION, vuelve a PENDIENTE_PAGO con un nuevo bloqueo de 20 min
   *   para que el jugador reenvíe un comprobante válido.
   */
  async rechazarPago(
    pagoId: number,
    observacion: unknown
  ): Promise<{ pago: Pago; reserva: Reserva; idempotent: boolean }> {
    if (!Number.isInteger(pagoId) || pagoId <= 0) {
      throw Errors.badRequest('El ID del pago debe ser un entero positivo.');
    }
    const motivo = typeof observacion === 'string' ? observacion.trim() : '';
    if (motivo.length < MIN_OBSERVACION_RECHAZO) {
      throw Errors.badRequest(
        `La observación del rechazo es obligatoria (mínimo ${MIN_OBSERVACION_RECHAZO} caracteres).`
      );
    }

    const pago = await dataRepository.getPagoById(pagoId);
    if (!pago) {
      throw Errors.notFound(`No se encontró el pago con ID ${pagoId}.`);
    }
    const reserva = await this.obtenerReserva(pago.reserva_id);

    if (pago.estado === 'RECHAZADO') {
      return { pago, reserva, idempotent: true };
    }
    if (pago.estado !== 'PENDIENTE_REVISION') {
      throw Errors.conflict(`No se puede rechazar un pago en estado ${pago.estado}.`);
    }
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se puede rechazar un pago de una reserva en estado ${reserva.estado}.`
      );
    }

    const pagoRechazado = (await dataRepository.updatePagoEstado(
      pagoId,
      'RECHAZADO',
      motivo
    ))!;

    let reservaActualizada = reserva;
    if (reserva.estado === 'EN_REVISION') {
      const otrosPendientes = (await dataRepository.getPagosByReserva(reserva.id)).some(
        (p) => p.id !== pagoId && p.estado === 'PENDIENTE_REVISION'
      );
      if (!otrosPendientes) {
        reservaActualizada = (await dataRepository.updateReserva(reserva.id, {
          estado: 'PENDIENTE_PAGO',
          expires_at: new Date(Date.now() + BLOQUEO_MINUTOS * 60 * 1000).toISOString(),
        }))!;
      }
    }

    return { pago: pagoRechazado, reserva: reservaActualizada, idempotent: false };
  }

  /**
   * LÓGICA DE NEGOCIO 5:
   * Cancelación de reserva con política de las 24 horas:
   * - >= 24 horas de anticipación: devolución del 100% del monto pagado.
   * - < 24 horas de anticipación: retención del 50% por penalidad y devolución del 50%.
   * Revoca el código QR y libera el turno de la cancha y el stock de extras.
   */
  async cancelarReserva(
    reservaId: number,
    motivo?: string
  ): Promise<{
    reserva: Reserva;
    politica_aplicada: string;
    horas_anticipacion: number;
    monto_pagado: number;
    penalidad: number;
    monto_devolucion: number;
  }> {
    const reserva = await this.obtenerReserva(reservaId);
    if (reserva.estado === 'CANCELADA') {
      throw Errors.conflict('La reserva ya se encuentra cancelada.');
    }

    // Calcular horas de anticipación respecto al inicio del turno en hora de Lima (UTC-5)
    const inicioTurnoUtcMs = Date.parse(
      `${reserva.fecha}T${String(reserva.hora_inicio).padStart(2, '0')}:00:00-05:00`
    );
    const ahoraMs = Date.now();
    const horasAnticipacion = Number(
      ((inicioTurnoUtcMs - ahoraMs) / (1000 * 60 * 60)).toFixed(2)
    );

    let montoDevolucion = 0;
    let penalidad = 0;
    let politicaAplicada = 'SIN_PAGOS_PREVIOS';

    if (reserva.monto_pagado > 0) {
      if (horasAnticipacion >= 24) {
        montoDevolucion = reserva.monto_pagado;
        penalidad = 0;
        politicaAplicada = 'REEMBOLSO_100_MAYOR_24H';
      } else {
        montoDevolucion = Number((reserva.monto_pagado * 0.5).toFixed(2));
        penalidad = Number((reserva.monto_pagado - montoDevolucion).toFixed(2));
        politicaAplicada = 'RETENCION_50_MENOR_24H';
      }
    }

    const updated = (await dataRepository.updateReserva(reservaId, {
      estado: 'CANCELADA',
      monto_devolucion: montoDevolucion,
      codigo_qr: null, // Revocar QR verificable al cancelar
      motivo_cancelacion:
        motivo && motivo.trim().length > 0
          ? motivo.trim()
          : `Cancelada por el usuario (${politicaAplicada})`,
    }))!;

    return {
      reserva: updated,
      politica_aplicada: politicaAplicada,
      horas_anticipacion: horasAnticipacion,
      monto_pagado: reserva.monto_pagado,
      penalidad,
      monto_devolucion: montoDevolucion,
    };
  }

  /**
   * LÓGICA DE NEGOCIO 6 (LX-202):
   * Verificación y escaneo de Ticket QR en puerta.
   * Comprueba que el código exista, pertenezca a una reserva CONFIRMADA (no cancelada ni revocada)
   * y no haya sido utilizado previamente (protección contra doble ingreso).
   */
  async verificarTicketQr(codigoQrInput: unknown): Promise<{
    verificado: boolean;
    estado_ingreso: 'INGRESO_REGISTRADO';
    verificado_en: string;
    reserva: Reserva;
  }> {
    const codigoQr = typeof codigoQrInput === 'string' ? codigoQrInput.trim() : '';
    if (!codigoQr || !codigoQr.toUpperCase().startsWith('LUXXITO-QR-')) {
      throw Errors.badRequest(
        'Debes proporcionar un código QR válido con formato LUXXITO-QR-...'
      );
    }

    let reserva = await dataRepository.getReservaByCodigoQr(codigoQr);
    if (!reserva) {
      const matchId = codigoQr.match(/^LUXXITO-QR-(\d+)-/i);
      if (matchId) {
        const byId = await dataRepository.getReservaById(Number(matchId[1]));
        if (byId && byId.estado === 'CANCELADA') {
          throw Errors.conflict(
            `El Ticket QR fue revocado porque la reserva #${byId.id} se encuentra CANCELADA.`
          );
        }
      }
      throw Errors.notFound(
        'El código QR proporcionado no corresponde a ninguna reserva activa.'
      );
    }

    if (reserva.estado !== 'CONFIRMADA') {
      throw Errors.conflict(
        `La reserva #${reserva.id} no está confirmada para el ingreso (estado actual: ${reserva.estado}).`
      );
    }

    if (reserva.qr_usado_at) {
      throw Errors.conflict(
        `Este Ticket QR ya fue utilizado previamente para registrar el ingreso (${reserva.qr_usado_at}).`
      );
    }

    const verificadoEn = new Date().toISOString();
    const actualizada = (await dataRepository.updateReserva(reserva.id, {
      qr_usado_at: verificadoEn,
    }))!;

    return {
      verificado: true,
      estado_ingreso: 'INGRESO_REGISTRADO',
      verificado_en: verificadoEn,
      reserva: actualizada,
    };
  }
}

export const reservationService = new ReservationService();

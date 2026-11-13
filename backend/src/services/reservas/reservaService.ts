/**
 * Ciclo de vida de la reserva: crearla, consultarla, editarla, eliminarla y cancelarla.
 *
 * Estados de una reserva:
 *   PENDIENTE_PAGO --(jugador envía comprobante)--> EN_REVISION --(admin aprueba)--> CONFIRMADA
 *        |                                              |
 *        |  (pasan 20 min sin pago)                     | (admin rechaza: vuelve a PENDIENTE_PAGO)
 *        v                                              v
 *     VENCIDA                       CANCELADA (en cualquier momento, con política de 24 h)
 *
 * Los cambios ligados al pago (EN_REVISION, CONFIRMADA) los hace pagoService.
 */
import { dataRepository } from '../../repositories/dataRepository';
import { Reserva } from '../../types/models';
import { Errors } from '../../utils/errors';
import { cotizacionService } from './cotizacionService';
import {
  ESTADOS_QUE_OCUPAN_TURNO,
  conBloqueoDeReserva,
  vencimientoDeBloqueo,
} from './reglasCompartidas';

const REGEX_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
/** Lima no tiene horario de verano: siempre es UTC-5. */
const DESFASE_LIMA_MS = 5 * 60 * 60 * 1000;

/** Resultado de cancelar: la reserva y el detalle de la devolución aplicada. */
export type ResultadoCancelacion = {
  reserva: Reserva;
  politica_aplicada: string;
  horas_anticipacion: number;
  monto_pagado: number;
  penalidad: number;
  monto_devolucion: number;
};

export class ReservaService {
  // ===========================================================================
  // Crear
  // ===========================================================================

  /**
   * LÓGICA DE NEGOCIO 3: crea una reserva PENDIENTE_PAGO que retiene el turno 20 minutos.
   *
   * Las reservas de una misma fecha se crean de una en una (clave `reservas:<fecha>`):
   * así dos personas no pueden quedarse con el mismo turno ni con el último extra
   * disponible al mismo tiempo. Como última defensa, PostgreSQL tiene una restricción
   * de exclusión que rechaza turnos solapados (código 23P01).
   */
  async crearReserva(payload: any): Promise<Reserva> {
    const fecha = String(payload?.fecha || '').trim();
    try {
      return await dataRepository.conBloqueo(`reservas:${fecha}`, () =>
        this.crearReservaSinBloqueo(payload)
      );
    } catch (error) {
      if ((error as { code?: string })?.code === '23P01') {
        throw Errors.conflict('El turno elegido acaba de ser reservado por otra persona. Elige otro horario.');
      }
      throw error;
    }
  }

  /** Validaciones y guardado de la reserva. Solo se llama dentro del bloqueo por fecha. */
  private async crearReservaSinBloqueo(payload: any): Promise<Reserva> {
    // --- 1. Datos del cliente -------------------------------------------------
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
    if (!REGEX_EMAIL.test(clienteEmail)) {
      throw Errors.badRequest('El correo electrónico ingresado no tiene un formato válido.');
    }

    // --- 2. Precio, horario, cancha y extras (lo valida la cotización) ---------
    const cotizacion = await cotizacionService.cotizarReserva({
      cancha_id: Number(payload.cancha_id),
      fecha: String(payload.fecha || ''),
      hora_inicio: Number(payload.hora_inicio),
      hora_fin: Number(payload.hora_fin),
      extras: payload.extras,
    });

    // --- 3. No se reserva en el pasado (según la hora de Lima) -----------------
    const limaNow = new Date(Date.now() - DESFASE_LIMA_MS);
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

    // --- 4. El turno no debe cruzarse con otra reserva activa de la misma cancha
    // Dos intervalos [a, b) y [c, d) se cruzan si a < d y b > c.
    const existentes = await dataRepository.getReservasByCanchaAndDate(
      cotizacion.cancha_id,
      cotizacion.fecha
    );
    const conflicto = existentes.find(
      (r) =>
        ESTADOS_QUE_OCUPAN_TURNO.includes(r.estado) &&
        r.hora_inicio < cotizacion.hora_fin &&
        r.hora_fin > cotizacion.hora_inicio
    );

    if (conflicto) {
      throw Errors.conflict(
        `El turno de ${cotizacion.hora_inicio}:00 a ${cotizacion.hora_fin}:00 ya se encuentra ocupado o bloqueado (Reserva #${conflicto.id} en estado ${conflicto.estado}).`
      );
    }

    // --- 5. Guardar con bloqueo temporal de 20 minutos ------------------------
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
        expires_at: vencimientoDeBloqueo(),
      },
      cotizacion.desglose_extras
    );
  }

  // ===========================================================================
  // Consultar
  // ===========================================================================

  /** Lista reservas con filtros opcionales. Antes marca como VENCIDAS las que pasaron sus 20 min. */
  async listarReservas(filters?: {
    estado?: string;
    cliente_dni?: string;
    fecha?: string;
  }): Promise<Reserva[]> {
    await dataRepository.expireOverdueReservas();
    return dataRepository.getReservas(filters);
  }

  /**
   * Devuelve una reserva o lanza 404. Los demás servicios del módulo la usan
   * para cargar la reserva con su estado ya actualizado (vencida o no).
   */
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

  // ===========================================================================
  // Editar y eliminar
  // ===========================================================================

  /**
   * Edita solo los datos de contacto y las notas. La cancha, la fecha y el horario
   * no se cambian aquí, porque alterarían el precio y la disponibilidad.
   */
  async actualizarReserva(id: number, payload: any): Promise<Reserva> {
    const reserva = await this.obtenerReserva(id);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se puede modificar una reserva en estado ${reserva.estado}.`
      );
    }

    if (payload.cliente_email !== undefined) {
      const email = String(payload.cliente_email).trim();
      if (!REGEX_EMAIL.test(email)) {
        throw Errors.badRequest('El correo electrónico proporcionado no es válido.');
      }
    }

    // Cada campo que no venga en el payload conserva su valor actual
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
      // notas: si llega vacía se borra (null); si no llega, se mantiene
      notas:
        payload.notas !== undefined
          ? payload.notas
            ? String(payload.notas).trim()
            : null
          : reserva.notas,
    });
    return updated!;
  }

  /**
   * Borra la reserva de la base de datos. Una reserva CONFIRMADA no se borra:
   * ya tiene dinero pagado y debe cancelarse para aplicar la política de devolución.
   */
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

  // ===========================================================================
  // Cancelar
  // ===========================================================================

  /**
   * LÓGICA DE NEGOCIO 5: cancelación con política de 24 horas.
   * - Con 24 h o más de anticipación: se devuelve el 100 % de lo pagado.
   * - Con menos de 24 h: se retiene el 50 % como penalidad y se devuelve el otro 50 %.
   * Al cancelar se anula el Ticket QR y se liberan el turno y el stock de extras.
   */
  async cancelarReserva(reservaId: number, motivo?: string): Promise<ResultadoCancelacion> {
    return conBloqueoDeReserva(reservaId, () => this.cancelarReservaSinBloqueo(reservaId, motivo));
  }

  private async cancelarReservaSinBloqueo(
    reservaId: number,
    motivo?: string
  ): Promise<ResultadoCancelacion> {
    const reserva = await this.obtenerReserva(reservaId);
    if (reserva.estado === 'CANCELADA') {
      throw Errors.conflict('La reserva ya se encuentra cancelada.');
    }

    // Horas que faltan para el inicio del turno, contando en hora de Lima (-05:00)
    const inicioTurnoUtcMs = Date.parse(
      `${reserva.fecha}T${String(reserva.hora_inicio).padStart(2, '0')}:00:00-05:00`
    );
    const horasAnticipacion = Number(
      ((inicioTurnoUtcMs - Date.now()) / (1000 * 60 * 60)).toFixed(2)
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
      codigo_qr: null, // Anula el Ticket QR: ya no servirá para ingresar
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
}

export const reservaService = new ReservaService();

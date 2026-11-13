/**
 * Pagos manuales de las reservas: Yape, Plin o transferencia.
 * LÓGICA DE NEGOCIO 4: registro del comprobante y protección de la reserva en revisión.
 * LÓGICA DE NEGOCIO 5: aprobación idempotente y emisión del Ticket QR.
 *
 * Flujo:
 *   1. El jugador registra el pago con el número de operación (y opcionalmente el
 *      voucher) → el pago queda PENDIENTE_REVISION y la reserva pasa a EN_REVISION,
 *      lo que la protege de vencer a los 20 minutos mientras el admin revisa.
 *   2. El admin lo revisa en la bandeja (listarPagos) y:
 *      - lo aprueba → la reserva queda CONFIRMADA y recibe su Ticket QR, o
 *      - lo rechaza con un motivo → la reserva vuelve a PENDIENTE_PAGO con 20 min nuevos.
 *
 * Aprobar y rechazar son idempotentes: repetir la misma acción no suma dos veces
 * el monto ni crea otro QR; responde el estado actual con `idempotent: true`.
 */
import { dataRepository } from '../../repositories/dataRepository';
import { EstadoPago, MetodoPago, ModalidadPago, Pago, Reserva } from '../../types/models';
import { Errors } from '../../utils/errors';
import { comprobanteService } from './comprobanteService';
import {
  conBloqueoDeReserva,
  conBloqueoDeReservaDelPago,
  vencimientoDeBloqueo,
} from './reglasCompartidas';
import { reservaService } from './reservaService';
import { ticketQrService } from './ticketQrService';

const VALID_METODOS_PAGO: MetodoPago[] = ['YAPE', 'PLIN', 'TRANSFERENCIA'];
const VALID_MODALIDADES: ModalidadPago[] = ['SENA_50', 'TOTAL'];
const VALID_ESTADOS_PAGO: EstadoPago[] = [
  'PENDIENTE_REVISION',
  'APROBADO',
  'RECHAZADO',
  'REEMBOLSADO',
];
const MIN_OBSERVACION_RECHAZO = 5;
/** Margen (en soles) para aceptar diferencias de redondeo en el monto enviado. */
const TOLERANCIA_MONTO = 0.05;

/** Un pago con el resumen de su reserva, tal como lo ve el admin en la bandeja. */
export type PagoConReserva = Pago & {
  /** Enlace temporal (1 h) para ver el voucher del bucket privado; null si no hay imagen. */
  comprobante_url_firmada: string | null;
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

/** Resultado de aprobar o rechazar: el pago, su reserva y si la acción ya se había hecho antes. */
export type ResultadoRevision = { pago: Pago; reserva: Reserva; idempotent: boolean };

export class PagoService {
  // Los métodos públicos solo ponen el bloqueo por reserva (ver reglasCompartidas)
  // y delegan en su versión "SinBloqueo", que tiene la lógica.

  /** El jugador registra el comprobante de pago de su reserva. */
  async registrarPago(reservaId: number, payload: any): Promise<{ pago: Pago; reserva: Reserva }> {
    return conBloqueoDeReserva(reservaId, () => this.registrarPagoSinBloqueo(reservaId, payload));
  }

  /** El admin aprueba un pago: la reserva queda CONFIRMADA con su Ticket QR. */
  async aprobarPago(pagoId: number): Promise<ResultadoRevision> {
    return conBloqueoDeReservaDelPago(pagoId, () => this.aprobarPagoSinBloqueo(pagoId));
  }

  /** El admin rechaza un pago indicando el motivo. */
  async rechazarPago(pagoId: number, observacion: unknown): Promise<ResultadoRevision> {
    return conBloqueoDeReservaDelPago(pagoId, () =>
      this.rechazarPagoSinBloqueo(pagoId, observacion)
    );
  }

  // ===========================================================================
  // Registrar
  // ===========================================================================

  private async registrarPagoSinBloqueo(
    reservaId: number,
    payload: any
  ): Promise<{ pago: Pago; reserva: Reserva }> {
    // --- 1. La reserva debe poder recibir un pago ----------------------------
    const reserva = await reservaService.obtenerReserva(reservaId);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se pueden registrar pagos para una reserva en estado ${reserva.estado}.`
      );
    }
    if (reserva.estado === 'CONFIRMADA' && reserva.monto_pagado >= reserva.total) {
      throw Errors.conflict('Esta reserva ya se encuentra pagada en su totalidad.');
    }
    // Solo un comprobante en revisión a la vez por reserva
    const pendiente = (await dataRepository.getPagosByReserva(reservaId)).find(
      (p) => p.estado === 'PENDIENTE_REVISION'
    );
    if (pendiente) {
      throw Errors.conflict(
        `Ya hay un comprobante en revisión para esta reserva (pago #${pendiente.id}). Espera la respuesta del operador.`
      );
    }

    // --- 2. Datos del pago ----------------------------------------------------
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

    // --- 3. Monto: la seña (50 %) en el primer pago, o lo que falte pagar -----
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
    // Se acepta el monto esperado o el total completo (con un margen por redondeo)
    if (
      Math.abs(monto - montoEsperado) > TOLERANCIA_MONTO &&
      Math.abs(monto - reserva.total) > TOLERANCIA_MONTO
    ) {
      throw Errors.unprocessable(
        `El monto enviado (S/ ${monto.toFixed(2)}) no coincide con el monto requerido para la modalidad ${modalidad} (S/ ${montoEsperado.toFixed(2)}).`
      );
    }

    // --- 4. Guardar el pago y proteger la reserva -----------------------------
    const pago = await dataRepository.createPago({
      reserva_id: reservaId,
      metodo,
      modalidad,
      monto,
      numero_operacion: numeroOperacion,
      comprobante_url: comprobanteService.validarPertenencia(reservaId, payload.comprobante_url),
      estado: 'PENDIENTE_REVISION',
      observacion: payload.observacion ? String(payload.observacion).trim() : null,
    });

    // EN_REVISION evita que la reserva venza a los 20 min mientras el admin revisa
    const reservaActualizada = (await dataRepository.updateReserva(reservaId, {
      estado: 'EN_REVISION',
    }))!;

    // auto_aprobar: la demo puede pedir que se apruebe en el acto
    if (payload.auto_aprobar === true) {
      return this.aprobarPagoSinBloqueo(pago.id);
    }

    return { pago, reserva: reservaActualizada };
  }

  // ===========================================================================
  // Aprobar
  // ===========================================================================

  private async aprobarPagoSinBloqueo(pagoId: number): Promise<ResultadoRevision> {
    if (!Number.isInteger(pagoId) || pagoId <= 0) {
      throw Errors.badRequest('El ID del pago debe ser un entero positivo.');
    }
    const pago = await dataRepository.getPagoById(pagoId);
    if (!pago) {
      throw Errors.notFound(`No se encontró el pago con ID ${pagoId}.`);
    }

    const reserva = await reservaService.obtenerReserva(pago.reserva_id);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se puede aprobar un pago de una reserva en estado ${reserva.estado}.`
      );
    }

    // Idempotencia: si ya estaba aprobado, se responde igual sin volver a sumar el monto
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

    // Lo pagado nunca supera el total de la reserva
    const nuevoMontoPagado = Number(
      Math.min(reserva.total, reserva.monto_pagado + pago.monto).toFixed(2)
    );

    const reservaConfirmada = (await dataRepository.updateReserva(reserva.id, {
      estado: 'CONFIRMADA',
      monto_pagado: nuevoMontoPagado,
      codigo_qr: ticketQrService.generarCodigo(reserva),
    }))!;

    return { pago: pagoAprobado, reserva: reservaConfirmada, idempotent: false };
  }

  // ===========================================================================
  // Rechazar
  // ===========================================================================

  /**
   * Solo se rechazan pagos PENDIENTE_REVISION (uno APROBADO o REEMBOLSADO responde 409).
   * Si la reserva estaba EN_REVISION y no le queda otro comprobante pendiente, vuelve a
   * PENDIENTE_PAGO con 20 minutos nuevos para que el jugador envíe un comprobante válido.
   */
  private async rechazarPagoSinBloqueo(
    pagoId: number,
    observacion: unknown
  ): Promise<ResultadoRevision> {
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
    const reserva = await reservaService.obtenerReserva(pago.reserva_id);

    // Idempotencia: rechazarlo otra vez no cambia nada
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
          expires_at: vencimientoDeBloqueo(),
        }))!;
      }
    }

    return { pago: pagoRechazado, reserva: reservaActualizada, idempotent: false };
  }

  // ===========================================================================
  // Bandeja del admin
  // ===========================================================================

  /**
   * Lista los pagos (opcionalmente filtrados por estado) con el resumen de su reserva
   * y el enlace firmado del voucher, para aprobarlos o rechazarlos sin consultas extra.
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

    // Cada reserva se consulta una sola vez aunque tenga varios pagos
    const reservas = new Map<number, Reserva | null>();
    for (const pago of pagos) {
      if (!reservas.has(pago.reserva_id)) {
        reservas.set(pago.reserva_id, await dataRepository.getReservaById(pago.reserva_id));
      }
    }

    const firmadas = await comprobanteService.firmarEnlaces(pagos);

    return pagos.map((pago) => {
      const r = reservas.get(pago.reserva_id);
      return {
        ...pago,
        comprobante_url_firmada: firmadas.get(pago.id) ?? null,
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
}

export const pagoService = new PagoService();

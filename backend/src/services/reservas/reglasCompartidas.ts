/**
 * Reglas y utilidades que comparten los servicios del módulo de reservas
 * (reservas, pagos, comprobantes y Ticket QR).
 *
 * Se juntan aquí para que todos usen exactamente el mismo bloqueo de 20 minutos
 * y la misma clave de concurrencia por reserva; si cada servicio tuviera la suya,
 * dos operaciones sobre la misma reserva podrían cruzarse.
 */
import { dataRepository } from '../../repositories/dataRepository';

/** Minutos que una reserva PENDIENTE_PAGO retiene el turno antes de vencer. */
export const BLOQUEO_MINUTOS = 20;

/** Estados en los que una reserva ocupa el turno de la cancha. */
export const ESTADOS_QUE_OCUPAN_TURNO = ['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'];

/** Fecha y hora (ISO) en que vencerá un bloqueo que empieza ahora. */
export function vencimientoDeBloqueo(): string {
  return new Date(Date.now() + BLOQUEO_MINUTOS * 60 * 1000).toISOString();
}

// ---------------------------------------------------------------------------
// Concurrencia
// Las operaciones que cambian el estado de una reserva o de sus pagos se
// ejecutan una detrás de otra por reserva (clave `reserva:<id>`). Así, por
// ejemplo, aprobar y rechazar el mismo pago a la vez no puede dejar datos
// inconsistentes. Crear reservas usa otra clave (`reservas:<fecha>`) en
// reservaService, porque ahí lo que se protege es el turno de ese día.
// ---------------------------------------------------------------------------

/** Ejecuta `fn` con la reserva bloqueada para otras operaciones. */
export function conBloqueoDeReserva<T>(reservaId: number, fn: () => Promise<T>): Promise<T> {
  return dataRepository.conBloqueo(`reserva:${reservaId}`, fn);
}

/**
 * Igual que conBloqueoDeReserva, pero a partir del ID de un pago: busca a qué
 * reserva pertenece y bloquea esa reserva. Si el ID no es válido o el pago no
 * existe, ejecuta `fn` sin bloqueo para que sea ella quien responda el error
 * correspondiente (400 o 404).
 */
export async function conBloqueoDeReservaDelPago<T>(
  pagoId: number,
  fn: () => Promise<T>
): Promise<T> {
  const pago =
    Number.isInteger(pagoId) && pagoId > 0 ? await dataRepository.getPagoById(pagoId) : null;
  if (!pago) return fn();
  return conBloqueoDeReserva(pago.reserva_id, fn);
}

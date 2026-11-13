/**
 * Ticket QR de ingreso (LÓGICA DE NEGOCIO 6, LX-202).
 *
 * El backend no genera ninguna imagen: el "QR" es un texto con el formato
 * LUXXITO-QR-<idReserva>-<10 caracteres hexadecimales>. La app lo dibuja como
 * imagen con el paquete qr_flutter y el operador lo escanea en la puerta.
 */
import crypto from 'crypto';
import { dataRepository } from '../../repositories/dataRepository';
import { Reserva } from '../../types/models';
import { Errors } from '../../utils/errors';

const PREFIJO_QR = 'LUXXITO-QR-';

export class TicketQrService {
  /**
   * Genera el código del Ticket QR de una reserva.
   * Si la reserva ya tiene uno, lo reutiliza (aprobar dos veces no cambia el ticket).
   * La parte final es un SHA-256 de id + DNI + fecha, para que no se pueda adivinar
   * el código de otra reserva solo cambiando el número.
   */
  generarCodigo(reserva: Pick<Reserva, 'id' | 'cliente_dni' | 'fecha' | 'codigo_qr'>): string {
    if (reserva.codigo_qr) return reserva.codigo_qr;
    const huella = crypto
      .createHash('sha256')
      .update(`${reserva.id}-${reserva.cliente_dni}-${reserva.fecha}`)
      .digest('hex')
      .substring(0, 10)
      .toUpperCase();
    return `${PREFIJO_QR}${reserva.id}-${huella}`;
  }

  /**
   * Verifica el ticket en la puerta y registra el ingreso. Solo se acepta si:
   * - el código existe y pertenece a una reserva CONFIRMADA, y
   * - no se usó antes (un mismo ticket no sirve para entrar dos veces).
   */
  async verificarTicketQr(codigoQrInput: unknown): Promise<{
    verificado: boolean;
    estado_ingreso: 'INGRESO_REGISTRADO';
    verificado_en: string;
    reserva: Reserva;
  }> {
    const codigoQr = typeof codigoQrInput === 'string' ? codigoQrInput.trim() : '';
    if (!codigoQr || !codigoQr.toUpperCase().startsWith(PREFIJO_QR)) {
      throw Errors.badRequest(
        'Debes proporcionar un código QR válido con formato LUXXITO-QR-...'
      );
    }

    const reserva = await dataRepository.getReservaByCodigoQr(codigoQr);
    if (!reserva) {
      // Al cancelar se borra el código, así que no se encuentra. Para dar un mensaje
      // más claro, se busca la reserva por el ID que viene dentro del código.
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
      const usadoEn = new Date(reserva.qr_usado_at).toLocaleString('es-PE', {
        timeZone: 'America/Lima',
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
      throw Errors.conflict(
        `Este Ticket QR ya fue utilizado para ingresar (${usadoEn}).`
      );
    }

    // marcarQrUsado solo escribe si el ticket sigue sin usar; si devuelve null,
    // otro escaneo registró el ingreso entre la lectura de arriba y esta escritura.
    const verificadoEn = new Date().toISOString();
    const actualizada = await dataRepository.marcarQrUsado(reserva.id, verificadoEn);
    if (!actualizada) {
      throw Errors.conflict('Este Ticket QR ya fue utilizado previamente para registrar el ingreso.');
    }

    return {
      verificado: true,
      estado_ingreso: 'INGRESO_REGISTRADO',
      verificado_en: verificadoEn,
      reserva: actualizada,
    };
  }
}

export const ticketQrService = new TicketQrService();

/**
 * Cotización de reservas (LÓGICA DE NEGOCIO 2).
 *
 * El precio siempre lo calcula el servidor; nunca se confía en importes que
 * envíe la app. Este servicio solo calcula y valida: no guarda nada en la base
 * de datos, por eso reservaService lo reutiliza antes de crear una reserva.
 */
import { dataRepository } from '../../repositories/dataRepository';
import { CotizacionInput, CotizacionOutput, ReservaExtraItem } from '../../types/models';
import { Errors } from '../../utils/errors';

/** Desde esta hora (inclusive) se cobra la tarifa nocturna. */
const HORA_INICIO_TARIFA_NOCTURNA = 18;
/** Máximo de horas seguidas que se pueden reservar en una sola reserva. */
const DURACION_MAXIMA_HORAS = 4;

export class CotizacionService {
  /**
   * Calcula el precio de un turno:
   * - Valida que la cancha exista y esté ACTIVA, y que el horario esté dentro de
   *   la atención del complejo (máximo 4 horas).
   * - Cobra cada hora con tarifa diurna (< 18:00) o nocturna (>= 18:00).
   * - Revisa que cada extra sea del mismo complejo y que haya stock libre en ese horario.
   * - Devuelve el total y el adelanto del 50 % (seña).
   */
  async cotizarReserva(input: CotizacionInput): Promise<CotizacionOutput> {
    // Libera primero los turnos con bloqueo vencido para que el stock de extras sea real
    await dataRepository.expireOverdueReservas();

    // --- 1. Cancha y complejo -------------------------------------------------
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

    // --- 2. Fecha y horario ---------------------------------------------------
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

    if (horaFin - horaInicio > DURACION_MAXIMA_HORAS) {
      throw Errors.unprocessable('La duración máxima por reserva es de 4 horas consecutivas.');
    }

    // --- 3. Precio de la cancha, hora por hora --------------------------------
    // Un turno de 17:00 a 19:00 cobra la primera hora como diurna y la segunda como nocturna.
    const desgloseHoras: CotizacionOutput['desglose_horas'] = [];
    let subtotalCancha = 0;

    for (let h = horaInicio; h < horaFin; h++) {
      const esNocturno = h >= HORA_INICIO_TARIFA_NOCTURNA;
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

    // --- 4. Extras (pelotas, chalecos, etc.) y su stock en ese horario ---------
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

        // El stock es por intervalo: lo que usan otras reservas que se cruzan con este horario
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

    // --- 5. Totales (redondeados a céntimos) ----------------------------------
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
}

export const cotizacionService = new CotizacionService();

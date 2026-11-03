import { dataRepository } from '../repositories/dataRepository';
import {
  Cancha,
  Complejo,
  DeporteTipo,
  DisponibilidadResponse,
  EstadoCancha,
  Extra,
  TurnoDisponibilidad,
} from '../types/models';
import { Errors } from '../utils/errors';
import { getDbMode, getSupabaseClient, isStorageConfigured } from '../config/database';

const BUCKET_CANCHAS = 'canchas';
const MIMES_IMAGEN = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_BYTES_IMAGEN = 5 * 1024 * 1024;

const VALID_DEPORTES: DeporteTipo[] = [
  'Futbol 5',
  'Futbol 7',
  'Futbol 11',
  'Voley',
  'Tenis',
  'Padel',
  'Basquet',
];

const VALID_ESTADOS_CANCHA: EstadoCancha[] = ['ACTIVA', 'MANTENIMIENTO', 'INACTIVA'];

export class CatalogService {
  async listarComplejos(distrito?: string): Promise<Complejo[]> {
    return dataRepository.getComplejos(distrito);
  }

  async obtenerComplejo(id: number): Promise<Complejo & { canchas: Cancha[]; extras: Extra[] }> {
    if (!Number.isInteger(id) || id <= 0) {
      throw Errors.badRequest('El ID del complejo debe ser un entero positivo.');
    }
    const complejo = await dataRepository.getComplejoById(id);
    if (!complejo) {
      throw Errors.notFound(`No se encontró el complejo deportivo con ID ${id}.`);
    }
    const canchas = await dataRepository.getCanchas({ complejo_id: id });
    const extras = await dataRepository.getExtrasByComplejo(id);
    return { ...complejo, canchas, extras };
  }

  async listarCanchas(filters?: {
    complejo_id?: number;
    distrito?: string;
    deporte?: string;
    estado?: string;
  }): Promise<Cancha[]> {
    return dataRepository.getCanchas(filters);
  }

  async obtenerCancha(id: number): Promise<Cancha> {
    if (!Number.isInteger(id) || id <= 0) {
      throw Errors.badRequest('El ID de la cancha debe ser un entero positivo.');
    }
    const cancha = await dataRepository.getCanchaById(id);
    if (!cancha) {
      throw Errors.notFound(`No se encontró la cancha con ID ${id}.`);
    }
    return cancha;
  }

  async crearCancha(payload: any): Promise<Cancha> {
    const complejoId = Number(payload.complejo_id);
    if (!Number.isInteger(complejoId) || complejoId <= 0) {
      throw Errors.badRequest('El campo complejo_id es obligatorio y debe ser válido.');
    }
    const complejo = await dataRepository.getComplejoById(complejoId);
    if (!complejo) {
      throw Errors.notFound(`El complejo con ID ${complejoId} no existe.`);
    }

    const nombre = String(payload.nombre || '').trim();
    if (nombre.length < 3) {
      throw Errors.badRequest('El nombre de la cancha debe tener al menos 3 caracteres.');
    }

    const deporte = payload.deporte as DeporteTipo;
    if (!VALID_DEPORTES.includes(deporte)) {
      throw Errors.badRequest(
        `Deporte inválido. Valores permitidos: ${VALID_DEPORTES.join(', ')}.`
      );
    }

    const precioDiurno = Number(payload.precio_hora_diurno);
    const precioNocturno = Number(payload.precio_hora_nocturno);
    if (isNaN(precioDiurno) || precioDiurno <= 0) {
      throw Errors.badRequest('El precio por hora diurno debe ser mayor a 0.');
    }
    if (isNaN(precioNocturno) || precioNocturno < precioDiurno) {
      throw Errors.badRequest(
        'El precio por hora nocturno debe ser mayor o igual al precio diurno.'
      );
    }

    const estado: EstadoCancha = payload.estado || 'ACTIVA';
    if (!VALID_ESTADOS_CANCHA.includes(estado)) {
      throw Errors.badRequest(
        `Estado de cancha inválido. Valores permitidos: ${VALID_ESTADOS_CANCHA.join(', ')}.`
      );
    }

    return dataRepository.createCancha({
      complejo_id: complejoId,
      nombre,
      deporte,
      superficie: String(payload.superficie || 'Grass Sintetico Pro').trim(),
      techada: Boolean(payload.techada),
      iluminacion: payload.iluminacion !== undefined ? Boolean(payload.iluminacion) : true,
      precio_hora_diurno: precioDiurno,
      precio_hora_nocturno: precioNocturno,
      estado,
    });
  }

  /**
   * Foto propia de una cancha (solo ADMIN): se guarda en el bucket público 'canchas'
   * y su URL pública queda en canchas.imagen_url.
   */
  async subirImagenCancha(id: number, payload: any): Promise<Cancha> {
    if (!Number.isInteger(id) || id <= 0) {
      throw Errors.badRequest('El ID de la cancha debe ser un entero positivo.');
    }
    const cancha = await dataRepository.getCanchaById(id);
    if (!cancha) throw Errors.notFound(`No se encontró la cancha con ID ${id}.`);

    const mimeType = String(payload?.mime_type || 'image/jpeg').trim().toLowerCase();
    if (!MIMES_IMAGEN.includes(mimeType)) {
      throw Errors.badRequest(`Formato de imagen no permitido (${mimeType}). Usa JPEG, PNG o WEBP.`);
    }
    const base64 = String(payload?.contenido_base64 || '')
      .replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, '')
      .trim();
    if (base64.length < 8) {
      throw Errors.badRequest('Debes adjuntar la imagen de la cancha en base64.');
    }
    const buffer = Buffer.from(base64, 'base64');
    if (buffer.byteLength > MAX_BYTES_IMAGEN) {
      throw Errors.unprocessable('La imagen supera el límite máximo permitido de 5 MB.');
    }

    const ext = mimeType === 'image/png' ? 'png' : mimeType === 'image/webp' ? 'webp' : 'jpg';
    const ruta = `cancha-${id}/foto-${Date.now()}.${ext}`;
    let imagenUrl: string;

    if (isStorageConfigured()) {
      const storage = getSupabaseClient().storage.from(BUCKET_CANCHAS);
      const { error } = await storage.upload(ruta, buffer, { contentType: mimeType, upsert: false });
      if (error) throw Errors.storage(`No se pudo guardar la foto en Storage: ${error.message}`);
      imagenUrl = storage.getPublicUrl(ruta).data.publicUrl;
    } else if (getDbMode() === 'LOCAL_STORE') {
      // Pruebas y modo local: se valida sin subir el archivo
      imagenUrl = `local://${BUCKET_CANCHAS}/${ruta}`;
    } else {
      throw Errors.storage(
        'Supabase Storage no está configurado en el servidor (falta SUPABASE_SERVICE_ROLE_KEY).'
      );
    }

    return (await dataRepository.actualizarImagenCancha(id, imagenUrl))!;
  }

  async actualizarCancha(id: number, payload: any): Promise<Cancha> {
    const existing = await this.obtenerCancha(id);

    if (payload.deporte !== undefined && !VALID_DEPORTES.includes(payload.deporte)) {
      throw Errors.badRequest(
        `Deporte inválido. Valores permitidos: ${VALID_DEPORTES.join(', ')}.`
      );
    }
    if (payload.estado !== undefined && !VALID_ESTADOS_CANCHA.includes(payload.estado)) {
      throw Errors.badRequest(
        `Estado inválido. Valores permitidos: ${VALID_ESTADOS_CANCHA.join(', ')}.`
      );
    }

    const diurno =
      payload.precio_hora_diurno !== undefined
        ? Number(payload.precio_hora_diurno)
        : existing.precio_hora_diurno;
    const nocturno =
      payload.precio_hora_nocturno !== undefined
        ? Number(payload.precio_hora_nocturno)
        : existing.precio_hora_nocturno;

    if (isNaN(diurno) || diurno <= 0) {
      throw Errors.badRequest('El precio diurno debe ser mayor a 0.');
    }
    if (isNaN(nocturno) || nocturno < diurno) {
      throw Errors.badRequest('El precio nocturno no puede ser menor al precio diurno.');
    }

    const updated = await dataRepository.updateCancha(id, {
      nombre: payload.nombre ? String(payload.nombre).trim() : existing.nombre,
      deporte: payload.deporte ?? existing.deporte,
      superficie: payload.superficie
        ? String(payload.superficie).trim()
        : existing.superficie,
      techada: payload.techada !== undefined ? Boolean(payload.techada) : existing.techada,
      iluminacion:
        payload.iluminacion !== undefined ? Boolean(payload.iluminacion) : existing.iluminacion,
      precio_hora_diurno: diurno,
      precio_hora_nocturno: nocturno,
      estado: payload.estado ?? existing.estado,
    });
    return updated!;
  }

  /**
   * LÓGICA DE NEGOCIO 1:
   * Calcula la disponibilidad horaria real de una cancha para una fecha específica,
   * determinando tarifas diferenciadas (diurna < 18:00, nocturna >= 18:00),
   * bloqueos activos, reservas confirmadas y stock de extras del complejo.
   */
  async consultarDisponibilidad(
    canchaId: number,
    fecha: string,
    horaConsulta?: number
  ): Promise<DisponibilidadResponse> {
    const cancha = await this.obtenerCancha(canchaId);
    const complejo = await dataRepository.getComplejoById(cancha.complejo_id);
    if (!complejo) {
      throw Errors.notFound('Complejo deportivo no encontrado.');
    }

    if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
      throw Errors.badRequest('El parámetro fecha debe tener formato YYYY-MM-DD.');
    }

    await dataRepository.expireOverdueReservas();
    const reservasDelDia = await dataRepository.getReservasByCanchaAndDate(canchaId, fecha);
    const now = new Date();
    const hoyLima = new Date(now.getTime() - 5 * 60 * 60 * 1000)
      .toISOString()
      .split('T')[0];
    const horaActualLima = new Date(now.getTime() - 5 * 60 * 60 * 1000).getUTCHours();

    const turnos: TurnoDisponibilidad[] = [];
    for (let h = complejo.hora_apertura; h < complejo.hora_cierre; h++) {
      const esNocturno = h >= 18;
      const precio = esNocturno ? cancha.precio_hora_nocturno : cancha.precio_hora_diurno;
      let estado: TurnoDisponibilidad['estado'] = 'DISPONIBLE';
      let reservaOcupanteId: number | undefined;

      if (cancha.estado !== 'ACTIVA') {
        estado = 'MANTENIMIENTO';
      } else if (fecha < hoyLima || (fecha === hoyLima && h <= horaActualLima)) {
        estado = 'PASADA';
      } else {
        const reservaActiva = reservasDelDia.find(
          (r) =>
            h >= r.hora_inicio &&
            h < r.hora_fin &&
            ['PENDIENTE_PAGO', 'EN_REVISION', 'CONFIRMADA'].includes(r.estado)
        );
        if (reservaActiva) {
          reservaOcupanteId = reservaActiva.id;
          estado =
            reservaActiva.estado === 'CONFIRMADA' ? 'OCUPADA' : 'BLOQUEADA';
        }
      }

      turnos.push({
        hora_inicio: h,
        hora_fin: h + 1,
        etiqueta: `${String(h).padStart(2, '0')}:00 - ${String(h + 1).padStart(2, '0')}:00`,
        tarifa_tipo: esNocturno ? 'NOCTURNA' : 'DIURNA',
        precio,
        estado,
        reserva_id: reservaOcupanteId,
      });
    }

    const extrasRaw = await dataRepository.getExtrasByComplejo(complejo.id);
    const extrasDisponibles: Extra[] = [];
    for (const ex of extrasRaw) {
      let usado = 0;
      if (horaConsulta !== undefined && Number.isInteger(horaConsulta)) {
        usado = await dataRepository.getExtraUsedQuantityInInterval(
          ex.id,
          fecha,
          horaConsulta,
          horaConsulta + 1
        );
      }
      extrasDisponibles.push({
        ...ex,
        stock_disponible: Math.max(0, ex.stock_total - usado),
      });
    }

    return {
      cancha,
      complejo,
      fecha,
      horario_operacion: {
        apertura: complejo.hora_apertura,
        cierre: complejo.hora_cierre,
      },
      turnos,
      extras_disponibles: extrasDisponibles,
    };
  }
}

export const catalogService = new CatalogService();

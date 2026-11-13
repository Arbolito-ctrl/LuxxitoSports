/**
 * Sugerencia de nombre a partir del DNI (para autocompletar el registro).
 *
 * Proveedor: Decolecta (antes apis.net.pe). Devuelve SOLO nombres y apellidos,
 * que son datos públicos: RENIEC ofrece la misma consulta gratis en su web.
 * No se pide ni se guarda ningún otro dato de la persona.
 *
 * Seguridad y costo:
 * - El token (DECOLECTA_TOKEN) vive solo en el servidor; nunca viaja en el APK.
 * - Las respuestas se guardan en memoria 24 h para no gastar consultas del plan
 *   gratuito (1000 al mes) si alguien escribe el mismo DNI varias veces.
 * - El límite de consultas por IP está en middlewares/limiteConsultas.ts.
 * - Si el proveedor falla o no hay token, el registro sigue funcionando: la app
 *   simplemente no muestra la sugerencia.
 */
import { AppError, Errors } from '../utils/errors';

const URL_DECOLECTA = 'https://api.decolecta.com/v1/reniec/dni';
const TIEMPO_MAXIMO_MS = 8000;
const VIGENCIA_CACHE_MS = 24 * 60 * 60 * 1000;
const MAXIMO_EN_CACHE = 500;

export type NombreSugerido = {
  dni: string;
  nombres: string;
  apellido_paterno: string;
  apellido_materno: string;
  nombre_completo: string;
};

type RespuestaDecolecta = {
  first_name?: string;
  first_last_name?: string;
  second_last_name?: string;
  full_name?: string;
  document_number?: string;
};

const noDisponible = (mensaje: string) => new AppError(mensaje, 503, 'DNI_LOOKUP_UNAVAILABLE');

export class DniService {
  private cache = new Map<string, { valor: NombreSugerido; vence: number }>();

  /** Solo para pruebas: vacía la caché entre casos. */
  limpiarCache(): void {
    this.cache.clear();
  }

  async sugerirNombre(dniEntrada: unknown): Promise<NombreSugerido> {
    const dni = typeof dniEntrada === 'string' ? dniEntrada.trim() : '';
    if (!/^\d{8}$/.test(dni)) {
      throw Errors.badRequest('El DNI debe tener exactamente 8 dígitos numéricos.');
    }

    const guardado = this.cache.get(dni);
    if (guardado && guardado.vence > Date.now()) return guardado.valor;

    const token = (process.env.DECOLECTA_TOKEN || '').trim();
    if (!token) {
      throw noDisponible('La sugerencia de nombre por DNI no está configurada en el servidor.');
    }

    let respuesta: Response;
    try {
      respuesta = await fetch(`${URL_DECOLECTA}?numero=${dni}`, {
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
        signal: AbortSignal.timeout(TIEMPO_MAXIMO_MS),
      });
    } catch {
      throw noDisponible('No pudimos consultar el DNI en este momento. Escribe tu nombre manualmente.');
    }

    // Token inválido o sin cuota: es un problema del servidor, no del usuario
    if (respuesta.status === 401 || respuesta.status === 403 || respuesta.status === 429) {
      console.error(`[DNI] Decolecta respondió ${respuesta.status}: revisa DECOLECTA_TOKEN o la cuota.`);
      throw noDisponible('La sugerencia de nombre no está disponible ahora. Escribe tu nombre manualmente.');
    }
    if (!respuesta.ok) {
      throw Errors.notFound('No encontramos un nombre para ese DNI. Escríbelo manualmente.');
    }

    const datos = (await respuesta.json().catch(() => ({}))) as RespuestaDecolecta;
    const nombres = (datos.first_name || '').trim();
    const paterno = (datos.first_last_name || '').trim();
    const materno = (datos.second_last_name || '').trim();
    if (!nombres || !paterno) {
      throw Errors.notFound('No encontramos un nombre para ese DNI. Escríbelo manualmente.');
    }

    // Solo se devuelven nombres y apellidos, aunque el proveedor enviara algo más
    const valor: NombreSugerido = {
      dni,
      nombres,
      apellido_paterno: paterno,
      apellido_materno: materno,
      nombre_completo: [nombres, paterno, materno].filter(Boolean).join(' '),
    };

    if (this.cache.size >= MAXIMO_EN_CACHE) {
      // Se descarta la entrada más antigua (los Map conservan el orden de inserción)
      const masAntigua = this.cache.keys().next().value;
      if (masAntigua !== undefined) this.cache.delete(masAntigua);
    }
    this.cache.set(dni, { valor, vence: Date.now() + VIGENCIA_CACHE_MS });
    return valor;
  }
}

export const dniService = new DniService();

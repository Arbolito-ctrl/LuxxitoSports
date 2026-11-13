/**
 * Imágenes de los comprobantes de pago (vouchers de Yape, Plin o transferencia).
 *
 * Los archivos se guardan en el bucket PRIVADO 'comprobantes' de Supabase Storage,
 * dentro de una carpeta por reserva: reserva-<id>/voucher-<timestamp>.<ext>.
 * En la base de datos se guarda la referencia "supabase://comprobantes/<ruta>";
 * para que el admin vea la imagen se genera un enlace firmado que caduca en 1 hora.
 */
import { getDbMode, getSupabaseClient, isStorageConfigured } from '../../config/database';
import { Pago } from '../../types/models';
import { Errors } from '../../utils/errors';
import { reservaService } from './reservaService';

const BUCKET_COMPROBANTES = 'comprobantes';
const PREFIJO_STORAGE = `supabase://${BUCKET_COMPROBANTES}/`;
const VIGENCIA_URL_FIRMADA_SEG = 60 * 60;
const TAMANO_MAXIMO_BYTES = 5 * 1024 * 1024;
const MIME_PERMITIDOS = ['image/jpeg', 'image/png', 'image/webp'];

export class ComprobanteService {
  /**
   * Recibe la imagen en base64, la valida y la sube al bucket (complementa la regla 4).
   * Devuelve la referencia `comprobante_url` que luego se envía al registrar el pago.
   */
  async subirComprobanteStorage(payload: {
    reserva_id?: unknown;
    nombre_archivo?: unknown;
    mime_type?: unknown;
    contenido_base64?: unknown;
  }): Promise<{
    bucket: string;
    path: string;
    comprobante_url: string;
    mime_type: string;
    size_bytes: number;
    almacenado: boolean;
  }> {
    // --- 1. La reserva debe existir y seguir activa ----------------------------
    const reservaId = Number(payload?.reserva_id);
    if (!Number.isInteger(reservaId) || reservaId <= 0) {
      throw Errors.badRequest('El campo reserva_id debe ser un entero positivo.');
    }
    const reserva = await reservaService.obtenerReserva(reservaId);
    if (reserva.estado === 'CANCELADA' || reserva.estado === 'VENCIDA') {
      throw Errors.conflict(
        `No se pueden adjuntar comprobantes a una reserva en estado ${reserva.estado}.`
      );
    }

    // --- 2. Formato y tamaño de la imagen --------------------------------------
    const mimeType = String(payload?.mime_type || 'image/jpeg').trim().toLowerCase();
    if (!MIME_PERMITIDOS.includes(mimeType)) {
      throw Errors.badRequest(
        `Formato de imagen no permitido (${mimeType}). Usa JPEG, PNG o WEBP.`
      );
    }

    // Acepta el base64 "puro" o con el prefijo data:image/...;base64,
    const base64Raw = String(payload?.contenido_base64 || '')
      .replace(/^data:image\/[a-zA-Z0-9+.-]+;base64,/, '')
      .trim();
    if (base64Raw.length < 8) {
      throw Errors.badRequest(
        'Debes adjuntar el contenido de la imagen del comprobante en base64.'
      );
    }

    const buffer = Buffer.from(base64Raw, 'base64');
    if (buffer.byteLength > TAMANO_MAXIMO_BYTES) {
      throw Errors.unprocessable(
        'El archivo del comprobante supera el límite máximo permitido de 5 MB.'
      );
    }

    // --- 3. Ruta dentro del bucket: una carpeta por reserva ---------------------
    const ext = mimeType === 'image/png' ? 'png' : mimeType === 'image/webp' ? 'webp' : 'jpg';
    const objectPath = `reserva-${reservaId}/voucher-${Date.now()}.${ext}`;
    const comprobanteUrl = `${PREFIJO_STORAGE}${objectPath}`;

    // --- 4. Subir ---------------------------------------------------------------
    // Con Supabase configurado se guarda el archivo en el bucket privado;
    // en pruebas y modo local solo se valida y se devuelve la ruta.
    const almacenado = isStorageConfigured();
    if (!almacenado && getDbMode() !== 'LOCAL_STORE') {
      throw Errors.storage(
        'Supabase Storage no está configurado en el servidor (falta SUPABASE_SERVICE_ROLE_KEY).'
      );
    }
    if (almacenado) {
      const { error } = await getSupabaseClient()
        .storage.from(BUCKET_COMPROBANTES)
        .upload(objectPath, buffer, { contentType: mimeType, upsert: false });
      if (error) {
        throw Errors.storage(`No se pudo guardar el comprobante en Storage: ${error.message}`);
      }
    }

    return {
      bucket: BUCKET_COMPROBANTES,
      path: objectPath,
      comprobante_url: comprobanteUrl,
      mime_type: mimeType,
      size_bytes: buffer.byteLength,
      almacenado,
    };
  }

  /**
   * Comprueba que el voucher que se adjunta a un pago se haya subido para esa misma
   * reserva (evita reutilizar el comprobante de otra). Devuelve la URL limpia, o
   * null si no se adjuntó ninguna. URLs externas (no del bucket) se aceptan tal cual.
   */
  validarPertenencia(reservaId: number, valor: unknown): string | null {
    if (valor === undefined || valor === null || String(valor).trim() === '') return null;
    const url = String(valor).trim();
    if (url.startsWith(PREFIJO_STORAGE) && !url.startsWith(`${PREFIJO_STORAGE}reserva-${reservaId}/`)) {
      throw Errors.badRequest('El comprobante adjunto no pertenece a esta reserva.');
    }
    return url;
  }

  /**
   * Genera enlaces firmados (válidos 1 hora) para ver los vouchers del bucket privado.
   * Devuelve un mapa idPago → enlace. Si Storage no está configurado o falla,
   * devuelve el mapa vacío y los pagos se listan igual, solo que sin vista previa.
   */
  async firmarEnlaces(pagos: Pago[]): Promise<Map<number, string>> {
    const firmadas = new Map<number, string>();
    const conArchivo = pagos.filter((p) => p.comprobante_url?.startsWith(PREFIJO_STORAGE));
    if (!isStorageConfigured() || conArchivo.length === 0) return firmadas;

    // Una sola llamada a Storage para todos los archivos
    const rutas = conArchivo.map((p) => p.comprobante_url!.slice(PREFIJO_STORAGE.length));
    const { data, error } = await getSupabaseClient()
      .storage.from(BUCKET_COMPROBANTES)
      .createSignedUrls(rutas, VIGENCIA_URL_FIRMADA_SEG);
    if (error || !data) return firmadas;

    // Storage responde en el mismo orden en que se enviaron las rutas
    data.forEach((item, i) => {
      if (item.signedUrl) firmadas.set(conArchivo[i].id, item.signedUrl);
    });
    return firmadas;
  }
}

export const comprobanteService = new ComprobanteService();

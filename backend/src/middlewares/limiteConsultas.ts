/**
 * Límite simple de peticiones por IP, en memoria (sin dependencias externas).
 *
 * Se usa en endpoints públicos que consumen un servicio externo con cuota, como
 * la sugerencia de nombre por DNI: evita que alguien agote las consultas o use
 * la API para buscar nombres en masa.
 *
 * Al vivir en memoria se reinicia si Render reinicia el servidor; para el
 * volumen del taller es suficiente.
 */
import { Request, Response, NextFunction } from 'express';

export function limiteConsultas(opciones: { maximo: number; ventanaMs: number }) {
  const registros = new Map<string, { cuenta: number; reinicio: number }>();

  return (req: Request, res: Response, next: NextFunction): void => {
    const ahora = Date.now();
    const ip = req.ip || req.socket.remoteAddress || 'desconocida';

    // Limpieza ocasional para que el mapa no crezca sin fin
    if (registros.size > 5000) {
      for (const [clave, r] of registros) if (r.reinicio <= ahora) registros.delete(clave);
    }

    let registro = registros.get(ip);
    if (!registro || registro.reinicio <= ahora) {
      registro = { cuenta: 0, reinicio: ahora + opciones.ventanaMs };
      registros.set(ip, registro);
    }
    registro.cuenta++;

    if (registro.cuenta > opciones.maximo) {
      const segundos = Math.ceil((registro.reinicio - ahora) / 1000);
      res.setHeader('Retry-After', String(segundos));
      res.status(429).json({
        ok: false,
        code: 'TOO_MANY_REQUESTS',
        message: `Demasiadas consultas. Intenta de nuevo en ${segundos} segundos.`,
      });
      return;
    }
    next();
  };
}

import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import apiRoutes from './routes/apiRoutes';
import { AppError } from './utils/errors';

const app = express();

// Render pone un proxy delante de la API: así req.ip es la IP real del usuario
// (la usa el límite de consultas) y no la del proxy, que sería la misma para todos.
app.set('trust proxy', 1);

app.use(cors());
// La foto del voucher viaja en base64: 5 MB del bucket equivalen a ~6,7 MB de JSON.
// El resto de la API mantiene el límite por defecto de 100 KB.
app.use('/api/pagos/comprobante', express.json({ limit: '8mb' }));
app.use(/^\/api\/canchas\/\d+\/imagen$/, express.json({ limit: '8mb' }));
app.use(express.json());

// Quien abre la raíz o /api en el navegador llega a la documentación (Swagger UI)
app.get(['/', '/api', '/api/'], (_req: Request, res: Response) => res.redirect('/api/docs'));

// Rutas principales de la API REST
app.use('/api', apiRoutes);

// Manejo de rutas inexistentes (404)
app.use((req: Request, res: Response) => {
  res.status(404).json({
    ok: false,
    code: 'ROUTE_NOT_FOUND',
    message: `La ruta ${req.method} ${req.originalUrl} no existe en la API de Luxxito Sports.`,
  });
});

// Middleware centralizado de manejo de errores
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      ok: false,
      code: err.code,
      message: err.message,
      details: err.details || undefined,
    });
    return;
  }

  // Errores del lector de JSON (cuerpo demasiado grande o mal formado)
  const tipo = (err as Error & { type?: string }).type;
  if (tipo === 'entity.too.large') {
    res.status(413).json({
      ok: false,
      code: 'PAYLOAD_TOO_LARGE',
      message: 'El contenido enviado es demasiado grande. Usa una imagen de máximo 5 MB.',
    });
    return;
  }
  if (tipo === 'entity.parse.failed') {
    res.status(400).json({
      ok: false,
      code: 'INVALID_JSON',
      message: 'El cuerpo de la solicitud no es un JSON válido.',
    });
    return;
  }

  console.error('[API Error]:', err);
  res.status(500).json({
    ok: false,
    code: 'INTERNAL_SERVER_ERROR',
    message: 'Error interno del servidor al procesar la solicitud.',
  });
});

export default app;

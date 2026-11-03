import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import apiRoutes from './routes/apiRoutes';
import { AppError } from './utils/errors';

const app = express();

app.use(cors());
app.use(express.json());

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

  console.error('[API Error]:', err);
  res.status(500).json({
    ok: false,
    code: 'INTERNAL_SERVER_ERROR',
    message: 'Error interno del servidor al procesar la solicitud.',
  });
});

export default app;

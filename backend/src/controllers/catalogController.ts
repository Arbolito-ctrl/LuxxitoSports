import { version as VERSION_API } from '../../package.json';
import path from 'path';
import fs from 'fs';
import { Request, Response, NextFunction } from 'express';
import { catalogService } from '../services/catalogService';
import { getDbMode, getPgPool, getSupabaseClient } from '../config/database';

export class CatalogController {
  async healthCheck(_req: Request, res: Response): Promise<void> {
    const mode = getDbMode();
    try {
      if (mode === 'POSTGRES_POOL') {
        await getPgPool().query('SELECT 1');
      } else if (mode === 'SUPABASE_REST') {
        const { error } = await getSupabaseClient().from('complejos').select('id').limit(1);
        if (error) throw error;
      } else if (process.env.NODE_ENV === 'production') {
        throw new Error('Persistent database is required in production');
      }
    } catch {
      res.status(503).json({ ok: false, code: 'DATABASE_UNAVAILABLE', db_mode: mode });
      return;
    }
    res.status(200).json({
      ok: true,
      service: 'Luxxito Sports REST API (SI806 - Taller 3)',
      db_mode: mode,
      db_ready: true,
      api_version: VERSION_API,
      commit: process.env.RENDER_GIT_COMMIT || null,
      apk_download_url:
        'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk',
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Versión del APK publicada en GitHub Releases (version.json que genera el CI),
   * para que cualquier cliente sepa cuál es la última sin valores fijos en el servidor.
   */
  async obtenerVersionApp(req: Request, res: Response): Promise<void> {
    const canal = req.query.canal === 'dev-apk' ? 'dev-apk' : 'latest-apk';
    const base = `https://github.com/Arbolito-ctrl/LuxxitoSports/releases/download/${canal}`;
    try {
      const respuesta = await fetch(`${base}/version.json`, { signal: AbortSignal.timeout(8000) });
      if (!respuesta.ok) throw new Error(`HTTP ${respuesta.status}`);
      const publicada = (await respuesta.json()) as Record<string, unknown>;
      res.status(200).json({
        ok: true,
        data: { ...publicada, apk_url: `${base}/luxxito-sports.apk`, api_version: VERSION_API },
      });
    } catch (error) {
      res.status(502).json({
        ok: false,
        code: 'VERSION_NO_DISPONIBLE',
        message: `No se pudo consultar la versión publicada en GitHub (${(error as Error).message}).`,
      });
    }
  }

  async descargarApkLocal(_req: Request, res: Response): Promise<void> {
    const releaseApk = path.join(
      __dirname,
      '../../../mobile/build/app/outputs/flutter-apk/app-release.apk'
    );
    const debugApk = path.join(
      __dirname,
      '../../../mobile/build/app/outputs/flutter-apk/app-debug.apk'
    );

    if (fs.existsSync(releaseApk)) {
      res.download(releaseApk, 'luxxito-sports.apk');
      return;
    }
    if (fs.existsSync(debugApk)) {
      res.download(debugApk, 'luxxito-sports.apk');
      return;
    }

    res.redirect(
      'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk'
    );
  }

  async listarComplejos(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const distrito = req.query.distrito ? String(req.query.distrito) : undefined;
      const complejos = await catalogService.listarComplejos(distrito);
      res.status(200).json({
        ok: true,
        count: complejos.length,
        data: complejos,
      });
    } catch (error) {
      next(error);
    }
  }

  async obtenerComplejo(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const complejo = await catalogService.obtenerComplejo(id);
      res.status(200).json({
        ok: true,
        data: complejo,
      });
    } catch (error) {
      next(error);
    }
  }

  async listarCanchas(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const filters = {
        complejo_id: req.query.complejo_id ? Number(req.query.complejo_id) : undefined,
        distrito: req.query.distrito ? String(req.query.distrito) : undefined,
        deporte: req.query.deporte ? String(req.query.deporte) : undefined,
        estado: req.query.estado ? String(req.query.estado) : undefined,
      };
      const canchas = await catalogService.listarCanchas(filters);
      res.status(200).json({
        ok: true,
        count: canchas.length,
        data: canchas,
      });
    } catch (error) {
      next(error);
    }
  }

  async obtenerCancha(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const cancha = await catalogService.obtenerCancha(id);
      res.status(200).json({
        ok: true,
        data: cancha,
      });
    } catch (error) {
      next(error);
    }
  }

  async crearCancha(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const nueva = await catalogService.crearCancha(req.body);
      res.status(201).json({
        ok: true,
        message: 'Cancha creada exitosamente.',
        data: nueva,
      });
    } catch (error) {
      next(error);
    }
  }

  async actualizarCancha(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const actualizada = await catalogService.actualizarCancha(id, req.body);
      res.status(200).json({
        ok: true,
        message: 'Cancha actualizada exitosamente.',
        data: actualizada,
      });
    } catch (error) {
      next(error);
    }
  }

  async subirImagenCancha(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const cancha = await catalogService.subirImagenCancha(Number(req.params.id), req.body);
      res.status(200).json({ ok: true, message: 'Foto de la cancha actualizada.', data: cancha });
    } catch (error) {
      next(error);
    }
  }

  async consultarDisponibilidad(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const canchaId = Number(req.params.id);
      const hoyLima = new Date(Date.now() - 5 * 60 * 60 * 1000)
        .toISOString()
        .split('T')[0];
      const fecha = req.query.fecha ? String(req.query.fecha) : hoyLima;
      const hora = req.query.hora !== undefined ? Number(req.query.hora) : undefined;

      const disponibilidad = await catalogService.consultarDisponibilidad(
        canchaId,
        fecha,
        hora
      );
      res.status(200).json({
        ok: true,
        data: disponibilidad,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const catalogController = new CatalogController();

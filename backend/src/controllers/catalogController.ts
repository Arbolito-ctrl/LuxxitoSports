import path from 'path';
import fs from 'fs';
import { Request, Response, NextFunction } from 'express';
import { catalogService } from '../services/catalogService';
import { getDbMode } from '../config/database';

export class CatalogController {
  async healthCheck(_req: Request, res: Response): Promise<void> {
    res.status(200).json({
      ok: true,
      service: 'Luxxito Sports REST API (SI806 - Taller 3)',
      db_mode: getDbMode(),
      app_version: '1.0.1',
      apk_download_url:
        'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk',
      timestamp: new Date().toISOString(),
    });
  }

  async obtenerVersionApp(req: Request, res: Response): Promise<void> {
    const host = req.get('host') || 'localhost:3000';
    const protocol = req.protocol || 'http';
    const localApkPath = path.join(
      __dirname,
      '../../../mobile/build/app/outputs/flutter-apk/app-debug.apk'
    );
    const hasLocalApk = fs.existsSync(localApkPath);

    res.status(200).json({
      ok: true,
      data: {
        version: process.env.APP_VERSION || '1.0.1',
        build_number: Number(process.env.APP_BUILD_NUMBER || 2),
        mandatory: false,
        release_notes:
          'Actualización OTA/APK: conexión con Supabase PostgreSQL, cotización horaria día/noche, stock de extras por intervalo y Ticket QR verificable.',
        github_release_apk_url:
          'https://github.com/Arbolito-ctrl/LuxxitoSports/releases/latest/download/luxxito-sports.apk',
        server_apk_url: hasLocalApk ? `${protocol}://${host}/api/apk/download` : null,
      },
    });
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

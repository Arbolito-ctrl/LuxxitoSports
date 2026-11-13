/**
 * Controlador HTTP de la sugerencia de nombre por DNI (registro de usuarios).
 */
import { Request, Response, NextFunction } from 'express';
import { dniService } from '../services/dniService';

export class DniController {
  /** GET /dni/:numero — nombres y apellidos asociados al DNI, para autocompletar. */
  async sugerirNombre(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const data = await dniService.sugerirNombre(req.params.numero);
      res.status(200).json({ ok: true, data });
    } catch (error) {
      next(error);
    }
  }
}

export const dniController = new DniController();

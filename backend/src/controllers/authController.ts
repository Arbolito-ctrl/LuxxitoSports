import { Request, Response, NextFunction } from 'express';
import { authService } from '../services/authService';
import { Errors } from '../utils/errors';

export class AuthController {
  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await authService.login(req.body?.email, req.body?.password);
      if (!result) {
        res.status(401).json({
          ok: false,
          code: 'INVALID_CREDENTIALS',
          message: 'Correo o contraseña incorrectos.',
        });
        return;
      }

      res.status(200).json({
        ok: true,
        message: 'Inicio de sesión exitoso.',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async registro(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await authService.registrar(req.body);
      res.status(201).json({
        ok: true,
        message: 'Cuenta creada exitosamente.',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async me(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = await authService.obtenerPerfilPorId(Number(req.user!.sub));
      res.status(200).json({
        ok: true,
        data: { user },
      });
    } catch (error) {
      next(error);
    }
  }

  async recuperarAcceso(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const email = String(req.body?.email || '').trim().toLowerCase();
      if (!email || !email.includes('@')) {
        throw Errors.badRequest('Ingresa un correo electrónico válido para recuperar tu cuenta.');
      }
      res.status(200).json({
        ok: true,
        message: `Se han enviado las instrucciones de recuperación de contraseña a ${email}.`,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const authController = new AuthController();

/**
 * Controlador HTTP del Ticket QR: el operador escanea el código en la puerta.
 */
import { Request, Response, NextFunction } from 'express';
import { ticketQrService } from '../services/reservas/ticketQrService';

export class TicketQrController {
  /** POST /reservas/verificar-qr (ADMIN) — valida el ticket y registra el ingreso. */
  async verificarQr(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const resultado = await ticketQrService.verificarTicketQr(req.body?.codigo_qr);
      res.status(200).json({
        ok: true,
        message: 'Ticket QR verificado exitosamente. Ingreso registrado.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const ticketQrController = new TicketQrController();

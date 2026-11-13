/**
 * Controlador HTTP de pagos y comprobantes: registrar el pago, subir el voucher
 * y la bandeja del admin (listar, aprobar, rechazar).
 */
import { Request, Response, NextFunction } from 'express';
import { comprobanteService } from '../services/reservas/comprobanteService';
import { pagoService } from '../services/reservas/pagoService';

export class PagoController {
  /** POST /reservas/:id/pagos — el jugador registra su comprobante. */
  async registrarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reservaId = Number(req.params.id);
      const resultado = await pagoService.registrarPago(reservaId, req.body);
      res.status(201).json({
        ok: true,
        // Con auto_aprobar la reserva sale ya CONFIRMADA
        message:
          resultado.reserva.estado === 'CONFIRMADA'
            ? 'Comprobante registrado y aprobado. Ticket QR generado.'
            : 'Comprobante registrado exitosamente. Reserva protegida en revisión.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  /** PATCH /pagos/:id/aprobar (ADMIN) — confirma la reserva y emite el Ticket QR. */
  async aprobarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const pagoId = Number(req.params.id);
      const resultado = await pagoService.aprobarPago(pagoId);
      res.status(200).json({
        ok: true,
        message: resultado.idempotent
          ? 'El pago ya había sido aprobado previamente (operación idempotente).'
          : 'Pago aprobado exitosamente. Reserva confirmada con Ticket QR.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  /** GET /pagos?estado=... (ADMIN) — bandeja de revisión. */
  async listarPagos(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const estado = req.query.estado ? String(req.query.estado) : undefined;
      const pagos = await pagoService.listarPagos(estado);
      res.status(200).json({
        ok: true,
        count: pagos.length,
        data: pagos,
      });
    } catch (error) {
      next(error);
    }
  }

  /** PATCH /pagos/:id/rechazar (ADMIN) — requiere `observacion` con el motivo. */
  async rechazarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const pagoId = Number(req.params.id);
      const resultado = await pagoService.rechazarPago(pagoId, req.body?.observacion);
      res.status(200).json({
        ok: true,
        message: resultado.idempotent
          ? 'El pago ya había sido rechazado previamente (operación idempotente).'
          : 'Pago rechazado. El jugador puede enviar un nuevo comprobante.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  /** POST /pagos/comprobante — sube la imagen del voucher al bucket privado. */
  async subirComprobante(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const resultado = await comprobanteService.subirComprobanteStorage(req.body || {});
      res.status(201).json({
        ok: true,
        message: 'Comprobante almacenado en el bucket privado comprobantes.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const pagoController = new PagoController();

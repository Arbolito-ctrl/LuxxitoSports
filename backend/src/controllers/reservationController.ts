import { Request, Response, NextFunction } from 'express';
import { reservationService } from '../services/reservationService';

export class ReservationController {
  async cotizarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const cotizacion = await reservationService.cotizarReserva(req.body);
      res.status(200).json({
        ok: true,
        data: cotizacion,
      });
    } catch (error) {
      next(error);
    }
  }

  async crearReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reserva = await reservationService.crearReserva(req.body);
      res.status(201).json({
        ok: true,
        message: 'Reserva creada con bloqueo temporal de 20 minutos.',
        data: reserva,
      });
    } catch (error) {
      next(error);
    }
  }

  async listarReservas(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const filters = {
        estado: req.query.estado ? String(req.query.estado) : undefined,
        cliente_dni: req.query.cliente_dni ? String(req.query.cliente_dni) : undefined,
        fecha: req.query.fecha ? String(req.query.fecha) : undefined,
      };
      const reservas = await reservationService.listarReservas(filters);
      res.status(200).json({
        ok: true,
        count: reservas.length,
        data: reservas,
      });
    } catch (error) {
      next(error);
    }
  }

  async obtenerReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const reserva = await reservationService.obtenerReserva(id);
      res.status(200).json({
        ok: true,
        data: reserva,
      });
    } catch (error) {
      next(error);
    }
  }

  async actualizarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const actualizada = await reservationService.actualizarReserva(id, req.body);
      res.status(200).json({
        ok: true,
        message: 'Datos de la reserva actualizados correctamente.',
        data: actualizada,
      });
    } catch (error) {
      next(error);
    }
  }

  async eliminarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const resultado = await reservationService.eliminarReserva(id);
      res.status(200).json({
        ok: true,
        ...resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  async registrarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reservaId = Number(req.params.id);
      const resultado = await reservationService.registrarPago(reservaId, req.body);
      res.status(201).json({
        ok: true,
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

  async aprobarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const pagoId = Number(req.params.id);
      const resultado = await reservationService.aprobarPago(pagoId);
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

  async listarPagos(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const estado = req.query.estado ? String(req.query.estado) : undefined;
      const pagos = await reservationService.listarPagos(estado);
      res.status(200).json({
        ok: true,
        count: pagos.length,
        data: pagos,
      });
    } catch (error) {
      next(error);
    }
  }

  async rechazarPago(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const pagoId = Number(req.params.id);
      const resultado = await reservationService.rechazarPago(pagoId, req.body?.observacion);
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

  async cancelarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reservaId = Number(req.params.id);
      const motivo = req.body?.motivo ? String(req.body.motivo) : undefined;
      const resultado = await reservationService.cancelarReserva(reservaId, motivo);
      res.status(200).json({
        ok: true,
        message: 'Reserva cancelada aplicando la política de reembolso de 24 horas.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  async verificarQr(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const resultado = await reservationService.verificarTicketQr(req.body?.codigo_qr);
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

export const reservationController = new ReservationController();

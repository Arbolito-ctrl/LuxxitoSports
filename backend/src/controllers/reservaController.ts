/**
 * Controlador HTTP de reservas: recibe la petición, llama al servicio y arma la respuesta.
 * Las reglas de negocio viven en services/reservas/; aquí solo se traduce HTTP.
 */
import { Request, Response, NextFunction } from 'express';
import { cotizacionService } from '../services/reservas/cotizacionService';
import { reservaService } from '../services/reservas/reservaService';

export class ReservaController {
  /** POST /reservas/cotizar — precio del turno, sin guardar nada. */
  async cotizarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const cotizacion = await cotizacionService.cotizarReserva(req.body);
      res.status(200).json({
        ok: true,
        data: cotizacion,
      });
    } catch (error) {
      next(error);
    }
  }

  /** POST /reservas — crea la reserva con bloqueo de 20 minutos. */
  async crearReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reserva = await reservaService.crearReserva(req.body);
      res.status(201).json({
        ok: true,
        message: 'Reserva creada con bloqueo temporal de 20 minutos.',
        data: reserva,
      });
    } catch (error) {
      next(error);
    }
  }

  /** GET /reservas — el JUGADOR solo ve las suyas; el ADMIN ve todas y puede filtrar. */
  async listarReservas(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const filters = {
        estado: req.query.estado ? String(req.query.estado) : undefined,
        // El jugador solo ve sus propias reservas; el ADMIN puede filtrar por cualquier DNI
        cliente_dni:
          req.user && req.user.rol !== 'ADMIN'
            ? req.user.dni
            : req.query.cliente_dni
              ? String(req.query.cliente_dni)
              : undefined,
        fecha: req.query.fecha ? String(req.query.fecha) : undefined,
      };
      const reservas = await reservaService.listarReservas(filters);
      res.status(200).json({
        ok: true,
        count: reservas.length,
        data: reservas,
      });
    } catch (error) {
      next(error);
    }
  }

  /** GET /reservas/:id */
  async obtenerReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const reserva = await reservaService.obtenerReserva(id);
      res.status(200).json({
        ok: true,
        data: reserva,
      });
    } catch (error) {
      next(error);
    }
  }

  /** PUT /reservas/:id — solo datos de contacto y notas. */
  async actualizarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const actualizada = await reservaService.actualizarReserva(id, req.body);
      res.status(200).json({
        ok: true,
        message: 'Datos de la reserva actualizados correctamente.',
        data: actualizada,
      });
    } catch (error) {
      next(error);
    }
  }

  /** DELETE /reservas/:id */
  async eliminarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const id = Number(req.params.id);
      const resultado = await reservaService.eliminarReserva(id);
      res.status(200).json({
        ok: true,
        ...resultado,
      });
    } catch (error) {
      next(error);
    }
  }

  /** POST /reservas/:id/cancelar — aplica la política de devolución de 24 horas. */
  async cancelarReserva(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const reservaId = Number(req.params.id);
      const motivo = req.body?.motivo ? String(req.body.motivo) : undefined;
      const resultado = await reservaService.cancelarReserva(reservaId, motivo);
      res.status(200).json({
        ok: true,
        message: 'Reserva cancelada aplicando la política de reembolso de 24 horas.',
        data: resultado,
      });
    } catch (error) {
      next(error);
    }
  }
}

export const reservaController = new ReservaController();

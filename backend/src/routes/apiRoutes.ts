import { Router } from 'express';
import { authController } from '../controllers/authController';
import { catalogController } from '../controllers/catalogController';
import { reservationController } from '../controllers/reservationController';

const router = Router();

// 0. Autenticación y Acceso (Login, Registro y Recuperación)
router.post('/auth/login', (req, res, next) => authController.login(req, res, next));
router.post('/auth/registro', (req, res, next) => authController.registro(req, res, next));
router.post('/auth/recuperar', (req, res, next) =>
  authController.recuperarAcceso(req, res, next)
);

// 1. Estado del servicio, versión de APK y descarga OTA
router.get('/health', (req, res) => catalogController.healthCheck(req, res));
router.get('/version', (req, res) => catalogController.obtenerVersionApp(req, res));
router.get('/apk/download', (req, res) => catalogController.descargarApkLocal(req, res));

// 2. Complejos deportivos
router.get('/complejos', (req, res, next) =>
  catalogController.listarComplejos(req, res, next)
);
router.get('/complejos/:id', (req, res, next) =>
  catalogController.obtenerComplejo(req, res, next)
);

// 3. Canchas (CRUD + Disponibilidad con reglas de negocio)
router.get('/canchas', (req, res, next) =>
  catalogController.listarCanchas(req, res, next)
);
router.get('/canchas/:id', (req, res, next) =>
  catalogController.obtenerCancha(req, res, next)
);
router.post('/canchas', (req, res, next) =>
  catalogController.crearCancha(req, res, next)
);
router.put('/canchas/:id', (req, res, next) =>
  catalogController.actualizarCancha(req, res, next)
);
router.get('/canchas/:id/disponibilidad', (req, res, next) =>
  catalogController.consultarDisponibilidad(req, res, next)
);

// 4. Reservas (CRUD + Cotización del Servidor + Bloqueo + Cancelación 24h)
router.post('/reservas/cotizar', (req, res, next) =>
  reservationController.cotizarReserva(req, res, next)
);
router.get('/reservas', (req, res, next) =>
  reservationController.listarReservas(req, res, next)
);
router.get('/reservas/:id', (req, res, next) =>
  reservationController.obtenerReserva(req, res, next)
);
router.post('/reservas', (req, res, next) =>
  reservationController.crearReserva(req, res, next)
);
router.put('/reservas/:id', (req, res, next) =>
  reservationController.actualizarReserva(req, res, next)
);
router.delete('/reservas/:id', (req, res, next) =>
  reservationController.eliminarReserva(req, res, next)
);
router.post('/reservas/:id/cancelar', (req, res, next) =>
  reservationController.cancelarReserva(req, res, next)
);

// 5. Pagos manuales (Yape / Plin / Transferencia), bandeja de revisión y aprobación/rechazo idempotentes
router.post('/reservas/:id/pagos', (req, res, next) =>
  reservationController.registrarPago(req, res, next)
);
router.get('/pagos', (req, res, next) =>
  reservationController.listarPagos(req, res, next)
);
router.patch('/pagos/:id/aprobar', (req, res, next) =>
  reservationController.aprobarPago(req, res, next)
);
router.patch('/pagos/:id/rechazar', (req, res, next) =>
  reservationController.rechazarPago(req, res, next)
);

export default router;

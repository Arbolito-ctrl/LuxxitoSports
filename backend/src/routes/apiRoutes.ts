import { Router } from 'express';
import { authController } from '../controllers/authController';
import { catalogController } from '../controllers/catalogController';
import { docsController } from '../controllers/docsController';
import { pagoController } from '../controllers/pagoController';
import { reservaController } from '../controllers/reservaController';
import { ticketQrController } from '../controllers/ticketQrController';
import { requireAuth, requireRole, requireTitularDeReserva } from '../middlewares/authMiddleware';

const router = Router();

// 0. Autenticación y Acceso (Login, Registro, Perfil /me y Recuperación - LX-201)
router.post('/auth/login', (req, res, next) => authController.login(req, res, next));
router.post('/auth/registro', (req, res, next) => authController.registro(req, res, next));
router.get('/auth/me', requireAuth, (req, res, next) => authController.me(req, res, next));
router.post('/auth/recuperar', (req, res, next) =>
  authController.recuperarAcceso(req, res, next)
);

// 1. Estado del servicio, versión de APK y descarga OTA
router.get('/health', (req, res) => catalogController.healthCheck(req, res));
router.get('/version', (req, res) => catalogController.obtenerVersionApp(req, res));
router.get('/apk/download', (req, res) => catalogController.descargarApkLocal(req, res));

// 1b. Documentación interactiva (Swagger UI) y contrato OpenAPI
router.get('/docs', (req, res) => docsController.pagina(req, res));
router.get('/openapi.yaml', (req, res) => docsController.contrato(req, res));

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
router.post('/canchas', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  catalogController.crearCancha(req, res, next)
);
router.put('/canchas/:id', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  catalogController.actualizarCancha(req, res, next)
);
// Foto propia de la cancha (bucket público 'canchas'); solo el ADMIN administra el catálogo
router.post('/canchas/:id/imagen', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  catalogController.subirImagenCancha(req, res, next)
);
router.get('/canchas/:id/disponibilidad', (req, res, next) =>
  catalogController.consultarDisponibilidad(req, res, next)
);

// 4. Reservas (CRUD + Cotización del Servidor + Bloqueo + Verificación QR + Cancelación 24h)
router.post('/reservas/cotizar', (req, res, next) =>
  reservaController.cotizarReserva(req, res, next)
);
// Solo el operador (ADMIN) puede registrar el ingreso con el Ticket QR
router.post('/reservas/verificar-qr', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  ticketQrController.verificarQr(req, res, next)
);
router.get('/reservas', requireAuth, (req, res, next) =>
  reservaController.listarReservas(req, res, next)
);
router.get('/reservas/:id', requireAuth, requireTitularDeReserva, (req, res, next) =>
  reservaController.obtenerReserva(req, res, next)
);
router.post('/reservas', (req, res, next) =>
  reservaController.crearReserva(req, res, next)
);
router.put('/reservas/:id', requireAuth, requireTitularDeReserva, (req, res, next) =>
  reservaController.actualizarReserva(req, res, next)
);
router.delete('/reservas/:id', requireAuth, requireTitularDeReserva, (req, res, next) =>
  reservaController.eliminarReserva(req, res, next)
);
router.post('/reservas/:id/cancelar', requireAuth, requireTitularDeReserva, (req, res, next) =>
  reservaController.cancelarReserva(req, res, next)
);

// 5. Pagos manuales (Yape / Plin / Transferencia), subida a bucket comprobantes, bandeja y aprobación/rechazo (ADMIN - LX-201)
router.post('/pagos/comprobante', (req, res, next) =>
  pagoController.subirComprobante(req, res, next)
);
router.post('/reservas/:id/pagos', requireAuth, requireTitularDeReserva, (req, res, next) =>
  pagoController.registrarPago(req, res, next)
);
router.get('/pagos', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  pagoController.listarPagos(req, res, next)
);
router.patch('/pagos/:id/aprobar', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  pagoController.aprobarPago(req, res, next)
);
router.patch('/pagos/:id/rechazar', requireAuth, requireRole('ADMIN'), (req, res, next) =>
  pagoController.rechazarPago(req, res, next)
);

export default router;

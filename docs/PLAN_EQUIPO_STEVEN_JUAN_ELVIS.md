# Plan de Trabajo y Distribución de Tareas — Equipo Luxxito Sports (Elvis · Juan · Steven)

**Fecha de actualización:** 3 de noviembre de 2026 (Perú)  
**Repositorio oficial:** `https://github.com/Arbolito-ctrl/LuxxitoSports`  
**Ramas activas:** `main` (versión estable + APK de producción) y `develop` (integración continua + APK de desarrollo)  
**Referencia metodológica:** [docs/METODOLOGIA.md](METODOLOGIA.md) y [docs/PLAN.md](PLAN.md)

---

## 1. Diagnóstico Actual: Estado del Proyecto

### 1.1. Todo lo construido e integrado en `develop` y `main`
- **Backend API REST propia (`backend/`)**: 22 endpoints bajo `/api`, arquitectura en capas (`middlewares/`, `controllers/`, `services/`, `repositories/`), conexión a **Supabase PostgreSQL** (`DATABASE_URL` y `@supabase/supabase-js`), CRUD completo de Canchas y Reservas, autenticación JWT (`POST /api/auth/login`, `POST /api/auth/registro`, `GET /api/auth/me`), control de rol `ADMIN` en bandeja de pagos (`GET /api/pagos`, `PATCH /api/pagos/:id/aprobar`, `PATCH /api/pagos/:id/rechazar`), verificación única de Ticket QR (`POST /api/reservas/verificar-qr`) y expiración automática de bloqueos de 20 minutos (`LX-203`).
- **Base de datos en Supabase (`backend/sql/`)**: Esquema de 7 tablas relacionadas (`usuarios`, `complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) con **Row Level Security (RLS)** activo, bucket privado `comprobantes` en Supabase Storage y funciones RPC `SECURITY DEFINER`.
- **App Móvil Flutter (`mobile/`)**: Pantalla inicial de Login/Registro, navegación de 3 pestañas (**Explorar · Mis reservas · Perfil**), tema claro deportivo (`LX-300`), bandeja de revisión de pagos para `ADMIN` (`LX-301`), temporizador de 20 minutos (`expires_at`) y módulo de descarga de actualizaciones OTA/APK.
- **Automatización y Entregables Taller 3**: **20 pruebas automatizadas (`npm test`)**, colección Postman ejecutable con Newman, contrato OpenAPI 1.3.0 (`contracts/openapi.yaml`), Documento Técnico en PDF (`docs/DOCUMENTO_TECNICO_TALLER3.pdf`) y workflow de compilación automática de APK con secrets de repositorio (`.github/workflows/apk.yml`).

---

## 2. Asignación de Responsabilidades por Integrante

| Integrante | Rol Principal | Áreas bajo su responsabilidad | Prefijo de Ramas |
|---|---|---|---|
| **Elvis** | **Líder Móvil, CI/CD de APK y Despliegue** | App Flutter (`mobile/`), experiencia de usuario, actualización OTA/APK, conexión con API en la nube y promoción `develop -> main`. | `elvis/<tema>` |
| **Juan** | **Líder Backend, Base de Datos Supabase y Contratos** | API REST (`backend/`), reglas de negocio avanzadas, autenticación JWT, verificación de QR, expiración de bloqueos, migraciones SQL y contratos (`contracts/`). | `juan/<tema>` |
| **Steven** | **Líder de FrontEnd (UI Móvil / Panel Web), Pagos/Comprobantes, QA y Demo** | Diseño e interfaz FrontEnd, flujo de comprobantes y bandeja de revisión, colección Postman, pruebas y evidencia del Taller 3 (`docs/`). | `steven/<tema>` |

---

## 3. Ficha Detallada de Tareas por Integrante

### Bloque de Elvis (Móvil Flutter · Distribución APK · Cloud) — [COMPLETADO]

#### `LX-101` — Despliegue/Conexión en la Nube y Configuración de URL de Producción en el APK (`[x] Completado`)
- **Responsable:** Elvis
- **Rama:** `elvis/deploy-api-cloud`
- **Estado:** Completado. Configurados secrets `API_BASE_URL`, `SUPABASE_URL` y `SUPABASE_ANON_KEY` en GitHub Actions (`.github/workflows/apk.yml`), permisos `INTERNET` en `AndroidManifest.xml` y funciones RPC `SECURITY DEFINER` con RLS en Supabase.

#### `LX-102` — Pantalla de Login/Registro y Persistencia de Sesión en Flutter (`[x] Completado`)
- **Responsable:** Elvis
- **Rama:** `elvis/auth-movil`
- **Estado:** Completado. Pantalla `mobile/lib/screens/auth_screen.dart` con autocompletado de perfil, envío de `Authorization: Bearer <token>` y cierre de sesión.

#### `LX-103` — Recuperación de Estado de Bloqueo (`expires_at`) y Temporizador Visual de 20 Minutos (`[x] Completado`)
- **Responsable:** Elvis
- **Rama:** `elvis/timer-bloqueo-20min`
- **Estado:** Completado. Cuenta regresiva real sincronizada con `expires_at` del servidor y refresco al reanudar la aplicación (`AppLifecycleState.resumed`).

---

### Bloque de Juan (Backend Node/TS · Supabase PostgreSQL · Contratos) — [COMPLETADO]

#### `LX-201` — Endpoints de Identidad (`/api/auth/registro`, `/api/auth/login`, `/api/auth/me`) y Control de Rol `ADMIN` (`[x] Completado` · PR #8 · Issue #2)
- **Responsable:** Juan
- **Rama:** `juan/auth-jwt-endpoints`
- **Entregado:**
  1. Tabla `usuarios` en `backend/sql/schema.sql` con RLS activo.
  2. `AuthService`, `AuthController` y `authMiddleware.ts` (`requireAuth`, `requireRole('ADMIN')`) con emisión y validación de JWT firmado con `JWT_SECRET`.
  3. Protección de `GET /api/pagos`, `PATCH /api/pagos/:id/aprobar` y `PATCH /api/pagos/:id/rechazar` (`401` sin token, `403` si es `JUGADOR`) y endpoint `GET /api/auth/me`.
  4. Casos 17 y 18 en `backend/src/tests/api.test.ts`.

#### `LX-202` — Endpoint de Verificación y Escaneo de Ticket QR (`POST /api/reservas/verificar-qr`) (`[x] Completado` · PR #9)
- **Responsable:** Juan
- **Rama:** `juan/verificacion-qr`
- **Entregado:**
  1. Endpoint `POST /api/reservas/verificar-qr` que valida formato `LUXXITO-QR-...`, estado `CONFIRMADA` y registra el ingreso único (`qr_usado_at`).
  2. Rechaza con `409 Conflict` cualquier QR ya escaneado previamente o perteneciente a una reserva `CANCELADA`, y con `404 Not Found` si no existe.
  3. Caso 19 en `backend/src/tests/api.test.ts`.

#### `LX-203` — Vencimiento Automático de Bloqueos de 20 Minutos No Pagados (`[x] Completado` · PR #10)
- **Responsable:** Juan
- **Rama:** `juan/expiracion-bloqueos`
- **Entregado:**
  1. Limpieza automática (`dataRepository.expireOverdueReservas()`) antes de consultar disponibilidad, cotizar, listar, obtener o crear reservas, pasando a `VENCIDA` las reservas en `PENDIENTE_PAGO` cuyo `expires_at < NOW()`.
  2. Las reservas en `EN_REVISION` o `CONFIRMADA` quedan protegidas y nunca expiran por esta limpieza.
  3. Caso 20 en `backend/src/tests/api.test.ts`.

---

### Bloque de Steven (FrontEnd UI · Pagos/Comprobantes · QA y Demostración Taller 3) — [COMPLETADO]

#### `LX-300` — Desarrollo y Pulido de FrontEnd Móvil (`[x] Completado` · PR #4, #25, #27, #30 y #32)
- **Responsable:** Steven
- **Entregado:** diseño "Claro deportivo", panel propio del ADMIN (Inicio, Pagos, Ingreso, Reservas), verificador de Ticket QR con cámara, actualización desde la app con firma fija del APK, sesión persistente e ícono oficial.

#### `LX-301` — Bandeja Administrativa de Revisión de Comprobantes y Bucket Storage (`[x] Completado` · PR #3, #21 · Issue #5)
- **Responsable:** Steven
- **Entregado:** bandeja de revisión con aprobación y rechazo, subida real de la foto del voucher al bucket privado `comprobantes` con enlace firmado para el ADMIN.

#### `LX-302` — Suite de Pruebas Automatizadas (23 Casos) y Colección Postman Ejecutable (38 requests, 63 aserciones) (`[x] Completado` · PR #6 y PR #10)
- **Responsable:** Steven (con casos `LX-201..203` integrados por Juan)
- **Rama:** `steven/qa-pruebas-y-postman`

#### `LX-303` — Guion y Evidencia de Demostración en Vivo Taller 3 (`[~] Guion actualizado` · PR #7 · faltan capturas finales del paso 5)
- **Responsable:** Steven
- **Rama:** `steven/evidencia-demostracion-taller3`

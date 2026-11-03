# Plan de Trabajo y Distribución de Tareas — Equipo Luxxito Sports (Elvis · Juan · Steven)

**Fecha de actualización:** 3 de noviembre de 2026 (Perú)  
**Repositorio oficial:** `https://github.com/Arbolito-ctrl/LuxxitoSports`  
**Ramas activas:** `main` (versión estable + APK de producción) y `develop` (integración continua + APK de desarrollo)  
**Referencia metodológica:** [docs/METODOLOGIA.md](METODOLOGIA.md) y [docs/PLAN.md](PLAN.md)

---

## 1. Diagnóstico Actual: ¿Qué ya está listo y qué falta?

### 1.1. Lo que ya está construido y subido al repositorio (Base v1.0)
- **Backend API REST propia (`backend/`)**: 14 endpoints bajo `/api`, arquitectura en 3 capas (`controllers/`, `services/`, `repositories/`), conexión a **Supabase PostgreSQL** (`DATABASE_URL` y `@supabase/supabase-js`), CRUD completo de Canchas y Reservas, y 5 reglas de negocio implementadas (disponibilidad horaria, cotización día/noche + seña 50%, bloqueo de 20 min con exclusión mutua, stock de extras por intervalo, pago idempotente con QR y cancelación con regla de 24h).
- **Base de datos en Supabase (`backend/sql/`)**: Esquema de 6 tablas relacionadas (`complejos`, `canchas`, `extras`, `reservas`, `reserva_extras`, `pagos`) y datos semilla inicializados.
- **App Móvil Flutter (`mobile/`)**: Navegación de 3 pestañas (**Explorar · Mis reservas · Perfil**), pantalla de disponibilidad y reserva, flujo de pago Yape/Plin, visualización de Ticket QR y módulo de descarga de actualizaciones OTA/APK.
- **Automatización y Entregables Taller 3**: 8 pruebas automatizadas (`npm test`), colección Postman, contrato OpenAPI (`contracts/openapi.yaml`), Documento Técnico en PDF (`docs/DOCUMENTO_TECNICO_TALLER3.pdf`) y workflow de compilación automática de APK (`.github/workflows/apk.yml`).

### 1.2. Lo que falta completar y distribuir entre Elvis, Juan y Steven
Para cerrar al 100% la **demostración en vivo del Taller 3** y completar las capacidades operativas pendientes del **Plan Móvil de Luxxito Sports**:
1. **Autenticación JWT y Perfil Persistente**: Pantallas y endpoints de Registro/Login (`/api/auth/registro`, `/api/auth/login`, `/api/auth/me`) con almacenamiento seguro de sesión en el teléfono.
2. **Subida Real de Imagen de Comprobante (Cámara/Galería -> Supabase Storage)**: Adjuntar foto del voucher de Yape/Plin desde el móvil hacia un bucket privado de Supabase Storage.
3. **Bandeja Administrativa de Revisión de Pagos y Escáner/Verificador de Ticket QR**: Vista o modo operador para aprobar/rechazar comprobantes (`PENDIENTE_REVISION` -> `APROBADO` / `RECHAZADO`) y endpoint de validación de ingreso con QR (`POST /api/reservas/verificar-qr`).
4. **Despliegue en la Nube del Backend (Render / Railway) para el APK en Dispositivos Físicos**: Publicar la API REST en una URL pública HTTPS para que el APK instalado en cualquier celular funcione con datos móviles sin depender de `localhost`.
5. **Pruebas de Concurrencia en PostgreSQL y Evidencia de Demostración (Video/Capturas Taller 3)**: Ejecutar pruebas simultáneas contra Supabase, grabar/capturar la demostración exigida en la diapositiva 6 del Taller 3 (cambio persistido en BD) y cerrar el informe de validación.

---

## 2. Asignación de Responsabilidades por Integrante

| Integrante | Rol Principal | Áreas bajo su responsabilidad | Prefijo de Ramas |
|---|---|---|---|
| **Elvis** | **Líder Móvil, CI/CD de APK y Despliegue** | App Flutter (`mobile/`), experiencia de usuario, actualización OTA/APK, conexión con API en la nube y promoción `develop -> main`. | `elvis/<tema>` |
| **Juan** | **Líder Backend, Base de Datos Supabase y Contratos** | API REST (`backend/`), reglas de negocio avanzadas, autenticación JWT, verificación de QR, migraciones SQL y contratos (`contracts/`). | `juan/<tema>` |
| **Steven** | **Líder de FrontEnd (UI Móvil / Panel Web), Pagos/Comprobantes, QA y Demo** | Diseño e interfaz FrontEnd (componentes visuales, estados de carga/vacío/error, panel administrativo web `frontend/`), flujo de comprobantes, colección Postman, pruebas y evidencia del Taller 3 (`docs/`). | `steven/<tema>` |

---

## 3. Ficha Detallada de Tareas por Integrante

### Bloque de Elvis (Móvil Flutter · Distribución APK · Cloud) — [COMPLETADO]

#### `LX-101` — Despliegue de la API REST en la Nube y Configuración de URL de Producción en el APK (`[x] Completado`)
- **Responsable:** Elvis
- **Rama sugerida:** `elvis/deploy-api-cloud`
- **Problema:** Cuando el APK se instala en un teléfono físico fuera de la red local, necesita conectarse a una URL HTTPS pública en lugar de `localhost:3000`.
- **Qué hacer:**
  1. Desplegar la carpeta `backend/` en Render o Railway configurando las variables `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` y `JWT_SECRET`.
  2. Actualizar la URL por defecto en `mobile/lib/services/api_service.dart` (y en `.github/workflows/apk.yml`) para que apunte al backend en la nube, manteniendo el selector manual en la pestaña **Perfil**.
- **Criterio de aceptación:** El APK descargado desde GitHub Releases consulta el catálogo y crea una reserva en Supabase usando datos móviles 4G/5G.
- **Verificación:** `GET https://<tu-api>/api/health` responde `200 OK` con `"db_mode": "POSTGRES_POOL"`.

#### `LX-102` — Pantalla de Login/Registro y Persistencia de Sesión en Flutter (`[x] Completado`)
- **Responsable:** Elvis
- **Rama sugerida:** `elvis/auth-movil`
- **Dependencias:** `LX-201` (Endpoints de Auth de Juan)
- **Problema:** Actualmente los datos del titular en la reserva se autocompletan manualmente; falta iniciar sesión para autocompletar perfil y filtrar "Mis Reservas" por el usuario autenticado.
- **Qué hacer:**
  1. Crear pantalla de Login y Registro en `mobile/lib/screens/auth_screen.dart`.
  2. Guardar el token JWT y datos del jugador (`nombre`, `dni`, `telefono`, `email`) en memoria/almacenamiento local y enviarlos en el header `Authorization: Bearer <token>`.
- **Criterio de aceptación:** Al iniciar sesión, el formulario de reserva rellena automáticamente los datos del jugador y la pestaña **Perfil** muestra su cuenta activa con botón de "Cerrar sesión".

#### `LX-103` — Recuperación de Estado de Bloqueo (`expires_at`) y Temporizador Visual de 20 Minutos (`[x] Completado`)
- **Responsable:** Elvis
- **Rama sugerida:** `elvis/timer-bloqueo-20min`
- **Problema:** El plan móvil exige mostrar una cuenta regresiva real basada en el campo `expires_at` devuelto por el servidor cuando una reserva está en `PENDIENTE_PAGO`.
- **Qué hacer:**
  1. En `mobile/lib/screens/mis_reservas_screen.dart`, calcular la diferencia entre `expiresAt` del servidor y la hora actual para mostrar el contador `MM:SS` restante para enviar el comprobante.
  2. Si la app vuelve de segundo plano (`AppLifecycleState.resumed`), refrescar `/api/reservas` para sincronizar el tiempo real del servidor.
- **Criterio de aceptación:** Cerrar y reabrir la app no reinicia los 20 minutos; muestra exactamente el tiempo restante del servidor.

---

### Bloque de Juan (Backend Node/TS · Supabase PostgreSQL · Contratos)

#### `LX-201` — Endpoints de Identidad (`/api/auth/registro`, `/api/auth/login`, `/api/auth/me`)
- **Responsable:** Juan
- **Rama sugerida:** `juan/auth-jwt-endpoints`
- **Problema:** Cumplir con el módulo de identidad del MVP móvil y asociar reservas a usuarios registrados.
- **Qué hacer:**
  1. Añadir tabla `usuarios` en `backend/sql/schema.sql` (`id`, `nombre`, `dni` único, `telefono`, `email` único, `password_hash`, `rol` `'JUGADOR' | 'ADMIN'`).
  2. Implementar `AuthService` y `AuthController` con emisión de token JWT firmado con `process.env.JWT_SECRET`.
  3. Documentar las 3 rutas en `contracts/openapi.yaml` y `docs/API_DOCUMENTATION.md`.
- **Criterio de aceptación:** Registro duplica DNI/email con `409 Conflict`, login inválido responde `401 Unauthorized` y login válido retorna JWT + perfil.

#### `LX-202` — Endpoint de Verificación y Escaneo de Ticket QR (`POST /api/reservas/verificar-qr`)
- **Responsable:** Juan
- **Rama sugerida:** `juan/verificacion-qr`
- **Problema:** El criterio de aceptación 9 del Plan Móvil exige que al escanear o validar un código QR se compruebe que esté `CONFIRMADA`, no haya sido cancelado y no se use dos veces (`INGRESO_REGISTRADO`).
- **Qué hacer:**
  1. Crear endpoint `POST /api/reservas/verificar-qr` que reciba `{ "codigo_qr": "LUXXITO-QR-..." }`.
  2. Si la reserva está `CANCELADA` o el QR no existe, responder `409 Conflict` / `404 Not Found`.
  3. Si está `CONFIRMADA`, validar acceso y devolver los datos de la cancha, horario y jugador.
- **Criterio de aceptación:** Un QR de reserva cancelada es rechazado inmediatamente por el servidor.

#### `LX-203` — Vencimiento Automático de Bloqueos de 20 Minutos No Pagados
- **Responsable:** Juan
- **Rama sugerida:** `juan/expiracion-bloqueos`
- **Problema:** Si un usuario crea una reserva (`PENDIENTE_PAGO`) y nunca sube comprobante pasados los 20 minutos (`expires_at < NOW()`), el turno debe liberarse automáticamente.
- **Qué hacer:**
  1. En `ReservationService` / `CatalogService`, antes de consultar disponibilidad o crear una reserva, ejecutar limpieza automática que pase a `VENCIDA` las reservas en estado `PENDIENTE_PAGO` cuyo `expires_at < NOW()` (respetando intactas las que están `EN_REVISION` o `CONFIRMADA`).
- **Criterio de aceptación:** Una reserva en `PENDIENTE_PAGO` con `expires_at` vencido pasa a `VENCIDA` y libera el turno; una reserva en `EN_REVISION` **nunca** vence por esa limpieza.

---

### Bloque de Steven (FrontEnd UI / Panel Web · Pagos/Comprobantes · QA y Demostración Taller 3)

#### `LX-300` — Desarrollo y Pulido de FrontEnd (Componentes UI, Estados de Pantalla y Panel Administrativo) (`[x] Completado` · PR #4)
- **Responsable:** Steven
- **Rama sugerida:** `steven/frontend-ui-admin`
- **Problema:** Asegurar que tanto las vistas móviles como el panel administrativo FrontEnd mantengan la línea gráfica de Luxxito Sports (azul oscuro `#0F172A` y verde `#10B981`, tarjetas de complejos con imágenes, estados de carga/vacío/error/reintento y accesibilidad).
- **Qué hacer:**
  1. Refinar los componentes de interfaz FrontEnd (tarjetas de canchas con badges de superficie/iluminación, previsualización de comprobantes, modales de confirmación y vista de agenda administrativa).
  2. Garantizar que cada pantalla maneje explícitamente los 4 estados visuales: cargando (`skeleton/spinner`), lista vacía, error de red con botón de reintento y confirmación exitosa.
- **Criterio de aceptación:** Interfaz consistente y responsiva conectada en tiempo real a los endpoints de la API REST sin usar datos simulados (`mocks`).

#### `LX-301` — Captura/Subida de Imagen de Comprobante y Bandeja Administrativa de Revisión (`[~] Bandeja completada` · PR #3 · falta subida de imagen: requiere bucket, issue #5)
- **Responsable:** Steven
- **Rama sugerida:** `steven/comprobantes-y-revision`
- **Problema:** Separar el flujo del jugador (que sube el comprobante y deja la reserva en `EN_REVISION`) del flujo del administrador (que revisa los pagos pendientes y los aprueba o rechaza con motivo).
- **Qué hacer:**
  1. Añadir en el backend `GET /api/pagos/pendientes` y `PATCH /api/pagos/:id/rechazar` (con campo `observacion` obligatorio).
  2. En la app móvil (pestaña **Mis Reservas** o sección **Modo Operador en Perfil**), permitir previsualizar el comprobante y probar tanto la aprobación (`PATCH /api/pagos/:id/aprobar`) como el rechazo (`PATCH /api/pagos/:id/rechazar`).
- **Criterio de aceptación:** Un pago rechazado registra el motivo de rechazo y permite al jugador reintentar el envío de un comprobante válido.

#### `LX-302` — Ampliación de Suite de Pruebas y Colección Postman con Casos de Borde (`[~] 17 pruebas y Postman listos` · faltan casos de LX-202 y LX-203)
- **Responsable:** Steven
- **Rama sugerida:** `steven/qa-pruebas-y-postman`
- **Dependencias:** `LX-202`, `LX-203`, `LX-301`
- **Problema:** Asegurar que todos los endpoints nuevos tengan cobertura en `backend/src/tests/api.test.ts` y en `docs/LuxxitoSports.postman_collection.json`.
- **Qué hacer:**
  1. Agregar casos de prueba automatizados para: rechazo de horas pasadas (`422`), cancelación con menos de 24 horas (retención del 50%), verificación de código QR y rechazo de comprobante inválido.
  2. Actualizar `docs/validaciones/2026-11-02-taller3.md` con los nuevos conteos de pruebas.
- **Criterio de aceptación:** `cd backend && npm test` ejecuta >= 12 pruebas en verde sin advertencias.

#### `LX-303` — Guion y Evidencia de Demostración en Vivo (Entregable Obligatorio Taller 3) (`[~] Guion listo` · faltan capturas con Supabase)
- **Responsable:** Steven (con apoyo de Elvis y Juan)
- **Rama sugerida:** `steven/evidencia-demostracion-taller3`
- **Problema:** La diapositiva 6 del PDF del Taller 3 exige: *"DEMOSTRACIÓN: Cliente consumiendo la API; operación completa y cambio persistido en base de datos"*.
- **Qué hacer:**
  1. Preparar capturas paso a paso en `docs/validaciones/DEMOSTRACION_TALLER3.md` mostrando:
     - **Paso 1:** App móvil Flutter listando y filtrando canchas desde la API.
     - **Paso 2:** Selección de horario y extras con cotización calculada por el servidor.
     - **Paso 3:** Creación de reserva (`201 Created`) y verificación en el **Table Editor de Supabase** (`reservas` y `reserva_extras`).
     - **Paso 4:** Intento de reserva duplicada en el mismo horario mostrando el error `409 Conflict` en la app.
     - **Paso 5:** Registro de pago Yape, generación de Ticket QR (`CONFIRMADA`) y cancelación con cálculo de reembolso persistido en Supabase.
  2. Regenerar el PDF técnico con `cd backend && npx tsx src/scripts/generatePdf.ts` si se agregan nuevos endpoints.

---

## 4. Flujo de Trabajo Diario en Git para los 3 Integrantes

Para evitar conflictos y mantener el estándar de `ContextApp`:

```bash
# 1. Antes de empezar una tarea, sincronizar develop:
git checkout develop
git pull origin develop

# 2. Crear tu rama con tu nombre y tema (ejemplo para Juan):
git checkout -b juan/verificacion-qr

# 3. Verificar siempre antes de hacer commit:
cd backend && npm run build && npm test
cd ../mobile && flutter analyze && flutter test

# 4. Subir tu rama y abrir Pull Request hacia develop:
git push -u origin juan/verificacion-qr
```

> **Regla de oro:**
> - Ningún integrante sube el archivo `backend/.env` al repositorio.
> - Cada vez que se integra un PR en `develop`, GitHub Actions (`.github/workflows/apk.yml`) compila y publica automáticamente el APK de pruebas (`dev-apk`).
> - Cuando las pruebas de la semana están validadas, **Elvis** promueve `develop -> main` mediante *merge commit*, lo que genera automáticamente el APK oficial (`latest-apk`) listo para descargar desde GitHub Releases.

---

## 5. Cronograma de Ejecución Corto (Cierre Taller 3 y Siguiente Iteración)

| Fase | Tareas | Responsables | Entregable Verificable |
|---|---|---|---|
| **Fase 1 (Inmediata - Cierre Demo Taller 3)** | `LX-101`, `LX-202`, `LX-303` | Elvis, Juan, Steven | API en la nube + APK conectado + Capturas de persistencia en Supabase. |
| **Fase 2 (Seguridad y Expiración)** | `LX-103`, `LX-201`, `LX-203` | Elvis, Juan | Login/Registro con JWT + Temporizador real de 20 min + Limpieza de vencidos. |
| **Fase 3 (Operación Completa y QA)** | `LX-102`, `LX-301`, `LX-302` | Elvis, Steven | Bandeja de aprobación/rechazo de comprobantes + 12 pruebas automatizadas. |


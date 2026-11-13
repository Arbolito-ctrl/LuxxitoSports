# Historial de Cambios de Contratos — Luxxito Sports API

## [1.8.0] - 2026-11-13 (Sugerencia de nombre por DNI)

### Añadido
- `GET /dni/{numero}`: devuelve solo nombres y apellidos asociados al DNI para autocompletar el registro (proveedor Decolecta, token solo en el servidor). Límite de 10 consultas por minuto por IP (`429` con `Retry-After`); `404` si no se encuentra y `503` si el proveedor no está configurado o no responde.

### Seguridad
- La app ya no lleva `SUPABASE_URL` ni `SUPABASE_ANON_KEY` y solo usa la API propia. Las funciones `rpc_*` y la lectura de `reservas`, `reserva_extras` y `pagos` quedaron cerradas a la anon key (migración `backend/sql/migraciones/2026-11-13_cerrar_acceso_publico.sql`).

## [1.7.0] - 2026-11-03 (Swagger UI)

### Añadido
- `GET /docs`: documentación interactiva con Swagger UI para probar la API desde el navegador (botón *Authorize* para el JWT).
- `GET /openapi.yaml`: entrega este contrato.
- Cuerpos de solicitud con ejemplos en `POST /auth/login`, `POST /auth/registro`, `POST /canchas`, `PUT /canchas/{id}`, `POST /reservas/cotizar`, `POST /reservas`, `PUT /reservas/{id}` y `POST /reservas/{id}/cancelar`.

## [1.6.0] - 2026-11-03 (Entregables y seguridad)

### Añadido
- `POST /canchas/{id}/imagen` documentado (solo ADMIN): sube la foto al bucket público `canchas`.
- `GET /version` documentado: devuelve la última versión publicada del APK leyendo `version.json` de GitHub Releases (`502` si GitHub no responde). Ya no devuelve valores fijos.

### Cambiado
- `POST /canchas` y `PUT /canchas/{id}` documentan que son solo ADMIN (`401`/`403`) y responden `409` si el nombre de la cancha ya existe en el complejo.
- `POST /reservas` documenta el `409` ante un pedido simultáneo por el mismo turno.
- `GET /health` informa `api_version` (de `package.json`) y `commit` (el desplegado en Render) en lugar de una versión fija; responde `503` si la base de datos no responde.
- Las contraseñas se guardan con hash `scrypt` y sal por usuario. Las cuentas antiguas en texto plano se migran en su primer login.
- El JWT incluye `exp` (30 días); un token vencido responde `401`.

## [1.5.0] - 2026-11-03 (Titularidad de reservas)

### Cambiado
- `GET /reservas` requiere JWT: el JUGADOR ve solo sus reservas (se ignora `cliente_dni` de otra persona) y el ADMIN ve todas.
- `GET /reservas/{id}`, `PUT /reservas/{id}`, `DELETE /reservas/{id}`, `POST /reservas/{id}/cancelar` y `POST /reservas/{id}/pagos` requieren JWT y solo los puede usar el **titular** (mismo DNI) o un ADMIN: `401` sin token, `403` con la reserva de otra persona.

## [1.4.0] - 2026-11-03 (LX-301 subida real y verificación QR por ADMIN)

### Añadido
- `POST /pagos/comprobante` documentado: guarda el voucher en el bucket privado `comprobantes` y devuelve `comprobante_url` y `almacenado`. Respuestas `409` (reserva cancelada o vencida), `413 PAYLOAD_TOO_LARGE` y `502 STORAGE_ERROR`.
- `GET /pagos` incluye `comprobante_url_firmada`: un enlace temporal de 1 hora para ver el voucher.
- `POST /reservas/{id}/pagos` documenta su cuerpo y acepta `comprobante_url`; responde `400` si el voucher pertenece a otra reserva.

### Cambiado
- `POST /reservas/verificar-qr` ahora requiere JWT con rol `ADMIN` (`401` / `403`). Solo el operador registra ingresos.
- Sin foto adjunta, `comprobante_url` queda en `null` (ya no se genera una URL de ejemplo).
- Los errores de lectura del cuerpo responden `413` o `400 INVALID_JSON` en lugar de `500`.

## [1.2.0] - 2026-11-03 (LX-201 & Infra #5)

### Añadido
- Esquema de seguridad `components.securitySchemes.bearerAuth` (`HTTP Bearer JWT` firmado con `JWT_SECRET`).
- Respuestas `401 Unauthorized` y `403 Forbidden` en `GET /pagos`, `PATCH /pagos/{id}/aprobar` y `PATCH /pagos/{id}/rechazar` (restringidos exclusivamente a `rol: 'ADMIN'`).
- Documentación de endpoints `POST /auth/login` y `POST /auth/registro`.

## [1.1.0] - 2026-11-03 (LX-301)

### Añadido
- `GET /pagos?estado=` — bandeja de revisión de comprobantes con el resumen de la reserva de cada pago.
- `PATCH /pagos/:id/rechazar` — rechazo idempotente con `observacion` obligatoria; la reserva `EN_REVISION` vuelve a `PENDIENTE_PAGO` con un nuevo bloqueo de 20 minutos.

### Cambiado
- `PATCH /pagos/:id/aprobar` responde `409` si el pago ya fue `RECHAZADO` o `REEMBOLSADO`.

## [1.0.0] - 2026-11-02 (Taller 3 · SI806)

### Añadido
- Contrato inicial OpenAPI 3.0.3 (`contracts/openapi.yaml`) para los recursos `/complejos`, `/canchas`, `/canchas/:id/disponibilidad`, `/reservas/cotizar`, `/reservas`, `/reservas/:id/pagos`, `/pagos/:id/aprobar` y `/reservas/:id/cancelar`.
- Ejemplos verificables de solicitudes válidas (`201 Created`) y rechazos por reglas de negocio (`409 Conflict`).

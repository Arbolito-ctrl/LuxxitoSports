# Historial de Cambios de Contratos — Luxxito Sports API

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

# Historial de Cambios de Contratos — Luxxito Sports API

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

